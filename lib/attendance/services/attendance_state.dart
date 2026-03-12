// import 'package:flutter_background_service/flutter_background_service.dart';
// import 'package:shared_preferences/shared_preferences.dart';
// import 'api_service.dart';
// import 'offline_queue.dart';

// // ─── STATE ENUM ───────────────────────────────────────────────────────────────

// enum DayStatus {
//   notStarted, // employee hasn't pressed START yet
//   inProgress, // tracking is active (service running)
//   completed, // employee pressed END — locked for the day
// }

// // ─── SINGLETON ────────────────────────────────────────────────────────────────

// class AttendanceState {
//   AttendanceState._();
//   static final AttendanceState instance = AttendanceState._();

//   // ── Mutable state ──────────────────────────────────────────────────────────
//   DayStatus dayStatus = DayStatus.notStarted;
//   DateTime? startTime;
//   DateTime? endTime;
//   String currentSiteName = "";
//   bool isInsideSite = false;

//   int _empId = -1;
//   bool _initialized = false;

//   // ── Pref keys (scoped per employee) ───────────────────────────────────────
//   String get _doneKey => "is_done_for_day_$_empId";
//   String get _doneDateKey => "done_for_day_date_$_empId";
//   String get _startKey => "start_time_$_empId";

//   // ── Status check (called on app open) ─────────────────────────────────────

//   Future<DayStatus> checkStatus(int empId) async {
//     if (empId != _empId) _reset(empId);

//     final prefs = await SharedPreferences.getInstance();
//     final today = _todayString();

//     // ── Step 1: Ask server first (source of truth = DB last row status) ──────
//     try {
//       final data = await ApiService.getTodayStatus(empId);
//       final status = data["status"] as String? ?? "not_started";

//       if (status == "completed") {
//         // DB has ended_manually row → lock the day
//         await _writeDoneFlag(prefs);
//         _setCompleted(prefs);
//         // Stop any lingering service
//         if (await FlutterBackgroundService().isRunning()) {
//           FlutterBackgroundService().invoke("stop_service");
//         }
//         _initialized = true;
//         return dayStatus;
//       }

//       if (status == "in_progress") {
//         // DB has active/completed rows but NOT ended_manually
//         // Guard: local done flag overrides stale server state
//         final ld = prefs.getBool(_doneKey) ?? false;
//         final dd = prefs.getString(_doneDateKey) ?? "";
//         if (ld && dd == today) {
//           _setCompleted(prefs);
//           _initialized = true;
//           return dayStatus;
//         }

//         // Service might have been killed — restart it
//         await prefs.setInt("employee_id", empId);
//         final serviceRunning = await FlutterBackgroundService().isRunning();
//         if (!serviceRunning) {
//           await FlutterBackgroundService().startService();
//         }
//         dayStatus = DayStatus.inProgress;
//         _recoverStartTime(prefs);
//         _initialized = true;
//         return dayStatus;
//       }

//       // status == "not_started" → no rows today
//       // Clear any stale local flags from previous days
//       await prefs.setBool(_doneKey, false);
//       await prefs.remove(_doneDateKey);
//       dayStatus = DayStatus.notStarted;
//       isInsideSite = false;
//       currentSiteName = "";
//     } catch (_) {
//       // Network unavailable — fall back to local prefs
//       final localDone = prefs.getBool(_doneKey) ?? false;
//       final localDoneDate = prefs.getString(_doneDateKey) ?? "";
//       if (localDone && localDoneDate == today) {
//         _setCompleted(prefs);
//         _initialized = true;
//         return dayStatus;
//       }

//       // Check if service is running as fallback
//       final serviceRunning = await FlutterBackgroundService().isRunning();
//       if (serviceRunning) {
//         dayStatus = DayStatus.inProgress;
//         _recoverStartTime(prefs);
//       } else {
//         dayStatus = DayStatus.notStarted;
//         isInsideSite = false;
//         currentSiteName = "";
//       }
//     }

//     _initialized = true;
//     return dayStatus;
//   }
//   // ── START ──────────────────────────────────────────────────────────────────

//   Future<void> start(int empId) async {
//     _empId = empId;
//     final prefs = await SharedPreferences.getInstance();
//     final today = _todayString();

//     // Guard: never start if already completed today
//     if (dayStatus == DayStatus.completed) return;
//     final localDone = prefs.getBool(_doneKey) ?? false;
//     final localDoneDate = prefs.getString(_doneDateKey) ?? "";
//     if (localDone && localDoneDate == today) {
//       _setCompleted(prefs);
//       return;
//     }

//     startTime = DateTime.now();
//     await prefs.setString(_startKey, startTime!.toIso8601String());
//     await prefs.setInt("employee_id", empId);
//     await prefs.setBool(_doneKey, false);
//     await prefs.remove(_doneDateKey);

//     // Start the background service (foreground service survives app kill)
//     if (!await FlutterBackgroundService().isRunning()) {
//       await FlutterBackgroundService().startService();
//     }

//     dayStatus = DayStatus.inProgress;
//   }

//   // ── END ────────────────────────────────────────────────────────────────────
//   //
//   // The UI calls _service.invoke("end_day") and waits for "end_day_done".
//   // That sequence (in employee_home.dart) is unchanged.
//   // After the background service confirms, the UI calls AttendanceState.end().

//   Future<void> end() async {
//     if (dayStatus == DayStatus.completed) return;

//     final prefs = await SharedPreferences.getInstance();

//     endTime = DateTime.now();

//     await prefs.remove(_startKey);
//     await _writeDoneFlag(prefs);

//     if (await FlutterBackgroundService().isRunning()) {
//       FlutterBackgroundService().invoke("stop_service");
//     }

//     _setCompleted(prefs);
//   }

//   // ── Site status (pushed from background service) ───────────────────────────

//   void updateSiteStatus(bool inside, String siteName) {
//     isInsideSite = inside;
//     currentSiteName = siteName;
//   }

//   // ── Internals ──────────────────────────────────────────────────────────────

//   void _reset(int empId) {
//     _empId = empId;
//     dayStatus = DayStatus.notStarted;
//     startTime = null;
//     endTime = null;
//     isInsideSite = false;
//     currentSiteName = "";
//     _initialized = false;
//   }

//   void _setCompleted(SharedPreferences prefs) {
//     dayStatus = DayStatus.completed;
//     isInsideSite = false;
//     currentSiteName = ""; // ⭐ IMPORTANT
//     endTime ??= DateTime.now();
//   }

//   void _recoverStartTime(SharedPreferences prefs) {
//     if (startTime != null) return;
//     final saved = prefs.getString(_startKey);
//     if (saved != null) startTime = DateTime.tryParse(saved);
//     startTime ??= DateTime.now();
//   }

//   Future<void> _writeDoneFlag(SharedPreferences prefs) async {
//     await prefs.setBool(_doneKey, true);
//     await prefs.setString(_doneDateKey, _todayString());
//   }

//   String _todayString() {
//     final n = DateTime.now();
//     return "${n.year}-${n.month.toString().padLeft(2, '0')}"
//         "-${n.day.toString().padLeft(2, '0')}";
//   }

//   // ── UI helpers ─────────────────────────────────────────────────────────────

//   String get workingDuration {
//     if (startTime == null) return "--";
//     final d = (endTime ?? DateTime.now()).difference(startTime!);
//     return "${d.inHours}h ${(d.inMinutes % 60).toString().padLeft(2, '0')}m";
//   }
// }
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';

// ─── STATUS ENUM ─────────────────────────────────────────────────────────────

enum DayStatus {
  notStarted, // No rows in DB for today
  inProgress, // Has rows, last row is NOT ended_manually
  completed, // Last row in DB is ended_manually — locked for the day
}

// ─── SINGLETON ────────────────────────────────────────────────────────────────

class AttendanceState {
  AttendanceState._();
  static final AttendanceState instance = AttendanceState._();

  DayStatus dayStatus = DayStatus.notStarted;
  DateTime? startTime;
  DateTime? endTime;
  String currentSiteName = '';
  bool isInsideSite = false;

  int _empId = -1;

  String get _startKey => 'start_time_$_empId';

  // ── CHECK STATUS ─────────────────────────────────────────────────────────────
  //
  // The SERVER DB is the single source of truth.
  // Called on: app open, every 1-minute timer, before START press.
  //
  // Server returns:
  //   "not_started"  → no rows today at all
  //   "in_progress"  → has rows, last row is active/completed (between sites)
  //   "completed"    → last row is ended_manually
  //
  // Offline fallback: if server unreachable, use SharedPreferences only.

  Future<DayStatus> checkStatus(int empId) async {
    if (empId != _empId) _resetFor(empId);

    final prefs = await SharedPreferences.getInstance();
    final today = _todayStr();

    // ── 1. Ask server DB ──────────────────────────────────────────────────────
    //
    // GET /attendance/status/:empId returns one of:
    //   { status: "not_started" } → no rows in DB today
    //   { status: "in_progress" } → has rows, last row is active/completed (between sites)
    //   { status: "completed" }   → last DB row is ended_manually → day is DONE
    //
    // "completed" from the server == employee pressed END == lock the day everywhere.
    try {
      final data = await ApiService.getTodayStatus(empId);
      final serverStatus = data['status'] as String? ?? 'not_started';

      if (serverStatus == 'completed') {
        // DB says this employee explicitly ended their day — lock on all devices
        await prefs.setString('day_status_$empId', 'completed');
        await prefs.setString('day_status_date_$empId', today);
        await _stopServiceIfRunning();
        _setCompleted();
        return dayStatus;
      }

      if (serverStatus == 'in_progress') {
        // Server says tracking is active — has rows today but NOT ended.
        // Check if THIS device already did end_day locally (pending sync).
        final localStatus = prefs.getString('day_status_$empId');
        final localDate = prefs.getString('day_status_date_$empId') ?? '';
        if (localStatus == 'completed' && localDate == today) {
          // end_day written locally, pending server sync — show completed here
          _setCompleted();
          return dayStatus;
        }

        // Ensure the background service is alive (OS may have killed it)
        await prefs.setInt('employee_id', empId);
        if (!await FlutterBackgroundService().isRunning()) {
          await FlutterBackgroundService().startService();
        }
        dayStatus = DayStatus.inProgress;
        _recoverStartTime(prefs);
        await prefs.setString('day_status_$empId', 'in_progress');
        await prefs.setString('day_status_date_$empId', today);
        return dayStatus;
      }

      // 'not_started' — no rows in DB for today. Clear any stale yesterday flags.
      if ((prefs.getString('day_status_date_$empId') ?? '') != today) {
        await prefs.remove('day_status_$empId');
        await prefs.remove('day_status_date_$empId');
        await prefs.remove(_startKey);
      }
      dayStatus = DayStatus.notStarted;
      isInsideSite = false;
      currentSiteName = '';
      return dayStatus;
    } catch (_) {
      // ── 2. Offline fallback — read from SharedPreferences ─────────────────
      final localStatus = prefs.getString('day_status_$empId');
      final localDate = prefs.getString('day_status_date_$empId') ?? '';

      if (localDate == today) {
        if (localStatus == 'completed') {
          _setCompleted();
          return dayStatus;
        }
        if (localStatus == 'in_progress') {
          // Make sure service is running
          if (!await FlutterBackgroundService().isRunning()) {
            await FlutterBackgroundService().startService();
          }
          dayStatus = DayStatus.inProgress;
          _recoverStartTime(prefs);
          return dayStatus;
        }
      }

      dayStatus = DayStatus.notStarted;
      isInsideSite = false;
      currentSiteName = '';
      return dayStatus;
    }
  }

  // ── START ─────────────────────────────────────────────────────────────────
  //
  // Only called after checkStatus() confirmed notStarted.
  // Writes local prefs so offline fallback works.

  Future<void> start(int empId) async {
    _empId = empId;
    final prefs = await SharedPreferences.getInstance();
    startTime = DateTime.now();
    await prefs.setString(_startKey, startTime!.toIso8601String());
    await prefs.setInt('employee_id', empId);
    await prefs.setString('day_status_$empId', 'in_progress');
    await prefs.setString('day_status_date_$empId', _todayStr());
    dayStatus = DayStatus.inProgress;
  }

  // ── END ───────────────────────────────────────────────────────────────────
  //
  // Called after background service confirms end_day_done (or server confirms).
  // Locks the day locally.

  Future<void> end() async {
    if (dayStatus == DayStatus.completed) return;
    final prefs = await SharedPreferences.getInstance();
    endTime = DateTime.now();
    await prefs.remove(_startKey);
    await prefs.setString('day_status_$_empId', 'completed');
    await prefs.setString('day_status_date_$_empId', _todayStr());
    await _stopServiceIfRunning();
    _setCompleted();
  }

  // ── SITE STATUS (pushed by background service stream events) ─────────────

  void updateSiteStatus(bool inside, String siteName) {
    isInsideSite = inside;
    currentSiteName = siteName;
  }

  // ── INTERNALS ─────────────────────────────────────────────────────────────

  void _resetFor(int empId) {
    _empId = empId;
    dayStatus = DayStatus.notStarted;
    startTime = null;
    endTime = null;
    isInsideSite = false;
    currentSiteName = '';
  }

  void _setCompleted() {
    dayStatus = DayStatus.completed;
    isInsideSite = false;
    currentSiteName = '';
    endTime ??= DateTime.now();
  }

  void _recoverStartTime(SharedPreferences prefs) {
    if (startTime != null) return;
    final s = prefs.getString(_startKey);
    startTime = s != null ? DateTime.tryParse(s) : null;
    startTime ??= DateTime.now();
  }

  Future<void> _stopServiceIfRunning() async {
    try {
      if (await FlutterBackgroundService().isRunning()) {
        FlutterBackgroundService().invoke('stop_service');
      }
    } catch (_) {}
  }

  String _todayStr() {
    final n = DateTime.now();
    return '${n.year}-${n.month.toString().padLeft(2, '0')}'
        '-${n.day.toString().padLeft(2, '0')}';
  }

  String get workingDuration {
    if (startTime == null) return '--';
    final d = (endTime ?? DateTime.now()).difference(startTime!);
    return '${d.inHours}h ${(d.inMinutes % 60).toString().padLeft(2, '0')}m';
  }
}
