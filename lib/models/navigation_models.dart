import 'package:google_maps_flutter/google_maps_flutter.dart';

class NavigationStep {
  final String instruction;
  final String travelMode; // WALKING, TRANSIT
  final String? transitLine; // Bus line, Metro line, etc.
  final String? vehicleType; // BUS, SUBWAY, TRAM, etc.
  final double distanceMeters;
  final int durationSeconds;
  final LatLng startLocation;
  final LatLng endLocation;
  final List<LatLng> polylinePoints;
  final String? departureTime;
  final String? arrivalTime;
  final bool isCompleted;

  NavigationStep({
    required this.instruction,
    required this.travelMode,
    this.transitLine,
    this.vehicleType,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.startLocation,
    required this.endLocation,
    required this.polylinePoints,
    this.departureTime,
    this.arrivalTime,
    this.isCompleted = false,
  });

  NavigationStep copyWith({
    String? instruction,
    String? travelMode,
    String? transitLine,
    String? vehicleType,
    double? distanceMeters,
    int? durationSeconds,
    LatLng? startLocation,
    LatLng? endLocation,
    List<LatLng>? polylinePoints,
    String? departureTime,
    String? arrivalTime,
    bool? isCompleted,
  }) {
    return NavigationStep(
      instruction: instruction ?? this.instruction,
      travelMode: travelMode ?? this.travelMode,
      transitLine: transitLine ?? this.transitLine,
      vehicleType: vehicleType ?? this.vehicleType,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      startLocation: startLocation ?? this.startLocation,
      endLocation: endLocation ?? this.endLocation,
      polylinePoints: polylinePoints ?? this.polylinePoints,
      departureTime: departureTime ?? this.departureTime,
      arrivalTime: arrivalTime ?? this.arrivalTime,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }
}

class NavigationState {
  final List<NavigationStep> steps;
  final int currentStepIndex;
  final LatLng? currentLocation;
  final double? currentHeading;
  final bool isNavigationActive;
  final bool hasArrived;
  final double distanceToNextPoint;
  final String? nextInstruction;

  NavigationState({
    required this.steps,
    this.currentStepIndex = 0,
    this.currentLocation,
    this.currentHeading,
    this.isNavigationActive = false,
    this.hasArrived = false,
    this.distanceToNextPoint = 0.0,
    this.nextInstruction,
  });

  NavigationState copyWith({
    List<NavigationStep>? steps,
    int? currentStepIndex,
    LatLng? currentLocation,
    double? currentHeading,
    bool? isNavigationActive,
    bool? hasArrived,
    double? distanceToNextPoint,
    String? nextInstruction,
  }) {
    return NavigationState(
      steps: steps ?? this.steps,
      currentStepIndex: currentStepIndex ?? this.currentStepIndex,
      currentLocation: currentLocation ?? this.currentLocation,
      currentHeading: currentHeading ?? this.currentHeading,
      isNavigationActive: isNavigationActive ?? this.isNavigationActive,
      hasArrived: hasArrived ?? this.hasArrived,
      distanceToNextPoint: distanceToNextPoint ?? this.distanceToNextPoint,
      nextInstruction: nextInstruction ?? this.nextInstruction,
    );
  }

  NavigationStep? get currentStep {
    if (currentStepIndex < steps.length) {
      return steps[currentStepIndex];
    }
    return null;
  }

  NavigationStep? get nextStep {
    if (currentStepIndex + 1 < steps.length) {
      return steps[currentStepIndex + 1];
    }
    return null;
  }

  double get progressPercentage {
    if (steps.isEmpty) return 0.0;
    return (currentStepIndex / steps.length) * 100;
  }
}