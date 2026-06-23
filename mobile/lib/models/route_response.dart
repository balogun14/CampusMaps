class RouteResponse {
  final String encodedPolyline;
  final RouteSummary summary;
  final List<RouteStep> steps;

  RouteResponse({
    required this.encodedPolyline,
    required this.summary,
    required this.steps,
  });

  factory RouteResponse.fromJson(Map<String, dynamic> json) => RouteResponse(
        encodedPolyline: json['encodedPolyline'] as String? ?? '',
        summary: RouteSummary.fromJson(json['summary'] as Map<String, dynamic>? ?? {}),
        steps: (json['steps'] as List<dynamic>? ?? [])
            .map((s) => RouteStep.fromJson(s as Map<String, dynamic>))
            .toList(),
      );
}

class RouteSummary {
  final double distanceMeters;
  final double durationSeconds;
  final double distanceKm;
  final String durationFormatted;

  RouteSummary({
    required this.distanceMeters,
    required this.durationSeconds,
    required this.distanceKm,
    required this.durationFormatted,
  });

  factory RouteSummary.fromJson(Map<String, dynamic> json) => RouteSummary(
        distanceMeters: (json['distanceMeters'] as num?)?.toDouble() ?? 0,
        durationSeconds: (json['durationSeconds'] as num?)?.toDouble() ?? 0,
        distanceKm: (json['distanceKm'] as num?)?.toDouble() ?? 0,
        durationFormatted: json['durationFormatted'] as String? ?? '',
      );
}

class RouteStep {
  final int stepNumber;
  final String instruction;
  final String streetName;
  final double lat;
  final double lng;
  final double distanceMeters;
  final double durationSeconds;
  final String direction;
  final bool isCustomPath;

  RouteStep({
    required this.stepNumber,
    required this.instruction,
    required this.streetName,
    required this.lat,
    required this.lng,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.direction,
    required this.isCustomPath,
  });

  factory RouteStep.fromJson(Map<String, dynamic> json) => RouteStep(
        stepNumber: json['stepNumber'] as int? ?? 0,
        instruction: json['instruction'] as String? ?? '',
        streetName: json['streetName'] as String? ?? '',
        lat: (json['startLocation']?['lat'] as num?)?.toDouble() ?? 0,
        lng: (json['startLocation']?['lng'] as num?)?.toDouble() ?? 0,
        distanceMeters: (json['distanceMeters'] as num?)?.toDouble() ?? 0,
        durationSeconds: (json['durationSeconds'] as num?)?.toDouble() ?? 0,
        direction: json['direction'] as String? ?? '',
        isCustomPath: json['isCustomPath'] as bool? ?? false,
      );
}
