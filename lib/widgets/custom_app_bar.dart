import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final bool showSignUpButton;
  final bool showContinueButton;
  final bool showLoginButton; // Log In butonu için yeni parametre
  final bool automaticallyImplyLeading; // Back button visibility kontrolü
  final VoidCallback? onContinuePressed;

  const CustomAppBar({
    super.key,
    this.title = 'MentorBridge',
    this.showSignUpButton = false,
    this.showContinueButton = false,
    this.showLoginButton = false, // Varsayılan olarak false
    this.automaticallyImplyLeading = true, // Varsayılan olarak true
    this.onContinuePressed,
  });

  @override
  Size get preferredSize => const Size.fromHeight(60);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: const Color(0xFF000000),
      elevation: 0,
      toolbarHeight: 50,
      centerTitle: true,
      title: Stack(
        alignment: Alignment.center,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              foreground: Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = 2
                ..color = Colors.black,
            ),
          ),
          const Text(
            'MentorBridge',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
      bottom: const PreferredSize(
        preferredSize: Size.fromHeight(10),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF000000), Colors.white],
            ),
          ),
          child: SizedBox(height: 10),
        ),
      ),
      automaticallyImplyLeading: automaticallyImplyLeading, // Geri tuşunu kontrol eder
      leading: automaticallyImplyLeading
          ? IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      )
          : null,
      actions: [
        if (showSignUpButton)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                backgroundColor: Colors.white,
                side: const BorderSide(color: Colors.white),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              onPressed: () => context.push('/username'),
              child: const Text(
                'Sign Up',
                style: TextStyle(color: Colors.black, fontSize: 14),
              ),
            ),
          ),
        if (showContinueButton)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                backgroundColor: Colors.white,
                side: const BorderSide(color: Colors.white),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              onPressed: onContinuePressed,
              child: const Text(
                'Continue',
                style: TextStyle(color: Colors.black, fontSize: 14),
              ),
            ),
          ),
        if (showLoginButton)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                backgroundColor: Colors.white,
                side: const BorderSide(color: Colors.white),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              onPressed: () => context.push('/login'),
              child: const Text(
                'Log In',
                style: TextStyle(color: Colors.black, fontSize: 14),
              ),
            ),
          ),
      ],
    );
  }
}