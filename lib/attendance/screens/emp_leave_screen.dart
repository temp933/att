// import '../services/leave_service.dart';
// import 'dart:convert';
// import 'package:flutter/material.dart';
// import 'responsive_utils.dart';
// import '../models/leavemodel.dart';
// import 'emp_holiday_view.dart';
// import '../providers/api_client.dart';

// class LeaveScreen extends StatefulWidget {
//   final String employeeId;
//   const LeaveScreen({super.key, required this.employeeId});

//   @override
//   State<LeaveScreen> createState() => _LeaveScreenState();
// }

// class _LeaveScreenState extends State<LeaveScreen>
//     with SingleTickerProviderStateMixin {
//   List<LeaveModel> leaves = [];
//   bool loading = true;
//   String? errorMessage;
//   bool isHalfDay = false;
//   String? halfDayPeriod;
//   DateTime? fromDate;
//   DateTime? toDate;
//   String? leaveType;
//   String? reason;
//   int? editingLeaveId;
//   late AnimationController _animCtrl;
//   late Animation<double> _fadeAnim;
//   List<Map<String, dynamic>> _leaveBalances = [];
//   bool _compoffEligible = false;
//   double _compoffAvailable = 0.0;
//   final Map<String, String> _personNames = {};

//   // ─── Design Tokens ───────────────────────────────────────────────────────────
//   static const Color _primary = Color(0xFF1A56DB);
//   static const Color _accent = Color(0xFF0E9F6E);
//   static const Color _red = Color(0xFFEF4444);
//   static const Color _surface = Color(0xFFF0F4FF);
//   static const Color _textDark = Color(0xFF0F172A);
//   static const Color _textMid = Color(0xFF64748B);
//   static const Color _textLight = Color(0xFF94A3B8);
//   static const Color _border = Color(0xFFE2E8F0);
//   static const int _totalAllowed = 12;

//   @override
//   void initState() {
//     super.initState();
//     _animCtrl = AnimationController(
//       vsync: this,
//       duration: const Duration(milliseconds: 500),
//     );
//     _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
//     fetchLeaves();
//   }

//   @override
//   void dispose() {
//     _animCtrl.dispose();
//     super.dispose();
//   }

//   // ─── Data ─────────────────────────────────────────────────────────────────────
//   Future<void> fetchLeaves() async {
//     setState(() {
//       loading = true;
//       errorMessage = null;
//     });
//     try {
//       final results = await Future.wait([
//         ApiClient.get('/employees/${widget.employeeId}/leaves'),
//         ApiClient.get(
//           '/employees/${widget.employeeId}/leave-balance?year=${DateTime.now().year}',
//         ),
//         ApiClient.get('/employees/${widget.employeeId}/compoff-eligible'),
//       ]);

//       // Leaves
//       final leavesRes = results[0];
//       if (leavesRes.statusCode == 200) {
//         final data = jsonDecode(leavesRes.body);
//         if (data['success'] == true) {
//           final list = data['data'] as List;
//           setState(() {
//             leaves = list.map((e) => LeaveModel.fromPendingJson(e)).toList();
//           });
//           _animCtrl.forward(from: 0);
//           final ids = <String>{};
//           for (final l in list) {
//             if (l['recommended_by'] != null) {
//               ids.add(l['recommended_by'].toString());
//             }
//             if (l['approved_by'] != null) {
//               ids.add(l['approved_by'].toString());
//             }
//           }
//           for (final id in ids) {
//             _fetchPersonName(id);
//           }
//         }
//       }

//       // Balance
//       final balRes = results[1];
//       if (balRes.statusCode == 200) {
//         final data = jsonDecode(balRes.body);
//         if (data['success'] == true) {
//           setState(() {
//             _leaveBalances = List<Map<String, dynamic>>.from(data['data']);
//           });
//         }
//       }

//       // Comp-off eligibility
//       final compRes = results[2];
//       if (compRes.statusCode == 200) {
//         final data = jsonDecode(compRes.body);
//         if (data['success'] == true) {
//           setState(() {
//             _compoffEligible = data['eligible'] as bool;
//             _compoffAvailable = _parseDouble(data['available']); // ← safe parse
//           });
//         }
//       }
//     } catch (e) {
//       setState(
//         () => errorMessage = 'Unable to load leaves. Check your connection.',
//       );
//     } finally {
//       setState(() => loading = false);
//     }
//   }

//   Future<void> _fetchPersonName(String id) async {
//     if (_personNames.containsKey(id)) return;
//     try {
//       // /employee-user/:loginId — queries by login_id (fixed in server.js)
//       final res = await ApiClient.get('/employee-user/$id');
//       if (res.statusCode == 200) {
//         final data = jsonDecode(res.body) as Map<String, dynamic>;
//         if (data['success'] == true) {
//           final name = (data['full_name'] ?? '').toString().trim();
//           final role = (data['role_name'] ?? '').toString().trim();
//           final display = role.isNotEmpty ? '$name · $role' : name;
//           if (mounted) {
//             setState(
//               () =>
//                   _personNames[id] = display.isNotEmpty ? display : 'User #$id',
//             );
//           }
//         }
//       }
//     } catch (_) {}
//   }

//   String _resolvePerson(dynamic id) {
//     if (id == null) return '-';
//     return _personNames[id.toString()] ?? 'Loading…';
//   }

//   Future<void> submitLeave() async {
//     if (leaveType == null || fromDate == null || toDate == null) return;
//     try {
//       final body = <String, dynamic>{
//         "leave_type": leaveType,
//         "leave_start_date": fromDate!.toIso8601String().split('T')[0],
//         "leave_end_date": toDate!.toIso8601String().split('T')[0],
//         "reason": reason ?? "",
//         "is_half_day": isHalfDay, // ← bool, not string
//       };

//       // ← Only add half_day_period when actually half day
//       if (isHalfDay && halfDayPeriod != null) {
//         body["half_day_period"] = halfDayPeriod;
//       }

//       final res = await ApiClient.post(
//         '/employees/${widget.employeeId}/apply-leave',
//         body,
//       );

//       final result = jsonDecode(res.body) as Map<String, dynamic>;
//       if (result['success'] == true) {
//         _showSnack(result['message'] as String, success: true);
//         if (mounted) Navigator.pop(context);
//         clearForm();
//         fetchLeaves();
//       } else {
//         _showSnack(result['message']?.toString() ?? 'Submission failed');
//       }
//     } catch (e) {
//       _showSnack('Error: $e');
//     }
//   }

//   Future<void> cancelLeave(int id, String cancelReason) async {
//     try {
//       final res = await ApiClient.put('/leave/$id/cancel', {
//         'cancel_reason': cancelReason,
//       });
//       final data = jsonDecode(res.body);
//       _showSnack(data['message'], success: data['success'] == true);
//       if (data['success'] == true) fetchLeaves();
//     } catch (e) {
//       _showSnack('Error cancelling: $e');
//     }
//   }

//   void clearForm() {
//     leaveType = null;
//     reason = null;
//     fromDate = null;
//     toDate = null;
//     editingLeaveId = null;
//     isHalfDay = false; // ← add
//     halfDayPeriod = null; // ← add
//   }

//   void _showSnack(String msg, {bool success = false}) {
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(
//         content: Row(
//           children: [
//             Icon(
//               success
//                   ? Icons.check_circle_rounded
//                   : Icons.error_outline_rounded,
//               color: Colors.white,
//               size: 18,
//             ),
//             const SizedBox(width: 8),
//             Expanded(
//               child: Text(
//                 msg,
//                 style: const TextStyle(fontWeight: FontWeight.w500),
//               ),
//             ),
//           ],
//         ),
//         backgroundColor: success ? _accent : _red,
//         behavior: SnackBarBehavior.floating,
//         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//         margin: const EdgeInsets.all(16),
//       ),
//     );
//   }

//   // ─── Summary ──────────────────────────────────────────────────────────────────
//   int get _approvedDays => leaves
//       .where((e) => e.status == 'Approved')
//       .fold<int>(0, (s, e) => s + (e.numberOfDays));
//   int get _remainingDays =>
//       (_totalAllowed - _approvedDays).clamp(0, _totalAllowed);
//   int get _pendingCount => leaves
//       .where((e) => e.status == 'Pending_TL' || e.status == 'Pending_Manager')
//       .length;
//   // ─── Root ─────────────────────────────────────────────────────────────────────
//   @override
//   Widget build(BuildContext context) {
//     final r = Responsive.of(context);
//     return Scaffold(
//       backgroundColor: _surface,
//       floatingActionButton: _buildFAB(r),
//       body: loading
//           ? const Center(child: CircularProgressIndicator(color: _primary))
//           : errorMessage != null
//           ? _buildError(r)
//           : RefreshIndicator(
//               onRefresh: fetchLeaves,
//               color: _primary,
//               child: CustomScrollView(
//                 physics: const AlwaysScrollableScrollPhysics(),
//                 slivers: [
//                   _buildSliverAppBar(r),
//                   SliverToBoxAdapter(child: _buildSummaryBar(r)),
//                   SliverToBoxAdapter(child: _buildHistoryHeader(r)),
//                   if (leaves.isEmpty)
//                     SliverToBoxAdapter(child: _buildEmpty(r))
//                   else
//                     SliverPadding(
//                       padding: EdgeInsets.fromLTRB(r.hPad, 0, r.hPad, 100),
//                       sliver: SliverToBoxAdapter(
//                         child: Center(
//                           child: ConstrainedBox(
//                             constraints: BoxConstraints(
//                               maxWidth: r.contentMaxWidth,
//                             ),
//                             child: FadeTransition(
//                               opacity: _fadeAnim,
//                               child: r.useTwoColSections
//                                   ? _buildLeaveGrid(r)
//                                   : _buildLeaveList(r),
//                             ),
//                           ),
//                         ),
//                       ),
//                     ),
//                 ],
//               ),
//             ),
//     );
//   }

//   Widget _buildLeaveGrid(Responsive r) {
//     return LayoutBuilder(
//       builder: (ctx, constraints) {
//         const cols = 2;
//         const gap = 12.0;
//         final itemW = (constraints.maxWidth - gap * (cols - 1)) / cols;
//         return Wrap(
//           spacing: gap,
//           runSpacing: gap,
//           children: List.generate(
//             leaves.length,
//             (i) => SizedBox(
//               width: itemW,
//               child: _LeaveCard(
//                 leave: leaves[i],
//                 resolvePerson: _resolvePerson,
//                 onEdit: leaves[i].status == 'Pending_TL'
//                     ? () => _openEdit(leaves[i])
//                     : null,
//                 onCancel: leaves[i].status == 'Pending_TL'
//                     ? (r) => cancelLeave(leaves[i].leaveId!, r)
//                     : null,
//               ),
//             ),
//           ),
//         );
//       },
//     );
//   }

//   Widget _buildLeaveList(Responsive r) {
//     return Column(
//       children: List.generate(
//         leaves.length,
//         (i) => _LeaveCard(
//           leave: leaves[i],
//           resolvePerson: _resolvePerson,
//           onEdit: leaves[i].status == 'Pending_TL'
//               ? () => _openEdit(leaves[i])
//               : null,
//           onCancel: leaves[i].status == 'Pending_TL'
//               ? (r) => cancelLeave(leaves[i].leaveId!, r)
//               : null,
//         ),
//       ),
//     );
//   }

//   void _openEdit(LeaveModel leave) {
//     editingLeaveId = leave.leaveId;
//     leaveType = leave.leaveType;
//     reason = leave.reason;
//     fromDate = leave.fromDate;
//     toDate = leave.toDate;
//     _showApplySheet(context);
//   }

//   // ─── Sliver AppBar ────────────────────────────────────────────────────────────
//   Widget _buildSliverAppBar(Responsive r) {
//     return SliverToBoxAdapter(
//       child: Container(
//         color: _primary,
//         padding: EdgeInsets.fromLTRB(
//           r.hPad,
//           MediaQuery.of(context).padding.top + 8,
//           4,
//           12,
//         ),
//         child: Row(
//           children: [
//             const Text(
//               'My Leaves',
//               style: TextStyle(
//                 fontSize: 17,
//                 fontWeight: FontWeight.w800,
//                 color: Colors.white,
//               ),
//             ),
//             const Spacer(),
//             // ── NEW: Holiday Calendar button ──────────────────────────
//             IconButton(
//               icon: const Icon(
//                 Icons.event_note_rounded,
//                 color: Colors.white,
//                 size: 20,
//               ),
//               tooltip: 'Holiday Calendar',
//               padding: const EdgeInsets.all(8),
//               constraints: const BoxConstraints(),
//               onPressed: () => Navigator.push(
//                 context,
//                 MaterialPageRoute(builder: (_) => const EmpHolidayView()),
//               ),
//             ),
//             // ── existing refresh button ───────────────────────────────
//             IconButton(
//               icon: const Icon(
//                 Icons.refresh_rounded,
//                 color: Colors.white,
//                 size: 20,
//               ),
//               padding: const EdgeInsets.all(8),
//               constraints: const BoxConstraints(),
//               onPressed: loading ? null : fetchLeaves,
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   // ─── Summary Bar ─────────────────────────────────────────────────────────────
//   Widget _buildSummaryBar(Responsive r) {
//     double totalAvailable = 0;
//     double totalUsed = 0;
//     double totalRemaining = 0;
//     int pending = 0;

//     for (final b in _leaveBalances) {
//       if (b['leave_type'] == 'Comp-Off') continue;
//       totalAvailable += _parseDouble(b['total_available']);
//       totalUsed += _parseDouble(b['used_days']);
//       totalRemaining += _parseDouble(b['remaining_days']);
//     }

//     pending = leaves
//         .where((e) => e.status == 'Pending_TL' || e.status == 'Pending_Manager')
//         .length;

//     return Container(
//       color: _primary,
//       padding: EdgeInsets.fromLTRB(r.hPad, 0, r.hPad, 20),
//       child: Center(
//         child: ConstrainedBox(
//           constraints: BoxConstraints(maxWidth: r.contentMaxWidth),
//           child: Container(
//             padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
//             decoration: BoxDecoration(
//               color: Colors.white.withValues(alpha: 0.12),
//               borderRadius: BorderRadius.circular(14),
//               border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
//             ),
//             child: Row(
//               children: [
//                 _statItem(
//                   totalAvailable.toStringAsFixed(0),
//                   'Total',
//                   Colors.white,
//                 ),
//                 _vDiv(),
//                 _statItem(
//                   totalRemaining.toStringAsFixed(1),
//                   'Remaining',
//                   const Color(0xFF6EE7B7),
//                 ),
//                 _vDiv(),
//                 _statItem(
//                   totalUsed.toStringAsFixed(1),
//                   'Used',
//                   const Color(0xFFFDE68A),
//                 ),
//                 _vDiv(),
//                 _statItem('$pending', 'Pending', Colors.white70),
//               ],
//             ),
//           ),
//         ),
//       ),
//     );
//   }

//   Widget _statItem(String v, String l, Color c) {
//     return Expanded(
//       child: Column(
//         children: [
//           Text(
//             v,
//             style: TextStyle(
//               fontSize: 18,
//               fontWeight: FontWeight.w800,
//               color: c,
//             ),
//           ),
//           const SizedBox(height: 2),
//           Text(
//             l,
//             style: TextStyle(
//               fontSize: 10,
//               color: c.withValues(alpha: 0.75),
//               letterSpacing: 0.4,
//               fontWeight: FontWeight.w500,
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _vDiv() {
//     return Container(
//       width: 1,
//       height: 28,
//       color: Colors.white.withValues(alpha: 0.2),
//     );
//   }

//   Widget _buildHistoryHeader(Responsive r) {
//     return Padding(
//       padding: EdgeInsets.fromLTRB(r.hPad, 20, r.hPad, 12),
//       child: Center(
//         child: ConstrainedBox(
//           constraints: BoxConstraints(maxWidth: r.contentMaxWidth),
//           child: const Text(
//             'Leave History',
//             style: TextStyle(
//               fontSize: 15,
//               fontWeight: FontWeight.w700,
//               color: Color(0xFF0F172A),
//             ),
//           ),
//         ),
//       ),
//     );
//   }

//   Widget _buildFAB(Responsive r) {
//     return FloatingActionButton.extended(
//       backgroundColor: _primary,
//       elevation: 4,
//       onPressed: () {
//         clearForm();
//         _showApplySheet(context);
//       },
//       icon: const Icon(Icons.add_rounded, color: Colors.white, size: 20),
//       label: const Text(
//         'Apply Leave',
//         style: TextStyle(
//           color: Colors.white,
//           fontWeight: FontWeight.w700,
//           fontSize: 14,
//           letterSpacing: 0.3,
//         ),
//       ),
//       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
//     );
//   }

//   Widget _buildError(Responsive r) {
//     return Center(
//       child: Padding(
//         padding: EdgeInsets.symmetric(horizontal: r.hPad),
//         child: ConstrainedBox(
//           constraints: BoxConstraints(maxWidth: r.contentMaxWidth),
//           child: Column(
//             mainAxisAlignment: MainAxisAlignment.center,
//             children: [
//               Container(
//                 padding: const EdgeInsets.all(20),
//                 decoration: BoxDecoration(
//                   color: _red.withValues(alpha: 0.08),
//                   shape: BoxShape.circle,
//                 ),
//                 child: const Icon(
//                   Icons.wifi_off_rounded,
//                   color: _red,
//                   size: 40,
//                 ),
//               ),
//               const SizedBox(height: 16),
//               const Text(
//                 'Failed to load leaves',
//                 style: TextStyle(
//                   fontSize: 17,
//                   fontWeight: FontWeight.w700,
//                   color: _textDark,
//                 ),
//               ),
//               const SizedBox(height: 6),
//               Text(
//                 errorMessage!,
//                 textAlign: TextAlign.center,
//                 style: const TextStyle(color: _textMid, fontSize: 13),
//               ),
//               const SizedBox(height: 24),
//               FilledButton.icon(
//                 onPressed: fetchLeaves,
//                 icon: const Icon(Icons.refresh_rounded, size: 18),
//                 label: const Text('Try Again'),
//                 style: FilledButton.styleFrom(
//                   backgroundColor: _primary,
//                   padding: const EdgeInsets.symmetric(
//                     horizontal: 24,
//                     vertical: 12,
//                   ),
//                   shape: RoundedRectangleBorder(
//                     borderRadius: BorderRadius.circular(12),
//                   ),
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }

//   Widget _buildEmpty(Responsive r) {
//     return Padding(
//       padding: EdgeInsets.fromLTRB(r.hPad, 60, r.hPad, 60),
//       child: Center(
//         child: Column(
//           children: [
//             Container(
//               padding: const EdgeInsets.all(24),
//               decoration: BoxDecoration(
//                 color: _primary.withValues(alpha: 0.06),
//                 shape: BoxShape.circle,
//               ),
//               child: const Icon(
//                 Icons.beach_access_rounded,
//                 size: 44,
//                 color: _textLight,
//               ),
//             ),
//             const SizedBox(height: 16),
//             const Text(
//               'No leaves applied yet',
//               style: TextStyle(
//                 fontSize: 17,
//                 fontWeight: FontWeight.w700,
//                 color: _textDark,
//               ),
//             ),
//             const SizedBox(height: 6),
//             const Text(
//               'Tap Apply Leave to submit a request',
//               style: TextStyle(color: _textMid, fontSize: 13),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   void _showApplySheet(BuildContext context) {
//     showModalBottomSheet(
//       context: context,
//       isScrollControlled: true,
//       backgroundColor: Colors.transparent,
//       builder: (_) => _ApplyLeaveSheet(
//         isEdit: editingLeaveId != null,
//         initialLeaveType: leaveType,
//         initialFromDate: fromDate,
//         initialToDate: toDate,
//         initialReason: reason,
//         leaveBalances: _leaveBalances, // ← pass balances
//         compoffEligible: _compoffEligible, // ← pass eligibility
//         compoffAvailable: _compoffAvailable, // ← pass balance
//         onSubmit: (lType, fDate, tDate, r, halfDay, halfPeriod) {
//           leaveType = lType;
//           fromDate = fDate;
//           toDate = tDate;
//           reason = r;
//           isHalfDay = halfDay;
//           halfDayPeriod = halfPeriod;
//           submitLeave();
//         },
//       ),
//     );
//   }
// }

// class _LeaveBalanceSummary extends StatefulWidget {
//   final String employeeId;
//   const _LeaveBalanceSummary({required this.employeeId});
//   @override
//   State<_LeaveBalanceSummary> createState() => _LeaveBalanceSummaryState();
// }

// class _LeaveBalanceSummaryState extends State<_LeaveBalanceSummary> {
//   List<Map<String, dynamic>> _balances = [];
//   bool _loading = true;

//   static const Color _primary = Color(0xFF1A56DB);
//   static const Color _accent = Color(0xFF0E9F6E);
//   static const Color _red = Color(0xFFEF4444);
//   static const Color _amber = Color(0xFFF59E0B);
//   static const Color _surface = Color(0xFFF0F4FF);
//   static const Color _textDark = Color(0xFF0F172A);
//   static const Color _textMid = Color(0xFF64748B);

//   @override
//   void initState() {
//     super.initState();
//     _load();
//   }

//   Widget _buildCompoffRow() {
//     final compoff = _balances.firstWhere(
//       (b) => b['leave_type'] == 'Comp-Off',
//       orElse: () => <String, dynamic>{},
//     );

//     if (compoff.isEmpty) return const SizedBox.shrink();

//     final remaining = _parseDouble(compoff['remaining_days']); // ← safe parse

//     if (remaining <= 0) return const SizedBox.shrink();

//     return Container(
//       margin: const EdgeInsets.only(top: 8),
//       padding: const EdgeInsets.all(10),
//       decoration: BoxDecoration(
//         color: _surface,
//         borderRadius: BorderRadius.circular(10),
//         border: Border.all(color: const Color(0xFFE2E8F0)),
//       ),
//       child: Row(
//         children: [
//           const Icon(
//             Icons.work_history_rounded,
//             size: 14,
//             color: Color(0xFF7C3AED),
//           ),
//           const SizedBox(width: 8),
//           const Text(
//             'Comp-Off',
//             style: TextStyle(
//               fontSize: 12,
//               fontWeight: FontWeight.w600,
//               color: Color(0xFF7C3AED),
//             ),
//           ),
//           const Spacer(),
//           Text(
//             '${remaining.toStringAsFixed(1)} day(s) available',
//             style: const TextStyle(
//               fontSize: 12,
//               fontWeight: FontWeight.w700,
//               color: _textDark,
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Future<void> _load() async {
//     final res = await ApiClient.get(
//       '/employees/${widget.employeeId}/leave-balance?year=${DateTime.now().year}',
//     );
//     if (mounted && res.statusCode == 200) {
//       final data = jsonDecode(res.body);
//       if (data['success'] == true) {
//         setState(() {
//           _balances = List<Map<String, dynamic>>.from(data['data']);
//           _loading = false;
//         });
//         return;
//       }
//     }
//     if (mounted) setState(() => _loading = false);
//   }

//   Color _colorForType(String t) {
//     switch (t) {
//       case 'Casual':
//         return _primary;
//       case 'Sick':
//         return _red;
//       case 'Paid':
//         return _accent;
//       default:
//         return _amber;
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     if (_loading) {
//       return const SizedBox(
//         height: 56,
//         child: Center(
//           child: CircularProgressIndicator(color: _primary, strokeWidth: 2),
//         ),
//       );
//     }
//     if (_balances.isEmpty) return const SizedBox.shrink();

//     return Container(
//       color: Colors.white,
//       padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           const Text(
//             'Leave balance',
//             style: TextStyle(
//               fontSize: 12,
//               fontWeight: FontWeight.w600,
//               color: _textMid,
//               letterSpacing: 0.3,
//             ),
//           ),
//           const SizedBox(height: 8),
//           Row(
//             children: _balances.where((b) => b['leave_type'] != 'Comp-Off').map((
//               b,
//             ) {
//               final type = b['leave_type'] as String;
//               final remaining = _parseDouble(b['remaining_days']); // ← safe
//               final total = _parseDouble(b['total_available']); // ← safe
//               final color = _colorForType(type);
//               final pct = total > 0 ? (remaining / total).clamp(0.0, 1.0) : 0.0;

//               return Expanded(
//                 child: Container(
//                   margin: const EdgeInsets.only(right: 8),
//                   padding: const EdgeInsets.all(10),
//                   decoration: BoxDecoration(
//                     color: _surface,
//                     borderRadius: BorderRadius.circular(10),
//                     border: Border.all(color: const Color(0xFFE2E8F0)),
//                   ),
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       Text(
//                         type,
//                         style: TextStyle(
//                           fontSize: 11,
//                           fontWeight: FontWeight.w600,
//                           color: color,
//                         ),
//                       ),
//                       const SizedBox(height: 4),
//                       Text(
//                         '${remaining.toStringAsFixed(remaining % 1 == 0 ? 0 : 1)} left',
//                         style: const TextStyle(
//                           fontSize: 13,
//                           fontWeight: FontWeight.w700,
//                           color: _textDark,
//                         ),
//                       ),
//                       const SizedBox(height: 6),
//                       ClipRRect(
//                         borderRadius: BorderRadius.circular(4),
//                         child: LinearProgressIndicator(
//                           value: pct,
//                           minHeight: 4,
//                           backgroundColor: color.withValues(
//                             alpha: 0.12,
//                           ), // ← fixed deprecated
//                           valueColor: AlwaysStoppedAnimation(color),
//                         ),
//                       ),
//                       const SizedBox(height: 3),
//                       Text(
//                         'of ${total.toStringAsFixed(0)} days',
//                         style: const TextStyle(fontSize: 10, color: _textMid),
//                       ),
//                     ],
//                   ),
//                 ),
//               );
//             }).toList(),
//           ),
//           _buildCompoffRow(),
//         ],
//       ),
//     );
//   }
// }

// // ═══════════════════════════════════════════════════════════════════════════════
// // Leave Card
// // ═══════════════════════════════════════════════════════════════════════════════
// class _LeaveCard extends StatefulWidget {
//   final LeaveModel leave;
//   final String Function(dynamic) resolvePerson;
//   final VoidCallback? onEdit;
//   final Function(String)? onCancel;

//   const _LeaveCard({
//     required this.leave,
//     required this.resolvePerson,
//     this.onEdit,
//     this.onCancel,
//   });

//   @override
//   State<_LeaveCard> createState() => _LeaveCardState();
// }

// class _LeaveCardState extends State<_LeaveCard> {
//   bool _expanded = false;

//   static const Color _primary = Color(0xFF1A56DB);
//   static const Color _accent = Color(0xFF0E9F6E);
//   static const Color _red = Color(0xFFEF4444);
//   static const Color _orange = Color(0xFFF97316); // for Not_Recommended
//   static const Color _textDark = Color(0xFF0F172A);
//   static const Color _textMid = Color(0xFF64748B);
//   static const Color _textLight = Color(0xFF94A3B8);

//   // ── Status config — extended with Not_Recommended_By_TL ───────────────────
//   // In _LeaveCardState._statusCfg — replace the entire map:
//   static const _statusCfg = <String, Map<String, dynamic>>{
//     'Approved': {
//       'label': 'Approved',
//       'color': Color(0xFF0E9F6E),
//       'bg': Color(0xFFECFDF5),
//       'icon': Icons.check_circle_rounded,
//     },
//     'Rejected_By_TL': {
//       'label': 'Rejected by TL',
//       'color': Color(0xFFEF4444),
//       'bg': Color(0xFFFFF1F2),
//       'icon': Icons.cancel_rounded,
//     },
//     'Rejected_By_Manager': {
//       // ← was wrongly named Rejected_By_HR
//       'label': 'Rejected',
//       'color': Color(0xFFEF4444),
//       'bg': Color(0xFFFFF1F2),
//       'icon': Icons.cancel_rounded,
//     },
//     'Not_Recommended_By_TL': {
//       'label': 'Not Recommended',
//       'color': Color(0xFFF97316),
//       'bg': Color(0xFFFFF7ED),
//       'icon': Icons.thumb_down_alt_rounded,
//     },
//     'Pending_TL': {
//       'label': 'Pending TL',
//       'color': Color(0xFFF59E0B),
//       'bg': Color(0xFFFFFBEB),
//       'icon': Icons.schedule_rounded,
//     },
//     'Pending_Manager': {
//       // ← was Pending_HR (wrong)
//       'label': 'Pending Manager',
//       'color': Color(0xFFF59E0B),
//       'bg': Color(0xFFFFFBEB),
//       'icon': Icons.schedule_rounded,
//     },
//     'Cancelled': {
//       'label': 'Cancelled',
//       'color': Color(0xFF94A3B8),
//       'bg': Color(0xFFF1F5F9),
//       'icon': Icons.block_rounded,
//     },
//   };
//   String _fmtDate(DateTime d) {
//     const m = [
//       '',
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

//     return '${d.day} ${m[d.month]} ${d.year}';
//   }

//   String _fmtDateTime(String? s) {
//     if (s == null) return '-';
//     try {
//       final d = DateTime.parse(s);
//       const m = [
//         '',
//         'Jan',
//         'Feb',
//         'Mar',
//         'Apr',
//         'May',
//         'Jun',
//         'Jul',
//         'Aug',
//         'Sep',
//         'Oct',
//         'Nov',
//         'Dec',
//       ];
//       return '${d.day} ${m[d.month]} ${d.year}, '
//           '${d.hour.toString().padLeft(2, '0')}:'
//           '${d.minute.toString().padLeft(2, '0')}';
//     } catch (_) {
//       return s;
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     final leave = widget.leave;
//     final status = leave.status as String? ?? 'Pending_TL';
//     final cfg =
//         _statusCfg[status] ??
//         {
//           'label': status,
//           'color': _textLight,
//           'bg': const Color(0xFFF0F4FF),
//           'icon': Icons.help_outline,
//         };
//     final statusColor = cfg['color'] as Color;
//     final statusBg = cfg['bg'] as Color;
//     final statusLabel = cfg['label'] as String;
//     final statusIcon = cfg['icon'] as IconData;
//     final sameDay = leave.fromDate == leave.toDate;

//     return Padding(
//       padding: const EdgeInsets.only(bottom: 12),
//       child: AnimatedContainer(
//         duration: const Duration(milliseconds: 250),
//         decoration: BoxDecoration(
//           color: Colors.white,
//           borderRadius: BorderRadius.circular(16),
//           border: Border.all(
//             color: _expanded
//                 ? statusColor.withValues(alpha: 0.3)
//                 : const Color(0xFFE2E8F0),
//             width: _expanded ? 1.5 : 1,
//           ),
//           boxShadow: [
//             BoxShadow(
//               color: Colors.black.withValues(alpha: _expanded ? 0.08 : 0.04),
//               blurRadius: _expanded ? 16 : 8,
//               offset: const Offset(0, 3),
//             ),
//           ],
//         ),
//         clipBehavior: Clip.antiAlias,
//         child: Column(
//           children: [
//             Container(height: 3, color: statusColor),
//             InkWell(
//               onTap: () => setState(() => _expanded = !_expanded),
//               child: Padding(
//                 padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
//                 child: Row(
//                   children: [
//                     Container(
//                       width: 42,
//                       height: 42,
//                       decoration: BoxDecoration(
//                         color: const Color(0xFFEEF2FF),
//                         borderRadius: BorderRadius.circular(11),
//                       ),
//                       child: const Icon(
//                         Icons.event_note_rounded,
//                         color: _primary,
//                         size: 20,
//                       ),
//                     ),
//                     const SizedBox(width: 12),
//                     Expanded(
//                       child: Column(
//                         crossAxisAlignment: CrossAxisAlignment.start,
//                         children: [
//                           Text(
//                             '${leave.leaveType} Leave',
//                             style: const TextStyle(
//                               fontWeight: FontWeight.w700,
//                               fontSize: 14,
//                               color: _textDark,
//                               letterSpacing: 0.1,
//                             ),
//                           ),
//                           const SizedBox(height: 3),
//                           Row(
//                             children: [
//                               const Icon(
//                                 Icons.calendar_today_outlined,
//                                 size: 11,
//                                 color: _textLight,
//                               ),
//                               const SizedBox(width: 4),
//                               Flexible(
//                                 child: Text(
//                                   sameDay
//                                       ? _fmtDate(leave.fromDate)
//                                       : '${_fmtDate(leave.fromDate)}  →  ${_fmtDate(leave.toDate)}',
//                                   style: const TextStyle(
//                                     fontSize: 11,
//                                     color: _textMid,
//                                   ),
//                                   overflow: TextOverflow.ellipsis,
//                                 ),
//                               ),
//                               const SizedBox(width: 8),
//                               Container(
//                                 padding: const EdgeInsets.symmetric(
//                                   horizontal: 6,
//                                   vertical: 2,
//                                 ),
//                                 decoration: BoxDecoration(
//                                   color: _primary.withValues(alpha: 0.08),
//                                   borderRadius: BorderRadius.circular(5),
//                                 ),
//                                 child: Text(
//                                   '${leave.numberOfDays}d',
//                                   style: const TextStyle(
//                                     fontSize: 10,
//                                     fontWeight: FontWeight.w700,
//                                     color: _primary,
//                                   ),
//                                 ),
//                               ),
//                             ],
//                           ),
//                         ],
//                       ),
//                     ),
//                     Container(
//                       padding: const EdgeInsets.symmetric(
//                         horizontal: 9,
//                         vertical: 5,
//                       ),
//                       decoration: BoxDecoration(
//                         color: statusBg,
//                         borderRadius: BorderRadius.circular(20),
//                       ),
//                       child: Row(
//                         mainAxisSize: MainAxisSize.min,
//                         children: [
//                           Icon(statusIcon, size: 12, color: statusColor),
//                           const SizedBox(width: 4),
//                           Text(
//                             statusLabel,
//                             style: TextStyle(
//                               fontSize: 11,
//                               fontWeight: FontWeight.w700,
//                               color: statusColor,
//                             ),
//                           ),
//                         ],
//                       ),
//                     ),
//                     const SizedBox(width: 6),
//                     AnimatedRotation(
//                       turns: _expanded ? 0.5 : 0,
//                       duration: const Duration(milliseconds: 250),
//                       child: const Icon(
//                         Icons.keyboard_arrow_down_rounded,
//                         color: _textLight,
//                         size: 22,
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             ),
//             AnimatedCrossFade(
//               firstChild: const SizedBox.shrink(),
//               secondChild: _buildDetails(leave, statusColor),
//               crossFadeState: _expanded
//                   ? CrossFadeState.showSecond
//                   : CrossFadeState.showFirst,
//               duration: const Duration(milliseconds: 250),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildDetails(LeaveModel leave, Color statusColor) {
//     final status = leave.status;

//     final hasTLAction = leave.recommendedBy != null;
//     final hasManagerAction =
//         leave.approvedBy != null &&
//         leave.status != 'Not_Recommended_By_TL' &&
//         leave.status != 'Rejected_By_TL';

//     final hasRejection = (leave.rejectionReason ?? '').toString().isNotEmpty;

//     final hasCancelNote = (leave.cancelReason ?? '').toString().isNotEmpty;

//     final tlNotRecommended = status == 'Not_Recommended_By_TL';

//     return Column(
//       children: [
//         Divider(height: 1, thickness: 1, color: Colors.grey.shade100),
//         Padding(
//           padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               // Duration
//               _infoBlock(
//                 icon: Icons.today_rounded,
//                 iconColor: _primary,
//                 title: 'Duration',
//                 content:
//                     '${leave.numberOfDays} day${leave.numberOfDays == 1 ? '' : 's'}'
//                     '  ·  ${_fmtDate(leave.fromDate)}  →  ${_fmtDate(leave.toDate)}',
//               ),
//               const SizedBox(height: 10),

//               // Employee reason
//               _infoBlock(
//                 icon: Icons.person_outline_rounded,
//                 iconColor: _primary,
//                 title: 'Employee Reason',
//                 content: leave.reason ?? '-',
//               ),
//               const SizedBox(height: 10),

//               if (hasTLAction ||
//                   status == 'Rejected_By_TL' ||
//                   tlNotRecommended) ...[
//                 _actionBlock(
//                   icon: Icons.supervisor_account_rounded,
//                   title: 'Team Lead Review',
//                   person: hasTLAction
//                       ? widget.resolvePerson(leave.recommendedBy)
//                       : 'Team Lead',
//                   timestamp: _fmtDateTime(leave.recommendedAt),
//                   statusLabel: tlNotRecommended
//                       ? 'Not Recommended'
//                       : status == 'Rejected_By_TL'
//                       ? 'Rejected'
//                       : 'Recommended',
//                   statusColor: tlNotRecommended
//                       ? _orange
//                       : status == 'Rejected_By_TL'
//                       ? _red
//                       : _accent,
//                   remark:
//                       (tlNotRecommended || status == 'Rejected_By_TL') &&
//                           hasRejection
//                       ? leave.rejectionReason
//                       : null,
//                 ),
//                 const SizedBox(height: 10),
//               ],

//               // Manager / Admin
//               if (hasManagerAction) ...[
//                 _actionBlock(
//                   icon: Icons.admin_panel_settings_rounded,
//                   title: 'Manager / Admin Action',
//                   person: widget.resolvePerson(leave.approvedBy),
//                   timestamp: null,
//                   statusLabel: status == 'Approved' ? 'Approved' : 'Rejected',
//                   statusColor: status == 'Approved' ? _accent : _red,
//                   remark: status == 'Rejected_By_Manager' && hasRejection
//                       ? leave.rejectionReason
//                       : null,
//                 ),
//                 const SizedBox(height: 10),
//               ],

//               // Cancel reason
//               if (hasCancelNote) ...[
//                 _infoBlock(
//                   icon: Icons.block_rounded,
//                   iconColor: _textLight,
//                   title: 'Cancellation Reason',
//                   content: leave.cancelReason!,
//                   contentColor: _textMid,
//                 ),
//                 const SizedBox(height: 10),
//               ],

//               // Dates
//               Row(
//                 children: [
//                   Expanded(
//                     child: _miniDetail(
//                       'Applied',
//                       _fmtDateTime(leave.createdAt),
//                     ),
//                   ),
//                   Expanded(
//                     child: _miniDetail(
//                       'Last Updated',
//                       _fmtDateTime(leave.updatedAt),
//                     ),
//                   ),
//                 ],
//               ),

//               // Buttons
//               if (widget.onEdit != null || widget.onCancel != null) ...[
//                 const SizedBox(height: 12),
//                 Divider(height: 1, color: Colors.grey.shade100),
//                 const SizedBox(height: 10),
//                 Row(
//                   mainAxisAlignment: MainAxisAlignment.end,
//                   children: [
//                     if (widget.onEdit != null)
//                       _actionBtn(
//                         label: 'Edit',
//                         icon: Icons.edit_outlined,
//                         color: _primary,
//                         onTap: widget.onEdit!,
//                       ),
//                     if (widget.onEdit != null && widget.onCancel != null)
//                       const SizedBox(width: 8),
//                     if (widget.onCancel != null)
//                       _actionBtn(
//                         label: 'Cancel Leave',
//                         icon: Icons.close_rounded,
//                         color: _red,
//                         onTap: () => _showCancelDialog(context),
//                       ),
//                   ],
//                 ),
//               ],
//               const SizedBox(height: 6),
//             ],
//           ),
//         ),
//       ],
//     );
//   }

//   // ─── Shared sub-widgets ───────────────────────────────────────────────────
//   Widget _infoBlock({
//     required IconData icon,
//     required Color iconColor,
//     required String title,
//     required String content,
//     Color contentColor = const Color(0xFF0F172A),
//   }) {
//     return Container(
//       padding: const EdgeInsets.all(12),
//       decoration: BoxDecoration(
//         color: const Color(0xFFF8FAFC),
//         borderRadius: BorderRadius.circular(10),
//         border: Border.all(color: const Color(0xFFE2E8F0)),
//       ),
//       child: Row(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Icon(icon, size: 16, color: iconColor),
//           const SizedBox(width: 10),
//           Expanded(
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Text(
//                   title,
//                   style: const TextStyle(
//                     fontSize: 11,
//                     color: _textMid,
//                     fontWeight: FontWeight.w600,
//                     letterSpacing: 0.4,
//                   ),
//                 ),
//                 const SizedBox(height: 4),
//                 Text(
//                   content,
//                   style: TextStyle(
//                     fontSize: 13,
//                     color: contentColor,
//                     fontWeight: FontWeight.w500,
//                     height: 1.4,
//                   ),
//                 ),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _actionBlock({
//     required IconData icon,
//     required String title,
//     required String person,
//     String? timestamp,
//     required String statusLabel,
//     required Color statusColor,
//     String? remark,
//   }) {
//     return Container(
//       padding: const EdgeInsets.all(12),
//       decoration: BoxDecoration(
//         color: statusColor.withValues(alpha: 0.04),
//         borderRadius: BorderRadius.circular(10),
//         border: Border.all(color: statusColor.withValues(alpha: 0.2)),
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Row(
//             children: [
//               Icon(icon, size: 16, color: statusColor),
//               const SizedBox(width: 7),
//               Text(
//                 title,
//                 style: const TextStyle(
//                   fontSize: 11,
//                   color: _textMid,
//                   fontWeight: FontWeight.w600,
//                   letterSpacing: 0.4,
//                 ),
//               ),
//               const Spacer(),
//               Container(
//                 padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
//                 decoration: BoxDecoration(
//                   color: statusColor.withValues(alpha: 0.12),
//                   borderRadius: BorderRadius.circular(10),
//                 ),
//                 child: Text(
//                   statusLabel,
//                   style: TextStyle(
//                     fontSize: 11,
//                     fontWeight: FontWeight.w700,
//                     color: statusColor,
//                   ),
//                 ),
//               ),
//             ],
//           ),
//           const SizedBox(height: 8),
//           Row(
//             children: [
//               const Icon(Icons.person_rounded, size: 13, color: _textLight),
//               const SizedBox(width: 4),
//               Expanded(
//                 child: Text(
//                   person,
//                   style: const TextStyle(
//                     fontSize: 13,
//                     fontWeight: FontWeight.w600,
//                     color: _textDark,
//                   ),
//                   overflow: TextOverflow.ellipsis,
//                 ),
//               ),
//             ],
//           ),
//           if (timestamp != null) ...[
//             const SizedBox(height: 3),
//             Row(
//               children: [
//                 const Icon(
//                   Icons.access_time_rounded,
//                   size: 12,
//                   color: _textLight,
//                 ),
//                 const SizedBox(width: 4),
//                 Text(
//                   timestamp,
//                   style: const TextStyle(fontSize: 11, color: _textMid),
//                 ),
//               ],
//             ),
//           ],
//           // ── Reason block — shown for Not_Recommended and Rejected_By_TL ──
//           if (remark != null && remark.isNotEmpty) ...[
//             const SizedBox(height: 10),
//             Container(
//               width: double.infinity,
//               padding: const EdgeInsets.all(10),
//               decoration: BoxDecoration(
//                 color: statusColor.withValues(alpha: 0.06),
//                 borderRadius: BorderRadius.circular(8),
//                 border: Border.all(color: statusColor.withValues(alpha: 0.18)),
//               ),
//               child: Row(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   Icon(
//                     Icons.comment_outlined,
//                     size: 13,
//                     color: statusColor.withValues(alpha: 0.7),
//                   ),
//                   const SizedBox(width: 6),
//                   Expanded(
//                     child: Text(
//                       remark,
//                       style: TextStyle(
//                         fontSize: 12,
//                         color: statusColor,
//                         fontStyle: FontStyle.italic,
//                         height: 1.4,
//                       ),
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//           ],
//         ],
//       ),
//     );
//   }

//   Widget _miniDetail(String label, String value) {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Text(
//           label,
//           style: const TextStyle(
//             fontSize: 10,
//             color: _textLight,
//             fontWeight: FontWeight.w600,
//             letterSpacing: 0.5,
//           ),
//         ),
//         const SizedBox(height: 2),
//         Text(
//           value,
//           style: const TextStyle(
//             fontSize: 11,
//             color: _textDark,
//             fontWeight: FontWeight.w500,
//           ),
//         ),
//       ],
//     );
//   }

//   Widget _actionBtn({
//     required String label,
//     required IconData icon,
//     required Color color,
//     required VoidCallback onTap,
//   }) {
//     return GestureDetector(
//       onTap: onTap,
//       child: Container(
//         padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
//         decoration: BoxDecoration(
//           border: Border.all(color: color.withValues(alpha: 0.5)),
//           borderRadius: BorderRadius.circular(9),
//           color: color.withValues(alpha: 0.04),
//         ),
//         child: Row(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             Icon(icon, size: 14, color: color),
//             const SizedBox(width: 5),
//             Text(
//               label,
//               style: TextStyle(
//                 fontSize: 12,
//                 fontWeight: FontWeight.w700,
//                 color: color,
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   void _showCancelDialog(BuildContext context) {
//     final ctrl = TextEditingController();
//     showDialog(
//       context: context,
//       builder: (ctx) => AlertDialog(
//         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
//         title: const Text(
//           'Cancel Leave',
//           style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
//         ),
//         content: Column(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             const Text(
//               'Please provide a reason for cancellation.',
//               style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
//             ),
//             const SizedBox(height: 12),
//             TextField(
//               controller: ctrl,
//               maxLines: 3,
//               decoration: InputDecoration(
//                 hintText: 'Reason for cancellation...',
//                 filled: true,
//                 fillColor: const Color(0xFFF8FAFC),
//                 border: OutlineInputBorder(
//                   borderRadius: BorderRadius.circular(12),
//                   borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
//                 ),
//               ),
//             ),
//           ],
//         ),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.pop(ctx),
//             child: const Text(
//               'Close',
//               style: TextStyle(color: Color(0xFF64748B)),
//             ),
//           ),
//           FilledButton(
//             onPressed: () {
//               if (ctrl.text.trim().isEmpty) return;
//               Navigator.pop(ctx);
//               widget.onCancel!(ctrl.text.trim());
//             },
//             style: FilledButton.styleFrom(
//               backgroundColor: const Color(0xFFEF4444),
//               shape: RoundedRectangleBorder(
//                 borderRadius: BorderRadius.circular(10),
//               ),
//             ),
//             child: const Text('Confirm Cancel'),
//           ),
//         ],
//       ),
//     );
//   }
// }

// // ═══════════════════════════════════════════════════════════════════════════════
// // Apply Leave Bottom Sheet
// // ═══════════════════════════════════════════════════════════════════════════════
// class _ApplyLeaveSheet extends StatefulWidget {
//   final bool isEdit;
//   final String? initialLeaveType;
//   final DateTime? initialFromDate;
//   final DateTime? initialToDate;
//   final String? initialReason;
//   final List<Map<String, dynamic>> leaveBalances;
//   final bool compoffEligible;
//   final double compoffAvailable;
//   final Function(String, DateTime, DateTime, String, bool, String?) onSubmit;

//   const _ApplyLeaveSheet({
//     required this.isEdit,
//     this.initialLeaveType,
//     this.initialFromDate,
//     this.initialToDate,
//     this.initialReason,
//     required this.leaveBalances,
//     required this.compoffEligible,
//     required this.compoffAvailable,
//     required this.onSubmit,
//   });

//   @override
//   State<_ApplyLeaveSheet> createState() => _ApplyLeaveSheetState();
// }

// class _ApplyLeaveSheetState extends State<_ApplyLeaveSheet> {
//   static const Color _primary = Color(0xFF1A56DB);
//   static const Color _accent = Color(0xFF0E9F6E);
//   static const Color _red = Color(0xFFEF4444);
//   static const Color _textDark = Color(0xFF0F172A);
//   static const Color _textMid = Color(0xFF64748B);
//   static const Color _textLight = Color(0xFF94A3B8);
//   static const Color _surface = Color(0xFFF0F4FF);
//   static const Color _border = Color(0xFFE2E8F0);

//   late String? leaveType;
//   late DateTime? fromDate;
//   late DateTime? toDate;
//   late String reason;
//   bool _isHalfDay = false;
//   String? _halfDayPeriod;
//   int? _workingDays;
//   bool _loadingDays = false;

//   // Build available leave type options from balances
//   List<Map<String, dynamic>> get _availableTypes {
//     final types = <Map<String, dynamic>>[];

//     for (final b in widget.leaveBalances) {
//       final type = b['leave_type'] as String;
//       if (type == 'Comp-Off') continue;
//       final remaining = _parseDouble(b['remaining_days']); // ← safe parse
//       final halfAllowed = (b['half_day_allowed'] as int?) == 1;
//       types.add({
//         'type': type,
//         'remaining': remaining,
//         'half_day_allowed': halfAllowed,
//         'has_balance': remaining > 0,
//       });
//     }

//     if (widget.compoffEligible) {
//       types.add({
//         'type': 'Comp-Off',
//         'remaining': widget.compoffAvailable,
//         'half_day_allowed': true,
//         'has_balance': widget.compoffAvailable > 0,
//       });
//     }

//     return types;
//   }

//   Map<String, dynamic>? get _selectedTypeInfo {
//     if (leaveType == null) return null;
//     try {
//       return _availableTypes.firstWhere((t) => t['type'] == leaveType);
//     } catch (_) {
//       return null;
//     }
//   }

//   bool get _halfDayAllowed {
//     if (_isHalfDay) return true;
//     return _selectedTypeInfo?['half_day_allowed'] == true;
//   }

//   @override
//   void initState() {
//     super.initState();
//     leaveType = widget.initialLeaveType;
//     fromDate = widget.initialFromDate;
//     toDate = widget.initialToDate;
//     reason = widget.initialReason ?? '';
//   }

//   String _fmt(DateTime d) =>
//       '${d.day.toString().padLeft(2, '0')}/'
//       '${d.month.toString().padLeft(2, '0')}/'
//       '${d.year}';

//   Future<void> _updateWorkingDays() async {
//     if (fromDate == null || toDate == null || _isHalfDay) {
//       setState(() => _workingDays = null);
//       return;
//     }
//     setState(() => _loadingDays = true);
//     try {
//       final svc = LeaveService();
//       final wd = await svc.getWorkingDays(
//         fromDate!.toIso8601String().split('T')[0],
//         toDate!.toIso8601String().split('T')[0],
//       );
//       if (mounted) {
//         setState(() {
//           _workingDays = wd;
//           _loadingDays = false;
//         });
//       }
//     } catch (_) {
//       if (mounted) setState(() => _loadingDays = false);
//     }
//   }

//   void _snack(String msg) => ScaffoldMessenger.of(context).showSnackBar(
//     SnackBar(
//       content: Text(msg),
//       backgroundColor: _red,
//       behavior: SnackBarBehavior.floating,
//       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
//       margin: const EdgeInsets.all(16),
//     ),
//   );

//   @override
//   Widget build(BuildContext context) {
//     final r = Responsive.of(context);
//     final sheetWidth = r.isMobile ? double.infinity : 520.0;
//     final info = _selectedTypeInfo;
//     final remaining = (info?['remaining'] as double?) ?? 0.0;
//     final hasBalance = info?['has_balance'] == true;

//     return Center(
//       child: Container(
//         width: sheetWidth,
//         decoration: BoxDecoration(
//           color: Colors.white,
//           borderRadius: r.isMobile
//               ? const BorderRadius.vertical(top: Radius.circular(24))
//               : BorderRadius.circular(24),
//         ),
//         margin: r.isMobile ? EdgeInsets.zero : const EdgeInsets.all(32),
//         padding: EdgeInsets.only(
//           left: 20,
//           right: 20,
//           top: 16,
//           bottom: MediaQuery.of(context).viewInsets.bottom + 28,
//         ),
//         child: SingleChildScrollView(
//           child: Column(
//             mainAxisSize: MainAxisSize.min,
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               // Handle bar
//               Center(
//                 child: Container(
//                   width: 40,
//                   height: 4,
//                   decoration: BoxDecoration(
//                     color: _border,
//                     borderRadius: BorderRadius.circular(2),
//                   ),
//                 ),
//               ),
//               const SizedBox(height: 16),
//               Text(
//                 widget.isEdit ? 'Edit Leave Request' : 'Apply for Leave',
//                 style: const TextStyle(
//                   fontSize: 18,
//                   fontWeight: FontWeight.w800,
//                   color: _textDark,
//                 ),
//               ),
//               const SizedBox(height: 2),
//               const Text(
//                 'Fill in the details below',
//                 style: TextStyle(fontSize: 13, color: _textMid),
//               ),
//               const SizedBox(height: 20),

//               // ── Leave Type Dropdown ─────────────────────────────────────
//               DropdownButtonFormField<String>(
//                 value: leaveType,
//                 decoration: InputDecoration(
//                   labelText: 'Leave Type *',
//                   filled: true,
//                   fillColor: const Color(0xFFF8FAFC),
//                   border: OutlineInputBorder(
//                     borderRadius: BorderRadius.circular(12),
//                     borderSide: const BorderSide(color: _border),
//                   ),
//                   enabledBorder: OutlineInputBorder(
//                     borderRadius: BorderRadius.circular(12),
//                     borderSide: const BorderSide(color: _border),
//                   ),
//                 ),
//                 items: _availableTypes.map((t) {
//                   final type = t['type'] as String;
//                   final rem = (t['remaining'] as double).toStringAsFixed(1);
//                   final noBalance = t['has_balance'] == false;
//                   return DropdownMenuItem<String>(
//                     value: type,
//                     enabled: !noBalance,
//                     child: Row(
//                       mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                       children: [
//                         Text(
//                           _leaveTypeLabel(type),
//                           style: TextStyle(
//                             color: noBalance ? _textLight : _textDark,
//                             fontSize: 14,
//                           ),
//                         ),
//                         Container(
//                           padding: const EdgeInsets.symmetric(
//                             horizontal: 8,
//                             vertical: 2,
//                           ),
//                           decoration: BoxDecoration(
//                             color: noBalance
//                                 ? _textLight.withValues(alpha: 0.1)
//                                 : _primary.withValues(alpha: 0.1),
//                             borderRadius: BorderRadius.circular(10),
//                           ),
//                           child: Text(
//                             '$rem d',
//                             style: TextStyle(
//                               fontSize: 11,
//                               fontWeight: FontWeight.w700,
//                               color: noBalance ? _textLight : _primary,
//                             ),
//                           ),
//                         ),
//                       ],
//                     ),
//                   );
//                 }).toList(),
//                 onChanged: (v) => setState(() {
//                   leaveType = v;
//                   _isHalfDay = false;
//                   _halfDayPeriod = null;
//                 }),
//               ),

//               // Balance warning
//               if (leaveType != null && !hasBalance) ...[
//                 const SizedBox(height: 8),
//                 Container(
//                   padding: const EdgeInsets.all(10),
//                   decoration: BoxDecoration(
//                     color: _red.withValues(alpha: 0.06),
//                     borderRadius: BorderRadius.circular(10),
//                     border: Border.all(color: _red.withValues(alpha: 0.2)),
//                   ),
//                   child: Row(
//                     children: [
//                       const Icon(
//                         Icons.warning_amber_rounded,
//                         color: _red,
//                         size: 15,
//                       ),
//                       const SizedBox(width: 8),
//                       Text(
//                         'No balance remaining for ${_leaveTypeLabel(leaveType!)}',
//                         style: const TextStyle(
//                           fontSize: 12,
//                           color: _red,
//                           fontWeight: FontWeight.w500,
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//               ],

//               // Comp-off info banner
//               if (leaveType == 'Comp-Off') ...[
//                 const SizedBox(height: 8),
//                 Container(
//                   padding: const EdgeInsets.all(10),
//                   decoration: BoxDecoration(
//                     color: _accent.withValues(alpha: 0.06),
//                     borderRadius: BorderRadius.circular(10),
//                     border: Border.all(color: _accent.withValues(alpha: 0.2)),
//                   ),
//                   child: Row(
//                     children: [
//                       const Icon(
//                         Icons.info_outline_rounded,
//                         color: _accent,
//                         size: 15,
//                       ),
//                       const SizedBox(width: 8),
//                       Expanded(
//                         child: Text(
//                           'Available comp-off: ${widget.compoffAvailable.toStringAsFixed(1)} day(s). '
//                           'Earned by working on holidays/weekends.',
//                           style: const TextStyle(
//                             fontSize: 12,
//                             color: _accent,
//                             fontWeight: FontWeight.w500,
//                           ),
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//               ],

//               const SizedBox(height: 12),

//               // ── Half-day toggle (only if type allows it) ────────────────
//               if (leaveType != null && _halfDayAllowed) ...[
//                 Row(
//                   children: [
//                     Switch(
//                       value: _isHalfDay,
//                       activeColor: _primary,
//                       onChanged: (v) => setState(() {
//                         _isHalfDay = v;
//                         if (v) {
//                           toDate = fromDate;
//                           _workingDays = null;
//                         } else {
//                           _halfDayPeriod = null;
//                         }
//                       }),
//                     ),
//                     const Text(
//                       'Half Day',
//                       style: TextStyle(fontSize: 13, color: _textDark),
//                     ),
//                     if (_isHalfDay) ...[
//                       const SizedBox(width: 16),
//                       _periodChip('AM'),
//                       const SizedBox(width: 8),
//                       _periodChip('PM'),
//                     ],
//                   ],
//                 ),
//                 const SizedBox(height: 4),
//               ],

//               // ── Date Pickers ────────────────────────────────────────────
//               Row(
//                 children: [
//                   Expanded(
//                     child: _datePicker(
//                       label: 'From Date *',
//                       value: fromDate,
//                       onPick: () async {
//                         final p = await showDatePicker(
//                           context: context,
//                           initialDate: fromDate ?? DateTime.now(),
//                           firstDate: DateTime.now(),
//                           lastDate: DateTime(DateTime.now().year + 2),
//                           builder: (ctx, child) => Theme(
//                             data: Theme.of(ctx).copyWith(
//                               colorScheme: const ColorScheme.light(
//                                 primary: _primary,
//                               ),
//                             ),
//                             child: child!,
//                           ),
//                         );
//                         if (p != null) {
//                           setState(() {
//                             fromDate = p;
//                             toDate = _isHalfDay ? p : null;
//                             _workingDays = null;
//                           });
//                         }
//                       },
//                     ),
//                   ),
//                   const SizedBox(width: 12),
//                   Expanded(
//                     child: _datePicker(
//                       label: 'To Date *',
//                       value: toDate,
//                       enabled: fromDate != null && !_isHalfDay,
//                       onPick: (fromDate == null || _isHalfDay)
//                           ? null
//                           : () async {
//                               final p = await showDatePicker(
//                                 context: context,
//                                 initialDate: toDate ?? fromDate!,
//                                 firstDate: fromDate!,
//                                 lastDate: DateTime(DateTime.now().year + 2),
//                                 builder: (ctx, child) => Theme(
//                                   data: Theme.of(ctx).copyWith(
//                                     colorScheme: const ColorScheme.light(
//                                       primary: _primary,
//                                     ),
//                                   ),
//                                   child: child!,
//                                 ),
//                               );
//                               if (p != null) {
//                                 setState(() {
//                                   toDate = p;
//                                   _workingDays = null;
//                                 });
//                                 await _updateWorkingDays();
//                               }
//                             },
//                     ),
//                   ),
//                 ],
//               ),

//               // Days info
//               if (fromDate != null && toDate != null) ...[
//                 const SizedBox(height: 8),
//                 Row(
//                   mainAxisAlignment: MainAxisAlignment.end,
//                   children: [
//                     Container(
//                       padding: const EdgeInsets.symmetric(
//                         horizontal: 12,
//                         vertical: 5,
//                       ),
//                       decoration: BoxDecoration(
//                         color: _primary.withValues(alpha: 0.08),
//                         borderRadius: BorderRadius.circular(20),
//                       ),
//                       child: _loadingDays
//                           ? const SizedBox(
//                               width: 14,
//                               height: 14,
//                               child: CircularProgressIndicator(
//                                 strokeWidth: 2,
//                                 color: _primary,
//                               ),
//                             )
//                           : Text(
//                               _isHalfDay
//                                   ? '0.5 day (${_halfDayPeriod ?? '?'})'
//                                   : _workingDays != null
//                                   ? '$_workingDays working day(s)'
//                                   : '${toDate!.difference(fromDate!).inDays + 1} day(s)',
//                               style: const TextStyle(
//                                 fontSize: 12,
//                                 fontWeight: FontWeight.w700,
//                                 color: _primary,
//                               ),
//                             ),
//                     ),
//                   ],
//                 ),
//               ],

//               const SizedBox(height: 12),

//               // ── Reason ─────────────────────────────────────────────────
//               TextFormField(
//                 initialValue: reason,
//                 maxLines: 3,
//                 onChanged: (v) => reason = v,
//                 decoration: InputDecoration(
//                   labelText: 'Reason *',
//                   alignLabelWithHint: true,
//                   filled: true,
//                   fillColor: const Color(0xFFF8FAFC),
//                   border: OutlineInputBorder(
//                     borderRadius: BorderRadius.circular(12),
//                     borderSide: const BorderSide(color: _border),
//                   ),
//                   enabledBorder: OutlineInputBorder(
//                     borderRadius: BorderRadius.circular(12),
//                     borderSide: const BorderSide(color: _border),
//                   ),
//                 ),
//               ),
//               const SizedBox(height: 20),

//               // ── Submit ──────────────────────────────────────────────────
//               SizedBox(
//                 width: double.infinity,
//                 height: 50,
//                 child: FilledButton(
//                   style: FilledButton.styleFrom(
//                     backgroundColor: _primary,
//                     shape: RoundedRectangleBorder(
//                       borderRadius: BorderRadius.circular(14),
//                     ),
//                   ),
//                   onPressed: () {
//                     if (leaveType == null)
//                       return _snack('Please select leave type');
//                     if (fromDate == null)
//                       return _snack('Please select from date');
//                     if (toDate == null) return _snack('Please select to date');
//                     if (reason.trim().isEmpty)
//                       return _snack('Please enter a reason');
//                     if (_isHalfDay && _halfDayPeriod == null) {
//                       return _snack('Please select AM or PM for half day');
//                     }
//                     final info = _selectedTypeInfo;
//                     if (info != null && info['has_balance'] == false) {
//                       return _snack(
//                         'No balance remaining for ${_leaveTypeLabel(leaveType!)}',
//                       );
//                     }
//                     widget.onSubmit(
//                       leaveType!,
//                       fromDate!,
//                       toDate!,
//                       reason,
//                       _isHalfDay,
//                       _halfDayPeriod,
//                     );
//                   },
//                   child: Text(
//                     widget.isEdit ? 'UPDATE REQUEST' : 'SUBMIT REQUEST',
//                     style: const TextStyle(
//                       fontWeight: FontWeight.w800,
//                       letterSpacing: 0.6,
//                       fontSize: 14,
//                     ),
//                   ),
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }

//   Widget _periodChip(String period) => GestureDetector(
//     onTap: () => setState(() => _halfDayPeriod = period),
//     child: AnimatedContainer(
//       duration: const Duration(milliseconds: 150),
//       padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
//       decoration: BoxDecoration(
//         color: _halfDayPeriod == period ? _primary : _surface,
//         borderRadius: BorderRadius.circular(20),
//         border: Border.all(
//           color: _halfDayPeriod == period ? _primary : _border,
//         ),
//       ),
//       child: Text(
//         period,
//         style: TextStyle(
//           fontSize: 13,
//           fontWeight: FontWeight.w600,
//           color: _halfDayPeriod == period ? Colors.white : _textMid,
//         ),
//       ),
//     ),
//   );

//   Widget _datePicker({
//     required String label,
//     required DateTime? value,
//     bool enabled = true,
//     VoidCallback? onPick,
//   }) => GestureDetector(
//     onTap: enabled ? onPick : null,
//     child: Container(
//       padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
//       decoration: BoxDecoration(
//         color: enabled ? const Color(0xFFF8FAFC) : const Color(0xFFF1F5F9),
//         borderRadius: BorderRadius.circular(12),
//         border: Border.all(
//           color: value != null ? _primary.withValues(alpha: 0.4) : _border,
//         ),
//       ),
//       child: Row(
//         children: [
//           Icon(
//             Icons.calendar_today_rounded,
//             size: 15,
//             color: enabled ? _primary : _textLight,
//           ),
//           const SizedBox(width: 8),
//           Expanded(
//             child: Text(
//               value == null ? label : _fmt(value),
//               style: TextStyle(
//                 fontSize: 13,
//                 color: value == null ? _textLight : _textDark,
//                 fontWeight: value == null ? FontWeight.normal : FontWeight.w600,
//               ),
//               overflow: TextOverflow.ellipsis,
//             ),
//           ),
//         ],
//       ),
//     ),
//   );

//   String _leaveTypeLabel(String type) {
//     switch (type) {
//       case 'Casual':
//         return 'Casual Leave';
//       case 'Sick':
//         return 'Sick Leave';
//       case 'Paid':
//         return 'Paid Leave';
//       case 'Maternity':
//         return 'Maternity Leave';
//       case 'Paternity':
//         return 'Paternity Leave';
//       case 'Comp-Off':
//         return 'Comp-Off';
//       default:
//         return type;
//     }
//   }
// }

// double _parseDouble(dynamic v) {
//   if (v == null) return 0.0;
//   if (v is num) return v.toDouble();
//   return double.tryParse(v.toString()) ?? 0.0;
// }
import '../services/leave_service.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'responsive_utils.dart';
import '../models/leavemodel.dart';
import 'emp_holiday_view.dart';
import '../providers/api_client.dart';

class LeaveScreen extends StatefulWidget {
  final String employeeId;
  const LeaveScreen({super.key, required this.employeeId});

  @override
  State<LeaveScreen> createState() => _LeaveScreenState();
}

class _LeaveScreenState extends State<LeaveScreen>
    with SingleTickerProviderStateMixin {
  List<LeaveModel> leaves = [];
  bool loading = true;
  String? errorMessage;
  bool isHalfDay = false;
  String? halfDayPeriod;
  DateTime? fromDate;
  DateTime? toDate;
  String? leaveType;
  String? reason;
  int? editingLeaveId;
  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;
  List<Map<String, dynamic>> _leaveBalances = [];
  bool _compoffEligible = false;
  double _compoffAvailable = 0.0;
  final Map<String, String> _personNames = {};

  static const Color _primary = Color(0xFF1A56DB);
  static const Color _accent = Color(0xFF0E9F6E);
  static const Color _red = Color(0xFFEF4444);
  static const Color _surface = Color(0xFFF0F4FF);
  static const Color _textDark = Color(0xFF0F172A);
  static const Color _textMid = Color(0xFF64748B);
  static const Color _textLight = Color(0xFF94A3B8);
  static const Color _border = Color(0xFFE2E8F0);
  static const int _totalAllowed = 12;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    fetchLeaves();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> fetchLeaves() async {
    setState(() {
      loading = true;
      errorMessage = null;
    });
    try {
      final results = await Future.wait([
        ApiClient.get('/employees/${widget.employeeId}/leaves'),
        ApiClient.get(
          '/employees/${widget.employeeId}/leave-balance?year=${DateTime.now().year}',
        ),
        ApiClient.get('/employees/${widget.employeeId}/compoff-eligible'),
      ]);

      final leavesRes = results[0];
      if (leavesRes.statusCode == 200) {
        final data = jsonDecode(leavesRes.body);
        if (data['success'] == true) {
          final list = data['data'] as List;
          setState(() {
            leaves = list.map((e) => LeaveModel.fromPendingJson(e)).toList();
          });
          _animCtrl.forward(from: 0);
          final ids = <String>{};
          for (final l in list) {
            if (l['recommended_by'] != null)
              ids.add(l['recommended_by'].toString());
            if (l['approved_by'] != null) ids.add(l['approved_by'].toString());
          }
          for (final id in ids) _fetchPersonName(id);
        }
      }

      final balRes = results[1];
      if (balRes.statusCode == 200) {
        final data = jsonDecode(balRes.body);
        if (data['success'] == true) {
          setState(() {
            _leaveBalances = List<Map<String, dynamic>>.from(data['data']);
          });
        }
      }

      final compRes = results[2];
      if (compRes.statusCode == 200) {
        final data = jsonDecode(compRes.body);
        if (data['success'] == true) {
          setState(() {
            _compoffEligible = data['eligible'] as bool;
            _compoffAvailable = _parseDouble(data['available']);
          });
        }
      }
    } catch (e) {
      setState(
        () => errorMessage = 'Unable to load leaves. Check your connection.',
      );
    } finally {
      setState(() => loading = false);
    }
  }

  Future<void> _fetchPersonName(String id) async {
    if (_personNames.containsKey(id)) return;
    try {
      final res = await ApiClient.get('/employee-user/$id');
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        if (data['success'] == true) {
          final name = (data['full_name'] ?? '').toString().trim();
          final role = (data['role_name'] ?? '').toString().trim();
          final display = role.isNotEmpty ? '$name · $role' : name;
          if (mounted) {
            setState(
              () =>
                  _personNames[id] = display.isNotEmpty ? display : 'User #$id',
            );
          }
        }
      }
    } catch (_) {}
  }

  String _resolvePerson(dynamic id) {
    if (id == null) return '-';
    return _personNames[id.toString()] ?? 'Loading…';
  }

  Future<void> submitLeave() async {
    if (leaveType == null || fromDate == null || toDate == null) return;
    try {
      final body = <String, dynamic>{
        "leave_type": leaveType,
        "leave_start_date": fromDate!.toIso8601String().split('T')[0],
        "leave_end_date": toDate!.toIso8601String().split('T')[0],
        "reason": reason ?? "",
        "is_half_day": isHalfDay,
      };
      if (isHalfDay && halfDayPeriod != null) {
        body["half_day_period"] = halfDayPeriod;
      }
      final res = await ApiClient.post(
        '/employees/${widget.employeeId}/apply-leave',
        body,
      );
      final result = jsonDecode(res.body) as Map<String, dynamic>;
      if (result['success'] == true) {
        _showSnack(result['message'] as String, success: true);
        if (mounted) Navigator.pop(context);
        clearForm();
        fetchLeaves();
      } else {
        _showSnack(result['message']?.toString() ?? 'Submission failed');
      }
    } catch (e) {
      _showSnack('Error: $e');
    }
  }

  Future<void> cancelLeave(int id, String cancelReason) async {
    try {
      final res = await ApiClient.put('/leave/$id/cancel', {
        'cancel_reason': cancelReason,
      });
      final data = jsonDecode(res.body);
      _showSnack(data['message'], success: data['success'] == true);
      if (data['success'] == true) fetchLeaves();
    } catch (e) {
      _showSnack('Error cancelling: $e');
    }
  }

  void clearForm() {
    leaveType = null;
    reason = null;
    fromDate = null;
    toDate = null;
    editingLeaveId = null;
    isHalfDay = false;
    halfDayPeriod = null;
  }

  void _showSnack(String msg, {bool success = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              success
                  ? Icons.check_circle_rounded
                  : Icons.error_outline_rounded,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                msg,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        backgroundColor: success ? _accent : _red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  int get _pendingCount => leaves
      .where((e) => e.status == 'Pending_TL' || e.status == 'Pending_Manager')
      .length;

  @override
  Widget build(BuildContext context) {
    final r = Responsive.of(context);
    return Scaffold(
      backgroundColor: _surface,
      floatingActionButton: _buildFAB(r),
      body: loading
          ? const Center(child: CircularProgressIndicator(color: _primary))
          : errorMessage != null
          ? _buildError(r)
          : RefreshIndicator(
              onRefresh: fetchLeaves,
              color: _primary,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  _buildSliverAppBar(r),
                  SliverToBoxAdapter(child: _buildSummaryBar(r)),
                  // ── Comp-off balance banner (shown only when available > 0) ──
                  if (_compoffEligible && _compoffAvailable > 0)
                    SliverToBoxAdapter(
                      child: _CompoffBanner(available: _compoffAvailable),
                    ),
                  SliverToBoxAdapter(child: _buildHistoryHeader(r)),
                  if (leaves.isEmpty)
                    SliverToBoxAdapter(child: _buildEmpty(r))
                  else
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(r.hPad, 0, r.hPad, 100),
                      sliver: SliverToBoxAdapter(
                        child: Center(
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: r.contentMaxWidth,
                            ),
                            child: FadeTransition(
                              opacity: _fadeAnim,
                              child: r.useTwoColSections
                                  ? _buildLeaveGrid(r)
                                  : _buildLeaveList(r),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _buildLeaveGrid(Responsive r) {
    return LayoutBuilder(
      builder: (ctx, constraints) {
        const cols = 2;
        const gap = 12.0;
        final itemW = (constraints.maxWidth - gap * (cols - 1)) / cols;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: List.generate(
            leaves.length,
            (i) => SizedBox(
              width: itemW,
              child: _LeaveCard(
                leave: leaves[i],
                resolvePerson: _resolvePerson,
                onEdit: leaves[i].status == 'Pending_TL'
                    ? () => _openEdit(leaves[i])
                    : null,
                onCancel: leaves[i].status == 'Pending_TL'
                    ? (r) => cancelLeave(leaves[i].leaveId!, r)
                    : null,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLeaveList(Responsive r) {
    return Column(
      children: List.generate(
        leaves.length,
        (i) => _LeaveCard(
          leave: leaves[i],
          resolvePerson: _resolvePerson,
          onEdit: leaves[i].status == 'Pending_TL'
              ? () => _openEdit(leaves[i])
              : null,
          onCancel: leaves[i].status == 'Pending_TL'
              ? (r) => cancelLeave(leaves[i].leaveId!, r)
              : null,
        ),
      ),
    );
  }

  void _openEdit(LeaveModel leave) {
    editingLeaveId = leave.leaveId;
    leaveType = leave.leaveType;
    reason = leave.reason;
    fromDate = leave.fromDate;
    toDate = leave.toDate;
    _showApplySheet(context);
  }

  Widget _buildSliverAppBar(Responsive r) {
    return SliverToBoxAdapter(
      child: Container(
        color: _primary,
        padding: EdgeInsets.fromLTRB(
          r.hPad,
          MediaQuery.of(context).padding.top + 8,
          4,
          12,
        ),
        child: Row(
          children: [
            const Text(
              'My Leaves',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
            const Spacer(),
            IconButton(
              icon: const Icon(
                Icons.event_note_rounded,
                color: Colors.white,
                size: 20,
              ),
              tooltip: 'Holiday Calendar',
              padding: const EdgeInsets.all(8),
              constraints: const BoxConstraints(),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const EmpHolidayView()),
              ),
            ),
            IconButton(
              icon: const Icon(
                Icons.refresh_rounded,
                color: Colors.white,
                size: 20,
              ),
              padding: const EdgeInsets.all(8),
              constraints: const BoxConstraints(),
              onPressed: loading ? null : fetchLeaves,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryBar(Responsive r) {
    double totalAvailable = 0;
    double totalUsed = 0;
    double totalRemaining = 0;

    // Only Paid + Casual + Sick in summary totals (not Comp-Off)
    for (final b in _leaveBalances) {
      final t = b['leave_type'] as String;
      if (!['Paid', 'Casual', 'Sick'].contains(t)) continue;
      totalAvailable += _parseDouble(b['total_available']);
      totalUsed += _parseDouble(b['used_days']);
      totalRemaining += _parseDouble(b['remaining_days']);
    }

    return Container(
      color: _primary,
      padding: EdgeInsets.fromLTRB(r.hPad, 0, r.hPad, 20),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: r.contentMaxWidth),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
            ),
            child: Row(
              children: [
                _statItem(
                  totalAvailable.toStringAsFixed(0),
                  'Total',
                  Colors.white,
                ),
                _vDiv(),
                _statItem(
                  totalRemaining.toStringAsFixed(1),
                  'Remaining',
                  const Color(0xFF6EE7B7),
                ),
                _vDiv(),
                _statItem(
                  totalUsed.toStringAsFixed(1),
                  'Used',
                  const Color(0xFFFDE68A),
                ),
                _vDiv(),
                _statItem('$_pendingCount', 'Pending', Colors.white70),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _statItem(String v, String l, Color c) {
    return Expanded(
      child: Column(
        children: [
          Text(
            v,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: c,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            l,
            style: TextStyle(
              fontSize: 10,
              color: c.withValues(alpha: 0.75),
              letterSpacing: 0.4,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _vDiv() => Container(
    width: 1,
    height: 28,
    color: Colors.white.withValues(alpha: 0.2),
  );

  Widget _buildHistoryHeader(Responsive r) {
    return Padding(
      padding: EdgeInsets.fromLTRB(r.hPad, 20, r.hPad, 12),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: r.contentMaxWidth),
          child: const Text(
            'Leave History',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F172A),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFAB(Responsive r) {
    return FloatingActionButton.extended(
      backgroundColor: _primary,
      elevation: 4,
      onPressed: () {
        clearForm();
        _showApplySheet(context);
      },
      icon: const Icon(Icons.add_rounded, color: Colors.white, size: 20),
      label: const Text(
        'Apply Leave',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 14,
          letterSpacing: 0.3,
        ),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    );
  }

  Widget _buildError(Responsive r) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: r.hPad),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: r.contentMaxWidth),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: _red.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.wifi_off_rounded,
                  color: _red,
                  size: 40,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Failed to load leaves',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: _textDark,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: _textMid, fontSize: 13),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: fetchLeaves,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Try Again'),
                style: FilledButton.styleFrom(
                  backgroundColor: _primary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmpty(Responsive r) {
    return Padding(
      padding: EdgeInsets.fromLTRB(r.hPad, 60, r.hPad, 60),
      child: Center(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: _primary.withValues(alpha: 0.06),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.beach_access_rounded,
                size: 44,
                color: _textLight,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'No leaves applied yet',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: _textDark,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Tap Apply Leave to submit a request',
              style: TextStyle(color: _textMid, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  void _showApplySheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ApplyLeaveSheet(
        isEdit: editingLeaveId != null,
        initialLeaveType: leaveType,
        initialFromDate: fromDate,
        initialToDate: toDate,
        initialReason: reason,
        leaveBalances: _leaveBalances,
        compoffEligible: _compoffEligible,
        compoffAvailable: _compoffAvailable,
        onSubmit: (lType, fDate, tDate, r, halfDay, halfPeriod) {
          leaveType = lType;
          fromDate = fDate;
          toDate = tDate;
          reason = r;
          isHalfDay = halfDay;
          halfDayPeriod = halfPeriod;
          submitLeave();
        },
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Comp-off balance banner
// ═══════════════════════════════════════════════════════════════════════════════
class _CompoffBanner extends StatelessWidget {
  final double available;
  const _CompoffBanner({required this.available});

  @override
  Widget build(BuildContext context) {
    final days = available % 1 == 0
        ? available.toInt().toString()
        : available.toStringAsFixed(1);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF86EFAC)),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: const Color(0xFFDCFCE7),
              borderRadius: BorderRadius.circular(9),
            ),
            child: const Icon(
              Icons.work_history_rounded,
              color: Color(0xFF16A34A),
              size: 17,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(
                  fontSize: 12.5,
                  color: Color(0xFF15803D),
                  height: 1.45,
                ),
                children: [
                  TextSpan(
                    text:
                        '$days comp-off day${available == 1.0 ? '' : 's'} available ',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const TextSpan(
                    text: '— select Comp-Off in Apply Leave to use it.',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Leave Card
// ═══════════════════════════════════════════════════════════════════════════════
class _LeaveCard extends StatefulWidget {
  final LeaveModel leave;
  final String Function(dynamic) resolvePerson;
  final VoidCallback? onEdit;
  final Function(String)? onCancel;

  const _LeaveCard({
    required this.leave,
    required this.resolvePerson,
    this.onEdit,
    this.onCancel,
  });

  @override
  State<_LeaveCard> createState() => _LeaveCardState();
}

class _LeaveCardState extends State<_LeaveCard> {
  bool _expanded = false;

  static const Color _primary = Color(0xFF1A56DB);
  static const Color _accent = Color(0xFF0E9F6E);
  static const Color _red = Color(0xFFEF4444);
  static const Color _orange = Color(0xFFF97316);
  static const Color _textDark = Color(0xFF0F172A);
  static const Color _textMid = Color(0xFF64748B);
  static const Color _textLight = Color(0xFF94A3B8);

  static const _statusCfg = <String, Map<String, dynamic>>{
    'Approved': {
      'label': 'Approved',
      'color': Color(0xFF0E9F6E),
      'bg': Color(0xFFECFDF5),
      'icon': Icons.check_circle_rounded,
    },
    'Rejected_By_TL': {
      'label': 'Rejected by TL',
      'color': Color(0xFFEF4444),
      'bg': Color(0xFFFFF1F2),
      'icon': Icons.cancel_rounded,
    },
    'Rejected_By_Manager': {
      'label': 'Rejected',
      'color': Color(0xFFEF4444),
      'bg': Color(0xFFFFF1F2),
      'icon': Icons.cancel_rounded,
    },
    'Not_Recommended_By_TL': {
      'label': 'Not Recommended',
      'color': Color(0xFFF97316),
      'bg': Color(0xFFFFF7ED),
      'icon': Icons.thumb_down_alt_rounded,
    },
    'Pending_TL': {
      'label': 'Pending TL',
      'color': Color(0xFFF59E0B),
      'bg': Color(0xFFFFFBEB),
      'icon': Icons.schedule_rounded,
    },
    'Pending_Manager': {
      'label': 'Pending Manager',
      'color': Color(0xFFF59E0B),
      'bg': Color(0xFFFFFBEB),
      'icon': Icons.schedule_rounded,
    },
    'Cancelled': {
      'label': 'Cancelled',
      'color': Color(0xFF94A3B8),
      'bg': Color(0xFFF1F5F9),
      'icon': Icons.block_rounded,
    },
  };

  String _fmtDate(DateTime d) {
    const m = [
      '',
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
    return '${d.day} ${m[d.month]} ${d.year}';
  }

  String _fmtDateTime(String? s) {
    if (s == null) return '-';
    try {
      final d = DateTime.parse(s);
      const m = [
        '',
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
      return '${d.day} ${m[d.month]} ${d.year}, '
          '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return s;
    }
  }

  @override
  Widget build(BuildContext context) {
    final leave = widget.leave;
    final status = leave.status as String? ?? 'Pending_TL';
    final cfg =
        _statusCfg[status] ??
        {
          'label': status,
          'color': _textLight,
          'bg': const Color(0xFFF0F4FF),
          'icon': Icons.help_outline,
        };
    final statusColor = cfg['color'] as Color;
    final statusBg = cfg['bg'] as Color;
    final statusLabel = cfg['label'] as String;
    final statusIcon = cfg['icon'] as IconData;
    final sameDay = leave.fromDate == leave.toDate;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _expanded
                ? statusColor.withValues(alpha: 0.3)
                : const Color(0xFFE2E8F0),
            width: _expanded ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: _expanded ? 0.08 : 0.04),
              blurRadius: _expanded ? 16 : 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            Container(height: 3, color: statusColor),
            InkWell(
              onTap: () => setState(() => _expanded = !_expanded),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEEF2FF),
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: const Icon(
                        Icons.event_note_rounded,
                        color: _primary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${leave.leaveType} Leave',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: _textDark,
                              letterSpacing: 0.1,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              const Icon(
                                Icons.calendar_today_outlined,
                                size: 11,
                                color: _textLight,
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  sameDay
                                      ? _fmtDate(leave.fromDate)
                                      : '${_fmtDate(leave.fromDate)}  →  ${_fmtDate(leave.toDate)}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: _textMid,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: _primary.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(5),
                                ),
                                child: Text(
                                  '${leave.numberOfDays}d',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: _primary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: statusBg,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(statusIcon, size: 12, color: statusColor),
                          const SizedBox(width: 4),
                          Text(
                            statusLabel,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: statusColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    AnimatedRotation(
                      turns: _expanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 250),
                      child: const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: _textLight,
                        size: 22,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            AnimatedCrossFade(
              firstChild: const SizedBox.shrink(),
              secondChild: _buildDetails(leave, statusColor),
              crossFadeState: _expanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 250),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetails(LeaveModel leave, Color statusColor) {
    final status = leave.status;
    final hasTLAction = leave.recommendedBy != null;
    final hasManagerAction =
        leave.approvedBy != null &&
        leave.status != 'Not_Recommended_By_TL' &&
        leave.status != 'Rejected_By_TL';
    final hasRejection = (leave.rejectionReason ?? '').toString().isNotEmpty;
    final hasCancelNote = (leave.cancelReason ?? '').toString().isNotEmpty;
    final tlNotRecommended = status == 'Not_Recommended_By_TL';

    return Column(
      children: [
        Divider(height: 1, thickness: 1, color: Colors.grey.shade100),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _infoBlock(
                icon: Icons.today_rounded,
                iconColor: _primary,
                title: 'Duration',
                content:
                    '${leave.numberOfDays} day${leave.numberOfDays == 1 ? '' : 's'}'
                    '  ·  ${_fmtDate(leave.fromDate)}  →  ${_fmtDate(leave.toDate)}',
              ),
              const SizedBox(height: 10),
              _infoBlock(
                icon: Icons.person_outline_rounded,
                iconColor: _primary,
                title: 'Employee Reason',
                content: leave.reason ?? '-',
              ),
              const SizedBox(height: 10),
              if (hasTLAction ||
                  status == 'Rejected_By_TL' ||
                  tlNotRecommended) ...[
                _actionBlock(
                  icon: Icons.supervisor_account_rounded,
                  title: 'Team Lead Review',
                  person: hasTLAction
                      ? widget.resolvePerson(leave.recommendedBy)
                      : 'Team Lead',
                  timestamp: _fmtDateTime(leave.recommendedAt),
                  statusLabel: tlNotRecommended
                      ? 'Not Recommended'
                      : status == 'Rejected_By_TL'
                      ? 'Rejected'
                      : 'Recommended',
                  statusColor: tlNotRecommended
                      ? _orange
                      : status == 'Rejected_By_TL'
                      ? _red
                      : _accent,
                  remark:
                      (tlNotRecommended || status == 'Rejected_By_TL') &&
                          hasRejection
                      ? leave.rejectionReason
                      : null,
                ),
                const SizedBox(height: 10),
              ],
              if (hasManagerAction) ...[
                _actionBlock(
                  icon: Icons.admin_panel_settings_rounded,
                  title: 'Manager / Admin Action',
                  person: widget.resolvePerson(leave.approvedBy),
                  timestamp: null,
                  statusLabel: status == 'Approved' ? 'Approved' : 'Rejected',
                  statusColor: status == 'Approved' ? _accent : _red,
                  remark: status == 'Rejected_By_Manager' && hasRejection
                      ? leave.rejectionReason
                      : null,
                ),
                const SizedBox(height: 10),
              ],
              if (hasCancelNote) ...[
                _infoBlock(
                  icon: Icons.block_rounded,
                  iconColor: _textLight,
                  title: 'Cancellation Reason',
                  content: leave.cancelReason!,
                  contentColor: _textMid,
                ),
                const SizedBox(height: 10),
              ],
              Row(
                children: [
                  Expanded(
                    child: _miniDetail(
                      'Applied',
                      _fmtDateTime(leave.createdAt),
                    ),
                  ),
                  Expanded(
                    child: _miniDetail(
                      'Last Updated',
                      _fmtDateTime(leave.updatedAt),
                    ),
                  ),
                ],
              ),
              if (widget.onEdit != null || widget.onCancel != null) ...[
                const SizedBox(height: 12),
                Divider(height: 1, color: Colors.grey.shade100),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (widget.onEdit != null)
                      _actionBtn(
                        label: 'Edit',
                        icon: Icons.edit_outlined,
                        color: _primary,
                        onTap: widget.onEdit!,
                      ),
                    if (widget.onEdit != null && widget.onCancel != null)
                      const SizedBox(width: 8),
                    if (widget.onCancel != null)
                      _actionBtn(
                        label: 'Cancel Leave',
                        icon: Icons.close_rounded,
                        color: _red,
                        onTap: () => _showCancelDialog(context),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 6),
            ],
          ),
        ),
      ],
    );
  }

  Widget _infoBlock({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String content,
    Color contentColor = const Color(0xFF0F172A),
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: iconColor),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 11,
                    color: _textMid,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  content,
                  style: TextStyle(
                    fontSize: 13,
                    color: contentColor,
                    fontWeight: FontWeight.w500,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionBlock({
    required IconData icon,
    required String title,
    required String person,
    String? timestamp,
    required String statusLabel,
    required Color statusColor,
    String? remark,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: statusColor.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: statusColor),
              const SizedBox(width: 7),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 11,
                  color: _textMid,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.4,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.person_rounded, size: 13, color: _textLight),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  person,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _textDark,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          if (timestamp != null) ...[
            const SizedBox(height: 3),
            Row(
              children: [
                const Icon(
                  Icons.access_time_rounded,
                  size: 12,
                  color: _textLight,
                ),
                const SizedBox(width: 4),
                Text(
                  timestamp,
                  style: const TextStyle(fontSize: 11, color: _textMid),
                ),
              ],
            ),
          ],
          if (remark != null && remark.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: statusColor.withValues(alpha: 0.18)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.comment_outlined,
                    size: 13,
                    color: statusColor.withValues(alpha: 0.7),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      remark,
                      style: TextStyle(
                        fontSize: 12,
                        color: statusColor,
                        fontStyle: FontStyle.italic,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _miniDetail(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            color: _textLight,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 11,
            color: _textDark,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _actionBtn({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: color.withValues(alpha: 0.5)),
          borderRadius: BorderRadius.circular(9),
          color: color.withValues(alpha: 0.04),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCancelDialog(BuildContext context) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Cancel Leave',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Please provide a reason for cancellation.',
              style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Reason for cancellation...',
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Close',
              style: TextStyle(color: Color(0xFF64748B)),
            ),
          ),
          FilledButton(
            onPressed: () {
              if (ctrl.text.trim().isEmpty) return;
              Navigator.pop(ctx);
              widget.onCancel!(ctrl.text.trim());
            },
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Confirm Cancel'),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Apply Leave Bottom Sheet
// ═══════════════════════════════════════════════════════════════════════════════
class _ApplyLeaveSheet extends StatefulWidget {
  final bool isEdit;
  final String? initialLeaveType;
  final DateTime? initialFromDate;
  final DateTime? initialToDate;
  final String? initialReason;
  final List<Map<String, dynamic>> leaveBalances;
  final bool compoffEligible;
  final double compoffAvailable;
  final Function(String, DateTime, DateTime, String, bool, String?) onSubmit;

  const _ApplyLeaveSheet({
    required this.isEdit,
    this.initialLeaveType,
    this.initialFromDate,
    this.initialToDate,
    this.initialReason,
    required this.leaveBalances,
    required this.compoffEligible,
    required this.compoffAvailable,
    required this.onSubmit,
  });

  @override
  State<_ApplyLeaveSheet> createState() => _ApplyLeaveSheetState();
}

class _ApplyLeaveSheetState extends State<_ApplyLeaveSheet> {
  static const Color _primary = Color(0xFF1A56DB);
  static const Color _accent = Color(0xFF0E9F6E);
  static const Color _red = Color(0xFFEF4444);
  static const Color _purple = Color(0xFF7C3AED);
  static const Color _textDark = Color(0xFF0F172A);
  static const Color _textMid = Color(0xFF64748B);
  static const Color _textLight = Color(0xFF94A3B8);
  static const Color _surface = Color(0xFFF0F4FF);
  static const Color _border = Color(0xFFE2E8F0);

  // ── Fixed 3 types + comp-off if available ──────────────────────────────────
  static const _fixedTypes = [
    {'type': 'Paid', 'label': 'Paid Leave', 'icon': Icons.paid_rounded},
    {
      'type': 'Casual',
      'label': 'Casual Leave',
      'icon': Icons.beach_access_rounded,
    },
    {
      'type': 'Sick',
      'label': 'Sick Leave',
      'icon': Icons.local_hospital_rounded,
    },
  ];

  late String? leaveType;
  late DateTime? fromDate;
  late DateTime? toDate;
  late String reason;
  bool _isHalfDay = false;
  String? _halfDayPeriod;
  int? _workingDays;
  bool _loadingDays = false;

  // Build the 3+1 list with balances merged in
  List<Map<String, dynamic>> get _leaveOptions {
    final options = <Map<String, dynamic>>[];

    for (final ft in _fixedTypes) {
      final type = ft['type'] as String;
      // find balance for this type
      final bal = widget.leaveBalances.firstWhere(
        (b) => b['leave_type'] == type,
        orElse: () => <String, dynamic>{},
      );
      final remaining = _parseDouble(bal['remaining_days']);
      final halfAllowed = (bal['half_day_allowed'] as int?) == 1;
      options.add({
        'type': type,
        'label': ft['label'] as String,
        'icon': ft['icon'] as IconData,
        'remaining': remaining,
        'half_day_allowed': halfAllowed,
        'has_balance': remaining > 0,
        'is_compoff': false,
      });
    }

    // Comp-Off only if available > 0
    if (widget.compoffEligible && widget.compoffAvailable > 0) {
      options.add({
        'type': 'Comp-Off',
        'label': 'Comp-Off',
        'icon': Icons.work_history_rounded,
        'remaining': widget.compoffAvailable,
        'half_day_allowed': true,
        'has_balance': true,
        'is_compoff': true,
      });
    }

    return options;
  }

  Map<String, dynamic>? get _selectedTypeInfo {
    if (leaveType == null) return null;
    try {
      return _leaveOptions.firstWhere((t) => t['type'] == leaveType);
    } catch (_) {
      return null;
    }
  }

  bool get _halfDayAllowed => _selectedTypeInfo?['half_day_allowed'] == true;

  @override
  void initState() {
    super.initState();
    leaveType = widget.initialLeaveType;
    fromDate = widget.initialFromDate;
    toDate = widget.initialToDate;
    reason = widget.initialReason ?? '';
  }

  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  Future<void> _updateWorkingDays() async {
    if (fromDate == null || toDate == null || _isHalfDay) {
      setState(() => _workingDays = null);
      return;
    }
    setState(() => _loadingDays = true);
    try {
      final svc = LeaveService();
      final wd = await svc.getWorkingDays(
        fromDate!.toIso8601String().split('T')[0],
        toDate!.toIso8601String().split('T')[0],
      );
      if (mounted)
        setState(() {
          _workingDays = wd;
          _loadingDays = false;
        });
    } catch (_) {
      if (mounted) setState(() => _loadingDays = false);
    }
  }

  void _snack(String msg) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(msg),
      backgroundColor: _red,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.all(16),
    ),
  );

  Color _typeColor(String type) {
    switch (type) {
      case 'Paid':
        return _accent;
      case 'Casual':
        return _primary;
      case 'Sick':
        return _red;
      case 'Comp-Off':
        return _purple;
      default:
        return _textMid;
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = Responsive.of(context);
    final sheetWidth = r.isMobile ? double.infinity : 520.0;
    final info = _selectedTypeInfo;
    final remaining = (info?['remaining'] as double?) ?? 0.0;
    final hasBalance = info?['has_balance'] == true;
    final isCompoff = info?['is_compoff'] == true;

    return Center(
      child: Container(
        width: sheetWidth,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: r.isMobile
              ? const BorderRadius.vertical(top: Radius.circular(24))
              : BorderRadius.circular(24),
        ),
        margin: r.isMobile ? EdgeInsets.zero : const EdgeInsets.all(32),
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 28,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: _border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                widget.isEdit ? 'Edit Leave Request' : 'Apply for Leave',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: _textDark,
                ),
              ),
              const SizedBox(height: 2),
              const Text(
                'Fill in the details below',
                style: TextStyle(fontSize: 13, color: _textMid),
              ),
              const SizedBox(height: 20),

              // ── Leave type selector — card grid ────────────────────────────
              const Text(
                'Leave Type',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _textMid,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _leaveOptions.map((opt) {
                  final type = opt['type'] as String;
                  final label = opt['label'] as String;
                  final icon = opt['icon'] as IconData;
                  final rem = (opt['remaining'] as double);
                  final noBalance = opt['has_balance'] == false;
                  final selected = leaveType == type;
                  final color = _typeColor(type);

                  return GestureDetector(
                    onTap: noBalance
                        ? null
                        : () => setState(() {
                            leaveType = type;
                            _isHalfDay = false;
                            _halfDayPeriod = null;
                            _workingDays = null;
                          }),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: (MediaQuery.of(context).size.width - 40 - 8) / 2,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: selected
                            ? color.withValues(alpha: 0.08)
                            : noBalance
                            ? const Color(0xFFF8FAFC)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: selected
                              ? color
                              : noBalance
                              ? _border
                              : _border,
                          width: selected ? 1.8 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              color: selected
                                  ? color.withValues(alpha: 0.12)
                                  : noBalance
                                  ? const Color(0xFFF1F5F9)
                                  : color.withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              icon,
                              size: 15,
                              color: noBalance ? _textLight : color,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  label,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: noBalance ? _textLight : _textDark,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  noBalance
                                      ? 'No balance'
                                      : '${rem % 1 == 0 ? rem.toInt() : rem.toStringAsFixed(1)} day${rem == 1.0 ? '' : 's'}',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: noBalance ? _textLight : color,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (selected)
                            Icon(
                              Icons.check_circle_rounded,
                              size: 15,
                              color: color,
                            ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),

              // Comp-off info line when selected
              if (isCompoff) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _purple.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _purple.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.info_outline_rounded,
                        color: _purple,
                        size: 14,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Using ${widget.compoffAvailable.toStringAsFixed(1)} comp-off day(s) earned from working on holidays/weekends.',
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: _purple,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // No balance warning
              if (leaveType != null && !hasBalance) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _red.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _red.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.warning_amber_rounded,
                        color: _red,
                        size: 15,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'No balance remaining for $leaveType leave',
                        style: const TextStyle(
                          fontSize: 12,
                          color: _red,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 14),

              // ── Half-day toggle ─────────────────────────────────────────
              if (leaveType != null && _halfDayAllowed) ...[
                Row(
                  children: [
                    Switch(
                      value: _isHalfDay,
                      activeColor: _primary,
                      onChanged: (v) => setState(() {
                        _isHalfDay = v;
                        if (v) {
                          toDate = fromDate;
                          _workingDays = null;
                        } else {
                          _halfDayPeriod = null;
                        }
                      }),
                    ),
                    const Text(
                      'Half Day',
                      style: TextStyle(fontSize: 13, color: _textDark),
                    ),
                    if (_isHalfDay) ...[
                      const SizedBox(width: 16),
                      _periodChip('AM'),
                      const SizedBox(width: 8),
                      _periodChip('PM'),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
              ],

              // ── Date pickers ────────────────────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: _datePicker(
                      label: 'From Date *',
                      value: fromDate,
                      onPick: () async {
                        final p = await showDatePicker(
                          context: context,
                          initialDate: fromDate ?? DateTime.now(),
                          firstDate: DateTime.now(),
                          lastDate: DateTime(DateTime.now().year + 2),
                          builder: (ctx, child) => Theme(
                            data: Theme.of(ctx).copyWith(
                              colorScheme: const ColorScheme.light(
                                primary: _primary,
                              ),
                            ),
                            child: child!,
                          ),
                        );
                        if (p != null)
                          setState(() {
                            fromDate = p;
                            toDate = _isHalfDay ? p : null;
                            _workingDays = null;
                          });
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _datePicker(
                      label: 'To Date *',
                      value: toDate,
                      enabled: fromDate != null && !_isHalfDay,
                      onPick: (fromDate == null || _isHalfDay)
                          ? null
                          : () async {
                              final p = await showDatePicker(
                                context: context,
                                initialDate: toDate ?? fromDate!,
                                firstDate: fromDate!,
                                lastDate: DateTime(DateTime.now().year + 2),
                                builder: (ctx, child) => Theme(
                                  data: Theme.of(ctx).copyWith(
                                    colorScheme: const ColorScheme.light(
                                      primary: _primary,
                                    ),
                                  ),
                                  child: child!,
                                ),
                              );
                              if (p != null) {
                                setState(() {
                                  toDate = p;
                                  _workingDays = null;
                                });
                                await _updateWorkingDays();
                              }
                            },
                    ),
                  ),
                ],
              ),

              if (fromDate != null && toDate != null) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: _primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: _loadingDays
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: _primary,
                            ),
                          )
                        : Text(
                            _isHalfDay
                                ? '0.5 day (${_halfDayPeriod ?? '?'})'
                                : _workingDays != null
                                ? '$_workingDays working day(s)'
                                : '${toDate!.difference(fromDate!).inDays + 1} day(s)',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: _primary,
                            ),
                          ),
                  ),
                ),
              ],

              const SizedBox(height: 12),

              // ── Reason ──────────────────────────────────────────────────
              TextFormField(
                initialValue: reason,
                maxLines: 3,
                onChanged: (v) => reason = v,
                decoration: InputDecoration(
                  labelText: 'Reason *',
                  alignLabelWithHint: true,
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _border),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // ── Submit ──────────────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: _primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () {
                    if (leaveType == null)
                      return _snack('Please select a leave type');
                    if (fromDate == null)
                      return _snack('Please select from date');
                    if (toDate == null) return _snack('Please select to date');
                    if (reason.trim().isEmpty)
                      return _snack('Please enter a reason');
                    if (_isHalfDay && _halfDayPeriod == null)
                      return _snack('Please select AM or PM');
                    if (_selectedTypeInfo?['has_balance'] == false) {
                      return _snack(
                        'No balance remaining for $leaveType leave',
                      );
                    }
                    widget.onSubmit(
                      leaveType!,
                      fromDate!,
                      toDate!,
                      reason,
                      _isHalfDay,
                      _halfDayPeriod,
                    );
                  },
                  child: Text(
                    widget.isEdit ? 'UPDATE REQUEST' : 'SUBMIT REQUEST',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.6,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _periodChip(String period) => GestureDetector(
    onTap: () => setState(() => _halfDayPeriod = period),
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
      decoration: BoxDecoration(
        color: _halfDayPeriod == period ? _primary : _surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _halfDayPeriod == period ? _primary : _border,
        ),
      ),
      child: Text(
        period,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: _halfDayPeriod == period ? Colors.white : _textMid,
        ),
      ),
    ),
  );

  Widget _datePicker({
    required String label,
    required DateTime? value,
    bool enabled = true,
    VoidCallback? onPick,
  }) => GestureDetector(
    onTap: enabled ? onPick : null,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: enabled ? const Color(0xFFF8FAFC) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: value != null ? _primary.withValues(alpha: 0.4) : _border,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.calendar_today_rounded,
            size: 15,
            color: enabled ? _primary : _textLight,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value == null ? label : _fmt(value),
              style: TextStyle(
                fontSize: 13,
                color: value == null ? _textLight : _textDark,
                fontWeight: value == null ? FontWeight.normal : FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    ),
  );
}

double _parseDouble(dynamic v) {
  if (v == null) return 0.0;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString()) ?? 0.0;
}
