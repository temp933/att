// // import 'package:url_launcher/url_launcher.dart';
// // import 'dart:convert';
// // import 'package:flutter/material.dart';
// // import 'package:http/http.dart' as http;

// // const String baseUrl = 'http://192.168.29.216:3000';

// // class AttendanceHistoryScreen extends StatefulWidget {
// //   final int employeeId;
// //   const AttendanceHistoryScreen({super.key, required this.employeeId});

// //   @override
// //   State<AttendanceHistoryScreen> createState() =>
// //       _AttendanceHistoryScreenState();
// // }

// // class _AttendanceHistoryScreenState extends State<AttendanceHistoryScreen> {
// //   DateTime _focusedMonth = DateTime(DateTime.now().year, DateTime.now().month);
// //   Map<String, Map<String, dynamic>> _dayData = {}; // key: 'yyyy-MM-dd'
// //   bool _loading = true;

// //   @override
// //   void initState() {
// //     super.initState();
// //     _loadMonth(_focusedMonth);
// //   }

// //   Future<void> _openInMaps(String siteName) async {
// //     // Search by site name (no coordinates stored in your data)
// //     final query = Uri.encodeComponent(siteName);
// //     final uris = [
// //       Uri.parse('geo:0,0?q=$query'), // Android native
// //       Uri.parse('https://maps.google.com/?q=$query'), // fallback
// //     ];

// //     for (final uri in uris) {
// //       if (await canLaunchUrl(uri)) {
// //         await launchUrl(uri, mode: LaunchMode.externalApplication);
// //         return;
// //       }
// //     }

// //     if (mounted) {
// //       ScaffoldMessenger.of(
// //         context,
// //       ).showSnackBar(const SnackBar(content: Text('Could not open maps app')));
// //     }
// //   }
// //   // ── Load month data ────────────────────────────────────────────────────────

// //   Future<void> _loadMonth(DateTime month) async {
// //     setState(() => _loading = true);
// //     try {
// //       // Load each day of the month that has passed
// //       final now = DateTime.now();
// //       final daysInMonth = DateUtils.getDaysInMonth(month.year, month.month);
// //       final futures = <Future>[];
// //       final results = <String, Map<String, dynamic>>{};

// //       for (int d = 1; d <= daysInMonth; d++) {
// //         final day = DateTime(month.year, month.month, d);
// //         if (day.isAfter(now)) continue;
// //         final dateStr = _fmtDate(day);
// //         futures.add(
// //           _fetchDay(dateStr).then((data) {
// //             if (data != null) results[dateStr] = data;
// //           }),
// //         );
// //       }
// //       await Future.wait(futures);
// //       if (mounted)
// //         setState(() {
// //           _dayData = results;
// //           _loading = false;
// //         });
// //     } catch (_) {
// //       if (mounted) setState(() => _loading = false);
// //     }
// //   }

// //   Future<Map<String, dynamic>?> _fetchDay(String date) async {
// //     try {
// //       final res = await http.get(
// //         Uri.parse('$baseUrl/attendance/by-date-detail?date=$date'),
// //       );

// //       if (res.statusCode != 200) return null;

// //       final body = jsonDecode(res.body);
// //       if (body['success'] != true) return null;

// //       final List data = body['data'] ?? [];

// //       final emp = data.firstWhere(
// //         (e) => e['emp_id'] == widget.employeeId,
// //         orElse: () => null,
// //       );

// //       if (emp == null || emp['attendance_status'] == 'ABSENT') return null;

// //       int totalMinutes = 0;
// //       bool isLate = false;
// //       String? lateText;

// //       final sessions = emp['sessions'] as List? ?? [];

// //       for (int i = 0; i < sessions.length; i++) {
// //         final s = sessions[i];

// //         totalMinutes += (s['site_minutes'] as num? ?? 0).toInt();

// //         // ✅ GET LATE INFO FROM FIRST SESSION
// //         if (i == 0) {
// //           if (s['is_late'] == true) {
// //             isLate = true;

// //             final lateMin = (s['late_minutes'] as num?)?.toInt() ?? 0;

// //             if (lateMin > 0) {
// //               final h = lateMin ~/ 60;
// //               final m = lateMin % 60;

// //               lateText = h > 0
// //                   ? '${h}h ${m.toString().padLeft(2, '0')}m'
// //                   : '${m}m';
// //             }
// //           }
// //         }
// //       }

// //       return {
// //         'total_minutes': totalMinutes,
// //         'sessions': sessions,
// //         'is_late': isLate,
// //         'late_text': lateText,
// //       };
// //     } catch (e) {
// //       return null;
// //     }
// //   }
// //   // ── Fetch day detail (sessions + visits) for dialog ───────────────────────

// //   Future<Map<String, dynamic>?> _fetchDayDetail(String date) async {
// //     try {
// //       final res = await http.get(
// //         Uri.parse('$baseUrl/attendance/by-date-detail?date=$date'),
// //       );
// //       if (res.statusCode != 200) return null;
// //       final body = jsonDecode(res.body);
// //       if (body['success'] != true) return null;
// //       final List data = body['data'] ?? [];
// //       final emp = data.firstWhere(
// //         (e) => e['emp_id'] == widget.employeeId,
// //         orElse: () => null,
// //       );
// //       return emp as Map<String, dynamic>?;
// //     } catch (_) {
// //       return null;
// //     }
// //   }

// //   // Also fetch late info from today-summary endpoint
// //   Future<Map<String, dynamic>?> _fetchLateSummary(String date) async {
// //     // Use the today-summary only for today; for history use stored session data
// //     try {
// //       final res = await http.get(
// //         Uri.parse('$baseUrl/attendance/today-summary/${widget.employeeId}'),
// //       );
// //       if (res.statusCode == 200) return jsonDecode(res.body);
// //     } catch (_) {}
// //     return null;
// //   }

// //   // ── Helpers ────────────────────────────────────────────────────────────────

// //   String _fmtDate(DateTime d) =>
// //       '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

// //   String _fmtTime(String? t) {
// //     if (t == null) return '--';
// //     // Format is 'yyyy-MM-dd HH:mm:ss' — just extract HH:mm directly
// //     try {
// //       if (t.contains(' ')) {
// //         // "2026-04-06 17:52:49" → "17:52"
// //         return t.split(' ')[1].substring(0, 5);
// //       }
// //       if (t.length >= 5) return t.substring(0, 5);
// //       return t;
// //     } catch (_) {
// //       return '--';
// //     }
// //   }

// //   String _fmtMinutes(int m) {
// //     if (m == 0) return '0m';
// //     final h = m ~/ 60;
// //     final min = m % 60;
// //     return h > 0 ? '${h}h ${min.toString().padLeft(2, '0')}m' : '${min}m';
// //   }

// //   String _monthLabel(DateTime d) {
// //     const months = [
// //       'January',
// //       'February',
// //       'March',
// //       'April',
// //       'May',
// //       'June',
// //       'July',
// //       'August',
// //       'September',
// //       'October',
// //       'November',
// //       'December',
// //     ];
// //     return '${months[d.month - 1]} ${d.year}';
// //   }

// //   bool _isToday(DateTime d) {
// //     final now = DateTime.now();
// //     return d.year == now.year && d.month == now.month && d.day == now.day;
// //   }

// //   bool _isFuture(DateTime d) => d.isAfter(DateTime.now());

// //   bool _isCurrentMonth(DateTime d) =>
// //       d.year == _focusedMonth.year && d.month == _focusedMonth.month;

// //   // ── Day tap ────────────────────────────────────────────────────────────────

// //   void _onDayTap(DateTime day) async {
// //     final dateStr = _fmtDate(day);
// //     final data = _dayData[dateStr];

// //     if (data == null) {
// //       if (!_isFuture(day)) {
// //         showDialog(context: context, builder: (_) => _buildAbsentDialog(day));
// //       }
// //       return;
// //     }

// //     final isLate = data['is_late'] == true;
// //     final lateText = data['late_text'];

// //     showDialog(
// //       context: context,
// //       barrierDismissible: false,
// //       builder: (_) => const Center(child: CircularProgressIndicator()),
// //     );

// //     final detail = await _fetchDayDetail(dateStr);
// //     if (!mounted) return;
// //     Navigator.pop(context);

// //     showDialog(
// //       context: context,
// //       builder: (_) => _buildDetailDialog(day, detail, isLate, lateText),
// //     );
// //   }
// //   // ── BUILD ──────────────────────────────────────────────────────────────────

// //   @override
// //   Widget build(BuildContext context) {
// //     return Scaffold(
// //       backgroundColor: const Color(0xFFF5F6FA),
// //       appBar: _buildAppBar(),
// //       body: _loading
// //           ? const Center(child: CircularProgressIndicator(color: Colors.indigo))
// //           : Column(
// //               children: [
// //                 _buildMonthNav(),
// //                 _buildWeekdayHeader(),
// //                 Expanded(child: _buildCalendar()),
// //                 _buildLegend(),
// //               ],
// //             ),
// //     );
// //   }

// //   PreferredSizeWidget _buildAppBar() => AppBar(
// //     backgroundColor: Colors.white,
// //     elevation: 0,
// //     leading: IconButton(
// //       icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF1A1A2E)),
// //       onPressed: () => Navigator.pop(context),
// //     ),
// //     title: const Text(
// //       'Attendance History',
// //       style: TextStyle(
// //         fontSize: 17,
// //         fontWeight: FontWeight.w700,
// //         color: Color(0xFF1A1A2E),
// //       ),
// //     ),
// //     bottom: PreferredSize(
// //       preferredSize: const Size.fromHeight(1),
// //       child: Container(height: 1, color: const Color(0xFFE2E8F0)),
// //     ),
// //   );

// //   Widget _buildMonthNav() => Container(
// //     color: Colors.white,
// //     padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
// //     child: Row(
// //       children: [
// //         IconButton(
// //           onPressed: () {
// //             final prev = DateTime(_focusedMonth.year, _focusedMonth.month - 1);
// //             setState(() {
// //               _focusedMonth = prev;
// //               _dayData = {};
// //             });
// //             _loadMonth(prev);
// //           },
// //           icon: const Icon(Icons.chevron_left_rounded, color: Colors.indigo),
// //           padding: EdgeInsets.zero,
// //           constraints: const BoxConstraints(),
// //         ),
// //         Expanded(
// //           child: Text(
// //             _monthLabel(_focusedMonth),
// //             textAlign: TextAlign.center,
// //             style: const TextStyle(
// //               fontSize: 16,
// //               fontWeight: FontWeight.w700,
// //               color: Color(0xFF1A1A2E),
// //             ),
// //           ),
// //         ),
// //         IconButton(
// //           onPressed: () {
// //             final now = DateTime.now();
// //             final next = DateTime(_focusedMonth.year, _focusedMonth.month + 1);
// //             if (next.isAfter(DateTime(now.year, now.month))) return;
// //             setState(() {
// //               _focusedMonth = next;
// //               _dayData = {};
// //             });
// //             _loadMonth(next);
// //           },
// //           icon: Icon(
// //             Icons.chevron_right_rounded,
// //             color:
// //                 DateTime(
// //                   _focusedMonth.year,
// //                   _focusedMonth.month + 1,
// //                 ).isAfter(DateTime(DateTime.now().year, DateTime.now().month))
// //                 ? Colors.grey.shade300
// //                 : Colors.indigo,
// //           ),
// //           padding: EdgeInsets.zero,
// //           constraints: const BoxConstraints(),
// //         ),
// //       ],
// //     ),
// //   );

// //   Widget _buildWeekdayHeader() => Container(
// //     color: Colors.white,
// //     padding: const EdgeInsets.only(bottom: 8),
// //     child: Row(
// //       children: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
// //           .map(
// //             (d) => Expanded(
// //               child: Text(
// //                 d,
// //                 textAlign: TextAlign.center,
// //                 style: TextStyle(
// //                   fontSize: 11,
// //                   fontWeight: FontWeight.w600,
// //                   color: (d == 'Sun')
// //                       ? Colors.red.shade300
// //                       : Colors.grey.shade500,
// //                 ),
// //               ),
// //             ),
// //           )
// //           .toList(),
// //     ),
// //   );

// //   Widget _buildCalendar() {
// //     final firstDay = DateTime(_focusedMonth.year, _focusedMonth.month, 1);
// //     // Monday = 1, so offset = weekday - 1
// //     final startOffset = (firstDay.weekday - 1) % 7;
// //     final daysInMonth = DateUtils.getDaysInMonth(
// //       _focusedMonth.year,
// //       _focusedMonth.month,
// //     );
// //     final totalCells = startOffset + daysInMonth;
// //     final rows = (totalCells / 7).ceil();

// //     return GridView.builder(
// //       padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
// //       gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
// //         crossAxisCount: 7,
// //         mainAxisSpacing: 6,
// //         crossAxisSpacing: 4,
// //         childAspectRatio: 0.72,
// //       ),
// //       itemCount: rows * 7,
// //       itemBuilder: (_, index) {
// //         final dayNum = index - startOffset + 1;
// //         if (dayNum < 1 || dayNum > daysInMonth) {
// //           return const SizedBox();
// //         }
// //         final day = DateTime(_focusedMonth.year, _focusedMonth.month, dayNum);
// //         return _buildDayCell(day);
// //       },
// //     );
// //   }

// //   Widget _buildDayCell(DateTime day) {
// //     final dateStr = _fmtDate(day);
// //     final data = _dayData[dateStr];
// //     final isToday = _isToday(day);
// //     final isFuture = _isFuture(day);
// //     final isSunday = day.weekday == DateTime.sunday;
// //     final isPresent = data != null;
// //     final totalMin = (data?['total_minutes'] as int?) ?? 0;
// //     final isLate = data?['is_late'] == true;
// //     final lateText = data?['late_text'] as String?;

// //     Color bgColor = Colors.white;
// //     Color textColor = const Color(0xFF1A1A2E);
// //     Color borderColor = const Color(0xFFE2E8F0);

// //     if (isFuture) {
// //       bgColor = Colors.grey.shade50;
// //       textColor = Colors.grey.shade300;
// //       borderColor = Colors.transparent;
// //     } else if (isToday) {
// //       borderColor = Colors.indigo;
// //     } else if (isPresent) {
// //       bgColor = const Color(0xFFE8F5E9);
// //       borderColor = const Color(0xFFA5D6A7);
// //     } else if (!isFuture) {
// //       // past absent
// //       bgColor = const Color(0xFFFFF3F3);
// //       borderColor = const Color(0xFFFFCDD2);
// //     }

// //     if (isSunday && !isFuture) {
// //       textColor = Colors.red.shade400;
// //     }

// //     return GestureDetector(
// //       onTap: isFuture ? null : () => _onDayTap(day),
// //       child: Container(
// //         decoration: BoxDecoration(
// //           color: isToday ? const Color(0xFFEEF2FF) : bgColor,
// //           borderRadius: BorderRadius.circular(10),
// //           border: Border.all(color: borderColor, width: isToday ? 1.5 : 1),
// //         ),
// //         child: Column(
// //           mainAxisAlignment: MainAxisAlignment.start,
// //           children: [
// //             const SizedBox(height: 6),
// //             // Day number
// //             Container(
// //               width: 24,
// //               height: 24,
// //               decoration: isToday
// //                   ? BoxDecoration(color: Colors.indigo, shape: BoxShape.circle)
// //                   : null,
// //               child: Center(
// //                 child: Text(
// //                   '${day.day}',
// //                   style: TextStyle(
// //                     fontSize: 12,
// //                     fontWeight: FontWeight.w700,
// //                     color: isToday ? Colors.white : textColor,
// //                   ),
// //                 ),
// //               ),
// //             ),
// //             const SizedBox(height: 4),
// //             if (isPresent && !isFuture) ...[
// //               // Hours
// //               Text(
// //                 _fmtMinutes(totalMin),
// //                 style: const TextStyle(
// //                   fontSize: 9,
// //                   fontWeight: FontWeight.w700,
// //                   color: Color(0xFF2E7D32),
// //                 ),
// //                 textAlign: TextAlign.center,
// //               ),
// //               // Late badge
// //               if (isLate && lateText != null) ...[
// //                 const SizedBox(height: 2),
// //                 Container(
// //                   padding: const EdgeInsets.symmetric(
// //                     horizontal: 3,
// //                     vertical: 1,
// //                   ),
// //                   decoration: BoxDecoration(
// //                     color: Colors.orange.shade100,
// //                     borderRadius: BorderRadius.circular(4),
// //                   ),
// //                   child: Text(
// //                     'Late',
// //                     style: TextStyle(
// //                       fontSize: 8,
// //                       fontWeight: FontWeight.w700,
// //                       color: Colors.orange.shade800,
// //                     ),
// //                   ),
// //                 ),
// //               ],
// //             ] else if (!isPresent &&
// //                 !isFuture &&
// //                 day.weekday != DateTime.sunday) ...[
// //               Text(
// //                 'Absent',
// //                 style: TextStyle(
// //                   fontSize: 8,
// //                   color: Colors.red.shade300,
// //                   fontWeight: FontWeight.w600,
// //                 ),
// //                 textAlign: TextAlign.center,
// //               ),
// //             ],
// //           ],
// //         ),
// //       ),
// //     );
// //   }

// //   Widget _buildLegend() => Container(
// //     color: Colors.white,
// //     padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
// //     child: Row(
// //       mainAxisAlignment: MainAxisAlignment.center,
// //       children: [
// //         _legendItem(
// //           const Color(0xFFE8F5E9),
// //           const Color(0xFFA5D6A7),
// //           'Present',
// //         ),
// //         const SizedBox(width: 16),
// //         _legendItem(const Color(0xFFFFF3F3), const Color(0xFFFFCDD2), 'Absent'),
// //         const SizedBox(width: 16),
// //         _legendItem(const Color(0xFFEEF2FF), Colors.indigo, 'Today'),
// //         const SizedBox(width: 16),
// //         Row(
// //           children: [
// //             Container(
// //               width: 12,
// //               height: 12,
// //               decoration: BoxDecoration(
// //                 color: Colors.orange.shade100,
// //                 borderRadius: BorderRadius.circular(3),
// //               ),
// //             ),
// //             const SizedBox(width: 4),
// //             Text(
// //               'Late',
// //               style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
// //             ),
// //           ],
// //         ),
// //       ],
// //     ),
// //   );

// //   Widget _legendItem(Color bg, Color border, String label) => Row(
// //     children: [
// //       Container(
// //         width: 12,
// //         height: 12,
// //         decoration: BoxDecoration(
// //           color: bg,
// //           border: Border.all(color: border),
// //           borderRadius: BorderRadius.circular(3),
// //         ),
// //       ),
// //       const SizedBox(width: 4),
// //       Text(label, style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
// //     ],
// //   );

// //   // ── Dialogs ────────────────────────────────────────────────────────────────

// //   Widget _buildAbsentDialog(DateTime day) => AlertDialog(
// //     shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
// //     titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
// //     contentPadding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
// //     title: Row(
// //       children: [
// //         Container(
// //           padding: const EdgeInsets.all(8),
// //           decoration: BoxDecoration(
// //             color: Colors.red.shade50,
// //             shape: BoxShape.circle,
// //           ),
// //           child: Icon(
// //             Icons.event_busy_rounded,
// //             color: Colors.red.shade400,
// //             size: 18,
// //           ),
// //         ),
// //         const SizedBox(width: 10),
// //         Column(
// //           crossAxisAlignment: CrossAxisAlignment.start,
// //           children: [
// //             const Text(
// //               'No Attendance',
// //               style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
// //             ),
// //             Text(
// //               _fullDate(day),
// //               style: TextStyle(
// //                 fontSize: 11,
// //                 color: Colors.grey.shade500,
// //                 fontWeight: FontWeight.w400,
// //               ),
// //             ),
// //           ],
// //         ),
// //       ],
// //     ),
// //     content: Text(
// //       day.weekday == DateTime.sunday
// //           ? 'Sunday — weekly off.'
// //           : 'No attendance recorded for this day.',
// //       style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
// //     ),
// //     actions: [
// //       TextButton(
// //         onPressed: () => Navigator.pop(context),
// //         child: const Text('Close'),
// //       ),
// //     ],
// //   );

// //   Future<void> _openSiteInMaps(int? siteId, String siteName) async {
// //     double? lat, lng;

// //     // Try to get precise coordinates from backend
// //     if (siteId != null) {
// //       try {
// //         final res = await http.get(
// //           Uri.parse('$baseUrl/sites/$siteId/location'),
// //         );
// //         if (res.statusCode == 200) {
// //           final body = jsonDecode(res.body);
// //           if (body['success'] == true) {
// //             lat = (body['lat'] as num?)?.toDouble();
// //             lng = (body['lng'] as num?)?.toDouble();
// //           }
// //         }
// //       } catch (_) {}
// //     }

// //     final Uri uri;
// //     if (lat != null && lng != null) {
// //       // Precise pin with label
// //       uri = Uri.parse(
// //         'https://www.google.com/maps/search/?api=1&query=$lat,$lng&query_place_id=${Uri.encodeComponent(siteName)}',
// //       );
// //     } else {
// //       // Fallback: search by name
// //       uri = Uri.parse(
// //         'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(siteName)}',
// //       );
// //     }

// //     if (await canLaunchUrl(uri)) {
// //       await launchUrl(uri, mode: LaunchMode.externalApplication);
// //     } else if (mounted) {
// //       ScaffoldMessenger.of(
// //         context,
// //       ).showSnackBar(const SnackBar(content: Text('Could not open maps')));
// //     }
// //   }

// //   Widget _buildDetailDialog(
// //     DateTime day,
// //     Map<String, dynamic>? detail,
// //     bool isLate,
// //     String? lateText,
// //   ) {
// //     final sessions = (detail?['sessions'] as List?) ?? [];
// //     final totalMin = sessions.fold<int>(
// //       0,
// //       (s, e) => s + ((e['site_minutes'] as num?)?.toInt() ?? 0),
// //     );

// //     return Dialog(
// //       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
// //       insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 40),
// //       child: Column(
// //         mainAxisSize: MainAxisSize.min,
// //         children: [
// //           // ── Header ────────────────────────────────────────────────────────────
// //           Container(
// //             padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
// //             decoration: const BoxDecoration(
// //               gradient: LinearGradient(
// //                 colors: [Color(0xFF3949AB), Color(0xFF1E88E5)],
// //                 begin: Alignment.topLeft,
// //                 end: Alignment.bottomRight,
// //               ),
// //               borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
// //             ),
// //             child: Row(
// //               children: [
// //                 Container(
// //                   padding: const EdgeInsets.all(8),
// //                   decoration: BoxDecoration(
// //                     color: Colors.white.withOpacity(0.2),
// //                     borderRadius: BorderRadius.circular(10),
// //                   ),
// //                   child: const Icon(
// //                     Icons.calendar_today_rounded,
// //                     color: Colors.white,
// //                     size: 18,
// //                   ),
// //                 ),
// //                 const SizedBox(width: 12),
// //                 Expanded(
// //                   child: Column(
// //                     crossAxisAlignment: CrossAxisAlignment.start,
// //                     children: [
// //                       Text(
// //                         _fullDate(day),
// //                         style: const TextStyle(
// //                           fontSize: 15,
// //                           fontWeight: FontWeight.w700,
// //                           color: Colors.white,
// //                         ),
// //                       ),

// //                       const SizedBox(height: 4),

// //                       // ✅ LATE BADGE (NEW)
// //                       if (isLate && lateText != null)
// //                         Container(
// //                           margin: const EdgeInsets.only(bottom: 4),
// //                           padding: const EdgeInsets.symmetric(
// //                             horizontal: 8,
// //                             vertical: 3,
// //                           ),
// //                           decoration: BoxDecoration(
// //                             color: Colors.orange.shade200,
// //                             borderRadius: BorderRadius.circular(6),
// //                           ),
// //                           child: Text(
// //                             'Late by $lateText',
// //                             style: const TextStyle(
// //                               fontSize: 11,
// //                               fontWeight: FontWeight.w700,
// //                               color: Colors.black87,
// //                             ),
// //                           ),
// //                         ),

// //                       Text(
// //                         'Total: ${_fmtMinutes(totalMin)}  ·  ${sessions.length} session(s)',
// //                         style: TextStyle(
// //                           fontSize: 11,
// //                           color: Colors.white.withOpacity(0.8),
// //                         ),
// //                       ),
// //                     ],
// //                   ),
// //                 ),
// //                 IconButton(
// //                   onPressed: () => Navigator.pop(context),
// //                   icon: const Icon(
// //                     Icons.close_rounded,
// //                     color: Colors.white,
// //                     size: 20,
// //                   ),
// //                   padding: EdgeInsets.zero,
// //                   constraints: const BoxConstraints(),
// //                 ),
// //               ],
// //             ),
// //           ),

// //           // ── Sessions list ─────────────────────────────────────────────────────
// //           ConstrainedBox(
// //             constraints: const BoxConstraints(maxHeight: 420),
// //             child: sessions.isEmpty
// //                 ? const Padding(
// //                     padding: EdgeInsets.all(32),
// //                     child: Text(
// //                       'No session data available.',
// //                       textAlign: TextAlign.center,
// //                     ),
// //                   )
// //                 : ListView.separated(
// //                     shrinkWrap: true,
// //                     padding: const EdgeInsets.all(16),
// //                     itemCount: sessions.length,
// //                     separatorBuilder: (_, __) => const SizedBox(height: 10),
// //                     itemBuilder: (_, si) {
// //                       final sess = sessions[si];
// //                       final visits = (sess['visits'] as List?) ?? [];
// //                       final sessMin =
// //                           (sess['site_minutes'] as num?)?.toInt() ?? 0;
// //                       final sessNum = sess['session_number'] ?? (si + 1);

// //                       return Container(
// //                         decoration: BoxDecoration(
// //                           color: const Color(0xFFF8FAFF),
// //                           borderRadius: BorderRadius.circular(12),
// //                           border: Border.all(color: const Color(0xFFE2E8F0)),
// //                         ),
// //                         child: Column(
// //                           crossAxisAlignment: CrossAxisAlignment.start,
// //                           children: [
// //                             // Session header
// //                             Container(
// //                               padding: const EdgeInsets.symmetric(
// //                                 horizontal: 14,
// //                                 vertical: 10,
// //                               ),
// //                               decoration: BoxDecoration(
// //                                 color: Colors.indigo.shade50,
// //                                 borderRadius: const BorderRadius.vertical(
// //                                   top: Radius.circular(12),
// //                                 ),
// //                               ),
// //                               child: Row(
// //                                 children: [
// //                                   Container(
// //                                     padding: const EdgeInsets.symmetric(
// //                                       horizontal: 8,
// //                                       vertical: 3,
// //                                     ),
// //                                     decoration: BoxDecoration(
// //                                       color: Colors.indigo,
// //                                       borderRadius: BorderRadius.circular(6),
// //                                     ),
// //                                     child: Text(
// //                                       'Session $sessNum',
// //                                       style: const TextStyle(
// //                                         fontSize: 11,
// //                                         color: Colors.white,
// //                                         fontWeight: FontWeight.w700,
// //                                       ),
// //                                     ),
// //                                   ),
// //                                   const SizedBox(width: 8),
// //                                   Text(
// //                                     _fmtTime(sess['started_at']?.toString()),
// //                                     style: TextStyle(
// //                                       fontSize: 11,
// //                                       color: Colors.grey.shade600,
// //                                     ),
// //                                   ),
// //                                   const Text(' → '),
// //                                   Text(
// //                                     sess['ended_at'] != null
// //                                         ? _fmtTime(sess['ended_at'].toString())
// //                                         : 'Active',
// //                                     style: TextStyle(
// //                                       fontSize: 11,
// //                                       color: sess['ended_at'] != null
// //                                           ? Colors.grey.shade600
// //                                           : Colors.green,
// //                                       fontWeight: FontWeight.w600,
// //                                     ),
// //                                   ),
// //                                   const Spacer(),
// //                                   Text(
// //                                     _fmtMinutes(sessMin),
// //                                     style: const TextStyle(
// //                                       fontSize: 12,
// //                                       fontWeight: FontWeight.w700,
// //                                       color: Color(0xFF2E7D32),
// //                                     ),
// //                                   ),
// //                                 ],
// //                               ),
// //                             ),

// //                             // Visits
// //                             if (visits.isEmpty)
// //                               Padding(
// //                                 padding: const EdgeInsets.all(12),
// //                                 child: Text(
// //                                   'No site visits in this session.',
// //                                   style: TextStyle(
// //                                     fontSize: 12,
// //                                     color: Colors.grey.shade500,
// //                                   ),
// //                                 ),
// //                               )
// //                             else
// //                               ...visits.asMap().entries.map((e) {
// //                                 final vi = e.key;
// //                                 final v = e.value;
// //                                 final isLast = vi == visits.length - 1;
// //                                 final vMin =
// //                                     (v['worked_minutes'] as num?)?.toInt() ?? 0;
// //                                 final isOpen = v['out_time'] == null;
// //                                 final siteName =
// //                                     v['site_name'] as String? ?? 'Unknown Site';
// //                                 final siteId = v['site_id'] as int?;

// //                                 return InkWell(
// //                                   onTap: () =>
// //                                       _openSiteInMaps(siteId, siteName),
// //                                   borderRadius: isLast
// //                                       ? const BorderRadius.vertical(
// //                                           bottom: Radius.circular(12),
// //                                         )
// //                                       : BorderRadius.zero,
// //                                   child: Container(
// //                                     padding: const EdgeInsets.fromLTRB(
// //                                       14,
// //                                       10,
// //                                       14,
// //                                       10,
// //                                     ),
// //                                     decoration: BoxDecoration(
// //                                       border: Border(
// //                                         top: const BorderSide(
// //                                           color: Color(0xFFE2E8F0),
// //                                         ),
// //                                         bottom: isLast
// //                                             ? BorderSide.none
// //                                             : const BorderSide(
// //                                                 color: Color(0xFFE2E8F0),
// //                                               ),
// //                                       ),
// //                                     ),
// //                                     child: Row(
// //                                       children: [
// //                                         // Status dot
// //                                         Container(
// //                                           width: 8,
// //                                           height: 8,
// //                                           decoration: BoxDecoration(
// //                                             color: isOpen
// //                                                 ? Colors.green
// //                                                 : Colors.grey.shade400,
// //                                             shape: BoxShape.circle,
// //                                           ),
// //                                         ),
// //                                         const SizedBox(width: 10),

// //                                         // Site name + times
// //                                         Expanded(
// //                                           child: Column(
// //                                             crossAxisAlignment:
// //                                                 CrossAxisAlignment.start,
// //                                             children: [
// //                                               Row(
// //                                                 children: [
// //                                                   Expanded(
// //                                                     child: Text(
// //                                                       siteName,
// //                                                       style: const TextStyle(
// //                                                         fontSize: 12,
// //                                                         fontWeight:
// //                                                             FontWeight.w600,
// //                                                         color: Color(
// //                                                           0xFF1A1A2E,
// //                                                         ),
// //                                                       ),
// //                                                     ),
// //                                                   ),
// //                                                   // Map icon hint
// //                                                   Icon(
// //                                                     Icons.open_in_new_rounded,
// //                                                     size: 12,
// //                                                     color:
// //                                                         Colors.indigo.shade300,
// //                                                   ),
// //                                                 ],
// //                                               ),
// //                                               const SizedBox(height: 3),
// //                                               Row(
// //                                                 children: [
// //                                                   Icon(
// //                                                     Icons.login_rounded,
// //                                                     size: 10,
// //                                                     color:
// //                                                         Colors.green.shade600,
// //                                                   ),
// //                                                   const SizedBox(width: 3),
// //                                                   Text(
// //                                                     _fmtTime(
// //                                                       v['in_time']?.toString(),
// //                                                     ),
// //                                                     style: TextStyle(
// //                                                       fontSize: 10,
// //                                                       color:
// //                                                           Colors.grey.shade600,
// //                                                     ),
// //                                                   ),
// //                                                   const SizedBox(width: 8),
// //                                                   Icon(
// //                                                     Icons.logout_rounded,
// //                                                     size: 10,
// //                                                     color: isOpen
// //                                                         ? Colors.orange
// //                                                         : Colors.red.shade400,
// //                                                   ),
// //                                                   const SizedBox(width: 3),
// //                                                   Text(
// //                                                     isOpen
// //                                                         ? 'Active'
// //                                                         : _fmtTime(
// //                                                             v['out_time']
// //                                                                 ?.toString(),
// //                                                           ),
// //                                                     style: TextStyle(
// //                                                       fontSize: 10,
// //                                                       color: isOpen
// //                                                           ? Colors.orange
// //                                                           : Colors
// //                                                                 .grey
// //                                                                 .shade600,
// //                                                     ),
// //                                                   ),
// //                                                   const SizedBox(width: 6),
// //                                                   Text(
// //                                                     'Tap to view map',
// //                                                     style: TextStyle(
// //                                                       fontSize: 9,
// //                                                       color: Colors
// //                                                           .indigo
// //                                                           .shade200,
// //                                                       fontStyle:
// //                                                           FontStyle.italic,
// //                                                     ),
// //                                                   ),
// //                                                 ],
// //                                               ),
// //                                             ],
// //                                           ),
// //                                         ),

// //                                         // Duration badge
// //                                         Container(
// //                                           padding: const EdgeInsets.symmetric(
// //                                             horizontal: 8,
// //                                             vertical: 3,
// //                                           ),
// //                                           decoration: BoxDecoration(
// //                                             color: isOpen
// //                                                 ? Colors.green.shade50
// //                                                 : Colors.grey.shade100,
// //                                             borderRadius: BorderRadius.circular(
// //                                               6,
// //                                             ),
// //                                           ),
// //                                           child: Text(
// //                                             _fmtMinutes(vMin),
// //                                             style: TextStyle(
// //                                               fontSize: 10,
// //                                               fontWeight: FontWeight.w700,
// //                                               color: isOpen
// //                                                   ? Colors.green.shade700
// //                                                   : Colors.grey.shade600,
// //                                             ),
// //                                           ),
// //                                         ),
// //                                       ],
// //                                     ),
// //                                   ),
// //                                 );
// //                               }),
// //                           ],
// //                         ),
// //                       );
// //                     },
// //                   ),
// //           ),

// //           // ── Footer ────────────────────────────────────────────────────────────
// //           Padding(
// //             padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
// //             child: SizedBox(
// //               width: double.infinity,
// //               child: TextButton(
// //                 onPressed: () => Navigator.pop(context),
// //                 style: TextButton.styleFrom(
// //                   backgroundColor: const Color(0xFFEEF2FF),
// //                   shape: RoundedRectangleBorder(
// //                     borderRadius: BorderRadius.circular(10),
// //                   ),
// //                   padding: const EdgeInsets.symmetric(vertical: 12),
// //                 ),
// //                 child: const Text(
// //                   'Close',
// //                   style: TextStyle(
// //                     color: Colors.indigo,
// //                     fontWeight: FontWeight.w600,
// //                   ),
// //                 ),
// //               ),
// //             ),
// //           ),
// //         ],
// //       ),
// //     );
// //   }

// //   String _fullDate(DateTime d) {
// //     const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
// //     const months = [
// //       'Jan',
// //       'Feb',
// //       'Mar',
// //       'Apr',
// //       'May',
// //       'Jun',
// //       'Jul',
// //       'Aug',
// //       'Sep',
// //       'Oct',
// //       'Nov',
// //       'Dec',
// //     ];
// //     return '${days[d.weekday - 1]}, ${d.day} ${months[d.month - 1]} ${d.year}';
// //   }
// // }
// import 'package:url_launcher/url_launcher.dart';
// import 'dart:convert';
// import 'package:flutter/material.dart';
// import 'package:http/http.dart' as http;

// import '../providers/api_client.dart';

// class AttendanceHistoryScreen extends StatefulWidget {
//   final int employeeId;
//   const AttendanceHistoryScreen({super.key, required this.employeeId});

//   @override
//   State<AttendanceHistoryScreen> createState() =>
//       _AttendanceHistoryScreenState();
// }

// class _AttendanceHistoryScreenState extends State<AttendanceHistoryScreen>
//     with SingleTickerProviderStateMixin {
//   DateTime _focusedMonth = DateTime(DateTime.now().year, DateTime.now().month);
//   Map<String, Map<String, dynamic>> _dayData = {};
//   bool _loading = true;

//   // Summary stats
//   int _presentDays = 0;
//   int _absentDays = 0;
//   int _lateDays = 0;
//   int _totalMinutes = 0;

//   late AnimationController _pulseController;
//   late Animation<double> _pulseAnim;

//   @override
//   void initState() {
//     super.initState();
//     _pulseController = AnimationController(
//       vsync: this,
//       duration: const Duration(seconds: 2),
//     )..repeat(reverse: true);
//     _pulseAnim = Tween<double>(begin: 0.85, end: 1.0).animate(
//       CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
//     );
//     _loadMonth(_focusedMonth);
//   }

//   @override
//   void dispose() {
//     _pulseController.dispose();
//     super.dispose();
//   }

//   // ── Load month ─────────────────────────────────────────────────────────────

//   Future<void> _loadMonth(DateTime month) async {
//     setState(() => _loading = true);
//     try {
//       final now = DateTime.now();
//       final daysInMonth = DateUtils.getDaysInMonth(month.year, month.month);
//       final futures = <Future>[];
//       final results = <String, Map<String, dynamic>>{};

//       for (int d = 1; d <= daysInMonth; d++) {
//         final day = DateTime(month.year, month.month, d);
//         if (day.isAfter(now)) continue;
//         final dateStr = _fmtDate(day);
//         futures.add(
//           _fetchDay(dateStr).then((data) {
//             if (data != null) results[dateStr] = data;
//           }),
//         );
//       }
//       await Future.wait(futures);

//       // Compute stats
//       int present = 0, absent = 0, late = 0, totalMin = 0;
//       for (int d = 1; d <= daysInMonth; d++) {
//         final day = DateTime(month.year, month.month, d);
//         if (day.isAfter(now)) continue;
//         if (day.weekday == DateTime.sunday) continue;
//         final dateStr = _fmtDate(day);
//         if (results.containsKey(dateStr)) {
//           present++;
//           totalMin += (results[dateStr]!['total_minutes'] as int? ?? 0);
//           if (results[dateStr]!['is_late'] == true) late++;
//         } else {
//           absent++;
//         }
//       }

//       if (mounted) {
//         setState(() {
//           _dayData = results;
//           _presentDays = present;
//           _absentDays = absent;
//           _lateDays = late;
//           _totalMinutes = totalMin;
//           _loading = false;
//         });
//       }
//     } catch (_) {
//       if (mounted) setState(() => _loading = false);
//     }
//   }

//   Future<Map<String, dynamic>?> _fetchDay(String date) async {
//     try {
//       final res = await ApiClient.get('/attendance/by-date-detail?date=$date');
//       if (res.statusCode != 200) return null;
//       final body = jsonDecode(res.body);
//       if (body['success'] != true) return null;
//       final List data = body['data'] ?? [];
//       final emp = data.firstWhere(
//         (e) => e['emp_id'] == widget.employeeId,
//         orElse: () => null,
//       );
//       if (emp == null || emp['attendance_status'] == 'ABSENT') return null;

//       int totalMinutes = 0;
//       bool isLate = false;
//       String? lateText;
//       final sessions = emp['sessions'] as List? ?? [];
//       for (int i = 0; i < sessions.length; i++) {
//         final s = sessions[i];
//         totalMinutes += (s['site_minutes'] as num? ?? 0).toInt();
//         if (i == 0 && s['is_late'] == true) {
//           isLate = true;
//           final lateMin = (s['late_minutes'] as num?)?.toInt() ?? 0;
//           if (lateMin > 0) {
//             final h = lateMin ~/ 60;
//             final m = lateMin % 60;
//             lateText = h > 0
//                 ? '${h}h ${m.toString().padLeft(2, '0')}m'
//                 : '${m}m';
//           }
//         }
//       }
//       return {
//         'total_minutes': totalMinutes,
//         'sessions': sessions,
//         'is_late': isLate,
//         'late_text': lateText,
//       };
//     } catch (_) {
//       return null;
//     }
//   }

//   Future<Map<String, dynamic>?> _fetchDayDetail(String date) async {
//     try {
//       final res = await ApiClient.get('/attendance/by-date-detail?date=$date');
//       if (res.statusCode != 200) return null;
//       final body = jsonDecode(res.body);
//       if (body['success'] != true) return null;
//       final List data = body['data'] ?? [];
//       final emp = data.firstWhere(
//         (e) => e['emp_id'] == widget.employeeId,
//         orElse: () => null,
//       );
//       return emp as Map<String, dynamic>?;
//     } catch (_) {
//       return null;
//     }
//   }

//   // ── Helpers ────────────────────────────────────────────────────────────────

//   String _fmtDate(DateTime d) =>
//       '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

//   String _fmtTime(String? t) {
//     if (t == null) return '--';
//     try {
//       if (t.contains(' ')) return t.split(' ')[1].substring(0, 5);
//       if (t.length >= 5) return t.substring(0, 5);
//       return t;
//     } catch (_) {
//       return '--';
//     }
//   }

//   String _fmtMinutes(int m) {
//     if (m == 0) return '0m';
//     final h = m ~/ 60;
//     final min = m % 60;
//     return h > 0 ? '${h}h ${min.toString().padLeft(2, '0')}m' : '${min}m';
//   }

//   String _monthLabel(DateTime d) {
//     const months = [
//       'January',
//       'February',
//       'March',
//       'April',
//       'May',
//       'June',
//       'July',
//       'August',
//       'September',
//       'October',
//       'November',
//       'December',
//     ];
//     return '${months[d.month - 1]} ${d.year}';
//   }

//   String _fullDate(DateTime d) {
//     const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
//     const months = [
//       'Jan',
//       'Feb',
//       'Mar',
//       'Apr',
//       'May',
//       'Jun',
//       'Jul',
//       'Aug',
//       'Sep',
//       'Oct',
//       'Nov',
//       'Dec',
//     ];
//     return '${days[d.weekday - 1]}, ${d.day} ${months[d.month - 1]} ${d.year}';
//   }

//   bool _isToday(DateTime d) {
//     final now = DateTime.now();
//     return d.year == now.year && d.month == now.month && d.day == now.day;
//   }

//   bool _isFuture(DateTime d) => d.isAfter(DateTime.now());

//   double get _attendanceRate {
//     final total = _presentDays + _absentDays;
//     if (total == 0) return 0;
//     return _presentDays / total;
//   }

//   // ── Day tap ────────────────────────────────────────────────────────────────

//   void _onDayTap(DateTime day) async {
//     final dateStr = _fmtDate(day);
//     final data = _dayData[dateStr];

//     if (data == null) {
//       if (!_isFuture(day)) {
//         showDialog(context: context, builder: (_) => _buildAbsentDialog(day));
//       }
//       return;
//     }

//     final isLate = data['is_late'] == true;
//     final lateText = data['late_text'];

//     showDialog(
//       context: context,
//       barrierDismissible: false,
//       builder: (_) =>
//           const Center(child: CircularProgressIndicator(color: Colors.indigo)),
//     );

//     final detail = await _fetchDayDetail(dateStr);
//     if (!mounted) return;
//     Navigator.pop(context);

//     showDialog(
//       context: context,
//       builder: (_) => _buildDetailDialog(day, detail, isLate, lateText),
//     );
//   }

//   // ── MAPS ───────────────────────────────────────────────────────────────────

//   Future<void> _openSiteInMaps(int? siteId, String siteName) async {
//     double? lat, lng;
//     if (siteId != null) {
//       try {
//         final res = await ApiClient.get('/sites/$siteId/location');
//         if (res.statusCode == 200) {
//           final body = jsonDecode(res.body);
//           if (body['success'] == true) {
//             lat = (body['lat'] as num?)?.toDouble();
//             lng = (body['lng'] as num?)?.toDouble();
//           }
//         }
//       } catch (_) {}
//     }

//     final Uri uri;
//     if (lat != null && lng != null) {
//       uri = Uri.parse(
//         'https://www.google.com/maps/search/?api=1&query=$lat,$lng&query_place_id=${Uri.encodeComponent(siteName)}',
//       );
//     } else {
//       uri = Uri.parse(
//         'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(siteName)}',
//       );
//     }

//     if (await canLaunchUrl(uri)) {
//       await launchUrl(uri, mode: LaunchMode.externalApplication);
//     } else if (mounted) {
//       ScaffoldMessenger.of(
//         context,
//       ).showSnackBar(const SnackBar(content: Text('Could not open maps')));
//     }
//   }

//   // ── BUILD ──────────────────────────────────────────────────────────────────

//   @override
//   Widget build(BuildContext context) {
//     final mq = MediaQuery.of(context);
//     final isSmall = mq.size.width < 360;
//     final hPad = isSmall ? 12.0 : 16.0;
//     final safeBot = mq.padding.bottom;

//     return Scaffold(
//       backgroundColor: const Color(0xFFF5F6FA),
//       body: SafeArea(
//         bottom: false,
//         child: Padding(
//           padding: EdgeInsets.fromLTRB(hPad, hPad, hPad, 0),
//           child: Column(
//             children: [
//               _buildHeader(isSmall: isSmall),
//               const SizedBox(height: 14),
//               if (_loading)
//                 Expanded(
//                   child: Center(
//                     child: CircularProgressIndicator(color: Colors.indigo),
//                   ),
//                 )
//               else ...[
//                 _buildSummaryCard(isSmall: isSmall),
//                 const SizedBox(height: 14),
//                 _buildMonthNav(isSmall: isSmall),
//                 const SizedBox(height: 10),
//                 _buildWeekdayHeader(),
//                 const SizedBox(height: 6),
//                 Expanded(child: _buildCalendar()),
//                 Padding(
//                   padding: EdgeInsets.only(top: 10, bottom: safeBot + 12),
//                   child: _buildLegend(),
//                 ),
//               ],
//             ],
//           ),
//         ),
//       ),
//     );
//   }

//   // ── Header ─────────────────────────────────────────────────────────────────

//   Widget _buildHeader({required bool isSmall}) {
//     return Row(
//       children: [
//         GestureDetector(
//           onTap: () => Navigator.pop(context),
//           child: Container(
//             width: 38,
//             height: 38,
//             decoration: BoxDecoration(
//               color: Colors.white,
//               borderRadius: BorderRadius.circular(12),
//               border: Border.all(color: const Color(0xFFE2E8F0)),
//             ),
//             child: const Icon(
//               Icons.arrow_back_rounded,
//               color: Color(0xFF1A1A2E),
//               size: 20,
//             ),
//           ),
//         ),
//         const SizedBox(width: 12),
//         Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Text(
//               'Attendance History',
//               style: TextStyle(
//                 fontSize: isSmall ? 15 : 17,
//                 fontWeight: FontWeight.w700,
//                 color: const Color(0xFF1A1A2E),
//               ),
//             ),
//             Text(
//               _monthLabel(_focusedMonth),
//               style: TextStyle(
//                 fontSize: 11,
//                 color: Colors.grey.shade500,
//                 fontWeight: FontWeight.w500,
//               ),
//             ),
//           ],
//         ),
//         const Spacer(),
//         AnimatedBuilder(
//           animation: _pulseAnim,
//           builder: (_, __) => Transform.scale(
//             scale: _pulseAnim.value,
//             child: Container(
//               width: 10,
//               height: 10,
//               decoration: BoxDecoration(
//                 shape: BoxShape.circle,
//                 color: Colors.indigo.shade300,
//                 boxShadow: [
//                   BoxShadow(
//                     color: Colors.indigo.withOpacity(0.5),
//                     blurRadius: 6,
//                     spreadRadius: 1,
//                   ),
//                 ],
//               ),
//             ),
//           ),
//         ),
//       ],
//     );
//   }

//   // ── Summary card (mirrors StatusCard from AttendanceScreen) ───────────────

//   Widget _buildSummaryCard({required bool isSmall}) {
//     final rate = _attendanceRate;
//     final ratePercent = (rate * 100).round();

//     // Choose gradient based on attendance rate
//     final gradient = rate >= 0.9
//         ? const LinearGradient(
//             colors: [Color(0xFF2E7D32), Color(0xFF43A047)],
//             begin: Alignment.topLeft,
//             end: Alignment.bottomRight,
//           )
//         : rate >= 0.7
//         ? const LinearGradient(
//             colors: [Color(0xFF1565C0), Color(0xFF1E88E5)],
//             begin: Alignment.topLeft,
//             end: Alignment.bottomRight,
//           )
//         : const LinearGradient(
//             colors: [Color(0xFFE65100), Color(0xFFFF6D00)],
//             begin: Alignment.topLeft,
//             end: Alignment.bottomRight,
//           );

//     final shadowColor = rate >= 0.9
//         ? const Color(0xFF2E7D32)
//         : rate >= 0.7
//         ? const Color(0xFF1565C0)
//         : const Color(0xFFE65100);

//     return Container(
//       decoration: BoxDecoration(
//         gradient: gradient,
//         borderRadius: BorderRadius.circular(20),
//         boxShadow: [
//           BoxShadow(
//             color: shadowColor.withOpacity(0.35),
//             blurRadius: 20,
//             offset: const Offset(0, 6),
//           ),
//         ],
//       ),
//       padding: EdgeInsets.all(isSmall ? 14 : 20),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           // Top row
//           Row(
//             children: [
//               Container(
//                 width: isSmall ? 38 : 46,
//                 height: isSmall ? 38 : 46,
//                 decoration: BoxDecoration(
//                   color: Colors.white.withOpacity(0.18),
//                   borderRadius: BorderRadius.circular(14),
//                 ),
//                 child: Icon(
//                   Icons.bar_chart_rounded,
//                   color: Colors.white,
//                   size: isSmall ? 22 : 26,
//                 ),
//               ),
//               SizedBox(width: isSmall ? 10 : 14),
//               Expanded(
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     Text(
//                       'Monthly Overview',
//                       style: TextStyle(
//                         color: Colors.white,
//                         fontSize: isSmall ? 15 : 17,
//                         fontWeight: FontWeight.w700,
//                       ),
//                     ),
//                     const SizedBox(height: 2),
//                     Text(
//                       _monthLabel(_focusedMonth),
//                       style: TextStyle(
//                         color: Colors.white.withOpacity(0.82),
//                         fontSize: isSmall ? 11 : 12.5,
//                         fontWeight: FontWeight.w500,
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//               // Attendance rate circle
//               Container(
//                 width: 52,
//                 height: 52,
//                 decoration: BoxDecoration(
//                   shape: BoxShape.circle,
//                   color: Colors.white.withOpacity(0.18),
//                 ),
//                 child: Center(
//                   child: Column(
//                     mainAxisAlignment: MainAxisAlignment.center,
//                     children: [
//                       Text(
//                         '$ratePercent%',
//                         style: const TextStyle(
//                           color: Colors.white,
//                           fontSize: 15,
//                           fontWeight: FontWeight.w800,
//                         ),
//                       ),
//                       Text(
//                         'rate',
//                         style: TextStyle(
//                           color: Colors.white.withOpacity(0.7),
//                           fontSize: 9,
//                           fontWeight: FontWeight.w500,
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//               ),
//             ],
//           ),
//           const SizedBox(height: 16),
//           Container(height: 1, color: Colors.white.withOpacity(0.15)),
//           const SizedBox(height: 14),
//           // Stats row
//           Row(
//             children: [
//               _summaryStatItem(
//                 icon: Icons.check_circle_outline_rounded,
//                 label: 'Present',
//                 value: '$_presentDays',
//                 color: Colors.white,
//                 isSmall: isSmall,
//               ),
//               _verticalDivider(),
//               _summaryStatItem(
//                 icon: Icons.cancel_outlined,
//                 label: 'Absent',
//                 value: '$_absentDays',
//                 color: Colors.white,
//                 isSmall: isSmall,
//               ),
//               _verticalDivider(),
//               _summaryStatItem(
//                 icon: Icons.schedule_rounded,
//                 label: 'Late',
//                 value: '$_lateDays',
//                 color: Colors.white,
//                 isSmall: isSmall,
//               ),
//               _verticalDivider(),
//               _summaryStatItem(
//                 icon: Icons.timelapse_rounded,
//                 label: 'Total',
//                 value: _fmtMinutes(_totalMinutes),
//                 color: Colors.white,
//                 isSmall: isSmall,
//               ),
//             ],
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _summaryStatItem({
//     required IconData icon,
//     required String label,
//     required String value,
//     required Color color,
//     required bool isSmall,
//   }) {
//     return Expanded(
//       child: Column(
//         children: [
//           Icon(icon, size: isSmall ? 13 : 15, color: color.withOpacity(0.7)),
//           const SizedBox(height: 4),
//           Text(
//             value,
//             style: TextStyle(
//               color: color,
//               fontSize: isSmall ? 13 : 15,
//               fontWeight: FontWeight.w800,
//             ),
//           ),
//           const SizedBox(height: 2),
//           Text(
//             label,
//             style: TextStyle(
//               fontSize: 9.5,
//               color: color.withOpacity(0.65),
//               fontWeight: FontWeight.w500,
//               letterSpacing: 0.3,
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _verticalDivider() {
//     return Container(
//       width: 1,
//       height: 36,
//       color: Colors.white.withOpacity(0.2),
//     );
//   }

//   // ── Month nav ──────────────────────────────────────────────────────────────

//   Widget _buildMonthNav({required bool isSmall}) {
//     final now = DateTime.now();
//     final canGoNext = !DateTime(
//       _focusedMonth.year,
//       _focusedMonth.month + 1,
//     ).isAfter(DateTime(now.year, now.month));

//     return Container(
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(14),
//         border: Border.all(color: const Color(0xFFE2E8F0)),
//       ),
//       padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
//       child: Row(
//         children: [
//           _navButton(
//             icon: Icons.chevron_left_rounded,
//             onTap: () {
//               final prev = DateTime(
//                 _focusedMonth.year,
//                 _focusedMonth.month - 1,
//               );
//               setState(() {
//                 _focusedMonth = prev;
//                 _dayData = {};
//               });
//               _loadMonth(prev);
//             },
//             enabled: true,
//           ),
//           Expanded(
//             child: Text(
//               _monthLabel(_focusedMonth),
//               textAlign: TextAlign.center,
//               style: TextStyle(
//                 fontSize: isSmall ? 13 : 15,
//                 fontWeight: FontWeight.w700,
//                 color: const Color(0xFF1A1A2E),
//               ),
//             ),
//           ),
//           _navButton(
//             icon: Icons.chevron_right_rounded,
//             onTap: () {
//               if (!canGoNext) return;
//               final next = DateTime(
//                 _focusedMonth.year,
//                 _focusedMonth.month + 1,
//               );
//               setState(() {
//                 _focusedMonth = next;
//                 _dayData = {};
//               });
//               _loadMonth(next);
//             },
//             enabled: canGoNext,
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _navButton({
//     required IconData icon,
//     required VoidCallback onTap,
//     required bool enabled,
//   }) {
//     return GestureDetector(
//       onTap: enabled ? onTap : null,
//       child: Container(
//         width: 34,
//         height: 34,
//         decoration: BoxDecoration(
//           color: enabled ? Colors.indigo.shade50 : Colors.grey.shade50,
//           borderRadius: BorderRadius.circular(10),
//         ),
//         child: Icon(
//           icon,
//           color: enabled ? Colors.indigo : Colors.grey.shade300,
//           size: 20,
//         ),
//       ),
//     );
//   }

//   // ── Weekday header ─────────────────────────────────────────────────────────

//   Widget _buildWeekdayHeader() {
//     return Row(
//       children: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
//           .map(
//             (d) => Expanded(
//               child: Text(
//                 d,
//                 textAlign: TextAlign.center,
//                 style: TextStyle(
//                   fontSize: 10,
//                   fontWeight: FontWeight.w700,
//                   color: (d == 'Sun')
//                       ? Colors.red.shade300
//                       : Colors.grey.shade400,
//                   letterSpacing: 0.3,
//                 ),
//               ),
//             ),
//           )
//           .toList(),
//     );
//   }

//   // ── Calendar ───────────────────────────────────────────────────────────────

//   Widget _buildCalendar() {
//     final firstDay = DateTime(_focusedMonth.year, _focusedMonth.month, 1);
//     final startOffset = (firstDay.weekday - 1) % 7;
//     final daysInMonth = DateUtils.getDaysInMonth(
//       _focusedMonth.year,
//       _focusedMonth.month,
//     );
//     final totalCells = startOffset + daysInMonth;
//     final rows = (totalCells / 7).ceil();

//     return GridView.builder(
//       padding: const EdgeInsets.symmetric(vertical: 4),
//       gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
//         crossAxisCount: 7,
//         mainAxisSpacing: 5,
//         crossAxisSpacing: 4,
//         childAspectRatio: 0.72,
//       ),
//       itemCount: rows * 7,
//       itemBuilder: (_, index) {
//         final dayNum = index - startOffset + 1;
//         if (dayNum < 1 || dayNum > daysInMonth) return const SizedBox();
//         final day = DateTime(_focusedMonth.year, _focusedMonth.month, dayNum);
//         return _buildDayCell(day);
//       },
//     );
//   }

//   Widget _buildDayCell(DateTime day) {
//     final dateStr = _fmtDate(day);
//     final data = _dayData[dateStr];
//     final isToday = _isToday(day);
//     final isFuture = _isFuture(day);
//     final isSunday = day.weekday == DateTime.sunday;
//     final isPresent = data != null;
//     final totalMin = (data?['total_minutes'] as int?) ?? 0;
//     final isLate = data?['is_late'] == true;
//     final lateText = data?['late_text'] as String?;

//     Color bgColor = Colors.white;
//     Color textColor = const Color(0xFF1A1A2E);
//     Color borderColor = const Color(0xFFE2E8F0);
//     LinearGradient? cellGradient;

//     if (isFuture) {
//       bgColor = Colors.grey.shade50;
//       textColor = Colors.grey.shade300;
//       borderColor = Colors.transparent;
//     } else if (isToday) {
//       borderColor = Colors.indigo;
//       bgColor = const Color(0xFFEEF2FF);
//     } else if (isPresent) {
//       if (isLate) {
//         bgColor = const Color(0xFFFFF8E1);
//         borderColor = const Color(0xFFFFCC02);
//       } else {
//         bgColor = const Color(0xFFE8F5E9);
//         borderColor = const Color(0xFFA5D6A7);
//       }
//     } else if (!isFuture) {
//       bgColor = const Color(0xFFFFF3F3);
//       borderColor = const Color(0xFFFFCDD2);
//     }

//     if (isSunday && !isFuture) {
//       textColor = Colors.red.shade400;
//     }

//     return GestureDetector(
//       onTap: isFuture ? null : () => _onDayTap(day),
//       child: Container(
//         decoration: BoxDecoration(
//           color: isToday ? const Color(0xFFEEF2FF) : bgColor,
//           borderRadius: BorderRadius.circular(10),
//           border: Border.all(color: borderColor, width: isToday ? 1.5 : 1),
//           boxShadow: isPresent && !isFuture
//               ? [
//                   BoxShadow(
//                     color: (isLate ? Colors.orange : Colors.green).withOpacity(
//                       0.08,
//                     ),
//                     blurRadius: 4,
//                     offset: const Offset(0, 2),
//                   ),
//                 ]
//               : null,
//         ),
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.start,
//           children: [
//             const SizedBox(height: 6),
//             // Day number circle
//             Container(
//               width: 22,
//               height: 22,
//               decoration: isToday
//                   ? const BoxDecoration(
//                       color: Colors.indigo,
//                       shape: BoxShape.circle,
//                     )
//                   : null,
//               child: Center(
//                 child: Text(
//                   '${day.day}',
//                   style: TextStyle(
//                     fontSize: 11,
//                     fontWeight: FontWeight.w700,
//                     color: isToday ? Colors.white : textColor,
//                   ),
//                 ),
//               ),
//             ),
//             const SizedBox(height: 3),
//             if (isPresent && !isFuture) ...[
//               Text(
//                 _fmtMinutes(totalMin),
//                 style: TextStyle(
//                   fontSize: 8,
//                   fontWeight: FontWeight.w700,
//                   color: isLate
//                       ? Colors.orange.shade800
//                       : const Color(0xFF2E7D32),
//                 ),
//                 textAlign: TextAlign.center,
//               ),
//               if (isLate) ...[
//                 const SizedBox(height: 2),
//                 Container(
//                   padding: const EdgeInsets.symmetric(
//                     horizontal: 3,
//                     vertical: 1,
//                   ),
//                   decoration: BoxDecoration(
//                     color: Colors.orange.shade600,
//                     borderRadius: BorderRadius.circular(4),
//                   ),
//                   child: const Text(
//                     'Late',
//                     style: TextStyle(
//                       fontSize: 7,
//                       fontWeight: FontWeight.w700,
//                       color: Colors.white,
//                     ),
//                   ),
//                 ),
//               ] else ...[
//                 const SizedBox(height: 2),
//                 Container(
//                   width: 16,
//                   height: 3,
//                   decoration: BoxDecoration(
//                     color: Colors.green.shade400,
//                     borderRadius: BorderRadius.circular(2),
//                   ),
//                 ),
//               ],
//             ] else if (!isPresent && !isFuture && !isSunday) ...[
//               Text(
//                 'Abs',
//                 style: TextStyle(
//                   fontSize: 8,
//                   color: Colors.red.shade300,
//                   fontWeight: FontWeight.w600,
//                 ),
//                 textAlign: TextAlign.center,
//               ),
//             ],
//           ],
//         ),
//       ),
//     );
//   }

//   // ── Legend ─────────────────────────────────────────────────────────────────

//   Widget _buildLegend() {
//     return Container(
//       padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(14),
//         border: Border.all(color: const Color(0xFFE2E8F0)),
//       ),
//       child: Row(
//         mainAxisAlignment: MainAxisAlignment.spaceEvenly,
//         children: [
//           _legendItem(
//             const Color(0xFFE8F5E9),
//             const Color(0xFFA5D6A7),
//             Colors.green.shade700,
//             'Present',
//           ),
//           _legendItem(
//             const Color(0xFFFFF3F3),
//             const Color(0xFFFFCDD2),
//             Colors.red.shade400,
//             'Absent',
//           ),
//           _legendItem(
//             const Color(0xFFEEF2FF),
//             Colors.indigo,
//             Colors.indigo,
//             'Today',
//           ),
//           _legendItem(
//             const Color(0xFFFFF8E1),
//             const Color(0xFFFFCC02),
//             Colors.orange.shade800,
//             'Late',
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _legendItem(Color bg, Color border, Color textColor, String label) {
//     return Row(
//       mainAxisSize: MainAxisSize.min,
//       children: [
//         Container(
//           width: 11,
//           height: 11,
//           decoration: BoxDecoration(
//             color: bg,
//             border: Border.all(color: border, width: 1.2),
//             borderRadius: BorderRadius.circular(3),
//           ),
//         ),
//         const SizedBox(width: 5),
//         Text(
//           label,
//           style: TextStyle(
//             fontSize: 10,
//             color: Colors.grey.shade600,
//             fontWeight: FontWeight.w500,
//           ),
//         ),
//       ],
//     );
//   }

//   // ── Absent dialog ──────────────────────────────────────────────────────────

//   Widget _buildAbsentDialog(DateTime day) => Dialog(
//     shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
//     insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 80),
//     child: Padding(
//       padding: const EdgeInsets.all(24),
//       child: Column(
//         mainAxisSize: MainAxisSize.min,
//         children: [
//           Container(
//             width: 56,
//             height: 56,
//             decoration: BoxDecoration(
//               color: Colors.red.shade50,
//               shape: BoxShape.circle,
//             ),
//             child: Icon(
//               Icons.event_busy_rounded,
//               color: Colors.red.shade400,
//               size: 28,
//             ),
//           ),
//           const SizedBox(height: 16),
//           Text(
//             day.weekday == DateTime.sunday ? 'Weekly Off' : 'No Attendance',
//             style: const TextStyle(
//               fontSize: 16,
//               fontWeight: FontWeight.w700,
//               color: Color(0xFF1A1A2E),
//             ),
//           ),
//           const SizedBox(height: 6),
//           Text(
//             _fullDate(day),
//             style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
//           ),
//           const SizedBox(height: 12),
//           Text(
//             day.weekday == DateTime.sunday
//                 ? 'Sunday — weekly off.'
//                 : 'No attendance recorded for this day.',
//             textAlign: TextAlign.center,
//             style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
//           ),
//           const SizedBox(height: 20),
//           SizedBox(
//             width: double.infinity,
//             child: TextButton(
//               onPressed: () => Navigator.pop(context),
//               style: TextButton.styleFrom(
//                 backgroundColor: const Color(0xFFEEF2FF),
//                 shape: RoundedRectangleBorder(
//                   borderRadius: BorderRadius.circular(10),
//                 ),
//                 padding: const EdgeInsets.symmetric(vertical: 12),
//               ),
//               child: const Text(
//                 'Close',
//                 style: TextStyle(
//                   color: Colors.indigo,
//                   fontWeight: FontWeight.w600,
//                 ),
//               ),
//             ),
//           ),
//         ],
//       ),
//     ),
//   );

//   // ── Detail dialog ──────────────────────────────────────────────────────────

//   Widget _buildDetailDialog(
//     DateTime day,
//     Map<String, dynamic>? detail,
//     bool isLate,
//     String? lateText,
//   ) {
//     final sessions = (detail?['sessions'] as List?) ?? [];
//     final totalMin = sessions.fold<int>(
//       0,
//       (s, e) => s + ((e['site_minutes'] as num?)?.toInt() ?? 0),
//     );

//     return Dialog(
//       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
//       insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 40),
//       child: Column(
//         mainAxisSize: MainAxisSize.min,
//         children: [
//           // Header — same gradient style as AttendanceScreen status card
//           Container(
//             padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
//             decoration: BoxDecoration(
//               gradient: LinearGradient(
//                 colors: isLate
//                     ? [const Color(0xFFE65100), const Color(0xFFFF8F00)]
//                     : [const Color(0xFF2E7D32), const Color(0xFF43A047)],
//                 begin: Alignment.topLeft,
//                 end: Alignment.bottomRight,
//               ),
//               borderRadius: const BorderRadius.vertical(
//                 top: Radius.circular(20),
//               ),
//             ),
//             child: Row(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Container(
//                   padding: const EdgeInsets.all(8),
//                   decoration: BoxDecoration(
//                     color: Colors.white.withOpacity(0.2),
//                     borderRadius: BorderRadius.circular(10),
//                   ),
//                   child: Icon(
//                     isLate
//                         ? Icons.schedule_rounded
//                         : Icons.check_circle_rounded,
//                     color: Colors.white,
//                     size: 18,
//                   ),
//                 ),
//                 const SizedBox(width: 12),
//                 Expanded(
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       Text(
//                         _fullDate(day),
//                         style: const TextStyle(
//                           fontSize: 14,
//                           fontWeight: FontWeight.w700,
//                           color: Colors.white,
//                         ),
//                       ),
//                       const SizedBox(height: 5),
//                       if (isLate && lateText != null)
//                         Container(
//                           padding: const EdgeInsets.symmetric(
//                             horizontal: 8,
//                             vertical: 3,
//                           ),
//                           decoration: BoxDecoration(
//                             color: Colors.white.withOpacity(0.25),
//                             borderRadius: BorderRadius.circular(6),
//                           ),
//                           child: Text(
//                             'Late by $lateText',
//                             style: const TextStyle(
//                               fontSize: 11,
//                               fontWeight: FontWeight.w700,
//                               color: Colors.white,
//                             ),
//                           ),
//                         ),
//                       const SizedBox(height: 4),
//                       Text(
//                         'Total: ${_fmtMinutes(totalMin)}  ·  ${sessions.length} session(s)',
//                         style: TextStyle(
//                           fontSize: 11,
//                           color: Colors.white.withOpacity(0.8),
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//                 IconButton(
//                   onPressed: () => Navigator.pop(context),
//                   icon: const Icon(
//                     Icons.close_rounded,
//                     color: Colors.white,
//                     size: 20,
//                   ),
//                   padding: EdgeInsets.zero,
//                   constraints: const BoxConstraints(),
//                 ),
//               ],
//             ),
//           ),

//           // Sessions list
//           ConstrainedBox(
//             constraints: const BoxConstraints(maxHeight: 420),
//             child: sessions.isEmpty
//                 ? const Padding(
//                     padding: EdgeInsets.all(32),
//                     child: Text(
//                       'No session data available.',
//                       textAlign: TextAlign.center,
//                     ),
//                   )
//                 : ListView.separated(
//                     shrinkWrap: true,
//                     padding: const EdgeInsets.all(16),
//                     itemCount: sessions.length,
//                     separatorBuilder: (_, __) => const SizedBox(height: 10),
//                     itemBuilder: (_, si) {
//                       final sess = sessions[si];
//                       final visits = (sess['visits'] as List?) ?? [];
//                       final sessMin =
//                           (sess['site_minutes'] as num?)?.toInt() ?? 0;
//                       final sessNum = sess['session_number'] ?? (si + 1);

//                       return Container(
//                         decoration: BoxDecoration(
//                           color: const Color(0xFFF8FAFF),
//                           borderRadius: BorderRadius.circular(12),
//                           border: Border.all(color: const Color(0xFFE2E8F0)),
//                         ),
//                         child: Column(
//                           crossAxisAlignment: CrossAxisAlignment.start,
//                           children: [
//                             // Session header — indigo accent like AttendanceScreen log cards
//                             Container(
//                               padding: const EdgeInsets.symmetric(
//                                 horizontal: 14,
//                                 vertical: 10,
//                               ),
//                               decoration: BoxDecoration(
//                                 color: Colors.indigo.shade50,
//                                 borderRadius: const BorderRadius.vertical(
//                                   top: Radius.circular(12),
//                                 ),
//                               ),
//                               child: Row(
//                                 children: [
//                                   Container(
//                                     padding: const EdgeInsets.symmetric(
//                                       horizontal: 8,
//                                       vertical: 3,
//                                     ),
//                                     decoration: BoxDecoration(
//                                       color: Colors.indigo,
//                                       borderRadius: BorderRadius.circular(6),
//                                     ),
//                                     child: Text(
//                                       'S$sessNum',
//                                       style: const TextStyle(
//                                         fontSize: 11,
//                                         color: Colors.white,
//                                         fontWeight: FontWeight.w700,
//                                       ),
//                                     ),
//                                   ),
//                                   const SizedBox(width: 8),
//                                   _dialogTimeTag(
//                                     icon: Icons.login_rounded,
//                                     time: _fmtTime(
//                                       sess['started_at']?.toString(),
//                                     ),
//                                     color: Colors.green.shade700,
//                                   ),
//                                   const Padding(
//                                     padding: EdgeInsets.symmetric(
//                                       horizontal: 4,
//                                     ),
//                                     child: Text(
//                                       '→',
//                                       style: TextStyle(color: Colors.grey),
//                                     ),
//                                   ),
//                                   _dialogTimeTag(
//                                     icon: Icons.logout_rounded,
//                                     time: sess['ended_at'] != null
//                                         ? _fmtTime(sess['ended_at'].toString())
//                                         : 'Active',
//                                     color: sess['ended_at'] != null
//                                         ? Colors.red.shade400
//                                         : Colors.green,
//                                   ),
//                                   const Spacer(),
//                                   Container(
//                                     padding: const EdgeInsets.symmetric(
//                                       horizontal: 8,
//                                       vertical: 3,
//                                     ),
//                                     decoration: BoxDecoration(
//                                       color: Colors.green.shade50,
//                                       borderRadius: BorderRadius.circular(6),
//                                       border: Border.all(
//                                         color: Colors.green.shade200,
//                                       ),
//                                     ),
//                                     child: Text(
//                                       _fmtMinutes(sessMin),
//                                       style: TextStyle(
//                                         fontSize: 11,
//                                         fontWeight: FontWeight.w700,
//                                         color: Colors.green.shade700,
//                                       ),
//                                     ),
//                                   ),
//                                 ],
//                               ),
//                             ),

//                             // Visits
//                             if (visits.isEmpty)
//                               Padding(
//                                 padding: const EdgeInsets.all(12),
//                                 child: Text(
//                                   'No site visits in this session.',
//                                   style: TextStyle(
//                                     fontSize: 12,
//                                     color: Colors.grey.shade500,
//                                   ),
//                                 ),
//                               )
//                             else
//                               ...visits.asMap().entries.map((e) {
//                                 final vi = e.key;
//                                 final v = e.value;
//                                 final isLast = vi == visits.length - 1;
//                                 final vMin =
//                                     (v['worked_minutes'] as num?)?.toInt() ?? 0;
//                                 final isOpen = v['out_time'] == null;
//                                 final siteName =
//                                     v['site_name'] as String? ?? 'Unknown Site';
//                                 final siteId = v['site_id'] as int?;

//                                 return InkWell(
//                                   onTap: () =>
//                                       _openSiteInMaps(siteId, siteName),
//                                   borderRadius: isLast
//                                       ? const BorderRadius.vertical(
//                                           bottom: Radius.circular(12),
//                                         )
//                                       : BorderRadius.zero,
//                                   child: Container(
//                                     padding: const EdgeInsets.fromLTRB(
//                                       14,
//                                       10,
//                                       14,
//                                       10,
//                                     ),
//                                     decoration: BoxDecoration(
//                                       border: Border(
//                                         top: const BorderSide(
//                                           color: Color(0xFFE2E8F0),
//                                         ),
//                                       ),
//                                     ),
//                                     child: Row(
//                                       children: [
//                                         // Status dot
//                                         Container(
//                                           width: 8,
//                                           height: 8,
//                                           decoration: BoxDecoration(
//                                             color: isOpen
//                                                 ? Colors.green
//                                                 : Colors.grey.shade400,
//                                             shape: BoxShape.circle,
//                                           ),
//                                         ),
//                                         const SizedBox(width: 10),

//                                         // Site info
//                                         Expanded(
//                                           child: Column(
//                                             crossAxisAlignment:
//                                                 CrossAxisAlignment.start,
//                                             children: [
//                                               Row(
//                                                 children: [
//                                                   Expanded(
//                                                     child: Text(
//                                                       siteName,
//                                                       style: const TextStyle(
//                                                         fontSize: 12,
//                                                         fontWeight:
//                                                             FontWeight.w600,
//                                                         color: Color(
//                                                           0xFF1A1A2E,
//                                                         ),
//                                                       ),
//                                                     ),
//                                                   ),
//                                                   Icon(
//                                                     Icons.open_in_new_rounded,
//                                                     size: 12,
//                                                     color:
//                                                         Colors.indigo.shade300,
//                                                   ),
//                                                 ],
//                                               ),
//                                               const SizedBox(height: 4),
//                                               // Time tags — same as AttendanceScreen log list
//                                               Wrap(
//                                                 spacing: 5,
//                                                 children: [
//                                                   _visitTimeTag(
//                                                     icon: Icons.login_rounded,
//                                                     time: _fmtTime(
//                                                       v['in_time']?.toString(),
//                                                     ),
//                                                     color:
//                                                         Colors.green.shade700,
//                                                     bg: Colors.green.shade50,
//                                                   ),
//                                                   _visitTimeTag(
//                                                     icon: Icons.logout_rounded,
//                                                     time: isOpen
//                                                         ? 'Active'
//                                                         : _fmtTime(
//                                                             v['out_time']
//                                                                 ?.toString(),
//                                                           ),
//                                                     color: isOpen
//                                                         ? Colors.orange.shade700
//                                                         : Colors.red.shade400,
//                                                     bg: isOpen
//                                                         ? Colors.orange.shade50
//                                                         : Colors.red.shade50,
//                                                   ),
//                                                 ],
//                                               ),
//                                             ],
//                                           ),
//                                         ),

//                                         // Duration
//                                         Container(
//                                           padding: const EdgeInsets.symmetric(
//                                             horizontal: 8,
//                                             vertical: 4,
//                                           ),
//                                           decoration: BoxDecoration(
//                                             gradient: isOpen
//                                                 ? LinearGradient(
//                                                     colors: [
//                                                       Colors.green.shade400,
//                                                       Colors.green.shade600,
//                                                     ],
//                                                   )
//                                                 : LinearGradient(
//                                                     colors: [
//                                                       Colors.grey.shade300,
//                                                       Colors.grey.shade400,
//                                                     ],
//                                                   ),
//                                             borderRadius: BorderRadius.circular(
//                                               8,
//                                             ),
//                                           ),
//                                           child: Text(
//                                             _fmtMinutes(vMin),
//                                             style: TextStyle(
//                                               fontSize: 10,
//                                               fontWeight: FontWeight.w700,
//                                               color: isOpen
//                                                   ? Colors.white
//                                                   : Colors.grey.shade700,
//                                             ),
//                                           ),
//                                         ),
//                                       ],
//                                     ),
//                                   ),
//                                 );
//                               }),
//                           ],
//                         ),
//                       );
//                     },
//                   ),
//           ),

//           // Footer
//           Padding(
//             padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
//             child: SizedBox(
//               width: double.infinity,
//               child: TextButton(
//                 onPressed: () => Navigator.pop(context),
//                 style: TextButton.styleFrom(
//                   backgroundColor: const Color(0xFFEEF2FF),
//                   shape: RoundedRectangleBorder(
//                     borderRadius: BorderRadius.circular(10),
//                   ),
//                   padding: const EdgeInsets.symmetric(vertical: 12),
//                 ),
//                 child: const Text(
//                   'Close',
//                   style: TextStyle(
//                     color: Colors.indigo,
//                     fontWeight: FontWeight.w600,
//                   ),
//                 ),
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _dialogTimeTag({
//     required IconData icon,
//     required String time,
//     required Color color,
//   }) {
//     return Row(
//       mainAxisSize: MainAxisSize.min,
//       children: [
//         Icon(icon, size: 10, color: color),
//         const SizedBox(width: 3),
//         Text(
//           time,
//           style: TextStyle(
//             fontSize: 11,
//             color: Colors.grey.shade600,
//             fontWeight: FontWeight.w500,
//           ),
//         ),
//       ],
//     );
//   }

//   Widget _visitTimeTag({
//     required IconData icon,
//     required String time,
//     required Color color,
//     required Color bg,
//   }) {
//     return Container(
//       padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
//       decoration: BoxDecoration(
//         color: bg,
//         borderRadius: BorderRadius.circular(5),
//       ),
//       child: Row(
//         mainAxisSize: MainAxisSize.min,
//         children: [
//           Icon(icon, size: 10, color: color),
//           const SizedBox(width: 3),
//           Text(
//             time,
//             style: TextStyle(
//               fontSize: 10,
//               color: color,
//               fontWeight: FontWeight.w600,
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../providers/api_client.dart';

class AttendanceHistoryScreen extends StatefulWidget {
  final int employeeId;
  const AttendanceHistoryScreen({super.key, required this.employeeId});

  @override
  State<AttendanceHistoryScreen> createState() =>
      _AttendanceHistoryScreenState();
}

class _AttendanceHistoryScreenState extends State<AttendanceHistoryScreen>
    with SingleTickerProviderStateMixin {
  DateTime _focusedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  Map<String, Map<String, dynamic>> _dayData = {};
  bool _loading = true;

  int _presentDays = 0;
  int _absentDays = 0;
  int _lateDays = 0;
  int _totalMinutes = 0;

  // ── Pulse animation (same as AttendanceScreen) ────────────────────────────
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
    _loadMonth(_focusedMonth);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  // ── Load month ─────────────────────────────────────────────────────────────

  Future<void> _loadMonth(DateTime month) async {
    setState(() => _loading = true);
    try {
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

      int present = 0, absent = 0, late = 0, totalMin = 0;
      for (int d = 1; d <= daysInMonth; d++) {
        final day = DateTime(month.year, month.month, d);
        if (day.isAfter(now)) continue;
        if (day.weekday == DateTime.sunday) continue;
        final dateStr = _fmtDate(day);
        if (results.containsKey(dateStr)) {
          present++;
          totalMin += (results[dateStr]!['total_minutes'] as int? ?? 0);
          if (results[dateStr]!['is_late'] == true) late++;
        } else {
          absent++;
        }
      }

      if (mounted) {
        setState(() {
          _dayData = results;
          _presentDays = present;
          _absentDays = absent;
          _lateDays = late;
          _totalMinutes = totalMin;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<Map<String, dynamic>?> _fetchDay(String date) async {
    try {
      final res = await ApiClient.get('/attendance/by-date-detail?date=$date');
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
        if (i == 0 && s['is_late'] == true) {
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
      return {
        'total_minutes': totalMinutes,
        'sessions': sessions,
        'is_late': isLate,
        'late_text': lateText,
      };
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> _fetchDayDetail(String date) async {
    try {
      final res = await ApiClient.get('/attendance/by-date-detail?date=$date');
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

  // ── Helpers ────────────────────────────────────────────────────────────────

  String _fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _fmtTime(String? t) {
    if (t == null) return '--';
    try {
      if (t.contains(' ')) return t.split(' ')[1].substring(0, 5);
      if (t.length >= 5) return t.substring(0, 5);
      return t;
    } catch (_) {
      return '--';
    }
  }

  String _fmtMinutes(int m) {
    if (m == 0) return '--';
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

  bool _isToday(DateTime d) {
    final now = DateTime.now();
    return d.year == now.year && d.month == now.month && d.day == now.day;
  }

  bool _isFuture(DateTime d) => d.isAfter(DateTime.now());

  double get _attendanceRate {
    final total = _presentDays + _absentDays;
    if (total == 0) return 0;
    return _presentDays / total;
  }

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
      builder: (_) =>
          const Center(child: CircularProgressIndicator(color: Colors.indigo)),
    );

    final detail = await _fetchDayDetail(dateStr);
    if (!mounted) return;
    Navigator.pop(context);

    showDialog(
      context: context,
      builder: (_) => _buildDetailDialog(day, detail, isLate, lateText),
    );
  }

  // ── Maps ───────────────────────────────────────────────────────────────────

  Future<void> _openSiteInMaps(int? siteId, String siteName) async {
    double? lat, lng;
    if (siteId != null) {
      try {
        final res = await ApiClient.get('/sites/$siteId/location');
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
      uri = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=$lat,$lng&query_place_id=${Uri.encodeComponent(siteName)}',
      );
    } else {
      uri = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(siteName)}',
      );
    }

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (mounted) {
      _showSnack('Could not open maps', isError: true);
    }
  }

  // ── BUILD ──────────────────────────────────────────────────────────────────
  // Matches AttendanceScreen: Scaffold → SafeArea → Padding → Column

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final sw = mq.size.width;
    final isSmall = sw < 360;
    final hPad = isSmall ? 12.0 : 16.0;
    final safeBot = mq.padding.bottom;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      body: SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(hPad, hPad, hPad, 0),
          child: Column(
            children: [
              // ── Header row (same pattern as AttendanceScreen log header) ──
              _buildHeader(isSmall: isSmall),
              SizedBox(height: isSmall ? 10 : 14),

              if (_loading)
                const Expanded(
                  child: Center(
                    child: CircularProgressIndicator(color: Colors.indigo),
                  ),
                )
              else ...[
                // ── Summary card (matches AttendanceScreen status card) ─────
                _buildSummaryCard(isSmall: isSmall),
                SizedBox(height: isSmall ? 10 : 14),

                // ── Month navigator ────────────────────────────────────────
                _buildMonthNav(isSmall: isSmall),
                SizedBox(height: isSmall ? 6 : 10),

                // ── Weekday header ─────────────────────────────────────────
                _buildWeekdayHeader(isSmall: isSmall),
                SizedBox(height: isSmall ? 4 : 6),

                // ── Calendar grid ──────────────────────────────────────────
                Expanded(child: _buildCalendar()),

                // ── Legend (matches AttendanceScreen log list bottom pad) ──
                Padding(
                  padding: EdgeInsets.only(
                    top: isSmall ? 8 : 10,
                    bottom: safeBot + (isSmall ? 8 : 12),
                  ),
                  child: _buildLegend(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ── Header — mirrors AttendanceScreen _buildLogHeader style ───────────────

  Widget _buildHeader({required bool isSmall}) {
    final rate = _attendanceRate;
    final ratePercent = (rate * 100).round();

    return Row(
      children: [
        // Back button — same container style used throughout AttendanceScreen
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            width: isSmall ? 34 : 38,
            height: isSmall ? 34 : 38,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(
              Icons.arrow_back_rounded,
              color: const Color(0xFF1A1A2E),
              size: isSmall ? 18 : 20,
            ),
          ),
        ),
        SizedBox(width: isSmall ? 10 : 12),

        // Title — same style as AttendanceScreen section labels
        Icon(
          Icons.calendar_month_rounded,
          size: isSmall ? 15 : 17,
          color: Colors.indigo,
        ),
        SizedBox(width: isSmall ? 5 : 7),
        Text(
          'Attendance History',
          style: TextStyle(
            fontSize: isSmall ? 12 : 13,
            fontWeight: FontWeight.w700,
            color: Colors.grey[800],
            letterSpacing: 0.2,
          ),
        ),

        const Spacer(),

        // Attendance rate badge — same style as session count badge
        if (!_loading) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _attendanceRate >= 0.9
                  ? Colors.green.shade50
                  : _attendanceRate >= 0.7
                  ? Colors.indigo.shade50
                  : Colors.orange.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _attendanceRate >= 0.9
                    ? Colors.green.shade200
                    : _attendanceRate >= 0.7
                    ? Colors.indigo.shade200
                    : Colors.orange.shade200,
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.trending_up_rounded,
                  size: 12,
                  color: _attendanceRate >= 0.9
                      ? Colors.green.shade700
                      : _attendanceRate >= 0.7
                      ? Colors.indigo.shade700
                      : Colors.orange.shade700,
                ),
                const SizedBox(width: 4),
                Text(
                  '$ratePercent%',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: _attendanceRate >= 0.9
                        ? Colors.green.shade700
                        : _attendanceRate >= 0.7
                        ? Colors.indigo.shade700
                        : Colors.orange.shade700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Pulse dot — same as AttendanceScreen status card live indicator
          AnimatedBuilder(
            animation: _pulseAnim,
            builder: (_, __) => Transform.scale(
              scale: _pulseAnim.value,
              child: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.indigo.shade300,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.indigo.withValues(alpha: 0.5),
                      blurRadius: 6,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  // ── Summary card — exact same structure as AttendanceScreen status card ───

  Widget _buildSummaryCard({required bool isSmall}) {
    final rate = _attendanceRate;

    // Gradient matches AttendanceScreen _StatusConfig gradients
    final LinearGradient gradient;
    final Color shadowColor;

    if (rate >= 0.9) {
      gradient = const LinearGradient(
        colors: [Color(0xFF2E7D32), Color(0xFF43A047)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
      shadowColor = const Color(0xFF2E7D32);
    } else if (rate >= 0.7) {
      gradient = const LinearGradient(
        colors: [Color(0xFF1565C0), Color(0xFF1E88E5)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
      shadowColor = const Color(0xFF1565C0);
    } else if (rate > 0) {
      gradient = const LinearGradient(
        colors: [Color(0xFFE65100), Color(0xFFFF6D00)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
      shadowColor = const Color(0xFFE65100);
    } else {
      gradient = const LinearGradient(
        colors: [Color(0xFF455A64), Color(0xFF607D8B)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
      shadowColor = const Color(0xFF455A64);
    }

    final cardPad = isSmall ? 14.0 : 20.0;
    final isCompact = MediaQuery.of(context).size.height < 680;

    return Container(
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: shadowColor.withValues(alpha: 0.35),
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
            // Top row — icon + title + pulse dot (matches AttendanceScreen)
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
                    Icons.bar_chart_rounded,
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
                        'Monthly Overview',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: isCompact ? 15 : 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _monthLabel(_focusedMonth),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.82),
                          fontSize: isCompact ? 11 : 12.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                // Static dot (same pattern as AttendanceScreen notStarted)
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),

            // Divider + stats — matches AttendanceScreen _buildCardBottom
            if (!isCompact) ...[
              const SizedBox(height: 16),
              Container(height: 1, color: Colors.white.withValues(alpha: 0.15)),
              const SizedBox(height: 14),
            ] else
              const SizedBox(height: 10),

            // Stats row — same _infoChip style columns as AttendanceScreen
            Row(
              children: [
                _statColumn(
                  icon: Icons.check_circle_outline_rounded,
                  label: 'Present',
                  value: '$_presentDays',
                  isCompact: isCompact,
                ),
                _statDivider(),
                _statColumn(
                  icon: Icons.cancel_outlined,
                  label: 'Absent',
                  value: '$_absentDays',
                  isCompact: isCompact,
                ),
                _statDivider(),
                _statColumn(
                  icon: Icons.schedule_rounded,
                  label: 'Late',
                  value: '$_lateDays',
                  isCompact: isCompact,
                ),
                _statDivider(),
                _statColumn(
                  icon: Icons.timelapse_rounded,
                  label: 'On-Site',
                  value: _fmtMinutes(_totalMinutes),
                  isCompact: isCompact,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _statColumn({
    required IconData icon,
    required String label,
    required String value,
    required bool isCompact,
  }) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
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
              Icon(icon, size: 14, color: Colors.white.withValues(alpha: 0.9)),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  value,
                  style: TextStyle(
                    fontSize: isCompact ? 13 : 15,
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statDivider() {
    return Container(
      width: 1,
      height: 32,
      margin: const EdgeInsets.symmetric(horizontal: 10),
      color: Colors.white.withValues(alpha: 0.2),
    );
  }

  // ── Month nav — matches the History button style in AttendanceScreen ───────

  Widget _buildMonthNav({required bool isSmall}) {
    final now = DateTime.now();
    final canGoNext = !DateTime(
      _focusedMonth.year,
      _focusedMonth.month + 1,
    ).isAfter(DateTime(now.year, now.month));

    return Row(
      children: [
        // Same icon button style used inside AttendanceScreen header
        InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            final prev = DateTime(_focusedMonth.year, _focusedMonth.month - 1);
            setState(() {
              _focusedMonth = prev;
              _dayData = {};
            });
            _loadMonth(prev);
          },
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Icon(
              Icons.chevron_left_rounded,
              size: 22,
              color: Colors.indigo.shade400,
            ),
          ),
        ),
        Expanded(
          child: Text(
            _monthLabel(_focusedMonth),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: isSmall ? 12 : 13,
              fontWeight: FontWeight.w700,
              color: Colors.grey[800],
              letterSpacing: 0.2,
            ),
          ),
        ),
        InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: canGoNext
              ? () {
                  final next = DateTime(
                    _focusedMonth.year,
                    _focusedMonth.month + 1,
                  );
                  setState(() {
                    _focusedMonth = next;
                    _dayData = {};
                  });
                  _loadMonth(next);
                }
              : null,
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Icon(
              Icons.chevron_right_rounded,
              size: 22,
              color: canGoNext ? Colors.indigo.shade400 : Colors.grey.shade300,
            ),
          ),
        ),
      ],
    );
  }

  // ── Weekday header ─────────────────────────────────────────────────────────

  Widget _buildWeekdayHeader({required bool isSmall}) {
    return Row(
      children: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
          .map(
            (d) => Expanded(
              child: Text(
                d,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: isSmall ? 9 : 10,
                  fontWeight: FontWeight.w700,
                  color: d == 'Sun'
                      ? Colors.red.shade300
                      : Colors.grey.shade400,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  // ── Calendar grid ──────────────────────────────────────────────────────────

  Widget _buildCalendar() {
    final firstDay = DateTime(_focusedMonth.year, _focusedMonth.month, 1);
    final startOffset = (firstDay.weekday - 1) % 7;
    final daysInMonth = DateUtils.getDaysInMonth(
      _focusedMonth.year,
      _focusedMonth.month,
    );
    final totalCells = startOffset + daysInMonth;
    final rows = (totalCells / 7).ceil();

    return GridView.builder(
      padding: const EdgeInsets.symmetric(vertical: 4),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        mainAxisSpacing: 5,
        crossAxisSpacing: 4,
        childAspectRatio: 0.72,
      ),
      itemCount: rows * 7,
      itemBuilder: (_, index) {
        final dayNum = index - startOffset + 1;
        if (dayNum < 1 || dayNum > daysInMonth) return const SizedBox();
        final day = DateTime(_focusedMonth.year, _focusedMonth.month, dayNum);
        return _buildDayCell(day);
      },
    );
  }

  // Day cell — uses same white card + border style as AttendanceScreen log items
  Widget _buildDayCell(DateTime day) {
    final dateStr = _fmtDate(day);
    final data = _dayData[dateStr];
    final isToday = _isToday(day);
    final isFuture = _isFuture(day);
    final isSunday = day.weekday == DateTime.sunday;
    final isPresent = data != null;
    final totalMin = (data?['total_minutes'] as int?) ?? 0;
    final isLate = data?['is_late'] == true;

    Color bgColor = Colors.white;
    Color textColor = const Color(0xFF1A1A2E);
    Color borderColor = Colors.grey.shade200;

    if (isFuture) {
      bgColor = Colors.grey.shade50;
      textColor = Colors.grey.shade300;
      borderColor = Colors.transparent;
    } else if (isToday) {
      borderColor = Colors.indigo;
      bgColor = const Color(0xFFEEF2FF);
    } else if (isPresent) {
      if (isLate) {
        bgColor = const Color(0xFFFFF8E1);
        borderColor = Colors.orange.shade200;
      } else {
        bgColor = const Color(0xFFE8F5E9);
        borderColor = Colors.green.shade200;
      }
    } else if (!isFuture) {
      bgColor = const Color(0xFFFFF3F3);
      borderColor = Colors.red.shade100;
    }

    if (isSunday && !isFuture) textColor = Colors.red.shade400;

    return GestureDetector(
      onTap: isFuture ? null : () => _onDayTap(day),
      child: Container(
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(10),
          // Same border style as AttendanceScreen log list items
          border: Border.all(color: borderColor, width: isToday ? 1.5 : 1.2),
          boxShadow: isPresent && !isFuture
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            const SizedBox(height: 6),
            // Day number — same circle style as AttendanceScreen "today"
            Container(
              width: 22,
              height: 22,
              decoration: isToday
                  ? const BoxDecoration(
                      color: Colors.indigo,
                      shape: BoxShape.circle,
                    )
                  : null,
              child: Center(
                child: Text(
                  '${day.day}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isToday ? Colors.white : textColor,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 3),
            if (isPresent && !isFuture) ...[
              Text(
                _fmtMinutes(totalMin),
                style: TextStyle(
                  fontSize: 8,
                  fontWeight: FontWeight.w700,
                  color: isLate
                      ? Colors.orange.shade800
                      : const Color(0xFF2E7D32),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 2),
              // Status indicator — matches AttendanceScreen log item icons
              if (isLate)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 3,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade600,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'Late',
                    style: TextStyle(
                      fontSize: 7,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                )
              else
                Container(
                  width: 16,
                  height: 3,
                  decoration: BoxDecoration(
                    color: Colors.green.shade400,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
            ] else if (!isPresent && !isFuture && !isSunday) ...[
              Text(
                'Abs',
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

  // ── Legend — same container style as AttendanceScreen cards ───────────────

  Widget _buildLegend() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _legendItem(
            const Color(0xFFE8F5E9),
            Colors.green.shade200,
            'Present',
          ),
          _legendItem(const Color(0xFFFFF3F3), Colors.red.shade100, 'Absent'),
          _legendItem(const Color(0xFFEEF2FF), Colors.indigo, 'Today'),
          _legendItem(const Color(0xFFFFF8E1), Colors.orange.shade200, 'Late'),
        ],
      ),
    );
  }

  Widget _legendItem(Color bg, Color border, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 11,
          height: 11,
          decoration: BoxDecoration(
            color: bg,
            border: Border.all(color: border, width: 1.2),
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  // ── Absent dialog ──────────────────────────────────────────────────────────
  // Same AlertDialog shape/style as AttendanceScreen dialogs

  Widget _buildAbsentDialog(DateTime day) => AlertDialog(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
            Text(
              day.weekday == DateTime.sunday ? 'Weekly Off' : 'No Attendance',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
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

  // ── Detail dialog ──────────────────────────────────────────────────────────
  // Header gradient matches AttendanceScreen status card.
  // Visit rows match AttendanceScreen log list items exactly.

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
          // Header — matches AttendanceScreen status card gradient + structure
          Container(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isLate
                    ? [const Color(0xFFE65100), const Color(0xFFFF6D00)]
                    : [const Color(0xFF2E7D32), const Color(0xFF43A047)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    isLate
                        ? Icons.schedule_rounded
                        : Icons.check_circle_rounded,
                    color: Colors.white,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _fullDate(day),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      // Late badge — matches AttendanceScreen late badge style
                      if (isLate && lateText != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.25),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.schedule_rounded,
                                size: 13,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                'Late by $lateText',
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 4),
                      ],
                      Text(
                        'Total: ${_fmtMinutes(totalMin)}  ·  ${sessions.length} session(s)',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: Colors.white.withValues(alpha: 0.82),
                          fontWeight: FontWeight.w500,
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

          // Sessions list — log items match AttendanceScreen log list exactly
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
                    padding: const EdgeInsets.all(14),
                    itemCount: sessions.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, si) {
                      final sess = sessions[si];
                      final visits = (sess['visits'] as List?) ?? [];
                      final sessMin =
                          (sess['site_minutes'] as num?)?.toInt() ?? 0;
                      final sessNum = sess['session_number'] ?? (si + 1);

                      return Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: Colors.grey.shade200,
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
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Session header row
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              child: Row(
                                children: [
                                  // Session badge — same indigo style as AttendanceScreen S-badge
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.indigo.shade50,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      'S$sessNum',
                                      style: TextStyle(
                                        fontSize: 9,
                                        color: Colors.indigo.shade400,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  // Times — same _timeTag style as log list
                                  _timeTag(
                                    icon: Icons.login_rounded,
                                    time: _fmtTime(
                                      sess['started_at']?.toString(),
                                    ),
                                    color: Colors.green.shade700,
                                    bg: Colors.green.shade50,
                                  ),
                                  const Padding(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 4,
                                    ),
                                    child: Text(
                                      '→',
                                      style: TextStyle(
                                        color: Colors.grey,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                                  _timeTag(
                                    icon: Icons.logout_rounded,
                                    time: sess['ended_at'] != null
                                        ? _fmtTime(sess['ended_at'].toString())
                                        : 'Active',
                                    color: sess['ended_at'] != null
                                        ? Colors.red.shade400
                                        : Colors.orange.shade700,
                                    bg: sess['ended_at'] != null
                                        ? Colors.red.shade50
                                        : Colors.orange.shade50,
                                  ),
                                  const Spacer(),
                                  // Duration badge — gradient matches log list
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          Colors.grey.shade300,
                                          Colors.grey.shade400,
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      _fmtMinutes(sessMin),
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.grey.shade700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Divider
                            Divider(
                              height: 1,
                              thickness: 1,
                              color: Colors.grey.shade100,
                            ),

                            // Visits — each row matches AttendanceScreen log list item
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
                                    v['site_name'] as String? ?? 'Unknown';
                                final siteId = v['site_id'] as int?;

                                return InkWell(
                                  onTap: () =>
                                      _openSiteInMaps(siteId, siteName),
                                  borderRadius: isLast
                                      ? const BorderRadius.vertical(
                                          bottom: Radius.circular(14),
                                        )
                                      : BorderRadius.zero,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 10,
                                    ),
                                    child: Row(
                                      children: [
                                        // Icon container — matches log list item icon
                                        Container(
                                          width: 36,
                                          height: 36,
                                          decoration: BoxDecoration(
                                            color: isOpen
                                                ? Colors.green.shade50
                                                : Colors.grey.shade100,
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                          ),
                                          child: Icon(
                                            isOpen
                                                ? Icons.radio_button_on_rounded
                                                : Icons
                                                      .check_circle_outline_rounded,
                                            size: 18,
                                            color: isOpen
                                                ? Colors.green
                                                : Colors.grey,
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
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        fontSize: 13.5,
                                                        color: Color(
                                                          0xFF1A1A2E,
                                                        ),
                                                      ),
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                  Icon(
                                                    Icons.open_in_new_rounded,
                                                    size: 12,
                                                    color:
                                                        Colors.indigo.shade300,
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 4),
                                              // Time tags — exact same _timeTag widget
                                              Wrap(
                                                spacing: 6,
                                                runSpacing: 4,
                                                children: [
                                                  _timeTag(
                                                    icon: Icons.login_rounded,
                                                    time: _fmtTime(
                                                      v['in_time']?.toString(),
                                                    ),
                                                    color:
                                                        Colors.green.shade700,
                                                    bg: Colors.green.shade50,
                                                  ),
                                                  _timeTag(
                                                    icon: Icons.logout_rounded,
                                                    time: isOpen
                                                        ? 'Active'
                                                        : _fmtTime(
                                                            v['out_time']
                                                                ?.toString(),
                                                          ),
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

                                        // Duration — gradient matches log list
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
                                                    colors: [
                                                      Colors.grey.shade300,
                                                      Colors.grey.shade400,
                                                    ],
                                                  ),
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                          ),
                                          child: Text(
                                            _fmtMinutes(vMin),
                                            style: TextStyle(
                                              fontSize: 11.5,
                                              fontWeight: FontWeight.w700,
                                              color: isOpen
                                                  ? Colors.white
                                                  : Colors.grey.shade700,
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

          // Footer — same TextButton style as AttendanceScreen dialogs
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
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

  // ── Shared widgets (copied from AttendanceScreen) ─────────────────────────

  /// Identical to AttendanceScreen._timeTag
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
}
