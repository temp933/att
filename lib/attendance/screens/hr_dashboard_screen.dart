// import 'package:provider/provider.dart';
// import '../providers/attendance_provider.dart';
// import 'package:flutter/material.dart';
// import 'hr_home_screen.dart';
// import 'emp_attendance_screen.dart';
// import 'admin_hr_attendance_screen.dart';
// import 'admin_hr_leave_approval.dart';
// import 'admin_hr_manage_expenses.dart';
// import 'admin_hr_assign_task.dart';
// import 'admin_hr_manage_task.dart';
// import 'admin_hr_travel_onsite.dart';
// import 'hr_report.dart';
// import 'admin_manage_user.dart';
// import 'login_screen.dart';
// import 'admin_assign_location.dart';
// import '../services/location_services.dart';
// import 'emp_profile_screen.dart';
// import '../services/auth_service.dart';

// class HRDashboardScreen extends StatefulWidget {
//   final String employeeId;

//   final String roleId;
//   final int initialIndex;
//   final int loginId;

//   const HRDashboardScreen({
//     super.key,
//     required this.loginId,
//     required this.employeeId,

//     required this.roleId,
//     this.initialIndex = 0,
//   });

//   @override
//   State<HRDashboardScreen> createState() => _HrDashboardScreenState();
// }

// class _HrDashboardScreenState extends State<HRDashboardScreen> {
//   final GlobalKey manageUserKey = GlobalKey();
//   late int selectedIndex;
//   bool isExpanded = false;
//   late LocationService locationService;
//   late List<Widget> pages; // ✅ NOT a getter anymore

//   static const int notificationIndex = 12;

//   @override
//   void initState() {
//     super.initState();
//     selectedIndex = widget.initialIndex;
//     locationService = LocationService();

//     // ✅ Build pages ONCE — so onNavigate callback stays alive
//     pages = [
//       HrHomeScreen(
//         employeeId: widget.employeeId,
//         onNavigate: (index) => setState(() => selectedIndex = index),
//       ), // 0
//       AttendanceScreen(), // 1
//       AdminHrAttendanceScreen(), // 2
//       LeaveApprovalScreen(loginId: widget.loginId), // 3
//       ExpenseApprovalScreen(), // 4
//       AssignTaskScreen(), // 5
//       ManageTaskScreen(), // 6
//       TravelAssignmentScreen(), // 7
//       HRReportsScreen(), // 8
//       ManageUserScreen(key: manageUserKey, roleId: widget.roleId), // 9
//       AdminAssignLocation(role: widget.roleId), // 10
//       EmployeeProfileScreen(employeeId: widget.employeeId.toString()), // 11
//       const Center(
//         child: Text(
//           "Notifications",
//           style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
//         ),
//       ), // 12
//     ];
//   }

//   final List<String> titles = [
//     "Dashboard",
//     "Mark Attendance",
//     "Manage Attendance",
//     "Leave Approval",
//     "Expense Approval",
//     "Assign Task",
//     "Manage Task",
//     "Travel / On-Site",
//     "Reports",
//     "Manage Users",
//     "Assign Location",
//     "Profile",
//     "Notifications",
//   ];

//   final List<NavigationRailDestination> railItems = const [
//     NavigationRailDestination(
//       icon: Icon(Icons.dashboard_outlined),
//       selectedIcon: Icon(Icons.dashboard),
//       label: Text("Dashboard"),
//     ),
//     NavigationRailDestination(
//       icon: Icon(Icons.login_outlined),
//       selectedIcon: Icon(Icons.login),
//       label: Text("Mark Attendance"),
//     ),
//     NavigationRailDestination(
//       icon: Icon(Icons.manage_accounts_outlined),
//       selectedIcon: Icon(Icons.manage_accounts),
//       label: Text("Manage Attendance"),
//     ),
//     NavigationRailDestination(
//       icon: Icon(Icons.event_busy_outlined),
//       selectedIcon: Icon(Icons.event_busy),
//       label: Text("Leave Approval"),
//     ),
//     NavigationRailDestination(
//       icon: Icon(Icons.payments_outlined),
//       selectedIcon: Icon(Icons.payments),
//       label: Text("Expense Approval"),
//     ),
//     NavigationRailDestination(
//       icon: Icon(Icons.assignment_add),
//       selectedIcon: Icon(Icons.assignment_add),
//       label: Text("Assign Task"),
//     ),
//     NavigationRailDestination(
//       icon: Icon(Icons.task_outlined),
//       selectedIcon: Icon(Icons.task),
//       label: Text("Manage Task"),
//     ),
//     NavigationRailDestination(
//       icon: Icon(Icons.flight_takeoff_outlined),
//       selectedIcon: Icon(Icons.flight_takeoff),
//       label: Text("Travel / On-Site"),
//     ),
//     NavigationRailDestination(
//       icon: Icon(Icons.summarize_outlined),
//       selectedIcon: Icon(Icons.summarize),
//       label: Text("Reports"),
//     ),
//     NavigationRailDestination(
//       icon: Icon(Icons.manage_accounts_outlined),
//       selectedIcon: Icon(Icons.manage_accounts),
//       label: Text("Manage Users"),
//     ),
//     NavigationRailDestination(
//       icon: Icon(Icons.place_outlined),
//       selectedIcon: Icon(Icons.place),
//       label: Text("Assign Location"),
//     ),
//     NavigationRailDestination(
//       icon: Icon(Icons.person_rounded),
//       selectedIcon: Icon(Icons.person),
//       label: Text("Profile"),
//     ),
//   ];

//   @override
//   Widget build(BuildContext context) {
//     final bool isDesktop = MediaQuery.of(context).size.width >= 900;

//     return ChangeNotifierProvider(
//       create: (_) => AttendanceProvider(empId: widget.employeeId),
//       child: Scaffold(
//         backgroundColor: Colors.grey.shade100,
//         appBar: AppBar(
//           elevation: 1,
//           backgroundColor: Colors.white,
//           iconTheme: const IconThemeData(color: Colors.black87),
//           title: Text(
//             titles[selectedIndex],
//             style: const TextStyle(
//               color: Colors.black87,
//               fontWeight: FontWeight.w600,
//             ),
//           ),
//           actions: [
//             IconButton(
//               tooltip: "Notifications",
//               icon: const Icon(Icons.notifications_outlined),
//               onPressed: () =>
//                   setState(() => selectedIndex = notificationIndex),
//             ),
//             IconButton(
//               tooltip: "Logout",
//               icon: const Icon(Icons.logout, color: Colors.red),
//               onPressed: _logout,
//             ),
//             const SizedBox(width: 8),
//           ],
//         ),
//         drawer: isDesktop ? null : _mobileDrawer(),
//         body: Row(
//           children: [
//             if (isDesktop) _desktopSidebar(),
//             Expanded(
//               child: IndexedStack(
//                 // ✅ keeps pages alive, no rebuild on switch
//                 index: selectedIndex,
//                 children: pages,
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _desktopSidebar() {
//     return MouseRegion(
//       onEnter: (_) => setState(() => isExpanded = true),
//       onExit: (_) => setState(() => isExpanded = false),
//       child: AnimatedContainer(
//         duration: const Duration(milliseconds: 250),
//         width: isExpanded ? 230 : 72,
//         color: Colors.white,
//         child: ListView.builder(
//           itemCount: railItems.length,
//           itemBuilder: (context, index) {
//             final item = railItems[index];
//             final bool selected = selectedIndex == index;

//             return InkWell(
//               onTap: () => setState(() => selectedIndex = index),
//               child: Container(
//                 margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
//                 padding: const EdgeInsets.symmetric(
//                   vertical: 12,
//                   horizontal: 12,
//                 ),
//                 decoration: selected
//                     ? BoxDecoration(
//                         color: Colors.indigo.shade50,
//                         borderRadius: BorderRadius.circular(10),
//                       )
//                     : null,
//                 child: Row(
//                   children: [
//                     IconTheme(
//                       data: IconThemeData(
//                         color: selected ? Colors.indigo : Colors.grey,
//                       ),
//                       child: selected ? item.selectedIcon : item.icon,
//                     ),
//                     if (isExpanded)
//                       Expanded(
//                         child: Padding(
//                           padding: const EdgeInsets.only(left: 14),
//                           child: Text(
//                             (item.label as Text).data!,
//                             overflow: TextOverflow.ellipsis,
//                             style: TextStyle(
//                               fontWeight: selected
//                                   ? FontWeight.w600
//                                   : FontWeight.normal,
//                             ),
//                           ),
//                         ),
//                       ),
//                   ],
//                 ),
//               ),
//             );
//           },
//         ),
//       ),
//     );
//   }

//   Widget _mobileDrawer() {
//     return Drawer(
//       child: ListView(
//         children: [
//           const DrawerHeader(
//             decoration: BoxDecoration(color: Colors.indigo),
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               mainAxisAlignment: MainAxisAlignment.end,
//               children: [
//                 Icon(Icons.badge, color: Colors.white, size: 40),
//                 SizedBox(height: 12),
//                 Text(
//                   "HR Panel",
//                   style: TextStyle(
//                     color: Colors.white,
//                     fontSize: 18,
//                     fontWeight: FontWeight.bold,
//                   ),
//                 ),
//                 Text(
//                   "Employee Attendance System",
//                   style: TextStyle(color: Colors.white70),
//                 ),
//               ],
//             ),
//           ),
//           ...List.generate(railItems.length, (index) {
//             final bool selected = selectedIndex == index;
//             return ListTile(
//               leading: IconTheme(
//                 data: IconThemeData(
//                   color: selected ? Colors.indigo : Colors.grey,
//                 ),
//                 child: railItems[index].icon,
//               ),
//               title: Text((railItems[index].label as Text).data!),
//               selected: selected,
//               selectedTileColor: Colors.indigo.shade50,
//               onTap: () {
//                 setState(() => selectedIndex = index);
//                 Navigator.pop(context);
//               },
//             );
//           }),
//         ],
//       ),
//     );
//   }

//   void _logout() async {
//     await AuthService.clearSession();
//     if (!mounted) return;
//     Navigator.of(context).pushAndRemoveUntil(
//       MaterialPageRoute(builder: (_) => const LoginScreen()),
//       (route) => false,
//     );
//   }
// }

import 'package:provider/provider.dart';
import '../providers/attendance_provider.dart';
import 'package:flutter/material.dart';
import 'hr_home_screen.dart';
import 'emp_attendance_screen.dart';
import 'admin_hr_attendance_screen.dart';
import 'admin_hr_leave_approval.dart';
import 'admin_hr_manage_expenses.dart';
import 'admin_hr_assign_task.dart';
import 'admin_hr_manage_task.dart';
import 'admin_hr_travel_onsite.dart';
import 'hr_report.dart';
import 'admin_manage_user.dart';
import 'login_screen.dart';
import 'admin_assign_location.dart';
import '../services/location_services.dart';
import 'emp_profile_screen.dart';
import '../services/auth_service.dart';

class HRDashboardScreen extends StatefulWidget {
  final String employeeId;

  final String roleId;
  final int initialIndex;
  final int loginId;

  const HRDashboardScreen({
    super.key,
    required this.loginId,
    required this.employeeId,

    required this.roleId,
    this.initialIndex = 0,
  });

  @override
  State<HRDashboardScreen> createState() => _HrDashboardScreenState();
}

class _HrDashboardScreenState extends State<HRDashboardScreen> {
  final GlobalKey<ManageUserScreenState> manageUserKey =
      GlobalKey<ManageUserScreenState>();
  late int selectedIndex;
  bool isExpanded = false;
  late LocationService locationService;
  late List<Widget> pages; // ✅ NOT a getter anymore

  static const int notificationIndex = 12;
  static const int manageUserIndex = 9; // ✅ index for ManageUserScreen

  @override
  void initState() {
    super.initState();
    selectedIndex = widget.initialIndex;
    locationService = LocationService();

    // ✅ Build pages ONCE — so onNavigate callback stays alive
    pages = [
      HrHomeScreen(
        employeeId: widget.employeeId,
        onNavigate: (index) => setState(() => selectedIndex = index),
      ), // 0
      AttendanceScreen(employeeId: int.parse(widget.employeeId)), // 1
      AdminHrAttendanceScreen(), // 2
      LeaveApprovalScreen(loginId: widget.loginId), // 3
      ExpenseApprovalScreen(), // 4
      AssignTaskScreen(), // 5
      ManageTaskScreen(), // 6
      TravelAssignmentScreen(), // 7
      HRReportsScreen(), // 8
      ManageUserScreen(key: manageUserKey, roleId: widget.roleId), // 9
      AdminAssignLocation(role: widget.roleId), // 10
      EmployeeProfileScreen(employeeId: widget.employeeId.toString()), // 11
      const Center(
        child: Text(
          "Notifications",
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
      ), // 12
    ];
  }

  /// ✅ Navigates to the given index and refreshes ManageUserScreen if applicable
  void _navigateTo(int index) {
    setState(() => selectedIndex = index);
    if (index == manageUserIndex) {
      manageUserKey.currentState?.refreshUsers();
    }
  }

  final List<String> titles = [
    "Dashboard",
    "Mark Attendance",
    "Manage Attendance",
    "Leave Approval",
    "Expense Approval",
    "Assign Task",
    "Manage Task",
    "Travel / On-Site",
    "Reports",
    "Manage Users",
    "Assign Location",
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
      icon: Icon(Icons.payments_outlined),
      selectedIcon: Icon(Icons.payments),
      label: Text("Expense Approval"),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.assignment_add),
      selectedIcon: Icon(Icons.assignment_add),
      label: Text("Assign Task"),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.task_outlined),
      selectedIcon: Icon(Icons.task),
      label: Text("Manage Task"),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.flight_takeoff_outlined),
      selectedIcon: Icon(Icons.flight_takeoff),
      label: Text("Travel / On-Site"),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.summarize_outlined),
      selectedIcon: Icon(Icons.summarize),
      label: Text("Reports"),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.manage_accounts_outlined),
      selectedIcon: Icon(Icons.manage_accounts),
      label: Text("Manage Users"),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.place_outlined),
      selectedIcon: Icon(Icons.place),
      label: Text("Assign Location"),
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
            // ✅ Refresh button — only visible on Manage Users screen
            if (selectedIndex == manageUserIndex)
              IconButton(
                tooltip: "Refresh",
                icon: const Icon(Icons.refresh),
                onPressed: () => manageUserKey.currentState?.refreshUsers(),
              ),
            IconButton(
              tooltip: "Notifications",
              icon: const Icon(Icons.notifications_outlined),
              onPressed: () =>
                  setState(() => selectedIndex = notificationIndex),
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
              child: IndexedStack(
                // ✅ keeps pages alive, no rebuild on switch
                index: selectedIndex,
                children: pages,
              ),
            ),
          ],
        ),
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
              onTap: () => _navigateTo(index), // ✅ use _navigateTo
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
                _navigateTo(index); // ✅ use _navigateTo
                Navigator.pop(context);
              },
            );
          }),
        ],
      ),
    );
  }

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
