// // D:\Kavidhan Global tech\Employee Attendance System\employee_attendance_system\lib\attendance\services\attendance_service.dart

// import 'dart:convert';
// import 'package:http/http.dart' as http;

// class AttendanceService {
//   final String baseUrl = "http://192.168.29.216:3000";

//   /// Check-In
//   Future<void> checkIn({
//     required int empId,
//     required double latitude,
//     required double longitude,
//     required String locationNickName,
//   }) async {
//     final url = Uri.parse("$baseUrl/attendance/checkin");

//     final response = await http.post(
//       url,
//       headers: {"Content-Type": "application/json"},
//       body: jsonEncode({
//         "emp_id": empId,
//         "latitude": latitude,
//         "longitude": longitude,
//         "location_nick_name": locationNickName,
//       }),
//     );

//     final data = jsonDecode(response.body) as Map<String, dynamic>;

//     if (response.statusCode != 200 && response.statusCode != 201) {
//       // Throws clean message from server (e.g. "Already Checked In")
//       throw Exception(data['message'] ?? data['error'] ?? 'Check-in failed');
//     }

//     print("Check-In Success: ${data['message']}");
//   }

//   /// Check-Out
//   Future<void> checkOut({required int empId}) async {
//     final url = Uri.parse("$baseUrl/attendance/checkout");

//     final response = await http.post(
//       url,
//       headers: {"Content-Type": "application/json"},
//       body: jsonEncode({"emp_id": empId}),
//     );

//     final data = jsonDecode(response.body) as Map<String, dynamic>;

//     if (response.statusCode != 200 && response.statusCode != 201) {
//       // Throws clean message from server (e.g. "No active check-in found")
//       throw Exception(data['message'] ?? data['error'] ?? 'Check-out failed');
//     }

//     print("Check-Out Success: ${data['message']}");
//   }
// }

import 'api_service.dart';

class AttendanceService {
  /// Mark employee IN at a specific site.
  Future<void> checkIn({required int empId, required int siteId}) async {
    await ApiService.markIn(empId, siteId);
  }

  /// Mark employee OUT (close open row).
  Future<void> checkOut({required int empId}) async {
    await ApiService.markOut(empId);
  }

  /// End the whole work day — locks attendance for today.
  Future<void> endDay({required int empId}) async {
    await ApiService.endDay(empId);
  }
}
