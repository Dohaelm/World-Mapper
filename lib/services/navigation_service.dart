import 'dart:async';
import 'dart:math' as math;
import 'package:flutter_application_1/models/navigation_models.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class NavigationService {
  static const double ARRIVAL_THRESHOLD_METERS = 50.0; // 50 meters for arrival detection
  static const double WALKING_ARRIVAL_THRESHOLD = 30.0; // Tighter threshold for walking
  static const double TRANSIT_ARRIVAL_THRESHOLD = 100.0; // Looser for transit stops

  StreamSubscription<Position>? _positionSubscription;
  final StreamController<NavigationState> _navigationController = 
      StreamController<NavigationState>.broadcast();

  NavigationState _currentState = NavigationState(steps: []);

  Stream<NavigationState> get navigationStream => _navigationController.stream;
  NavigationState get currentState => _currentState;

  // Start navigation with the provided steps
  Future<void> startNavigation(List<NavigationStep> steps) async {
    try {
      // Request location permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Location permissions are denied');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception('Location permissions are permanently denied');
      }

      // Get current location
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      _currentState = NavigationState(
        steps: steps,
        currentStepIndex: 0,
        currentLocation: LatLng(position.latitude, position.longitude),
        currentHeading: position.heading,
        isNavigationActive: true,
        distanceToNextPoint: _calculateDistanceToCurrentDestination(
          LatLng(position.latitude, position.longitude),
          steps.isNotEmpty ? steps[0].endLocation : LatLng(0, 0),
        ),
      );

      _navigationController.add(_currentState);

      // Start listening to location updates
      _startLocationTracking();
    } catch (e) {
      print('Error starting navigation: $e');
      rethrow;
    }
  }

  void _startLocationTracking() {
    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5, // Update every 5 meters
    );

    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen(
      _onLocationUpdate,
      onError: (error) {
        print('Location tracking error: $error');
      },
    );
  }

  void _onLocationUpdate(Position position) {
    if (!_currentState.isNavigationActive || _currentState.hasArrived) {
      return;
    }

    final currentLocation = LatLng(position.latitude, position.longitude);
    final currentStep = _currentState.currentStep;

    if (currentStep == null) {
      _completeNavigation();
      return;
    }

    // Calculate distance to current step's destination
    final distanceToDestination = _calculateDistanceToCurrentDestination(
      currentLocation,
      currentStep.endLocation,
    );

    // Determine arrival threshold based on travel mode
    final arrivalThreshold = currentStep.travelMode == 'WALKING'
        ? WALKING_ARRIVAL_THRESHOLD
        : TRANSIT_ARRIVAL_THRESHOLD;

    // Check if user has arrived at current step destination
    bool shouldAdvanceStep = distanceToDestination <= arrivalThreshold;

    if (shouldAdvanceStep) {
      _advanceToNextStep();
    } else {
      // Update current state with new location and distance
      _currentState = _currentState.copyWith(
        currentLocation: currentLocation,
        currentHeading: position.heading,
        distanceToNextPoint: distanceToDestination,
        nextInstruction: _getNextInstruction(),
      );

      _navigationController.add(_currentState);
    }
  }

  void _advanceToNextStep() {
    final nextStepIndex = _currentState.currentStepIndex + 1;
    
    // Mark current step as completed
    final updatedSteps = List<NavigationStep>.from(_currentState.steps);
    if (_currentState.currentStepIndex < updatedSteps.length) {
      updatedSteps[_currentState.currentStepIndex] = 
          updatedSteps[_currentState.currentStepIndex].copyWith(isCompleted: true);
    }

    if (nextStepIndex >= _currentState.steps.length) {
      // Navigation completed
      _completeNavigation();
      return;
    }

    final nextStep = updatedSteps[nextStepIndex];
    final distanceToNext = _calculateDistanceToCurrentDestination(
      _currentState.currentLocation!,
      nextStep.endLocation,
    );

    _currentState = _currentState.copyWith(
      steps: updatedSteps,
      currentStepIndex: nextStepIndex,
      distanceToNextPoint: distanceToNext,
      nextInstruction: _getNextInstruction(),
    );

    _navigationController.add(_currentState);

    // Notify step completion (you can add sound/vibration here)
    _notifyStepCompletion();
  }

  void _completeNavigation() {
    _currentState = _currentState.copyWith(
      hasArrived: true,
      isNavigationActive: false,
      distanceToNextPoint: 0.0,
      nextInstruction: 'You have arrived at your destination!',
    );

    _navigationController.add(_currentState);
    _notifyNavigationComplete();
    stopNavigation();
  }

  double _calculateDistanceToCurrentDestination(LatLng from, LatLng to) {
    return Geolocator.distanceBetween(
      from.latitude,
      from.longitude,
      to.latitude,
      to.longitude,
    );
  }

  String? _getNextInstruction() {
    final currentStep = _currentState.currentStep;
    if (currentStep == null) return null;

    final distance = _currentState.distanceToNextPoint;
    final instruction = currentStep.instruction;

    if (distance > 1000) {
      return '$instruction (${(distance / 1000).toStringAsFixed(1)} km)';
    } else {
      return '$instruction (${distance.toInt()} m)';
    }
  }

  void _notifyStepCompletion() {
    // Add haptic feedback, sound, or notification here
    print('Step completed!');
  }

  void _notifyNavigationComplete() {
    // Add completion notification/celebration here
    print('Navigation completed! You have arrived!');
  }

  void stopNavigation() {
    _positionSubscription?.cancel();
    _currentState = _currentState.copyWith(
      isNavigationActive: false,
    );
    _navigationController.add(_currentState);
  }

  void dispose() {
    _positionSubscription?.cancel();
    _navigationController.close();
  }
}