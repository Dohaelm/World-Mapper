import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
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
  
  // The green theme colors
  final Color primaryGreen = Color(0xFF4CAF50);
  final Color lightGreen = Color(0xFFAED581);
  final Color darkGreen = Color(0xFF2E7D32);
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
      // Fetch transit routes
      await fetchTransitRoutes();
      
      // If no routes found, calculate walking directions
      if (routes.isEmpty) {
        await fetchWalkingDirections();
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Failed to fetch transportation options: $e';
        isLoading = false;
      });
    }
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
            Text('Recommended for short distances',
                style: TextStyle(
                  fontStyle: FontStyle.italic,
                  color: Colors.grey[700],
                )
            ),
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
      elevation: 3,
      margin: EdgeInsets.symmetric(vertical: 6, horizontal: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
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

  return Container(
    margin: EdgeInsets.symmetric(vertical: 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
  );
}



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Transportation Options'),
        backgroundColor: darkGreen,
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
    if (routes.isNotEmpty) buildTaxiCard(routes.first, 0),
    ...routes.asMap().entries.map((entry) {
      final index = entry.key;
      final route = entry.value;
      return buildRouteCard(route, index);
    }).toList(),
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