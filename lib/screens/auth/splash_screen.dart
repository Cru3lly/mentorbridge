import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // 3 saniye bekle (logo+loading gösterilsin), sonra _navigate() çalışsın
    Timer(const Duration(seconds: 3), _navigate);
  }

  Future<void> _navigate() async {
    // 2) FirebaseAuth ile oturum kontrolü
    final user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      // Kullanıcı daha önce login olmuş, şimdi Firestore'dan "role" bilgisini çek:
      try {
        final uid = user.uid;
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .get();

        if (userDoc.exists) {
          final data = userDoc.data()!;
          final role = data['role'] as String? ?? '';
          final badgeShown = data['badgeShown'] as bool? ?? false;

          // Eğer roldeyse ve badge henüz gösterilmediyse öncelikle badge ekranını göster:
          if (!badgeShown && role.isNotEmpty) {
            context.go('/roleBadge', extra: role);
            return;
          }

          // Badge gösterildiyse veya gerek yoksa, AuthGate'e yönlendir
          context.go('/authGate');
        } else {
          // Kullanıcı dokümanı yoksa → direkt login'e gönder (veri kaydı silinmiş olabilir)
          context.go('/login');
        }
      } catch (e) {
        // Bir hata olduysa (internet yok, Firestore hatası vs.) login'e gönder:
        context.go('/login');
      }
    } else {
      // user == null → kullanıcı hiç login olmamış → Login ekranına git
      context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // veya istemiş olduğunuz renk
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo
            Image.asset(
              'assets/logo.png',
              width: 240,
              height: 240,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) {
                return const Text('Logo could not be loaded.');
              },
            ),
            const SizedBox(height: 0),

            // Dönen yükleniyor göstergesi
            const CircularProgressIndicator(color: Color(0xFF6200EE)),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
