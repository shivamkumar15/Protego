import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/auth_service.dart';

class PhoneAuthScreen extends StatefulWidget {
  const PhoneAuthScreen({super.key});

  @override
  State<PhoneAuthScreen> createState() => _PhoneAuthScreenState();
}

class _PhoneAuthScreenState extends State<PhoneAuthScreen>
    with SingleTickerProviderStateMixin {
  final _authService = AuthService();
  final _phoneController = TextEditingController();
  final _countryCodeController = TextEditingController(text: '+91');

  // OTP controllers — one per digit
  final List<TextEditingController> _otpControllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _otpFocusNodes = List.generate(6, (_) => FocusNode());

  bool _isLoading = false;
  bool _codeSent = false;
  String? _verificationId;
  int? _resendToken;
  int _resendSeconds = 0;
  Timer? _resendTimer;

  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _animController.forward();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _countryCodeController.dispose();
    for (final c in _otpControllers) {
      c.dispose();
    }
    for (final n in _otpFocusNodes) {
      n.dispose();
    }
    _resendTimer?.cancel();
    _animController.dispose();
    super.dispose();
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFFD93627),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFF2E7D32),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _startResendTimer() {
    _resendSeconds = 60;
    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _resendSeconds--;
        if (_resendSeconds <= 0) {
          timer.cancel();
        }
      });
    });
  }

  Future<void> _sendOTP({bool resend = false}) async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) {
      _showError('Please enter your phone number.');
      return;
    }

    final fullPhone = '${_countryCodeController.text.trim()}$phone';

    setState(() => _isLoading = true);

    await _authService.signInWithPhone(
      phoneNumber: fullPhone,
      forceResendingToken: resend ? _resendToken : null,
      onCodeSent: (verificationId, resendToken) {
        if (!mounted) return;
        setState(() {
          _verificationId = verificationId;
          _resendToken = resendToken;
          _codeSent = true;
          _isLoading = false;
        });
        _startResendTimer();
        // Reset animation for OTP view
        _animController.reset();
        _animController.forward();
        // Auto focus first OTP field
        Future.delayed(const Duration(milliseconds: 400), () {
          if (mounted) _otpFocusNodes[0].requestFocus();
        });
      },
      onAutoVerified: (credential) async {
        // Auto-verification (Android only)
        try {
          await _authService.signInWithCredential(credential);
          _showSuccess('Phone verified automatically!');
          if (mounted) {
            Navigator.popUntil(context, (route) => route.isFirst);
          }
        } on Exception catch (_) {
          // Will be handled by normal flow
        }
      },
      onError: (e) {
        if (!mounted) return;
        setState(() => _isLoading = false);
        String msg;
        switch (e.code) {
          case 'invalid-phone-number':
            msg = 'Invalid phone number format.';
            break;
          case 'too-many-requests':
            msg = 'Too many attempts. Try again later.';
            break;
          case 'quota-exceeded':
            msg = 'SMS quota exceeded. Try again later.';
            break;
          default:
            msg = e.message ?? 'Failed to send verification code.';
        }
        _showError(msg);
      },
    );
  }

  Future<void> _verifyOTP() async {
    final otp = _otpControllers.map((c) => c.text).join();
    if (otp.length != 6) {
      _showError('Please enter the complete 6-digit code.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _authService.verifyOTP(
        verificationId: _verificationId!,
        smsCode: otp,
      );
      _showSuccess('Phone verified successfully!');
      if (mounted) {
        Navigator.popUntil(context, (route) => route.isFirst);
      }
      // Auth state change will handle navigation
    } on Exception catch (e) {
      final errorStr = e.toString();
      if (errorStr.contains('invalid-verification-code')) {
        _showError('Invalid code. Please check and try again.');
      } else if (errorStr.contains('session-expired')) {
        _showError('Code expired. Please request a new one.');
      } else {
        _showError('Verification failed. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Stack(
        children: [
          // Background Blobs
          Positioned(
            top: size.height * 0.2,
            left: -size.width * 0.1,
            child: Container(
              width: size.width * 0.5,
              height: size.height * 0.5,
              decoration: BoxDecoration(
                color: const Color(0xFF0a2f1f).withOpacity(0.5),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            bottom: size.height * 0.1,
            right: -size.width * 0.15,
            child: Container(
              width: size.width * 0.45,
              height: size.height * 0.45,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
            ),
          ),

          // Backdrop blur
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
              child: Container(color: Colors.transparent),
            ),
          ),

          // Content
          SafeArea(
            child: Column(
              children: [
                // App Bar
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8.0, vertical: 8.0),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: Icon(
                          Icons.arrow_back_ios_new,
                          color: theme.colorScheme.primary,
                          size: 22,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'PHONE VERIFICATION',
                        style: theme.textTheme.labelLarge,
                      ),
                      const Spacer(),
                      const SizedBox(width: 48), // balance
                    ],
                  ),
                ),

                // Scrollable content
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24.0, vertical: 16.0),
                      child: FadeTransition(
                        opacity: _fadeAnim,
                        child: _codeSent
                            ? _buildOTPView(theme)
                            : _buildPhoneInputView(theme),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Decorative Bottom Line
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 4,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.transparent,
                    theme.colorScheme.primary.withOpacity(0.5),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhoneInputView(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Icon
        Container(
          width: 80,
          height: 80,
          margin: const EdgeInsets.only(bottom: 32),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                theme.colorScheme.primary.withOpacity(0.2),
                theme.colorScheme.primary.withOpacity(0.05),
              ],
            ),
            border: Border.all(
              color: theme.colorScheme.primary.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Icon(
            Icons.phone_android,
            color: theme.colorScheme.primary,
            size: 36,
          ),
        ),

        Text(
          'Enter Your Number',
          textAlign: TextAlign.center,
          style: theme.textTheme.displayLarge?.copyWith(fontSize: 28),
        ),
        const SizedBox(height: 8),
        Text(
          "We'll send a 6-digit verification code to your phone.",
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyLarge,
        ),
        const SizedBox(height: 40),

        // Card
        Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: const Color(0xFF1B1B1B),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.5),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 8),
                child: Text('PHONE NUMBER', style: theme.textTheme.labelLarge),
              ),

              // Phone input row
              Row(
                children: [
                  // Country code
                  SizedBox(
                    width: 80,
                    child: TextFormField(
                      controller: _countryCodeController,
                      keyboardType: TextInputType.phone,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: Colors.white),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: const Color(0xFF0A0A0A),
                        contentPadding: const EdgeInsets.symmetric(
                            vertical: 20, horizontal: 8),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color: theme.colorScheme.primary.withOpacity(0.5),
                            width: 1,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Phone number
                  Expanded(
                    child: TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: Colors.white),
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      decoration: InputDecoration(
                        hintText: '9876543210',
                        hintStyle: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withOpacity(0.3),
                        ),
                        prefixIcon: Icon(Icons.smartphone,
                            color: Colors.white.withOpacity(0.3), size: 22),
                        filled: true,
                        fillColor: const Color(0xFF0A0A0A),
                        contentPadding: const EdgeInsets.symmetric(
                            vertical: 20, horizontal: 16),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color: theme.colorScheme.primary.withOpacity(0.5),
                            width: 1,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // Send OTP button
              _buildPrimaryButton(
                theme: theme,
                label: 'Send Verification Code',
                isLoading: _isLoading,
                onPressed: _isLoading ? null : () => _sendOTP(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOTPView(ThemeData theme) {
    final maskedPhone =
        '${_countryCodeController.text} ••••${_phoneController.text.length > 4 ? _phoneController.text.substring(_phoneController.text.length - 4) : _phoneController.text}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Icon
        Container(
          width: 80,
          height: 80,
          margin: const EdgeInsets.only(bottom: 32),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF2E7D32).withOpacity(0.2),
                const Color(0xFF2E7D32).withOpacity(0.05),
              ],
            ),
            border: Border.all(
              color: const Color(0xFF2E7D32).withOpacity(0.3),
              width: 1,
            ),
          ),
          child: const Icon(
            Icons.sms_outlined,
            color: Color(0xFF66BB6A),
            size: 36,
          ),
        ),

        Text(
          'Verify Code',
          textAlign: TextAlign.center,
          style: theme.textTheme.displayLarge?.copyWith(fontSize: 28),
        ),
        const SizedBox(height: 8),
        Text(
          'Enter the 6-digit code sent to\n$maskedPhone',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyLarge,
        ),
        const SizedBox(height: 40),

        // Card
        Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: const Color(0xFF1B1B1B),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.5),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 16),
                child: Text('VERIFICATION CODE',
                    style: theme.textTheme.labelLarge),
              ),

              // OTP input boxes
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(6, (i) {
                  return SizedBox(
                    width: 44,
                    child: TextFormField(
                      controller: _otpControllers[i],
                      focusNode: _otpFocusNodes[i],
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      maxLength: 1,
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      decoration: InputDecoration(
                        counterText: '',
                        filled: true,
                        fillColor: const Color(0xFF0A0A0A),
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 16),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: theme.colorScheme.primary.withOpacity(0.5),
                            width: 1.5,
                          ),
                        ),
                      ),
                      onChanged: (value) {
                        if (value.isNotEmpty && i < 5) {
                          _otpFocusNodes[i + 1].requestFocus();
                        }
                        if (value.isEmpty && i > 0) {
                          _otpFocusNodes[i - 1].requestFocus();
                        }
                        // Auto-verify when all 6 digits entered
                        if (i == 5 && value.isNotEmpty) {
                          final otp =
                              _otpControllers.map((c) => c.text).join();
                          if (otp.length == 6) {
                            _verifyOTP();
                          }
                        }
                      },
                    ),
                  );
                }),
              ),
              const SizedBox(height: 32),

              // Verify Button
              _buildPrimaryButton(
                theme: theme,
                label: 'Verify & Continue',
                isLoading: _isLoading,
                onPressed: _isLoading ? null : _verifyOTP,
              ),
              const SizedBox(height: 16),

              // Resend
              Center(
                child: _resendSeconds > 0
                    ? Text(
                        'Resend code in ${_resendSeconds}s',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.white.withOpacity(0.4),
                        ),
                      )
                    : TextButton(
                        onPressed:
                            _isLoading ? null : () => _sendOTP(resend: true),
                        child: Text(
                          'Resend Code',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
              ),

              const SizedBox(height: 8),

              // Change number
              Center(
                child: TextButton(
                  onPressed: _isLoading
                      ? null
                      : () {
                          setState(() {
                            _codeSent = false;
                            for (final c in _otpControllers) {
                              c.clear();
                            }
                          });
                          _animController.reset();
                          _animController.forward();
                        },
                  child: Text(
                    'Change Number',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.white.withOpacity(0.5),
                      decoration: TextDecoration.underline,
                      decorationColor: Colors.white.withOpacity(0.3),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPrimaryButton({
    required ThemeData theme,
    required String label,
    required bool isLoading,
    VoidCallback? onPressed,
  }) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          colors: [Color(0xFFFFB4AA), Color(0xFFD93627)],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF5545).withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        onPressed: onPressed,
        child: isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: Color(0xFF690003),
                  strokeWidth: 2.5,
                ),
              )
            : Text(
                label,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: const Color(0xFF690003),
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }
}
