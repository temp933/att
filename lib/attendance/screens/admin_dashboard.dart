import '../services/auth_service.dart';
import '../providers/attendance_provider.dart';
import 'package:provider/provider.dart';
import 'package:flutter/material.dart';
import 'admin_hr_attendance_screen.dart';
import 'login_screen.dart';
import 'admin_home_screen.dart';
import 'emp_attendance_screen.dart';
import 'admin_hr_leave_approval.dart';
import 'admin_hr_manage_expenses.dart';
import 'admin_hr_assign_task.dart';
import 'admin_hr_manage_task.dart';
import 'admin_department_screen.dart';
import 'admin_audit_logs.dart';
import 'admin_report.dart';
import 'manage_location.dart';
import '../services/location_services.dart';
import 'emp_profile_screen.dart';
import 'admin_approval.dart';
import 'admin_assign_location.dart';
import 'admin_manage_user.dart';

class AdminDashboardScreen extends StatefulWidget {
  final int initialIndex;
  final String employeeId;
  final String roleId;
  final int loginId;

  const AdminDashboardScreen({
    super.key,
    required this.loginId,
    required this.employeeId,
    required this.roleId,
    this.initialIndex = 0,
  });

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  late int selectedIndex;
  bool isExpanded = false;

  /// 🔔 Notification page index (NOT in menu)
  static const int notificationIndex = 12;

  @override
  void initState() {
    super.initState();
    selectedIndex = widget.initialIndex;
  }

  // ================= PAGES =================
  late final LocationService locationService = LocationService();

  final List<Widget> pages = [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Initialize pages here because AddNewLocationPage requires locationService
    pages.clear();
    pages.addAll([
      AdminHomeScreen(
        employeeId: widget.employeeId,
        onNavigate: (index) {
          setState(() {
            selectedIndex = index;
          });
        },
      ), // 0
      AttendanceScreen(employeeId: int.parse(widget.employeeId)), // 1
      AdminHrAttendanceScreen(), // 2
      LeaveApprovalScreen(loginId: widget.loginId), // 3
      ExpenseApprovalScreen(), // 4
      AssignTaskScreen(), // 5
      ManageTaskScreen(), // 6
      AdminDepartmentsScreen(), // 7
      // AdminAuditLogsScreen(), // 8
      DrawCampusOSM(),
      AdminReportScreen(), // 9
      ManageUserScreen(roleId: widget.roleId), //10
      AdminApprovalPage(), // 11
      ManageLocationPage(), // 12
      AdminAssignLocation(role: widget.roleId), //13
      EmployeeProfileScreen(employeeId: widget.employeeId.toString()),
      // Notification placeholder (14)
      Center(
        child: Text(
          "Notifications",
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
      ),
    ]);
  }

  // ================= TITLES =================
  final List<String> titles = [
    "Dashboard",
    "Attendance",
    "Manage Attendance",
    "Leave Management",
    "Manage Expenses",
    "Assign Task",
    "Manage Tasks",
    "Departments",
    "Audit Logs",
    "System Reports",
    "Manage User",
    "Approval Page",
    "Add Location",
    "Assign Location",
    "Profile",
    "Notifications",
  ];

  // ================= SIDEBAR ITEMS =================
  final List<NavigationRailDestination> railItems = const [
    NavigationRailDestination(
      icon: Icon(Icons.dashboard_outlined),
      selectedIcon: Icon(Icons.dashboard),
      label: Text("Dashboard"),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.fingerprint_outlined),
      selectedIcon: Icon(Icons.fingerprint),
      label: Text("Attendance"),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.fact_check_outlined),
      selectedIcon: Icon(Icons.fact_check),
      label: Text("Manage Attendance"),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.event_busy_outlined),
      selectedIcon: Icon(Icons.event_busy),
      label: Text("Leave Management"),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.payments_outlined),
      selectedIcon: Icon(Icons.payments),
      label: Text("Manage Expenses"),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.assignment_add),
      selectedIcon: Icon(Icons.assignment_add),
      label: Text("Assign Task"),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.task_alt_outlined),
      selectedIcon: Icon(Icons.task_alt),
      label: Text("Manage Tasks"),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.apartment_outlined),
      selectedIcon: Icon(Icons.apartment),
      label: Text("Departments"),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.history_outlined),
      selectedIcon: Icon(Icons.history),
      label: Text("Audit Logs"),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.summarize_outlined),
      selectedIcon: Icon(Icons.summarize),
      label: Text("System Reports"),
    ),

    NavigationRailDestination(
      icon: Icon(Icons.manage_accounts_outlined),
      selectedIcon: Icon(Icons.manage_accounts),
      label: Text("Manage Users"),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.manage_accounts_outlined),
      selectedIcon: Icon(Icons.manage_accounts),
      label: Text("Approval Page"),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.place_outlined),
      selectedIcon: Icon(Icons.place),
      label: Text("Location"),
    ),

    NavigationRailDestination(
      icon: Icon(Icons.place_outlined),
      selectedIcon: Icon(Icons.place),
      label: Text("Assign Location"),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.person_outline),
      selectedIcon: Icon(Icons.person),
      label: Text("Profile"),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final bool isDesktop = MediaQuery.of(context).size.width >= 900;

    return ChangeNotifierProvider(
      create: (_) => AttendanceProvider(empId: widget.employeeId.toString()),
      child: Scaffold(
        backgroundColor: Colors.grey.shade100,

        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 1,
          title: Text(
            titles[selectedIndex],
            style: const TextStyle(
              color: Colors.black87,
              fontWeight: FontWeight.w600,
            ),
          ),
          actions: [
            IconButton(
              tooltip: "Notifications",
              icon: const Icon(Icons.notifications_outlined),
              onPressed: () {
                setState(() => selectedIndex = notificationIndex);
              },
            ),
            IconButton(
              tooltip: "Logout",
              icon: const Icon(Icons.logout, color: Colors.red),
              onPressed: _logout,
            ),
            const SizedBox(width: 8),
          ],
        ),

        drawer: isDesktop ? null : _mobileDrawer(),

        body: Row(
          children: [
            if (isDesktop) _desktopSidebar(),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: pages[selectedIndex],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ================= DESKTOP SIDEBAR =================
  Widget _desktopSidebar() {
    return MouseRegion(
      onEnter: (_) => setState(() => isExpanded = true),
      onExit: (_) => setState(() => isExpanded = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        width: isExpanded ? 230 : 72,
        color: Colors.white,
        child: ListView.builder(
          itemCount: railItems.length,
          itemBuilder: (context, index) {
            final item = railItems[index];
            final bool selected = selectedIndex == index;

            return InkWell(
              onTap: () => setState(() => selectedIndex = index),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 12,
                ),
                decoration: selected
                    ? BoxDecoration(
                        color: Colors.indigo.shade50,
                        borderRadius: BorderRadius.circular(10),
                      )
                    : null,
                child: Row(
                  children: [
                    IconTheme(
                      data: IconThemeData(
                        color: selected ? Colors.indigo : Colors.grey,
                      ),
                      child: selected ? item.selectedIcon : item.icon,
                    ),
                    if (isExpanded)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(left: 14),
                          child: Text(
                            (item.label as Text).data!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: selected
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // ================= MOBILE DRAWER =================
  Widget _mobileDrawer() {
    return Drawer(
      child: ListView(
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(color: Colors.indigo),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: const [
                Icon(Icons.admin_panel_settings, color: Colors.white, size: 40),
                SizedBox(height: 12),
                Text(
                  "Admin Panel",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  "Employee Attendance System",
                  style: TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
          ...List.generate(railItems.length, (index) {
            final bool selected = selectedIndex == index;
            return ListTile(
              leading: IconTheme(
                data: IconThemeData(
                  color: selected ? Colors.indigo : Colors.grey,
                ),
                child: railItems[index].icon,
              ),
              title: Text((railItems[index].label as Text).data!),
              selected: selected,
              selectedTileColor: Colors.indigo.shade50,
              onTap: () {
                setState(() => selectedIndex = index);
                Navigator.pop(context);
              },
            );
          }),
        ],
      ),
    );
  }

  // ================= LOGOUT =================
  Future<void> _logout() async {
    try {
      await AuthService.clearSession(); // clears DB session fields
    } catch (_) {}

    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }
}
