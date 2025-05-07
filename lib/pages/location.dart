import 'dart:async';
import 'package:flutter/material.dart';
import 'package:csv/csv.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

class LocationPage extends StatefulWidget {
  final LatLng? selectedLocation;

  const LocationPage({super.key, this.selectedLocation});

  @override
  State<LocationPage> createState() => _LocationPageState();
}

class _LocationPageState extends State<LocationPage> {
  List<Map<String, String>> _nearbyRoutes = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.selectedLocation != null) {
      _handleLocation(widget.selectedLocation!);
    } else {
      setState(() {
        _error = "No location provided.";
      });
    }
  }

  bool _isInTetouan(LatLng location) {
    return location.latitude >= 35.55 &&
        location.latitude <= 35.61 &&
        location.longitude >= -5.41 &&
        location.longitude <= -5.30;
  }

  Future<List<Map<String, String>>> _parseGTFSFile(String filename) async {
    final raw = await rootBundle.loadString('assets/gtfs/$filename');
    final rows = const CsvToListConverter(eol: '\n').convert(raw);
    final headers = rows.first.cast<String>();
    return rows.skip(1).map((row) {
      final map = <String, String>{};
      for (int i = 0; i < headers.length; i++) {
        map[headers[i]] = row[i].toString();
      }
      return map;
    }).toList();
  }

  Future<void> _handleLocation(LatLng location) async {
    if (!_isInTetouan(location)) {
      setState(() {
        _error = "Sorry, the location is not in Tetouan.";
      });
      return;
    }

    final stops = await _parseGTFSFile('stops.txt');
    final stopTimes = await _parseGTFSFile('stop_times.txt');
    final trips = await _parseGTFSFile('trips.txt');
    final routes = await _parseGTFSFile('routes.txt');

    final nearbyStops = stops.where((stop) {
      final lat = double.tryParse(stop['stop_lat'] ?? '') ?? 0;
      final lon = double.tryParse(stop['stop_lon'] ?? '') ?? 0;
      final distance = Geolocator.distanceBetween(
        location.latitude,
        location.longitude,
        lat,
        lon,
      );
      return distance < 1000; // within 1km
    }).toList();

    final stopIds = nearbyStops.map((stop) => stop['stop_id']).toSet();
    final nearbyTripIds = stopTimes
        .where((stopTime) => stopIds.contains(stopTime['stop_id']))
        .map((e) => e['trip_id'])
        .toSet();

    final nearbyRoutes = trips
        .where((trip) => nearbyTripIds.contains(trip['trip_id']))
        .map((trip) => trip['route_id'])
        .toSet();

    final nearbyRouteDetails = routes
        .where((route) => nearbyRoutes.contains(route['route_id']))
        .toList();

    setState(() {
      _nearbyRoutes = nearbyRouteDetails;
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Transit Options"),
      ),
      body: _error != null
          ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
          : _nearbyRoutes.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : ListView.builder(
                  itemCount: _nearbyRoutes.length,
                  itemBuilder: (context, index) {
                    final route = _nearbyRoutes[index];
                    return ListTile(
                      title: Text("Route: ${route['route_short_name'] ?? 'N/A'}"),
                      subtitle: Text("Description: ${route['route_long_name'] ?? 'N/A'}"),
                    );
                  },
                ),
    );
  }
}
