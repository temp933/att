import 'package:flutter/material.dart';
import 'emp_dashboard_screen.dart';
import 'admin_dashboard.dart';
import 'hr_dashboard_screen.dart';
import '../services/employee_service.dart';
import '../services/auth_service.dart'; 
import 'package:flutter/services.dart';
import 'team_lead_dashboard.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _hidePassword = true;
  bool _isLoading = false;

  void _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final deviceId = await AuthService.getDeviceId(); // ✅ get device ID

      final data = await EmployeeService.login(
        _emailController.text,
        _passwordController.text,
        deviceId: deviceId, // ✅ pass to service
      );

      final int loginId = data['loginId'];
      final int empId = data['empId'];
      final int roleId = data['roleId'];
      final String username = data['username'] ?? '';
      final String sessionToken = data['sessionToken'] ?? ''; // ✅ NEW

      await AuthService.saveSession(
        loginId: loginId.toString(),
        empId: empId.toString(),
        role: roleId.toString(),
        username: username,
        sessionToken: sessionToken, // ✅ NEW
      );

      if (!mounted) return;

      if (roleId == 1) {
        // ADMIN (Office Admin)
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => AdminDashboardScreen(
              loginId: loginId,
              employeeId: empId.toString(),
              roleId: roleId.toString(),
            ),
          ),
        );
      } else if (roleId == 2) {
        // HR Executive
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => HRDashboardScreen(
              loginId: loginId,
              employeeId: empId.toString(),
              roleId: roleId.toString(),
            ),
          ),
        );
      } else if (roleId == 3) {
        // TEAM LEAD
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => TLDashboardScreen(
              loginId: loginId,
              employeeId: empId.toString(),
              role: roleId.toString(),
            ),
          ),
        );
      } else {
        // ALL OTHER ROLES → NORMAL EMPLOYEE
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => DashboardScreen(
              loginId: loginId,
              empId: empId,
              role: roleId.toString(),
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      // ✅ Show friendly message for multi-device block
      final msg = e.toString().contains('another device')
          ? 'You are already logged in on another device.'
          : e.toString();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final bool isDesktop = size.width > 900;
    final double padding = isDesktop ? size.width * 0.2 : 24;

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: padding, vertical: 40),
            child: Card(
              elevation: 10,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              shadowColor: Colors.indigo.withValues(alpha: 0.3), // ✅ FIXED
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Form(
                  key: _formKey,
                  child: _LoginForm(
                    emailController: _emailController,
                    passwordController: _passwordController,
                    hidePassword: _hidePassword,
                    togglePassword: () =>
                        setState(() => _hidePassword = !_hidePassword),
                    isLoading: _isLoading,
                    login: _login,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LoginForm extends StatelessWidget {
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final bool hidePassword;
  final VoidCallback togglePassword;
  final bool isLoading;
  final VoidCallback login;

  const _LoginForm({
    required this.emailController,
    required this.passwordController,
    required this.hidePassword,
    required this.togglePassword,
    required this.isLoading,
    required this.login,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final bool isDesktop = size.width > 900;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(
          Icons.fingerprint,
          size: isDesktop ? 120 : 90,
          color: Colors.indigo,
        ),
        SizedBox(height: isDesktop ? 24 : 16),

        Text(
          "Employee Attendance",
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: isDesktop ? 36 : 28,
            fontWeight: FontWeight.bold,
            color: Colors.indigo.shade700,
          ),
        ),

        SizedBox(height: isDesktop ? 16 : 8),

        Text(
          "Login to continue",
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: isDesktop ? 18 : 14,
            color: Colors.grey.shade600,
          ),
        ),

        SizedBox(height: isDesktop ? 40 : 32),

        TextFormField(
          controller: emailController,
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(
            labelText: "Email",
            prefixIcon: const Icon(Icons.email_outlined),
            border: const OutlineInputBorder(),
            filled: true,
            fillColor: Colors.grey.shade50,
          ),
          validator: (value) {
            if (value == null || value.isEmpty)
              return "User Name or Email is required";
            if (!value.contains("@")) return "Enter valid user name or email";
            return null;
          },
        ),

        SizedBox(height: isDesktop ? 24 : 16),

        TextFormField(
          controller: passwordController,
          obscureText: hidePassword,
          keyboardType: TextInputType.number,
          maxLength: 6,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(
            labelText: "Password",
            prefixIcon: const Icon(Icons.lock_outline),
            border: const OutlineInputBorder(),
            filled: true,
            fillColor: Colors.grey.shade50,
            counterText: "",
            suffixIcon: IconButton(
              icon: Icon(
                hidePassword ? Icons.visibility_off : Icons.visibility,
              ),
              onPressed: togglePassword,
            ),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) return "Password is required";
            if (!RegExp(r'^\d{6}$').hasMatch(value))
              return "Password must be exactly 6 digits";
            return null;
          },
        ),

        SizedBox(height: isDesktop ? 32 : 24),

        SizedBox(
          height: 50,
          child: ElevatedButton(
            onPressed: isLoading ? null : login,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.indigo,
              foregroundColor: const Color.fromARGB(255, 230, 231, 235),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: isLoading
                ? const CircularProgressIndicator(color: Colors.white)
                : const Text("LOGIN", style: TextStyle(fontSize: 16)),
          ),
        ),
      ],
    );
  }
}
