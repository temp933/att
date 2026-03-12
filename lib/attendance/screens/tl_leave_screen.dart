import 'package:flutter/material.dart';
import '../models/leavemodel.dart';
import '../services/leave_service.dart';

class TLLeaveScreen extends StatefulWidget {
  final int loginId;
  const TLLeaveScreen({super.key, required this.loginId});

  @override
  State<TLLeaveScreen> createState() => _TLLeaveScreenState();
}

class _TLLeaveScreenState extends State<TLLeaveScreen>
    with SingleTickerProviderStateMixin {
  final LeaveService _leaveService = LeaveService();

  late TabController _tabController;
  late Future<List<LeaveModel>> _pendingFuture;
  late Future<List<LeaveModel>> _historyFuture;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _reload();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _reload() {
    setState(() {
      _pendingFuture = _leaveService.getPendingTLLeaves();
      _historyFuture = _leaveService.getAllLeavesHistory();
    });
  }

  String _formatDate(DateTime d) =>
      "${d.day.toString().padLeft(2, '0')}-${d.month.toString().padLeft(2, '0')}-${d.year}";

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final bool isDesktop = size.width >= 900;
    final double spacing = isDesktop ? 20 : 12;
    final double fontTitle = isDesktop ? 18 : 14;
    final double fontSub = isDesktop ? 16 : 12;

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.teal,
        title: const Text("TL Leave Review"),
        actions: [
          IconButton(
            tooltip: "Refresh",
            icon: const Icon(Icons.refresh),
            onPressed: _reload,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: const [
            Tab(icon: Icon(Icons.pending_actions), text: "Pending"),
            Tab(icon: Icon(Icons.history), text: "History"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Recommend / Not Recommend buttons
          FutureBuilder<List<LeaveModel>>(
            future: _pendingFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.inbox_outlined, size: 64, color: Colors.teal),
                      SizedBox(height: 12),
                      Text(
                        "No pending leave requests",
                        style: TextStyle(fontSize: 16, color: Colors.black54),
                      ),
                    ],
                  ),
                );
              }

              final leaves = snapshot.data!;
              return Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 900),
                  child: ListView.builder(
                    padding: EdgeInsets.symmetric(
                      horizontal: isDesktop ? 24 : 16,
                      vertical: spacing,
                    ),
                    itemCount: leaves.length,
                    itemBuilder: (context, index) {
                      final leave = leaves[index];

                      return Card(
                        margin: EdgeInsets.only(bottom: spacing),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ExpansionTile(
                          tilePadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 4,
                          ),
                          title: Text(
                            leave.employeeName ?? "",
                            style: TextStyle(
                              fontSize: fontTitle,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: Text(
                            "${leave.departmentName ?? ""} | ${leave.roleName ?? ""}",
                            style: TextStyle(
                              fontSize: fontSub,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          trailing: _statusChip(leave.status),
                          childrenPadding: const EdgeInsets.fromLTRB(
                            16,
                            4,
                            16,
                            16,
                          ),
                          children: [
                            _infoRow("Emp ID", leave.empId.toString()),
                            _infoRow("Leave Type", leave.leaveType),
                            _infoRow("From", _formatDate(leave.fromDate)),
                            _infoRow("To", _formatDate(leave.toDate)),
                            _infoRow(
                              "Total Days",
                              leave.numberOfDays.toString(),
                            ),
                            _infoRow("Reason", leave.reason ?? "-"),
                            const Divider(height: 20),
                            _infoRow(
                              "Taken",
                              leave.takenDays?.toString() ?? "0",
                            ),
                            _infoRow(
                              "Remaining",
                              leave.remainingDays?.toString() ?? "0",
                            ),
                            const SizedBox(height: 12),

                            // ── Recommend / Not Recommend buttons ──────────
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.red,
                                    side: const BorderSide(color: Colors.red),
                                  ),
                                  icon: const Icon(Icons.close, size: 16),
                                  label: const Text("Not Recommend"),
                                  onPressed: () =>
                                      _showNotRecommendDialog(leave),
                                ),
                                const SizedBox(width: 10),
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.teal,
                                  ),
                                  icon: const Icon(Icons.check, size: 16),
                                  label: const Text("Recommend"),
                                  onPressed: () =>
                                      _tlAction(leave, "recommend"),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              );
            },
          ),

          // ══════════════════════════════════════════════════════════════════
          // TAB 2 — FULL HISTORY
          // ══════════════════════════════════════════════════════════════════
          FutureBuilder<List<LeaveModel>>(
            future: _historyFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Center(child: Text("No leave records found"));
              }

              final leaves = snapshot.data!;
              return LayoutBuilder(
                builder: (context, constraints) {
                  if (constraints.maxWidth >= 900) {
                    return _buildDesktopHistory(leaves);
                  } else {
                    return _buildMobileHistory(leaves);
                  }
                },
              );
            },
          ),
        ],
      ),
    );
  }

  // ── Desktop: table with expandable details ──────────────────────────────
  Widget _buildDesktopHistory(List<LeaveModel> leaves) {
    const headers = [
      "Employee",
      "Type",
      "From",
      "To",
      "Days",
      "Status",
      "Approved By",
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 16,
                ),
                decoration: BoxDecoration(
                  color: Colors.teal.shade700,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(10),
                  ),
                ),
                child: Row(
                  children: headers
                      .map(
                        (h) => Expanded(
                          child: Text(
                            h,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
              // Rows
              ...leaves.asMap().entries.map(
                (e) => _TLHistoryDetailRow(
                  leave: e.value,
                  formatDate: _formatDate,
                  isEven: e.key.isEven,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Mobile: card list ───────────────────────────────────────────────────
  Widget _buildMobileHistory(List<LeaveModel> leaves) {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: leaves.length,
      itemBuilder: (context, index) {
        final leave = leaves[index];
        final color = _statusColorValue(leave.status);

        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(color: color.withOpacity(0.4)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        leave.employeeName ?? "Emp #${leave.empId}",
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    _statusChip(leave.status),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  "${leave.leaveType} • ${_formatDate(leave.fromDate)} → ${_formatDate(leave.toDate)} • ${leave.numberOfDays} day(s)",
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                ),
                if (leave.reason != null && leave.reason!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    "Reason: ${leave.reason}",
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
                if (leave.rejectionReason != null &&
                    leave.rejectionReason!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    "Rejection: ${leave.rejectionReason}",
                    style: const TextStyle(fontSize: 12, color: Colors.red),
                  ),
                ],
                if (leave.approvedBy != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    "Approved By: ${leave.approvedBy}",
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Shared helpers ──────────────────────────────────────────────────────
  Widget _statusChip(String status) {
    return Chip(
      label: Text(
        _statusLabel(status),
        style: const TextStyle(color: Colors.white, fontSize: 11),
      ),
      backgroundColor: _statusColorValue(status),
      padding: EdgeInsets.zero,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  String _statusLabel(String status) {
    switch (status) {
      case "Pending_TL":
        return "Pending Review";
      case "Pending_HR":
        return "TL Recommended";
      case "Approved":
        return "Approved";
      case "Rejected_By_TL":
        return "Rejected by TL";
      case "Rejected_By_HR":
        return "Rejected by HR";
      case "Cancelled":
        return "Cancelled";
      default:
        return status;
    }
  }

  Color _statusColorValue(String status) {
    switch (status) {
      case "Approved":
        return Colors.green.shade600;
      case "Rejected_By_HR":
      case "Rejected_By_TL":
        return Colors.red.shade600;
      case "Cancelled":
        return Colors.orange.shade600;
      case "Pending_HR":
        return Colors.teal.shade600;
      case "Pending_TL":
      default:
        return Colors.blue.shade600;
    }
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              "$label:",
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  void _showNotRecommendDialog(LeaveModel leave) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Reason for Not Recommending"),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: "Enter your reason...",
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              final reason = controller.text.trim();
              if (reason.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Please enter a reason")),
                );
                return;
              }
              Navigator.pop(context);
              _tlAction(leave, "not_recommend", rejectionReason: reason);
            },
            child: const Text("Submit"),
          ),
        ],
      ),
    );
  }

  Future<void> _tlAction(
    LeaveModel leave,
    String action, {
    String? rejectionReason,
  }) async {
    final success = await _leaveService.tlLeaveAction(
      leaveId: leave.leaveId!,
      action: action,
      loginId: widget.loginId,
      rejectionReason: rejectionReason,
    );

    if (!mounted) return;

    if (success) {
      final msg = action == "recommend"
          ? "Leave recommended to HR ✓"
          : "Leave rejected ✗";
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: action == "recommend"
              ? Colors.teal
              : Colors.red.shade700,
        ),
      );
      _reload();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Failed to update. Please try again."),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Desktop history row — expandable with full details
// ═════════════════════════════════════════════════════════════════════════════
class _TLHistoryDetailRow extends StatelessWidget {
  final LeaveModel leave;
  final String Function(DateTime) formatDate;
  final bool isEven;

  const _TLHistoryDetailRow({
    required this.leave,
    required this.formatDate,
    required this.isEven,
  });

  Color _statusColor(String s) {
    switch (s) {
      case "Approved":
        return Colors.green.shade600;
      case "Rejected_By_HR":
      case "Rejected_By_TL":
        return Colors.red.shade600;
      case "Cancelled":
        return Colors.orange.shade600;
      case "Pending_HR":
        return Colors.teal.shade600;
      default:
        return Colors.blue.shade600;
    }
  }

  String _statusLabel(String s) {
    switch (s) {
      case "Pending_TL":
        return "Pending Review";
      case "Pending_HR":
        return "TL Recommended";
      case "Approved":
        return "Approved";
      case "Rejected_By_TL":
        return "Rejected by TL";
      case "Rejected_By_HR":
        return "Rejected by HR";
      case "Cancelled":
        return "Cancelled";
      default:
        return s;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isEven ? Colors.white : Colors.grey.shade50,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        title: Row(
          children: [
            // Employee name
            Expanded(
              child: Text(
                leave.employeeName ?? "Emp #${leave.empId}",
                style: const TextStyle(fontSize: 13),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // Leave type
            Expanded(
              child: Text(
                leave.leaveType,
                style: const TextStyle(fontSize: 13),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // From
            Expanded(
              child: Text(
                formatDate(leave.fromDate),
                style: const TextStyle(fontSize: 13),
              ),
            ),
            // To
            Expanded(
              child: Text(
                formatDate(leave.toDate),
                style: const TextStyle(fontSize: 13),
              ),
            ),
            // Days
            Expanded(
              child: Text(
                leave.numberOfDays.toString(),
                style: const TextStyle(fontSize: 13),
              ),
            ),
            // Status badge
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _statusColor(leave.status).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _statusLabel(leave.status),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: _statusColor(leave.status),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            // Approved by
            Expanded(
              child: Text(
                leave.approvedBy ?? "-",
                style: const TextStyle(fontSize: 13),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(height: 1),
          const SizedBox(height: 10),
          Wrap(
            spacing: 40,
            runSpacing: 10,
            children: [
              _detail("Emp ID", leave.empId.toString()),
              _detail("Leave Type", leave.leaveType),
              _detail("From", formatDate(leave.fromDate)),
              _detail("To", formatDate(leave.toDate)),
              _detail("Total Days", leave.numberOfDays.toString()),
              _detail("Status", _statusLabel(leave.status)),
              if (leave.approvedBy != null)
                _detail("Approved By", leave.approvedBy!),
              if (leave.reason != null && leave.reason!.isNotEmpty)
                _detail("Reason", leave.reason!),
              if (leave.rejectionReason != null &&
                  leave.rejectionReason!.isNotEmpty)
                _detail(
                  "Rejection Reason",
                  leave.rejectionReason!,
                  valueColor: Colors.red.shade700,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _detail(String label, String value, {Color? valueColor}) {
    return SizedBox(
      width: 180,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade500,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: valueColor ?? Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}
