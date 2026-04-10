// import 'dart:convert';
// import 'package:http/http.dart' as http;
// import '../models/asign_location.dart';

// class AssignLocationService {
//   static const String baseUrl = "http://localhost:3000";

//   /// ASSIGN LOCATION
//   static Future<Map<String, dynamic>> assignLocation({
//     required List<int> empIds,
//     required int locationId,
//     required String aboutWork,
//     required String startDate,
//     required String endDate,
//     String status = "Active", // default
//     String assignBy = "Admin", // Employee / HR / Admin
//     String? extendReason, // only if status = Extended
//   }) async {
//     final url = Uri.parse("$baseUrl/assign-location-and-get-list");

//     final body = {
//       "emp_ids": empIds,
//       "location_id": locationId,
//       "about_work": aboutWork,
//       "start_date": startDate,
//       "end_date": endDate,
//       "status": status,
//       "assign_by": assignBy,
//       "extend_reason": extendReason,
//     };

//     final response = await http.post(
//       url,
//       headers: {"Content-Type": "application/json"},
//       body: jsonEncode(body),
//     );

//     if (response.statusCode == 200 || response.statusCode == 201) {
//       return jsonDecode(response.body);
//     } else {
//       throw Exception("Assign failed: ${response.body}");
//     }
//   }

//   /// WORKING + FUTURE EMPLOYEES
//   static Future<List<AssignLocationModel>> getCurrentWorkingEmployees() async {
//     final response = await http.get(
//       Uri.parse("$baseUrl/working-today-and-future"),
//     );

//     if (response.statusCode == 200) {
//       final List data = jsonDecode(response.body);
//       return data.map((e) => AssignLocationModel.fromJson(e)).toList();
//     } else {
//       throw Exception("Failed to load employees");
//     }
//   }

//   /// SINGLE EMPLOYEE ASSIGNMENTS
//   static Future<List<AssignLocationModel>> getEmployeeAssignments(
//     int empId,
//   ) async {
//     final response = await http.get(
//       Uri.parse("$baseUrl/employee-assignments/$empId"),
//     );

//     if (response.statusCode == 200) {
//       final List data = jsonDecode(response.body);
//       return data.map((e) => AssignLocationModel.fromJson(e)).toList();
//     } else {
//       throw Exception("Failed to load assignments");
//     }
//   }
// }
// D:\Kavidhan Global tech\Employee Attendance System\employee_attendance_system\lib\attendance\services\asign_location_services.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/asign_location.dart';

class AssignLocationService {
  static const String baseUrl = "http://192.168.29.216:3000";

  // ── ASSIGN LOCATION ────────────────────────────────────────────────────────
  /// Assigns a location to one or more employees.
  /// Returns the success response map from the server.
  static Future<Map<String, dynamic>> assignLocation({
    required List<int> empIds,
    required int locationId,
    required String aboutWork,
    required String startDate, // "yyyy-MM-dd"
    required String endDate, // "yyyy-MM-dd"
    String assignBy = "Admin",
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse("$baseUrl/assign-location-and-get-list"),
            headers: {"Content-Type": "application/json"},
            body: jsonEncode({
              "emp_ids": empIds,
              "location_id": locationId,
              "about_work": aboutWork,
              "start_date": startDate,
              "end_date": endDate,
              "assign_by": assignBy,
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200 || response.statusCode == 201) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        throw Exception(
          "Assign failed (${response.statusCode}): ${response.body}",
        );
      }
    } on Exception {
      rethrow;
    }
  }

  // ── WORKING + FUTURE EMPLOYEES ─────────────────────────────────────────────
  /// Returns Active (working/future/not-completed) + Extended + Relieved
  /// (until their end date passes). Dates are plain "yyyy-MM-dd" strings.
  static Future<List<AssignLocationModel>> getCurrentWorkingEmployees() async {
    try {
      final response = await http
          .get(Uri.parse("$baseUrl/working-today-and-future"))
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body) as List;
        return data
            .map((e) => AssignLocationModel.fromJson(e as Map<String, dynamic>))
            .toList();
      } else {
        throw Exception(
          "Failed to load employees (${response.statusCode}): ${response.body}",
        );
      }
    } on Exception {
      rethrow;
    }
  }

  // ── ALL EMPLOYEES (for assignment tab) ─────────────────────────────────────
  /// Returns the full list from /working-today-and-future which includes all
  /// statuses needed for the "All Employees" assignment tab.
  static Future<List<AssignLocationModel>> getAllEmployees() async {
    return getCurrentWorkingEmployees();
  }

  // ── SINGLE EMPLOYEE ASSIGNMENTS ────────────────────────────────────────────
  /// Returns all assignment history for a single employee, newest first.
  static Future<List<AssignLocationModel>> getEmployeeAssignments(
    int empId,
  ) async {
    try {
      final response = await http
          .get(Uri.parse("$baseUrl/employee-assignments/$empId"))
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body) as List;
        return data
            .map((e) => AssignLocationModel.fromJson(e as Map<String, dynamic>))
            .toList();
      } else {
        throw Exception(
          "Failed to load assignments (${response.statusCode}): ${response.body}",
        );
      }
    } on Exception {
      rethrow;
    }
  }

  // ── UPDATE WORK STATUS ─────────────────────────────────────────────────────
  /// Updates the status of the latest assignment for an employee.
  /// [reason] is required for Relieved; [endDate] is required for Extended.
  static Future<void> updateWorkStatus({
    required int empId,
    required String status,
    required String updatedBy,
    String? reason,
    String? endDate, // "yyyy-MM-dd", only for Extended
  }) async {
    try {
      final body = <String, dynamic>{
        "empId": empId,
        "status": status,
        "updatedBy": updatedBy,
        if (reason != null) "reason": reason,
        if (endDate != null) "endDate": endDate,
      };

      final response = await http
          .post(
            Uri.parse("$baseUrl/update-work-status"),
            headers: {"Content-Type": "application/json"},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        throw Exception(
          "Update failed (${response.statusCode}): ${response.body}",
        );
      }
    } on Exception {
      rethrow;
    }
  }
}
