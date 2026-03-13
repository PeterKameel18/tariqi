import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:tariqi/const/api_links_keys/api_links_keys.dart';

class PhoneAuthRepo {
  Future<Map<String, dynamic>> exchangeFirebaseToken({
    required String idToken,
    String? role,
    Map<String, dynamic>? profile,
  }) async {
    final response = await http.post(
      Uri.parse('${ApiLinksKeys.baseUrl}/auth/phone'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'idToken': idToken,
        if (role != null) 'role': role,
        if (profile != null) 'profile': profile,
      }),
    ).timeout(const Duration(seconds: 20));

    final data = jsonDecode(response.body);
    return {
      'statusCode': response.statusCode,
      'data': data,
    };
  }
}
