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

// import 'package:camera/camera.dart';
// import 'package:flutter/material.dart';
// import 'package:http/http.dart' as http;
// import 'dart:convert';

// late List<CameraDescription> cameras;

// const String SERVER = "http://192.168.29.103:3000";

// Future<void> main() async {
//   WidgetsFlutterBinding.ensureInitialized();
//   cameras = await availableCameras();
//   runApp(const MyApp());
// }

// class MyApp extends StatelessWidget {
//   const MyApp({super.key});
//   @override
//   Widget build(BuildContext context) {
//     return const MaterialApp(
//       debugShowCheckedModeBanner: false,
//       home: CameraScreen(),
//     );
//   }
// }

// class CameraScreen extends StatefulWidget {
//   const CameraScreen({super.key});
//   @override
//   State<CameraScreen> createState() => _CameraScreenState();
// }

// class _CameraScreenState extends State<CameraScreen> {
//   late CameraController _controller;
//   bool _ready = false;
//   bool _loading = false;
//   bool? _matched;
//   double? _distance;
//   String? _message; // info/error message

//   @override
//   void initState() {
//     super.initState();
//     _initCamera();
//   }

//   Future<void> _initCamera() async {
//     final front = cameras.firstWhere(
//       (c) => c.lensDirection == CameraLensDirection.front,
//     );
//     _controller = CameraController(
//       front,
//       ResolutionPreset.high,
//       enableAudio: false,
//     );
//     await _controller.initialize();
//     if (mounted) setState(() => _ready = true);
//   }

//   @override
//   void dispose() {
//     _controller.dispose();
//     super.dispose();
//   }

//   Future<void> _captureAndCompare() async {
//     if (!_controller.value.isInitialized) return;

//     setState(() {
//       _loading = true;
//       _matched = null;
//       _distance = null;
//       _message = null;
//     });

//     try {
//       final img = await _controller.takePicture();
//       final req = http.MultipartRequest(
//         'POST',
//         Uri.parse("$SERVER/api/compare"),
//       );
//       req.files.add(await http.MultipartFile.fromPath('image', img.path));

//       final res = await req.send();
//       final body = jsonDecode(await res.stream.bytesToString());

//       if (body['error'] != null) {
//         // Face not detected clearly
//         setState(() => _message = body['error']);
//       } else {
//         setState(() {
//           _matched = body['match'] == true;
//           _distance = (body['distance'] as num?)?.toDouble();
//           _message = null;
//         });
//       }
//     } catch (e) {
//       setState(() => _message = 'Connection error: $e');
//     }

//     setState(() => _loading = false);
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: const Text('Face Capture')),
//       body: Column(
//         children: [
//           // Camera
//           Expanded(
//             child: _ready
//                 ? CameraPreview(_controller)
//                 : const Center(child: CircularProgressIndicator()),
//           ),

//           const SizedBox(height: 20),

//           // Button
//           ElevatedButton(
//             onPressed: _loading ? null : _captureAndCompare,
//             child: _loading
//                 ? const SizedBox(
//                     width: 20,
//                     height: 20,
//                     child: CircularProgressIndicator(strokeWidth: 2),
//                   )
//                 : const Text('Capture & Compare'),
//           ),

//           const SizedBox(height: 16),

//           // Result
//           if (_message != null)
//             Padding(
//               padding: const EdgeInsets.symmetric(horizontal: 16),
//               child: Text(
//                 '⚠️ $_message',
//                 style: const TextStyle(color: Colors.orange, fontSize: 15),
//                 textAlign: TextAlign.center,
//               ),
//             )
//           else if (_matched != null)
//             Text(
//               _matched!
//                   ? '✅ MATCH (distance: ${_distance?.toStringAsFixed(4)})'
//                   : '❌ NOT MATCH (distance: ${_distance?.toStringAsFixed(4)})',
//               style: TextStyle(
//                 fontSize: 18,
//                 fontWeight: FontWeight.bold,
//                 color: _matched! ? Colors.green : Colors.red,
//               ),
//             ),

//           const SizedBox(height: 24),
//         ],
//       ),
//     );
//   }
// }
