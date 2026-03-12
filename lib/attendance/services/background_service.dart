// import 'dart:async';
// import 'dart:ui';
// import 'package:flutter_background_service/flutter_background_service.dart';
// import 'package:flutter_local_notifications/flutter_local_notifications.dart';
// import 'package:geolocator/geolocator.dart';
// import 'package:permission_handler/permission_handler.dart';
// import 'package:shared_preferences/shared_preferences.dart';
// import 'package:sqflite/sqflite.dart';
// import 'package:path/path.dart' as p;
// import 'package:flutter/foundation.dart';
// import 'api_service.dart';
// import 'site_cache.dart';

// const String kChannelId = "attendance_tracking";
// const String kNotifTitle = "Attendance Tracking";
// const int kNotifId = 888;

// // ─── LOCAL SQLITE ─────────────────────────────────────────────────────────────

// class LocalDB {
//   static Database? _db;

//   static Future<Database> get db async {
//     _db ??= await openDatabase(
//       p.join(await getDatabasesPath(), 'attendance_local.db'),
//       version: 1,
//       onCreate: (db, _) => db.execute('''
//         CREATE TABLE attendance_events (
//           id          INTEGER PRIMARY KEY AUTOINCREMENT,
//           type        TEXT    NOT NULL,
//           employee_id INTEGER NOT NULL,
//           site_id     INTEGER,
//           timestamp   TEXT    NOT NULL,
//           synced      INTEGER NOT NULL DEFAULT 0
//         )
//       '''),
//     );
//     return _db!;
//   }

//   static Future<void> writeEvent({
//     required String type,
//     required int employeeId,
//     int? siteId,
//   }) async {
//     await (await db).insert('attendance_events', {
//       'type': type,
//       'employee_id': employeeId,
//       'site_id': siteId,
//       'timestamp': DateTime.now().toIso8601String(),
//       'synced': 0,
//     });
//     print('[LocalDB] $type emp=$employeeId site=$siteId');
//   }

//   static Future<List<Map<String, dynamic>>> pendingEvents() async => (await db)
//       .query('attendance_events', where: 'synced = 0', orderBy: 'id ASC');

//   static Future<void> markSynced(List<int> ids) async {
//     if (ids.isEmpty) return;
//     await (await db).update(
//       'attendance_events',
//       {'synced': 1},
//       where: 'id IN (${List.filled(ids.length, '?').join(',')})',
//       whereArgs: ids,
//     );
//   }

//   static Future<void> cleanup() async {
//     final cutoff = DateTime.now()
//         .subtract(const Duration(days: 3))
//         .toIso8601String();
//     await (await db).delete(
//       'attendance_events',
//       where: 'synced = 1 AND timestamp < ?',
//       whereArgs: [cutoff],
//     );
//   }
// }

// // ─── SYNC WORKER ──────────────────────────────────────────────────────────────

// class SyncWorker {
//   static bool _running = false;

//   static Future<void> flush() async {
//     if (_running) return;
//     _running = true;
//     try {
//       final events = await LocalDB.pendingEvents();
//       if (events.isEmpty) return;

//       print('[Sync] flushing ${events.length} event(s)');

//       // Use batch endpoint for efficiency
//       final payload = events
//           .map(
//             (e) => {
//               'type': e['type'],
//               'employee_id': e['employee_id'],
//               'site_id': e['site_id'],
//               'timestamp': e['timestamp'],
//             },
//           )
//           .toList();

//       try {
//         await ApiService.batchSync(payload);
//         await LocalDB.markSynced(events.map((e) => e['id'] as int).toList());
//         await LocalDB.cleanup();
//         print('[Sync] done — ${events.length} synced via batch');
//       } catch (_) {
//         // Batch failed — fall back to individual calls
//         final synced = <int>[];
//         for (final e in events) {
//           try {
//             switch (e['type'] as String) {
//               case 'mark_in':
//                 await ApiService.markIn(
//                   e['employee_id'] as int,
//                   e['site_id'] as int,
//                 );
//                 break;
//               case 'mark_out':
//                 await ApiService.markOut(e['employee_id'] as int);
//                 break;
//               case 'end_day':
//                 await ApiService.endDay(e['employee_id'] as int);
//                 break;
//             }
//             synced.add(e['id'] as int);
//           } catch (err) {
//             print('[Sync] event ${e['id']} failed: $err — will retry');
//           }
//         }
//         await LocalDB.markSynced(synced);
//         if (synced.isNotEmpty) await LocalDB.cleanup();
//         print(
//           '[Sync] fallback done — ${synced.length}/${events.length} synced',
//         );
//       }
//     } finally {
//       _running = false;
//     }
//   }
// }

// // ─── SERVICE INIT ─────────────────────────────────────────────────────────────

// Future<void> initBackgroundService() async {
//   final service = FlutterBackgroundService();

//   final notifPlugin = FlutterLocalNotificationsPlugin();
//   await notifPlugin
//       .resolvePlatformSpecificImplementation<
//         AndroidFlutterLocalNotificationsPlugin
//       >()
//       ?.createNotificationChannel(
//         const AndroidNotificationChannel(
//           kChannelId,
//           "Attendance Tracking",
//           description: "Keeps tracking running even when app is closed",
//           importance: Importance.low,
//         ),
//       );

//   await service.configure(
//     androidConfiguration: AndroidConfiguration(
//       onStart: onServiceStart,
//       isForegroundMode: true,
//       autoStartOnBoot: false,
//       notificationChannelId: kChannelId,
//       initialNotificationTitle: kNotifTitle,
//       initialNotificationContent: "Tracking active — tap to open",
//       foregroundServiceNotificationId: kNotifId,
//       foregroundServiceTypes: [AndroidForegroundType.location],
//     ),
//     iosConfiguration: IosConfiguration(
//       autoStart: false,
//       onForeground: onServiceStart,
//       onBackground: onIosBackground,
//     ),
//   );
// }

// @pragma('vm:entry-point')
// Future<bool> onIosBackground(ServiceInstance service) async => true;

// // ─── SERVICE ENTRY POINT ──────────────────────────────────────────────────────

// @pragma('vm:entry-point')
// void onServiceStart(ServiceInstance service) async {
//   DartPluginRegistrant.ensureInitialized();

//   final notifPlugin = FlutterLocalNotificationsPlugin();
//   await notifPlugin.initialize(
//     const InitializationSettings(
//       android: AndroidInitializationSettings('@mipmap/ic_launcher'),
//     ),
//   );

//   print('[Service] STARTED');

//   void updateNotif(String text) {
//     notifPlugin.show(
//       kNotifId,
//       kNotifTitle,
//       text,
//       const NotificationDetails(
//         android: AndroidNotificationDetails(
//           kChannelId,
//           kNotifTitle,
//           ongoing: true,
//           importance: Importance.low,
//           priority: Priority.low,
//           playSound: false,
//         ),
//       ),
//     );
//   }

//   // Load site polygons
//   _fire(SiteCache.init());

//   final prefs = await SharedPreferences.getInstance();
//   final int? empId = prefs.getInt("employee_id");
//   if (empId == null) {
//     print('[Service] No employee_id — stopping');
//     service.stopSelf();
//     return;
//   }

//   // FIX: Check background location permission before starting GPS stream.
//   final bgPerm = await Permission.locationAlways.status;
//   if (!bgPerm.isGranted) {
//     print('[Service] ⚠️  ACCESS_BACKGROUND_LOCATION not granted — stopping');
//     updateNotif("Location permission required");
//     service.invoke("service_error", {"reason": "no_background_location"});
//     service.stopSelf();
//     return;
//   }

//   int? currentSiteId = prefs.getInt("current_site_id_$empId");
//   String _currentWorkDate = _todayStr();

//   // Flush leftover events from previous session
//   _fire(SyncWorker.flush());

//   final syncTimer = Timer.periodic(const Duration(minutes: 5), (_) {
//     _fire(SyncWorker.flush());
//   });

//   // ── END DAY ────────────────────────────────────────────────────────────────
//   service.on("end_day").listen((_) async {
//     print('[Service] END DAY — user initiated');

//     await LocalDB.writeEvent(type: 'end_day', employeeId: empId);

//     if (currentSiteId != null) {
//       await LocalDB.writeEvent(type: 'mark_out', employeeId: empId);
//       currentSiteId = null;
//       await prefs.remove("current_site_id_$empId");
//     }

//     await SyncWorker.flush();
//     syncTimer.cancel();
//     SiteCache.dispose();

//     await prefs.setBool("is_done_for_day_$empId", true);
//     await prefs.setString("done_for_day_date_$empId", _currentWorkDate);
//     service.invoke("end_day_done", {});
//     await notifPlugin.cancel(kNotifId);
//     service.stopSelf();
//     print('[Service] STOPPED');
//   });

//   // ── GPS SMOOTHING ──────────────────────────────────────────────────────────
//   final List<({double lat, double lng})> _hist = [];

//   ({double lat, double lng}) smooth(Position pos) {
//     _hist.add((lat: pos.latitude, lng: pos.longitude));
//     if (_hist.length > 3) _hist.removeAt(0);
//     double ls = 0, ns = 0, ws = 0;
//     for (int i = 0; i < _hist.length; i++) {
//       final w = (i + 1).toDouble();
//       ls += _hist[i].lat * w;
//       ns += _hist[i].lng * w;
//       ws += w;
//     }
//     return (lat: ls / ws, lng: ns / ws);
//   }

//   double? _lastLat, _lastLng;
//   bool movedEnough(double lat, double lng) {
//     if (_lastLat == null) return true;
//     return Geolocator.distanceBetween(_lastLat!, _lastLng!, lat, lng) > 8;
//   }

//   // Instant first position from cache
//   try {
//     final last = await Geolocator.getLastKnownPosition();
//     if (last != null) {
//       service.invoke("location_update", {
//         "lat": last.latitude,
//         "lng": last.longitude,
//         "accuracy": last.accuracy,
//         "good": last.accuracy <= 80,
//       });
//     }
//   } catch (_) {}

//   // ── GPS STREAM ──────────────────────────────────────────────────────────────
//   StreamSubscription<Position>? gpsSub;

//   gpsSub =
//       Geolocator.getPositionStream(
//         locationSettings: AndroidSettings(
//           accuracy: LocationAccuracy.bestForNavigation,
//           distanceFilter: 0,
//           intervalDuration: const Duration(seconds: 3),
//           foregroundNotificationConfig: const ForegroundNotificationConfig(
//             notificationChannelName: "Attendance Tracking",
//             notificationText: "Location tracking active",
//             notificationTitle: kNotifTitle,
//             enableWakeLock: true,
//             setOngoing: true,
//           ),
//         ),
//       ).listen(
//         (Position pos) async {
//           if (pos.accuracy > 150) return;

//           final s = smooth(pos);

//           // FIX: Midnight rollover — if the calendar date changed, reset site state
//           final todayStr = _todayStr();
//           if (todayStr != _currentWorkDate) {
//             print(
//               '[Service] 🕛 Midnight rollover detected — resetting site state',
//             );
//             if (currentSiteId != null) {
//               await LocalDB.writeEvent(type: 'mark_out', employeeId: empId);
//               currentSiteId = null;
//               await prefs.remove("current_site_id_$empId");
//             }
//             _hist.clear();
//             _lastLat = null;
//             _lastLng = null;
//             _currentWorkDate = todayStr;
//             // Re-sync sites for the new day
//             _fire(SiteCache.sync());
//           }

//           // Path 1: UI update — every tick
//           service.invoke("location_update", {
//             "lat": s.lat,
//             "lng": s.lng,
//             "accuracy": pos.accuracy,
//             "good": pos.accuracy <= 50,
//           });

//           // Path 2: Site detection — only when position changed enough
//           if (!movedEnough(s.lat, s.lng)) return;
//           _lastLat = s.lat;
//           _lastLng = s.lng;

//           final result = SiteCache.checkLocation(s.lat, s.lng);

//           if (result.inside) {
//             final siteId = result.siteId!;
//             final siteName = result.siteName!;

//             // GUARD: If day is already done, stop the service instead of tracking
//             final isDone = prefs.getBool("is_done_for_day_$empId") ?? false;
//             final isDoneDate =
//                 prefs.getString("done_for_day_date_$empId") ?? "";
//             if (isDone && isDoneDate == _currentWorkDate) {
//               print('[Service] Day already ended — stopping service');
//               gpsSub?.cancel();
//               syncTimer.cancel();
//               SiteCache.dispose();
//               await notifPlugin.cancel(kNotifId);
//               service.stopSelf();
//               return;
//             }

//             if (currentSiteId != siteId) {
//               if (currentSiteId != null) {
//                 await LocalDB.writeEvent(type: 'mark_out', employeeId: empId);
//               }
//               await LocalDB.writeEvent(
//                 type: 'mark_in',
//                 employeeId: empId,
//                 siteId: siteId,
//               );
//               currentSiteId = siteId;
//               await prefs.setInt("current_site_id_$empId", siteId);
//               updateNotif("IN: $siteName");
//             }

//             service.invoke("status_update", {
//               "status": "IN",
//               "site_name": siteName,
//               "lat": s.lat,
//               "lng": s.lng,
//               "accuracy": pos.accuracy,
//             });
//           } else {
//             if (currentSiteId != null) {
//               await LocalDB.writeEvent(type: 'mark_out', employeeId: empId);
//               currentSiteId = null;
//               await prefs.remove("current_site_id_$empId");
//               updateNotif("Tracking... (outside sites)");
//             }
//             service.invoke("status_update", {
//               "status": "OUTSIDE",
//               "lat": s.lat,
//               "lng": s.lng,
//               "accuracy": pos.accuracy,
//             });
//           }
//         },

//         // FIX: Handle GPS errors (e.g. permissions revoked mid-session)
//         onError: (Object error) {
//           print('[Service] GPS error: $error');
//           updateNotif("GPS unavailable — check permissions");
//           service.invoke("service_error", {
//             "reason": "gps_error",
//             "detail": error.toString(),
//           });
//         },

//         // FIX: Handle stream closing (shouldn't happen, but guards against it)
//         onDone: () {
//           print('[Service] GPS stream closed unexpectedly');
//           updateNotif("GPS stream ended — restart app");
//           service.invoke("service_error", {"reason": "gps_stream_closed"});
//         },
//       );

//   print('[Service] GPS running | ${SiteCache.siteCount} sites cached');
// }

// // ─── HELPERS ─────────────────────────────────────────────────────────────────

// String _todayStr() {
//   final n = DateTime.now();
//   return "${n.year}-${n.month.toString().padLeft(2, '0')}"
//       "-${n.day.toString().padLeft(2, '0')}";
// }

// void _fire(Future<void> f) =>
//     f.catchError((e) => print('[Service] async error: $e'));

// // ─── PLATFORM BRIDGE FUNCTIONS ───────────────────────────────────────────────

// final FlutterBackgroundService _service = FlutterBackgroundService();

// /// Web listener (stub)
// Stream<Map<String, dynamic>?> webOn(String event) {
//   return const Stream.empty();
// }

// /// Desktop listener (stub)
// Stream<Map<String, dynamic>?> desktopOn(String event) {
//   return const Stream.empty();
// }

// /// Start background tracking
// Future<void> startBackgroundTracking(int employeeId) async {
//   final prefs = await SharedPreferences.getInstance();
//   await prefs.setInt("employee_id", employeeId);

//   if (kIsWeb) return;

//   final service = FlutterBackgroundService();

//   final isRunning = await service.isRunning();
//   if (!isRunning) {
//     await service.startService();
//   }
// }

// /// Send END DAY signal to service
// Future<bool> sendEndDay() async {
//   if (kIsWeb) return true;

//   final service = FlutterBackgroundService();
//   final completer = Completer<bool>();

//   StreamSubscription? sub;

//   sub = service.on("end_day_done").listen((event) {
//     completer.complete(true);
//     sub?.cancel();
//   });

//   service.invoke("end_day");

//   return completer.future.timeout(
//     const Duration(seconds: 10),
//     onTimeout: () {
//       sub?.cancel();
//       return false;
//     },
//   );
// }
import 'dart:async';
import 'dart:ui';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:flutter/foundation.dart';
import 'api_service.dart';
import 'site_cache.dart';

const String kChannelId = 'attendance_tracking';
const String kNotifTitle = 'Attendance Tracking';
const int kNotifId = 888;

// ─── LOCAL DB (offline event queue) ──────────────────────────────────────────
//
// Every mark_in / mark_out / end_day is written here first.
// SyncWorker pushes them to the server every 1 minute.
// If the server is unreachable the events stay here and are retried
// on the next tick — no data is ever lost.

class LocalDB {
  static Database? _db;

  static Future<Database> get db async {
    _db ??= await openDatabase(
      p.join(await getDatabasesPath(), 'attendance_local.db'),
      version: 1,
      onCreate: (db, _) => db.execute('''
        CREATE TABLE attendance_events (
          id          INTEGER PRIMARY KEY AUTOINCREMENT,
          type        TEXT    NOT NULL,
          employee_id INTEGER NOT NULL,
          site_id     INTEGER,
          timestamp   TEXT    NOT NULL,
          synced      INTEGER NOT NULL DEFAULT 0
        )
      '''),
    );
    return _db!;
  }

  static Future<void> writeEvent({
    required String type,
    required int employeeId,
    int? siteId,
  }) async {
    final ts = DateTime.now().toIso8601String();
    await (await db).insert('attendance_events', {
      'type': type,
      'employee_id': employeeId,
      'site_id': siteId,
      'timestamp': ts,
      'synced': 0,
    });
    print('[LocalDB] ✍ $type emp=$employeeId site=$siteId ts=$ts');
  }

  static Future<List<Map<String, dynamic>>> pendingEvents() async => (await db)
      .query('attendance_events', where: 'synced = 0', orderBy: 'id ASC');

  static Future<void> markSynced(List<int> ids) async {
    if (ids.isEmpty) return;
    await (await db).update(
      'attendance_events',
      {'synced': 1},
      where: 'id IN (${List.filled(ids.length, '?').join(',')})',
      whereArgs: ids,
    );
  }

  static Future<void> cleanup() async {
    final cutoff = DateTime.now()
        .subtract(const Duration(days: 3))
        .toIso8601String();
    await (await db).delete(
      'attendance_events',
      where: 'synced = 1 AND timestamp < ?',
      whereArgs: [cutoff],
    );
  }
}

// ─── SYNC WORKER ──────────────────────────────────────────────────────────────
//
// Runs every 1 minute. Attempts batch sync first, falls back to individual
// calls if the batch endpoint fails. If ALL network calls fail (offline), the
// events stay in LocalDB and will be retried on the next tick.

class SyncWorker {
  static bool _running = false;

  static Future<void> flush() async {
    if (_running) return;
    _running = true;
    try {
      final events = await LocalDB.pendingEvents();
      if (events.isEmpty) return;

      print('[Sync] flushing ${events.length} pending event(s)');

      final payload = events
          .map(
            (e) => {
              'type': e['type'],
              'employee_id': e['employee_id'],
              'site_id': e['site_id'],
              'timestamp': e['timestamp'],
            },
          )
          .toList();

      try {
        // ── Preferred: batch endpoint ──────────────────────────────────────
        await ApiService.batchSync(payload);
        await LocalDB.markSynced(events.map((e) => e['id'] as int).toList());
        await LocalDB.cleanup();
        print('[Sync] ✅ batch OK — ${events.length} synced');
      } catch (_) {
        // ── Fallback: one by one ───────────────────────────────────────────
        final synced = <int>[];
        for (final e in events) {
          try {
            switch (e['type'] as String) {
              case 'mark_in':
                await ApiService.markIn(
                  e['employee_id'] as int,
                  e['site_id'] as int,
                );
                break;
              case 'mark_out':
                await ApiService.markOut(e['employee_id'] as int);
                break;
              case 'end_day':
                await ApiService.endDay(e['employee_id'] as int);
                break;
            }
            synced.add(e['id'] as int);
          } catch (err) {
            print('[Sync] ⚠ event ${e['id']} failed — will retry: $err');
          }
        }
        await LocalDB.markSynced(synced);
        if (synced.isNotEmpty) await LocalDB.cleanup();
        print('[Sync] fallback: ${synced.length}/${events.length} synced');
      }
    } finally {
      _running = false;
    }
  }
}

// ─── SERVICE INIT ─────────────────────────────────────────────────────────────

Future<void> initBackgroundService() async {
  final service = FlutterBackgroundService();

  final notifPlugin = FlutterLocalNotificationsPlugin();
  await notifPlugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >()
      ?.createNotificationChannel(
        const AndroidNotificationChannel(
          kChannelId,
          'Attendance Tracking',
          description: 'Keeps tracking running even when app is closed',
          importance: Importance.low,
        ),
      );

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onServiceStart,
      isForegroundMode: true,
      autoStartOnBoot: false,
      notificationChannelId: kChannelId,
      initialNotificationTitle: kNotifTitle,
      initialNotificationContent: 'Tracking active — tap to open',
      foregroundServiceNotificationId: kNotifId,
      foregroundServiceTypes: [AndroidForegroundType.location],
    ),
    iosConfiguration: IosConfiguration(
      autoStart: false,
      onForeground: onServiceStart,
      onBackground: onIosBackground,
    ),
  );
}

@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async => true;

// ─── SERVICE ENTRY POINT ──────────────────────────────────────────────────────

@pragma('vm:entry-point')
void onServiceStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  final notifPlugin = FlutterLocalNotificationsPlugin();
  await notifPlugin.initialize(
    const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    ),
  );

  print('[Service] ▶ STARTED');

  // ── Helper: update persistent notification ────────────────────────────────
  void updateNotif(String text) {
    notifPlugin.show(
      kNotifId,
      kNotifTitle,
      text,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          kChannelId,
          kNotifTitle,
          ongoing: true,
          importance: Importance.low,
          priority: Priority.low,
          playSound: false,
        ),
      ),
    );
  }

  // ── Read employee_id written by startBackgroundTracking() ─────────────────
  final prefs = await SharedPreferences.getInstance();
  final int? empId = prefs.getInt('employee_id');
  if (empId == null) {
    print('[Service] No employee_id in prefs — stopping');
    service.stopSelf();
    return;
  }

  // ── Guard: background location permission ─────────────────────────────────
  final bgPerm = await Permission.locationAlways.status;
  if (!bgPerm.isGranted) {
    print('[Service] ⚠ ACCESS_BACKGROUND_LOCATION not granted — stopping');
    updateNotif('Location permission required');
    service.invoke('service_error', {'reason': 'no_background_location'});
    service.stopSelf();
    return;
  }

  // ── Guard: check server DB — if day already completed, stop immediately ────
  // This is the correct cross-device check: ask the server, not local prefs.
  try {
    final data = await ApiService.getTodayStatus(empId);
    final serverStatus = data['status'] as String? ?? 'not_started';
    if (serverStatus == 'completed') {
      print('[Service] Server DB says day completed — stopping service');
      service.stopSelf();
      return;
    }
    if (serverStatus == 'not_started') {
      // Edge case: service was started but server has no record yet.
      // This is fine — the first mark_in will create the DB row.
      print('[Service] Server DB: not_started yet (first location pending)');
    }
  } catch (_) {
    // Network unavailable at service start — continue anyway.
    // SyncWorker will push events when network returns.
    print('[Service] Could not reach server at start — continuing offline');
  }

  // ── Load site polygons into memory ────────────────────────────────────────
  // SiteCache.init() was already called by startBackgroundTracking() which
  // fetched from server and saved to SQLite. Here we just load memory in
  // this new isolate from the already-populated SQLite table.
  _fire(SiteCache.init());

  int? currentSiteId = prefs.getInt('current_site_id_$empId');
  String _currentWorkDate = _todayStr();

  // Flush any events left over from a previous session
  _fire(SyncWorker.flush());

  // ── 1-minute sync timer ───────────────────────────────────────────────────
  // Every minute: push pending local events to the server.
  // If network is down, events stay in LocalDB and are retried next minute.
  final syncTimer = Timer.periodic(const Duration(minutes: 1), (_) {
    _fire(SyncWorker.flush());
  });

  // ── 30-minute site refresh timer ──────────────────────────────────────────
  final siteRefreshTimer = Timer.periodic(const Duration(minutes: 30), (_) {
    _fire(SiteCache.sync());
  });

  // ── END DAY listener (from UI) ────────────────────────────────────────────
  service.on('end_day').listen((_) async {
    print('[Service] ⏹ END DAY received from UI');

    // 1. Close any open site visit
    if (currentSiteId != null) {
      await LocalDB.writeEvent(type: 'mark_out', employeeId: empId);
      currentSiteId = null;
      await prefs.remove('current_site_id_$empId');
    }

    // 2. Write end_day event to local DB
    await LocalDB.writeEvent(type: 'end_day', employeeId: empId);

    // 3. Final flush — attempt to push everything to server before stopping
    await SyncWorker.flush();

    // 4. Clear site cache from SQLite — next START re-fetches fresh data
    await SiteCache.clear();

    // 5. Cancel all timers
    syncTimer.cancel();
    siteRefreshTimer.cancel();
    SiteCache.dispose();

    // 6. Notify UI
    service.invoke('end_day_done', {});

    await notifPlugin.cancel(kNotifId);
    service.stopSelf();
    print('[Service] ■ STOPPED after END DAY');
  });

  // ── GPS smoothing (weighted moving average over last 3 positions) ─────────
  final List<({double lat, double lng})> _hist = [];

  ({double lat, double lng}) _smooth(Position pos) {
    _hist.add((lat: pos.latitude, lng: pos.longitude));
    if (_hist.length > 3) _hist.removeAt(0);
    double ls = 0, ns = 0, ws = 0;
    for (int i = 0; i < _hist.length; i++) {
      final w = (i + 1).toDouble();
      ls += _hist[i].lat * w;
      ns += _hist[i].lng * w;
      ws += w;
    }
    return (lat: ls / ws, lng: ns / ws);
  }

  double? _lastLat, _lastLng;
  bool _movedEnough(double lat, double lng) {
    if (_lastLat == null) return true;
    return Geolocator.distanceBetween(_lastLat!, _lastLng!, lat, lng) > 8;
  }

  // Warm-up: show last known position immediately
  try {
    final last = await Geolocator.getLastKnownPosition();
    if (last != null) {
      service.invoke('location_update', {
        'lat': last.latitude,
        'lng': last.longitude,
        'accuracy': last.accuracy,
        'good': last.accuracy <= 80,
      });
    }
  } catch (_) {}

  // ── GPS stream ────────────────────────────────────────────────────────────
  StreamSubscription<Position>? gpsSub;

  gpsSub =
      Geolocator.getPositionStream(
        locationSettings: AndroidSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          distanceFilter: 0,
          intervalDuration: const Duration(seconds: 3),
          foregroundNotificationConfig: const ForegroundNotificationConfig(
            notificationChannelName: 'Attendance Tracking',
            notificationText: 'Location tracking active',
            notificationTitle: kNotifTitle,
            enableWakeLock: true,
            setOngoing: true,
          ),
        ),
      ).listen(
        (Position pos) async {
          if (pos.accuracy > 150) return; // ignore very poor fixes

          final s = _smooth(pos);

          // ── Midnight rollover ────────────────────────────────────────────────
          final todayStr = _todayStr();
          if (todayStr != _currentWorkDate) {
            print('[Service] 🕛 Midnight rollover');
            if (currentSiteId != null) {
              await LocalDB.writeEvent(type: 'mark_out', employeeId: empId);
              currentSiteId = null;
              await prefs.remove('current_site_id_$empId');
            }
            _hist.clear();
            _lastLat = null;
            _lastLng = null;
            _currentWorkDate = todayStr;
            _fire(SiteCache.sync());
          }

          // ── Always: push UI location update ──────────────────────────────────
          service.invoke('location_update', {
            'lat': s.lat,
            'lng': s.lng,
            'accuracy': pos.accuracy,
            'good': pos.accuracy <= 50,
          });

          // ── Only when moved enough: check site membership ─────────────────────
          if (!_movedEnough(s.lat, s.lng)) return;
          _lastLat = s.lat;
          _lastLng = s.lng;

          // Re-check server DB to see if day was ended on another device.
          // We do this lazily — only on actual movement, not every GPS tick.
          // The 1-min sync timer is the primary cross-device protection.
          final freshLocal = prefs.getString('day_status_$empId');
          final freshDate = prefs.getString('day_status_date_$empId') ?? '';
          if (freshLocal == 'completed' && freshDate == _currentWorkDate) {
            print('[Service] Local prefs say completed — stopping');
            gpsSub?.cancel();
            syncTimer.cancel();
            siteRefreshTimer.cancel();
            SiteCache.dispose();
            await notifPlugin.cancel(kNotifId);
            service.stopSelf();
            return;
          }

          final result = SiteCache.checkLocation(s.lat, s.lng);

          if (result.inside) {
            final siteId = result.siteId!;
            final siteName = result.siteName!;

            if (currentSiteId != siteId) {
              // Left previous site → mark out
              if (currentSiteId != null) {
                await LocalDB.writeEvent(type: 'mark_out', employeeId: empId);
              }
              // Entered new site → mark in
              await LocalDB.writeEvent(
                type: 'mark_in',
                employeeId: empId,
                siteId: siteId,
              );
              currentSiteId = siteId;
              await prefs.setInt('current_site_id_$empId', siteId);
              updateNotif('IN: $siteName');
              // Eager flush on transition — don't wait for the 1-min timer
              _fire(SyncWorker.flush());
            }

            service.invoke('status_update', {
              'status': 'IN',
              'site_name': siteName,
              'lat': s.lat,
              'lng': s.lng,
              'accuracy': pos.accuracy,
            });
          } else {
            if (currentSiteId != null) {
              await LocalDB.writeEvent(type: 'mark_out', employeeId: empId);
              currentSiteId = null;
              await prefs.remove('current_site_id_$empId');
              updateNotif('Tracking... (outside all sites)');
              // Eager flush on site exit
              _fire(SyncWorker.flush());
            }
            service.invoke('status_update', {
              'status': 'OUTSIDE',
              'lat': s.lat,
              'lng': s.lng,
              'accuracy': pos.accuracy,
            });
          }
        },
        onError: (Object error) {
          print('[Service] GPS error: $error');
          updateNotif('GPS unavailable — check permissions');
          service.invoke('service_error', {
            'reason': 'gps_error',
            'detail': error.toString(),
          });
        },
        onDone: () {
          print('[Service] GPS stream closed unexpectedly');
          updateNotif('GPS stream ended — restart app');
          service.invoke('service_error', {'reason': 'gps_stream_closed'});
        },
      );

  print('[Service] ✅ GPS running | ${SiteCache.siteCount} site(s) loaded');
}

// ─── HELPERS ─────────────────────────────────────────────────────────────────

String _todayStr() {
  final n = DateTime.now();
  return '${n.year}-${n.month.toString().padLeft(2, '0')}'
      '-${n.day.toString().padLeft(2, '0')}';
}

void _fire(Future<void> f) =>
    f.catchError((e) => print('[Service] async error: $e'));

// ─── PLATFORM STUBS ───────────────────────────────────────────────────────────

Stream<Map<String, dynamic>?> webOn(String event) => const Stream.empty();
Stream<Map<String, dynamic>?> desktopOn(String event) => const Stream.empty();

// ─── START BACKGROUND TRACKING ────────────────────────────────────────────────
//
// Called by EmployeeHome after:
//   1. Server confirmed status = "not_started"
//   2. Permissions granted
//
// Steps:
//   a. Save employee_id to prefs (service isolate reads this).
//   b. Fetch site polygons from server → persist to SQLite.
//      (Service isolate will load from SQLite in its own init.)
//   c. Start the foreground service.

Future<void> startBackgroundTracking(int employeeId) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setInt('employee_id', employeeId);

  if (kIsWeb) return;

  // Fetch and cache site polygons BEFORE starting the service,
  // so the background isolate can load them without a network call.
  await SiteCache.init();

  final service = FlutterBackgroundService();
  if (!await service.isRunning()) {
    await service.startService();
  }
}

// ─── SEND END DAY ─────────────────────────────────────────────────────────────
//
// Signals the background service to perform a clean shutdown:
//   mark_out → end_day → flush → clear sites → stop service.
//
// Returns true  if service confirmed within 10 s.
// Returns false on timeout (data is safe in LocalDB, will sync later).

Future<bool> sendEndDay() async {
  if (kIsWeb) return true;

  final service = FlutterBackgroundService();
  final completer = Completer<bool>();
  StreamSubscription? sub;

  sub = service.on('end_day_done').listen((_) {
    if (!completer.isCompleted) completer.complete(true);
    sub?.cancel();
  });

  service.invoke('end_day');

  return completer.future.timeout(
    const Duration(seconds: 10),
    onTimeout: () {
      sub?.cancel();
      return false;
    },
  );
}
