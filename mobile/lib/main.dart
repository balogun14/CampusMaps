import 'package:flutter/material.dart';
import 'screens/map_screen.dart';
import 'services/routing_service.dart';

void main() {
  runApp(const RunItMapsApp());
}

class RunItMapsApp extends StatelessWidget {
  const RunItMapsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RunIt Maps',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: Colors.blue,
        useMaterial3: true,
      ),
      home: MapScreen(
        routingService: RoutingService(
          // Change this to your server's address.
          // For Android emulator use 10.0.2.2 instead of localhost.
          baseUrl: const String.fromEnvironment('API_BASE_URL', defaultValue: 'http://10.0.2.2:8080'),
        ),
      ),
    );
  }
}
