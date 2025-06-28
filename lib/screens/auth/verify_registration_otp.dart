// lib/screens/auth/verify_registration_otp_screen.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../auth/auth_service.dart'; // sendRegistrationOtp & verifyRegistrationOtp
import 'package:go_router/go_router.dart';

class VerifyRegistrationOtp extends StatefulWidget {
  final String email;
  final String password;
  final String username;
  final String firstName;
  final String? lastName;
  final String country;
  final String province;
  final String city;
  final String gender;

  const VerifyRegistrationOtp({
    super.key,
    required this.email,
    required this.password,
    required this.username,
    required this.firstName,
    this.lastName,
    required this.country,
    required this.province,
    required this.city,
    required this.gender,
  });

  @override
  State<VerifyRegistrationOtp> createState() =>
      _VerifyRegistrationOtpState();
}

class _VerifyRegistrationOtpState
    extends State<VerifyRegistrationOtp> {
  final _otpController = TextEditingController();
  bool _isSending    = false; // "Send OTP" için loading flag
  bool _isVerifying  = false; // "Verify & Register" için loading flag
  bool _otpSent      = false;
  String? _errorMessage;
  int _secondsRemaining = 0;
  bool _canResend       = false;

  @override
  void initState() {
    super.initState();
    // Ekran açılınca otomatik OTP göndermek istemiyorsanız,
    // bu satırı kaldırın. Kendi isteğinize göre "Send OTP" butonuna basılsın.
    // _sendOtp();
  }

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  void _showError(String msg) {
    setState(() => _errorMessage = msg);
    Future.delayed(const Duration(seconds: 3), () {
      setState(() => _errorMessage = null);
    });
  }

  /// 1) "Send OTP" veya "Resend Code" tuşuna basıldığında çağrılır
  Future<void> _sendOtp() async {
    setState(() {
      _isSending = true;
      _errorMessage = null;
      _canResend = false;
      _secondsRemaining = 30;
    });

    final success = await AuthService.sendRegistrationOtp(widget.email);

    setState(() {
      _isSending = false;
      _otpSent = success;
    });

    if (success) {
      _startResendCountdown();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('A verification code has been sent to your email.'),
          backgroundColor: Colors.black87,
        ),
      );
    } else {
      _showError('Failed to send OTP. Please try again.');
    }
  }

  /// 30 saniyelik "yeniden gönderme" geri sayım mekanizması
  void _startResendCountdown() {
    Future.delayed(const Duration(seconds: 1), () {
      if (_secondsRemaining > 0) {
        setState(() => _secondsRemaining--);
        _startResendCountdown();
      } else {
        setState(() => _canResend = true);
      }
    });
  }

  /// 2) "Verify & Register" tuşuna basıldığında çağrılır
  Future<void> _verifyOtpAndRegister() async {
    final otp = _otpController.text.trim();
    if (otp.isEmpty) {
      _showError('Please enter the code you received in your email.');
      return;
    }

    setState(() {
      _isVerifying = true;
      _errorMessage = null;
    });

    final valid = await AuthService.verifyRegistrationOtp(widget.email, otp);

    if (!valid) {
      setState(() {
        _isVerifying = false;
        _errorMessage = 'Invalid or expired code.';
      });
      return;
    }

    // OTP geçerli → Firebase Auth ile kullanıcıyı oluştur, Firestore'a yaz
    try {
      final cred = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
        email: widget.email,
        password: widget.password,
      );
      final uid = cred.user!.uid;

      // Firestore profili
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .set({
        'username': widget.username,
        'firstName': widget.firstName,
        'lastName': widget.lastName,
        'email': widget.email,
        'role': 'user',
        'gender': widget.gender,
        'country': widget.country,
        'province': widget.province,
        'city': widget.city,
        'createdAt': FieldValue.serverTimestamp(),
        'completedOnboarding': false,
        'badgeShown': false,
      });

      // username rezervasyonu
      await FirebaseFirestore.instance
          .collection('usernames')
          .doc(widget.username)
          .set({'email': widget.email});

      setState(() => _isVerifying = false);
      if (!mounted) return;
      context.go('/onboarding');
    } on FirebaseAuthException catch (e) {
      String msg = 'Registration failed. Please try again.';
      if (e.code == 'weak-password') {
        msg = 'The password is too weak.';
      } else if (e.code == 'email-already-in-use') {
        msg = 'This email is already in use.';
        // Kullanıcıyı bir önceki ekrana yönlendir
        if (mounted) {
          _showError(msg);
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) context.pop();
          });
        }
        setState(() => _isVerifying = false);
        return;
      }
      setState(() {
        _isVerifying = false;
        _errorMessage = msg;
      });
    } catch (e) {
      setState(() {
        _isVerifying = false;
        _errorMessage = 'Unexpected error. Please try again.';
      });
    }
  }

  String _maskedEmail(String email) {
    final atIdx = email.indexOf('@');
    if (atIdx <= 2) return email; // too short to mask
    final first = email.substring(0, 2);
    final last = email.substring(atIdx - 2, atIdx);
    final domain = email.substring(atIdx);
    return '$first***$last$domain';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F2FA),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.deepPurple),
          onPressed: () => context.pop(),
          tooltip: 'Back',
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.only(left: 20.0, right: 20.0, top: 32.0, bottom: 0.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              const Text(
                'Verify your email',
                style: TextStyle(
                  fontSize: 28,
                  color: Colors.deepPurple,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 18),
              Card(
                elevation: 6,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 28.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_errorMessage != null) ...[
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12.0),
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(color: Colors.red, fontSize: 14),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                      Text(
                        _maskedEmail(widget.email),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                          letterSpacing: 0.2,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: _isSending ? null : _sendOtp,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.deepPurple.shade100,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                            textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          child: _isSending
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    color: Color.fromARGB(255, 120, 60, 200),
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(
                                  _canResend
                                      ? 'Resend OTP'
                                      : _otpSent
                                          ? 'OTP Sent'
                                          : 'Send OTP',
                                  style: const TextStyle(color: Colors.deepPurple),
                                ),
                        ),
                      ),
                      if (_secondsRemaining > 0)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            'You can resend the code in $_secondsRemaining seconds.',
                            style: const TextStyle(fontSize: 13, color: Colors.black54),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      const SizedBox(height: 18),
                      TextField(
                        controller: _otpController,
                        decoration: InputDecoration(
                          labelText: 'Enter the code.',
                          labelStyle: const TextStyle(color: Colors.grey),
                          prefixIcon: const Icon(Icons.verified_user_outlined),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          filled: true,
                          fillColor: Colors.grey[100],
                        ),
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.left,
                        style: const TextStyle(letterSpacing: 4, fontSize: 18),
                        maxLength: 6,
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: _isVerifying ? null : _verifyOtpAndRegister,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.deepPurple,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          child: _isVerifying
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    color: Color.fromARGB(255, 255, 255, 255),
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text('Verify & Register', style: TextStyle(color: Colors.white)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
