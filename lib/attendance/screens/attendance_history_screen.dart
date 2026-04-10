import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

const String _ahBaseUrl = 'http://192.168.29.216:3000';

class AttendanceHistoryScreen extends StatefulWidget {
  final int employeeId;
  const AttendanceHistoryScreen({super.key, required this.employeeId});

  @override
  State<AttendanceHistoryScreen> createState() =>
      _AttendanceHistoryScreenState();
}

class _AttendanceHistoryScreenState extends State<AttendanceHistoryScreen> {
  DateTime _focusedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  Map<String, Map<String, dynamic>> _dayData = {}; // key: 'yyyy-MM-dd'
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadMonth(_focusedMonth);
  }

  Future<void> _openInMaps(String siteName) async {
    // Search by site name (no coordinates stored in your data)
    final query = Uri.encodeComponent(siteName);
    final uris = [
      Uri.parse('geo:0,0?q=$query'), // Android native
      Uri.parse('https://maps.google.com/?q=$query'), // fallback
    ];

    for (final uri in uris) {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return;
      }
    }

    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Could not open maps app')));
    }
  }
  // ── Load month data ────────────────────────────────────────────────────────

  Future<void> _loadMonth(DateTime month) async {
    setState(() => _loading = true);
    try {
      // Load each day of the month that has passed
      final now = DateTime.now();
      final daysInMonth = DateUtils.getDaysInMonth(month.year, month.month);
      final futures = <Future>[];
      final results = <String, Map<String, dynamic>>{};

      for (int d = 1; d <= daysInMonth; d++) {
        final day = DateTime(month.year, month.month, d);
        if (day.isAfter(now)) continue;
        final dateStr = _fmtDate(day);
        futures.add(
          _fetchDay(dateStr).then((data) {
            if (data != null) results[dateStr] = data;
          }),
        );
      }
      await Future.wait(futures);
      if (mounted)
        setState(() {
          _dayData = results;
          _loading = false;
        });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<Map<String, dynamic>?> _fetchDay(String date) async {
    try {
      final res = await http.get(
        Uri.parse('$_ahBaseUrl/attendance/by-date-detail?date=$date'),
      );

      if (res.statusCode != 200) return null;

      final body = jsonDecode(res.body);
      if (body['success'] != true) return null;

      final List data = body['data'] ?? [];

      final emp = data.firstWhere(
        (e) => e['emp_id'] == widget.employeeId,
        orElse: () => null,
      );

      if (emp == null || emp['attendance_status'] == 'ABSENT') return null;

      int totalMinutes = 0;
      bool isLate = false;
      String? lateText;

      final sessions = emp['sessions'] as List? ?? [];

      for (int i = 0; i < sessions.length; i++) {
        final s = sessions[i];

        totalMinutes += (s['site_minutes'] as num? ?? 0).toInt();

        // ✅ GET LATE INFO FROM FIRST SESSION
        if (i == 0) {
          if (s['is_late'] == true) {
            isLate = true;

            final lateMin = (s['late_minutes'] as num?)?.toInt() ?? 0;

            if (lateMin > 0) {
              final h = lateMin ~/ 60;
              final m = lateMin % 60;

              lateText = h > 0
                  ? '${h}h ${m.toString().padLeft(2, '0')}m'
                  : '${m}m';
            }
          }
        }
      }

      return {
        'total_minutes': totalMinutes,
        'sessions': sessions,
        'is_late': isLate,
        'late_text': lateText,
      };
    } catch (e) {
      return null;
    }
  }
  // ── Fetch day detail (sessions + visits) for dialog ───────────────────────

  Future<Map<String, dynamic>?> _fetchDayDetail(String date) async {
    try {
      final res = await http.get(
        Uri.parse('$_ahBaseUrl/attendance/by-date-detail?date=$date'),
      );
      if (res.statusCode != 200) return null;
      final body = jsonDecode(res.body);
      if (body['success'] != true) return null;
      final List data = body['data'] ?? [];
      final emp = data.firstWhere(
        (e) => e['emp_id'] == widget.employeeId,
        orElse: () => null,
      );
      return emp as Map<String, dynamic>?;
    } catch (_) {
      return null;
    }
  }

  // Also fetch late info from today-summary endpoint
  Future<Map<String, dynamic>?> _fetchLateSummary(String date) async {
    // Use the today-summary only for today; for history use stored session data
    try {
      final res = await http.get(
        Uri.parse('$_ahBaseUrl/attendance/today-summary/${widget.employeeId}'),
      );
      if (res.statusCode == 200) return jsonDecode(res.body);
    } catch (_) {}
    return null;
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  String _fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _fmtTime(String? t) {
    if (t == null) return '--';
    // Format is 'yyyy-MM-dd HH:mm:ss' — just extract HH:mm directly
    try {
      if (t.contains(' ')) {
        // "2026-04-06 17:52:49" → "17:52"
        return t.split(' ')[1].substring(0, 5);
      }
      if (t.length >= 5) return t.substring(0, 5);
      return t;
    } catch (_) {
      return '--';
    }
  }

  String _fmtMinutes(int m) {
    if (m == 0) return '0m';
    final h = m ~/ 60;
    final min = m % 60;
    return h > 0 ? '${h}h ${min.toString().padLeft(2, '0')}m' : '${min}m';
  }

  String _monthLabel(DateTime d) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${months[d.month - 1]} ${d.year}';
  }

  bool _isToday(DateTime d) {
    final now = DateTime.now();
    return d.year == now.year && d.month == now.month && d.day == now.day;
  }

  bool _isFuture(DateTime d) => d.isAfter(DateTime.now());

  bool _isCurrentMonth(DateTime d) =>
      d.year == _focusedMonth.year && d.month == _focusedMonth.month;

  // ── Day tap ────────────────────────────────────────────────────────────────

  void _onDayTap(DateTime day) async {
    final dateStr = _fmtDate(day);
    final data = _dayData[dateStr];

    if (data == null) {
      if (!_isFuture(day)) {
        showDialog(context: context, builder: (_) => _buildAbsentDialog(day));
      }
      return;
    }

    final isLate = data['is_late'] == true;
    final lateText = data['late_text'];

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    final detail = await _fetchDayDetail(dateStr);
    if (!mounted) return;
    Navigator.pop(context);

    showDialog(
      context: context,
      builder: (_) => _buildDetailDialog(day, detail, isLate, lateText),
    );
  }
  // ── BUILD ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: _buildAppBar(),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Colors.indigo))
          : Column(
              children: [
                _buildMonthNav(),
                _buildWeekdayHeader(),
                Expanded(child: _buildCalendar()),
                _buildLegend(),
              ],
            ),
    );
  }

  PreferredSizeWidget _buildAppBar() => AppBar(
    backgroundColor: Colors.white,
    elevation: 0,
    leading: IconButton(
      icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF1A1A2E)),
      onPressed: () => Navigator.pop(context),
    ),
    title: const Text(
      'Attendance History',
      style: TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w700,
        color: Color(0xFF1A1A2E),
      ),
    ),
    bottom: PreferredSize(
      preferredSize: const Size.fromHeight(1),
      child: Container(height: 1, color: const Color(0xFFE2E8F0)),
    ),
  );

  Widget _buildMonthNav() => Container(
    color: Colors.white,
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    child: Row(
      children: [
        IconButton(
          onPressed: () {
            final prev = DateTime(_focusedMonth.year, _focusedMonth.month - 1);
            setState(() {
              _focusedMonth = prev;
              _dayData = {};
            });
            _loadMonth(prev);
          },
          icon: const Icon(Icons.chevron_left_rounded, color: Colors.indigo),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
        Expanded(
          child: Text(
            _monthLabel(_focusedMonth),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1A1A2E),
            ),
          ),
        ),
        IconButton(
          onPressed: () {
            final now = DateTime.now();
            final next = DateTime(_focusedMonth.year, _focusedMonth.month + 1);
            if (next.isAfter(DateTime(now.year, now.month))) return;
            setState(() {
              _focusedMonth = next;
              _dayData = {};
            });
            _loadMonth(next);
          },
          icon: Icon(
            Icons.chevron_right_rounded,
            color:
                DateTime(
                  _focusedMonth.year,
                  _focusedMonth.month + 1,
                ).isAfter(DateTime(DateTime.now().year, DateTime.now().month))
                ? Colors.grey.shade300
                : Colors.indigo,
          ),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
      ],
    ),
  );

  Widget _buildWeekdayHeader() => Container(
    color: Colors.white,
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      children: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
          .map(
            (d) => Expanded(
              child: Text(
                d,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: (d == 'Sun')
                      ? Colors.red.shade300
                      : Colors.grey.shade500,
                ),
              ),
            ),
          )
          .toList(),
    ),
  );

  Widget _buildCalendar() {
    final firstDay = DateTime(_focusedMonth.year, _focusedMonth.month, 1);
    // Monday = 1, so offset = weekday - 1
    final startOffset = (firstDay.weekday - 1) % 7;
    final daysInMonth = DateUtils.getDaysInMonth(
      _focusedMonth.year,
      _focusedMonth.month,
    );
    final totalCells = startOffset + daysInMonth;
    final rows = (totalCells / 7).ceil();

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        mainAxisSpacing: 6,
        crossAxisSpacing: 4,
        childAspectRatio: 0.72,
      ),
      itemCount: rows * 7,
      itemBuilder: (_, index) {
        final dayNum = index - startOffset + 1;
        if (dayNum < 1 || dayNum > daysInMonth) {
          return const SizedBox();
        }
        final day = DateTime(_focusedMonth.year, _focusedMonth.month, dayNum);
        return _buildDayCell(day);
      },
    );
  }

  Widget _buildDayCell(DateTime day) {
    final dateStr = _fmtDate(day);
    final data = _dayData[dateStr];
    final isToday = _isToday(day);
    final isFuture = _isFuture(day);
    final isSunday = day.weekday == DateTime.sunday;
    final isPresent = data != null;
    final totalMin = (data?['total_minutes'] as int?) ?? 0;
    final isLate = data?['is_late'] == true;
    final lateText = data?['late_text'] as String?;

    Color bgColor = Colors.white;
    Color textColor = const Color(0xFF1A1A2E);
    Color borderColor = const Color(0xFFE2E8F0);

    if (isFuture) {
      bgColor = Colors.grey.shade50;
      textColor = Colors.grey.shade300;
      borderColor = Colors.transparent;
    } else if (isToday) {
      borderColor = Colors.indigo;
    } else if (isPresent) {
      bgColor = const Color(0xFFE8F5E9);
      borderColor = const Color(0xFFA5D6A7);
    } else if (!isFuture) {
      // past absent
      bgColor = const Color(0xFFFFF3F3);
      borderColor = const Color(0xFFFFCDD2);
    }

    if (isSunday && !isFuture) {
      textColor = Colors.red.shade400;
    }

    return GestureDetector(
      onTap: isFuture ? null : () => _onDayTap(day),
      child: Container(
        decoration: BoxDecoration(
          color: isToday ? const Color(0xFFEEF2FF) : bgColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: borderColor, width: isToday ? 1.5 : 1),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            const SizedBox(height: 6),
            // Day number
            Container(
              width: 24,
              height: 24,
              decoration: isToday
                  ? BoxDecoration(color: Colors.indigo, shape: BoxShape.circle)
                  : null,
              child: Center(
                child: Text(
                  '${day.day}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isToday ? Colors.white : textColor,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            if (isPresent && !isFuture) ...[
              // Hours
              Text(
                _fmtMinutes(totalMin),
                style: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF2E7D32),
                ),
                textAlign: TextAlign.center,
              ),
              // Late badge
              if (isLate && lateText != null) ...[
                const SizedBox(height: 2),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 3,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Late',
                    style: TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.w700,
                      color: Colors.orange.shade800,
                    ),
                  ),
                ),
              ],
            ] else if (!isPresent &&
                !isFuture &&
                day.weekday != DateTime.sunday) ...[
              Text(
                'Absent',
                style: TextStyle(
                  fontSize: 8,
                  color: Colors.red.shade300,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLegend() => Container(
    color: Colors.white,
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _legendItem(
          const Color(0xFFE8F5E9),
          const Color(0xFFA5D6A7),
          'Present',
        ),
        const SizedBox(width: 16),
        _legendItem(const Color(0xFFFFF3F3), const Color(0xFFFFCDD2), 'Absent'),
        const SizedBox(width: 16),
        _legendItem(const Color(0xFFEEF2FF), Colors.indigo, 'Today'),
        const SizedBox(width: 16),
        Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: Colors.orange.shade100,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(width: 4),
            Text(
              'Late',
              style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _legendItem(Color bg, Color border, String label) => Row(
    children: [
      Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(
          color: bg,
          border: Border.all(color: border),
          borderRadius: BorderRadius.circular(3),
        ),
      ),
      const SizedBox(width: 4),
      Text(label, style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
    ],
  );

  // ── Dialogs ────────────────────────────────────────────────────────────────

  Widget _buildAbsentDialog(DateTime day) => AlertDialog(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
    contentPadding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
    title: Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.red.shade50,
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.event_busy_rounded,
            color: Colors.red.shade400,
            size: 18,
          ),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'No Attendance',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
            Text(
              _fullDate(day),
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade500,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ],
    ),
    content: Text(
      day.weekday == DateTime.sunday
          ? 'Sunday — weekly off.'
          : 'No attendance recorded for this day.',
      style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Close'),
      ),
    ],
  );

  Future<void> _openSiteInMaps(int? siteId, String siteName) async {
    double? lat, lng;

    // Try to get precise coordinates from backend
    if (siteId != null) {
      try {
        final res = await http.get(
          Uri.parse('$_ahBaseUrl/sites/$siteId/location'),
        );
        if (res.statusCode == 200) {
          final body = jsonDecode(res.body);
          if (body['success'] == true) {
            lat = (body['lat'] as num?)?.toDouble();
            lng = (body['lng'] as num?)?.toDouble();
          }
        }
      } catch (_) {}
    }

    final Uri uri;
    if (lat != null && lng != null) {
      // Precise pin with label
      uri = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=$lat,$lng&query_place_id=${Uri.encodeComponent(siteName)}',
      );
    } else {
      // Fallback: search by name
      uri = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(siteName)}',
      );
    }

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Could not open maps')));
    }
  }

  Widget _buildDetailDialog(
    DateTime day,
    Map<String, dynamic>? detail,
    bool isLate,
    String? lateText,
  ) {
    final sessions = (detail?['sessions'] as List?) ?? [];
    final totalMin = sessions.fold<int>(
      0,
      (s, e) => s + ((e['site_minutes'] as num?)?.toInt() ?? 0),
    );

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Header ────────────────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF3949AB), Color(0xFF1E88E5)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.calendar_today_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _fullDate(day),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),

                      const SizedBox(height: 4),

                      // ✅ LATE BADGE (NEW)
                      if (isLate && lateText != null)
                        Container(
                          margin: const EdgeInsets.only(bottom: 4),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade200,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'Late by $lateText',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Colors.black87,
                            ),
                          ),
                        ),

                      Text(
                        'Total: ${_fmtMinutes(totalMin)}  ·  ${sessions.length} session(s)',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.white.withOpacity(0.8),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(
                    Icons.close_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),

          // ── Sessions list ─────────────────────────────────────────────────────
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 420),
            child: sessions.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(32),
                    child: Text(
                      'No session data available.',
                      textAlign: TextAlign.center,
                    ),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.all(16),
                    itemCount: sessions.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, si) {
                      final sess = sessions[si];
                      final visits = (sess['visits'] as List?) ?? [];
                      final sessMin =
                          (sess['site_minutes'] as num?)?.toInt() ?? 0;
                      final sessNum = sess['session_number'] ?? (si + 1);

                      return Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFF),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Session header
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.indigo.shade50,
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(12),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.indigo,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      'Session $sessNum',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    _fmtTime(sess['started_at']?.toString()),
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                  const Text(' → '),
                                  Text(
                                    sess['ended_at'] != null
                                        ? _fmtTime(sess['ended_at'].toString())
                                        : 'Active',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: sess['ended_at'] != null
                                          ? Colors.grey.shade600
                                          : Colors.green,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    _fmtMinutes(sessMin),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF2E7D32),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Visits
                            if (visits.isEmpty)
                              Padding(
                                padding: const EdgeInsets.all(12),
                                child: Text(
                                  'No site visits in this session.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade500,
                                  ),
                                ),
                              )
                            else
                              ...visits.asMap().entries.map((e) {
                                final vi = e.key;
                                final v = e.value;
                                final isLast = vi == visits.length - 1;
                                final vMin =
                                    (v['worked_minutes'] as num?)?.toInt() ?? 0;
                                final isOpen = v['out_time'] == null;
                                final siteName =
                                    v['site_name'] as String? ?? 'Unknown Site';
                                final siteId = v['site_id'] as int?;

                                return InkWell(
                                  onTap: () =>
                                      _openSiteInMaps(siteId, siteName),
                                  borderRadius: isLast
                                      ? const BorderRadius.vertical(
                                          bottom: Radius.circular(12),
                                        )
                                      : BorderRadius.zero,
                                  child: Container(
                                    padding: const EdgeInsets.fromLTRB(
                                      14,
                                      10,
                                      14,
                                      10,
                                    ),
                                    decoration: BoxDecoration(
                                      border: Border(
                                        top: const BorderSide(
                                          color: Color(0xFFE2E8F0),
                                        ),
                                        bottom: isLast
                                            ? BorderSide.none
                                            : const BorderSide(
                                                color: Color(0xFFE2E8F0),
                                              ),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        // Status dot
                                        Container(
                                          width: 8,
                                          height: 8,
                                          decoration: BoxDecoration(
                                            color: isOpen
                                                ? Colors.green
                                                : Colors.grey.shade400,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        const SizedBox(width: 10),

                                        // Site name + times
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      siteName,
                                                      style: const TextStyle(
                                                        fontSize: 12,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color: Color(
                                                          0xFF1A1A2E,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                  // Map icon hint
                                                  Icon(
                                                    Icons.open_in_new_rounded,
                                                    size: 12,
                                                    color:
                                                        Colors.indigo.shade300,
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 3),
                                              Row(
                                                children: [
                                                  Icon(
                                                    Icons.login_rounded,
                                                    size: 10,
                                                    color:
                                                        Colors.green.shade600,
                                                  ),
                                                  const SizedBox(width: 3),
                                                  Text(
                                                    _fmtTime(
                                                      v['in_time']?.toString(),
                                                    ),
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      color:
                                                          Colors.grey.shade600,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Icon(
                                                    Icons.logout_rounded,
                                                    size: 10,
                                                    color: isOpen
                                                        ? Colors.orange
                                                        : Colors.red.shade400,
                                                  ),
                                                  const SizedBox(width: 3),
                                                  Text(
                                                    isOpen
                                                        ? 'Active'
                                                        : _fmtTime(
                                                            v['out_time']
                                                                ?.toString(),
                                                          ),
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      color: isOpen
                                                          ? Colors.orange
                                                          : Colors
                                                                .grey
                                                                .shade600,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 6),
                                                  Text(
                                                    'Tap to view map',
                                                    style: TextStyle(
                                                      fontSize: 9,
                                                      color: Colors
                                                          .indigo
                                                          .shade200,
                                                      fontStyle:
                                                          FontStyle.italic,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),

                                        // Duration badge
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 3,
                                          ),
                                          decoration: BoxDecoration(
                                            color: isOpen
                                                ? Colors.green.shade50
                                                : Colors.grey.shade100,
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                          ),
                                          child: Text(
                                            _fmtMinutes(vMin),
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w700,
                                              color: isOpen
                                                  ? Colors.green.shade700
                                                  : Colors.grey.shade600,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }),
                          ],
                        ),
                      );
                    },
                  ),
          ),

          // ── Footer ────────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  backgroundColor: const Color(0xFFEEF2FF),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text(
                  'Close',
                  style: TextStyle(
                    color: Colors.indigo,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _fullDate(DateTime d) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${days[d.weekday - 1]}, ${d.day} ${months[d.month - 1]} ${d.year}';
  }
}
