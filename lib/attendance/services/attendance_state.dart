// import 'package:flutter_background_service/flutter_background_service.dart';
// import 'package:shared_preferences/shared_preferences.dart';
// import 'api_service.dart';

// enum DayStatus { notStarted, inProgress }

// class AttendanceState {
//   AttendanceState._();
//   static final AttendanceState instance = AttendanceState._();

//   DayStatus dayStatus = DayStatus.notStarted;
//   bool isInsideSite = false;
//   String currentSiteName = '';
//   int? currentSessionId;
//   int sessionCountToday = 0;
//   DateTime? currentSessionStart;

//   int _empId = -1;

//   String get _activeKey => 'tracking_active_$_empId';
//   String get _sessionIdKey => 'session_id_$_empId';
//   String get _sessionStart => 'session_start_$_empId';
//   String get _sessionCount => 'session_count_$_empId';

//   // ── checkStatus ────────────────────────────────────────────────────────────
//   Future<DayStatus> checkStatus(int empId) async {
//     if (empId != _empId) _resetFor(empId);
//     final prefs = await SharedPreferences.getInstance();

//     try {
//       final data = await ApiService.getTodayStatus(empId);
//       final status = data['status'] as String? ?? 'not_started';

//       if (status == 'in_progress') {
//         currentSessionId = data['session_id'] as int?;
//         sessionCountToday = data['session_number'] as int? ?? 1;
//         dayStatus = DayStatus.inProgress;

//         await prefs.setInt('employee_id', empId);
//         await prefs.setBool(_activeKey, true);
//         if (currentSessionId != null) {
//           await prefs.setInt(_sessionIdKey, currentSessionId!);
//         }
//         _recoverSessionStart(prefs);

//         if (!await FlutterBackgroundService().isRunning()) {
//           await FlutterBackgroundService().startService();
//         }
//         return dayStatus;
//       }

//       // not_started — between sessions or never started today
//       sessionCountToday = data['sessions_today'] as int? ?? 0;
//       dayStatus = DayStatus.notStarted;
//       isInsideSite = false;
//       currentSiteName = '';
//       currentSessionId = null;
//       await prefs.setBool(_activeKey, false);
//       return dayStatus;
//     } catch (_) {
//       // Offline fallback
//       final active = prefs.getBool(_activeKey) ?? false;
//       if (active) {
//         currentSessionId = prefs.getInt(_sessionIdKey);
//         sessionCountToday = prefs.getInt(_sessionCount) ?? 1;
//         dayStatus = DayStatus.inProgress;
//         _recoverSessionStart(prefs);
//         if (!await FlutterBackgroundService().isRunning()) {
//           await prefs.setInt('employee_id', empId);
//           await FlutterBackgroundService().startService();
//         }
//       } else {
//         dayStatus = DayStatus.notStarted;
//         isInsideSite = false;
//         currentSiteName = '';
//         currentSessionId = null;
//       }
//       return dayStatus;
//     }
//   }

//   // ── start ──────────────────────────────────────────────────────────────────
//   Future<void> start(int empId) async {
//     _empId = empId;
//     final prefs = await SharedPreferences.getInstance();
//     currentSessionStart = DateTime.now();
//     sessionCountToday += 1;

//     // Reset site state for new session
//     isInsideSite = false;
//     currentSiteName = '';

//     // Open a new session row on the server
//     final sessionId = await ApiService.startSession(empId);
//     currentSessionId = sessionId;

//     await prefs.setInt('employee_id', empId);
//     await prefs.setBool(_activeKey, true);
//     await prefs.setString(
//       _sessionStart,
//       currentSessionStart!.toIso8601String(),
//     );
//     await prefs.setInt(_sessionCount, sessionCountToday);
//     if (sessionId != null) await prefs.setInt(_sessionIdKey, sessionId);

//     dayStatus = DayStatus.inProgress;
//   }

//   // ── end ────────────────────────────────────────────────────────────────────
//   Future<void> end() async {
//     final prefs = await SharedPreferences.getInstance();
//     await prefs.setBool(_activeKey, false);
//     await prefs.remove(_sessionStart);
//     // Keep session count — badge persists across sessions

//     dayStatus = DayStatus.notStarted;
//     isInsideSite = false;
//     currentSiteName = '';
//     currentSessionId = null;
//     currentSessionStart = null;
//   }

//   // ── forceStop — logout (admin or user) ────────────────────────────────────
//   Future<void> forceStop() async {
//     final prefs = await SharedPreferences.getInstance();
//     try {
//       if (await FlutterBackgroundService().isRunning()) {
//         FlutterBackgroundService().invoke('force_stop');
//       }
//     } catch (_) {}

//     await prefs.remove(_activeKey);
//     await prefs.remove(_sessionStart);
//     await prefs.remove(_sessionIdKey);
//     await prefs.remove(_sessionCount);
//     await prefs.remove('employee_id');
//     await prefs.remove('current_site_id_$_empId');

//     dayStatus = DayStatus.notStarted;
//     isInsideSite = false;
//     currentSiteName = '';
//     currentSessionId = null;
//     currentSessionStart = null;
//     sessionCountToday = 0;
//     _empId = -1;
//   }

//   void updateSiteStatus(bool inside, String siteName) {
//     isInsideSite = inside;
//     currentSiteName = siteName;
//   }

//   void _resetFor(int empId) {
//     _empId = empId;
//     dayStatus = DayStatus.notStarted;
//     isInsideSite = false;
//     currentSiteName = '';
//     currentSessionId = null;
//     currentSessionStart = null;
//     sessionCountToday = 0;
//   }

//   void _recoverSessionStart(SharedPreferences prefs) {
//     if (currentSessionStart != null) return;
//     final s = prefs.getString(_sessionStart);
//     currentSessionStart = s != null ? DateTime.tryParse(s) : DateTime.now();
//   }

//   String get sessionDuration {
//     if (currentSessionStart == null) return '--';
//     final d = DateTime.now().difference(currentSessionStart!);
//     final h = d.inHours;
//     final m = (d.inMinutes % 60).toString().padLeft(2, '0');
//     return h > 0 ? '${h}h ${m}m' : '${d.inMinutes}m';
//   }

//   bool get hasActivityToday => sessionCountToday > 0;
// }
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

  // ── START — always fresh ───────────────────────────────────────────────────
  Future<void> start(int empId) async {
    _empId = empId;
    currentSessionStart = DateTime.now();
    sessionCountToday += 1;
    isInsideSite = false;
    currentSiteName = '';

    final sessionId = await ApiService.startSession(empId);
    currentSessionId = sessionId;
    dayStatus = DayStatus.inProgress;
  }

  // ── END — full reset ───────────────────────────────────────────────────────
  Future<void> end() async {
    dayStatus = DayStatus.notStarted;
    isInsideSite = false;
    currentSiteName = '';
    currentSessionId = null;
    currentSessionStart = null;
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
