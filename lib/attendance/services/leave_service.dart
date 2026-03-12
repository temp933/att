import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/leavemodel.dart';

class LeaveService {
  final String baseUrl = "http://192.168.29.216:3000";

  // ── Pending leaves (old endpoint — keep for backward compat) ─────────────
  Future<List<LeaveModel>> getPendingLeaves() async {
    final response = await http.get(
      Uri.parse("$baseUrl/leaves/pending/details"),
    );
    if (response.statusCode == 200) {
      final decoded = json.decode(response.body);
      List data = decoded['data'];
      return data.map((e) => LeaveModel.fromPendingJson(e)).toList();
    } else {
      throw Exception("Failed to load pending leaves");
    }
  }

  // ── Leaves pending TL review (status = Pending_TL) ───────────────────────
  Future<List<LeaveModel>> getPendingTLLeaves() async {
    final response = await http.get(Uri.parse("$baseUrl/leaves/pending-tl"));
    if (response.statusCode == 200) {
      final decoded = json.decode(response.body);
      if (decoded['success'] == true) {
        List data = decoded['data'];
        return data.map((e) => LeaveModel.fromPendingJson(e)).toList();
      }
    }
    return [];
  }

  // ── Leaves pending HR review (status = Pending_HR) ───────────────────────
  Future<List<LeaveModel>> getPendingHRLeaves() async {
    final response = await http.get(Uri.parse("$baseUrl/leaves/pending-hr"));
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

  // ── HR/Admin action: Approved or Rejected_By_HR ──────────────────────────
  Future<bool> hrLeaveAction({
    required int leaveId,
    required String status, // "Approved" | "Rejected_By_HR"
    required int loginId,
    String? rejectionReason,
  }) async {
    final response = await http.put(
      Uri.parse("$baseUrl/leave/$leaveId/hr-action"),
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

  // ── Update leave status (old method — keep for backward compat) ──────────
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

  // ── Leave history ─────────────────────────────────────────────────────────


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
}
