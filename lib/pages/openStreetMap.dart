import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_application_1/pages/location.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_location_marker/flutter_map_location_marker.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:location/location.dart';
import '../widgets/map_control_panel.dart';
import 'package:http/http.dart' as http;

class OpenstreetmapScreen extends StatefulWidget {
  const OpenstreetmapScreen({super.key});

  @override
  State<OpenstreetmapScreen> createState() => _OpenstreetmapScreenState();
}

class _OpenstreetmapScreenState extends State<OpenstreetmapScreen> {
  final MapController _mapController = MapController();
  final Location _location = Location();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _startLocationController = TextEditingController();
  bool _showTransitButton = false;


  bool isLoading = true;
  double _currentZoom = 12.0;


  LatLng? _currentLocation;
  LatLng? _destination;
  List<LatLng> _route = [];
  List<dynamic> _suggestions = [];

  @override
  void initState() {
    super.initState();
    _initializeLocation();
  }

  Future<void> _initializeLocation() async {
    if (!await _checktheRequestPermissions()) return;
    _location.onLocationChanged.listen((LocationData locationData) {
      if (locationData.latitude != null && locationData.longitude != null) {
        setState(() {
          _currentLocation =
              LatLng(locationData.latitude!, locationData.longitude!);
          isLoading = false;
        });
      }
    });
  }

  Future<void> fetchCoordinatesPoint(String location) async {
    final url = Uri.parse(
        "https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(location)}&format=json&limit=1");

    final response = await http.get(url);
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data.isNotEmpty) {
        final lat = double.parse(data[0]['lat']);
        final lon = double.parse(data[0]['lon']);
        setState(() {
          _destination = LatLng(lat, lon);
        });
        await _fetchRoute();
      } else {
        errorMessage('Location not found. Please try another search.');
      }
    } else {
      errorMessage('Failed to fetch location. Try again later.');
    }
  }

  Future<void> fetchSuggestions(String query) async {
    if (query.isEmpty) {
      setState(() {
        _suggestions = [];
      });
      return;
    }

    final url = Uri.parse(
        'https://photon.komoot.io/api/?q=${Uri.encodeComponent(query)}&limit=5');
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      setState(() {
        _suggestions = data['features'];
      });

      // Calculate distances for each suggestion
      if (_currentLocation != null) {
        for (var suggestion in _suggestions) {
          final lat = suggestion['geometry']['coordinates'][1];
          final lon = suggestion['geometry']['coordinates'][0];
          final distance = Geolocator.distanceBetween(
            _currentLocation!.latitude,
            _currentLocation!.longitude,
            lat,
            lon,
          ) / 1000; // Convert meters to kilometers
          suggestion['distance'] = distance;
        }
        
        // Sort suggestions by proximity
        _suggestions.sort((a, b) =>
            a['distance'].compareTo(b['distance']));
      }
    } else {
      setState(() {
        _suggestions = [];
      });
    }
  }

  Future<void> _fetchRoute() async {
    if (_currentLocation == null || _destination == null) return;
    final url = Uri.parse(
        'http://router.project-osrm.org/route/v1/driving/'
        '${_currentLocation!.longitude},${_currentLocation!.latitude};'
        '${_destination!.longitude},${_destination!.latitude}?overview=full&geometries=polyline');
    final response = await http.get(url);
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final geometry = data['routes'][0]['geometry'];
      _decodePolyline(geometry);
    } else {
      errorMessage('Failed to fetch route. Try again later.');
    }
  }

  void _decodePolyline(String encodedPolyline) {
    PolylinePoints polylinePoints = PolylinePoints();
    List<PointLatLng> decodedPoints =
        polylinePoints.decodePolyline(encodedPolyline);
    setState(() {
      _route =
          decodedPoints.map((point) => LatLng(point.latitude, point.longitude)).toList();
    });
  }

  Future<bool> _checktheRequestPermissions() async {
    bool serviceEnabled = await _location.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await _location.requestService();
      if (!serviceEnabled) return false;
    }

    PermissionStatus permissionGranted = await _location.hasPermission();
    if (permissionGranted == PermissionStatus.denied) {
      permissionGranted = await _location.requestPermission();
      if (permissionGranted != PermissionStatus.granted) {
        return false;
      }
    }
    return true;
  }
  


  Future<void> _userCurrentLocation() async {
    if (_currentLocation != null) {
      _mapController.move(_currentLocation!, 15);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Current location not available")),
      );
    }
  }

  void errorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          isLoading
              ? const Center(child: CircularProgressIndicator())
              : FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _currentLocation ?? const LatLng(0, 0),
                    initialZoom: _currentZoom ,
                    minZoom: 0,
                    maxZoom: 18,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    ),
                    CurrentLocationLayer(
                      style: LocationMarkerStyle(
                        marker: DefaultLocationMarker(
                          child: const Icon(
                            Icons.location_pin,
                            color: Colors.white,
                          ),
                        ),
                        markerSize: const Size(40, 40),
                        markerDirection: MarkerDirection.heading,
                      ),
                      alignPositionOnUpdate: AlignOnUpdate.never,
                      alignDirectionOnUpdate: AlignOnUpdate.never,
                    ),
                    if (_destination != null)
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: _destination!,
                            width: 50,
                            height: 50,
                            child: const Icon(
                              Icons.location_pin,
                              size: 40,
                              color: Colors.red,
                            ),
                          )
                        ],
                      ),
                    if (_currentLocation != null &&
                        _destination != null &&
                        _route.isNotEmpty)
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: _route,
                            strokeWidth: 5,
                            color: Colors.red,
                          )
                        ],
                      ),
                  ],
                ),
          Positioned(
            top: 0,
            right: 0,
            left: 0,
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _locationController,
                          onChanged: fetchSuggestions,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Colors.white,
                            hintText: 'Enter a location',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(30),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding:
                                const EdgeInsets.symmetric(horizontal: 20),
                          ),
                        ),
                      ),
                      IconButton(
                        style: IconButton.styleFrom(
                            backgroundColor: Colors.white),
                       onPressed: () {
  final location = _locationController.text.trim();
  if (location.isEmpty) {
    // Reset everything
    setState(() {
      _destination = null;
      _route = [];
      _suggestions = [];
      _showTransitButton = false;
    });

    if (_currentLocation != null) {
      _mapController.move(_currentLocation!, _currentZoom);
    }

    return;
  }

  // Otherwise, search normally
  fetchCoordinatesPoint(location);
  setState(() {
    _suggestions = [];
    _showTransitButton = true;
  });
},
                        icon: const Icon(Icons.search),
                      ),
                      if (_showTransitButton)
  ElevatedButton(
    onPressed: () {
      // Call your function to show transit options here
      Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => LocationPage(selectedLocation: _destination)), // Replace with your actual widget name
    );
    },
    child: Text("Show Transit Options"),
  ),
                    ],
                  ),
                  if (_suggestions.isNotEmpty)
                    Card(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: _suggestions.length,
                        itemBuilder: (context, index) {
                          final suggestion = _suggestions[index];
                          final name = suggestion['properties']['name'];
                          final city = suggestion['properties']['city'] ?? '';
                          final country =
                              suggestion['properties']['country'] ?? '';
                          final distance = suggestion['distance'] ?? 0;
                          return ListTile(
                            title: Text('$name, $city, $country'),
                            subtitle: Text('${distance.toStringAsFixed(2)} km away'),
                            onTap: () {
                              final coords =
                                  suggestion['geometry']['coordinates'];
                              setState(() {
                                _locationController.text = '$name, $city';
                                _suggestions = [];
                                _destination = LatLng(coords[1], coords[0]);
                              });
                              _fetchRoute();
                            },
                          );
                        },
                      ),
                    ),
                    
                ],
              ),
            ),
          ),
          Positioned(
  bottom: 16,
  right: 16,
  child: MapControlPanel(
    onEditToggle: () {},
    isEditMode: false,
    onZoomIn: () {
      final newZoom = _currentZoom + 1;
      setState(() {
        _currentZoom = newZoom.clamp(3.0, 19.0);
      });
      _mapController.move(_mapController.camera.center, _currentZoom);
    },
    onZoomOut: () {
      final newZoom = _currentZoom - 1;
      setState(() {
        _currentZoom = newZoom.clamp(3.0, 19.0);
      });
      _mapController.move(_mapController.camera.center, _currentZoom);
    },
    onMyLocation: () {
     _userCurrentLocation();
    },
  ),
),


        ],
      ),
      
      
      // floatingActionButton: FloatingActionButton(
      //   elevation: 0,
      //   onPressed: _userCurrentLocation,
      //   backgroundColor: Colors.green,
      //   child: const Icon(
      //     Icons.my_location,
      //     size: 30,
      //     color: Colors.white,
      //   ),
      // ),
    );
  }
}
