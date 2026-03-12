// // import 'package:shared_preferences/shared_preferences.dart';

// // class AuthService {
// //   static const String _isLoggedInKey = 'is_logged_in';

// //   // Save login status
// //   Future<void> login() async {
// //     final prefs = await SharedPreferences.getInstance();
// //     await prefs.setBool(_isLoggedInKey, true);
// //   }

// //   // Clear login status
// //   Future<void> logout() async {
// //     final prefs = await SharedPreferences.getInstance();
// //     await prefs.remove(_isLoggedInKey);
// //   }

// //   // Check login status
// //   Future<bool> isLoggedIn() async {
// //     final prefs = await SharedPreferences.getInstance();
// //     return prefs.getBool(_isLoggedInKey) ?? false;
// //   }
// // }

// import 'package:shared_preferences/shared_preferences.dart';

// class AuthService {
//   static const _keyLoginId = 'loginId';
//   static const _keyEmpId = 'empId';
//   static const _keyRole = 'role';
//   static const _keyUsername = 'username';

//   // Save after successful login
//   static Future<void> saveSession({
//     required String loginId,
//     required String empId,
//     required String role,
//     required String username,
//   }) async {
//     final prefs = await SharedPreferences.getInstance();
//     await prefs.setString(_keyLoginId, loginId);
//     await prefs.setString(_keyEmpId, empId);
//     await prefs.setString(_keyRole, role);
//     await prefs.setString(_keyUsername, username);
//   }

//   // Read saved session
//   static Future<Map<String, String>?> getSession() async {
//     final prefs = await SharedPreferences.getInstance();
//     final loginId = prefs.getString(_keyLoginId);
//     if (loginId == null) return null; // not logged in
//     return {
//       'loginId': loginId,
//       'empId': prefs.getString(_keyEmpId) ?? '',
//       'role': prefs.getString(_keyRole) ?? '',
//       'username': prefs.getString(_keyUsername) ?? '',
//     };
//   }

//   // Call on logout
//   static Future<void> clearSession() async {
//     final prefs = await SharedPreferences.getInstance();
//     await prefs.clear();
//   }
// }
import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';

class AuthService {
  static const _keyLoginId = 'loginId';
  static const _keyEmpId = 'empId';
  static const _keyRole = 'role';
  static const _keyUsername = 'username';
  static const _keyToken = 'session_token'; // ✅ NEW
  static const _keyDeviceId = 'device_id'; // ✅ NEW

  static const String _baseUrl = 'http://192.168.29.216:3000';

  // ─── Get a stable unique device ID ─────────────────────────────────────────
  static Future<String> getDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    String? existing = prefs.getString(_keyDeviceId);
    if (existing != null) return existing;

    // Generate from device info
    String deviceId = 'unknown';
    try {
      final info = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final d = await info.androidInfo;
        deviceId = d.id; // Android ID
      } else if (Platform.isIOS) {
        final d = await info.iosInfo;
        deviceId = d.identifierForVendor ?? 'ios-unknown';
      }
    } catch (_) {
      deviceId = DateTime.now().millisecondsSinceEpoch.toString();
    }

    await prefs.setString(_keyDeviceId, deviceId);
    return deviceId;
  }

  // ─── Save after successful login ────────────────────────────────────────────
  static Future<void> saveSession({
    required String loginId,
    required String empId,
    required String role,
    required String username,
    required String sessionToken, // ✅ NEW
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLoginId, loginId);
    await prefs.setString(_keyEmpId, empId);
    await prefs.setString(_keyRole, role);
    await prefs.setString(_keyUsername, username);
    await prefs.setString(_keyToken, sessionToken); // ✅ save token
  }

  // ─── Read saved session ─────────────────────────────────────────────────────
  static Future<Map<String, String>?> getSession() async {
    final prefs = await SharedPreferences.getInstance();
    final loginId = prefs.getString(_keyLoginId);
    if (loginId == null) return null;
    return {
      'loginId': loginId,
      'empId': prefs.getString(_keyEmpId) ?? '',
      'role': prefs.getString(_keyRole) ?? '',
      'username': prefs.getString(_keyUsername) ?? '',
      'session_token': prefs.getString(_keyToken) ?? '',
    };
  }

  // ─── Validate session with server ──────────────────────────────────────────
  static Future<bool> validateSession() async {
    final session = await getSession();
    if (session == null) return false;

    final deviceId = await getDeviceId();

    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/auth/validate-session'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'login_id': session['loginId'],
              'session_token': session['session_token'],
              'device_id': deviceId,
            }),
          )
          .timeout(const Duration(seconds: 5));

      final data = jsonDecode(response.body);
      return data['valid'] == true;
    } catch (_) {
      return true; // ✅ allow offline use if server unreachable
    }
  }

  // ─── Logout — clears server + local ────────────────────────────────────────
  static Future<void> clearSession() async {
    final session = await getSession();
    if (session != null) {
      try {
        await http.post(
          Uri.parse('$_baseUrl/auth/logout'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'login_id': session['loginId']}),
        );
      } catch (_) {} // best-effort
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}
