import 'dart:async';
import 'package:latlong2/latlong.dart' as latlong2;
import '../models/route_response.dart';
import '../utils/polyline_decoder.dart';

class NavigationUpdate {
  final int currentStepIndex;
  final int totalSteps;
  final RouteStep currentStep;
  final double remainingDistanceMeters;
  final double remainingDurationSeconds;
  final double distanceToNextTurnMeters;
  final double progress;
  final bool arrived;
  final double? bearing;

  const NavigationUpdate({
    required this.currentStepIndex,
    required this.totalSteps,
    required this.currentStep,
    required this.remainingDistanceMeters,
    required this.remainingDurationSeconds,
    required this.distanceToNextTurnMeters,
    required this.progress,
    this.arrived = false,
    this.bearing,
  });
}

class NavigationService {
  List<latlong2.LatLng>? _routePoints;
  List<RouteStep> _steps = [];
  List<List<latlong2.LatLng>> _stepGeometries = [];
  int _currentStepIndex = 0;
  double _totalDistanceMeters = 0;
  double _totalDurationSeconds = 0;
  bool _arrived = false;

  final StreamController<NavigationUpdate> _updateController =
      StreamController<NavigationUpdate>.broadcast();
  Stream<NavigationUpdate> get updates => _updateController.stream;

  int get currentStepIndex => _currentStepIndex;
  bool get isActive => _routePoints != null;
  bool get arrived => _arrived;
  int get totalSteps => _steps.length;

  void init(RouteResponse response) {
    _steps = response.steps;
    _totalDistanceMeters = response.summary.distanceMeters;
    _totalDurationSeconds = response.summary.durationSeconds;
    _currentStepIndex = 0;
    _arrived = false;

    _routePoints = decodePolyline(response.encodedPolyline)
        .map((p) => latlong2.LatLng(p.lat, p.lng))
        .toList();

    _stepGeometries = response.steps.map((step) {
      if (step.encodedPolyline.isNotEmpty) {
        return decodePolyline(step.encodedPolyline)
            .map((p) => latlong2.LatLng(p.lat, p.lng))
            .toList();
      }
      return <latlong2.LatLng>[];
    }).toList();
  }

  NavigationUpdate? updatePosition(double lat, double lng, {double? heading}) {
    if (_routePoints == null || _routePoints!.isEmpty || _arrived) return null;

    final userPos = latlong2.LatLng(lat, lng);

    final closest = _findClosestPointOnPolyline(userPos, _routePoints!);
    if (closest == null) return null;

    final segIndex = closest.$1;
    final frac = closest.$2;
    final snapPos = closest.$3;

    _advanceStep(snapPos);

    if (_currentStepIndex >= _steps.length) {
      _arrived = true;
      return NavigationUpdate(
        currentStepIndex: _steps.length - 1,
        totalSteps: _steps.length,
        currentStep: _steps.last,
        remainingDistanceMeters: 0,
        remainingDurationSeconds: 0,
        distanceToNextTurnMeters: 0,
        progress: 1.0,
        arrived: true,
        bearing: heading,
      );
    }

    final remainingDist = _computeRemainingDistance(snapPos, segIndex, frac);
    final remainingDur = _totalDurationSeconds *
        (remainingDist / _totalDistanceMeters.clamp(0.001, double.infinity));
    final distanceToNext = _distanceToNextTurn(snapPos);

    final totalProgress = _totalDistanceMeters > 0
        ? 1.0 - (remainingDist / _totalDistanceMeters)
        : 0.0;

    double? bearing;
    if (heading != null && heading >= 0) {
      bearing = heading;
    } else {
      final nextPts = _routePoints!.skip(segIndex).take(5).toList();
      if (nextPts.length >= 2) {
        bearing = _bearingBetween(nextPts[0], nextPts[1]);
      }
    }

    final update = NavigationUpdate(
      currentStepIndex: _currentStepIndex.clamp(0, _steps.length - 1),
      totalSteps: _steps.length,
      currentStep: _steps[_currentStepIndex.clamp(0, _steps.length - 1)],
      remainingDistanceMeters: remainingDist,
      remainingDurationSeconds: remainingDur,
      distanceToNextTurnMeters: distanceToNext,
      progress: totalProgress.clamp(0.0, 1.0),
      bearing: bearing,
    );

    _updateController.add(update);
    return update;
  }

  void _advanceStep(latlong2.LatLng snapPos) {
    if (_stepGeometries.isEmpty || _steps.isEmpty) return;

    for (int i = _currentStepIndex; i < _steps.length; i++) {
      final geo = _stepGeometries[i];
      if (geo.isEmpty) continue;

      final endPoint = geo.last;
      final dist = _haversine(snapPos, endPoint);
      final stepLen = _steps[i].distanceMeters;

      if (stepLen > 0 && dist < stepLen * 0.2) {
        _currentStepIndex = (i + 1).clamp(0, _steps.length - 1);
        return;
      }
      if (dist < 15) {
        _currentStepIndex = (i + 1).clamp(0, _steps.length - 1);
        return;
      }
      break;
    }
  }

  double _distanceToNextTurn(latlong2.LatLng snapPos) {
    if (_currentStepIndex >= _steps.length) return 0;
    final step = _steps[_currentStepIndex];
    final geo = _stepGeometries.isNotEmpty &&
            _currentStepIndex < _stepGeometries.length
        ? _stepGeometries[_currentStepIndex]
        : <latlong2.LatLng>[];

    if (geo.length < 2) {
      final end = latlong2.LatLng(step.lat, step.lng);
      return _haversine(snapPos, end);
    }

    double accumulated = 0;
    double minDist = double.infinity;
    int closestIdx = 0;
    for (int i = 0; i < geo.length; i++) {
      final d = _haversine(snapPos, geo[i]);
      if (d < minDist) {
        minDist = d;
        closestIdx = i;
      }
    }

    for (int i = closestIdx; i < geo.length - 1; i++) {
      accumulated += _haversine(geo[i], geo[i + 1]);
    }
    return accumulated;
  }

  (int, double, latlong2.LatLng)? _findClosestPointOnPolyline(
    latlong2.LatLng point,
    List<latlong2.LatLng> polyline,
  ) {
    if (polyline.length < 2) return null;

    double minDist = double.infinity;
    int bestSeg = 0;
    double bestFrac = 0.0;
    latlong2.LatLng bestSnap = polyline.first;

    for (int i = 0; i < polyline.length - 1; i++) {
      final a = polyline[i];
      final b = polyline[i + 1];
      final proj = _projectOnSegment(point, a, b);
      final snap = latlong2.LatLng(proj.$1, proj.$2);
      final dist = _haversine(point, snap);
      if (dist < minDist) {
        minDist = dist;
        bestSeg = i;
        bestFrac = proj.$3;
        bestSnap = snap;
      }
    }

    return (bestSeg, bestFrac, bestSnap);
  }

  (double, double, double) _projectOnSegment(
    latlong2.LatLng p,
    latlong2.LatLng a,
    latlong2.LatLng b,
  ) {
    final ax = a.latitude, ay = a.longitude;
    final bx = b.latitude, by = b.longitude;
    final dx = bx - ax, dy = by - ay;
    final len2 = dx * dx + dy * dy;

    if (len2 < 1e-12) return (ax, ay, 0.0);

    final t = ((p.latitude - ax) * dx + (p.longitude - ay) * dy) / len2;
    final tClamped = t.clamp(0.0, 1.0);
    final px = ax + tClamped * dx;
    final py = ay + tClamped * dy;
    return (px, py, tClamped);
  }

  double _computeRemainingDistance(
    latlong2.LatLng snapPos,
    int segIndex,
    double frac,
  ) {
    double dist = 0;

    final remainingFrac = 1.0 - frac;
    if (segIndex < _routePoints!.length - 1) {
      dist +=
          _haversine(snapPos, _routePoints![segIndex + 1]) * remainingFrac;
    }

    for (int i = segIndex + 1; i < _routePoints!.length - 1; i++) {
      dist += _haversine(_routePoints![i], _routePoints![i + 1]);
    }

    return dist;
  }

  double _haversine(latlong2.LatLng a, latlong2.LatLng b) {
    return const latlong2.Distance().as(
      latlong2.LengthUnit.Meter,
      a,
      b,
    );
  }

  double _bearingBetween(latlong2.LatLng a, latlong2.LatLng b) {
    return const latlong2.Distance().bearing(a, b);
  }

  void dispose() {
    _routePoints = null;
    _steps = [];
    _stepGeometries = [];
    _updateController.close();
  }
}
