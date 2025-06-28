// lib/screens/auth/forgot_password_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import '../auth/auth_service.dart';  // Yeni AuthService metodları
import 'package:go_router/go_router.dart';

/// Burada kullanıcı e-posta girer → OTP gönderir → OTP'yi doğrular → Yeni şifre ekranına gider.
class ForgotPassword extends StatefulWidget {
  const ForgotPassword({super.key});

  @override
  State<ForgotPassword> createState() => _ForgotPasswordState();
}

class _ForgotPasswordState extends State<ForgotPassword> {
  final _emailController = TextEditingController();
  final _otpController   = TextEditingController();

  bool _isSendingOtp   = false;  // "Send OTP" basıldı mı?
  bool _isVerifyingOtp = false;  // "Verify Code" basıldı mı?
  bool _otpSent        = false;  // OTP başarıyla gönderildi mi?
  String? _errorMessage;

  // 30 saniyelik "yeniden gönderme engeli" için:
  Timer? _sendCooldownTimer;
  int _secondsLeft = 0;

  void _showError(String message) {
    setState(() => _errorMessage = message);
    Future.delayed(const Duration(seconds: 3), () {
      setState(() => _errorMessage = null);
    });
  }

  @override
  void dispose() {
    _sendCooldownTimer?.cancel();
    _emailController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  /// 1) Send OTP: _sendOtp()
  Future<void> _sendOtp() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      _showError('Please enter a valid email address.');
      return;
    }

    setState(() {
      _isSendingOtp = true;
      _errorMessage = null;
    });

    // Yeni metoda yönlendiriyoruz:
    final success = await AuthService.sendPasswordResetOtp(email);

    setState(() {
      _isSendingOtp = false;
    });

    if (success) {
      setState(() {
        _otpSent = true;
        _secondsLeft = 30;
      });
      _startSendCooldown();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('OTP code has been sent to your email.')),
      );
    } else {
      _showError('Failed to send OTP. Please try again.');
    }
  }

  void _startSendCooldown() {
    _sendCooldownTimer?.cancel();
    _sendCooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsLeft <= 1) {
        timer.cancel();
        setState(() {
          _secondsLeft = 0;
        });
      } else {
        setState(() {
          _secondsLeft -= 1;
        });
      }
    });
  }

  /// 2) Verify OTP: _verifyOtp()
  Future<void> _verifyOtp() async {
    final email = _emailController.text.trim();
    final otp   = _otpController.text.trim();
    if (otp.isEmpty) {
      _showError('Please enter the code you received in your email.');
      return;
    }

    setState(() {
      _isVerifyingOtp = true;
      _errorMessage   = null;
    });

    // Yeni metoda yönlendiriyoruz:
    final valid = await AuthService.verifyPasswordResetOtp(email, otp);

    setState(() {
      _isVerifyingOtp = false;
    });

    if (valid) {
      // Kod doğru → kullanıcı yeni şifre girebileceği ekrana yönlendir
      context.push('/resetPassword', extra: {
        'email': email,
        'otp': otp,
      });
    } else {
      _showError('The code is invalid or expired.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.deepPurple),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Reset Password',
          style: TextStyle(color: Colors.deepPurple),
        ),
        centerTitle: true,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF8FAFF), Color(0xFFE8F0FE)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Card(
                    elevation: 3,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    color: Colors.white,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 28),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'Forgot your password?',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'Enter your email address to receive a verification code.',
                            style: TextStyle(fontSize: 15, color: Colors.black54),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 18),
                          if (_errorMessage != null) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                              decoration: BoxDecoration(
                                color: Colors.red.shade50,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.error_outline, color: Colors.red, size: 18),
                                  const SizedBox(width: 8),
                                  Expanded(child: Text(_errorMessage!, style: const TextStyle(color: Colors.red))),
                                ],
                              ),
                            ),
                            const SizedBox(height: 10),
                          ],
                          TextField(
                            controller: _emailController,
                            decoration: InputDecoration(
                              labelText: 'Your Email Address',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                              prefixIcon: const Icon(Icons.email_outlined),
                              filled: true,
                              fillColor: Colors.grey[100],
                            ),
                            keyboardType: TextInputType.emailAddress,
                          ),
                          const SizedBox(height: 18),
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: ElevatedButton(
                              onPressed: (_isSendingOtp || _secondsLeft > 0) ? null : _sendOtp,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: (_secondsLeft > 0 || _isSendingOtp)
                                    ? Colors.grey
                                    : Colors.deepPurple,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                              ),
                              child: _isSendingOtp
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                    )
                                  : (_secondsLeft > 0
                                      ? Text('Send OTP ($_secondsLeft s)')
                                      : const Text('Send OTP')),
                            ),
                          ),
                          if (_otpSent) ...[
                            const SizedBox(height: 28),
                            Divider(height: 1, color: Colors.grey.shade200),
                            const SizedBox(height: 24),
                            TextField(
                              controller: _otpController,
                              decoration: InputDecoration(
                                labelText: 'Enter the Code from Your Email',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                                prefixIcon: const Icon(Icons.verified_user_outlined),
                                filled: true,
                                fillColor: Colors.grey[100],
                              ),
                              keyboardType: TextInputType.number,
                            ),
                            const SizedBox(height: 18),
                            SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: ElevatedButton(
                                onPressed: _isVerifyingOtp ? null : _verifyOtp,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.indigo.shade400,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                  textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                                ),
                                child: _isVerifyingOtp
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                      )
                                    : const Text('Verify Code'),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// "Verify Password Reset OTP" sonrası yeni şifre girişi
class ResetPassword extends StatefulWidget {
  final String email;
  final String otp;

  const ResetPassword({
    super.key,
    required this.email,
    required this.otp,
  });

  @override
  State<ResetPassword> createState() => _ResetPasswordState();
}

class _ResetPasswordState extends State<ResetPassword> {
  final _newPasswordController     = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _passwordVisible = false;
  bool _isLoading       = false;
  String? _errorMessage;

  bool _isPasswordValid(String password) {
    final regex = RegExp(
      r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&])[A-Za-z\d@$!%*?&]{8,}$',
    );
    return regex.hasMatch(password);
  }

  Future<void> _resetPassword() async {
    final newPass = _newPasswordController.text.trim();
    final confirm = _confirmPasswordController.text.trim();

    if (newPass != confirm) {
      setState(() => _errorMessage = 'Passwords do not match.');
      return;
    }
    if (!_isPasswordValid(newPass)) {
      setState(() => _errorMessage =
      'Password must be at least 8 chars, include upper & lower case, number & special character.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final success = await AuthService.resetPasswordWithOtp(
      widget.email,
      widget.otp,
      newPass,
    );

    setState(() => _isLoading = false);

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Your password has been successfully changed.')),
      );
      Navigator.pushReplacementNamed(context, '/login');
    } else {
      setState(() => _errorMessage = 'Password reset failed. Please try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Set New Password')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            if (_errorMessage != null) ...[
              Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 8),
            ],
            TextField(
              controller: _newPasswordController,
              obscureText: !_passwordVisible,
              decoration: InputDecoration(
                labelText: 'New Password',
                suffixIcon: IconButton(
                  icon: Icon(
                    _passwordVisible ? Icons.visibility : Icons.visibility_off,
                  ),
                  onPressed: () =>
                      setState(() => _passwordVisible = !_passwordVisible),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _confirmPasswordController,
              obscureText: !_passwordVisible,
              decoration: const InputDecoration(
                labelText: 'Confirm Password',
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isLoading ? null : _resetPassword,
              child: _isLoading
                  ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
                  : const Text('Change Password'),
            ),
          ],
        ),
      ),
    );
  }
}
