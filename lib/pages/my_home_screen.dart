import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_application_1/pages/transportations.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:location/location.dart' as loc;
import 'package:geocoding/geocoding.dart' as geo;
import 'package:google_place/google_place.dart';
import 'package:flutter_application_1/widgets/map_control_panel.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class MyHomeScreen extends StatefulWidget {
  const MyHomeScreen({super.key});

  @override
  State<MyHomeScreen> createState() => _MyHomeScreenState();
}

class _MyHomeScreenState extends State<MyHomeScreen> {
  final Completer<GoogleMapController> _controller = Completer();
  bool _showTransportOptions = false;

  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _startPointController = TextEditingController();
  List<AutocompletePrediction> _startPredictions = [];
  Set<Polyline> _polylines = {};
  List<LatLng> _polylineCoordinates = [];
  LatLng? startLatLng;
  LatLng? destLatLng;
  
  final Set<Marker> _markers = {};
  late GooglePlace _googlePlace;
  List<AutocompletePrediction> _predictions = [];
  final apiKey = dotenv.env['GOOGLE_API_KEY'] ?? '';


  final loc.Location _location = loc.Location();
  loc.LocationData? _currentLocation;

  @override
  void initState() {
    super.initState();
    _getUserLocation();
    _googlePlace = GooglePlace(apiKey);
  }

  Future<void> _getUserLocation() async {
    bool serviceEnabled;
    loc.PermissionStatus permissionGranted;

    serviceEnabled = await _location.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await _location.requestService();
      if (!serviceEnabled) return;
    }

    permissionGranted = await _location.hasPermission();
    if (permissionGranted == loc.PermissionStatus.denied) {
      permissionGranted = await _location.requestPermission();
      if (permissionGranted != loc.PermissionStatus.granted) return;
    }

    final loc.LocationData locationData = await _location.getLocation();

    setState(() {
      _currentLocation = locationData;
      
      _startPointController.text = "Current Location";
    });

    final GoogleMapController controller = await _controller.future;
    controller.animateCamera(CameraUpdate.newLatLng(
      LatLng(locationData.latitude!, locationData.longitude!),
    ));
  }
double _currentZoom = 15.0; // Default zoom level
Future<void> _drawPolyline(LatLng start, LatLng end) async {
  
  final url = Uri.parse(
    'https://maps.googleapis.com/maps/api/directions/json'
    '?origin=${start.latitude},${start.longitude}'
    '&destination=${end.latitude},${end.longitude}'
    '&key=$apiKey',
  );

  final response = await http.get(url);
  if (response.statusCode == 200) {
    final data = jsonDecode(response.body);
    final points = data['routes'][0]['overview_polyline']['points'];
    _polylineCoordinates = _decodePolyline(points);

    setState(() {
      _polylines.clear();
      _polylines.add(
        Polyline(
          polylineId: PolylineId('route'),
          width: 5,
          color: Colors.blue,
          points: _polylineCoordinates,
        ),
      );
    });
  } else {
    print("Failed to get directions: ${response.body}");
  }
}
List<LatLng> _decodePolyline(String encoded) {
  List<LatLng> polyline = [];
  int index = 0, len = encoded.length;
  int lat = 0, lng = 0;

  while (index < len) {
    int b, shift = 0, result = 0;
    do {
      b = encoded.codeUnitAt(index++) - 63;
      result |= (b & 0x1F) << shift;
      shift += 5;
    } while (b >= 0x20);
    int dlat = ((result & 1) != 0) ? ~(result >> 1) : (result >> 1);
    lat += dlat;

    shift = 0;
    result = 0;
    do {
      b = encoded.codeUnitAt(index++) - 63;
      result |= (b & 0x1F) << shift;
      shift += 5;
    } while (b >= 0x20);
    int dlng = ((result & 1) != 0) ? ~(result >> 1) : (result >> 1);
    lng += dlng;

    polyline.add(LatLng(lat / 1e5, lng / 1e5));
  }
  return polyline;
}



Future<void> _zoomIn() async {
  final GoogleMapController controller = await _controller.future;
  _currentZoom += 1;
  controller.animateCamera(CameraUpdate.zoomTo(_currentZoom));
}

Future<void> _zoomOut() async {
  final GoogleMapController controller = await _controller.future;
  _currentZoom -= 1;
  controller.animateCamera(CameraUpdate.zoomTo(_currentZoom));
}


 void _searchAndNavigateBoth(String start, String destination) async {
  if (destination.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Please enter a destination")),
    );
    return;
  }

  try {
    

    if (start.isEmpty || start == "Current Location") {
      // Use current location as start point
      startLatLng = LatLng(_currentLocation!.latitude!, _currentLocation!.longitude!);
      if (startLatLng == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Current location not available")),
        );
        return;
      }
    } else {
      // Get start location details from Google Places
      var startResult = await _googlePlace.autocomplete.get(start);
      var startPlaceId = startResult?.predictions?.first.placeId;

      if (startPlaceId != null) {
        var startDetails = await _googlePlace.details.get(startPlaceId);
        if (startDetails?.result?.geometry?.location != null) {
          var loc = startDetails!.result!.geometry!.location!;
          startLatLng = LatLng(loc.lat!, loc.lng!);
        }
      }

      if (startLatLng == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Could not find start location details.")),
        );
        return;
      }
     
    }

    // Get destination location details
    var destResult = await _googlePlace.autocomplete.get(destination);
    var destPlaceId = destResult?.predictions?.first.placeId;

    if (destPlaceId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Could not find destination location.")),
      );
      return;
    }

    var destDetails = await _googlePlace.details.get(destPlaceId);
    if (destDetails?.result?.geometry?.location == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Could not find destination location details.")),
      );
      return;
    }

    final destLoc = destDetails!.result!.geometry!.location!;
     destLatLng = LatLng(destLoc.lat!, destLoc.lng!);

    // Animate camera to show route bounds
    final controller = await _controller.future;
    controller.animateCamera(CameraUpdate.newLatLngBounds(
      LatLngBounds(
        southwest: LatLng(
          (startLatLng != null && destLatLng != null)
              ? (startLatLng!.latitude < destLatLng!.latitude ? startLatLng!.latitude : destLatLng!.latitude)
              : 0.0,
          (startLatLng != null && destLatLng != null)
              ? (startLatLng!.longitude < destLatLng!.longitude ? startLatLng!.longitude : destLatLng!.longitude)
              : 0.0,
        ),
        northeast: LatLng(
          (startLatLng != null && destLatLng != null)
              ? (startLatLng!.latitude > destLatLng!.latitude ? startLatLng!.latitude : destLatLng!.latitude)
              : 0.0,
          (startLatLng != null && destLatLng != null)
              ? (startLatLng!.longitude > destLatLng!.longitude ? startLatLng!.longitude : destLatLng!.longitude)
              : 0.0,
        ),
      ),
      50,
    ));

    // Update markers and state
    setState(() {
      _markers.clear();
      _markers.addAll([
        Marker(
          markerId: MarkerId("start_location"),
          position: startLatLng!,
          infoWindow: InfoWindow(title: start.isEmpty ? "Current Location" : start),
        ),
        Marker(
          markerId: MarkerId("destination_location"),
          position: destLatLng!,
          infoWindow: InfoWindow(title: destination),
        ),
      ]);
      _showTransportOptions = true;
      
    });

    await _drawPolyline(startLatLng!, destLatLng!);


  } catch (e) {
    print("Error searching locations: $e");
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Failed to search locations.")),
    );
  }
}


  Future<void> _goToCurrentLocation() async {
    final loc.LocationData locationData = await _location.getLocation();

    if (locationData.latitude != null && locationData.longitude != null) {
      final GoogleMapController controller = await _controller.future;
      controller.animateCamera(CameraUpdate.newLatLngZoom(
        LatLng(locationData.latitude!, locationData.longitude!),
        15,
      ));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Unable to get current location.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _currentLocation == null
          ? Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: LatLng(
                      _currentLocation!.latitude!,
                      _currentLocation!.longitude!,
                    ),
                    zoom: _currentZoom,
                  ),
                  myLocationEnabled: true,
                   polylines: _polylines,
                  myLocationButtonEnabled: false,
                  markers: _markers,
                  mapType: MapType.normal,
                  onMapCreated: (GoogleMapController controller) {
                    _controller.complete(controller);
                  },
                ),
// Start Point input
// Start Point input
// START: TextField
Positioned(
  top: 20,
  left: 15,
  right: 15,
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      // Start input
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 5)],
        ),
        child: TextField(
          controller: _startPointController,
          decoration: InputDecoration(
            hintText: 'Enter start location...',
            border: InputBorder.none,
          ),
          onChanged: (value) async {
            if (value.isNotEmpty) {
              var result = await _googlePlace.autocomplete.get(value);
              if (result != null && result.predictions != null) {
                setState(() {
                  _startPredictions = result.predictions!;
                });
              }
            } else {
              setState(() {
                _startPredictions = [];
              });
            }
          },
        ),
      ),

      // Start predictions
      if (_startPredictions.isNotEmpty)
        Container(
          color: Colors.white,
          constraints: BoxConstraints(maxHeight: 150),
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _startPredictions.length,
            itemBuilder: (context, index) {
              final prediction = _startPredictions[index];
              return ListTile(
                title: Text(prediction.description ?? ""),
                onTap: () async {
                  FocusScope.of(context).unfocus();
                  setState(() {
                    _startPointController.text = prediction.description ?? "";
                    _startPredictions = [];
                  });
                  final details = await _googlePlace.details.get(prediction.placeId!);
                  final location = details?.result?.geometry?.location;
                  if (location != null) {
                    final latLng = LatLng(location.lat!, location.lng!);
                    final controller = await _controller.future;
                    controller.animateCamera(CameraUpdate.newLatLngZoom(latLng, _currentZoom));
                  }
                },
              );
            },
          ),
        ),

      const SizedBox(height: 10),

      // Destination input
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 5)],
        ),
        child: TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'Enter destination...',
            border: InputBorder.none,
          ),
          onChanged: (value) async {
            if (value.isNotEmpty) {
              var result = await _googlePlace.autocomplete.get(value);
              if (result != null && result.predictions != null) {
                setState(() {
                  _predictions = result.predictions!;
                });
              }
            } else {
              setState(() {
                _predictions = [];
                _markers.clear();
              });
            }
          },
        ),
      ),

      // Destination predictions
      if (_predictions.isNotEmpty)
        Container(
          color: Colors.white,
          constraints: BoxConstraints(maxHeight: 150),
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _predictions.length,
            itemBuilder: (context, index) {
              final prediction = _predictions[index];
              return ListTile(
                title: Text(prediction.description ?? ""),
                onTap: () async {
                  FocusScope.of(context).unfocus();
                  setState(() {
                    _searchController.text = prediction.description ?? "";
                    _predictions = [];
                  });
                  final details = await _googlePlace.details.get(prediction.placeId!);
                  final location = details?.result?.geometry?.location;
                  if (location != null) {
                    final latLng = LatLng(location.lat!, location.lng!);
                    final controller = await _controller.future;
                    controller.animateCamera(CameraUpdate.newLatLngZoom(latLng, _currentZoom));

                    setState(() {
                      _markers.clear();
                      _markers.add(
                        Marker(
                          markerId: MarkerId("selected_location"),
                          position: latLng,
                          infoWindow: InfoWindow(title: prediction.description),
                        ),
                      );
                      

                    });
                  }
                },
              );
            },
          ),
        ),

      const SizedBox(height: 15),

      // Search button
      Row(
  children: [
    // Search Button
    Expanded(
      child: ElevatedButton.icon(
        icon: Icon(Icons.search),
        label: Text('Search'),
        onPressed: () => _searchAndNavigateBoth(
          _startPointController.text,
          _searchController.text,
        ),
      ),
    ),

    SizedBox(width: 10), // Space between buttons

    if (_searchController.text.isNotEmpty )
      
    ElevatedButton.icon(
      icon: Icon(Icons.cancel),
      label: Text('Cancel'),
      style: ElevatedButton.styleFrom(backgroundColor: Colors.white
      ),
      onPressed: () {
        FocusScope.of(context).unfocus(); // Close keyboard
        setState(() {
          _searchController.clear();
          _startPointController.text='Current Location';
          _predictions = [];
          _startPredictions = [];
          _showTransportOptions= false;
          _polylineCoordinates.clear();
          _polylines.clear();
          _markers.clear();
        });
      },
    ),
  ],
)

    ],
  ),
),


                // Button for current location
                Positioned(
                  bottom: 30,
                  right: 15,
                  child: MapControlPanel(
  onZoomIn: _zoomIn,
  onZoomOut: _zoomOut,
  onMyLocation: _goToCurrentLocation, // You may already have this method
),
                ),
                if (_showTransportOptions)
                Positioned(
                  bottom: 90,
                  left: 15,
                  child: ElevatedButton.icon(
                    icon: Icon(Icons.arrow_forward, color: Colors.white),
                    label: Text("Let's Go"),
    style: ElevatedButton.styleFrom(
      backgroundColor: Colors.green,
      foregroundColor: Colors.white,
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      textStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    ),
    onPressed: () {
      Navigator.push(
  context,
  MaterialPageRoute(
    builder: (_) => TransportationOptionsPage(
      startPoint: startLatLng!,
      destinationPoint: destLatLng!,
    ),
  ),
);
    },
  ),
),
  

              ],
            ),
    );
  }
}