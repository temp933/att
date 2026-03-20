import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

// ─── CONFIG ───────────────────────────────────────────────────────────────────
// Change this one constant to point at your server.
// For local development: use your LAN IP.
// For production:        use your public domain / HTTPS URL.
const String kServerBaseUrl = "http://192.168.29.103:3000";

class ApiService {
  static const String baseUrl = kServerBaseUrl;
  static const Duration _timeout = Duration(seconds: 10);
  static const Duration _longTimeout = Duration(seconds: 20);

  static final http.Client _client = http.Client();

  // ── AUTH ────────────────────────────────────────────────────────────────────

  /// FIX: posts to /auth/login (server now has this route)
  static Future<Map<String, dynamic>> login(
    String loginId,
    String password,
  ) async {
    final res = await _client
        .post(
          Uri.parse("$baseUrl/auth/login"),
          headers: {"Content-Type": "application/json"},
          body: jsonEncode({"login_id": loginId, "password": password}),
        )
        .timeout(_timeout);

    final body = _decode(res.body);
    if (res.statusCode == 200) return body;
    throw ApiException(body["message"] ?? "Login failed", res.statusCode);
  }

  // ── ATTENDANCE STATUS & LOGS ────────────────────────────────────────────────

  static Future<Map<String, dynamic>> getTodayStatus(int employeeId) async {
    final res = await _client
        .get(Uri.parse("$baseUrl/attendance/status/$employeeId"))
        .timeout(_timeout);
    if (res.statusCode == 200) return _decode(res.body);
    throw ApiException("Status check failed", res.statusCode);
  }

  static Future<List<dynamic>> getTodayLogs(int employeeId) async {
    final res = await _client
        .get(Uri.parse("$baseUrl/attendance/today/$employeeId"))
        .timeout(_timeout);
    if (res.statusCode == 200) return jsonDecode(res.body) as List;
    throw ApiException("Failed to fetch logs", res.statusCode);
  }

  // ── SITES ───────────────────────────────────────────────────────────────────

  static Future<List<dynamic>> getSites() async {
    final res = await _client
        .get(Uri.parse("$baseUrl/sites"))
        .timeout(_longTimeout);
    if (res.statusCode == 200) return jsonDecode(res.body) as List;
    throw ApiException("Failed to fetch sites", res.statusCode);
  }

  // ── INDIVIDUAL ATTENDANCE CALLS (used by SyncWorker) ───────────────────────

  static Future<void> markIn(int employeeId, int siteId) async {
    final res = await _client
        .post(
          Uri.parse("$baseUrl/attendance/in"),
          headers: {"Content-Type": "application/json"},
          body: jsonEncode({"employee_id": employeeId, "site_id": siteId}),
        )
        .timeout(_timeout);
    if (res.statusCode != 200) {
      throw ApiException("Mark IN failed: ${res.body}", res.statusCode);
    }
  }

  static Future<void> markOut(int employeeId) async {
    final res = await _client
        .post(
          Uri.parse("$baseUrl/attendance/out"),
          headers: {"Content-Type": "application/json"},
          body: jsonEncode({"employee_id": employeeId}),
        )
        .timeout(_timeout);
    if (res.statusCode != 200) {
      throw ApiException("Mark OUT failed: ${res.body}", res.statusCode);
    }
  }

  static Future<void> endDay(int employeeId) async {
    final res = await _client
        .post(
          Uri.parse("$baseUrl/attendance/end-day"),
          headers: {"Content-Type": "application/json"},
          body: jsonEncode({"employee_id": employeeId}),
        )
        .timeout(_timeout);
    if (res.statusCode != 200) {
      throw ApiException("End day failed: ${res.body}", res.statusCode);
    }
  }

  // ── BATCH SYNC ──────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> batchSync(
    List<Map<String, dynamic>> events,
  ) async {
    final res = await _client
        .post(
          Uri.parse("$baseUrl/attendance/batch-sync"),
          headers: {"Content-Type": "application/json"},
          body: jsonEncode({"events": events}),
        )
        .timeout(_longTimeout);
    if (res.statusCode == 200) return _decode(res.body);
    throw ApiException("Batch sync failed: ${res.statusCode}", res.statusCode);
  }

  // ── PING ────────────────────────────────────────────────────────────────────

  static Future<bool> pingServer() async {
    try {
      final res = await _client
          .get(Uri.parse(baseUrl))
          .timeout(const Duration(seconds: 5));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // ── HELPERS ─────────────────────────────────────────────────────────────────

  static Map<String, dynamic> _decode(String body) {
    try {
      return jsonDecode(body) as Map<String, dynamic>;
    } catch (_) {
      return {"raw": body};
    }
  }
}

// ─── EXCEPTION ────────────────────────────────────────────────────────────────

class ApiException implements Exception {
  final String message;
  final int statusCode;
  const ApiException(this.message, this.statusCode);

  @override
  String toString() => "ApiException($statusCode): $message";
}
