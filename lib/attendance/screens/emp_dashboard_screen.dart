import '../services/auth_service.dart';
import '../services/attendance_state.dart';
import '../services/site_cache.dart';
import 'package:flutter/material.dart';
import 'emp_home_screen.dart';
import 'emp_attendance_screen.dart';
import 'emp_leave_screen.dart';
import 'emp_expenses_screen.dart';
import 'emp_profile_screen.dart';
import 'emp_report_screen.dart';
import 'emp_tasks_screen.dart';
import 'emp_travel_onsite_screen.dart';
import 'login_screen.dart';
import '../services/location_services.dart';
import 'emp_work_location.dart';

class DashboardScreen extends StatefulWidget {
  final int loginId;
  final int empId;
  final String role;
  final int initialIndex;

  const DashboardScreen({
    super.key,
    required this.loginId,
    required this.empId,
    required this.role,
    this.initialIndex = 0,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late int selectedIndex;
  bool isExpanded = false;
  late LocationService locationService;
  double? distance;

  static const int notificationIndex = 8;

  @override
  void initState() {
    super.initState();
    selectedIndex = widget.initialIndex;
    locationService = LocationService();
  }

  @override
  void dispose() {
    super.dispose();
  }

  List<Widget> get pages => [
    EmployeeHomeScreen(empId: widget.empId, role: widget.role),
    AttendanceScreen(employeeId: widget.empId),
    LeaveScreen(employeeId: widget.empId.toString()),
    TasksScreen(),
    EmployeeAssignmentsScreen(empId: widget.empId),
    TravelOnsiteScreen(),
    ExpenseScreen(),
    ReportsScreen(),
    EmployeeProfileScreen(employeeId: widget.empId.toString()),
    const Center(
      child: Text(
        "Notifications",
        style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
      ),
    ),
  ];

  final List<String> titles = [
    "Dashboard",
    "Attendance",
    "Leave Management",
    "My Tasks",
    "Work Location",
    "Travel / Onsite",
    "Expenses",
    "Reports",
    "Profile",
    "Notifications",
  ];

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
      icon: Icon(Icons.event_note_outlined),
      selectedIcon: Icon(Icons.event_note),
      label: Text("Leave"),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.task_outlined),
      selectedIcon: Icon(Icons.task),
      label: Text("Tasks"),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.task_outlined),
      selectedIcon: Icon(Icons.place),
      label: Text("Work Location"),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.directions_car_outlined),
      selectedIcon: Icon(Icons.directions_car),
      label: Text("Travel"),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.receipt_long_outlined),
      selectedIcon: Icon(Icons.receipt_long),
      label: Text("Expenses"),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.analytics_outlined),
      selectedIcon: Icon(Icons.analytics),
      label: Text("Reports"),
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

    return Scaffold(
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
            onPressed: () async => await _logout(),
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
    );
  }

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
                  "Employee Dashboard",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
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

  // ── LOGOUT ───────────────────────────────────────────────────────────────────
  Future<void> _logout() async {
    // 1. Stop site cache auto-sync timer
    try {
      SiteCache.dispose();
    } catch (_) {}

    // 2. Reset AttendanceState singleton in memory
    try {
      final state = AttendanceState.instance;
      state.dayStatus = DayStatus.notStarted;
      state.startTime = null;
      state.endTime = null;
      state.isInsideSite = false;
      state.currentSiteName = "";
    } catch (_) {}

    // 3. ✅ Call server logout + clear SharedPreferences
    await AuthService.clearSession(); // ← replaces prefs.clear()

    // 4. Navigate to login
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }
}
