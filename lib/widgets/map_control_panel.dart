import 'package:flutter/material.dart';

class MapControlPanel extends StatelessWidget {
  final Function() onZoomIn;
  final Function() onZoomOut;
  final Function() onMyLocation;
  
  
  const MapControlPanel({
    Key? key,
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onMyLocation,

  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Zoom in button
            _buildControlButton(
              icon: Icons.add,
              tooltip: 'Zoom in',
              onPressed: onZoomIn,
            ),
            const Divider(height: 1),
            
            // Zoom out button
            _buildControlButton(
              icon: Icons.remove,
              tooltip: 'Zoom out',
              onPressed: onZoomOut,
            ),
            const Divider(height: 1),
            
            // My location button
            _buildControlButton(
              icon: Icons.my_location,
              tooltip: 'My location',
              onPressed: onMyLocation,
            ),
           
          ],
        ),
      ),
    );
  }
  
  Widget _buildControlButton({
    required IconData icon,
    required String tooltip,
    required Function() onPressed,
    Color? color,
  }) {
    return SizedBox(
      width: 48,
      height: 48,
      child: IconButton(
        icon: Icon(icon, color: color),
        tooltip: tooltip,
        onPressed: onPressed,
      ),
    );
  }
} 