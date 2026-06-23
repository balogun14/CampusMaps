import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/route_request.dart';
import '../models/route_response.dart';
import '../services/routing_service.dart';
import '../utils/polyline_decoder.dart';
import '../widgets/directions_panel.dart';
import '../widgets/route_settings.dart';

class MapScreen extends StatefulWidget {
  final RoutingService routingService;
  const MapScreen({super.key, required this.routingService});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final _mapController = MapController();

  // Route settings
  String _costing = 'campus_pedestrian';
  bool _avoidStairs = true;
  double _walkingSpeed = 5.0;

  // Map markers
  LatLng? _origin;
  LatLng? _destination;

  // Route state
  RouteResponse? _routeResponse;
  List<LatLng>? _routeLatLngs;
  bool _loading = false;
  String? _error;

  // Panel state
  bool _showSettings = false;
  bool _showDirections = false;

  static const _medilagCenter = LatLng(6.515, 3.350);

  @override
  void initState() {
    super.initState();
    _origin = LatLng(6.5135, 3.3515);
    _destination = LatLng(6.5165, 3.3490);
  }

  void _onMapTap(TapPosition tap, LatLng point) {
    if (_origin == null) {
      setState(() => _origin = point);
    } else if (_destination == null) {
      setState(() => _destination = point);
    } else {
      setState(() {
        _origin = point;
        _destination = null;
        _routeResponse = null;
        _routeLatLngs = null;
        _showDirections = false;
      });
    }
  }

  Future<void> _fetchRoute() async {
    if (_origin == null || _destination == null) return;
    setState(() { _loading = true; _error = null; _showDirections = false; });

    try {
      final req = RouteRequest(
        originLat: _origin!.latitude,
        originLng: _origin!.longitude,
        destLat: _destination!.latitude,
        destLng: _destination!.longitude,
        costing: _costing,
        avoidStairs: _avoidStairs,
        walkingSpeedKmh: _walkingSpeed,
      );
      final resp = await widget.routingService.getRoute(req);
      final points = decodePolyline(resp.encodedPolyline)
          .map((p) => LatLng(p.lat, p.lng))
          .toList();

      setState(() {
        _routeResponse = resp;
        _routeLatLngs = points;
        _loading = false;
        _showDirections = true;
      });

      if (points.isNotEmpty) {
        _mapController.fitCamera(CameraFit.bounds(
          bounds: LatLngBounds.fromPoints(points),
          padding: const EdgeInsets.all(40),
        ));
      }
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('RunIt Maps'),
        actions: [
          IconButton(
            icon: Icon(_showSettings ? Icons.tune : Icons.tune_outlined),
            onPressed: () => setState(() => _showSettings = !_showSettings),
          ),
          IconButton(
            icon: const Icon(Icons.my_location),
            onPressed: () => _mapController.move(_medilagCenter, 16),
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _medilagCenter,
              initialZoom: 16,
              onTap: _onMapTap,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.runit.maps',
              ),
              // Route polyline
              if (_routeLatLngs != null)
                PolylineLayer(polylines: [
                  Polyline(
                    points: _routeLatLngs!,
                    color: Colors.blue,
                    strokeWidth: 4,
                  ),
                ]),
              // Markers
              MarkerLayer(markers: [
                if (_origin != null)
                  Marker(
                    point: _origin!,
                    width: 36, height: 36,
                    child: _marker('A', Colors.blue),
                  ),
                if (_destination != null)
                  Marker(
                    point: _destination!,
                    width: 36, height: 36,
                    child: _marker('B', Colors.red),
                  ),
              ]),
            ],
          ),

          // Top — hint text
          if (_origin == null || _destination == null)
            Positioned(
              top: 8, left: 16, right: 16,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(
                    _origin == null ? 'Tap map to set origin (A)' : 'Tap map to set destination (B)',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ),
            ),

          // Bottom — settings panel
          if (_showSettings)
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: RouteSettingsWidget(
                costing: _costing,
                avoidStairs: _avoidStairs,
                walkingSpeed: _walkingSpeed,
                onCostingChanged: (v) { _costing = v; setState(() {}); },
                onAvoidStairsChanged: (v) { _avoidStairs = v; setState(() {}); },
                onWalkingSpeedChanged: (v) { _walkingSpeed = v; setState(() {}); },
              ),
            ),

          // Bottom — directions panel
          if (_showDirections && _routeResponse != null && !_showSettings)
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: DirectionsPanel(
                response: _routeResponse!,
                onDismiss: () => setState(() => _showDirections = false),
              ),
            ),

          // Floating route button
          if (_origin != null && _destination != null)
            Positioned(
              right: 16,
              bottom: _showDirections ? MediaQuery.of(context).size.height * 0.48 : 100,
              child: FloatingActionButton(
                heroTag: 'route',
                onPressed: _loading ? null : _fetchRoute,
                child: _loading
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.route),
              ),
            ),

          // Error snackbar
          if (_error != null)
            Positioned(
              top: 8, left: 16, right: 16,
              child: Card(
                color: Colors.red.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(_error!, style: TextStyle(color: Colors.red.shade800, fontSize: 13)),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _marker(String label, Color color) {
    return Container(
      decoration: BoxDecoration(color: color, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
      child: Center(child: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14))),
    );
  }
}
