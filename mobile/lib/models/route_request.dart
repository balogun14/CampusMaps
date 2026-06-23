class RouteRequest {
  final double originLat;
  final double originLng;
  final double destLat;
  final double destLng;
  final String costing;
  final bool avoidStairs;
  final double walkingSpeedKmh;

  RouteRequest({
    required this.originLat,
    required this.originLng,
    required this.destLat,
    required this.destLng,
    this.costing = 'campus_pedestrian',
    this.avoidStairs = true,
    this.walkingSpeedKmh = 5.0,
  });

  Map<String, dynamic> toJson() => {
        'origin': {'lat': originLat, 'lng': originLng},
        'destination': {'lat': destLat, 'lng': destLng},
        'costing': costing,
        'avoidStairs': avoidStairs,
        'walkingSpeedKmh': walkingSpeedKmh,
      };
}
