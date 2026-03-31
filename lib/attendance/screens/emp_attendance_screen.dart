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

  Timer? _statusTimer;
  Timer? _logsTimer;
  Timer? _clockTimer;

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
    await _state.checkStatus(widget.employeeId);
    if (_state.dayStatus == DayStatus.inProgress) {
      _attachListeners();
      _startTimers();
    }
    _fetchLogs();
    if (mounted) setState(() => _isLoading = false);
  }

  void _startTimers() {
    _statusTimer?.cancel();
    _statusTimer = Timer.periodic(const Duration(minutes: 1), (_) async {
      if (!mounted) return;
      await _state.checkStatus(widget.employeeId);
      if (mounted) setState(() {});
      if (_state.dayStatus == DayStatus.completed) _stopTimers();
    });
    _logsTimer?.cancel();
    _logsTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => _fetchLogs(),
    );
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

  Future<void> _fetchLogs() async {
    try {
      final logs = await ApiService.getTodayLogs(widget.employeeId);
      if (mounted) setState(() => _logs = logs.cast<Map<String, dynamic>>());
    } catch (_) {}
  }

  Future<void> _startWork() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

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

    if (!kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS)) {
      if (!await Permission.locationWhenInUse.isGranted) {
        final s = await Permission.locationWhenInUse.request();
        if (!s.isGranted) {
          if (mounted) setState(() => _isLoading = false);
          _showSnack('Location permission is required to track attendance.');
          return;
        }
      }

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

    try {
      await _state.start(widget.employeeId);
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

    final serviceConfirmed = await sendEndDay();

    if (!serviceConfirmed) {
      try {
        final data = await ApiService.getTodayStatus(widget.employeeId);
        if ((data['status'] as String?) != 'completed') {
          if (mounted) setState(() => _isLoading = false);
          _showSnack(
            'Could not confirm end of day. Please try again.',
            isError: true,
          );
          return;
        }
      } catch (_) {}
    }

    await _state.end();
    _stopTimers();
    if (mounted) setState(() => _isLoading = false);
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
    // ── Responsive helpers ──────────────────────────────────────────────────
    final mq = MediaQuery.of(context);
    final sw = mq.size.width;
    final sh = mq.size.height;
    final isSmall = sw < 360; // very small phones (SE 1st gen)
    final isCompact = sh < 680; // short screens (landscape / SE)
    final safeBottom = mq.padding.bottom; // home-bar height (notch phones)

    final isRunning = _state.dayStatus == DayStatus.inProgress;
    final notStarted = _state.dayStatus == DayStatus.notStarted;

    // ── Adaptive sizing ─────────────────────────────────────────────────────
    final hPad = isSmall ? 12.0 : 16.0; // horizontal screen padding
    final cardPad = isSmall ? 14.0 : 20.0; // status card inner padding
    final gap = isCompact ? 10.0 : 16.0; // spacing between sections
    final btnHeight = isSmall ? 48.0 : 54.0; // START / END button height
    final btnRadius = isSmall ? 12.0 : 16.0; // button corner radius
    final btnFontSize = isSmall ? 13.0 : 15.0; // button label size
    final btnIconSize = isSmall ? 19.0 : 22.0; // button icon size

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      body: SafeArea(
        // SafeArea handles top notch; we handle bottom manually so the
        // home-bar gap isn't swallowed by an extra blank area.
        bottom: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(hPad, hPad, hPad, 0),
          child: Column(
            children: [
              // ── Status card ───────────────────────────────────────────────
              _buildStatusCard(cardPad: cardPad, isCompact: isCompact),

              SizedBox(height: gap),

              // ── Section header ────────────────────────────────────────────
              Row(
                children: [
                  Icon(
                    Icons.list_alt_rounded,
                    size: isSmall ? 15 : 17,
                    color: Colors.indigo,
                  ),
                  SizedBox(width: isSmall ? 5 : 7),
                  Text(
                    "Today's Site Visits",
                    style: TextStyle(
                      fontSize: isSmall ? 12 : 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey[800],
                      letterSpacing: 0.2,
                    ),
                  ),
                  const Spacer(),
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

              SizedBox(height: isSmall ? 6 : 8),

              // ── Log list (fills remaining space) ──────────────────────────
              Expanded(child: _buildLogList(isRunning, isSmall: isSmall)),

              // ── START / END buttons ───────────────────────────────────────
              // Uses intrinsic height so it never overflows, even on SE.
              Padding(
                padding: EdgeInsets.only(
                  top: gap,
                  // Leave room for home-bar + a little breathing space
                  bottom: safeBottom + (isSmall ? 8 : 12),
                ),
                child: _buildButtons(
                  isRunning: isRunning,
                  notStarted: notStarted,
                  height: btnHeight,
                  radius: btnRadius,
                  fontSize: btnFontSize,
                  iconSize: btnIconSize,
                  isSmall: isSmall,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── STATUS CARD ───────────────────────────────────────────────────────────

  Widget _buildStatusCard({required double cardPad, required bool isCompact}) {
    if (_isLoading) {
      return Container(
        height: isCompact ? 130 : 170,
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
        padding: EdgeInsets.all(cardPad),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Top row ──────────────────────────────────────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: isCompact ? 38 : 46,
                  height: isCompact ? 38 : 46,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    cfg.icon,
                    color: Colors.white,
                    size: isCompact ? 22 : 26,
                  ),
                ),
                SizedBox(width: isCompact ? 10 : 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        cfg.label,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: isCompact ? 15 : 17,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.1,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        cfg.sublabel,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.82),
                          fontSize: isCompact ? 11 : 12.5,
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

            // Hide the divider + bottom row on very short screens to save space
            if (!isCompact) ...[
              const SizedBox(height: 16),
              Container(height: 1, color: Colors.white.withValues(alpha: 0.15)),
              const SizedBox(height: 14),
              _buildCardBottom(isRunning: isRunning, isCompact: false),
            ] else ...[
              const SizedBox(height: 10),
              _buildCardBottom(isRunning: isRunning, isCompact: true),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCardBottom({required bool isRunning, required bool isCompact}) {
    return Row(
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
                    style: TextStyle(
                      fontSize: isCompact ? 13 : 15,
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

  Widget _buildLogList(bool isRunning, {required bool isSmall}) {
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
      // Prevent the list's own bottom padding from hiding behind the buttons
      padding: EdgeInsets.zero,
      itemCount: _logs.length,
      separatorBuilder: (_, _) => SizedBox(height: isSmall ? 6 : 8),
      itemBuilder: (_, i) {
        final log = _logs[i];
        final isOpen = log['out_time'] == null;
        final duration = log['duration_minutes'] as int?;

        return Container(
          padding: EdgeInsets.symmetric(
            horizontal: isSmall ? 10 : 14,
            vertical: isSmall ? 9 : 12,
          ),
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
                width: isSmall ? 30 : 36,
                height: isSmall ? 30 : 36,
                decoration: BoxDecoration(
                  color: isOpen ? Colors.green.shade50 : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isOpen
                      ? Icons.radio_button_on_rounded
                      : Icons.check_circle_outline_rounded,
                  size: isSmall ? 15 : 18,
                  color: isOpen ? Colors.green : Colors.grey,
                ),
              ),
              SizedBox(width: isSmall ? 8 : 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      log['site_name'] as String? ?? 'Unknown',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: isSmall ? 12 : 13.5,
                        color: const Color(0xFF1A1A2E),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    // Wrap prevents time tags from overflowing on narrow screens
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        _timeTag(
                          icon: Icons.login_rounded,
                          time: log['in_time'] as String? ?? '--',
                          color: Colors.green.shade700,
                          bg: Colors.green.shade50,
                        ),
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
              const SizedBox(width: 8),
              // Duration badge — shrinks text on small screens
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isSmall ? 7 : 10,
                  vertical: isSmall ? 4 : 6,
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
                    fontSize: isSmall ? 10 : 11.5,
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

  Widget _buildButtons({
    required bool isRunning,
    required bool notStarted,
    required double height,
    required double radius,
    required double fontSize,
    required double iconSize,
    required bool isSmall,
  }) {
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
            height: height,
            radius: radius,
            fontSize: fontSize,
            iconSize: iconSize,
          ),
        ),
        SizedBox(width: isSmall ? 10 : 14),
        Expanded(
          child: _ActionButton(
            label: 'END',
            icon: Icons.stop_rounded,
            gradient: const LinearGradient(
              colors: [Color(0xFFC62828), Color(0xFFE53935)],
            ),
            onPressed: (isRunning && !_isLoading) ? _endWork : null,
            height: height,
            radius: radius,
            fontSize: fontSize,
            iconSize: iconSize,
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
  final double height;
  final double radius;
  final double fontSize;
  final double iconSize;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.gradient,
    required this.onPressed,
    required this.height,
    required this.radius,
    required this.fontSize,
    required this.iconSize,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return GestureDetector(
      onTap: onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: height,
        decoration: BoxDecoration(
          gradient: enabled ? gradient : null,
          color: enabled ? null : Colors.grey.shade300,
          borderRadius: BorderRadius.circular(radius),
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
              size: iconSize,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: enabled ? Colors.white : Colors.grey.shade500,
                fontSize: fontSize,
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
