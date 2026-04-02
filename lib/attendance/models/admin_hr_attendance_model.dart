// ── Site Visit ────────────────────────────────────────────────────────────────
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
      visitId: json['visit_id'] ?? 0,
      locationName: json['site_name'] ?? json['location_name'] ?? 'Unknown',
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

// ── Tracking Session ──────────────────────────────────────────────────────────
class SessionModel {
  final int sessionNumber;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final String? endReason;
  final int sessionMinutes;
  final int siteMinutes;
  final List<SiteVisitModel> visits;

  SessionModel({
    required this.sessionNumber,
    this.startedAt,
    this.endedAt,
    this.endReason,
    required this.sessionMinutes,
    required this.siteMinutes,
    required this.visits,
  });

  factory SessionModel.fromJson(Map<String, dynamic> json) {
    final visitList = (json['visits'] as List? ?? [])
        .map((v) => SiteVisitModel.fromJson(v as Map<String, dynamic>))
        .toList();
    return SessionModel(
      sessionNumber: json['session_number'] ?? 1,
      startedAt: json['started_at'] != null
          ? DateTime.parse(json['started_at']).toLocal()
          : null,
      endedAt: json['ended_at'] != null
          ? DateTime.parse(json['ended_at']).toLocal()
          : null,
      endReason: json['end_reason'] as String?,
      sessionMinutes: json['session_minutes'] as int? ?? 0,
      siteMinutes: json['site_minutes'] as int? ?? 0,
      visits: visitList,
    );
  }

  String get sessionDuration {
    final m = sessionMinutes;
    return '${m ~/ 60}h ${m % 60}m';
  }
}

// ── Employee Attendance ───────────────────────────────────────────────────────
class AttendanceAdminModel {
  final int empId;
  final String name;
  final String status; // PRESENT / ABSENT
  final List<SessionModel> sessions;

  AttendanceAdminModel({
    required this.empId,
    required this.name,
    required this.status,
    required this.sessions,
  });

  // ── Flat visits across all sessions (used for legacy visit count / summary)
  List<SiteVisitModel> get visits => sessions.expand((s) => s.visits).toList();

  DateTime? get inTime {
    for (final s in sessions) {
      for (final v in s.visits) {
        if (v.inTime != null) return v.inTime;
      }
    }
    return null;
  }

  DateTime? get outTime {
    DateTime? last;
    for (final s in sessions) {
      for (final v in s.visits) {
        if (v.outTime != null) {
          if (last == null || v.outTime!.isAfter(last)) last = v.outTime;
        }
      }
    }
    return last;
  }

  String? get workedHrs {
    final total = sessions.fold<int>(0, (sum, s) => sum + s.siteMinutes);
    if (total == 0) return null;
    return '${total ~/ 60}h ${total % 60}m';
  }

  String? get lateHrs => null;

  factory AttendanceAdminModel.fromJson(Map<String, dynamic> json) {
    // New backend: sessions[] with nested visits[]
    if (json.containsKey('sessions')) {
      final sessionList = (json['sessions'] as List? ?? [])
          .map((s) => SessionModel.fromJson(s as Map<String, dynamic>))
          .toList();
      return AttendanceAdminModel(
        empId: json['emp_id'] as int,
        name: json['name'] as String,
        status: json['attendance_status'] ?? 'ABSENT',
        sessions: sessionList,
      );
    }

    // Legacy backend: flat visits[] (TL team endpoint still uses old format)
    final flatVisits = (json['visits'] as List? ?? [])
        .map((v) => SiteVisitModel.fromJson(v as Map<String, dynamic>))
        .toList();

    SessionModel? legacySession;
    if (flatVisits.isNotEmpty) {
      final totalMin = flatVisits.fold<int>(
        0,
        (sum, v) => sum + (v.workedMinutes ?? 0),
      );
      legacySession = SessionModel(
        sessionNumber: 1,
        startedAt: flatVisits.first.inTime,
        endedAt: flatVisits.last.outTime,
        endReason: null,
        sessionMinutes: totalMin,
        siteMinutes: totalMin,
        visits: flatVisits,
      );
    }

    return AttendanceAdminModel(
      empId: json['emp_id'] as int,
      name: json['name'] as String,
      status: json['attendance_status'] ?? 'ABSENT',
      sessions: legacySession != null ? [legacySession] : [],
    );
  }
}
