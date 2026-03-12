// class AttendanceAdminModel {
//   final int empId;
//   final String name;
//   final String status;
//   final DateTime? inTime;
//   final DateTime? outTime;
//   final String? workedHrs;
//   final String? lateHrs;

//   AttendanceAdminModel({
//     required this.empId,
//     required this.name,
//     required this.status,
//     this.inTime,
//     this.outTime,
//     this.workedHrs,
//     this.lateHrs,
//   });

//   factory AttendanceAdminModel.fromJson(Map<String, dynamic> json) {
//     return AttendanceAdminModel(
//       empId: json['emp_id'],
//       name: json['name'],
//       status: json['attendance_status'],
//       inTime: json['in_time_date'] == null
//           ? null
//           : DateTime.parse(json['in_time_date']).toLocal(),

//       outTime: json['out_time_date'] == null
//           ? null
//           : DateTime.parse(json['out_time_date']).toLocal(),
//       workedHrs: json['worked_hrs']?.toString(),
//       lateHrs: json['late_hrs']?.toString(),
//     );
//   }
// }
class SiteVisitModel {
  final int visitId;
  final String locationName;
  final DateTime? inTime;
  final DateTime? outTime;
  final int? workedMinutes;
  final String status;

  SiteVisitModel({
    required this.visitId,
    required this.locationName,
    this.inTime,
    this.outTime,
    this.workedMinutes,
    required this.status,
  });

  factory SiteVisitModel.fromJson(Map<String, dynamic> json) {
    return SiteVisitModel(
      visitId: json['visit_id'],
      locationName: json['location_name'] ?? 'Unknown',
      inTime: json['in_time'] != null
          ? DateTime.parse(json['in_time']).toLocal()
          : null,
      outTime: json['out_time'] != null
          ? DateTime.parse(json['out_time']).toLocal()
          : null,
      workedMinutes: json['worked_minutes'] as int?,
      status: json['status'] ?? '',
    );
  }

  String get workedFormatted {
    if (workedMinutes == null) return '--';
    final h = workedMinutes! ~/ 60;
    final m = workedMinutes! % 60;
    return '${h}h ${m}m';
  }
}

class AttendanceAdminModel {
  final int empId;
  final String name;
  final String status; // PRESENT / ABSENT
  final List<SiteVisitModel> visits;

  // Legacy fields kept for summary card counts
  DateTime? get inTime => visits.isNotEmpty ? visits.first.inTime : null;
  DateTime? get outTime => visits.isNotEmpty ? visits.last.outTime : null;

  String? get workedHrs {
    final total = visits.fold<int>(0, (sum, v) => sum + (v.workedMinutes ?? 0));
    if (total == 0) return null;
    return '${total ~/ 60}h ${total % 60}m';
  }

  String? get lateHrs => null; // extend later if needed

  AttendanceAdminModel({
    required this.empId,
    required this.name,
    required this.status,
    required this.visits,
  });

  factory AttendanceAdminModel.fromJson(Map<String, dynamic> json) {
    final visitsList = (json['visits'] as List? ?? [])
        .map((v) => SiteVisitModel.fromJson(v))
        .toList();
    return AttendanceAdminModel(
      empId: json['emp_id'],
      name: json['name'],
      status: json['attendance_status'] ?? 'ABSENT',
      visits: visitsList,
    );
  }
}
