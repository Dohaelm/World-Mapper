import 'package:flutter/material.dart';

class LocationPage extends StatefulWidget {
  const LocationPage({super.key});

  @override
  State<LocationPage> createState() => _LocationPageState();
}

class _LocationPageState extends State<LocationPage> {
  final TextEditingController _fromController = TextEditingController();
  final TextEditingController _toController = TextEditingController();
  List<String> transitOptions = [];

  void _browseTransit() {
    // In a real app, you'd call an API or use logic here
    setState(() {
      transitOptions = [
        '🚍 Bus Line 24 - 15 mins',
        '🚆 Metro A - 12 mins',
        '🚕 Taxi - 10 mins (approx. \$7)',
        '🚲 Bike Path - 25 mins'
      ];
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Transit Planner'),
        backgroundColor: Colors.green,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Current Position:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            TextField(
              controller: _fromController,
              decoration: const InputDecoration(
                hintText: 'e.g. Gare Rabat Ville',
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Destination:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            TextField(
              controller: _toController,
              decoration: const InputDecoration(
                hintText: 'e.g. Technopolis',
              ),
            ),
            const SizedBox(height: 30),
            Center(
              child: ElevatedButton(
                onPressed: _browseTransit,
                child: const Text('Browse'),
              ),
            ),
            const SizedBox(height: 30),
            if (transitOptions.isNotEmpty) ...[
              const Text(
                'Available Transit Options:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              for (var option in transitOptions)
                ListTile(
                  leading: const Icon(Icons.directions_transit),
                  title: Text(option),
                )
            ]
          ],
        ),
      ),
    );
  }
}
