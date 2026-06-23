import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/route_request.dart';
import '../models/route_response.dart';

class RoutingService {
  final String baseUrl;

  RoutingService({required this.baseUrl});

  Future<RouteResponse> getRoute(RouteRequest request) async {
    final uri = Uri.parse('$baseUrl/v1/route');
    final res = await http
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(request.toJson()),
        )
        .timeout(const Duration(seconds: 15));

    if (res.statusCode != 200) {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      throw RoutingException(body['error'] as String? ?? 'Unknown error');
    }

    return RouteResponse.fromJson(
      jsonDecode(res.body) as Map<String, dynamic>,
    );
  }
}

class RoutingException implements Exception {
  final String message;
  RoutingException(this.message);

  @override
  String toString() => message;
}
