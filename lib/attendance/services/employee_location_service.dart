import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/employee_location_model.dart';

class EmployeeLocationService {
  final String baseUrl = "http://192.168.29.216:3000";

  Future<EmployeeLocationAssignment?> fetchEmployeeLocation(int empId) async {
    final response = await http.get(
      Uri.parse("$baseUrl/employee-location/$empId"),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);

      if (data["assigned"] == false) {
        return null; // not assigned
      }

      return EmployeeLocationAssignment.fromJson(data);
    } else {
      throw Exception("Failed to fetch employee location");
    }
  }
}
