// lib/screens/auth/register_screen.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:go_router/go_router.dart';

class RegisterScreen extends StatefulWidget {
  final String username;
  final String firstName;
  final String? lastName;
  final String country;
  final String province;
  final String city;
  final String gender;

  const RegisterScreen({
    super.key,
    required this.username,
    required this.firstName,
    this.lastName,
    required this.country,
    required this.province,
    required this.city,
    required this.gender,
  });

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordFocusNode = FocusNode();
  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _passwordController.addListener(() {
      setState(() {
        // Bu, şifre alanı her değiştiğinde UI'ın yeniden çizilmesini sağlar,
        // böylece kriter listesi anlık olarak güncellenir.
      });
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  bool _isPasswordValid(String password) {
    // Şifre sıfırlama ekranındakiyle aynı kriterler
    final regex = RegExp(
      r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&])[A-Za-z\d@$!%*?&]{8,}$',
    );
    return regex.hasMatch(password);
  }

  Future<void> _registerWithEmail() async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please fill in all fields.',
            style: TextStyle(color: Colors.white),
          ),
        ),
      );
      setState(() => _isLoading = false);
      return;
    }

    if (!_isPasswordValid(password)) {
      setState(() {
        _errorMessage =
        'Password must meet all the criteria.';
        _isLoading = false;
      });
      return;
    }

    // Check if email is already in use
    final methods = await FirebaseAuth.instance.fetchSignInMethodsForEmail(email);
    bool existsInAuth = methods.contains('password') || methods.contains('google.com');
    final firestoreQuery = await FirebaseFirestore.instance
        .collection('users')
        .where('email', isEqualTo: email)
        .limit(1)
        .get();
    bool existsInFirestore = firestoreQuery.docs.isNotEmpty;
    if (existsInAuth || existsInFirestore) {
      setState(() {
        _errorMessage = 'This email is already in use.';
        _isLoading = false;
      });
      return;
    }

    // Check if username is already taken
    final usernameDoc = await FirebaseFirestore.instance
        .collection('usernames')
        .doc(widget.username)
        .get();
    if (usernameDoc.exists) {
      setState(() {
        _errorMessage = 'This username is already taken.';
        _isLoading = false;
      });
      return;
    }

    // Kullanıcıyı database'e kaydetme! Sadece OTP ekranına yönlendir.
    if (!mounted) return;
    context.go('/verifyRegistrationOtp', extra: {
      'email': email,
      'password': password,
      'username': widget.username,
      'firstName': widget.firstName,
      'lastName': widget.lastName,
      'country': widget.country,
      'province': widget.province,
      'city': widget.city,
      'gender': widget.gender,
    });
    setState(() => _isLoading = false);
  }

  Future<void> _registerWithGoogle() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    try {
      final googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        setState(() => _isLoading = false);
        return;
      }

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
      final user = userCredential.user!;

      // Check if email is already in use
      final methods = await FirebaseAuth.instance.fetchSignInMethodsForEmail(user.email!);
      bool existsInAuth = methods.contains('password') || methods.contains('google.com');
      final firestoreQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: user.email)
          .limit(1)
          .get();
      bool existsInFirestore = firestoreQuery.docs.isNotEmpty;
      if (existsInAuth || existsInFirestore) {
        setState(() {
          _errorMessage = 'This email is already in use.';
          _isLoading = false;
        });
        await FirebaseAuth.instance.signOut();
        return;
      }

      // Create user document in Firestore
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'username': widget.username,
        'firstName': widget.firstName,
        'lastName': widget.lastName,
        'email': user.email,
        'country': widget.country,
        'province': widget.province,
        'city': widget.city,
        'gender': widget.gender,
        'createdAt': FieldValue.serverTimestamp(),
        'completedOnboarding': false,
        'badgeShown': false,
        'role': 'user', // Default role
      });

      // Reserve username
      await FirebaseFirestore.instance
          .collection('usernames')
          .doc(widget.username)
          .set({'email': user.email});

      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/onboarding');
    } catch (e) {
      setState(() {
        _errorMessage = 'Google sign in failed. Try again.';
      });
    } finally {
      setState(() => _isLoading = false);
    }
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
          onPressed: () => Navigator.pop(context),
          tooltip: 'Back',
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.only(left: 20.0, right: 20.0, top: 24.0, bottom: 0.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Text(
                'MentorBridge',
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                  color: Colors.deepPurple.shade700,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 2),
              const Text(
                'Create your account',
                style: TextStyle(
                  fontSize: 20,
                  color: Colors.black54,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 10),
              Card(
                elevation: 6,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
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
                      TextField(
                        controller: _emailController,
                        textInputAction: TextInputAction.next,
                        onSubmitted: (_) {
                          FocusScope.of(context).requestFocus(_passwordFocusNode);
                        },
                        decoration: InputDecoration(
                          labelText: 'Email',
                          prefixIcon: const Icon(Icons.email_outlined),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          filled: true,
                          fillColor: Colors.grey[100],
                        ),
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _passwordController,
                        focusNode: _passwordFocusNode,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _registerWithEmail(),
                        obscureText: _obscurePassword,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          prefixIcon: const Icon(Icons.lock_outline),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          filled: true,
                          fillColor: Colors.grey[100],
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                          ),
                        ),
                      ),
                      if (_passwordController.text.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        _PasswordCriteriaRow(
                          met: _passwordController.text.length >= 8,
                          text: 'At least 8 characters',
                        ),
                        _PasswordCriteriaRow(
                          met: RegExp(r'[A-Z]').hasMatch(_passwordController.text),
                          text: 'Uppercase letter (A-Z)',
                        ),
                        _PasswordCriteriaRow(
                          met: RegExp(r'[a-z]').hasMatch(_passwordController.text),
                          text: 'Lowercase letter (a-z)',
                        ),
                        _PasswordCriteriaRow(
                          met: RegExp(r'\d').hasMatch(_passwordController.text),
                          text: 'Number (0-9)',
                        ),
                        _PasswordCriteriaRow(
                          met: RegExp(r'[@$!%*?&]')
                              .hasMatch(_passwordController.text),
                          text: 'Special character (@, !, %, etc.)',
                        ),
                      ],
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _registerWithEmail,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.deepPurple,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          child: _isLoading
                              ? const CircularProgressIndicator(color: Colors.white)
                              : const Text('Sign up', style: TextStyle(color: Colors.white)),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Or',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.black54,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton.icon(
                          onPressed: _isLoading ? null : _registerWithGoogle,
                          icon: Image.asset(
                            'assets/google_logo.png',
                            height: 24,
                          ),
                          label: const Text(
                            'Sign up with Google',
                            style: TextStyle(
                              color: Colors.black87,
                              fontSize: 16,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: const BorderSide(color: Colors.grey),
                            ),
                          ),
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

class _PasswordCriteriaRow extends StatelessWidget {
  final bool met;
  final String text;
  const _PasswordCriteriaRow({required this.met, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: Row(
        children: [
          Icon(
            met ? Icons.check_circle : Icons.radio_button_unchecked,
            color: met ? Colors.green : Colors.grey,
            size: 20,
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              color: met ? Colors.green : Colors.black54,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
