import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/departmentmodel.dart';

class DepartmentService {
  final String baseUrl = "http://192.168.29.216:3000";

  /// GET ALL DEPARTMENTS
  Future<List<DepartmentModel>> fetchDepartments() async {
    final res = await http.get(Uri.parse("$baseUrl/departments"));

    if (res.statusCode == 200) {
      final Map<String, dynamic> json = jsonDecode(res.body);

      if (json['success'] == true && json['data'] != null) {
        final List data = json['data'];
        return data.map((e) => DepartmentModel.fromJson(e)).toList();
      } else {
        return [];
      }
    } else {
      throw Exception("Failed to load departments");
    }
  }

  /// ADD DEPARTMENT
  Future<void> addDepartment(String name) async {
    final res = await http.post(
      Uri.parse("$baseUrl/departments"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"department_name": name}),
    );

    if (res.statusCode != 200) {
      throw Exception("Failed to add department: ${res.body}");
    }
  }

  /// UPDATE STATUS
  Future<void> updateDepartmentStatus(int deptId, String status) async {
    final res = await http.put(
      Uri.parse("$baseUrl/departments/$deptId/status"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"status": status}),
    );

    if (res.statusCode != 200) {
      throw Exception("Failed to update department status: ${res.body}");
    }
  }

  /// TRANSFER EMPLOYEE
  Future<void> transferEmployee({
    required int empId,
    required int toDept,
    required String reason,
  }) async {
    final res = await http.put(
      Uri.parse("$baseUrl/departments/$toDept/transfer-employee"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"emp_id": empId, "reason": reason}),
    );

    if (res.statusCode != 200) {
      throw Exception("Employee transfer failed: ${res.body}");
    }
  }

  /// GET EMPLOYEES BY DEPARTMENT
  Future<List<Map<String, dynamic>>> fetchDeptEmployees(int deptId) async {
    final uri = Uri.parse("$baseUrl/departments/$deptId/employees");

    final res = await http
        .get(uri, headers: {"Accept": "application/json"})
        .timeout(const Duration(seconds: 5));

    if (res.statusCode == 200) {
      final List data = jsonDecode(res.body);
      return List<Map<String, dynamic>>.from(data);
    } else {
      throw Exception("Failed to load employees: ${res.body}");
    }
  }
}
