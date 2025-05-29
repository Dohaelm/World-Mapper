import 'package:flutter/material.dart';
import 'package:flutter_application_1/models/navigation_models.dart';
import 'package:flutter_application_1/services/navigation_service.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:async';

class NavigationScreen extends StatefulWidget {
  final List<NavigationStep> navigationSteps;
  final String destinationName;

  const NavigationScreen({
    Key? key,
    required this.navigationSteps,
    required this.destinationName,
  }) : super(key: key);

  @override
  State<NavigationScreen> createState() => _NavigationScreenState();
}

class _NavigationScreenState extends State<NavigationScreen> {
  late NavigationService _navigationService;
  GoogleMapController? _mapController;
  StreamSubscription<NavigationState>? _navigationSubscription;
  NavigationState? _currentNavigationState;

  @override
  void initState() {
    super.initState();
    _navigationService = NavigationService();
    _startNavigation();
  }

  void _startNavigation() async {
    try {
      await _navigationService.startNavigation(widget.navigationSteps);
      
      _navigationSubscription = _navigationService.navigationStream.listen(
        (navigationState) {
          setState(() {
            _currentNavigationState = navigationState;
          });
          _updateMapCamera(navigationState);
        },
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to start navigation: $e')),
      );
    }
  }

  void _updateMapCamera(NavigationState state) {
    if (_mapController != null && state.currentLocation != null) {
      _mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: state.currentLocation!,
            zoom: 16.0,
            bearing: state.currentHeading ?? 0.0,
          ),
        ),
      );
    }
  }

  Set<Polyline> _buildPolylines() {
    if (_currentNavigationState == null) return {};

    final Set<Polyline> polylines = {};
    
    // Add polyline for current step
    final currentStep = _currentNavigationState!.currentStep;
    if (currentStep != null && currentStep.polylinePoints.isNotEmpty) {
      polylines.add(
        Polyline(
          polylineId: const PolylineId('current_step'),
          points: currentStep.polylinePoints,
          color: Colors.blue,
          width: 5,
        ),
      );
    }

    // Add polylines for remaining steps (lighter color)
    for (int i = _currentNavigationState!.currentStepIndex + 1; 
         i < _currentNavigationState!.steps.length; i++) {
      final step = _currentNavigationState!.steps[i];
      if (step.polylinePoints.isNotEmpty) {
        polylines.add(
          Polyline(
            polylineId: PolylineId('step_$i'),
            points: step.polylinePoints,
            color: Colors.grey.withOpacity(0.6),
            width: 3,
          ),
        );
      }
    }

    return polylines;
  }

  Set<Marker> _buildMarkers() {
    if (_currentNavigationState == null) return {};

    final Set<Marker> markers = {};

    // Current location marker
    if (_currentNavigationState!.currentLocation != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('current_location'),
          position: _currentNavigationState!.currentLocation!,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          infoWindow: const InfoWindow(title: 'Your Location'),
        ),
      );
    }

    // Destination marker for current step
    final currentStep = _currentNavigationState!.currentStep;
    if (currentStep != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('current_destination'),
          position: currentStep.endLocation,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: InfoWindow(title: 'Next: ${currentStep.instruction}'),
        ),
      );
    }

    return markers;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('To ${widget.destinationName}'),
        backgroundColor: Colors.blue[600],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () {
              _navigationService.stopNavigation();
              Navigator.pop(context);
            },
          ),
        ],
      ),
      body: _currentNavigationState == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Progress indicator
                _buildProgressIndicator(),
                
                // Map
                Expanded(
                  flex: 2,
                  child: GoogleMap(
                    onMapCreated: (GoogleMapController controller) {
                      _mapController = controller;
                    },
                    initialCameraPosition: CameraPosition(
                      target: widget.navigationSteps.isNotEmpty
                          ? widget.navigationSteps[0].startLocation
                          : const LatLng(0, 0),
                      zoom: 16.0,
                    ),
                    polylines: _buildPolylines(),
                    markers: _buildMarkers(),
                    myLocationEnabled: true,
                    myLocationButtonEnabled: true,
                    compassEnabled: true,
                    trafficEnabled: true,
                  ),
                ),
                
                // Navigation instructions
                _buildNavigationInstructions(),
              ],
            ),
    );
  }

  Widget _buildProgressIndicator() {
    if (_currentNavigationState == null) return const SizedBox.shrink();

    final progress = _currentNavigationState!.progressPercentage / 100;
    final currentStep = _currentNavigationState!.currentStepIndex + 1;
    final totalSteps = _currentNavigationState!.steps.length;

    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.blue[50],
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Step $currentStep of $totalSteps',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                '${(progress * 100).toInt()}% Complete',
                style: TextStyle(color: Colors.blue[700]),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.grey[300],
            valueColor: AlwaysStoppedAnimation<Color>(Colors.blue[600]!),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationInstructions() {
    if (_currentNavigationState == null) return const SizedBox.shrink();

    if (_currentNavigationState!.hasArrived) {
      return _buildArrivalCard();
    }

    final currentStep = _currentNavigationState!.currentStep;
    if (currentStep == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Current instruction
          Row(
            children: [
              _getStepIcon(currentStep),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _currentNavigationState!.nextInstruction ?? currentStep.instruction,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (currentStep.transitLine != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blue[100],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            currentStep.transitLine!,
                            style: TextStyle(
                              color: Colors.blue[800],
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Next step preview
          if (_currentNavigationState!.nextStep != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.next_plan, color: Colors.grey[600], size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Next: ${_currentNavigationState!.nextStep!.instruction}',
                      style: TextStyle(
                        color: Colors.grey[700],
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildArrivalCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.green[50],
        border: Border(top: BorderSide(color: Colors.green[200]!)),
      ),
      child: Column(
        children: [
          Icon(
            Icons.check_circle,
            color: Colors.green[600],
            size: 48,
          ),
          const SizedBox(height: 16),
          Text(
            'You have arrived!',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.green[800],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Welcome to ${widget.destinationName}',
            style: TextStyle(
              fontSize: 16,
              color: Colors.green[700],
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green[600],
              foregroundColor: Colors.white,
            ),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  Widget _getStepIcon(NavigationStep step) {
    IconData iconData;
    Color iconColor;

    switch (step.travelMode) {
      case 'WALKING':
        iconData = Icons.directions_walk;
        iconColor = Colors.green;
        break;
      case 'TRANSIT':
        switch (step.vehicleType) {
          case 'BUS':
            iconData = Icons.directions_bus;
            iconColor = Colors.blue;
            break;
          case 'SUBWAY':
            iconData = Icons.directions_subway;
            iconColor = Colors.purple;
            break;
          case 'TRAM':
            iconData = Icons.tram;
            iconColor = Colors.orange;
            break;
          default:
            iconData = Icons.directions_transit;
            iconColor = Colors.blue;
        }
        break;
      default:
        iconData = Icons.navigation;
        iconColor = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: iconColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        iconData,
        color: iconColor,
        size: 24,
      ),
    );
  }

  @override
  void dispose() {
    _navigationSubscription?.cancel();
    _navigationService.dispose();
    super.dispose();
  }
}