import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/leavemodel.dart';

class LeaveService {
  final String baseUrl = "http://192.168.29.216:3000";

  // ── Employee: fetch own leaves ────────────────────────────────────────────
  Future<List<LeaveModel>> getEmployeeLeaves(int empId) async {
    final response = await http.get(
      Uri.parse("$baseUrl/employees/$empId/leaves"),
    );
    if (response.statusCode == 200) {
      final decoded = json.decode(response.body);
      if (decoded['success'] == true) {
        List data = decoded['data'];
        return data.map((e) => LeaveModel.fromPendingJson(e)).toList();
      }
    }
    return [];
  }

  // ── TL: leaves waiting for TL review ────────────────────────────────────
  // Future<List<LeaveModel>> getPendingTLLeaves() async {
  //   final response = await http.get(Uri.parse("$baseUrl/leaves/pending-tl"));
  //   if (response.statusCode == 200) {
  //     final decoded = json.decode(response.body);
  //     if (decoded['success'] == true) {
  //       List data = decoded['data'];
  //       return data.map((e) => LeaveModel.fromPendingJson(e)).toList();
  //     }
  //   }
  //   return [];
  // }

  Future<List<LeaveModel>> getPendingTLLeaves(int loginId) async {
    final response = await http.get(
      Uri.parse("$baseUrl/leaves/pending-tl?login_id=$loginId"),
    );
    if (response.statusCode == 200) {
      final decoded = json.decode(response.body);
      if (decoded['success'] == true) {
        List data = decoded['data'];
        return data.map((e) => LeaveModel.fromPendingJson(e)).toList();
      }
    }
    return [];
  }

  Future<List<LeaveModel>> getPendingManagerLeaves() async {
    final response = await http.get(
      Uri.parse("$baseUrl/leaves/pending-manager"),
    );
    if (response.statusCode == 200) {
      final decoded = json.decode(response.body);
      if (decoded['success'] == true) {
        List data = decoded['data'];
        return data.map((e) => LeaveModel.fromPendingJson(e)).toList();
      }
    }
    return [];
  }

  // FIX: alias kept for backward compat — routes to same manager endpoint
  Future<List<LeaveModel>> getPendingHRLeaves() => getPendingManagerLeaves();

  // ── All pending leaves (admin overview) ─────────────────────────────────
  Future<List<LeaveModel>> getAllPendingLeaves() async {
    final response = await http.get(Uri.parse("$baseUrl/leaves/all-pending"));
    if (response.statusCode == 200) {
      final decoded = json.decode(response.body);
      if (decoded['success'] == true) {
        List data = decoded['data'];
        return data.map((e) => LeaveModel.fromPendingJson(e)).toList();
      }
    }
    return [];
  }

  // ── TL action: recommend or not_recommend ────────────────────────────────
  Future<bool> tlLeaveAction({
    required int leaveId,
    required String action, // "recommend" | "not_recommend"
    required int loginId,
    String? rejectionReason,
  }) async {
    final response = await http.put(
      Uri.parse("$baseUrl/leave/$leaveId/tl-action"),
      headers: {"Content-Type": "application/json"},
      body: json.encode({
        "action": action,
        "login_id": loginId,
        if (rejectionReason != null) "rejection_reason": rejectionReason,
      }),
    );
    if (response.statusCode == 200) {
      final decoded = json.decode(response.body);
      return decoded['success'] == true;
    }
    return false;
  }

  Future<bool> managerLeaveAction({
    required int leaveId,
    required String status, // "Approved" | "Rejected_By_Manager"
    required int loginId,
    String? rejectionReason,
  }) async {
    final response = await http.put(
      Uri.parse("$baseUrl/leave/$leaveId/manager-action"),
      headers: {"Content-Type": "application/json"},
      body: json.encode({
        "status": status,
        "login_id": loginId,
        if (rejectionReason != null) "rejection_reason": rejectionReason,
      }),
    );
    if (response.statusCode == 200) {
      final decoded = json.decode(response.body);
      return decoded['success'] == true;
    }
    return false;
  }

  // ── Leave history for a single employee ──────────────────────────────────
  Future<List<LeaveModel>> getAllLeaveHistory(int empId) async {
    final response = await http.get(
      Uri.parse("$baseUrl/leave-history?emp_id=$empId"),
    );
    if (response.statusCode == 200) {
      final decoded = json.decode(response.body);
      if (decoded['success'] == true) {
        List data = decoded['data'];
        return data.map((e) => LeaveModel.fromHistoryJson(e)).toList();
      } else {
        throw Exception(decoded['message']);
      }
    } else {
      throw Exception("Failed to load leave history");
    }
  }

  // ── Full leave history (admin view) ──────────────────────────────────────
  Future<List<LeaveModel>> getAllLeavesHistory() async {
    final response = await http.get(Uri.parse("$baseUrl/leaves/all-history"));
    if (response.statusCode == 200) {
      final decoded = json.decode(response.body);
      if (decoded['success'] == true) {
        List data = decoded['data'];
        return data.map((e) => LeaveModel.fromHistoryJson(e)).toList();
      }
    }
    return [];
  }

  // ── Update leave status (legacy — kept for backward compat) ─────────────
  Future<bool> updateLeaveStatus(
    int leaveId,
    String status, {
    String? reason,
    required int loginId,
  }) async {
    final response = await http.put(
      Uri.parse("$baseUrl/leave/$leaveId/status"),
      headers: {"Content-Type": "application/json"},
      body: json.encode({
        "status": status,
        "login_id": loginId,
        if (reason != null) "rejection_reason": reason,
      }),
    );
    return response.statusCode == 200;
  }

  Future<List<LeaveModel>> getTLLeavesHistory(int loginId) async {
    final response = await http.get(
      Uri.parse("$baseUrl/leaves/tl-history?login_id=$loginId"),
    );
    if (response.statusCode == 200) {
      final decoded = json.decode(response.body);
      if (decoded['success'] == true) {
        List data = decoded['data'];
        return data.map((e) => LeaveModel.fromHistoryJson(e)).toList();
      }
    }
    return [];
  }
}
