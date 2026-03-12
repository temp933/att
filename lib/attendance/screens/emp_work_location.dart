import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import '../models/asign_location.dart';
import '../services/asign_location_services.dart';
import 'responsive_utils.dart';

class EmployeeAssignmentsScreen extends StatefulWidget {
  final int empId;
  const EmployeeAssignmentsScreen({super.key, required this.empId});

  @override
  State<EmployeeAssignmentsScreen> createState() =>
      _EmployeeAssignmentsScreenState();
}

class _EmployeeAssignmentsScreenState extends State<EmployeeAssignmentsScreen>
    with SingleTickerProviderStateMixin {
  List<AssignLocationModel> assignments = [];
  bool isLoading = true;
  String? errorMessage;

  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;

  // ─── Design Tokens ───────────────────────────────────────────────────────────
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
    fetchAssignments();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> fetchAssignments() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });
    try {
      final data = await AssignLocationService.getEmployeeAssignments(
        widget.empId,
      );
      if (!mounted) return;
      setState(() {
        assignments = data;
        isLoading = false;
      });
      _animCtrl.forward(from: 0);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        isLoading = false;
        errorMessage = 'Unable to load assignments. Check your connection.';
      });
    }
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────────
  String _fmtDate(DateTime? d) =>
      d == null ? '-' : DateFormat('dd MMM yyyy').format(d);
  String _fmtShort(DateTime? d) =>
      d == null ? '-' : DateFormat('dd MMM').format(d);

  _AssignStatus _getStatus(AssignLocationModel a) {
    final now = DateTime.now();
    if (a.startDate == null) return _AssignStatus.unknown;
    if (a.endDate != null && a.endDate!.isBefore(now))
      return _AssignStatus.past;
    if (a.startDate!.isAfter(now)) return _AssignStatus.upcoming;
    return _AssignStatus.active;
  }

  Color _statusColor(_AssignStatus s) {
    switch (s) {
      case _AssignStatus.active:
        return _accent;
      case _AssignStatus.upcoming:
        return _amber;
      case _AssignStatus.past:
        return _textLight;
      default:
        return _textMid;
    }
  }

  void _showWorkDetails(AssignLocationModel a, Responsive r) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: r.isMobile ? 0.5 : 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
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
                              a.locationName ?? '-',
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: _textDark,
                              ),
                            ),
                            const SizedBox(height: 2),
                            _statusChip(_getStatus(a)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // Date range
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
                          _fmtDate(a.startDate),
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
                        _dateBlock('End Date', _fmtDate(a.endDate), _red),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
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
                          '${a.daysCount ?? 0} days assigned',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: _primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'About Work',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _textMid,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: _surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _border),
                    ),
                    child: Text(
                      a.aboutWork?.isNotEmpty == true
                          ? a.aboutWork!
                          : 'No details provided.',
                      style: const TextStyle(
                        fontSize: 14,
                        color: _textDark,
                        height: 1.6,
                      ),
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
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: _primary))
          : errorMessage != null
          ? _buildError(r)
          : RefreshIndicator(
              onRefresh: fetchAssignments,
              color: _primary,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  _buildAppBar(r),
                  SliverToBoxAdapter(child: _buildSummaryBar(r)),
                  SliverToBoxAdapter(child: _buildHistoryHeader(r)),
                  if (assignments.isEmpty)
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

  // Tablet/Desktop: 2-column card grid
  Widget _buildGrid(Responsive r) {
    return LayoutBuilder(
      builder: (ctx, constraints) {
        final cols = r.isDesktop ? 3 : 2;
        final gap = 12.0;
        final itemW = (constraints.maxWidth - gap * (cols - 1)) / cols;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: List.generate(
            assignments.length,
            (i) => SizedBox(width: itemW, child: _buildCard(assignments[i], r)),
          ),
        );
      },
    );
  }

  Widget _buildList(Responsive r) => Column(
    children: List.generate(
      assignments.length,
      (i) => Padding(
        padding: EdgeInsets.only(top: i == 0 ? 0 : 10),
        child: _buildCard(assignments[i], r),
      ),
    ),
  );

  // ─── Sliver AppBar ────────────────────────────────────────────────────────────
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
        onPressed: isLoading ? null : fetchAssignments,
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
                        'My Assignments',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'All your location assignments',
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

  // ─── Summary Bar ─────────────────────────────────────────────────────────────
  Widget _buildSummaryBar(Responsive r) {
    final active = assignments
        .where((a) => _getStatus(a) == _AssignStatus.active)
        .length;
    final upcoming = assignments
        .where((a) => _getStatus(a) == _AssignStatus.upcoming)
        .length;
    final past = assignments
        .where((a) => _getStatus(a) == _AssignStatus.past)
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
                _statItem('${assignments.length}', 'Total', Colors.white),
                _vDiv(),
                _statItem('$active', 'Active', const Color(0xFF6EE7B7)),
                _vDiv(),
                _statItem('$upcoming', 'Upcoming', const Color(0xFFFDE68A)),
                _vDiv(),
                _statItem('$past', 'Past', Colors.white60),
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

  Widget _buildHistoryHeader(Responsive r) => Padding(
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
              'Assignment History',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: _textDark,
                letterSpacing: 0.1,
              ),
            ),
            const Spacer(),
            if (assignments.isNotEmpty)
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
                  '${assignments.length} records',
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

  // ─── Assignment Card ──────────────────────────────────────────────────────────
  Widget _buildCard(AssignLocationModel a, Responsive r) {
    final status = _getStatus(a);
    return GestureDetector(
      onTap: () => _showWorkDetails(a, r),
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
            Container(height: 3, color: _statusColor(status)),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
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
                      Expanded(
                        child: Text(
                          a.locationName ?? '-',
                          style: TextStyle(
                            fontSize: r.sectionTitleSize,
                            fontWeight: FontWeight.w700,
                            color: _textDark,
                          ),
                        ),
                      ),
                      _statusChip(status),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Container(
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
                      children: [
                        _miniDate(
                          Icons.play_circle_outline_rounded,
                          _fmtShort(a.startDate),
                          _accent,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Container(
                            height: 1.5,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  _accent.withOpacity(0.4),
                                  _red.withOpacity(0.4),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        _miniDate(
                          Icons.stop_circle_outlined,
                          _fmtShort(a.endDate),
                          _red,
                        ),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: _primary.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(7),
                          ),
                          child: Text(
                            '${a.daysCount ?? 0}d',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: _primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (a.aboutWork != null &&
                      a.aboutWork!.trim().isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      a.aboutWork!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: _textMid,
                        height: 1.5,
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        'View details',
                        style: TextStyle(
                          fontSize: 12,
                          color: _primary.withOpacity(0.8),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.arrow_forward_rounded,
                        size: 13,
                        color: _primary.withOpacity(0.8),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusChip(_AssignStatus s) {
    final label = s == _AssignStatus.active
        ? 'Active'
        : s == _AssignStatus.upcoming
        ? 'Upcoming'
        : s == _AssignStatus.past
        ? 'Past'
        : 'Unknown';
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

  Widget _miniDate(IconData icon, String d, Color c) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 14, color: c),
      const SizedBox(width: 4),
      Text(
        d,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: c),
      ),
    ],
  );

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
              'Failed to load assignments',
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
              onPressed: fetchAssignments,
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
            'No assignments yet',
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

enum _AssignStatus { active, upcoming, past, unknown }
