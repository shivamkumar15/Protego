import os

main_code = """import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'screens/signup_screen.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const ProtegoApp());
}

class ProtegoApp extends StatelessWidget {
  const ProtegoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Protego',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.light,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        primaryColor: const Color(0xFFF71180),
        scaffoldBackgroundColor: Colors.white,
        colorScheme: const ColorScheme.light(
          primary: Color(0xFFF71180),
          secondary: Color(0xFFF71180),
          surface: Colors.white,
          onSurface: Color(0xFF111827),
        ),
        fontFamily: 'Inter',
      ),
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Colors.white,
            body: Center(
              child: CircularProgressIndicator(color: Color(0xFFF71180)),
            ),
          );
        }
        if (snapshot.hasData) {
          return const HomeScreen();
        }
        return const SignUpScreen();
      },
    );
  }
}
"""

ui_code = """import 'package:flutter/material.dart';

Widget buildTextField({
  required String label,
  required String hint,
  required TextEditingController controller,
  bool obscure = false,
  TextInputType keyboardType = TextInputType.text,
  Widget? suffixIcon,
  String? Function(String?)? validator,
}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF4B5563))),
      const SizedBox(height: 8),
      TextFormField(
        controller: controller,
        obscureText: obscure,
        keyboardType: keyboardType,
        validator: validator,
        style: const TextStyle(color: Color(0xFF111827)),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
          suffixIcon: suffixIcon,
          filled: true,
          fillColor: const Color(0xFFF9FAFB),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFF71180), width: 1.5)),
          errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.red, width: 1)),
          focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.red, width: 1.5)),
        ),
      ),
    ],
  );
}

Widget buildButton({
  required String label,
  required bool isLoading,
  required VoidCallback? onPressed,
  bool isOutlined = false,
  Widget? icon,
}) {
  if (isOutlined) {
    return SizedBox(
      height: 52,
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: icon ?? const SizedBox.shrink(),
        label: isLoading 
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF111827))) 
            : Text(label, style: const TextStyle(color: Color(0xFF111827), fontWeight: FontWeight.w600, fontSize: 16)),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Color(0xFFE5E7EB)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  return SizedBox(
    height: 52,
    width: double.infinity,
    child: ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFFF71180),
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: isLoading
          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
          : Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
    ),
  );
}
"""

login_code = """import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../ui_components.dart';
import 'phone_auth_screen.dart';
import 'signup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _authService = AuthService();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _loadingProvider;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  Future<void> _signInWithEmail() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _isLoading = true; _loadingProvider = 'email'; });
    try {
      await _authService.signInWithEmail(email: _emailController.text.trim(), password: _passwordController.text);
      if (mounted) Navigator.popUntil(context, (route) => route.isFirst);
    } catch (e) {
      _showError('Invalid email or password.');
    } finally {
      if (mounted) setState(() { _isLoading = false; _loadingProvider = null; });
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() { _isLoading = true; _loadingProvider = 'google'; });
    try {
      await _authService.signInWithGoogle();
      if (mounted) Navigator.popUntil(context, (route) => route.isFirst);
    } catch (e) {
      if (!e.toString().contains('cancelled')) _showError('Google sign-in failed.');
    } finally {
      if (mounted) setState(() { _isLoading = false; _loadingProvider = null; });
    }
  }

  Future<void> _signInWithApple() async {
    setState(() { _isLoading = true; _loadingProvider = 'apple'; });
    try {
      await _authService.signInWithApple();
      if (mounted) Navigator.popUntil(context, (route) => route.isFirst);
    } catch (e) {
      _showError('Apple sign-in failed.');
    } finally {
      if (mounted) setState(() { _isLoading = false; _loadingProvider = null; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isIOS = !kIsWeb && Platform.isIOS;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF111827)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Image.asset('assets/logo.png', height: 48),
                const SizedBox(height: 24),
                const Text('Welcome back', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Color(0xFF111827), letterSpacing: -1)),
                const SizedBox(height: 8),
                const Text('Sign in to your account to continue', style: TextStyle(fontSize: 16, color: Color(0xFF6B7280))),
                const SizedBox(height: 40),
                buildTextField(
                  label: 'Email address',
                  
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) => v!.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 20),
                buildTextField(
                  label: 'Password',
                  hint: '••••••••',
                  controller: _passwordController,
                  obscure: _obscurePassword,
                  suffixIcon: IconButton(
                    icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, color: const Color(0xFF9CA3AF)),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                  validator: (v) => v!.isEmpty ? 'Required' : null,
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {
                       if (_emailController.text.isNotEmpty) {
                         _authService.sendPasswordResetEmail(_emailController.text);
                         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Reset link sent')));
                       } else {
                         _showError('Enter your email first');
                       }
                    },
                    child: const Text('Forgot password?', style: TextStyle(color: Color(0xFFF71180), fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(height: 24),
                buildButton(
                  label: 'Sign in',
                  isLoading: _loadingProvider == 'email',
                  onPressed: _isLoading ? null : _signInWithEmail,
                ),
                const SizedBox(height: 24),
                Row(
                  children: const [
                    Expanded(child: Divider(color: Color(0xFFE5E7EB))),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Text('OR', style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 12, fontWeight: FontWeight.w600)),
                    ),
                    Expanded(child: Divider(color: Color(0xFFE5E7EB))),
                  ],
                ),
                const SizedBox(height: 24),
                buildButton(
                  label: 'Continue with Phone',
                  isOutlined: true,
                  icon: const Icon(Icons.phone_android, color: Color(0xFF111827), size: 20),
                  isLoading: false,
                  onPressed: _isLoading ? null : () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PhoneAuthScreen())),
                ),
                const SizedBox(height: 12),
                buildButton(
                  label: 'Continue with Google',
                  isOutlined: true,
                  isLoading: _loadingProvider == 'google',
                  onPressed: _isLoading ? null : _signInWithGoogle,
                ),
                if (isIOS) ...[
                  const SizedBox(height: 12),
                  buildButton(
                    label: 'Continue with Apple',
                    isOutlined: true,
                    icon: const Icon(Icons.apple, color: Color(0xFF111827), size: 22),
                    isLoading: _loadingProvider == 'apple',
                    onPressed: _isLoading ? null : _signInWithApple,
                  ),
                ],
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
"""

signup_code = """import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../ui_components.dart';
import 'phone_auth_screen.dart';
import 'login_screen.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});
  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _authService = AuthService();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _loadingProvider;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  Future<void> _signUpWithEmail() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _isLoading = true; _loadingProvider = 'email'; });
    try {
      await _authService.signUpWithEmail(email: _emailController.text.trim(), password: _passwordController.text, fullName: _nameController.text.trim());
      if (mounted) Navigator.popUntil(context, (route) => route.isFirst);
    } catch (e) {
      _showError('Sign up failed.');
    } finally {
      if (mounted) setState(() { _isLoading = false; _loadingProvider = null; });
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() { _isLoading = true; _loadingProvider = 'google'; });
    try {
      await _authService.signInWithGoogle();
      if (mounted) Navigator.popUntil(context, (route) => route.isFirst);
    } catch (e) {
      if (!e.toString().contains('cancelled')) _showError('Google sign-in failed.');
    } finally {
      if (mounted) setState(() { _isLoading = false; _loadingProvider = null; });
    }
  }

  Future<void> _signInWithApple() async {
    setState(() { _isLoading = true; _loadingProvider = 'apple'; });
    try {
      await _authService.signInWithApple();
      if (mounted) Navigator.popUntil(context, (route) => route.isFirst);
    } catch (e) {
      _showError('Apple sign-in failed.');
    } finally {
      if (mounted) setState(() { _isLoading = false; _loadingProvider = null; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isIOS = !kIsWeb && Platform.isIOS;
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Image.asset('assets/logo.png', height: 48),
                const SizedBox(height: 24),
                const Text('Create account', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Color(0xFF111827), letterSpacing: -1)),
                const SizedBox(height: 8),
                const Text('Get started with Protego today.', style: TextStyle(fontSize: 16, color: Color(0xFF6B7280))),
                const SizedBox(height: 40),
                buildTextField(
                  label: 'Full Name',
                  
                  controller: _nameController,
                  validator: (v) => v!.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 20),
                buildTextField(
                  label: 'Email address',
                  hint: 'name@example.com',
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) => v!.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 20),
                buildTextField(
                  label: 'Password',
                  hint: '••••••••',
                  controller: _passwordController,
                  obscure: _obscurePassword,
                  suffixIcon: IconButton(
                    icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, color: const Color(0xFF9CA3AF)),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                  validator: (v) => v!.length < 6 ? 'At least 6 characters' : null,
                ),
                const SizedBox(height: 32),
                buildButton(
                  label: 'Create account',
                  isLoading: _loadingProvider == 'email',
                  onPressed: _isLoading ? null : _signUpWithEmail,
                ),
                const SizedBox(height: 24),
                Row(
                  children: const [
                    Expanded(child: Divider(color: Color(0xFFE5E7EB))),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Text('OR', style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 12, fontWeight: FontWeight.w600)),
                    ),
                    Expanded(child: Divider(color: Color(0xFFE5E7EB))),
                  ],
                ),
                const SizedBox(height: 24),
                buildButton(
                  label: 'Continue with Phone',
                  isOutlined: true,
                  icon: const Icon(Icons.phone_android, color: Color(0xFF111827), size: 20),
                  isLoading: false,
                  onPressed: _isLoading ? null : () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PhoneAuthScreen())),
                ),
                const SizedBox(height: 12),
                buildButton(
                  label: 'Continue with Google',
                  isOutlined: true,
                  isLoading: _loadingProvider == 'google',
                  onPressed: _isLoading ? null : _signInWithGoogle,
                ),
                if (isIOS) ...[
                  const SizedBox(height: 12),
                  buildButton(
                    label: 'Continue with Apple',
                    isOutlined: true,
                    icon: const Icon(Icons.apple, color: Color(0xFF111827), size: 22),
                    isLoading: _loadingProvider == 'apple',
                    onPressed: _isLoading ? null : _signInWithApple,
                  ),
                ],
                const SizedBox(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Already have an account?', style: TextStyle(color: Color(0xFF6B7280))),
                    TextButton(
                      onPressed: _isLoading ? null : () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen())),
                      child: const Text('Log in', style: TextStyle(color: Color(0xFFF71180), fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
"""

phone_code = """import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../ui_components.dart';

class PhoneAuthScreen extends StatefulWidget {
  const PhoneAuthScreen({super.key});
  @override
  State<PhoneAuthScreen> createState() => _PhoneAuthScreenState();
}

class _PhoneAuthScreenState extends State<PhoneAuthScreen> {
  final _authService = AuthService();
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();
  bool _isLoading = false;
  bool _codeSent = false;
  String? _verificationId;

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  Future<void> _sendOTP() async {
    if (_phoneController.text.isEmpty) return;
    setState(() => _isLoading = true);
    await _authService.signInWithPhone(
      phoneNumber: '+91${_phoneController.text.trim()}',
      onCodeSent: (verificationId, resendToken) {
        if (mounted) setState(() { _verificationId = verificationId; _codeSent = true; _isLoading = false; });
      },
      onAutoVerified: (credential) async {
        try {
          await _authService.signInWithCredential(credential);
          if (mounted) Navigator.popUntil(context, (route) => route.isFirst);
        } catch (_) {}
      },
      onError: (e) {
        if (mounted) {
          setState(() => _isLoading = false);
          _showError('Failed to send code.');
        }
      },
    );
  }

  Future<void> _verifyOTP() async {
    if (_codeController.text.length != 6) return;
    setState(() => _isLoading = true);
    try {
      await _authService.verifyOTP(verificationId: _verificationId!, smsCode: _codeController.text);
      if (mounted) Navigator.popUntil(context, (route) => route.isFirst);
    } catch (e) {
      _showError('Invalid verification code.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF111827)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_codeSent ? 'Enter Code' : 'What is your number?', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Color(0xFF111827), letterSpacing: -1)),
              const SizedBox(height: 8),
              Text(
                _codeSent ? 'We sent a 6-digit code to your phone.' : 'We will send a verification code to this number.', 
                style: const TextStyle(fontSize: 16, color: Color(0xFF6B7280))
              ),
              const SizedBox(height: 40),
              if (!_codeSent) ...[
                buildTextField(
                  label: 'Phone Number',
                  hint: '9876543210',
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 32),
                buildButton(
                  label: 'Send Code',
                  isLoading: _isLoading,
                  onPressed: _isLoading ? null : _sendOTP,
                ),
              ] else ...[
                buildTextField(
                  label: 'Verification Code',
                  hint: '123456',
                  controller: _codeController,
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 32),
                buildButton(
                  label: 'Verify',
                  isLoading: _isLoading,
                  onPressed: _isLoading ? null : _verifyOTP,
                ),
                const SizedBox(height: 16),
                Center(
                  child: TextButton(
                    onPressed: () => setState(() => _codeSent = false),
                    child: const Text('Change Number', style: TextStyle(color: Color(0xFFF71180), fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
"""

home_code = """import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final authService = AuthService();

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('Dashboard', style: TextStyle(color: Color(0xFF111827), fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Color(0xFF111827)),
            onPressed: () => authService.signOut(),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: const Color(0xFFE5E7EB), height: 1),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Overview', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE5E7EB)),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4)),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF71180).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.shield_outlined, color: Color(0xFFF71180)),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Protection Active', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF111827))),
                        const SizedBox(height: 4),
                        Text(user?.email ?? user?.phoneNumber ?? 'Guardian connected', style: const TextStyle(color: Color(0xFF6B7280), fontSize: 14)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
"""

with open('lib/ui_components.dart', 'w') as f: f.write(ui_code)
with open('lib/main.dart', 'w') as f: f.write(main_code)
with open('lib/screens/login_screen.dart', 'w') as f: f.write(login_code)
with open('lib/screens/signup_screen.dart', 'w') as f: f.write(signup_code)
with open('lib/screens/phone_auth_screen.dart', 'w') as f: f.write(phone_code)
with open('lib/screens/home_screen.dart', 'w') as f: f.write(home_code)
