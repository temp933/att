import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/employee.dart';
import 'package:flutter/material.dart';
import '../models/employee_work_status.dart';

const String baseUrl = 'http://192.168.29.103:3000';

class EmployeeService {
  // ================= LOGIN =================
  static Future<Map<String, dynamic>> login(
    String username,
    String password, {
    String deviceId = '',
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'username': username,
        'password': password,
        'device_id': deviceId,
      }),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else if (response.statusCode == 403) {
      // ✅ Multi-device block
      throw Exception('Already logged in on another device. Logout first.');
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['message'] ?? error['error'] ?? 'Login failed');
    }
  }

  // ================= GET EMPLOYEE BY ID =================
  static Future<Employee> fetchEmployee(int empId) async {
    final response = await http.get(Uri.parse('$baseUrl/employees/$empId'));
    if (response.statusCode == 200) {
      return Employee.fromJson(jsonDecode(response.body));
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['error'] ?? 'Failed to fetch employee');
    }
  }

  // ================= DASHBOARD DATA =================
  static Future<Map<String, dynamic>> fetchDashboardData() async {
    final response = await http.get(Uri.parse('$baseUrl/dashboard'));
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception('Failed to fetch dashboard data');
    }
  }

  // ================= LEAVE STATUS SUMMARY =================
  static Future<List<LeaveData>> fetchLeaveStatusSummary() async {
    final response = await http.get(Uri.parse('$baseUrl/leave-status-summary'));
    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      return data.map((e) {
        Color color;
        switch (e['status']) {
          case 'Approved':
            color = Colors.green;
            break;
          case 'Pending':
            color = Colors.orange;
            break;
          case 'Rejected':
            color = Colors.red;
            break;

          case 'Not_Recommended_By_TL':
            color = const Color.fromARGB(167, 228, 10, 10);
            break;
          default:
            color = Colors.grey;
        }
        return LeaveData(e['status'], e['count'], color);
      }).toList();
    } else {
      throw Exception('Failed to fetch leave status summary');
    }
  }

  // ================= LEAVE TYPE SUMMARY =================
  static List<LeaveData> getLeaveChartData(Map<String, dynamic> json) {
    return [
      LeaveData('Sick', json['sick'] ?? 0, Colors.red),
      LeaveData('Casual', json['casual'] ?? 0, Colors.blue),
      LeaveData('Paid', json['paid'] ?? 0, Colors.green),
      LeaveData('Unpaid', json['unpaid'] ?? 0, Colors.orange),
    ];
  }

  // ================= GET ALL REQUESTS =================
  static Future<List<Employee>> fetchAllRequests() async {
    final response = await http.get(Uri.parse('$baseUrl/admin/requests'));
    if (response.statusCode == 200) {
      final List list = jsonDecode(response.body)['data'];
      return list.map((e) => Employee.fromJson(e)).toList();
    } else {
      throw Exception('Failed to fetch requests');
    }
  }

  // ================= GET ALL EMPLOYEES =================
  static Future<List<Employee>> fetchAllEmployees() async {
    final response = await http.get(Uri.parse('$baseUrl/all-employees'));
    if (response.statusCode == 200) {
      final List list = jsonDecode(response.body)['data'];
      return list.map((e) => Employee.fromJson(e)).toList();
    } else {
      throw Exception('Failed to fetch employees');
    }
  }

  // ================= EMPLOYEES WITH WORK =================
  static Future<List<EmployeeWorkStatus>> fetchEmployeesWithWork() async {
    final response = await http.get(Uri.parse('$baseUrl/employees-with-work'));
    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      return data.map((e) => EmployeeWorkStatus.fromJson(e)).toList();
    } else {
      throw Exception("Failed to load employees with work");
    }
  }

  // ================= GET EMPLOYEE WORK HOURS =================
  static Future<Map<String, String>> fetchEmployeeWorkHours(int empId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/employee-work-hours/$empId'),
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return {
        "today": data["today"]?.toString() ?? "0h 0m",
        "week": data["week"]?.toString() ?? "0h 0m",
      };
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['error'] ?? 'Failed to fetch work hours');
    }
  }

  // ================= ASSIGN LOCATION =================
  static Future<void> assignLocation({
    required int empId,
    required int locationId,
    required String aboutWork,
    required String startDate,
    required String endDate,
    required String doneBy,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/assign-location'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        "emp_id": empId,
        "location_id": locationId,
        "about_work": aboutWork,
        "start_date": startDate,
        "end_date": endDate,
        "done_by": doneBy,
      }),
    );
    if (response.statusCode != 200) {
      final error = jsonDecode(response.body);
      throw Exception(error['error'] ?? 'Failed to assign location');
    }
  }

  // ================= GET DEPARTMENTS =================
  static Future<List<Map<String, dynamic>>> fetchDepartments() async {
    final response = await http.get(Uri.parse('$baseUrl/departments'));
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return List<Map<String, dynamic>>.from(data['data']);
    } else {
      throw Exception("Failed to load departments");
    }
  }

  // ================= GET ROLES =================
  static Future<List<Map<String, dynamic>>> fetchRoles() async {
    final response = await http.get(Uri.parse('$baseUrl/roles'));
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return List<Map<String, dynamic>>.from(data['data']);
    } else {
      throw Exception("Failed to load roles");
    }
  }

  /// Fetch education records from MASTER table (approved employee)
  static Future<List<Education>> fetchEducation(int empId) async {
    final res = await http.get(
      Uri.parse('$baseUrl/employees/$empId/education'),
    );

    if (res.statusCode == 200) {
      final List list = jsonDecode(res.body)['data'];
      return list.map((e) => Education.fromJson(e)).toList();
    }

    throw Exception('Failed to fetch education records');
  }

  static Future<void> addEducation(int empId, Map<String, dynamic> data) async {
    final res = await http.post(
      Uri.parse('$baseUrl/employees/$empId/education'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(data),
    );

    final body = jsonDecode(res.body);

    // ✅ FIX: backend blocked write because a pending request exists.
    // Auto-redirect to education_pending_request instead.
    if (res.statusCode == 403 && body['pending'] == true) {
      final requestId = body['request_id'];
      if (requestId == null) throw Exception('Pending request ID missing');
      return addPendingEducation(requestId, data);
    }

    if (res.statusCode != 200 || body['success'] != true) {
      throw Exception(body['message'] ?? 'Failed to add education');
    }
  }

  /// Update education in MASTER — auto-redirects to pending if blocked (403).
  static Future<void> updateEducation(
    int eduId,
    Map<String, dynamic> data,
  ) async {
    final res = await http.put(
      Uri.parse('$baseUrl/education/$eduId'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(data),
    );

    final body = jsonDecode(res.body);

    // ✅ FIX: auto-redirect to pending on 403.
    if (res.statusCode == 403 && body['pending'] == true) {
      final requestId = body['request_id'];
      if (requestId == null) throw Exception('Pending request ID missing');
      return updatePendingEducation(eduId, data);
    }

    if (res.statusCode != 200 || body['success'] != true) {
      throw Exception(body['message'] ?? 'Failed to update education');
    }
  }

  /// Delete education from MASTER — auto-redirects to pending if blocked (403).
  static Future<void> deleteEducation(int eduId) async {
    final res = await http.delete(Uri.parse('$baseUrl/education/$eduId'));

    final body = jsonDecode(res.body);

    // ✅ FIX: auto-redirect to pending on 403.
    if (res.statusCode == 403 && body['pending'] == true) {
      final requestId = body['request_id'];
      if (requestId == null) throw Exception('Pending request ID missing');
      return deletePendingEducation(eduId);
    }

    if (res.statusCode != 200 || body['success'] != true) {
      throw Exception(body['message'] ?? 'Failed to delete education');
    }
  }

  //PENDING EDUCATION (BEFORE ADMIN APPROVAL)

  /// Fetch pending education by requestId
  static Future<List<Education>> fetchPendingEducation(int requestId) async {
    final res = await http.get(
      Uri.parse('$baseUrl/requests/$requestId/education'),
    );

    if (res.statusCode == 200) {
      final List list = jsonDecode(res.body)['data'];
      return list.map((e) => Education.fromJson(e)).toList();
    }

    throw Exception('Failed to fetch pending education');
  }

  /// Add pending education (request stage)
  static Future<void> addPendingEducation(
    int requestId,
    Map<String, dynamic> data,
  ) async {
    final res = await http.post(
      Uri.parse("$baseUrl/requests/$requestId/education"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(data),
    );
    final body = jsonDecode(res.body);
    if (res.statusCode != 200 || body['success'] != true) {
      throw Exception(body['message'] ?? "Failed to add pending education");
    }
  }

  static Future<void> updatePendingEducation(
    int eduReqId,
    Map<String, dynamic> data,
  ) async {
    final res = await http.put(
      Uri.parse("$baseUrl/requests/education/$eduReqId"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(data),
    );
    final body = jsonDecode(res.body);
    if (res.statusCode != 200 || body['success'] != true) {
      throw Exception(body['message'] ?? "Failed to update pending education");
    }
  }

  static Future<void> deletePendingEducation(int eduReqId) async {
    final res = await http.delete(
      Uri.parse("$baseUrl/requests/education/$eduReqId"),
    );
    final body = jsonDecode(res.body);
    if (res.statusCode != 200 || body['success'] != true) {
      throw Exception(body['message'] ?? "Failed to delete pending education");
    }
  }

  // ── Check if employee has a pending request ────────────────────────────────

  static Future<int?> getPendingRequestId(int empId) async {
    final res = await http.get(
      Uri.parse("$baseUrl/employees/$empId/pending-request"),
    );
    if (res.statusCode == 200) {
      final body = jsonDecode(res.body);
      if (body['pending'] == true) return body['request_id'];
    }
    return null;
  }

  // ================= LEAVE HISTORY =================
  static Future<List<Map<String, dynamic>>> fetchLeaveHistory(int empId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/leave-history?emp_id=$empId'), // pass emp_id here
    );

    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      if (body['success'] == true) {
        return List<Map<String, dynamic>>.from(body['data']);
      } else {
        throw Exception(body['message'] ?? 'Failed to fetch leave history');
      }
    } else {
      final body = jsonDecode(response.body);
      throw Exception(body['message'] ?? 'Failed to fetch leave history');
    }
  }

  // ================= PENDING TL LEAVES =================
  static Future<List<Map<String, dynamic>>> fetchPendingTLLeaves() async {
    final response = await http.get(Uri.parse('$baseUrl/leaves/pending-tl'));

    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      if (body['success'] == true) {
        return List<Map<String, dynamic>>.from(body['data']);
      } else {
        throw Exception(body['message'] ?? 'Failed to fetch pending TL leaves');
      }
    } else {
      final body = jsonDecode(response.body);
      throw Exception(body['message'] ?? 'Failed to fetch pending TL leaves');
    }
  }

  // ================= HR ACTION =================
  static Future<void> hrAction(
    int leaveId,
    String status,
    int loginId, {
    String? rejectionReason,
  }) async {
    final response = await http.put(
      Uri.parse('$baseUrl/leave/$leaveId/hr-action'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'status': status,
        'login_id': loginId,
        'rejection_reason': rejectionReason,
      }),
    );

    final body = jsonDecode(response.body);
    if (response.statusCode != 200 || body['success'] != true) {
      throw Exception(body['message'] ?? 'Failed to update leave status');
    }
  }

  // ================= TL ACTION =================
  static Future<void> tlAction(
    int leaveId,
    String action,
    int loginId, {
    String? rejectionReason,
  }) async {
    final response = await http.put(
      Uri.parse('$baseUrl/leave/$leaveId/tl-action'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'action': action,
        'login_id': loginId,
        'rejection_reason': rejectionReason,
      }),
    );

    final body = jsonDecode(response.body);
    if (response.statusCode != 200 || body['success'] != true) {
      throw Exception(body['message'] ?? 'Failed to perform TL action');
    }
  }
}

class LeaveData {
  final String status;
  final int count;
  final Color color;
  const LeaveData(this.status, this.count, this.color); // ✅ const
}
