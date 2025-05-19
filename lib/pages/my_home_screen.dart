import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
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
  final TextEditingController _searchController = TextEditingController();
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
    });

    final GoogleMapController controller = await _controller.future;
    controller.animateCamera(CameraUpdate.newLatLng(
      LatLng(locationData.latitude!, locationData.longitude!),
    ));
  }
double _currentZoom = 15.0; // Default zoom level

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

 Future<void> _searchAndNavigate(String address) async {
  if (address.trim().isEmpty) {
    // If the search is empty, clear everything and exit
    setState(() {
      _markers.clear();
      _predictions = [];
    });
    return;
  }

  try {
    List<geo.Location> locations = await geo.locationFromAddress(address);
    if (locations.isNotEmpty) {
      final target = LatLng(locations.first.latitude, locations.first.longitude);

      final GoogleMapController controller = await _controller.future;
      controller.animateCamera(CameraUpdate.newLatLngZoom(target, 15));

      setState(() {
        _markers.clear();
        _markers.add(
          Marker(
            markerId: MarkerId("searched_location"),
            position: target,
            infoWindow: InfoWindow(title: address),
          ),
        );
      });
    }
  } catch (e) {
    print("Search error: $e");
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Could not find location')),
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
                  myLocationButtonEnabled: false,
                  markers: _markers,
                  mapType: MapType.normal,
                  onMapCreated: (GoogleMapController controller) {
                    _controller.complete(controller);
                  },
                ),
                // Search input
                Positioned(
                  top: 20,
                  left: 15,
                  right: 15,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(color: Colors.black26, blurRadius: 5),
                      ],
                    ),
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search destination...',
                        suffixIcon: IconButton(
                          icon: Icon(Icons.search),
                          onPressed: () => _searchAndNavigate(_searchController.text),
                        ),
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
                      onSubmitted: (value) => _searchAndNavigate(value),
                    ),
                  ),
                ),
                // Suggestions list (only shown if not empty)
                if (_predictions.isNotEmpty)
                  Positioned(
                    top: 80,
                    left: 15,
                    right: 15,
                    child: Container(
                      color: Colors.white,
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

                              try {
                                final details = await _googlePlace.details.get(prediction.placeId!);
                                if (details != null && details.result != null) {
                                  final location = details.result!.geometry?.location;
                                  if (location != null) {
                                    final latLng = LatLng(location.lat!, location.lng!);
                                    final controller = await _controller.future;
                                    controller.animateCamera(CameraUpdate.newLatLngZoom(latLng, 15));

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
                                }
                              } catch (e) {
                                print("Place details error: $e");
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text("Failed to get place details.")),
                                );
                              }
                            },
                          );
                        },
                      ),
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
              ],
            ),
    );
  }
}