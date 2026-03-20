// import 'dart:convert';
// import 'package:http/http.dart' as http;
// import '../models/admin_hr_attendance_model.dart';

// class AdminHrAttendanceService {
//   static const String baseUrl = "http://192.168.29.216:3000";

//   static Future<List<AttendanceAdminModel>> fetchAttendance(String date) async {
//     final url = "$baseUrl/attendance/by-date?date=$date";

//     final response = await http.get(Uri.parse(url));

//     if (response.statusCode == 200) {
//       final List data = json.decode(response.body);
//       return data.map((e) => AttendanceAdminModel.fromJson(e)).toList();
//     } else {
//       throw Exception("Failed to load attendance");
//     }
//   }
// }
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/admin_hr_attendance_model.dart';

class AdminHrAttendanceService {
  static const String baseUrl = "http://192.168.29.103:3000";

  static Future<List<AttendanceAdminModel>> fetchAttendance(String date) async {
    final url = "$baseUrl/attendance/by-date-detail?date=$date";
    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      final body = json.decode(response.body);
      final List data = body['data'];
      return data.map((e) => AttendanceAdminModel.fromJson(e)).toList();
    } else {
      throw Exception("Failed to load attendance");
    }
  }
}
