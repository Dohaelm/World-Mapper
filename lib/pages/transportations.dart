import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_application_1/models/navigation_models.dart';
import 'package:flutter_application_1/pages/navigation_screen.dart';
import 'package:flutter_application_1/services/directions_parser.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:io';

class TransportationOptionsPage extends StatefulWidget {
  final LatLng startPoint;
  final LatLng destinationPoint;


  const TransportationOptionsPage({
    required this.startPoint,
    required this.destinationPoint,
    super.key,
  });

  @override
  _TransportationOptionsPageState createState() => _TransportationOptionsPageState();
}

class _TransportationOptionsPageState extends State<TransportationOptionsPage> {
  final String googleApiKey = dotenv.env['GOOGLE_API_KEY'] ?? '';
  List<dynamic> routes = [];
  bool isLoading = true;
  String? errorMessage;
  Map<String, dynamic>? cheapestRoute;
  Map<String, dynamic>? fastestRoute;
  Map<String, dynamic>? mostComfortableRoute;
  

  
  dynamic drivingRoute;
  
  // The green theme colors
  final Color primaryGreen = Color(0xFF4CAF50);
  final Color lightGreen = Color(0xFFAED581);
  final Color darkGreen = Color(0xFF2E7D32);
  void classifyRoutes() {
  if (routes.isEmpty) return;

  // Cheapest based on estimated price
  cheapestRoute = routes.reduce((a, b) {
    final priceA = calculateTotalPrice(a);
    final priceB = calculateTotalPrice(b);
    return priceA < priceB ? a : b;
  });

  // Fastest based on duration value (in seconds)
  fastestRoute = routes.reduce((a, b) {
    final durationA = a['legs'][0]['duration']['value'];
    final durationB = b['legs'][0]['duration']['value'];
    return durationA < durationB ? a : b;
  });

  // Most comfortable: Consider vehicle preference, number of transfers, and destination accuracy
  List<String> comfortRanking = ['TRAM', 'SUBWAY', 'BUS'];

  int getComfortScore(Map<String, dynamic> route) {
    final steps = route['legs'][0]['steps'];
    
    // Count transit steps (transfers)
    int transitSteps = 0;
    int bestVehicleScore = comfortRanking.length; // Default to worst
    
    for (var step in steps) {
      if (step['travel_mode'] == 'TRANSIT') {
        transitSteps++;
        final line = step['transit_details']['line'];
        final vehicleType = extractVehicleType(line);
        final vehicleScore = comfortRanking.contains(vehicleType) 
            ? comfortRanking.indexOf(vehicleType) 
            : comfortRanking.length;
        
        // Keep track of the best (most comfortable) vehicle type in this route
        if (vehicleScore < bestVehicleScore) {
          bestVehicleScore = vehicleScore;
        }
      }
    }
    
    // Check if route reaches exact destination (look at final step)
    final lastStep = steps.last;
    bool reachesExactDestination = lastStep['travel_mode'] != 'WALKING' || 
        (lastStep['distance']?['value'] ?? 0) < 100; // Less than 100m walking at end
    
    // Calculate composite comfort score
    // Lower score = more comfortable
    int score = 0;
    
    // Vehicle type preference (0-3, lower is better)
    score += bestVehicleScore * 10;
    
    // Number of transfers penalty (more transfers = less comfortable)
    score += (transitSteps - 1) * 5; // First transit step doesn't count as transfer
    
    // Destination accuracy penalty
    if (!reachesExactDestination) {
      score += 20; // Heavy penalty for not reaching exact destination
    }
    
    return score;
  }

  mostComfortableRoute = routes.reduce((a, b) {
    final scoreA = getComfortScore(a);
    final scoreB = getComfortScore(b);
    return scoreA < scoreB ? a : b;
  });
}

double calculateTotalPrice(Map<String, dynamic> route) {
  double total = 0.0;
  for (var step in route['legs'][0]['steps']) {
    if (step['travel_mode'] == 'TRANSIT') {
      final line = step['transit_details']['line'];
      final vehicleType = extractVehicleType(line);
      final distance = step['distance']?['value'] ?? 0;
      total += calculatePrice(vehicleType, distance.toDouble());
    }
  }
  return total;
}

  String extractVehicleType(Map<String, dynamic> line) {
  if (line['vehicle'] != null) {
    if (line['vehicle']['type'] != null && line['vehicle']['type'] != 'TRANSIT') {
      return line['vehicle']['type']; // Ex: BUS, TRAM
    } else if (line['vehicle']['name'] != null) {
      final name = line['vehicle']['name'].toString().toLowerCase();
      if (name.contains('bus')) return 'BUS';
      if (name.contains('tram')) return 'TRAM';
      if (name.contains('subway') || name.contains('metro')) return 'SUBWAY';
    }
  }

  // Try fallback on line name
  final fallback = line['name']?.toString().toLowerCase() ?? '';
  if (fallback.contains('bus')) return 'BUS';
  if (fallback.contains('tram')) return 'TRAM';
  if (fallback.contains('metro')) return 'SUBWAY';

  return 'TRANSIT';
}

  
  // Transportation options costs (MAD per km)
  final Map<String, double> costRates = {
    'TAXI': 3.9,
    'BUS': 0.6,
    'TRAM': 0.8,
    'SUBWAY': 0.7,
    'TRANSIT': 0.65, // Default transit rate
  };

  @override
  void initState() {
    super.initState();
    fetchAllTransportationOptions();
  }

  Future<void> fetchAllTransportationOptions() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });
    
    try {
    await Future.wait([
      fetchTransitRoutes(),
      fetchDrivingDirections(),
    ]);
      // If no routes found, calculate walking directions
      if (routes.isEmpty) {
        await fetchWalkingDirections();
      }
      classifyRoutes();

    } catch (e) {
    if (!mounted) return;
      setState(() {
        errorMessage = 'Failed to fetch transportation options: $e';
        isLoading = false;
      });
    }
  }
  String getRouteSignature(Map<String, dynamic> route) {
  final steps = route['legs'][0]['steps'];
  final transitLines = steps.where((step) => step['travel_mode'] == 'TRANSIT').map((step) {
    return step['transit_details']['line']['short_name'] ?? step['transit_details']['line']['name'];
  }).join('-');
  return transitLines;
}


  Future<void> fetchTransitRoutes() async {
    final origin = '${widget.startPoint.latitude},${widget.startPoint.longitude}';
    final destination = '${widget.destinationPoint.latitude},${widget.destinationPoint.longitude}';

    final url =
        'https://maps.googleapis.com/maps/api/directions/json?origin=$origin&destination=$destination&mode=transit&alternatives=true&key=$googleApiKey';

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['status'] == 'OK') {
          setState(() {
            routes = data['routes'];
            final seenSignatures = <String>{};
            routes = routes.where((route) {
            final signature = getRouteSignature(route);
            if (seenSignatures.contains(signature)) return false;
            seenSignatures.add(signature);
            return true;
             }).toList();

            isLoading = false;
          });
        } else if (data['status'] == 'ZERO_RESULTS') {
          // No transit routes available
          setState(() {
            routes = [];
            isLoading = false;
          });
        } else {
          setState(() {
            errorMessage = 'API error: ${data["status"]}';
            isLoading = false;
          });
        }
      } else {
        setState(() {
          errorMessage = 'Failed to fetch routes: ${response.statusCode}';
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Error: $e';
        isLoading = false;
      });
    }
  }

  Future<void> fetchWalkingDirections() async {
    final origin = '${widget.startPoint.latitude},${widget.startPoint.longitude}';
    final destination = '${widget.destinationPoint.latitude},${widget.destinationPoint.longitude}';

    final url =
        'https://maps.googleapis.com/maps/api/directions/json?origin=$origin&destination=$destination&mode=walking&key=$googleApiKey';

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['status'] == 'OK') {
          setState(() {
            routes = data['routes'];
            isLoading = false;
          });
        } else {
          setState(() {
            errorMessage = 'Walking directions error: ${data["status"]}';
            isLoading = false;
          });
        }
      } else {
        setState(() {
          errorMessage = 'Failed to fetch walking directions';
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Walking directions error: $e';
        isLoading = false;
      });
    }
  }
  Future<void> fetchDrivingDirections() async {
  final origin = '${widget.startPoint.latitude},${widget.startPoint.longitude}';
  final destination = '${widget.destinationPoint.latitude},${widget.destinationPoint.longitude}';

  final url =
      'https://maps.googleapis.com/maps/api/directions/json?origin=$origin&destination=$destination&mode=driving&key=$googleApiKey';

  try {
    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      final data = json.decode(response.body);

      if (data['status'] == 'OK' && data['routes'].isNotEmpty) {
        setState(() {
          drivingRoute = data['routes'][0]; // Store only the best driving route
        });
      } else {
        setState(() {
          drivingRoute = null;
        });
        print('Driving directions error: ${data['status']}');
      }
    } else {
      setState(() {
        drivingRoute = null;
      });
      print('Failed to fetch driving directions: ${response.statusCode}');
    }
  } catch (e) {
    setState(() {
      drivingRoute = null;
    });
    print('Driving directions error: $e');
  }
}


  // Calculate price based on distance and mode of transport
  double calculatePrice(String mode, double distanceInMeters) {
  final distanceInKm = distanceInMeters / 1000;

  switch (mode.toLowerCase()) {
    case 'bus':
      return 5.0;
    case 'tram':
      return 6.0;
    default:
      return distanceInKm * 3.9;
  }
}


  // Get icon based on transportation mode
  IconData getTransportIcon(String type) {
    switch (type.toUpperCase()) {
      case 'BUS':
        return Icons.directions_bus;
      case 'TRAM':
        return Icons.tram;
      case 'SUBWAY':
        return Icons.subway;
      case 'TAXI':
        return Icons.local_taxi;
      case 'WALKING':
        return Icons.directions_walk;
      default:
        return Icons.directions_transit;
    }
  }

  // Get color based on transportation mode
  Color getTransportColor(String type) {
    switch (type.toUpperCase()) {
      case 'BUS':
        return Colors.blue;
      case 'TRAM':
        return Colors.orange;
      case 'SUBWAY':
        return Colors.purple;
      case 'TAXI':
        return Colors.amber;
      case 'WALKING':
        return lightGreen;
      default:
        return primaryGreen;
    }
  }

  // Build the taxi option card
  Widget buildTaxiCard(dynamic route, int routeIndex) {
    final leg = route['legs'][0];
    final duration = leg['duration']['text'];
    final distance = leg['distance']['text'];
    final distanceValue = leg['distance']['value']; // in meters

    final taxiPrice = calculatePrice('TAXI', double.parse(distanceValue.toString()));

    return Card(
      elevation: 4,
      margin: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: darkGreen, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.local_taxi, color: Colors.amber, size: 28),
                SizedBox(width: 12),
                Text('Taxi Option', 
                  style: TextStyle(
                    fontSize: 18, 
                    fontWeight: FontWeight.bold,
                    color: darkGreen
                  )
                ),
              ],
            ),
            Divider(color: lightGreen),
            SizedBox(height: 8),
            buildInfoRow(Icons.access_time, 'Duration', duration),
            SizedBox(height: 4),
            buildInfoRow(Icons.straighten, 'Distance', distance),
            SizedBox(height: 4),
            buildInfoRow(Icons.monetization_on, 'Estimated Price', 'MAD ${taxiPrice.toStringAsFixed(1)}'),
           
          ],
          
        
           
        ),
      ),
    );
  }

  // Card for walking-only routes
  Widget buildWalkingCard(dynamic leg) {
    final distance = leg['distance']['text'];
    final duration = leg['duration']['text'];

    return Card(
      
      elevation: 4,
      margin: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: darkGreen, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.directions_walk, color: lightGreen, size: 28),
                SizedBox(width: 12),
                Text('Walking', 
                  style: TextStyle(
                    fontSize: 18, 
                    fontWeight: FontWeight.bold,
                    color: darkGreen
                  )
                ),
              ],
            ),
            Divider(color: lightGreen),
            SizedBox(height: 8),
            buildInfoRow(Icons.straighten, 'Distance', distance),
            SizedBox(height: 4),
            buildInfoRow(Icons.access_time, 'Estimated time', duration),
            
          ],
        ),
      ),
    );
  }

  // Build cards for transit steps
  Widget buildTransitStepCard(Map<String, dynamic> step) {
    final transit = step['transit_details'];
    final line = transit['line'];
    final vehicleType = extractVehicleType(line);

    final lineName = line['short_name'] ?? line['name'] ?? 'Line';
    final departureStop = transit['departure_stop']?['name'] ?? 'Unknown';
    final arrivalStop = transit['arrival_stop']?['name'] ?? 'Unknown';
    final departureTime = transit['departure_time']?['text'] ?? 'N/A';
    final arrivalTime = transit['arrival_time']?['text'] ?? 'N/A';
    
    final distance = step['distance']?['value'] ?? 0;
    final price = calculatePrice(vehicleType, double.parse(distance.toString()));

    final icon = getTransportIcon(vehicleType);
    final color = getTransportColor(vehicleType);

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: darkGreen, width: 1),
      ),
      elevation: 3,
      margin: EdgeInsets.symmetric(vertical: 6, horizontal: 16),
    
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 24),
                SizedBox(width: 8),
                Text('$vehicleType • Line $lineName', 
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: darkGreen
                  )
                ),
              ],
            ),
            Divider(color: lightGreen),
            buildInfoRow(Icons.departure_board, 'Departure', '$departureStop at $departureTime'),
            SizedBox(height: 4),
            buildInfoRow(Icons.announcement, 'Arrival', '$arrivalStop at $arrivalTime'),
            if (distance > 0) ...[
              SizedBox(height: 4),
              buildInfoRow(Icons.monetization_on, 'Est. Price', 'MAD ${price.toStringAsFixed(1)}'),
            ],
          ],
        ),
      ),
    );
  }

 
  Widget buildRouteBadge(String label, IconData icon, Color color) {
  return Container(
    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: color.withOpacity(0.2),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: color, width: 1),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ],
    ),
  );
}

   

  // Helper widget for showing info with icon
  Widget buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey[700]),
        SizedBox(width: 8),
        Text(
          '$label: ',
          style: TextStyle(fontWeight: FontWeight.w500),
        ),
        Expanded(
          child: Text(
            value,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
  

  // Main route card with taxi option and transit options
 Widget buildRouteCard(dynamic route, int routeIndex) {
  final leg = route['legs'][0];
  final duration = leg['duration']['text'];
  final distance = leg['distance']['text'];
  final distanceValue = leg['distance']['value']; // in meters

  final List<Map<String, dynamic>> transitSteps = [];
  final List<Map<String, dynamic>> walkingSteps = [];

  final Set<String> seenLines = {};

  for (final step in leg['steps']) {
    if (step['travel_mode'] == 'TRANSIT' && step['transit_details'] != null) {
      final lineName = step['transit_details']['line']['short_name'] ?? step['transit_details']['line']['name'];
      if (!seenLines.contains(lineName)) {
        seenLines.add(lineName);
        transitSteps.add(step);
      }
    } else if (step['travel_mode'] == 'WALKING') {
      walkingSteps.add(step);
    }
  }

  // Determine if this route is one of our classified routes
  bool isCheapest = cheapestRoute != null && cheapestRoute == route;
  bool isFastest = fastestRoute != null && fastestRoute == route;
  bool isMostComfortable = mostComfortableRoute != null && mostComfortableRoute == route;

  return InkWell(
  onTap: () async {
    // Parse the selected route
    final List<NavigationStep> steps = DirectionsParser.parseDirectionsResponse(route);

    // Provide a destination name (e.g., from route summary or your own label)
    final String destinationName = route['legs'][0]['end_address'] ?? 'Destination';
    final currentPosition = await Geolocator.getCurrentPosition();

  // Compare to selected start point
  double distance = Geolocator.distanceBetween(
    currentPosition.latitude,
    currentPosition.longitude,
    widget.startPoint.latitude,
    widget.startPoint.longitude,
  );

  if (distance > 2000) { // threshold in meters (you can change it)
    // Show alert
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text("Incorrect Starting Point"),
        content: Text("Make sure your current location matches your selected start point."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("OK"),
          ),
        ],
      ),
    );
    return; // don’t proceed to NavigationScreen
  }

    // Navigate to the NavigationScreen with the parsed steps and destination name
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NavigationScreen(
          navigationSteps: steps,
          destinationName: destinationName,
        ),
      ),
    );
  },
  child: Container(
    margin: EdgeInsets.symmetric(vertical: 8),
    child: Column(
    
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Add badges row if this is a special route
        if (isCheapest || isFastest || isMostComfortable)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
            child: Wrap(
              spacing: 8,
              children: [
                if (isCheapest)
                  buildRouteBadge('Cheapest', Icons.attach_money, Colors.green),
                if (isFastest)
                  buildRouteBadge('Fastest', Icons.speed, Colors.blue),
                if (isMostComfortable)
                  buildRouteBadge('Most Comfortable', Icons.airline_seat_recline_extra, Colors.orange),
              ],
            ),
          ),
        if (transitSteps.isEmpty)
          buildWalkingCard(leg)
        else
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ...transitSteps.map((step) => buildTransitStepCard(step)).toList(),
            ],
          ),
        SizedBox(height: 8),
        Divider(thickness: 1),
      ],
    ),
  )
  );
}


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Transportation Options'),
        iconTheme: IconThemeData(color: Colors.white),
        titleTextStyle: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
        backgroundColor: primaryGreen,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              darkGreen.withOpacity(0.05),
              Colors.white,
            ],
          ),
        ),
        child: isLoading
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(primaryGreen),
                    ),
                    SizedBox(height: 16),
                    Text('Finding the best options for you...',
                        style: TextStyle(color: darkGreen)),
                  ],
                ),
              )
            : errorMessage != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.error_outline, size: 48, color: Colors.red),
                          SizedBox(height: 16),
                          Text(
                            errorMessage!,
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 16),
                          ),
                          SizedBox(height: 24),
                          ElevatedButton(
                            onPressed: fetchAllTransportationOptions,
                            child: Text('Try Again'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryGreen,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : routes.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.no_transfer, size: 48, color: Colors.grey),
                            SizedBox(height: 16),
                            Text('No transportation options found.',
                                style: TextStyle(fontSize: 16)),
                            SizedBox(height: 24),
                            ElevatedButton(
                              onPressed: fetchAllTransportationOptions,
                              child: Text('Try Again'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryGreen,
                              ),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: fetchAllTransportationOptions,
                        color: primaryGreen,
                        child: RefreshIndicator(
  onRefresh: fetchAllTransportationOptions,
  color: primaryGreen,
  child: ListView(
  padding: EdgeInsets.only(bottom: 16),
  children: [
    if (drivingRoute != null) ...[
      buildTaxiCard(drivingRoute, 0),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Divider(thickness: 1),
      ),
    ],
    // First show classified routes
    if (cheapestRoute != null)
      buildRouteCard(cheapestRoute, routes.indexOf(cheapestRoute)),
    if (fastestRoute != null && fastestRoute != cheapestRoute)
      buildRouteCard(fastestRoute, routes.indexOf(fastestRoute)),
    if (mostComfortableRoute != null && 
        mostComfortableRoute != cheapestRoute && 
        mostComfortableRoute != fastestRoute)
      buildRouteCard(mostComfortableRoute, routes.indexOf(mostComfortableRoute)),
      
    // Then show the rest of the routes that aren't one of the special ones
    ...routes.where((route) => 
      route != cheapestRoute && 
      route != fastestRoute && 
      route != mostComfortableRoute
    ).map((route) => buildRouteCard(route, routes.indexOf(route))).toList(),
  ],
),

),

                      ),
      ),
      bottomNavigationBar: Container(
        height: 50,
        color: primaryGreen,
        child: Center(
          child: Text(
            'Find sustainable transportation options',
            style: TextStyle(
              color: Colors.white, 
              fontWeight: FontWeight.bold
            ),
          ),
        ),
      ),
    );
  }
}