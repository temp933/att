import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/location_modules.dart';

class LocationService {
  final String baseUrl = "http://192.168.29.103:3000";  

  /// GET all locations
  Future<List<LocationManager>> fetchLocations() async {
    final response = await http.get(Uri.parse("$baseUrl/locations"));

    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      return data.map((e) => LocationManager.fromJson(e)).toList();
    } else {
      throw Exception("Failed to load locations");
    }
  }

  /// ADD new location (endDate optional)
  Future<void> addLocationToDb({
    required String nickName,
    required double latitude,
    required double longitude,
    required DateTime startDate,
    DateTime? endDate, // ✅ make nullable
    String? contactPersonName,
    String? contactPersonNumber,
  }) async {
    final url = Uri.parse("$baseUrl/locations");

    final response = await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "nick_name": nickName,
        "latitude": latitude,
        "longitude": longitude,
        "start_date": startDate.toIso8601String(),
        "end_date": endDate?.toIso8601String(), // ✅ handle null safely
        "contact_person_name": contactPersonName ?? "",
        "contact_person_number": contactPersonNumber ?? "",
      }),
    );

    // Debugging logs
    print("STATUS CODE: ${response.statusCode}");
    print("RESPONSE BODY: ${response.body}");

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception("Failed to add location: ${response.body}");
    }
  }
}
