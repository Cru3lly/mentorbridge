// lib/screens/auth/reset_password_screen.dart

import 'package:flutter/material.dart';
import '../auth/auth_service.dart';
import 'package:go_router/go_router.dart';

/// OTP doğrulandıktan sonra kullanıcı yeni şifresini girecek.
/// AppBar'daki "home" ikonu sağ üstte olacak; basınca /login rotasına dönecek.
class ResetPassword extends StatefulWidget {
  final String email;  // Doğrulanan e-posta
  final String otp;    // Doğrulanan OTP kodu

  const ResetPassword({
    super.key,
    required this.email,
    required this.otp,
  });

  static ResetPassword fromGoRouter(BuildContext context) {
    final extra = GoRouterState.of(context).extra as Map<String, dynamic>?;
    return ResetPassword(
      email: extra?['email'] ?? '',
      otp: extra?['otp'] ?? '',
    );
  }

  @override
  State<ResetPassword> createState() => _ResetPasswordState();
}

class _ResetPasswordState extends State<ResetPassword> {
  final _newPasswordController     = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _passwordVisible = false;
  bool _isLoading       = false;
  String? _errorMessage;

  int _passwordStrength = 0; // 0-4
  String _passwordStrengthText = '';
  Color _passwordStrengthColor = Colors.red;
  String _confirmPasswordMessage = '';
  Color _confirmPasswordColor = Colors.red;

  @override
  void initState() {
    super.initState();
    _newPasswordController.addListener(_updatePasswordStrength);
    _confirmPasswordController.addListener(_checkPasswordMatch);
  }

  @override
  void dispose() {
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _updatePasswordStrength() {
    final password = _newPasswordController.text;
    int strength = 0;
    if (password.length >= 8) strength++;
    if (RegExp(r'[A-Z]').hasMatch(password)) strength++;
    if (RegExp(r'[a-z]').hasMatch(password)) strength++;
    if (RegExp(r'\d').hasMatch(password)) strength++;
    if (RegExp(r'[@$!%*?&]').hasMatch(password)) strength++;
    // Max 4 (her biri bir kriter)
    if (strength <= 1) {
      _passwordStrengthText = 'Very Weak';
      _passwordStrengthColor = Colors.red;
    } else if (strength == 2) {
      _passwordStrengthText = 'Weak';
      _passwordStrengthColor = Colors.orange;
    } else if (strength == 3) {
      _passwordStrengthText = 'Medium';
      _passwordStrengthColor = Colors.amber;
    } else if (strength == 4) {
      _passwordStrengthText = 'Strong';
      _passwordStrengthColor = Colors.lightGreen;
    } else if (strength >= 5) {
      _passwordStrengthText = 'Very Strong';
      _passwordStrengthColor = Colors.green;
    }
    setState(() {
      _passwordStrength = strength;
    });
  }

  void _checkPasswordMatch() {
    final newPass = _newPasswordController.text;
    final confirm = _confirmPasswordController.text;
    if (confirm.isEmpty) {
      setState(() {
        _confirmPasswordMessage = '';
      });
      return;
    }
    if (newPass == confirm) {
      setState(() {
        _confirmPasswordMessage = 'Passwords match!';
        _confirmPasswordColor = Colors.green;
      });
    } else {
      setState(() {
        _confirmPasswordMessage = 'Passwords do not match';
        _confirmPasswordColor = Colors.red;
      });
    }
  }

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
      setState(() {
        _errorMessage =
        'Password must be at least 8 chars, include upper & lower case letters, a number and a special character.';
      });
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
      context.go('/login');
    } else {
      setState(() => _errorMessage = 'Password reset failed. Please try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.deepPurple),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Set New Password',
          style: TextStyle(color: Colors.deepPurple),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.home),
            tooltip: 'Back to Login',
            onPressed: () {
              context.go('/login');
            },
          ),
        ],
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
              child: Card(
                elevation: 3,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
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
                      // Şifre kriterleri kontrolü
                      if (_newPasswordController.text.isNotEmpty) ...[
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _PasswordCriteriaRow(
                              met: _newPasswordController.text.length >= 8,
                              text: 'At least 8 characters',
                            ),
                            _PasswordCriteriaRow(
                              met: RegExp(r'[A-Z]').hasMatch(_newPasswordController.text),
                              text: 'Uppercase letter (A-Z)',
                            ),
                            _PasswordCriteriaRow(
                              met: RegExp(r'[a-z]').hasMatch(_newPasswordController.text),
                              text: 'Lowercase letter (a-z)',
                            ),
                            _PasswordCriteriaRow(
                              met: RegExp(r'\d').hasMatch(_newPasswordController.text),
                              text: 'Number (0-9)',
                            ),
                            _PasswordCriteriaRow(
                              met: RegExp(r'[@$!%*?&]').hasMatch(_newPasswordController.text),
                              text: 'Special character (@, !, %, etc.)',
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _passwordStrengthText,
                          style: TextStyle(
                            color: _passwordStrengthColor,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 2),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final barWidth = constraints.maxWidth * (_passwordStrength / 5);
                            return Container(
                              height: 8,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: Colors.red.shade100,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Stack(
                                children: [
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 400),
                                    curve: Curves.easeInOut,
                                    width: barWidth,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: _passwordStrengthColor,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 10),
                      ],
                      TextField(
                        controller: _newPasswordController,
                        obscureText: !_passwordVisible,
                        decoration: InputDecoration(
                          labelText: 'New Password',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                          prefixIcon: const Icon(Icons.lock_outline),
                          filled: true,
                          fillColor: Colors.grey[100],
                          suffixIcon: IconButton(
                            icon: Icon(_passwordVisible ? Icons.visibility : Icons.visibility_off),
                            onPressed: () => setState(() => _passwordVisible = !_passwordVisible),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _confirmPasswordController,
                        obscureText: !_passwordVisible,
                        decoration: InputDecoration(
                          labelText: 'Confirm Password',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                          prefixIcon: const Icon(Icons.lock_reset),
                          filled: true,
                          fillColor: Colors.grey[100],
                        ),
                      ),
                      if (_confirmPasswordController.text.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          _confirmPasswordMessage,
                          style: TextStyle(
                            color: _confirmPasswordColor,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _resetPassword,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.deepPurple,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Text('Change Password'),
                        ),
                      ),
                    ],
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

class _PasswordCriteriaRow extends StatelessWidget {
  final bool met;
  final String text;
  const _PasswordCriteriaRow({required this.met, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2.0),
      child: Row(
        children: [
          Icon(
            met ? Icons.check_circle : Icons.radio_button_unchecked,
            color: met ? Colors.green : Colors.grey,
            size: 18,
          ),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              color: met ? Colors.green : Colors.grey,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
