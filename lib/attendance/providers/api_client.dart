import 'package:http/http.dart' as http;
import 'api_config.dart';
import 'dart:convert';

class ApiClient {
  static final Map<String, String> _headers = ApiConfig.headers;

  static Future<http.Response> get(String path) {
    return http.get(Uri.parse('${ApiConfig.baseUrl}$path'), headers: _headers);
  }

  // In api_client.dart — verify it looks like this:
  static Future<http.Response> post(
    String path,
    Map<String, dynamic> body,
  ) async {
    return http.post(
      Uri.parse('${ApiConfig.baseUrl}$path'),
      headers: {
        'Content-Type': 'application/json',
        'ngrok-skip-browser-warning': 'true',
      },
      body: jsonEncode(body), // ← must be jsonEncode, not toString()
    );
  }

  static Future<http.Response> put(String path, Map<String, dynamic> body) {
    return http.put(
      Uri.parse('${ApiConfig.baseUrl}$path'),
      headers: _headers,
      body: jsonEncode(body),
    );
  }

  static Future<http.Response> delete(String path) {
    return http.delete(
      Uri.parse('${ApiConfig.baseUrl}$path'),
      headers: _headers,
    );
  }
}
