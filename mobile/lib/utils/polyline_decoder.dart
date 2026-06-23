import 'dart:convert';

List<LatLngPoint> decodePolyline(String encoded) {
  final len = encoded.length;
  int index = 0;
  int lat = 0;
  int lng = 0;
  final points = <LatLngPoint>[];

  while (index < len) {
    int b;
    int shift = 0;
    int result = 0;
    do {
      b = encoded.codeUnitAt(index++) - 63;
      result |= (b & 0x1f) << shift;
      shift += 5;
    } while (b >= 0x20);
    final dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
    lat += dlat;

    shift = 0;
    result = 0;
    do {
      b = encoded.codeUnitAt(index++) - 63;
      result |= (b & 0x1f) << shift;
      shift += 5;
    } while (b >= 0x20);
    final dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
    lng += dlng;

    points.add(LatLngPoint(lat: lat / 1e5, lng: lng / 1e5));
  }
  return points;
}

class LatLngPoint {
  final double lat;
  final double lng;
  const LatLngPoint({required this.lat, required this.lng});
}
