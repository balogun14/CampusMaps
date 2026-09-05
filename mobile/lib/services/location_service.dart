import 'dart:async';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:latlong2/latlong.dart';

class LocationService {
  StreamSubscription<geo.Position>? _positionSub;
  bool _permissionGranted = false;
  double? _lastHeading;
  bool _isDisposed = false;

  final StreamController<LatLng> _positionController =
      StreamController<LatLng>.broadcast();
  final StreamController<double> _headingController =
      StreamController<double>.broadcast();

  Stream<LatLng> get positionStream => _positionController.stream;
  Stream<double> get headingStream => _headingController.stream;

  LatLng? _lastPosition;
  LatLng? get lastPosition => _lastPosition;

  double? get lastHeading => _lastHeading;

  Future<bool> requestPermission() async {
    if (_permissionGranted) return true;

    geo.LocationPermission permission = await geo.Geolocator.checkPermission();
    if (permission == geo.LocationPermission.denied) {
      permission = await geo.Geolocator.requestPermission();
    }
    _permissionGranted =
        permission == geo.LocationPermission.always ||
        permission == geo.LocationPermission.whileInUse;
    return _permissionGranted;
  }

  Future<bool> isGpsEnabled() async {
    return await geo.Geolocator.isLocationServiceEnabled();
  }

  Future<LatLng?> getCurrentPosition() async {
    final granted = await requestPermission();
    if (!granted) return null;

    try {
      final pos = await geo.Geolocator.getCurrentPosition(
        desiredAccuracy: geo.LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
      final ll = LatLng(pos.latitude, pos.longitude);
      _lastPosition = ll;
      _lastHeading = pos.heading;
      return ll;
    } catch (_) {
      return null;
    }
  }

  void startListening({double distanceFilter = 3.0}) {
    if (_positionSub != null) return;
    _requestPermissionAndListen(distanceFilter);
  }

  Future<void> _requestPermissionAndListen(double distanceFilter) async {
    await requestPermission();

    _positionSub = geo.Geolocator.getPositionStream(
      locationSettings: geo.LocationSettings(
        accuracy: geo.LocationAccuracy.high,
        distanceFilter: distanceFilter.toInt(),
      ),
    ).listen(
      (pos) {
        if (_isDisposed) return;
        final ll = LatLng(pos.latitude, pos.longitude);
        _lastPosition = ll;
        _lastHeading = pos.heading;
        _positionController.add(ll);
        if (pos.heading >= 0) {
          _headingController.add(pos.heading);
        }
      },
      onError: (_) {},
      cancelOnError: false,
    );
  }

  void stopListening() {
    _positionSub?.cancel();
    _positionSub = null;
  }

  double bearingTo(LatLng from, LatLng to) {
    return const Distance().bearing(from, to);
  }

  double distanceBetween(LatLng a, LatLng b) {
    return const Distance().as(LengthUnit.Meter, a, b);
  }

  void dispose() {
    _isDisposed = true;
    stopListening();
    _positionController.close();
    _headingController.close();
  }
}
