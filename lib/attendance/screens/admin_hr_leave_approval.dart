import 'package:flutter/material.dart';
import '../models/leavemodel.dart';
import '../services/leave_service.dart';

// Design Tokens — kept in sync with EmployeeProfileScreen

const Color _primary = Color(0xFF1A56DB);
const Color _accent = Color(0xFF0E9F6E);
const Color _purple = Color(0xFF7C3AED);
const Color _amber = Color(0xFFF59E0B);
const Color _red = Color(0xFFEF4444);
const Color _surface = Color(0xFFF0F4FF);
const Color _card = Colors.white;
const Color _textDark = Color(0xFF0F172A);
const Color _textMid = Color(0xFF64748B);
const Color _textLight = Color(0xFF94A3B8);
const Color _border = Color(0xFFE2E8F0);

// ─────────────────────────────────────────────────────────────────────────────
class LeaveApprovalScreen extends StatefulWidget {
  final int loginId;
  const LeaveApprovalScreen({super.key, required this.loginId});

  @override
  State<LeaveApprovalScreen> createState() => _LeaveApprovalScreenState();
}

class _LeaveApprovalScreenState extends State<LeaveApprovalScreen>
    with SingleTickerProviderStateMixin {
  final LeaveService _leaveService = LeaveService();
  late TabController _tabController;

  List<LeaveModel> _pendingLeaves = [];
  List<LeaveModel> _historyLeaves = [];
  bool _pendingLoading = true;
  bool _historyLoading = true;
  String? _pendingError;
  String? _historyError;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadAll();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAll() => Future.wait([_loadPending(), _loadHistory()]);

  Future<void> _loadPending() async {
    setState(() {
      _pendingLoading = true;
      _pendingError = null;
    });
    try {
      final data = await _leaveService.getAllPendingLeaves();
      if (mounted) setState(() => _pendingLeaves = data);
    } catch (e) {
      if (mounted) setState(() => _pendingError = '$e');
    } finally {
      if (mounted) setState(() => _pendingLoading = false);
    }
  }

  Future<void> _loadHistory() async {
    setState(() {
      _historyLoading = true;
      _historyError = null;
    });
    try {
      final data = await _leaveService.getAllLeavesHistory();
      if (mounted) setState(() => _historyLeaves = data);
    } catch (e) {
      if (mounted) setState(() => _historyError = '$e');
    } finally {
      if (mounted) setState(() => _historyLoading = false);
    }
  }

  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')} ${_mon(d.month)} ${d.year}';

  String _mon(int m) => const [
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
  ][m];

  // ── Build ───────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surface,
      appBar: _buildAppBar(),
      body: TabBarView(
        controller: _tabController,
        physics: const NeverScrollableScrollPhysics(),
        children: [_buildPendingTab(), _buildHistoryTab()],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return PreferredSize(
      preferredSize: const Size.fromHeight(130), // 🔥 increased height
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color.fromARGB(255, 255, 255, 255),
              Color.fromARGB(255, 255, 255, 255),
              Color.fromARGB(255, 255, 255, 255),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: Color(0x401A56DB),
              blurRadius: 14,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min, // 🔥 important
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 12, 0),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.approval_rounded,
                        color: Color.fromARGB(255, 0, 0, 0),
                        size: 19,
                      ),
                    ),
                    const SizedBox(width: 12),

                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min, // 🔥 prevents overflow
                        children: const [
                          Text(
                            'Leave Approval',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: Color.fromARGB(255, 0, 0, 0),
                            ),
                          ),
                          Text(
                            'Review & manage leave requests',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              color: Color.fromARGB(143, 0, 0, 0),
                            ),
                          ),
                        ],
                      ),
                    ),

                    IconButton(
                      icon: const Icon(Icons.refresh_rounded),
                      color: const Color.fromARGB(255, 0, 0, 0),
                      onPressed: _loadPending,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 6),

              /// 🔥 Prevent TabBar overflow
              Flexible(
                child: TabBar(
                  controller: _tabController,
                  indicator: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  indicatorPadding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 4,
                  ),
                  labelColor: const Color.fromARGB(255, 0, 0, 0),
                  unselectedLabelColor: const Color.fromARGB(137, 0, 0, 0),
                  tabs: [
                    _buildTab(
                      Icons.pending_actions_outlined,
                      'Pending',
                      _pendingLeaves.length,
                    ),
                    _buildTab(Icons.history_rounded, 'History', null),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  } // PreferredSizeWidget _buildAppBar() {
  //   return PreferredSize(
  //     preferredSize: const Size.fromHeight(108),
  //     child: Container(
  //       decoration: const BoxDecoration(
  //         gradient: LinearGradient(
  //           colors: [Color(0xFF1A56DB), Color(0xFF1E3A8A), Color(0xFF1e1b4b)],
  //           begin: Alignment.topLeft,
  //           end: Alignment.bottomRight,
  //         ),
  //         boxShadow: [
  //           BoxShadow(
  //             color: Color(0x401A56DB),
  //             blurRadius: 14,
  //             offset: Offset(0, 4),
  //           ),
  //         ],
  //       ),
  //       child: SafeArea(
  //         child: Column(
  //           children: [
  //             Padding(
  //               padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
  //               child: Row(
  //                 children: [
  //                   Container(
  //                     width: 36,
  //                     height: 36,
  //                     decoration: BoxDecoration(
  //                       color: Colors.white.withOpacity(0.15),
  //                       borderRadius: BorderRadius.circular(10),
  //                     ),
  //                     child: const Icon(
  //                       Icons.approval_rounded,
  //                       color: Colors.white,
  //                       size: 19,
  //                     ),
  //                   ),
  //                   const SizedBox(width: 12),
  //                   const Column(
  //                     crossAxisAlignment: CrossAxisAlignment.start,
  //                     children: [
  //                       Text(
  //                         'Leave Approval',
  //                         style: TextStyle(
  //                           fontSize: 17,
  //                           fontWeight: FontWeight.w700,
  //                           color: Colors.white,
  //                           letterSpacing: 0.2,
  //                         ),
  //                       ),
  //                       Text(
  //                         'Review & manage leave requests',
  //                         style: TextStyle(fontSize: 11, color: Colors.white60),
  //                       ),

  //                     ],

  //                   ),
  //                 ],
  //               ),

  //             ),
  //             const SizedBox(height: 8),
  //             TabBar(
  //               controller: _tabController,
  //               indicator: BoxDecoration(
  //                 borderRadius: BorderRadius.circular(8),
  //               ),
  //               indicatorPadding: const EdgeInsets.symmetric(
  //                 horizontal: 4,
  //                 vertical: 4,
  //               ),
  //               labelColor: Colors.white,
  //               unselectedLabelColor: Colors.white54,
  //               labelStyle: const TextStyle(
  //                 fontWeight: FontWeight.w600,
  //                 fontSize: 13,
  //               ),
  //               unselectedLabelStyle: const TextStyle(
  //                 fontWeight: FontWeight.w500,
  //                 fontSize: 13,
  //               ),
  //               tabs: [
  //                 _buildTab(
  //                   Icons.pending_actions_outlined,
  //                   'Pending',
  //                   _pendingLeaves.length,
  //                 ),
  //                 _buildTab(Icons.history_rounded, 'History', null),
  //               ],
  //             ),
  //           ],
  //         ),
  //       ),
  //     ),
  //   );
  // }

  Tab _buildTab(IconData icon, String label, int? count) => Tab(
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16),
        const SizedBox(width: 6),
        Text(label),
        if (count != null && count > 0) ...[
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$count',
              style: const TextStyle(
                fontSize: 10,
                color: _primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ],
    ),
  );

  // TAB 1 — PENDING

  Widget _buildPendingTab() {
    if (_pendingLoading) return _loader();
    if (_pendingError != null) return _error(_pendingError!, _loadPending);
    if (_pendingLeaves.isEmpty) {
      return _empty(
        icon: Icons.inbox_outlined,
        title: 'All clear!',
        subtitle: 'No pending leave requests right now.',
        onRefresh: _loadPending,
      );
    }
    return RefreshIndicator(
      onRefresh: _loadPending,
      color: _primary,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860),
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
            itemCount: _pendingLeaves.length,
            itemBuilder: (_, i) => _PendingCard(
              leave: _pendingLeaves[i],
              fmt: _fmt,
              onApprove: (l) {
                if (l.status == 'Pending_TL') {
                  _handleLeaveAction(l, 'recommend');
                } else if (l.status == 'Pending_Manager') {
                  _handleLeaveAction(l, 'Approved'); // final approval
                }
              },
              onReject: (l) => _showRejectionDialog(l),
            ),
          ),
        ),
      ),
    );
  }

  // TAB 2 — HISTORY
  Widget _buildHistoryTab() {
    if (_historyLoading) return _loader();
    if (_historyError != null) return _error(_historyError!, _loadHistory);
    if (_historyLeaves.isEmpty) {
      return _empty(
        icon: Icons.history_toggle_off_rounded,
        title: 'No records yet',
        subtitle: 'Leave history will appear here.',
        onRefresh: _loadHistory,
      );
    }
    return RefreshIndicator(
      onRefresh: _loadHistory,
      color: _primary,
      child: LayoutBuilder(
        builder: (ctx, cs) => cs.maxWidth >= 860
            ? _DesktopHistory(leaves: _historyLeaves, fmt: _fmt)
            : _MobileHistory(leaves: _historyLeaves, fmt: _fmt),
      ),
    );
  }

  // ── Shared state widgets ──────────────────────────────────────────────────
  Widget _loader() => const Center(
    child: CircularProgressIndicator(color: _primary, strokeWidth: 2.5),
  );

  Widget _error(String msg, VoidCallback retry) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _red.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.wifi_off_rounded, color: _red, size: 28),
          ),
          const SizedBox(height: 16),
          const Text(
            'Something went wrong',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: _textDark,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            msg,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: _textMid),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: retry,
            style: FilledButton.styleFrom(
              backgroundColor: _primary,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: const Text(
              'Try Again',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _empty({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onRefresh,
  }) => RefreshIndicator(
    onRefresh: () async => onRefresh(),
    color: _primary,
    child: CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverFillRemaining(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: _primary.withOpacity(0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 36, color: _primary),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: _textDark,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 13, color: _textMid),
              ),
              const SizedBox(height: 20),
              TextButton.icon(
                onPressed: onRefresh,
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Refresh'),
                style: TextButton.styleFrom(
                  foregroundColor: _primary,
                  textStyle: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  // ── Dialogs & Actions ─────────────────────────────────────────────────────
  void _showRejectionDialog(LeaveModel leave) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      barrierColor: Colors.black38,
      builder: (_) => AlertDialog(
        backgroundColor: _card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
        contentPadding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
        actionsPadding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _red.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.do_not_disturb_on_rounded,
                color: _red,
                size: 18,
              ),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Reject Leave Request',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: _textDark,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Reason for rejection',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _textMid,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: ctrl,
              maxLines: 3,
              style: const TextStyle(fontSize: 13, color: _textDark),
              decoration: InputDecoration(
                hintText: 'Briefly describe the reason…',
                hintStyle: const TextStyle(color: _textLight, fontSize: 13),
                filled: true,
                fillColor: _surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: _border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: _border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: _primary, width: 1.5),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
              ),
            ),
          ],
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(context),
            style: OutlinedButton.styleFrom(
              foregroundColor: _textMid,
              side: const BorderSide(color: _border),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(9),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            ),
            child: const Text(
              'Cancel',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: _red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(9),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            ),
            onPressed: () {
              final reason = ctrl.text.trim();
              if (reason.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter a rejection reason'),
                  ),
                );
                return;
              }
              Navigator.pop(context);
              String status;

              if (leave.status == 'Pending_TL') {
                status = 'Not_Recommended_By_TL';
              } else if (leave.status == 'Pending_Manager ') {
                status = 'Rejected_By_HR';
              } else {
                status = 'Rejected_By_Manager';
              }

              _handleLeaveAction(leave, status, rejectionReason: reason);
            },
            child: const Text(
              'Reject',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleLeaveAction(
    LeaveModel leave,
    String status, {
    String? rejectionReason,
  }) async {
    final ok = await _leaveService.managerLeaveAction(
      leaveId: leave.leaveId!,
      status: status,
      loginId: widget.loginId,
      rejectionReason: rejectionReason,
    );
    if (!mounted) return;
    final approved = status == 'Approved';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              ok
                  ? (approved
                        ? Icons.check_circle_rounded
                        : Icons.cancel_rounded)
                  : Icons.error_rounded,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 8),
            Text(
              ok
                  ? (approved
                        ? 'Leave approved successfully'
                        : 'Leave rejected')
                  : 'Action failed. Please try again.',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ],
        ),
        backgroundColor: ok ? (approved ? _accent : _red) : _red,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 3),
      ),
    );
    if (ok) _loadAll();
  }
}

// Pending Card

class _PendingCard extends StatelessWidget {
  final LeaveModel leave;
  final String Function(DateTime) fmt;
  final void Function(LeaveModel) onApprove;
  final void Function(LeaveModel) onReject;

  const _PendingCard({
    required this.leave,
    required this.fmt,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final isPendingManager = leave.status == 'Pending_Manager';
    final isPendingTL = leave.status == 'Pending_TL';
    final insufficient =
        leave.remainingDays != null &&
        leave.remainingDays! < leave.numberOfDays;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // ── Header ───────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1A56DB), Color(0xFF1E3A8A)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      (leave.employeeName ?? '?').substring(0, 1).toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        leave.employeeName ?? 'Employee #${leave.empId}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: _textDark,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        [
                          leave.departmentName,
                          leave.roleName,
                        ].where((e) => e != null && e.isNotEmpty).join('  ·  '),
                        style: const TextStyle(fontSize: 12, color: _textMid),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _StatusBadge(leave.status),
              ],
            ),
          ),

          const Divider(height: 1, thickness: 1, color: _border),

          // ── Info grid ─────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Column(
              children: [
                Row(
                  children: [
                    _InfoCell(
                      icon: Icons.badge_outlined,
                      label: 'Emp ID',
                      value: leave.empId.toString(),
                    ),
                    const SizedBox(width: 10),
                    _InfoCell(
                      icon: Icons.category_outlined,
                      label: 'Leave Type',
                      value: leave.leaveType,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _InfoCell(
                      icon: Icons.calendar_today_outlined,
                      label: 'From',
                      value: fmt(leave.fromDate),
                    ),
                    const SizedBox(width: 10),
                    _InfoCell(
                      icon: Icons.event_outlined,
                      label: 'To',
                      value: fmt(leave.toDate),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _InfoCell(
                      icon: Icons.today_outlined,
                      label: 'Total Days',
                      value: '${leave.numberOfDays} day(s)',
                    ),
                    const SizedBox(width: 10),
                    _InfoCell(
                      icon: Icons.account_balance_wallet_outlined,
                      label: 'Balance',
                      value: '${leave.remainingDays ?? 0} remaining',
                      valueColor: insufficient ? _red : null,
                    ),
                  ],
                ),
                if (leave.reason != null && leave.reason!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: _surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _border),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.notes_rounded,
                          size: 14,
                          color: _textMid,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            leave.reason!,
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: _textDark,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          // ── Banners & actions ─────────────────────────────────────────
          if (isPendingTL || isPendingManager) ...[
            const Divider(height: 1, thickness: 1, color: _border),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
              child: Column(
                children: [
                  if (leave.status == 'Pending_Manager ')
                    _Banner(
                      icon: Icons.people_alt_rounded,
                      message: 'Awaiting HR review',
                      color: _purple,
                      bg: Color(0xFFF3E8FF),
                      borderColor: Color(0xFFD8B4FE),
                    ),
                  if (isPendingManager && insufficient) ...[
                    _Banner(
                      icon: Icons.warning_amber_rounded,
                      message:
                          'Insufficient balance — only ${leave.remainingDays} day(s) remaining',
                      color: const Color(0xFF92400E),
                      bg: const Color(0xFFFFFBEB),
                      borderColor: const Color(0xFFFCD34D),
                    ),
                    const SizedBox(height: 8),
                  ],
                  if (isPendingManager) ...[
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _red,
                            side: BorderSide(color: _red.withOpacity(0.5)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(9),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 9,
                            ),
                          ),
                          icon: const Icon(Icons.close_rounded, size: 15),
                          label: const Text(
                            'Reject',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          onPressed: () => onReject(leave),
                        ),
                        const SizedBox(width: 10),
                        FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: insufficient
                                ? _textLight
                                : _accent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(9),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 9,
                            ),
                          ),
                          icon: const Icon(Icons.check_rounded, size: 15),
                          label: const Text(
                            'Approve',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          onPressed: insufficient
                              ? null
                              : () => onApprove(leave),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// Mobile History

class _MobileHistory extends StatefulWidget {
  final List<LeaveModel> leaves;
  final String Function(DateTime) fmt;
  const _MobileHistory({required this.leaves, required this.fmt});

  @override
  State<_MobileHistory> createState() => _MobileHistoryState();
}

class _MobileHistoryState extends State<_MobileHistory> {
  final Set<int> _expanded = {};

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
      itemCount: widget.leaves.length,
      itemBuilder: (_, i) {
        final l = widget.leaves[i];
        final isOpen = _expanded.contains(i);
        final accentColor = _statusColor(l.status);

        final hasEmployeeReason = l.reason?.isNotEmpty == true;
        final hasRejection = l.rejectionReason?.isNotEmpty == true;
        final hasCancelReason = l.cancelReason?.isNotEmpty == true;
        final hasApprovedBy = l.approvedBy?.isNotEmpty == true;

        final hasAnyDetail =
            hasEmployeeReason ||
            hasRejection ||
            hasCancelReason ||
            hasApprovedBy;

        return GestureDetector(
          onTap: hasAnyDetail
              ? () => setState(
                  () => isOpen ? _expanded.remove(i) : _expanded.add(i),
                )
              : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeInOut,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: _card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isOpen ? accentColor.withOpacity(0.4) : _border,
                width: isOpen ? 1.5 : 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: isOpen
                      ? accentColor.withOpacity(0.08)
                      : Colors.black.withOpacity(0.04),
                  blurRadius: isOpen ? 14 : 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(width: 4, color: accentColor),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ───────── Summary ─────────
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 13, 12, 13),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            /// LEFT SIDE (Employee + Leave Info)
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    l.employeeName ?? 'Emp #${l.empId}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: _textDark,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${l.leaveType}  ·  '
                                    '${widget.fmt(l.fromDate)} – ${widget.fmt(l.toDate)}'
                                    '  ·  ${l.numberOfDays} day(s)',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: _textMid,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(width: 8),

                            /// RIGHT SIDE (Status + Arrow)
                            Flexible(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  _StatusBadge(l.status),

                                  if (hasAnyDetail) ...[
                                    const SizedBox(height: 6),
                                    AnimatedRotation(
                                      turns: isOpen ? 0.5 : 0,
                                      duration: const Duration(
                                        milliseconds: 220,
                                      ),
                                      child: Icon(
                                        Icons.keyboard_arrow_down_rounded,
                                        size: 18,
                                        color: isOpen
                                            ? accentColor
                                            : _textLight,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      /// ───────── Expandable Details ─────────
                      AnimatedCrossFade(
                        duration: const Duration(milliseconds: 220),
                        sizeCurve: Curves.easeInOut,
                        crossFadeState: isOpen
                            ? CrossFadeState.showSecond
                            : CrossFadeState.showFirst,
                        firstChild: const SizedBox.shrink(),
                        secondChild: _ReasonSection(leave: l),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _DesktopHistory extends StatefulWidget {
  final List<LeaveModel> leaves;
  final String Function(DateTime) fmt;

  static const List<int> _flex = [3, 2, 3, 1, 2, 2];
  static const List<String> _headers = [
    'Employee',
    'Leave Type',
    'Duration',
    'Days',
    'Status',
    'Processed By',
  ];

  const _DesktopHistory({required this.leaves, required this.fmt});

  @override
  State<_DesktopHistory> createState() => _DesktopHistoryState();
}

class _DesktopHistoryState extends State<_DesktopHistory> {
  final Set<int> _expanded = {};

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Container(
            decoration: BoxDecoration(
              color: _card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header row ───────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 13,
                    horizontal: 20,
                  ),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Color(0xFF1A56DB),
                        Color(0xFF1E3A8A),
                        Color(0xFF1e1b4b),
                      ],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                  ),
                  child: Row(
                    children: [
                      // Extra space for the expand icon column
                      const SizedBox(width: 28),
                      ...List.generate(_DesktopHistory._headers.length, (i) {
                        return Expanded(
                          flex: _DesktopHistory._flex[i],
                          child: Text(
                            _DesktopHistory._headers[i],
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                              letterSpacing: 0.4,
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),

                // ── Data rows ────────────────────────────────────────────
                ...widget.leaves.asMap().entries.map((e) {
                  final i = e.key;
                  final l = e.value;
                  final isOpen = _expanded.contains(i);
                  final accentColor = _statusColor(l.status);

                  final hasAnyDetail =
                      l.reason?.isNotEmpty == true ||
                      l.rejectionReason?.isNotEmpty == true ||
                      l.cancelReason?.isNotEmpty == true ||
                      l.approvedBy?.isNotEmpty == true;

                  return Column(
                    children: [
                      // ── Main row ────────────────────────────────────
                      InkWell(
                        onTap: hasAnyDetail
                            ? () => setState(
                                () => isOpen
                                    ? _expanded.remove(i)
                                    : _expanded.add(i),
                              )
                            : null,
                        child: Container(
                          decoration: BoxDecoration(
                            color: isOpen
                                ? accentColor.withOpacity(0.04)
                                : (i.isEven ? _card : const Color(0xFFF8FAFF)),
                            border: Border(
                              bottom: BorderSide(
                                color: isOpen
                                    ? accentColor.withOpacity(0.2)
                                    : _border,
                                width: 1,
                              ),
                              left: BorderSide(
                                color: isOpen
                                    ? accentColor
                                    : Colors.transparent,
                                width: 3,
                              ),
                            ),
                          ),
                          padding: const EdgeInsets.symmetric(
                            vertical: 12,
                            horizontal: 20,
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // Expand chevron
                              SizedBox(
                                width: 28,
                                child: hasAnyDetail
                                    ? AnimatedRotation(
                                        turns: isOpen ? 0.5 : 0,
                                        duration: const Duration(
                                          milliseconds: 200,
                                        ),
                                        child: Icon(
                                          Icons.keyboard_arrow_down_rounded,
                                          size: 18,
                                          color: isOpen
                                              ? accentColor
                                              : _textLight,
                                        ),
                                      )
                                    : const SizedBox.shrink(),
                              ),

                              // Employee
                              Expanded(
                                flex: _DesktopHistory._flex[0],
                                child: Row(
                                  children: [
                                    Container(
                                      width: 32,
                                      height: 32,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFEEF2FF),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Center(
                                        child: Text(
                                          (l.employeeName ?? '?')
                                              .substring(0, 1)
                                              .toUpperCase(),
                                          style: const TextStyle(
                                            color: _primary,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        l.employeeName ?? 'Emp #${l.empId}',
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
                              ),

                              // Leave Type
                              Expanded(
                                flex: _DesktopHistory._flex[1],
                                child: Text(
                                  l.leaveType,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: _textDark,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),

                              // Duration
                              Expanded(
                                flex: _DesktopHistory._flex[2],
                                child: Text(
                                  '${widget.fmt(l.fromDate)} – ${widget.fmt(l.toDate)}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: _textMid,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),

                              // Days
                              Expanded(
                                flex: _DesktopHistory._flex[3],
                                child: Text(
                                  '${l.numberOfDays}',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: _textDark,
                                  ),
                                ),
                              ),

                              // Status
                              Expanded(
                                flex: _DesktopHistory._flex[4],
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: _StatusBadge(l.status),
                                ),
                              ),

                              // Processed By
                              Expanded(
                                flex: _DesktopHistory._flex[5],
                                child: Text(
                                  l.approvedBy ?? '—',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: _textMid,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // ── Expanded reason panel ───────────────────────
                      AnimatedCrossFade(
                        duration: const Duration(milliseconds: 220),
                        sizeCurve: Curves.easeInOut,
                        crossFadeState: isOpen
                            ? CrossFadeState.showSecond
                            : CrossFadeState.showFirst,
                        firstChild: const SizedBox.shrink(),
                        secondChild: Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: accentColor.withOpacity(0.03),
                            border: Border(
                              bottom: BorderSide(color: _border),
                              left: BorderSide(color: accentColor, width: 3),
                            ),
                          ),
                          padding: const EdgeInsets.fromLTRB(52, 12, 20, 16),
                          child: _ReasonSection(leave: l),
                        ),
                      ),
                    ],
                  );
                }),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DesktopRow extends StatelessWidget {
  final LeaveModel leave;
  final String Function(DateTime) fmt;
  final bool isEven;

  static const List<int> _flex = [3, 2, 3, 1, 2, 2];

  const _DesktopRow({
    required this.leave,
    required this.fmt,
    required this.isEven,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isEven ? _card : const Color(0xFFF8FAFF),
        border: const Border(bottom: BorderSide(color: _border, width: 1)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Employee
          Expanded(
            flex: _flex[0],
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEF2FF),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      (leave.employeeName ?? '?').substring(0, 1).toUpperCase(),
                      style: const TextStyle(
                        color: _primary,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    leave.employeeName ?? 'Emp #${leave.empId}',
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
          ),
          // Leave Type
          Expanded(
            flex: _flex[1],
            child: Text(
              leave.leaveType,
              style: const TextStyle(fontSize: 13, color: _textDark),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Duration
          Expanded(
            flex: _flex[2],
            child: Text(
              '${fmt(leave.fromDate)} – ${fmt(leave.toDate)}',
              style: const TextStyle(fontSize: 12, color: _textMid),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Days
          Expanded(
            flex: _flex[3],
            child: Text(
              '${leave.numberOfDays}',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: _textDark,
              ),
            ),
          ),
          // Status — Align left so chip stays compact
          Expanded(
            flex: _flex[4],
            child: Align(
              alignment: Alignment.centerLeft,
              child: _StatusBadge(leave.status),
            ),
          ),
          // Processed By
          Expanded(
            flex: _flex[5],
            child: Text(
              leave.approvedBy ?? '—',
              style: const TextStyle(fontSize: 13, color: _textMid),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// Shared micro-components
/// Compact status badge — mainAxisSize.min prevents stretching.
class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge(this.status);

  @override
  Widget build(BuildContext context) {
    final c = _statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: c.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.withOpacity(0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min, // ← prevents full-width stretch
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: c, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            _statusLabel(status),
            style: TextStyle(
              color: c,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

String _statusLabel(String s) {
  switch (s) {
    case 'Pending_TL':
      return 'Awaiting TL';

    case 'Pending_Manager':
      return 'Awaiting Manager'; // ✅ ADD

    case 'Approved':
      return 'Approved';

    case 'Rejected_By_HR':
      return 'Rejected by HR'; // ✅ ADD

    case 'Rejected_By_Manager':
      return 'Rejected by Manager';

    case 'Not_Recommended_By_TL':
      return 'Not Recommended';

    case 'Cancelled':
      return 'Cancelled';

    default:
      return s;
  }
}

Color _statusColor(String s) {
  switch (s) {
    case 'Approved':
      return _accent; // green
    case 'Rejected_By_Manager':
    case 'Rejected_By_TL':
      return _red;
    case 'Not_Recommended_By_TL':
      return _red;
    case 'Cancelled':
      return _amber;
    case 'Pending_Manager':
      return _purple;
    case 'Pending_TL':
    default:
      return _primary; // blue
  }
}

/// Info cell — matches EmployeeProfileScreen label/value tile style.
class _InfoCell extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _InfoCell({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _border),
        ),
        child: Row(
          children: [
            Icon(icon, size: 14, color: _textMid),
            const SizedBox(width: 7),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 10,
                      color: _textMid,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: valueColor ?? _textDark,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  final IconData icon;
  final String message;
  final Color color, bg, borderColor;

  const _Banner({
    required this.icon,
    required this.message,
    required this.color,
    required this.bg,
    required this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: color,
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReasonSection extends StatelessWidget {
  final LeaveModel leave;
  const _ReasonSection({required this.leave});

  @override
  Widget build(BuildContext context) {
    final tiles = <Widget>[];

    // 1 — Employee's own reason
    if (leave.reason?.isNotEmpty == true) {
      tiles.add(
        _ReasonTile(
          icon: Icons.person_outline_rounded,
          label: 'Employee Reason',
          text: leave.reason!,
          iconColor: _primary,
          iconBg: const Color(0xFFEEF2FF),
          textColor: _textDark,
        ),
      );
    }

    // 2 — TL rejection
    if (leave.status == 'Not_Recommended_By_TL' &&
        leave.rejectionReason?.isNotEmpty == true) {
      tiles.add(
        _ReasonTile(
          icon: Icons.supervisor_account_outlined,
          label: 'Rejected by Team Lead',
          text: leave.rejectionReason!,
          iconColor: _red,
          iconBg: const Color(0xFFFEE2E2),
          textColor: _red,
        ),
      );
    }

    // 3 — HR rejection
    if (leave.status == 'Rejected_By_HR' &&
        leave.rejectionReason?.isNotEmpty == true) {
      tiles.add(
        _ReasonTile(
          icon: Icons.admin_panel_settings_outlined,
          label: 'Rejected by HR',
          text: leave.rejectionReason!,
          iconColor: _red,
          iconBg: const Color(0xFFFEE2E2),
          textColor: _red,
        ),
      );
    }

    if (leave.status == 'Pending_Manager') {
      tiles.add(
        _ReasonTile(
          icon: Icons.schedule_outlined,
          label: 'Waiting for Manager Approval',
          text:
              'This leave has been reviewed by HR and is pending final approval.',
          iconColor: _purple,
          iconBg: const Color(0xFFF3E8FF),
          textColor: _textDark,
        ),
      );
    }

    if (leave.status == 'Rejected_By_Manager' &&
        leave.rejectionReason?.isNotEmpty == true) {
      tiles.add(
        _ReasonTile(
          icon: Icons.business_center_outlined,
          label: 'Rejected by Manager',
          text: leave.rejectionReason!,
          iconColor: _red,
          iconBg: const Color(0xFFFEE2E2),
          textColor: _red,
        ),
      );
    }
    // 4 — Cancel reason
    if (leave.cancelReason?.isNotEmpty == true) {
      tiles.add(
        _ReasonTile(
          icon: Icons.cancel_outlined,
          label: 'Cancelled – Reason',
          text: leave.cancelReason!,
          iconColor: _amber,
          iconBg: const Color(0xFFFFF8E1),
          textColor: const Color(0xFF92400E),
        ),
      );
    }

    // // 5 — Approved by (only show on approved, non-rejection statuses)
    // if (leave.status == 'Approved' && leave.approvedBy?.isNotEmpty == true) {
    //   tiles.add(
    //     _ReasonTile(
    //       icon: Icons.verified_outlined,
    //       label: 'Approved by HR',
    //       text: leave.approvedBy!,
    //       iconColor: _accent,
    //       iconBg: const Color(0xFFD1FAE5),
    //       textColor: _textDark,
    //     ),
    //   );
    // }

    if (tiles.isEmpty) return const SizedBox.shrink();

    // On desktop, lay tiles out in a wrap (side by side if space allows)
    return LayoutBuilder(
      builder: (ctx, cs) {
        final isDesktop = cs.maxWidth > 500;
        if (isDesktop) {
          return Wrap(
            spacing: 10,
            runSpacing: 10,
            children: tiles
                .map(
                  (t) => SizedBox(
                    width:
                        (cs.maxWidth - (tiles.length > 1 ? 10 : 0)) /
                        (tiles.length > 2
                            ? 3
                            : tiles.length > 1
                            ? 2
                            : 1),
                    child: t,
                  ),
                )
                .toList(),
          );
        }
        // Mobile: stack vertically
        return Column(
          children: [
            for (int i = 0; i < tiles.length; i++) ...[
              if (i > 0) const SizedBox(height: 8),
              tiles[i],
            ],
          ],
        );
      },
    );
  }
}

class _ReasonTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String text;
  final Color iconColor;
  final Color iconBg;
  final Color textColor;

  const _ReasonTile({
    required this.icon,
    required this.label,
    required this.text,
    required this.iconColor,
    required this.iconBg,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: iconBg.withOpacity(0.5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: iconColor.withOpacity(0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 14, color: iconColor),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: iconColor,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  text,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: textColor,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
