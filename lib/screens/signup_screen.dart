import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../ui_components.dart';
import '../utils/auth_validators.dart';
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
  final _confirmPasswordController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;
  String? _loadingProvider;

  @override
  void initState() {
    super.initState();
    _passwordController.addListener(_onPasswordChanged);
  }

  void _onPasswordChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _passwordController.removeListener(_onPasswordChanged);
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  Future<void> _signUpWithEmail() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _loadingProvider = 'email';
    });

    try {
      await _authService.signUpWithEmail(
          email: _emailController.text.trim(),
          password: _passwordController.text,
          fullName: _nameController.text.trim());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'Verification email sent. Please verify your email first to login to the app.')));
      }
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        _showError('That email is already registered. Please log in.');
      } else if (e.code == 'weak-password') {
        _showError('Use a stronger password to continue.');
      } else if (e.code == 'too-many-requests') {
        _showError('Too many attempts. Please wait a bit and try again.');
      } else if (e.code == 'network-request-failed') {
        _showError('Network error. Check internet and try again.');
      } else {
        _showError(e.message ??
            'Sign up failed. Please check your details and try again.');
      }
    } catch (_) {
      _showError('Sign up failed. Please check your details and try again.');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _loadingProvider = null;
        });
      }
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() {
      _isLoading = true;
      _loadingProvider = 'google';
    });
    try {
      await _authService.signInWithGoogle();
      if (mounted) {
        Navigator.popUntil(context, (route) => route.isFirst);
      }
    } catch (e) {
      if (!e.toString().contains('cancelled')) {
        _showError('Google sign-in failed.');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _loadingProvider = null;
        });
      }
    }
  }

  Future<void> _signInWithApple() async {
    setState(() {
      _isLoading = true;
      _loadingProvider = 'apple';
    });
    try {
      await _authService.signInWithApple();
      if (mounted) {
        Navigator.popUntil(context, (route) => route.isFirst);
      }
    } catch (e) {
      _showError('Apple sign-in failed.');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _loadingProvider = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isIOS = !kIsWeb && Platform.isIOS;
    final rules = AuthValidators.passwordRules(_passwordController.text);

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Image.asset(
                        isDark
                            ? 'assets/DarkThemeLogo.png'
                            : 'assets/LightThemeLogo.png',
                        height: 104,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Center(
                      child: Text('Create account',
                          style: TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onSurface,
                              letterSpacing: -1)),
                    ),
                    const SizedBox(height: 6),
                    Center(
                      child: Text('Get started with Protego today.',
                          style: TextStyle(
                            fontSize: 15,
                            color: isDark
                                ? const Color(0xFFA3A3A3)
                                : const Color(0xFF6B7280),
                          )),
                    ),
                    const SizedBox(height: 28),
                    buildTextField(
                      context: context,
                      label: 'Full Name',
                      hint: '',
                      controller: _nameController,
                      validator: AuthValidators.validateName,
                    ),
                    const SizedBox(height: 16),
                    buildTextField(
                      context: context,
                      label: 'Email address',
                      hint: '',
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      validator: AuthValidators.validateEmail,
                    ),
                    const SizedBox(height: 16),
                    buildTextField(
                      context: context,
                      label: 'Password',
                      hint: '••••••••',
                      controller: _passwordController,
                      obscure: _obscurePassword,
                      suffixIcon: IconButton(
                        icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                            color: isDark
                                ? const Color(0xFFB3B3B3)
                                : const Color(0xFF9CA3AF)),
                        onPressed: () => setState(
                            () => _obscurePassword = !_obscurePassword),
                      ),
                      validator: AuthValidators.validatePassword,
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _PasswordRuleTag(
                          label: '8+ chars',
                          isMet: rules.minLength,
                        ),
                        _PasswordRuleTag(
                          label: 'Uppercase',
                          isMet: rules.hasUppercase,
                        ),
                        _PasswordRuleTag(
                          label: 'Lowercase',
                          isMet: rules.hasLowercase,
                        ),
                        _PasswordRuleTag(
                          label: 'Number',
                          isMet: rules.hasNumber,
                        ),
                        _PasswordRuleTag(
                          label: 'Special char',
                          isMet: rules.hasSpecial,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    buildTextField(
                      context: context,
                      label: 'Confirm Password',
                      hint: '••••••••',
                      controller: _confirmPasswordController,
                      obscure: _obscureConfirmPassword,
                      suffixIcon: IconButton(
                        icon: Icon(
                            _obscureConfirmPassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                            color: isDark
                                ? const Color(0xFFB3B3B3)
                                : const Color(0xFF9CA3AF)),
                        onPressed: () => setState(() =>
                            _obscureConfirmPassword = !_obscureConfirmPassword),
                      ),
                      validator: (v) => AuthValidators.validateConfirmPassword(
                          v, _passwordController.text),
                    ),
                    const SizedBox(height: 24),
                    buildButton(
                      context: context,
                      label: 'Create account',
                      isLoading: _loadingProvider == 'email',
                      onPressed: _isLoading ? null : _signUpWithEmail,
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                            child: Divider(
                                color: isDark
                                    ? const Color(0xFF2A2A2A)
                                    : const Color(0xFFE5E7EB))),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12),
                          child: Text('OR',
                              style: TextStyle(
                                  color: Color(0xFFA3A3A3),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600)),
                        ),
                        Expanded(
                            child: Divider(
                                color: isDark
                                    ? const Color(0xFF2A2A2A)
                                    : const Color(0xFFE5E7EB))),
                      ],
                    ),
                    const SizedBox(height: 18),
                    buildButton(
                      context: context,
                      label: 'Continue with Phone',
                      isOutlined: true,
                      icon: Icon(Icons.phone_android,
                          color: theme.colorScheme.onSurface, size: 20),
                      isLoading: false,
                      onPressed: _isLoading
                          ? null
                          : () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const PhoneAuthScreen())),
                    ),
                    const SizedBox(height: 10),
                    buildButton(
                      context: context,
                      label: 'Continue with Google',
                      isOutlined: true,
                      isLoading: _loadingProvider == 'google',
                      onPressed: _isLoading ? null : _signInWithGoogle,
                    ),
                    if (isIOS) ...[
                      const SizedBox(height: 10),
                      buildButton(
                        context: context,
                        label: 'Continue with Apple',
                        isOutlined: true,
                        icon: Icon(Icons.apple,
                            color: theme.colorScheme.onSurface, size: 22),
                        isLoading: _loadingProvider == 'apple',
                        onPressed: _isLoading ? null : _signInWithApple,
                      ),
                    ],
                    const SizedBox(height: 22),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Already have an account?',
                            style: TextStyle(
                                color: isDark
                                    ? const Color(0xFFA3A3A3)
                                    : const Color(0xFF6B7280))),
                        TextButton(
                          onPressed: _isLoading
                              ? null
                              : () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) => const LoginScreen())),
                          child: Text('Log in',
                              style: TextStyle(
                                  color: theme.colorScheme.primary,
                                  fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PasswordRuleTag extends StatelessWidget {
  const _PasswordRuleTag({
    required this.label,
    required this.isMet,
  });

  final String label;
  final bool isMet;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOut,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isMet
            ? theme.colorScheme.primary.withValues(alpha: 0.18)
            : (isDark ? const Color(0xFF161616) : const Color(0xFFF3F4F6)),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: isMet
              ? theme.colorScheme.primary.withValues(alpha: 0.55)
              : (isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE5E7EB)),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: isMet
              ? theme.colorScheme.primary
              : (isDark ? const Color(0xFFA3A3A3) : const Color(0xFF6B7280)),
        ),
      ),
    );
  }
}
