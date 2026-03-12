import '../services/auth_service.dart';
import 'package:provider/provider.dart';
import '../providers/attendance_provider.dart';
import 'package:flutter/material.dart';
import 'hr_home_screen.dart';
import 'emp_attendance_screen.dart';
import 'admin_hr_attendance_screen.dart';
import 'tl_leave_screen.dart';
import 'login_screen.dart';
import '../services/location_services.dart';
import 'emp_profile_screen.dart';
import 'emp_leave_screen.dart';

class TLDashboardScreen extends StatefulWidget {
  final String employeeId; // Employee ID from login
  final String role; // "HR"
  final int initialIndex; // optional: which page to open first
  final int loginId;

  const TLDashboardScreen({
    super.key,
    required this.loginId,
    required this.employeeId,
    required this.role,
    this.initialIndex = 0,
  });

  @override
  State<TLDashboardScreen> createState() => _TLDashboardScreenState();
}

class _TLDashboardScreenState extends State<TLDashboardScreen> {
  late int selectedIndex;
  bool isExpanded = false;
  late LocationService locationService;
  double? distance;

  /// 🔔 Notification index (NOT in menu)
  static const int notificationIndex = 12;

  @override
  void initState() {
    super.initState();
    selectedIndex = widget.initialIndex;
    locationService = LocationService();
  }

  // ================= PAGES =================

  List<Widget> get pages => [
    HrHomeScreen(employeeId: widget.employeeId), // 0
    AttendanceScreen(employeeId: int.parse(widget.employeeId)), // 1
    AdminHrAttendanceScreen(), // 2
    TLLeaveScreen(loginId: widget.loginId), // 3
    LeaveScreen(employeeId: widget.employeeId),

    EmployeeProfileScreen(employeeId: widget.employeeId.toString()),
    const Center(
      child: Text(
        "Notifications",
        style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
      ),
    ),
  ];

  final List<String> titles = [
    "Dashboard",
    "Mark Attendance",
    "Manage Attendance",
    "Leave Approval",
    "Leave"
        "Profile",
    "Notifications",
  ];

  /// SET MENU WITH ICONS
  /// This list defines all sidebar menu options
  final List<NavigationRailDestination> railItems = const [
    NavigationRailDestination(
      icon: Icon(Icons.dashboard_outlined),
      selectedIcon: Icon(Icons.dashboard),
      label: Text("Dashboard"),
    ),

    NavigationRailDestination(
      icon: Icon(Icons.login_outlined),
      selectedIcon: Icon(Icons.login),
      label: Text("Mark Attendance"),
    ),

    NavigationRailDestination(
      icon: Icon(Icons.manage_accounts_outlined),
      selectedIcon: Icon(Icons.manage_accounts),
      label: Text("Manage Attendance"),
    ),

    NavigationRailDestination(
      icon: Icon(Icons.event_busy_outlined),
      selectedIcon: Icon(Icons.event_busy),
      label: Text("Leave Approval"),
    ),

    NavigationRailDestination(
      icon: Icon(Icons.event_busy_outlined),
      selectedIcon: Icon(Icons.event_busy),
      label: Text("Leave Apply"),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.person_rounded),
      selectedIcon: Icon(Icons.person),
      label: Text("Profile"),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final bool isDesktop = MediaQuery.of(context).size.width >= 900;

    return ChangeNotifierProvider(
      create: (_) => AttendanceProvider(empId: widget.employeeId),
      child: Scaffold(
        backgroundColor: Colors.grey.shade100,

        appBar: AppBar(
          elevation: 1,
          backgroundColor: Colors.white,
          iconTheme: const IconThemeData(color: Colors.black87),
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

  //  DESKTOP SIDEBAR
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

  //  MOBILE DRAWER OR MENU BAR
  Widget _mobileDrawer() {
    return Drawer(
      child: ListView(
        children: [
          const DrawerHeader(
            decoration: BoxDecoration(color: Colors.indigo),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Icon(Icons.badge, color: Colors.white, size: 40),
                SizedBox(height: 12),
                Text(
                  "HR Panel",
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

  // LOGOUT
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
