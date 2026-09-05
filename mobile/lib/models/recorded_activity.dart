import 'gps_point.dart';

enum ActivityType { walk, run, hike }

class RecordedActivity {
  final String id;
  final String name;
  final DateTime date;
  final Duration duration;
  final double distanceMeters;
  final double? avgPaceMinPerKm;
  final double? avgSpeedKmh;
  final List<GpsPoint> points;
  final ActivityType type;

  const RecordedActivity({
    required this.id,
    required this.name,
    required this.date,
    required this.duration,
    required this.distanceMeters,
    this.avgPaceMinPerKm,
    this.avgSpeedKmh,
    required this.points,
    this.type = ActivityType.walk,
  });

  double get distanceKm => distanceMeters / 1000.0;

  String get formattedDistance {
    if (distanceKm >= 1.0) return '${distanceKm.toStringAsFixed(2)} km';
    return '${distanceMeters.toStringAsFixed(0)} m';
  }

  String get formattedDuration {
    final h = duration.inHours;
    final m = duration.inMinutes.remainder(60);
    final s = duration.inSeconds.remainder(60);
    if (h > 0) return '${h}h ${m}m';
    if (m > 0) return '${m}m ${s}s';
    return '${s}s';
  }

  String get formattedPace {
    if (avgPaceMinPerKm == null) return '--';
    final min = avgPaceMinPerKm!.floor();
    final sec = ((avgPaceMinPerKm! - min) * 60).round();
    return '$min:${sec.toString().padLeft(2, '0')} /km';
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'date': date.toIso8601String(),
        'durationMs': duration.inMilliseconds,
        'distanceMeters': distanceMeters,
        'avgPaceMinPerKm': avgPaceMinPerKm,
        'avgSpeedKmh': avgSpeedKmh,
        'points': points.map((p) => p.toJson()).toList(),
        'type': type.name,
      };

  factory RecordedActivity.fromJson(Map<String, dynamic> json) =>
      RecordedActivity(
        id: json['id'] as String,
        name: json['name'] as String? ?? 'Activity',
        date: DateTime.parse(json['date'] as String),
        duration: Duration(milliseconds: json['durationMs'] as int),
        distanceMeters: (json['distanceMeters'] as num).toDouble(),
        avgPaceMinPerKm:
            (json['avgPaceMinPerKm'] as num?)?.toDouble(),
        avgSpeedKmh: (json['avgSpeedKmh'] as num?)?.toDouble(),
        points: (json['points'] as List<dynamic>)
            .map((p) => GpsPoint.fromJson(p as Map<String, dynamic>))
            .toList(),
        type: ActivityType.values.firstWhere(
          (t) => t.name == json['type'],
          orElse: () => ActivityType.walk,
        ),
      );
}
