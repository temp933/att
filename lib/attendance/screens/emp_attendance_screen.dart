import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart'
    if (dart.library.html) '../services/stub/flutter_background_service_stub.dart';
import 'package:latlong2/latlong.dart';
import 'package:permission_handler/permission_handler.dart';

import '../services/api_service.dart';
import '../services/attendance_state.dart';
import '../services/background_service.dart';

class AttendanceScreen extends StatefulWidget {
  final int employeeId;
  const AttendanceScreen({super.key, required this.employeeId});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen>
    with SingleTickerProviderStateMixin {
  final _service = FlutterBackgroundService();
  final _state = AttendanceState.instance;

  LatLng? _position;
  double? _accuracy;
  bool _goodAccuracy = true;
  bool _isLoading = true;
  bool _listenersAttached = false;

  List<Map<String, dynamic>> _logs = [];

  // ── Timers ────────────────────────────────────────────────────────────────
  Timer? _statusTimer; // every 1 min: re-poll server DB for status
  Timer? _logsTimer; // every 1 min: refresh today's log list
  Timer? _clockTimer; // every 1 min: repaint elapsed time

  StreamSubscription? _statusSub;
  StreamSubscription? _locationSub;
  StreamSubscription? _errorSub;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _init();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _statusSub?.cancel();
    _locationSub?.cancel();
    _errorSub?.cancel();
    _statusTimer?.cancel();
    _logsTimer?.cancel();
    _clockTimer?.cancel();
    super.dispose();
  }

  Future<void> _init() async {
    setState(() => _isLoading = true);

    // Server DB is the single source of truth
    await _state.checkStatus(widget.employeeId);

    if (_state.dayStatus == DayStatus.inProgress) {
      _attachListeners();
      _startTimers();
    }

    _fetchLogs(); // fire-and-forget
    if (mounted) setState(() => _isLoading = false);
  }

  void _startTimers() {
    // 1-min server status poll — detects if another device ended the day
    _statusTimer?.cancel();
    _statusTimer = Timer.periodic(const Duration(minutes: 1), (_) async {
      if (!mounted) return;
      await _state.checkStatus(widget.employeeId);
      if (mounted) setState(() {});

      // If the server now says completed (ended on another device), stop
      if (_state.dayStatus == DayStatus.completed) {
        _stopTimers();
      }
    });

    // 1-min log refresh
    _logsTimer?.cancel();
    _logsTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      _fetchLogs();
    });

    // 1-min clock repaint (shows elapsed time ticking)
    _clockTimer?.cancel();
    _clockTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  void _stopTimers() {
    _statusTimer?.cancel();
    _statusTimer = null;
    _logsTimer?.cancel();
    _logsTimer = null;
    _clockTimer?.cancel();
    _clockTimer = null;
  }

  // ── BACKGROUND SERVICE LISTENERS ──────────────────────────────────────────

  void _attachListeners() {
    if (_listenersAttached) return;
    _listenersAttached = true;

    Stream<Map<String, dynamic>?> statusStream;
    Stream<Map<String, dynamic>?> locationStream;
    Stream<Map<String, dynamic>?> errorStream;

    if (kIsWeb) {
      statusStream = webOn('status_update');
      locationStream = webOn('location_update');
      errorStream = webOn('service_error');
    } else if (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS) {
      statusStream = _service.on('status_update');
      locationStream = _service.on('location_update');
      errorStream = _service.on('service_error');
    } else {
      statusStream = desktopOn('status_update');
      locationStream = desktopOn('location_update');
      errorStream = desktopOn('service_error');
    }

    _statusSub = statusStream.listen((e) {
      if (!mounted || e == null) return;
      _state.updateSiteStatus(
        e['status'] == 'IN',
        e['site_name'] as String? ?? '',
      );
      setState(() {
        if (e['lat'] != null) {
          _position = LatLng(e['lat'] as double, e['lng'] as double);
          _accuracy = (e['accuracy'] as num).toDouble();
          _goodAccuracy = true;
        }
      });
      _fetchLogs();
    });

    _locationSub = locationStream.listen((e) {
      if (!mounted || e == null) return;
      setState(() {
        _position = LatLng(e['lat'] as double, e['lng'] as double);
        _accuracy = (e['accuracy'] as num).toDouble();
        _goodAccuracy = e['good'] as bool? ?? true;
      });
    });

    _errorSub = errorStream.listen((e) {
      if (!mounted || e == null) return;
      final reason = e['reason'] as String? ?? 'unknown';
      final String msg;
      switch (reason) {
        case 'no_background_location':
          msg = 'Background location permission required. Enable in Settings.';
          break;
        case 'location_permission_denied':
          msg = 'Location permission denied. Tracking cannot work without it.';
          break;
        case 'gps_error':
          msg = 'GPS error: ${e['detail'] ?? 'unknown'}';
          break;
        case 'gps_stream_closed':
          msg = 'GPS stopped unexpectedly. Please restart the app.';
          break;
        default:
          msg = 'Tracking error: $reason';
      }
      _showSnack(msg, isError: true);
    });
  }

  // ── FETCH LOGS (background, never blocks UI) ──────────────────────────────

  Future<void> _fetchLogs() async {
    try {
      final logs = await ApiService.getTodayLogs(widget.employeeId);
      if (mounted) setState(() => _logs = logs.cast<Map<String, dynamic>>());
    } catch (_) {
      // Network unavailable — keep showing cached list silently
    }
  }

  Future<void> _startWork() async {
    if (_isLoading) return;

    setState(() => _isLoading = true);

    // Always re-check server DB before starting
    await _state.checkStatus(widget.employeeId);

    if (_state.dayStatus == DayStatus.completed) {
      if (mounted) setState(() => _isLoading = false);
      _showSnack('Your work day is already complete for today.');
      return;
    }

    if (_state.dayStatus == DayStatus.inProgress) {
      if (mounted) setState(() => _isLoading = false);
      _showSnack('Tracking is already active.');
      if (!_listenersAttached) {
        _attachListeners();
        _startTimers();
        if (mounted) setState(() {});
      }
      return;
    }

    // ── Location permissions (Android / iOS only) ──────────────────────────
    if (!kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS)) {
      // Fine location
      if (!await Permission.locationWhenInUse.isGranted) {
        final s = await Permission.locationWhenInUse.request();
        if (!s.isGranted) {
          if (mounted) setState(() => _isLoading = false);
          _showSnack('Location permission is required to track attendance.');
          return;
        }
      }

      // Background location
      if (!await Permission.locationAlways.isGranted) {
        if (!mounted) return;
        final proceed = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Row(
              children: [
                Icon(Icons.location_on, color: Colors.indigo),
                SizedBox(width: 8),
                Text('Background Location Required'),
              ],
            ),
            content: const Text(
              "This app needs 'Allow all the time' location permission to "
              "track your attendance when the app is in the background.\n\n"
              "Please select 'Allow all the time' on the next screen.",
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Continue'),
              ),
            ],
          ),
        );
        if (proceed != true) {
          if (mounted) setState(() => _isLoading = false);
          return;
        }
        final bgStatus = await Permission.locationAlways.request();
        if (!bgStatus.isGranted) {
          if (mounted) setState(() => _isLoading = false);
          _showSnack(
            'Background location denied. Tracking cannot work without it.',
          );
          return;
        }
      }
    }

    // ── Start tracking ─────────────────────────────────────────────────────
    try {
      // Save local state (offline fallback)
      await _state.start(widget.employeeId);

      // Fetch site polygons from server → SQLite → start service
      await startBackgroundTracking(widget.employeeId);

      _attachListeners();
      _startTimers();
      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      _showSnack('Failed to start tracking: $e', isError: true);
    }
  }

  Future<void> _endWork() async {
    if (_state.dayStatus != DayStatus.inProgress || _isLoading) return;

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.stop_circle_outlined, color: Colors.red),
            SizedBox(width: 8),
            Text('End Work Day?'),
          ],
        ),
        content: const Text(
          'This stops location tracking for today.\n\n'
          'You cannot start again until tomorrow.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('End Day', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _isLoading = true);

    // Signal background service → waits for end_day_done (10 s timeout)
    final serviceConfirmed = await sendEndDay();

    if (!serviceConfirmed) {
      try {
        final data = await ApiService.getTodayStatus(widget.employeeId);
        // Server returns 'completed' when DB has ended_manually
        if ((data['status'] as String?) != 'completed') {
          if (mounted) setState(() => _isLoading = false);
          _showSnack(
            'Could not confirm end of day. Please try again.',
            isError: true,
          );
          return;
        }
      } catch (_) {
        // Server unreachable — trust the local end() call below.
      }
    }

    // Lock local state for the rest of the day
    await _state.end();
    _stopTimers();

    if (mounted) setState(() => _isLoading = false);

    // Final log refresh so the UI shows the closed-out visit
    _fetchLogs();
  }

  // ── HELPERS ───────────────────────────────────────────────────────────────

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.red.shade700 : null,
        duration: Duration(seconds: isError ? 5 : 3),
      ),
    );
  }

  String _fmtDuration(int? m) {
    if (m == null) return '--';
    return m < 60
        ? '${m}m'
        : '${m ~/ 60}h ${(m % 60).toString().padLeft(2, '0')}m';
  }

  String _accuracyLabel() {
    if (_accuracy == null) return 'Acquiring GPS...';
    final a = _accuracy!;
    if (a <= 10) return '±${a.toStringAsFixed(0)}m · Excellent';
    if (a <= 20) return '±${a.toStringAsFixed(0)}m · Good';
    if (a <= 40) return '±${a.toStringAsFixed(0)}m · Fair';
    return '±${a.toStringAsFixed(0)}m · Poor';
  }

  Color _accuracyColor() {
    if (_accuracy == null) return Colors.grey;
    if (!_goodAccuracy) return Colors.orange;
    if (_accuracy! <= 10) return Colors.green;
    if (_accuracy! <= 20) return Colors.lightGreen;
    if (_accuracy! <= 40) return Colors.orange;
    return Colors.red;
  }

  int get _totalWorkedMinutes {
    int total = 0;
    for (final log in _logs) {
      final m = log['duration_minutes'];
      if (m != null) total += (m as num).toInt();
    }
    return total;
  }

  String get _totalWorkedLabel {
    final m = _totalWorkedMinutes;
    if (m == 0) return '--';
    final h = m ~/ 60;
    final min = (m % 60).toString().padLeft(2, '0');
    return h > 0 ? '${h}h ${min}m' : '${min}m';
  }

  // ── STATUS CARD CONFIG ────────────────────────────────────────────────────

  _StatusConfig get _statusConfig {
    switch (_state.dayStatus) {
      case DayStatus.completed:
        return _StatusConfig(
          gradient: const LinearGradient(
            colors: [Color(0xFF00897B), Color(0xFF26A69A)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          icon: Icons.check_circle_rounded,
          label: 'Work Day Complete',
          sublabel: 'Total on-site: $_totalWorkedLabel   👋 See you tomorrow!',
          dotColor: const Color(0xFF80CBC4),
          showPulse: false,
        );
      case DayStatus.inProgress:
        if (_state.isInsideSite) {
          return _StatusConfig(
            gradient: const LinearGradient(
              colors: [Color(0xFF2E7D32), Color(0xFF43A047)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            icon: Icons.location_on_rounded,
            label: "You're On Site",
            sublabel: _state.currentSiteName,
            dotColor: const Color(0xFFA5D6A7),
            showPulse: true,
          );
        }
        return _StatusConfig(
          gradient: const LinearGradient(
            colors: [Color(0xFF1565C0), Color(0xFF1E88E5)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          icon: Icons.radar_rounded,
          label: 'Tracking Active',
          sublabel: 'Outside registered sites',
          dotColor: const Color(0xFF90CAF9),
          showPulse: true,
        );
      case DayStatus.notStarted:
        return _StatusConfig(
          gradient: const LinearGradient(
            colors: [Color(0xFF455A64), Color(0xFF607D8B)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          icon: Icons.fingerprint_rounded,
          label: 'Not Started',
          sublabel: 'Tap START when you arrive',
          dotColor: const Color(0xFFB0BEC5),
          showPulse: false,
        );
    }
  }

  // ── BUILD ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isRunning = _state.dayStatus == DayStatus.inProgress;
    final notStarted = _state.dayStatus == DayStatus.notStarted;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        centerTitle: true,
        title: const Text(
          'Attendance',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: Colors.grey.shade200, height: 1),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: Column(
          children: [
            _buildStatusCard(),
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(
                  Icons.list_alt_rounded,
                  size: 17,
                  color: Colors.indigo,
                ),
                const SizedBox(width: 7),
                Text(
                  "Today's Site Visits",
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey[800],
                    letterSpacing: 0.2,
                  ),
                ),
                const Spacer(),
                // Manual refresh button (available any time, not just in-progress)
                InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: _fetchLogs,
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(
                      Icons.refresh_rounded,
                      size: 18,
                      color: Colors.indigo.shade300,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(child: _buildLogList(isRunning)),
            const SizedBox(height: 12),
            _buildButtons(isRunning, notStarted),
          ],
        ),
      ),
    );
  }

  // ── STATUS CARD ───────────────────────────────────────────────────────────

  Widget _buildStatusCard() {
    if (_isLoading) {
      return Container(
        height: 170,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    final cfg = _statusConfig;
    final isRunning = _state.dayStatus == DayStatus.inProgress;

    return Container(
      decoration: BoxDecoration(
        gradient: cfg.gradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: cfg.gradient.colors.first.withValues(alpha: 0.35),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Top row: icon + label + pulse dot ───────────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(cfg.icon, color: Colors.white, size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        cfg.label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.1,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        cfg.sublabel,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.82),
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (cfg.showPulse)
                  AnimatedBuilder(
                    animation: _pulseAnim,
                    builder: (_, _) => Transform.scale(
                      scale: _pulseAnim.value,
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: cfg.dotColor,
                          boxShadow: [
                            BoxShadow(
                              color: cfg.dotColor.withValues(alpha: 0.7),
                              blurRadius: 8,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                else
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: cfg.dotColor.withValues(alpha: 0.5),
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 16),
            Container(height: 1, color: Colors.white.withValues(alpha: 0.15)),
            const SizedBox(height: 14),

            // ── Bottom row: totals + GPS ─────────────────────────────────────
            Row(
              children: [
                if (_state.dayStatus != DayStatus.notStarted) ...[
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Total On-Site',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.white.withValues(alpha: 0.6),
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.4,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(
                            Icons.timelapse_rounded,
                            size: 14,
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            _totalWorkedLabel,
                            style: const TextStyle(
                              fontSize: 15,
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.2,
                            ),
                          ),
                          if (_logs.length > 1) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '${_logs.length} visits',
                                style: TextStyle(
                                  fontSize: 9.5,
                                  color: Colors.white.withValues(alpha: 0.8),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(width: 16),
                  Container(
                    width: 1,
                    height: 32,
                    color: Colors.white.withValues(alpha: 0.2),
                  ),
                  const SizedBox(width: 16),
                ],
                if (isRunning)
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'GPS Signal',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.white.withValues(alpha: 0.6),
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.4,
                          ),
                        ),
                        const SizedBox(height: 2),
                        _position == null
                            ? _infoChip(
                                icon: Icons.gps_not_fixed,
                                label: 'Acquiring...',
                                spinning: true,
                              )
                            : _infoChipColor(
                                icon: _goodAccuracy
                                    ? Icons.gps_fixed
                                    : Icons.gps_not_fixed,
                                label: _accuracyLabel(),
                                color: _accuracyColor(),
                              ),
                      ],
                    ),
                  )
                else
                  const Spacer(),
              ],
            ),

            if (isRunning && _position != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.location_pin,
                    size: 11,
                    color: Colors.white.withValues(alpha: 0.6),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${_position!.latitude.toStringAsFixed(6)}, '
                    '${_position!.longitude.toStringAsFixed(6)}',
                    style: TextStyle(
                      fontSize: 10.5,
                      color: Colors.white.withValues(alpha: 0.6),
                      fontFamily: 'monospace',
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _infoChip({
    required IconData icon,
    required String label,
    bool spinning = false,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        spinning
            ? SizedBox(
                width: 11,
                height: 11,
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  color: Colors.white.withValues(alpha: 0.75),
                ),
              )
            : Icon(icon, size: 13, color: Colors.white.withValues(alpha: 0.75)),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            color: Colors.white.withValues(alpha: 0.85),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _infoChipColor({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            color: Colors.white.withValues(alpha: 0.85),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  // ── LOG LIST ──────────────────────────────────────────────────────────────

  Widget _buildLogList(bool isRunning) {
    if (_logs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.location_off_outlined,
              size: 40,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 10),
            Text(
              isRunning ? 'No site visits yet' : 'No attendance today',
              style: TextStyle(color: Colors.grey[400], fontSize: 13),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      itemCount: _logs.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final log = _logs[i];
        final isOpen = log['out_time'] == null;
        final duration = log['duration_minutes'] as int?;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isOpen ? Colors.green.shade200 : Colors.grey.shade200,
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: isOpen ? Colors.green.shade50 : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isOpen
                      ? Icons.radio_button_on_rounded
                      : Icons.check_circle_outline_rounded,
                  size: 18,
                  color: isOpen ? Colors.green : Colors.grey,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      log['site_name'] as String? ?? 'Unknown',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13.5,
                        color: Color(0xFF1A1A2E),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        _timeTag(
                          icon: Icons.login_rounded,
                          time: log['in_time'] as String? ?? '--',
                          color: Colors.green.shade700,
                          bg: Colors.green.shade50,
                        ),
                        const SizedBox(width: 6),
                        _timeTag(
                          icon: Icons.logout_rounded,
                          time: isOpen
                              ? 'Active'
                              : (log['out_time'] as String? ?? '--'),
                          color: isOpen
                              ? Colors.orange.shade700
                              : Colors.red.shade400,
                          bg: isOpen
                              ? Colors.orange.shade50
                              : Colors.red.shade50,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  gradient: isOpen
                      ? LinearGradient(
                          colors: [
                            Colors.green.shade400,
                            Colors.green.shade600,
                          ],
                        )
                      : LinearGradient(
                          colors: [Colors.grey.shade300, Colors.grey.shade400],
                        ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  _fmtDuration(duration),
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: isOpen ? Colors.white : Colors.grey.shade700,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _timeTag({
    required IconData icon,
    required String time,
    required Color color,
    required Color bg,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 3),
          Text(
            time,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ── BUTTONS ───────────────────────────────────────────────────────────────

  Widget _buildButtons(bool isRunning, bool notStarted) {
    return Row(
      children: [
        Expanded(
          child: _ActionButton(
            label: 'START',
            icon: Icons.play_arrow_rounded,
            gradient: const LinearGradient(
              colors: [Color(0xFF2E7D32), Color(0xFF43A047)],
            ),
            onPressed: (notStarted && !_isLoading) ? _startWork : null,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: _ActionButton(
            label: 'END',
            icon: Icons.stop_rounded,
            gradient: const LinearGradient(
              colors: [Color(0xFFC62828), Color(0xFFE53935)],
            ),
            onPressed: (isRunning && !_isLoading) ? _endWork : null,
          ),
        ),
      ],
    );
  }
}

// ── STATUS CONFIG ─────────────────────────────────────────────────────────────

class _StatusConfig {
  final LinearGradient gradient;
  final IconData icon;
  final String label;
  final String sublabel;
  final Color dotColor;
  final bool showPulse;

  const _StatusConfig({
    required this.gradient,
    required this.icon,
    required this.label,
    required this.sublabel,
    required this.dotColor,
    required this.showPulse,
  });
}

// ── ACTION BUTTON ─────────────────────────────────────────────────────────────

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final LinearGradient gradient;
  final VoidCallback? onPressed;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.gradient,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return GestureDetector(
      onTap: onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 56,
        decoration: BoxDecoration(
          gradient: enabled ? gradient : null,
          color: enabled ? null : Colors.grey.shade300,
          borderRadius: BorderRadius.circular(16),
          boxShadow: enabled
              ? [
                  BoxShadow(
                    color: gradient.colors.first.withValues(alpha: 0.4),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: enabled ? Colors.white : Colors.grey.shade500,
              size: 22,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: enabled ? Colors.white : Colors.grey.shade500,
                fontSize: 15,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
