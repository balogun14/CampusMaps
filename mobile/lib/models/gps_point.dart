class GpsPoint {
  final double lat;
  final double lng;
  final DateTime timestamp;
  final double? speed;
  final double? heading;
  final double? accuracy;

  const GpsPoint({
    required this.lat,
    required this.lng,
    required this.timestamp,
    this.speed,
    this.heading,
    this.accuracy,
  });

  Map<String, dynamic> toJson() => {
        'lat': lat,
        'lng': lng,
        'timestamp': timestamp.toIso8601String(),
        'speed': speed,
        'heading': heading,
        'accuracy': accuracy,
      };

  factory GpsPoint.fromJson(Map<String, dynamic> json) => GpsPoint(
        lat: (json['lat'] as num).toDouble(),
        lng: (json['lng'] as num).toDouble(),
        timestamp: DateTime.parse(json['timestamp'] as String),
        speed: (json['speed'] as num?)?.toDouble(),
        heading: (json['heading'] as num?)?.toDouble(),
        accuracy: (json['accuracy'] as num?)?.toDouble(),
      );
}
