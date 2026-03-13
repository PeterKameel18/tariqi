import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:tariqi/const/api_links_keys/api_links_keys.dart';

class AuthRepo {
  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final response = await http
        .post(
          Uri.parse('${ApiLinksKeys.baseUrl}/auth/login'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'email': email,
            'password': password,
          }),
        )
        .timeout(const Duration(seconds: 15));

    return _mapResponse(response);
  }

  Future<Map<String, dynamic>> signup({
    required Map<String, dynamic> body,
    required String endpoint,
  }) async {
    final response = await http
        .post(
          Uri.parse(endpoint),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 15));

    return _mapResponse(response);
  }

  Future<Map<String, dynamic>> forgotPassword({
    required String email,
  }) async {
    final response = await http
        .post(
          Uri.parse('${ApiLinksKeys.baseUrl}/auth/forgot-password'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'email': email}),
        )
        .timeout(const Duration(seconds: 15));

    return _mapResponse(response);
  }

  Map<String, dynamic> _mapResponse(http.Response response) {
    dynamic decoded;
    try {
      decoded = jsonDecode(response.body);
    } catch (_) {
      decoded = {'message': response.body};
    }

    return {
      'statusCode': response.statusCode,
      'data': decoded is Map<String, dynamic>
          ? decoded
          : <String, dynamic>{'message': decoded.toString()},
    };
  }
}
