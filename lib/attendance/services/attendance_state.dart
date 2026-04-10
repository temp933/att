import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';

enum DayStatus { notStarted, inProgress }

class AttendanceState {
  AttendanceState._();
  static final AttendanceState instance = AttendanceState._();

  DayStatus dayStatus = DayStatus.notStarted;
  bool isInsideSite = false;
  String currentSiteName = '';
  int? currentSessionId;
  int sessionCountToday = 0;
  DateTime? currentSessionStart;
  int _empId = -1;
  bool isLate = false;
  int lateMinutes = 0;
  double lateHours = 0.0;
  String? lateText; // e.g. "1hr 15min" or "Half Day"

  // ── Check status ───────────────────────────────────────────────────────────
  Future<DayStatus> checkStatus(int empId) async {
    _empId = empId;
    try {
      final data = await ApiService.getTodayStatus(empId);
      final status = data['status'] as String? ?? 'not_started';

      if (status == 'in_progress') {
        currentSessionId = data['session_id'] as int?;
        sessionCountToday = data['session_number'] as int? ?? 1;
        dayStatus = DayStatus.inProgress;
      } else {
        sessionCountToday = data['sessions_today'] as int? ?? 0;
        dayStatus = DayStatus.notStarted;
        isInsideSite = false;
        currentSiteName = '';
        currentSessionId = null;
      }
    } catch (_) {
      // Offline fallback
      final svc = FlutterBackgroundService();
      if (await svc.isRunning()) {
        dayStatus = DayStatus.inProgress;
      } else {
        dayStatus = DayStatus.notStarted;
        isInsideSite = false;
        currentSiteName = '';
        currentSessionId = null;
      }
    }
    return dayStatus;
  }

  void confirmStart() {
    sessionCountToday += 1;
  }

  // ── START — always fresh ───────────────────────────────────────────────────
  Future<void> start(int empId) async {
    _empId = empId;
    currentSessionStart = DateTime.now();
    isInsideSite = false;
    currentSiteName = '';

    // BEFORE: final sessionId = await ApiService.startSession(empId);
    // AFTER:
    final data = await ApiService.startSession(empId);
    currentSessionId = data['session_id'] as int?;

    // Capture late entry info from server response
    isLate = data['is_late'] == true;
    lateMinutes = (data['late_minutes'] as num?)?.toInt() ?? 0;
    lateHours = (data['late_hours'] as num?)?.toDouble() ?? 0.0;
    lateText = data['late_text'] as String?;

    dayStatus = DayStatus.inProgress;
  }

  // ── END — full reset ───────────────────────────────────────────────────────
  Future<void> end() async {
    dayStatus = DayStatus.notStarted;
    isInsideSite = false;
    currentSiteName = '';
    currentSessionId = null;
    currentSessionStart = null;
    isLate = false; // ADD
    lateMinutes = 0; // ADD
    lateHours = 0.0; // ADD
    lateText = null; // ADD
  }

  Future<void> cancelStart(int empId) async {
    try {
      if (currentSessionId != null) {
        await ApiService.cancelSession(empId, currentSessionId!);
      }
    } catch (e) {
      print('[AttendanceState] cancelStart API failed: $e');
    } finally {
      dayStatus = DayStatus.notStarted;
      isInsideSite = false;
      currentSiteName = '';
      currentSessionId = null;
      currentSessionStart = null;
      isLate = false; // ADD
      lateMinutes = 0; // ADD
      lateHours = 0.0; // ADD
      lateText = null; // ADD
      if (sessionCountToday > 0) sessionCountToday -= 1;
    }
  }

  // ── Force stop (logout) ────────────────────────────────────────────────────
  Future<void> forceStop() async {
    dayStatus = DayStatus.notStarted;
    isInsideSite = false;
    currentSiteName = '';
    currentSessionId = null;
    currentSessionStart = null;
    sessionCountToday = 0;
    _empId = -1;
  }

  void updateSiteStatus(bool inside, String siteName) {
    isInsideSite = inside;
    currentSiteName = siteName;
  }

  String get sessionDuration {
    if (currentSessionStart == null) return '--';
    final d = DateTime.now().difference(currentSessionStart!);
    final h = d.inHours;
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    return h > 0 ? '${h}h ${m}m' : '${d.inMinutes}m';
  }

  bool get hasActivityToday => sessionCountToday > 0;
}
