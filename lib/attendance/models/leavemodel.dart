class LeaveModel {
  final int? leaveId;
  final int empId;
  final String? employeeName;
  final String? departmentName;
  final String? roleName;
  final String leaveType;
  final DateTime fromDate;
  final DateTime toDate;
  final int numberOfDays;
  final String? approvedBy;
  final int? takenDays;
  final int? remainingDays;
  String status;
  final String? reason;
  final String? rejectionReason;
  final String? cancelReason;
  final String? recommendedByName;

  LeaveModel({
    this.leaveId,
    required this.empId,
    this.employeeName,
    this.departmentName,
    this.roleName,
    required this.leaveType,
    required this.fromDate,
    required this.toDate,
    required this.numberOfDays,
    this.approvedBy,
    this.reason,
    this.takenDays,
    this.remainingDays,
    required this.status,
    this.rejectionReason,
    this.cancelReason,
    this.recommendedByName,
  });

  // ── Static helpers (must be static to use inside factory constructors) ──
  static int? _parseInt(dynamic v) =>
      v == null ? null : int.tryParse(v.toString());

  static int _parseIntRequired(dynamic v, {int fallback = 0}) =>
      v == null ? fallback : (int.tryParse(v.toString()) ?? fallback);

  /// Parse "dd.MM.yyyy" or "yyyy-MM-dd"
  static DateTime _parseDate(String? s) {
    if (s == null || s.isEmpty) return DateTime.now();
    if (s.contains('.')) {
      final p = s.split('.');
      if (p.length == 3) {
        return DateTime(
          int.parse(p[2]), // year
          int.parse(p[1]), // month
          int.parse(p[0]), // day
        );
      }
    }
    return DateTime.parse(s);
  }

  /// For PENDING LEAVES API
  factory LeaveModel.fromPendingJson(Map<String, dynamic> json) {
    return LeaveModel(
      leaveId: _parseInt(json['leave_id']),
      empId: _parseIntRequired(json['emp_id']),
      employeeName: json['employee_name']?.toString(),
      departmentName: json['department_name']?.toString(),
      roleName: json['role_name']?.toString(),
      leaveType: json['leave_type']?.toString() ?? '',
      fromDate: _parseDate(json['leave_start_date']?.toString()),
      toDate: _parseDate(json['leave_end_date']?.toString()),
      numberOfDays: _parseIntRequired(json['number_of_days']),
      approvedBy: json['approved_by']?.toString(),
      reason: json['reason']?.toString(),
      takenDays: _parseInt(json['taken_days']),
      remainingDays: _parseInt(json['remaining_days']),
      status: json['status']?.toString() ?? 'Pending',
      rejectionReason: json['rejection_reason']?.toString(),
      cancelReason: json['cancel_reason']?.toString(),
    );
  }

  /// For HISTORY LEAVES API
  /// For HISTORY LEAVES API
  factory LeaveModel.fromHistoryJson(Map<String, dynamic> json) {
    final approvedByName = json['approved_by_name']?.toString();
    final recommendedByName = json['recommended_by_name']?.toString();
    return LeaveModel(
      leaveId: _parseInt(json['leave_id']),
      empId: _parseIntRequired(json['emp_id']),
      employeeName: json['employee_name']?.toString(),
      departmentName: json['department_name']?.toString(),
      roleName: json['role_name']?.toString(),
      leaveType: json['leave_type']?.toString() ?? '',
      fromDate: _parseDate(json['from_date']?.toString()),
      toDate: _parseDate(json['to_date']?.toString()),
      numberOfDays: _parseIntRequired(json['total_days']),
      approvedBy:
          approvedByName ?? recommendedByName, // ← resolved name, not raw ID
      status: json['status']?.toString() ?? '',
      reason: json['reason']?.toString(),
      rejectionReason: json['rejection_reason']?.toString(),
      cancelReason: json['cancel_reason']?.toString(),
      recommendedByName: recommendedByName,
    );
  }
}
