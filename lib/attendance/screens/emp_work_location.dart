// // import 'package:intl/intl.dart';
// // import 'package:flutter/material.dart';
// // import '../models/asign_location.dart';
// // import '../services/asign_location_services.dart';
// // import 'responsive_utils.dart';

// // class EmployeeAssignmentsScreen extends StatefulWidget {
// //   final int empId;
// //   const EmployeeAssignmentsScreen({super.key, required this.empId});

// //   @override
// //   State<EmployeeAssignmentsScreen> createState() =>
// //       _EmployeeAssignmentsScreenState();
// // }

// // class _EmployeeAssignmentsScreenState extends State<EmployeeAssignmentsScreen>
// //     with SingleTickerProviderStateMixin {
// //   List<AssignLocationModel> assignments = [];
// //   bool isLoading = true;
// //   String? errorMessage;

// //   late AnimationController _animCtrl;
// //   late Animation<double> _fadeAnim;

// //   // ─── Design Tokens ───────────────────────────────────────────────────────────
// //   static const Color _primary = Color(0xFF1A56DB);
// //   static const Color _accent = Color(0xFF0E9F6E);
// //   static const Color _amber = Color(0xFFF59E0B);
// //   static const Color _red = Color(0xFFEF4444);
// //   static const Color _surface = Color(0xFFF0F4FF);
// //   static const Color _card = Colors.white;
// //   static const Color _textDark = Color(0xFF0F172A);
// //   static const Color _textMid = Color(0xFF64748B);
// //   static const Color _textLight = Color(0xFF94A3B8);
// //   static const Color _border = Color(0xFFE2E8F0);

// //   @override
// //   void initState() {
// //     super.initState();
// //     _animCtrl = AnimationController(
// //       vsync: this,
// //       duration: const Duration(milliseconds: 500),
// //     );
// //     _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
// //     fetchAssignments();
// //   }

// //   @override
// //   void dispose() {
// //     _animCtrl.dispose();
// //     super.dispose();
// //   }

// //   Future<void> fetchAssignments() async {
// //     setState(() {
// //       isLoading = true;
// //       errorMessage = null;
// //     });
// //     try {
// //       final data = await AssignLocationService.getEmployeeAssignments(
// //         widget.empId,
// //       );
// //       if (!mounted) return;
// //       setState(() {
// //         assignments = data;
// //         isLoading = false;
// //       });
// //       _animCtrl.forward(from: 0);
// //     } catch (e) {
// //       if (!mounted) return;
// //       setState(() {
// //         isLoading = false;
// //         errorMessage = 'Unable to load assignments. Check your connection.';
// //       });
// //     }
// //   }

// //   // ─── Helpers ─────────────────────────────────────────────────────────────────
// //   String _fmtDate(DateTime? d) =>
// //       d == null ? '-' : DateFormat('dd MMM yyyy').format(d);
// //   String _fmtShort(DateTime? d) =>
// //       d == null ? '-' : DateFormat('dd MMM').format(d);

// //   _AssignStatus _getStatus(AssignLocationModel a) {
// //     final now = DateTime.now();
// //     if (a.startDate == null) return _AssignStatus.unknown;
// //     if (a.endDate != null && a.endDate!.isBefore(now))
// //       return _AssignStatus.past;
// //     if (a.startDate!.isAfter(now)) return _AssignStatus.upcoming;
// //     return _AssignStatus.active;
// //   }

// //   Color _statusColor(_AssignStatus s) {
// //     switch (s) {
// //       case _AssignStatus.active:
// //         return _accent;
// //       case _AssignStatus.upcoming:
// //         return _amber;
// //       case _AssignStatus.past:
// //         return _textLight;
// //       default:
// //         return _textMid;
// //     }
// //   }

// //   void _showWorkDetails(AssignLocationModel a, Responsive r) {
// //     showModalBottomSheet(
// //       context: context,
// //       isScrollControlled: true,
// //       backgroundColor: Colors.transparent,
// //       builder: (_) => DraggableScrollableSheet(
// //         initialChildSize: r.isMobile ? 0.5 : 0.6,
// //         minChildSize: 0.3,
// //         maxChildSize: 0.9,
// //         builder: (_, ctrl) => Container(
// //           decoration: const BoxDecoration(
// //             color: _card,
// //             borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
// //           ),
// //           child: Center(
// //             child: ConstrainedBox(
// //               constraints: const BoxConstraints(maxWidth: 600),
// //               child: ListView(
// //                 controller: ctrl,
// //                 padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
// //                 children: [
// //                   Center(
// //                     child: Container(
// //                       margin: const EdgeInsets.only(top: 12, bottom: 20),
// //                       width: 40,
// //                       height: 4,
// //                       decoration: BoxDecoration(
// //                         color: _border,
// //                         borderRadius: BorderRadius.circular(2),
// //                       ),
// //                     ),
// //                   ),
// //                   Row(
// //                     children: [
// //                       Container(
// //                         padding: const EdgeInsets.all(10),
// //                         decoration: BoxDecoration(
// //                           color: const Color(0xFFEEF2FF),
// //                           borderRadius: BorderRadius.circular(12),
// //                         ),
// //                         child: const Icon(
// //                           Icons.location_on_rounded,
// //                           color: _primary,
// //                           size: 22,
// //                         ),
// //                       ),
// //                       const SizedBox(width: 12),
// //                       Expanded(
// //                         child: Column(
// //                           crossAxisAlignment: CrossAxisAlignment.start,
// //                           children: [
// //                             Text(
// //                               a.locationName ?? '-',
// //                               style: const TextStyle(
// //                                 fontSize: 17,
// //                                 fontWeight: FontWeight.w800,
// //                                 color: _textDark,
// //                               ),
// //                             ),
// //                             const SizedBox(height: 2),
// //                             _statusChip(_getStatus(a)),
// //                           ],
// //                         ),
// //                       ),
// //                     ],
// //                   ),
// //                   const SizedBox(height: 20),
// //                   // Date range
// //                   Container(
// //                     padding: const EdgeInsets.all(14),
// //                     decoration: BoxDecoration(
// //                       color: _surface,
// //                       borderRadius: BorderRadius.circular(12),
// //                       border: Border.all(color: _border),
// //                     ),
// //                     child: Row(
// //                       children: [
// //                         _dateBlock(
// //                           'Start Date',
// //                           _fmtDate(a.startDate),
// //                           _accent,
// //                         ),
// //                         const Expanded(
// //                           child: Column(
// //                             children: [
// //                               Icon(
// //                                 Icons.arrow_forward_rounded,
// //                                 color: _textLight,
// //                                 size: 18,
// //                               ),
// //                             ],
// //                           ),
// //                         ),
// //                         _dateBlock('End Date', _fmtDate(a.endDate), _red),
// //                       ],
// //                     ),
// //                   ),
// //                   const SizedBox(height: 12),
// //                   Container(
// //                     padding: const EdgeInsets.symmetric(
// //                       horizontal: 14,
// //                       vertical: 12,
// //                     ),
// //                     decoration: BoxDecoration(
// //                       color: _primary.withOpacity(0.05),
// //                       borderRadius: BorderRadius.circular(12),
// //                       border: Border.all(color: _primary.withOpacity(0.15)),
// //                     ),
// //                     child: Row(
// //                       children: [
// //                         const Icon(
// //                           Icons.today_rounded,
// //                           color: _primary,
// //                           size: 18,
// //                         ),
// //                         const SizedBox(width: 10),
// //                         Text(
// //                           '${a.daysCount ?? 0} days assigned',
// //                           style: const TextStyle(
// //                             fontSize: 13,
// //                             fontWeight: FontWeight.w600,
// //                             color: _primary,
// //                           ),
// //                         ),
// //                       ],
// //                     ),
// //                   ),
// //                   const SizedBox(height: 20),
// //                   const Text(
// //                     'About Work',
// //                     style: TextStyle(
// //                       fontSize: 13,
// //                       fontWeight: FontWeight.w700,
// //                       color: _textMid,
// //                       letterSpacing: 0.3,
// //                     ),
// //                   ),
// //                   const SizedBox(height: 8),
// //                   Container(
// //                     width: double.infinity,
// //                     padding: const EdgeInsets.all(14),
// //                     decoration: BoxDecoration(
// //                       color: _surface,
// //                       borderRadius: BorderRadius.circular(12),
// //                       border: Border.all(color: _border),
// //                     ),
// //                     child: Text(
// //                       a.aboutWork?.isNotEmpty == true
// //                           ? a.aboutWork!
// //                           : 'No details provided.',
// //                       style: const TextStyle(
// //                         fontSize: 14,
// //                         color: _textDark,
// //                         height: 1.6,
// //                       ),
// //                     ),
// //                   ),
// //                 ],
// //               ),
// //             ),
// //           ),
// //         ),
// //       ),
// //     );
// //   }

// //   // ─── Root ─────────────────────────────────────────────────────────────────────
// //   @override
// //   Widget build(BuildContext context) {
// //     final r = Responsive.of(context);
// //     return Scaffold(
// //       backgroundColor: _surface,
// //       body: isLoading
// //           ? const Center(child: CircularProgressIndicator(color: _primary))
// //           : errorMessage != null
// //           ? _buildError(r)
// //           : RefreshIndicator(
// //               onRefresh: fetchAssignments,
// //               color: _primary,
// //               child: CustomScrollView(
// //                 physics: const AlwaysScrollableScrollPhysics(),
// //                 slivers: [
// //                   _buildAppBar(r),
// //                   SliverToBoxAdapter(child: _buildSummaryBar(r)),
// //                   SliverToBoxAdapter(child: _buildHistoryHeader(r)),
// //                   if (assignments.isEmpty)
// //                     SliverToBoxAdapter(child: _buildEmpty(r))
// //                   else
// //                     SliverPadding(
// //                       padding: EdgeInsets.fromLTRB(r.hPad, 0, r.hPad, 32),
// //                       sliver: SliverToBoxAdapter(
// //                         child: Center(
// //                           child: ConstrainedBox(
// //                             constraints: BoxConstraints(
// //                               maxWidth: r.contentMaxWidth,
// //                             ),
// //                             child: FadeTransition(
// //                               opacity: _fadeAnim,
// //                               child: r.useTwoColSections
// //                                   ? _buildGrid(r)
// //                                   : _buildList(r),
// //                             ),
// //                           ),
// //                         ),
// //                       ),
// //                     ),
// //                 ],
// //               ),
// //             ),
// //     );
// //   }

// //   // Tablet/Desktop: 2-column card grid
// //   Widget _buildGrid(Responsive r) {
// //     return LayoutBuilder(
// //       builder: (ctx, constraints) {
// //         final cols = r.isDesktop ? 3 : 2;
// //         final gap = 12.0;
// //         final itemW = (constraints.maxWidth - gap * (cols - 1)) / cols;
// //         return Wrap(
// //           spacing: gap,
// //           runSpacing: gap,
// //           children: List.generate(
// //             assignments.length,
// //             (i) => SizedBox(width: itemW, child: _buildCard(assignments[i], r)),
// //           ),
// //         );
// //       },
// //     );
// //   }

// //   Widget _buildList(Responsive r) => Column(
// //     children: List.generate(
// //       assignments.length,
// //       (i) => Padding(
// //         padding: EdgeInsets.only(top: i == 0 ? 0 : 10),
// //         child: _buildCard(assignments[i], r),
// //       ),
// //     ),
// //   );

// //   // ─── Sliver AppBar ────────────────────────────────────────────────────────────
// //   Widget _buildAppBar(Responsive r) => SliverAppBar(
// //     expandedHeight: r.appBarHeight,
// //     pinned: true,
// //     elevation: 0,
// //     backgroundColor: _primary,
// //     foregroundColor: Colors.white,
// //     actions: [
// //       IconButton(
// //         icon: const Icon(Icons.refresh_rounded),
// //         tooltip: 'Refresh',
// //         onPressed: isLoading ? null : fetchAssignments,
// //       ),
// //     ],
// //     flexibleSpace: FlexibleSpaceBar(
// //       collapseMode: CollapseMode.pin,
// //       background: Container(
// //         decoration: const BoxDecoration(
// //           gradient: LinearGradient(
// //             colors: [Color(0xFF1A56DB), Color(0xFF1E3A8A), Color(0xFF1e1b4b)],
// //             begin: Alignment.topLeft,
// //             end: Alignment.bottomRight,
// //           ),
// //         ),
// //         child: Stack(
// //           children: [
// //             Positioned(
// //               top: -20,
// //               right: -20,
// //               child: Container(
// //                 width: 120,
// //                 height: 120,
// //                 decoration: BoxDecoration(
// //                   shape: BoxShape.circle,
// //                   color: Colors.white.withOpacity(0.05),
// //                 ),
// //               ),
// //             ),
// //             Positioned(
// //               left: 0,
// //               right: 0,
// //               bottom: 0,
// //               child: SafeArea(
// //                 top: false,
// //                 child: Padding(
// //                   padding: EdgeInsets.fromLTRB(r.hPad, 0, 20, 16),
// //                   child: Column(
// //                     mainAxisSize: MainAxisSize.min,
// //                     crossAxisAlignment: CrossAxisAlignment.start,
// //                     children: [
// //                       const Text(
// //                         'My Assignments',
// //                         style: TextStyle(
// //                           color: Colors.white,
// //                           fontWeight: FontWeight.w800,
// //                           fontSize: 18,
// //                           letterSpacing: 0.2,
// //                         ),
// //                       ),
// //                       const SizedBox(height: 2),
// //                       Text(
// //                         'All your location assignments',
// //                         style: TextStyle(
// //                           color: Colors.white.withOpacity(0.6),
// //                           fontSize: 12,
// //                         ),
// //                       ),
// //                     ],
// //                   ),
// //                 ),
// //               ),
// //             ),
// //           ],
// //         ),
// //       ),
// //     ),
// //   );

// //   // ─── Summary Bar ─────────────────────────────────────────────────────────────
// //   Widget _buildSummaryBar(Responsive r) {
// //     final active = assignments
// //         .where((a) => _getStatus(a) == _AssignStatus.active)
// //         .length;
// //     final upcoming = assignments
// //         .where((a) => _getStatus(a) == _AssignStatus.upcoming)
// //         .length;
// //     final past = assignments
// //         .where((a) => _getStatus(a) == _AssignStatus.past)
// //         .length;
// //     return Container(
// //       color: _primary,
// //       padding: EdgeInsets.fromLTRB(r.hPad, 0, r.hPad, 20),
// //       child: Center(
// //         child: ConstrainedBox(
// //           constraints: BoxConstraints(maxWidth: r.contentMaxWidth),
// //           child: Container(
// //             padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
// //             decoration: BoxDecoration(
// //               color: Colors.white.withOpacity(0.12),
// //               borderRadius: BorderRadius.circular(14),
// //               border: Border.all(color: Colors.white.withOpacity(0.15)),
// //             ),
// //             child: Row(
// //               children: [
// //                 _statItem('${assignments.length}', 'Total', Colors.white),
// //                 _vDiv(),
// //                 _statItem('$active', 'Active', const Color(0xFF6EE7B7)),
// //                 _vDiv(),
// //                 _statItem('$upcoming', 'Upcoming', const Color(0xFFFDE68A)),
// //                 _vDiv(),
// //                 _statItem('$past', 'Past', Colors.white60),
// //               ],
// //             ),
// //           ),
// //         ),
// //       ),
// //     );
// //   }

// //   Widget _statItem(String v, String l, Color c) => Expanded(
// //     child: Column(
// //       children: [
// //         Text(
// //           v,
// //           style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: c),
// //         ),
// //         const SizedBox(height: 2),
// //         Text(
// //           l,
// //           style: TextStyle(
// //             fontSize: 10,
// //             color: c.withOpacity(0.75),
// //             letterSpacing: 0.4,
// //             fontWeight: FontWeight.w500,
// //           ),
// //         ),
// //       ],
// //     ),
// //   );

// //   Widget _vDiv() =>
// //       Container(width: 1, height: 30, color: Colors.white.withOpacity(0.2));

// //   Widget _buildHistoryHeader(Responsive r) => Padding(
// //     padding: EdgeInsets.fromLTRB(r.hPad, 20, r.hPad, 12),
// //     child: Center(
// //       child: ConstrainedBox(
// //         constraints: BoxConstraints(maxWidth: r.contentMaxWidth),
// //         child: Row(
// //           children: [
// //             Container(
// //               width: 4,
// //               height: 20,
// //               decoration: BoxDecoration(
// //                 color: _primary,
// //                 borderRadius: BorderRadius.circular(2),
// //               ),
// //             ),
// //             const SizedBox(width: 10),
// //             const Text(
// //               'Assignment History',
// //               style: TextStyle(
// //                 fontSize: 17,
// //                 fontWeight: FontWeight.w800,
// //                 color: _textDark,
// //                 letterSpacing: 0.1,
// //               ),
// //             ),
// //             const Spacer(),
// //             if (assignments.isNotEmpty)
// //               Container(
// //                 padding: const EdgeInsets.symmetric(
// //                   horizontal: 10,
// //                   vertical: 4,
// //                 ),
// //                 decoration: BoxDecoration(
// //                   color: const Color(0xFFEEF2FF),
// //                   borderRadius: BorderRadius.circular(20),
// //                 ),
// //                 child: Text(
// //                   '${assignments.length} records',
// //                   style: const TextStyle(
// //                     fontSize: 11,
// //                     color: _primary,
// //                     fontWeight: FontWeight.w600,
// //                   ),
// //                 ),
// //               ),
// //           ],
// //         ),
// //       ),
// //     ),
// //   );

// //   // ─── Assignment Card ──────────────────────────────────────────────────────────
// //   Widget _buildCard(AssignLocationModel a, Responsive r) {
// //     final status = _getStatus(a);
// //     return GestureDetector(
// //       onTap: () => _showWorkDetails(a, r),
// //       child: Container(
// //         decoration: BoxDecoration(
// //           color: _card,
// //           borderRadius: BorderRadius.circular(r.cardRadius),
// //           border: Border.all(color: _border),
// //           boxShadow: [
// //             BoxShadow(
// //               color: Colors.black.withOpacity(0.05),
// //               blurRadius: 10,
// //               offset: const Offset(0, 2),
// //             ),
// //           ],
// //         ),
// //         clipBehavior: Clip.antiAlias,
// //         child: Column(
// //           crossAxisAlignment: CrossAxisAlignment.start,
// //           children: [
// //             Container(height: 3, color: _statusColor(status)),
// //             Padding(
// //               padding: const EdgeInsets.all(16),
// //               child: Column(
// //                 crossAxisAlignment: CrossAxisAlignment.start,
// //                 children: [
// //                   Row(
// //                     children: [
// //                       Container(
// //                         padding: const EdgeInsets.all(9),
// //                         decoration: BoxDecoration(
// //                           color: const Color(0xFFEEF2FF),
// //                           borderRadius: BorderRadius.circular(10),
// //                         ),
// //                         child: const Icon(
// //                           Icons.location_on_rounded,
// //                           color: _primary,
// //                           size: 18,
// //                         ),
// //                       ),
// //                       const SizedBox(width: 12),
// //                       Expanded(
// //                         child: Text(
// //                           a.locationName ?? '-',
// //                           style: TextStyle(
// //                             fontSize: r.sectionTitleSize,
// //                             fontWeight: FontWeight.w700,
// //                             color: _textDark,
// //                           ),
// //                         ),
// //                       ),
// //                       _statusChip(status),
// //                     ],
// //                   ),
// //                   const SizedBox(height: 14),
// //                   Container(
// //                     padding: const EdgeInsets.symmetric(
// //                       horizontal: 12,
// //                       vertical: 10,
// //                     ),
// //                     decoration: BoxDecoration(
// //                       color: _surface,
// //                       borderRadius: BorderRadius.circular(10),
// //                       border: Border.all(color: _border),
// //                     ),
// //                     child: Row(
// //                       children: [
// //                         _miniDate(
// //                           Icons.play_circle_outline_rounded,
// //                           _fmtShort(a.startDate),
// //                           _accent,
// //                         ),
// //                         const SizedBox(width: 6),
// //                         Expanded(
// //                           child: Container(
// //                             height: 1.5,
// //                             decoration: BoxDecoration(
// //                               gradient: LinearGradient(
// //                                 colors: [
// //                                   _accent.withOpacity(0.4),
// //                                   _red.withOpacity(0.4),
// //                                 ],
// //                               ),
// //                             ),
// //                           ),
// //                         ),
// //                         const SizedBox(width: 6),
// //                         _miniDate(
// //                           Icons.stop_circle_outlined,
// //                           _fmtShort(a.endDate),
// //                           _red,
// //                         ),
// //                         const SizedBox(width: 12),
// //                         Container(
// //                           padding: const EdgeInsets.symmetric(
// //                             horizontal: 8,
// //                             vertical: 4,
// //                           ),
// //                           decoration: BoxDecoration(
// //                             color: _primary.withOpacity(0.08),
// //                             borderRadius: BorderRadius.circular(7),
// //                           ),
// //                           child: Text(
// //                             '${a.daysCount ?? 0}d',
// //                             style: const TextStyle(
// //                               fontSize: 12,
// //                               fontWeight: FontWeight.w700,
// //                               color: _primary,
// //                             ),
// //                           ),
// //                         ),
// //                       ],
// //                     ),
// //                   ),
// //                   if (a.aboutWork != null &&
// //                       a.aboutWork!.trim().isNotEmpty) ...[
// //                     const SizedBox(height: 10),
// //                     Text(
// //                       a.aboutWork!,
// //                       maxLines: 2,
// //                       overflow: TextOverflow.ellipsis,
// //                       style: const TextStyle(
// //                         fontSize: 12,
// //                         color: _textMid,
// //                         height: 1.5,
// //                       ),
// //                     ),
// //                   ],
// //                   const SizedBox(height: 10),
// //                   Row(
// //                     mainAxisAlignment: MainAxisAlignment.end,
// //                     children: [
// //                       Text(
// //                         'View details',
// //                         style: TextStyle(
// //                           fontSize: 12,
// //                           color: _primary.withOpacity(0.8),
// //                           fontWeight: FontWeight.w600,
// //                         ),
// //                       ),
// //                       const SizedBox(width: 4),
// //                       Icon(
// //                         Icons.arrow_forward_rounded,
// //                         size: 13,
// //                         color: _primary.withOpacity(0.8),
// //                       ),
// //                     ],
// //                   ),
// //                 ],
// //               ),
// //             ),
// //           ],
// //         ),
// //       ),
// //     );
// //   }

// //   Widget _statusChip(_AssignStatus s) {
// //     final label = s == _AssignStatus.active
// //         ? 'Active'
// //         : s == _AssignStatus.upcoming
// //         ? 'Upcoming'
// //         : s == _AssignStatus.past
// //         ? 'Past'
// //         : 'Unknown';
// //     final color = _statusColor(s);
// //     return Container(
// //       padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
// //       decoration: BoxDecoration(
// //         color: color.withOpacity(0.1),
// //         borderRadius: BorderRadius.circular(20),
// //         border: Border.all(color: color.withOpacity(0.3)),
// //       ),
// //       child: Row(
// //         mainAxisSize: MainAxisSize.min,
// //         children: [
// //           Container(
// //             width: 6,
// //             height: 6,
// //             decoration: BoxDecoration(color: color, shape: BoxShape.circle),
// //           ),
// //           const SizedBox(width: 5),
// //           Text(
// //             label,
// //             style: TextStyle(
// //               fontSize: 11,
// //               fontWeight: FontWeight.w700,
// //               color: color,
// //             ),
// //           ),
// //         ],
// //       ),
// //     );
// //   }

// //   Widget _miniDate(IconData icon, String d, Color c) => Row(
// //     mainAxisSize: MainAxisSize.min,
// //     children: [
// //       Icon(icon, size: 14, color: c),
// //       const SizedBox(width: 4),
// //       Text(
// //         d,
// //         style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: c),
// //       ),
// //     ],
// //   );

// //   Widget _dateBlock(String label, String value, Color color) => Expanded(
// //     child: Column(
// //       crossAxisAlignment: CrossAxisAlignment.center,
// //       children: [
// //         Text(
// //           label,
// //           style: const TextStyle(
// //             fontSize: 11,
// //             color: _textMid,
// //             fontWeight: FontWeight.w500,
// //           ),
// //         ),
// //         const SizedBox(height: 4),
// //         Text(
// //           value,
// //           style: TextStyle(
// //             fontSize: 14,
// //             fontWeight: FontWeight.w700,
// //             color: color,
// //           ),
// //         ),
// //       ],
// //     ),
// //   );

// //   Widget _buildError(Responsive r) => Center(
// //     child: Padding(
// //       padding: EdgeInsets.symmetric(horizontal: r.hPad),
// //       child: ConstrainedBox(
// //         constraints: BoxConstraints(maxWidth: r.contentMaxWidth),
// //         child: Column(
// //           mainAxisAlignment: MainAxisAlignment.center,
// //           children: [
// //             Container(
// //               padding: const EdgeInsets.all(20),
// //               decoration: BoxDecoration(
// //                 color: _red.withOpacity(0.08),
// //                 shape: BoxShape.circle,
// //               ),
// //               child: const Icon(Icons.wifi_off_rounded, color: _red, size: 40),
// //             ),
// //             const SizedBox(height: 16),
// //             const Text(
// //               'Failed to load assignments',
// //               style: TextStyle(
// //                 fontSize: 17,
// //                 fontWeight: FontWeight.w700,
// //                 color: _textDark,
// //               ),
// //             ),
// //             const SizedBox(height: 6),
// //             Text(
// //               errorMessage!,
// //               textAlign: TextAlign.center,
// //               style: const TextStyle(color: _textMid, fontSize: 13),
// //             ),
// //             const SizedBox(height: 24),
// //             FilledButton.icon(
// //               onPressed: fetchAssignments,
// //               icon: const Icon(Icons.refresh_rounded, size: 18),
// //               label: const Text('Try Again'),
// //               style: FilledButton.styleFrom(
// //                 backgroundColor: _primary,
// //                 padding: const EdgeInsets.symmetric(
// //                   horizontal: 24,
// //                   vertical: 12,
// //                 ),
// //                 shape: RoundedRectangleBorder(
// //                   borderRadius: BorderRadius.circular(12),
// //                 ),
// //               ),
// //             ),
// //           ],
// //         ),
// //       ),
// //     ),
// //   );

// //   Widget _buildEmpty(Responsive r) => Padding(
// //     padding: EdgeInsets.fromLTRB(r.hPad, 60, r.hPad, 60),
// //     child: Center(
// //       child: Column(
// //         children: [
// //           Container(
// //             padding: const EdgeInsets.all(24),
// //             decoration: BoxDecoration(
// //               color: _primary.withOpacity(0.06),
// //               shape: BoxShape.circle,
// //             ),
// //             child: const Icon(
// //               Icons.location_off_rounded,
// //               color: _textLight,
// //               size: 44,
// //             ),
// //           ),
// //           const SizedBox(height: 16),
// //           const Text(
// //             'No assignments yet',
// //             style: TextStyle(
// //               fontSize: 17,
// //               fontWeight: FontWeight.w700,
// //               color: _textDark,
// //             ),
// //           ),
// //           const SizedBox(height: 6),
// //           const Text(
// //             'Pull down to refresh',
// //             style: TextStyle(color: _textMid, fontSize: 13),
// //           ),
// //         ],
// //       ),
// //     ),
// //   );
// // }

// // enum _AssignStatus { active, upcoming, past, unknown }
// import 'dart:convert';
// import 'dart:math' as math;
// import 'package:intl/intl.dart';
// import 'package:flutter/material.dart';
// import 'package:url_launcher/url_launcher.dart';
// import '../services/api_service.dart';
// import 'responsive_utils.dart';

// // ─── Model ────────────────────────────────────────────────────────────────────

// class SiteModel {
//   final int id;
//   final String siteName;
//   final List<Map<String, double>> polygon;
//   final DateTime? startDate;
//   final DateTime? endDate;
//   final DateTime? createdAt;

//   const SiteModel({
//     required this.id,
//     required this.siteName,
//     required this.polygon,
//     this.startDate,
//     this.endDate,
//     this.createdAt,
//   });

//   factory SiteModel.fromJson(Map<String, dynamic> json) {
//     List<Map<String, double>> polygon = [];
//     try {
//       final raw = json['polygon_json'];
//       final list = raw is String ? jsonDecode(raw) as List : raw as List;
//       polygon = list
//           .map<Map<String, double>>(
//             (pt) => {
//               'lat': (pt['lat'] as num).toDouble(),
//               'lng': (pt['lng'] as num).toDouble(),
//             },
//           )
//           .toList();
//     } catch (_) {}

//     return SiteModel(
//       id: (json['id'] as num).toInt(),
//       siteName: (json['site_name'] as String?) ?? 'Unnamed Site',
//       polygon: polygon,
//       startDate: _parseDate(json['start_date']),
//       endDate: _parseDate(json['end_date']),
//       createdAt: _parseDate(json['created_at']),
//     );
//   }

//   static DateTime? _parseDate(dynamic v) {
//     if (v == null || v.toString().isEmpty) return null;
//     try {
//       return DateTime.parse(v.toString());
//     } catch (_) {
//       return null;
//     }
//   }

//   /// Centroid of the polygon (used to open in Maps)
//   LatLng? get centroid {
//     if (polygon.isEmpty) return null;
//     final lat =
//         polygon.map((p) => p['lat']!).reduce((a, b) => a + b) / polygon.length;
//     final lng =
//         polygon.map((p) => p['lng']!).reduce((a, b) => a + b) / polygon.length;
//     return LatLng(lat, lng);
//   }

//   int get daysCount {
//     if (startDate == null || endDate == null) return 0;
//     return endDate!.difference(startDate!).inDays + 1;
//   }
// }

// class LatLng {
//   final double lat;
//   final double lng;
//   const LatLng(this.lat, this.lng);
// }

// // ─── Screen ───────────────────────────────────────────────────────────────────

// class EmployeeAssignmentsScreen extends StatefulWidget {
//   final int empId;
//   const EmployeeAssignmentsScreen({super.key, required this.empId});

//   @override
//   State<EmployeeAssignmentsScreen> createState() =>
//       _EmployeeAssignmentsScreenState();
// }

// class _EmployeeAssignmentsScreenState extends State<EmployeeAssignmentsScreen>
//     with SingleTickerProviderStateMixin {
//   List<SiteModel> _sites = [];
//   bool _isLoading = true;
//   String? _errorMessage;

//   late AnimationController _animCtrl;
//   late Animation<double> _fadeAnim;

//   // ─── Design Tokens ──────────────────────────────────────────────────────────
//   static const Color _primary = Color(0xFF1A56DB);
//   static const Color _accent = Color(0xFF0E9F6E);
//   static const Color _amber = Color(0xFFF59E0B);
//   static const Color _red = Color(0xFFEF4444);
//   static const Color _surface = Color(0xFFF0F4FF);
//   static const Color _card = Colors.white;
//   static const Color _textDark = Color(0xFF0F172A);
//   static const Color _textMid = Color(0xFF64748B);
//   static const Color _textLight = Color(0xFF94A3B8);
//   static const Color _border = Color(0xFFE2E8F0);

//   @override
//   void initState() {
//     super.initState();
//     _animCtrl = AnimationController(
//       vsync: this,
//       duration: const Duration(milliseconds: 500),
//     );
//     _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
//     _fetchSites();
//   }

//   @override
//   void dispose() {
//     _animCtrl.dispose();
//     super.dispose();
//   }

//   // ─── Data ────────────────────────────────────────────────────────────────────

//   Future<void> _fetchSites() async {
//     setState(() {
//       _isLoading = true;
//       _errorMessage = null;
//     });
//     try {
//       final raw = await ApiService.getSites(); // returns List<dynamic>
//       if (!mounted) return;
//       final sites = (raw as List)
//           .map((e) => SiteModel.fromJson(e as Map<String, dynamic>))
//           .toList();
//       setState(() {
//         _sites = sites;
//         _isLoading = false;
//       });
//       _animCtrl.forward(from: 0);
//     } catch (e) {
//       if (!mounted) return;
//       setState(() {
//         _isLoading = false;
//         _errorMessage = 'Unable to load sites. Check your connection.';
//       });
//     }
//   }

//   // ─── Status helpers ──────────────────────────────────────────────────────────

//   _SiteStatus _getStatus(SiteModel s) {
//     final now = DateTime.now();
//     if (s.startDate == null) return _SiteStatus.unknown;
//     if (s.endDate != null && s.endDate!.isBefore(now)) return _SiteStatus.past;
//     if (s.startDate!.isAfter(now)) return _SiteStatus.upcoming;
//     return _SiteStatus.active;
//   }

//   Color _statusColor(_SiteStatus s) => switch (s) {
//     _SiteStatus.active => _accent,
//     _SiteStatus.upcoming => _amber,
//     _SiteStatus.past => _textLight,
//     _ => _textMid,
//   };

//   String _fmtDate(DateTime? d) =>
//       d == null ? '-' : DateFormat('dd MMM yyyy').format(d);
//   String _fmtShort(DateTime? d) =>
//       d == null ? '-' : DateFormat('dd MMM').format(d);

//   // ─── Google Maps navigation ──────────────────────────────────────────────────

//   Future<void> _openInMaps(SiteModel site) async {
//     final center = site.centroid;
//     if (center == null) {
//       _showSnack('No location data for this site.');
//       return;
//     }

//     // Build a label-based Google Maps URL so the user sees the site name
//     // and can tap "Directions" inside the app.
//     final label = Uri.encodeComponent(site.siteName);
//     final lat = center.lat;
//     final lng = center.lng;

//     // geo: URI — Android opens Google Maps natively
//     // On iOS falls back to Apple Maps unless Google Maps is installed
//     final geoUri = Uri.parse('geo:$lat,$lng?q=$lat,$lng($label)');

//     // Google Maps universal link — works on both platforms when
//     // Google Maps is installed; falls back to browser otherwise
//     final mapsUrl = Uri.parse(
//       'https://www.google.com/maps/search/?api=1'
//       '&query=$lat%2C$lng'
//       '&query_place=$label',
//     );

//     if (await canLaunchUrl(geoUri)) {
//       await launchUrl(geoUri, mode: LaunchMode.externalApplication);
//     } else if (await canLaunchUrl(mapsUrl)) {
//       await launchUrl(mapsUrl, mode: LaunchMode.externalApplication);
//     } else {
//       _showSnack('Could not open Maps on this device.');
//     }
//   }

//   void _showSnack(String msg) {
//     if (!mounted) return;
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
//     );
//   }

//   // ─── Bottom-sheet detail ─────────────────────────────────────────────────────

//   void _showSiteDetails(SiteModel site, Responsive r) {
//     final status = _getStatus(site);
//     showModalBottomSheet(
//       context: context,
//       isScrollControlled: true,
//       backgroundColor: Colors.transparent,
//       builder: (_) => DraggableScrollableSheet(
//         initialChildSize: r.isMobile ? 0.55 : 0.65,
//         minChildSize: 0.35,
//         maxChildSize: 0.92,
//         builder: (_, ctrl) => Container(
//           decoration: const BoxDecoration(
//             color: _card,
//             borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
//           ),
//           child: Center(
//             child: ConstrainedBox(
//               constraints: const BoxConstraints(maxWidth: 600),
//               child: ListView(
//                 controller: ctrl,
//                 padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
//                 children: [
//                   // drag handle
//                   Center(
//                     child: Container(
//                       margin: const EdgeInsets.only(top: 12, bottom: 20),
//                       width: 40,
//                       height: 4,
//                       decoration: BoxDecoration(
//                         color: _border,
//                         borderRadius: BorderRadius.circular(2),
//                       ),
//                     ),
//                   ),

//                   // Header
//                   Row(
//                     children: [
//                       Container(
//                         padding: const EdgeInsets.all(10),
//                         decoration: BoxDecoration(
//                           color: const Color(0xFFEEF2FF),
//                           borderRadius: BorderRadius.circular(12),
//                         ),
//                         child: const Icon(
//                           Icons.location_on_rounded,
//                           color: _primary,
//                           size: 22,
//                         ),
//                       ),
//                       const SizedBox(width: 12),
//                       Expanded(
//                         child: Column(
//                           crossAxisAlignment: CrossAxisAlignment.start,
//                           children: [
//                             Text(
//                               site.siteName,
//                               style: const TextStyle(
//                                 fontSize: 17,
//                                 fontWeight: FontWeight.w800,
//                                 color: _textDark,
//                               ),
//                             ),
//                             const SizedBox(height: 2),
//                             _statusChip(status),
//                           ],
//                         ),
//                       ),
//                     ],
//                   ),
//                   const SizedBox(height: 20),

//                   // Date range
//                   Container(
//                     padding: const EdgeInsets.all(14),
//                     decoration: BoxDecoration(
//                       color: _surface,
//                       borderRadius: BorderRadius.circular(12),
//                       border: Border.all(color: _border),
//                     ),
//                     child: Row(
//                       children: [
//                         _dateBlock(
//                           'Start Date',
//                           _fmtDate(site.startDate),
//                           _accent,
//                         ),
//                         const Expanded(
//                           child: Column(
//                             children: [
//                               Icon(
//                                 Icons.arrow_forward_rounded,
//                                 color: _textLight,
//                                 size: 18,
//                               ),
//                             ],
//                           ),
//                         ),
//                         _dateBlock('End Date', _fmtDate(site.endDate), _red),
//                       ],
//                     ),
//                   ),
//                   const SizedBox(height: 12),

//                   // Days count
//                   Container(
//                     padding: const EdgeInsets.symmetric(
//                       horizontal: 14,
//                       vertical: 12,
//                     ),
//                     decoration: BoxDecoration(
//                       color: _primary.withOpacity(0.05),
//                       borderRadius: BorderRadius.circular(12),
//                       border: Border.all(color: _primary.withOpacity(0.15)),
//                     ),
//                     child: Row(
//                       children: [
//                         const Icon(
//                           Icons.today_rounded,
//                           color: _primary,
//                           size: 18,
//                         ),
//                         const SizedBox(width: 10),
//                         Text(
//                           '${site.daysCount} days total',
//                           style: const TextStyle(
//                             fontSize: 13,
//                             fontWeight: FontWeight.w600,
//                             color: _primary,
//                           ),
//                         ),
//                         const Spacer(),
//                         Text(
//                           '${site.polygon.length} boundary points',
//                           style: const TextStyle(fontSize: 12, color: _textMid),
//                         ),
//                       ],
//                     ),
//                   ),
//                   const SizedBox(height: 20),

//                   // Navigate button
//                   if (site.centroid != null) ...[
//                     FilledButton.icon(
//                       onPressed: () {
//                         Navigator.pop(context);
//                         _openInMaps(site);
//                       },
//                       icon: const Icon(Icons.navigation_rounded, size: 18),
//                       label: const Text('Navigate to Site'),
//                       style: FilledButton.styleFrom(
//                         backgroundColor: _primary,
//                         padding: const EdgeInsets.symmetric(
//                           horizontal: 24,
//                           vertical: 14,
//                         ),
//                         shape: RoundedRectangleBorder(
//                           borderRadius: BorderRadius.circular(12),
//                         ),
//                         textStyle: const TextStyle(
//                           fontSize: 15,
//                           fontWeight: FontWeight.w700,
//                         ),
//                       ),
//                     ),
//                     const SizedBox(height: 10),

//                     // Coordinates hint
//                     Center(
//                       child: Text(
//                         'Lat ${site.centroid!.lat.toStringAsFixed(5)}, '
//                         'Lng ${site.centroid!.lng.toStringAsFixed(5)}',
//                         style: const TextStyle(fontSize: 11, color: _textLight),
//                       ),
//                     ),
//                   ] else
//                     Container(
//                       padding: const EdgeInsets.all(14),
//                       decoration: BoxDecoration(
//                         color: _red.withOpacity(0.06),
//                         borderRadius: BorderRadius.circular(12),
//                         border: Border.all(color: _red.withOpacity(0.2)),
//                       ),
//                       child: const Row(
//                         children: [
//                           Icon(
//                             Icons.location_off_rounded,
//                             color: _red,
//                             size: 18,
//                           ),
//                           SizedBox(width: 8),
//                           Text(
//                             'No polygon data — cannot navigate',
//                             style: TextStyle(fontSize: 13, color: _red),
//                           ),
//                         ],
//                       ),
//                     ),
//                 ],
//               ),
//             ),
//           ),
//         ),
//       ),
//     );
//   }

//   // ─── Root ─────────────────────────────────────────────────────────────────────

//   @override
//   Widget build(BuildContext context) {
//     final r = Responsive.of(context);
//     return Scaffold(
//       backgroundColor: _surface,
//       body: _isLoading
//           ? const Center(child: CircularProgressIndicator(color: _primary))
//           : _errorMessage != null
//           ? _buildError(r)
//           : RefreshIndicator(
//               onRefresh: _fetchSites,
//               color: _primary,
//               child: CustomScrollView(
//                 physics: const AlwaysScrollableScrollPhysics(),
//                 slivers: [
//                   _buildAppBar(r),
//                   SliverToBoxAdapter(child: _buildSummaryBar(r)),
//                   SliverToBoxAdapter(child: _buildListHeader(r)),
//                   if (_sites.isEmpty)
//                     SliverToBoxAdapter(child: _buildEmpty(r))
//                   else
//                     SliverPadding(
//                       padding: EdgeInsets.fromLTRB(r.hPad, 0, r.hPad, 32),
//                       sliver: SliverToBoxAdapter(
//                         child: Center(
//                           child: ConstrainedBox(
//                             constraints: BoxConstraints(
//                               maxWidth: r.contentMaxWidth,
//                             ),
//                             child: FadeTransition(
//                               opacity: _fadeAnim,
//                               child: r.useTwoColSections
//                                   ? _buildGrid(r)
//                                   : _buildList(r),
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

//   // ─── Grid / List ─────────────────────────────────────────────────────────────

//   Widget _buildGrid(Responsive r) {
//     return LayoutBuilder(
//       builder: (_, constraints) {
//         final cols = r.isDesktop ? 3 : 2;
//         const gap = 12.0;
//         final itemW = (constraints.maxWidth - gap * (cols - 1)) / cols;
//         return Wrap(
//           spacing: gap,
//           runSpacing: gap,
//           children: List.generate(
//             _sites.length,
//             (i) => SizedBox(width: itemW, child: _buildCard(_sites[i], r)),
//           ),
//         );
//       },
//     );
//   }

//   Widget _buildList(Responsive r) => Column(
//     children: List.generate(
//       _sites.length,
//       (i) => Padding(
//         padding: EdgeInsets.only(top: i == 0 ? 0 : 10),
//         child: _buildCard(_sites[i], r),
//       ),
//     ),
//   );

//   // ─── Sliver AppBar ────────────────────────────────────────────────────────────

//   Widget _buildAppBar(Responsive r) => SliverAppBar(
//     expandedHeight: r.appBarHeight,
//     pinned: true,
//     elevation: 0,
//     backgroundColor: _primary,
//     foregroundColor: Colors.white,
//     actions: [
//       IconButton(
//         icon: const Icon(Icons.refresh_rounded),
//         tooltip: 'Refresh',
//         onPressed: _isLoading ? null : _fetchSites,
//       ),
//     ],
//     flexibleSpace: FlexibleSpaceBar(
//       collapseMode: CollapseMode.pin,
//       background: Container(
//         decoration: const BoxDecoration(
//           gradient: LinearGradient(
//             colors: [Color(0xFF1A56DB), Color(0xFF1E3A8A), Color(0xFF1e1b4b)],
//             begin: Alignment.topLeft,
//             end: Alignment.bottomRight,
//           ),
//         ),
//         child: Stack(
//           children: [
//             Positioned(
//               top: -20,
//               right: -20,
//               child: Container(
//                 width: 120,
//                 height: 120,
//                 decoration: BoxDecoration(
//                   shape: BoxShape.circle,
//                   color: Colors.white.withOpacity(0.05),
//                 ),
//               ),
//             ),
//             Positioned(
//               left: 0,
//               right: 0,
//               bottom: 0,
//               child: SafeArea(
//                 top: false,
//                 child: Padding(
//                   padding: EdgeInsets.fromLTRB(r.hPad, 0, 20, 16),
//                   child: Column(
//                     mainAxisSize: MainAxisSize.min,
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       const Text(
//                         'My Sites',
//                         style: TextStyle(
//                           color: Colors.white,
//                           fontWeight: FontWeight.w800,
//                           fontSize: 18,
//                           letterSpacing: 0.2,
//                         ),
//                       ),
//                       const SizedBox(height: 2),
//                       Text(
//                         'All assigned work sites',
//                         style: TextStyle(
//                           color: Colors.white.withOpacity(0.6),
//                           fontSize: 12,
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//               ),
//             ),
//           ],
//         ),
//       ),
//     ),
//   );

//   // ─── Summary Bar ─────────────────────────────────────────────────────────────

//   Widget _buildSummaryBar(Responsive r) {
//     final active = _sites
//         .where((s) => _getStatus(s) == _SiteStatus.active)
//         .length;
//     final upcoming = _sites
//         .where((s) => _getStatus(s) == _SiteStatus.upcoming)
//         .length;
//     final past = _sites.where((s) => _getStatus(s) == _SiteStatus.past).length;

//     return Container(
//       color: _primary,
//       padding: EdgeInsets.fromLTRB(r.hPad, 0, r.hPad, 20),
//       child: Center(
//         child: ConstrainedBox(
//           constraints: BoxConstraints(maxWidth: r.contentMaxWidth),
//           child: Container(
//             padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
//             decoration: BoxDecoration(
//               color: Colors.white.withOpacity(0.12),
//               borderRadius: BorderRadius.circular(14),
//               border: Border.all(color: Colors.white.withOpacity(0.15)),
//             ),
//             child: Row(
//               children: [
//                 _statItem('${_sites.length}', 'Total', Colors.white),
//                 _vDiv(),
//                 _statItem('$active', 'Active', const Color(0xFF6EE7B7)),
//                 _vDiv(),
//                 _statItem('$upcoming', 'Upcoming', const Color(0xFFFDE68A)),
//                 _vDiv(),
//                 _statItem('$past', 'Past', Colors.white60),
//               ],
//             ),
//           ),
//         ),
//       ),
//     );
//   }

//   Widget _statItem(String v, String l, Color c) => Expanded(
//     child: Column(
//       children: [
//         Text(
//           v,
//           style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: c),
//         ),
//         const SizedBox(height: 2),
//         Text(
//           l,
//           style: TextStyle(
//             fontSize: 10,
//             color: c.withOpacity(0.75),
//             letterSpacing: 0.4,
//             fontWeight: FontWeight.w500,
//           ),
//         ),
//       ],
//     ),
//   );

//   Widget _vDiv() =>
//       Container(width: 1, height: 30, color: Colors.white.withOpacity(0.2));

//   Widget _buildListHeader(Responsive r) => Padding(
//     padding: EdgeInsets.fromLTRB(r.hPad, 20, r.hPad, 12),
//     child: Center(
//       child: ConstrainedBox(
//         constraints: BoxConstraints(maxWidth: r.contentMaxWidth),
//         child: Row(
//           children: [
//             Container(
//               width: 4,
//               height: 20,
//               decoration: BoxDecoration(
//                 color: _primary,
//                 borderRadius: BorderRadius.circular(2),
//               ),
//             ),
//             const SizedBox(width: 10),
//             const Text(
//               'Site List',
//               style: TextStyle(
//                 fontSize: 17,
//                 fontWeight: FontWeight.w800,
//                 color: _textDark,
//                 letterSpacing: 0.1,
//               ),
//             ),
//             const Spacer(),
//             if (_sites.isNotEmpty)
//               Container(
//                 padding: const EdgeInsets.symmetric(
//                   horizontal: 10,
//                   vertical: 4,
//                 ),
//                 decoration: BoxDecoration(
//                   color: const Color(0xFFEEF2FF),
//                   borderRadius: BorderRadius.circular(20),
//                 ),
//                 child: Text(
//                   '${_sites.length} sites',
//                   style: const TextStyle(
//                     fontSize: 11,
//                     color: _primary,
//                     fontWeight: FontWeight.w600,
//                   ),
//                 ),
//               ),
//           ],
//         ),
//       ),
//     ),
//   );

//   // ─── Site Card ────────────────────────────────────────────────────────────────

//   Widget _buildCard(SiteModel site, Responsive r) {
//     final status = _getStatus(site);
//     final center = site.centroid;

//     return GestureDetector(
//       onTap: () => _showSiteDetails(site, r),
//       child: Container(
//         decoration: BoxDecoration(
//           color: _card,
//           borderRadius: BorderRadius.circular(r.cardRadius),
//           border: Border.all(color: _border),
//           boxShadow: [
//             BoxShadow(
//               color: Colors.black.withOpacity(0.05),
//               blurRadius: 10,
//               offset: const Offset(0, 2),
//             ),
//           ],
//         ),
//         clipBehavior: Clip.antiAlias,
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             // Status bar
//             Container(height: 3, color: _statusColor(status)),

//             Padding(
//               padding: const EdgeInsets.all(16),
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   // Title row
//                   Row(
//                     children: [
//                       Container(
//                         padding: const EdgeInsets.all(9),
//                         decoration: BoxDecoration(
//                           color: const Color(0xFFEEF2FF),
//                           borderRadius: BorderRadius.circular(10),
//                         ),
//                         child: const Icon(
//                           Icons.location_on_rounded,
//                           color: _primary,
//                           size: 18,
//                         ),
//                       ),
//                       const SizedBox(width: 12),
//                       Expanded(
//                         child: Text(
//                           site.siteName,
//                           style: TextStyle(
//                             fontSize: r.sectionTitleSize,
//                             fontWeight: FontWeight.w700,
//                             color: _textDark,
//                           ),
//                         ),
//                       ),
//                       _statusChip(status),
//                     ],
//                   ),
//                   const SizedBox(height: 14),

//                   // Date range bar
//                   Container(
//                     padding: const EdgeInsets.symmetric(
//                       horizontal: 12,
//                       vertical: 10,
//                     ),
//                     decoration: BoxDecoration(
//                       color: _surface,
//                       borderRadius: BorderRadius.circular(10),
//                       border: Border.all(color: _border),
//                     ),
//                     child: Row(
//                       children: [
//                         _miniDate(
//                           Icons.play_circle_outline_rounded,
//                           _fmtShort(site.startDate),
//                           _accent,
//                         ),
//                         const SizedBox(width: 6),
//                         Expanded(
//                           child: Container(
//                             height: 1.5,
//                             decoration: BoxDecoration(
//                               gradient: LinearGradient(
//                                 colors: [
//                                   _accent.withOpacity(0.4),
//                                   _red.withOpacity(0.4),
//                                 ],
//                               ),
//                             ),
//                           ),
//                         ),
//                         const SizedBox(width: 6),
//                         _miniDate(
//                           Icons.stop_circle_outlined,
//                           _fmtShort(site.endDate),
//                           _red,
//                         ),
//                         const SizedBox(width: 12),
//                         Container(
//                           padding: const EdgeInsets.symmetric(
//                             horizontal: 8,
//                             vertical: 4,
//                           ),
//                           decoration: BoxDecoration(
//                             color: _primary.withOpacity(0.08),
//                             borderRadius: BorderRadius.circular(7),
//                           ),
//                           child: Text(
//                             '${site.daysCount}d',
//                             style: const TextStyle(
//                               fontSize: 12,
//                               fontWeight: FontWeight.w700,
//                               color: _primary,
//                             ),
//                           ),
//                         ),
//                       ],
//                     ),
//                   ),
//                   const SizedBox(height: 10),

//                   // Coordinates row (if available)
//                   if (center != null) ...[
//                     Row(
//                       children: [
//                         Icon(
//                           Icons.my_location_rounded,
//                           size: 13,
//                           color: _textLight,
//                         ),
//                         const SizedBox(width: 5),
//                         Text(
//                           '${center.lat.toStringAsFixed(4)}, '
//                           '${center.lng.toStringAsFixed(4)}',
//                           style: const TextStyle(
//                             fontSize: 11,
//                             color: _textLight,
//                           ),
//                         ),
//                         const Spacer(),
//                         Text(
//                           '${site.polygon.length} pts',
//                           style: const TextStyle(
//                             fontSize: 11,
//                             color: _textLight,
//                           ),
//                         ),
//                       ],
//                     ),
//                     const SizedBox(height: 10),
//                   ],

//                   // Footer action row
//                   Row(
//                     children: [
//                       // Navigate button
//                       if (center != null) ...[
//                         GestureDetector(
//                           onTap: () => _openInMaps(site),
//                           child: Container(
//                             padding: const EdgeInsets.symmetric(
//                               horizontal: 10,
//                               vertical: 6,
//                             ),
//                             decoration: BoxDecoration(
//                               color: _accent.withOpacity(0.1),
//                               borderRadius: BorderRadius.circular(8),
//                               border: Border.all(
//                                 color: _accent.withOpacity(0.3),
//                               ),
//                             ),
//                             child: Row(
//                               mainAxisSize: MainAxisSize.min,
//                               children: [
//                                 Icon(
//                                   Icons.navigation_rounded,
//                                   size: 13,
//                                   color: _accent,
//                                 ),
//                                 const SizedBox(width: 5),
//                                 Text(
//                                   'Navigate',
//                                   style: TextStyle(
//                                     fontSize: 12,
//                                     color: _accent,
//                                     fontWeight: FontWeight.w600,
//                                   ),
//                                 ),
//                               ],
//                             ),
//                           ),
//                         ),
//                       ],
//                     ],
//                   ),
//                 ],
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   // ─── Reusable widgets ─────────────────────────────────────────────────────────

//   Widget _statusChip(_SiteStatus s) {
//     final label = switch (s) {
//       _SiteStatus.active => 'Active',
//       _SiteStatus.upcoming => 'Upcoming',
//       _SiteStatus.past => 'Past',
//       _ => 'Unknown',
//     };
//     final color = _statusColor(s);
//     return Container(
//       padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
//       decoration: BoxDecoration(
//         color: color.withOpacity(0.1),
//         borderRadius: BorderRadius.circular(20),
//         border: Border.all(color: color.withOpacity(0.3)),
//       ),
//       child: Row(
//         mainAxisSize: MainAxisSize.min,
//         children: [
//           Container(
//             width: 6,
//             height: 6,
//             decoration: BoxDecoration(color: color, shape: BoxShape.circle),
//           ),
//           const SizedBox(width: 5),
//           Text(
//             label,
//             style: TextStyle(
//               fontSize: 11,
//               fontWeight: FontWeight.w700,
//               color: color,
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _miniDate(IconData icon, String d, Color c) => Row(
//     mainAxisSize: MainAxisSize.min,
//     children: [
//       Icon(icon, size: 14, color: c),
//       const SizedBox(width: 4),
//       Text(
//         d,
//         style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: c),
//       ),
//     ],
//   );

//   Widget _dateBlock(String label, String value, Color color) => Expanded(
//     child: Column(
//       crossAxisAlignment: CrossAxisAlignment.center,
//       children: [
//         Text(
//           label,
//           style: const TextStyle(
//             fontSize: 11,
//             color: _textMid,
//             fontWeight: FontWeight.w500,
//           ),
//         ),
//         const SizedBox(height: 4),
//         Text(
//           value,
//           style: TextStyle(
//             fontSize: 14,
//             fontWeight: FontWeight.w700,
//             color: color,
//           ),
//         ),
//       ],
//     ),
//   );

//   // ─── Error / Empty ────────────────────────────────────────────────────────────

//   Widget _buildError(Responsive r) => Center(
//     child: Padding(
//       padding: EdgeInsets.symmetric(horizontal: r.hPad),
//       child: ConstrainedBox(
//         constraints: BoxConstraints(maxWidth: r.contentMaxWidth),
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             Container(
//               padding: const EdgeInsets.all(20),
//               decoration: BoxDecoration(
//                 color: _red.withOpacity(0.08),
//                 shape: BoxShape.circle,
//               ),
//               child: const Icon(Icons.wifi_off_rounded, color: _red, size: 40),
//             ),
//             const SizedBox(height: 16),
//             const Text(
//               'Failed to load sites',
//               style: TextStyle(
//                 fontSize: 17,
//                 fontWeight: FontWeight.w700,
//                 color: _textDark,
//               ),
//             ),
//             const SizedBox(height: 6),
//             Text(
//               _errorMessage!,
//               textAlign: TextAlign.center,
//               style: const TextStyle(color: _textMid, fontSize: 13),
//             ),
//             const SizedBox(height: 24),
//             FilledButton.icon(
//               onPressed: _fetchSites,
//               icon: const Icon(Icons.refresh_rounded, size: 18),
//               label: const Text('Try Again'),
//               style: FilledButton.styleFrom(
//                 backgroundColor: _primary,
//                 padding: const EdgeInsets.symmetric(
//                   horizontal: 24,
//                   vertical: 12,
//                 ),
//                 shape: RoundedRectangleBorder(
//                   borderRadius: BorderRadius.circular(12),
//                 ),
//               ),
//             ),
//           ],
//         ),
//       ),
//     ),
//   );

//   Widget _buildEmpty(Responsive r) => Padding(
//     padding: EdgeInsets.fromLTRB(r.hPad, 60, r.hPad, 60),
//     child: Center(
//       child: Column(
//         children: [
//           Container(
//             padding: const EdgeInsets.all(24),
//             decoration: BoxDecoration(
//               color: _primary.withOpacity(0.06),
//               shape: BoxShape.circle,
//             ),
//             child: const Icon(
//               Icons.location_off_rounded,
//               color: _textLight,
//               size: 44,
//             ),
//           ),
//           const SizedBox(height: 16),
//           const Text(
//             'No sites found',
//             style: TextStyle(
//               fontSize: 17,
//               fontWeight: FontWeight.w700,
//               color: _textDark,
//             ),
//           ),
//           const SizedBox(height: 6),
//           const Text(
//             'Pull down to refresh',
//             style: TextStyle(color: _textMid, fontSize: 13),
//           ),
//         ],
//       ),
//     ),
//   );
// }

// enum _SiteStatus { active, upcoming, past, unknown }
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_service.dart';
import 'responsive_utils.dart';

// ─── Model ────────────────────────────────────────────────────────────────────

class SiteModel {
  final int id;
  final String siteName;
  final List<Map<String, double>> polygon;
  final DateTime? startDate;
  final DateTime? endDate;
  final DateTime? createdAt;

  const SiteModel({
    required this.id,
    required this.siteName,
    required this.polygon,
    this.startDate,
    this.endDate,
    this.createdAt,
  });

  factory SiteModel.fromJson(Map<String, dynamic> json) {
    List<Map<String, double>> polygon = [];
    try {
      final raw = json['polygon_json'];
      final list = raw is String ? jsonDecode(raw) as List : raw as List;
      polygon = list
          .map<Map<String, double>>(
            (pt) => {
              'lat': (pt['lat'] as num).toDouble(),
              'lng': (pt['lng'] as num).toDouble(),
            },
          )
          .toList();
    } catch (_) {}

    return SiteModel(
      id: (json['id'] as num).toInt(),
      siteName: (json['site_name'] as String?) ?? 'Unnamed Site',
      polygon: polygon,
      startDate: _parseDate(json['start_date']),
      endDate: _parseDate(json['end_date']),
      createdAt: _parseDate(json['created_at']),
    );
  }

  static DateTime? _parseDate(dynamic v) {
    if (v == null || v.toString().isEmpty) return null;
    try {
      return DateTime.parse(v.toString());
    } catch (_) {
      return null;
    }
  }

  LatLng? get centroid {
    if (polygon.isEmpty) return null;
    final lat =
        polygon.map((p) => p['lat']!).reduce((a, b) => a + b) / polygon.length;
    final lng =
        polygon.map((p) => p['lng']!).reduce((a, b) => a + b) / polygon.length;
    return LatLng(lat, lng);
  }

  int get daysCount {
    if (startDate == null || endDate == null) return 0;
    return endDate!.difference(startDate!).inDays + 1;
  }
}

class LatLng {
  final double lat;
  final double lng;
  const LatLng(this.lat, this.lng);
}

// ─── Screen ───────────────────────────────────────────────────────────────────

class EmployeeAssignmentsScreen extends StatefulWidget {
  final int empId;
  const EmployeeAssignmentsScreen({super.key, required this.empId});

  @override
  State<EmployeeAssignmentsScreen> createState() =>
      _EmployeeAssignmentsScreenState();
}

class _EmployeeAssignmentsScreenState extends State<EmployeeAssignmentsScreen>
    with SingleTickerProviderStateMixin {
  List<SiteModel> _sites = [];
  bool _isLoading = true;
  String? _errorMessage;

  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;

  static const Color _primary = Color(0xFF1A56DB);
  static const Color _accent = Color(0xFF0E9F6E);
  static const Color _amber = Color(0xFFF59E0B);
  static const Color _red = Color(0xFFEF4444);
  static const Color _surface = Color(0xFFF0F4FF);
  static const Color _card = Colors.white;
  static const Color _textDark = Color(0xFF0F172A);
  static const Color _textMid = Color(0xFF64748B);
  static const Color _textLight = Color(0xFF94A3B8);
  static const Color _border = Color(0xFFE2E8F0);

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _fetchSites();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  // ─── Data ────────────────────────────────────────────────────────────────────

  Future<void> _fetchSites() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final raw = await ApiService.getSites();
      if (!mounted) return;
      final now = DateTime.now();
      final sites = (raw as List)
          .map((e) => SiteModel.fromJson(e as Map<String, dynamic>))
          // ── filter out past sites ──────────────────────────────────────────
          .where((s) {
            if (s.endDate == null) return true;
            return !s.endDate!.isBefore(
              DateTime(now.year, now.month, now.day), // compare date-only
            );
          })
          .toList();
      setState(() {
        _sites = sites;
        _isLoading = false;
      });
      _animCtrl.forward(from: 0);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Unable to load sites. Check your connection.';
      });
    }
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────────

  _SiteStatus _getStatus(SiteModel s) {
    final now = DateTime.now();
    if (s.startDate == null) return _SiteStatus.unknown;
    if (s.endDate != null && s.endDate!.isBefore(now)) return _SiteStatus.past;
    if (s.startDate!.isAfter(now)) return _SiteStatus.upcoming;
    return _SiteStatus.active;
  }

  Color _statusColor(_SiteStatus s) => switch (s) {
    _SiteStatus.active => _accent,
    _SiteStatus.upcoming => _amber,
    _SiteStatus.past => _textLight,
    _ => _textMid,
  };

  String _fmtDate(DateTime? d) =>
      d == null ? '-' : DateFormat('dd MMM yyyy').format(d);

  // ─── Maps ────────────────────────────────────────────────────────────────────

  Future<void> _openInMaps(SiteModel site) async {
    final center = site.centroid;
    if (center == null) {
      _showSnack('No location data for this site.');
      return;
    }
    final label = Uri.encodeComponent(site.siteName);
    final lat = center.lat;
    final lng = center.lng;
    final geoUri = Uri.parse('geo:$lat,$lng?q=$lat,$lng($label)');
    final webUrl = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$lat%2C$lng&query_place=$label',
    );
    if (await canLaunchUrl(geoUri)) {
      await launchUrl(geoUri, mode: LaunchMode.externalApplication);
    } else if (await canLaunchUrl(webUrl)) {
      await launchUrl(webUrl, mode: LaunchMode.externalApplication);
    } else {
      _showSnack('Could not open Maps on this device.');
    }
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  // ─── Bottom sheet (full details + navigate) ──────────────────────────────────

  void _showSiteDetails(SiteModel site, Responsive r) {
    final status = _getStatus(site);
    final center = site.centroid;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: r.isMobile ? 0.55 : 0.65,
        minChildSize: 0.35,
        maxChildSize: 0.92,
        builder: (_, ctrl) => Container(
          decoration: const BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: ListView(
                controller: ctrl,
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                children: [
                  // drag handle
                  Center(
                    child: Container(
                      margin: const EdgeInsets.only(top: 12, bottom: 20),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: _border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),

                  // ── Site name + status ──────────────────────────────────────
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEEF2FF),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.location_on_rounded,
                          color: _primary,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              site.siteName,
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: _textDark,
                              ),
                            ),
                            const SizedBox(height: 4),
                            _statusChip(status),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // ── Date range ──────────────────────────────────────────────
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: _surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _border),
                    ),
                    child: Row(
                      children: [
                        _dateBlock(
                          'Start Date',
                          _fmtDate(site.startDate),
                          _accent,
                        ),
                        const Expanded(
                          child: Column(
                            children: [
                              Icon(
                                Icons.arrow_forward_rounded,
                                color: _textLight,
                                size: 18,
                              ),
                            ],
                          ),
                        ),
                        _dateBlock('End Date', _fmtDate(site.endDate), _red),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // ── Days count + polygon info ───────────────────────────────
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: _primary.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _primary.withOpacity(0.15)),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.today_rounded,
                          color: _primary,
                          size: 18,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          '${site.daysCount} days total',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: _primary,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${site.polygon.length} boundary points',
                          style: const TextStyle(fontSize: 12, color: _textMid),
                        ),
                      ],
                    ),
                  ),

                  // ── Coordinates ────────────────────────────────────────────
                  if (center != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: _surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _border),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.my_location_rounded,
                            size: 16,
                            color: _textMid,
                          ),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Centre coordinates',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: _textMid,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${center.lat.toStringAsFixed(6)}, '
                                '${center.lng.toStringAsFixed(6)}',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: _textDark,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),

                  // ── Navigate button ────────────────────────────────────────
                  if (center != null)
                    FilledButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _openInMaps(site);
                      },
                      icon: const Icon(Icons.navigation_rounded, size: 18),
                      label: const Text('Navigate to Site'),
                      style: FilledButton.styleFrom(
                        backgroundColor: _primary,
                        minimumSize: const Size.fromHeight(50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: _red.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _red.withOpacity(0.2)),
                      ),
                      child: const Row(
                        children: [
                          Icon(
                            Icons.location_off_rounded,
                            color: _red,
                            size: 18,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'No polygon data — cannot navigate',
                            style: TextStyle(fontSize: 13, color: _red),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─── Root ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final r = Responsive.of(context);
    return Scaffold(
      backgroundColor: _surface,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _primary))
          : _errorMessage != null
          ? _buildError(r)
          : RefreshIndicator(
              onRefresh: _fetchSites,
              color: _primary,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  _buildAppBar(r),
                  SliverToBoxAdapter(child: _buildSummaryBar(r)),
                  SliverToBoxAdapter(child: _buildListHeader(r)),
                  if (_sites.isEmpty)
                    SliverToBoxAdapter(child: _buildEmpty(r))
                  else
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(r.hPad, 0, r.hPad, 32),
                      sliver: SliverToBoxAdapter(
                        child: Center(
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: r.contentMaxWidth,
                            ),
                            child: FadeTransition(
                              opacity: _fadeAnim,
                              child: r.useTwoColSections
                                  ? _buildGrid(r)
                                  : _buildList(r),
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

  // ─── Grid / List ─────────────────────────────────────────────────────────────

  Widget _buildGrid(Responsive r) {
    return LayoutBuilder(
      builder: (_, constraints) {
        final cols = r.isDesktop ? 3 : 2;
        const gap = 12.0;
        final itemW = (constraints.maxWidth - gap * (cols - 1)) / cols;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: List.generate(
            _sites.length,
            (i) => SizedBox(width: itemW, child: _buildCard(_sites[i], r)),
          ),
        );
      },
    );
  }

  Widget _buildList(Responsive r) => Column(
    children: List.generate(
      _sites.length,
      (i) => Padding(
        padding: EdgeInsets.only(top: i == 0 ? 0 : 10),
        child: _buildCard(_sites[i], r),
      ),
    ),
  );

  // ─── AppBar ───────────────────────────────────────────────────────────────────

  Widget _buildAppBar(Responsive r) => SliverAppBar(
    expandedHeight: r.appBarHeight,
    pinned: true,
    elevation: 0,
    backgroundColor: _primary,
    foregroundColor: Colors.white,
    actions: [
      IconButton(
        icon: const Icon(Icons.refresh_rounded),
        tooltip: 'Refresh',
        onPressed: _isLoading ? null : _fetchSites,
      ),
    ],
    flexibleSpace: FlexibleSpaceBar(
      collapseMode: CollapseMode.pin,
      background: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF1A56DB), Color(0xFF1E3A8A), Color(0xFF1e1b4b)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: -20,
              right: -20,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.05),
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(r.hPad, 0, 20, 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'My Sites',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Active & upcoming work sites',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.6),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  // ─── Summary bar ─────────────────────────────────────────────────────────────

  Widget _buildSummaryBar(Responsive r) {
    final active = _sites
        .where((s) => _getStatus(s) == _SiteStatus.active)
        .length;
    final upcoming = _sites
        .where((s) => _getStatus(s) == _SiteStatus.upcoming)
        .length;

    return Container(
      color: _primary,
      padding: EdgeInsets.fromLTRB(r.hPad, 0, r.hPad, 20),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: r.contentMaxWidth),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withOpacity(0.15)),
            ),
            child: Row(
              children: [
                _statItem('${_sites.length}', 'Total', Colors.white),
                _vDiv(),
                _statItem('$active', 'Active', const Color(0xFF6EE7B7)),
                _vDiv(),
                _statItem('$upcoming', 'Upcoming', const Color(0xFFFDE68A)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _statItem(String v, String l, Color c) => Expanded(
    child: Column(
      children: [
        Text(
          v,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: c),
        ),
        const SizedBox(height: 2),
        Text(
          l,
          style: TextStyle(
            fontSize: 10,
            color: c.withOpacity(0.75),
            letterSpacing: 0.4,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    ),
  );

  Widget _vDiv() =>
      Container(width: 1, height: 30, color: Colors.white.withOpacity(0.2));

  Widget _buildListHeader(Responsive r) => Padding(
    padding: EdgeInsets.fromLTRB(r.hPad, 20, r.hPad, 12),
    child: Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: r.contentMaxWidth),
        child: Row(
          children: [
            Container(
              width: 4,
              height: 20,
              decoration: BoxDecoration(
                color: _primary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'Site List',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: _textDark,
                letterSpacing: 0.1,
              ),
            ),
            const Spacer(),
            if (_sites.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${_sites.length} sites',
                  style: const TextStyle(
                    fontSize: 11,
                    color: _primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
  );

  // ─── Card — compact row: site name + from–to dates ───────────────────────────

  Widget _buildCard(SiteModel site, Responsive r) {
    final status = _getStatus(site);
    final color = _statusColor(status);

    return GestureDetector(
      onTap: () => _showSiteDetails(site, r),
      child: Container(
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(r.cardRadius),
          border: Border.all(color: _border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // coloured status bar at top
            Container(height: 3, color: color),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  // location icon
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEEF2FF),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.location_on_rounded,
                      color: _primary,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),

                  // site name + date range
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          site.siteName,
                          style: TextStyle(
                            fontSize: r.sectionTitleSize,
                            fontWeight: FontWeight.w700,
                            color: _textDark,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.calendar_today_rounded,
                              size: 11,
                              color: _textLight,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${_fmtDate(site.startDate)}  →  ${_fmtDate(site.endDate)}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: _textMid,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),

                  // status chip on the right
                  _statusChip(status),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Reusable widgets ─────────────────────────────────────────────────────────

  Widget _statusChip(_SiteStatus s) {
    final label = switch (s) {
      _SiteStatus.active => 'Active',
      _SiteStatus.upcoming => 'Upcoming',
      _SiteStatus.past => 'Past',
      _ => 'Unknown',
    };
    final color = _statusColor(s);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _dateBlock(String label, String value, Color color) => Expanded(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: _textMid,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    ),
  );

  // ─── Error / Empty ────────────────────────────────────────────────────────────

  Widget _buildError(Responsive r) => Center(
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
                color: _red.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.wifi_off_rounded, color: _red, size: 40),
            ),
            const SizedBox(height: 16),
            const Text(
              'Failed to load sites',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: _textDark,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: _textMid, fontSize: 13),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _fetchSites,
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

  Widget _buildEmpty(Responsive r) => Padding(
    padding: EdgeInsets.fromLTRB(r.hPad, 60, r.hPad, 60),
    child: Center(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: _primary.withOpacity(0.06),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.location_off_rounded,
              color: _textLight,
              size: 44,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'No active sites',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: _textDark,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Pull down to refresh',
            style: TextStyle(color: _textMid, fontSize: 13),
          ),
        ],
      ),
    ),
  );
}

enum _SiteStatus { active, upcoming, past, unknown }
