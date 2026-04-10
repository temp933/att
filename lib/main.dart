import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'attendance/screens/login_screen.dart';
import 'attendance/screens/emp_dashboard_screen.dart';
import 'attendance/screens/admin_dashboard.dart';
import 'attendance/screens/hr_dashboard_screen.dart';
import 'attendance/screens/team_lead_dashboard.dart';
import 'attendance/services/location_services.dart';
import 'attendance/services/auth_service.dart';
import 'attendance/services/background_service.dart';
import 'attendance/screens/manager_dashboard.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ✅ Start live GPS background service only on mobile
  if (!kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS)) {
    await initBackgroundService();
  }

  runApp(
    MultiProvider(
      providers: [Provider<LocationService>(create: (_) => LocationService())],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: SplashRouter(),
    );
  }
}

class SplashRouter extends StatefulWidget {
  const SplashRouter({super.key});

  @override
  State<SplashRouter> createState() => _SplashRouterState();
}

class _SplashRouterState extends State<SplashRouter> {
  @override
  void initState() {
    super.initState();
    _checkSession();
  }

  Future<void> _checkSession() async {
    final session = await AuthService.getSession();

    if (!mounted) return;

    if (session == null) {
      _go(const LoginScreen());
      return;
    }
    final isValid = await AuthService.validateSession();
    if (!isValid) {
      await AuthService.clearSession();
      if (!mounted) return;
      _go(const LoginScreen());
      return;
    }

    final int loginId = int.parse(session['loginId']!);
    final int empId = int.parse(session['empId']!);
    final int roleId = int.parse(session['role']!);

    Widget destination;

    if (roleId == 1) {
      destination = AdminDashboardScreen(
        loginId: loginId,
        employeeId: empId.toString(),
        roleId: roleId.toString(),
      );
    } else if (roleId == 2) {
      destination = HRDashboardScreen(
        loginId: loginId,
        employeeId: empId.toString(),
        roleId: roleId.toString(),
      );
    } else if (roleId == 3) {
      destination = TLDashboardScreen(
        loginId: loginId,
        employeeId: empId.toString(),
        role: roleId.toString(),
      );
    } else if (roleId == 8) {
      destination = ManagerDashboardScreen(
        loginId: loginId,
        employeeId: empId.toString(),
        roleId: roleId.toString(),
      );
    } else {
      destination = DashboardScreen(
        loginId: loginId,
        empId: empId,
        role: roleId.toString(),
      );
    }

    _go(destination);
  }

  void _go(Widget screen) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
