import 'package:flutter/material.dart';
import 'theme.dart';
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
      theme: AppTheme.light,
      home: MapScreen(
        routingService: RoutingService(
          baseUrl: const String.fromEnvironment('API_BASE_URL', defaultValue: 'http://10.0.2.2:8080'),
        ),
      ),
    );
  }
}
