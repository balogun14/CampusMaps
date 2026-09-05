import 'dart:async';
import 'dart:math';
import 'package:latlong2/latlong.dart' as latlong2;
import '../models/gps_point.dart';
import '../models/recorded_activity.dart';
import 'storage_service.dart';

enum RecordingState { idle, recording, paused }

class RecordingStats {
  final Duration elapsed;
  final double distanceMeters;
  final double? currentPaceMinPerKm;
  final double? avgPaceMinPerKm;
  final double? avgSpeedKmh;
  final int pointCount;

  const RecordingStats({
    required this.elapsed,
    required this.distanceMeters,
    this.currentPaceMinPerKm,
    this.avgPaceMinPerKm,
    this.avgSpeedKmh,
    required this.pointCount,
  });
}

class RecordingService {
  RecordingState _state = RecordingState.idle;
  final List<GpsPoint> _points = [];
  DateTime? _startTime;
  DateTime? _pausedAt;
  Duration _pausedDuration = Duration.zero;
  Timer? _ticker;
  final StorageService storage = StorageService();

  final StreamController<RecordingState> _stateController =
      StreamController<RecordingState>.broadcast();
  final StreamController<RecordingStats> _statsController =
      StreamController<RecordingStats>.broadcast();

  Stream<RecordingState> get stateStream => _stateController.stream;
  Stream<RecordingStats> get statsStream => _statsController.stream;

  RecordingState get state => _state;
  List<GpsPoint> get points => List.unmodifiable(_points);
  bool get isRecording => _state == RecordingState.recording;
  bool get isPaused => _state == RecordingState.paused;

  void start() {
    _points.clear();
    _startTime = DateTime.now();
    _pausedDuration = Duration.zero;
    _pausedAt = null;
    _state = RecordingState.recording;
    _stateController.add(_state);
    _startTicker();
  }

  void addPoint(double lat, double lng,
      {double? speed, double? heading, double? accuracy}) {
    if (_state != RecordingState.recording) return;
    _points.add(GpsPoint(
      lat: lat,
      lng: lng,
      timestamp: DateTime.now(),
      speed: speed,
      heading: heading,
      accuracy: accuracy,
    ));
    _emitStats();
  }

  void pause() {
    if (_state != RecordingState.recording) return;
    _state = RecordingState.paused;
    _pausedAt = DateTime.now();
    _ticker?.cancel();
    _stateController.add(_state);
    _emitStats();
  }

  void resume() {
    if (_state != RecordingState.paused || _pausedAt == null) return;
    _pausedDuration += DateTime.now().difference(_pausedAt!);
    _pausedAt = null;
    _state = RecordingState.recording;
    _startTicker();
    _stateController.add(_state);
  }

  Future<RecordedActivity> stop({String name = 'Untitled', ActivityType type = ActivityType.walk}) async {
    _state = RecordingState.idle;
    _ticker?.cancel();
    _stateController.add(_state);

    if (_startTime == null) {
      throw StateError('No recording in progress');
    }

    final now = DateTime.now();
    final elapsed = now.difference(_startTime!) - _pausedDuration;
    final distance = _computeTotalDistance();
    final avgSpeed = elapsed.inSeconds > 0
        ? (distance / 1000.0) / (elapsed.inSeconds / 3600.0)
        : null;
    final avgPace = distance > 0 && elapsed.inSeconds > 0
        ? (elapsed.inSeconds / 60.0) / (distance / 1000.0)
        : null;

    final activity = RecordedActivity(
      id: now.millisecondsSinceEpoch.toString(),
      name: name,
      date: now,
      duration: elapsed,
      distanceMeters: distance,
      avgPaceMinPerKm: avgPace,
      avgSpeedKmh: avgSpeed,
      points: List.from(_points),
      type: type,
    );

    await storage.saveActivity(activity);
    _points.clear();
    return activity;
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      _emitStats();
    });
  }

  void _emitStats() {
    final elapsed = _computeElapsed();
    final distance = _computeTotalDistance();
    final pace = _computeCurrentPace();
    final avgSpeed = elapsed.inSeconds > 0
        ? (distance / 1000.0) / (elapsed.inSeconds / 3600.0)
        : null;
    final avgPace = distance > 0 && elapsed.inSeconds > 0
        ? (elapsed.inSeconds / 60.0) / (distance / 1000.0)
        : null;

    _statsController.add(RecordingStats(
      elapsed: elapsed,
      distanceMeters: distance,
      currentPaceMinPerKm: pace,
      avgPaceMinPerKm: avgPace,
      avgSpeedKmh: avgSpeed,
      pointCount: _points.length,
    ));
  }

  Duration _computeElapsed() {
    if (_startTime == null) return Duration.zero;
    final total = DateTime.now().difference(_startTime!);
    return total - _pausedDuration;
  }

  double _computeTotalDistance() {
    if (_points.length < 2) return 0;
    double total = 0;
    for (int i = 1; i < _points.length; i++) {
      total += _haversine(
        _points[i - 1].lat,
        _points[i - 1].lng,
        _points[i].lat,
        _points[i].lng,
      );
    }
    return total;
  }

  double? _computeCurrentPace() {
    if (_points.length < 10) return null;
    final recent = _points.sublist(max(0, _points.length - 10));
    if (recent.length < 2) return null;

    double dist = 0;
    for (int i = 1; i < recent.length; i++) {
      dist += _haversine(
        recent[i - 1].lat,
        recent[i - 1].lng,
        recent[i].lat,
        recent[i].lng,
      );
    }

    final timeSpan = recent.last.timestamp.difference(recent.first.timestamp);
    final secs = timeSpan.inMilliseconds / 1000.0;
    if (secs < 5 || dist < 5) return null;

    return (secs / 60.0) / (dist / 1000.0);
  }

  double _haversine(double lat1, double lon1, double lat2, double lon2) {
    return const latlong2.Distance().as(
      latlong2.LengthUnit.Meter,
      latlong2.LatLng(lat1, lon1),
      latlong2.LatLng(lat2, lon2),
    );
  }

  Future<List<RecordedActivity>> getHistory() => storage.loadActivities();

  void dispose() {
    _ticker?.cancel();
    _stateController.close();
    _statsController.close();
  }
}
