import 'package:flutter_application_1/models/navigation_models.dart';
import 'package:google_polyline_algorithm/google_polyline_algorithm.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class DirectionsParser {
  static List<NavigationStep> parseDirectionsResponse(Map<String, dynamic> route) {
    // Parse route legs and steps
    final List<NavigationStep> steps = [];

    final legs = route['legs'] as List;
    for (var leg in legs) {
      for (var step in leg['steps']) {
        final travelMode = step['travel_mode'];
        final instruction = step['html_instructions'] ?? '';
        final distance = step['distance']['value']?.toDouble() ?? 0;
        final duration = step['duration']['value'] ?? 0;

        final startLocation = LatLng(
          step['start_location']['lat'],
          step['start_location']['lng'],
        );
        final endLocation = LatLng(
          step['end_location']['lat'],
          step['end_location']['lng'],
        );

        final polyline = decodePolyline(step['polyline']['points']);
        final polylineLatLng = polyline
            .map<LatLng>((point) => LatLng(point[0] as double, point[1] as double))
            .toList();

        final transitDetails = step['transit_details'];

        steps.add(NavigationStep(
          instruction: instruction,
          travelMode: travelMode,
          transitLine: transitDetails?['line']?['short_name'],
          vehicleType: transitDetails?['line']?['vehicle']?['type'],
          distanceMeters: distance,
          polylinePoints: polylineLatLng,
          startLocation: startLocation,
          endLocation: endLocation,
          departureTime: transitDetails?['departure_time']?['text'],
          arrivalTime: transitDetails?['arrival_time']?['text'],
          durationSeconds: duration,
        ));
        
      }
    }

    return steps;
  }
}
