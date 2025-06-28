// lib/services/auth_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;

class AuthService {
  // 1) Registration OTP endpoint’leri:
  //    Bunları Cloud Functions → sendRegistrationOtp/verifyRegistrationOtp trigger URL'lerinden kopyalayın.
  static const _sendRegistrationOtpUrl    =
      'https://sendregistrationotp-f4wn5fkbva-uc.a.run.app';
  static const _verifyRegistrationOtpUrl  =
      'https://verifyregistrationotp-f4wn5fkbva-uc.a.run.app';

  // 2) Password Reset OTP endpoint’leri:
  //    Bunları Cloud Functions → sendPasswordResetOtp/verifyPasswordResetOtp/ resetPasswordWithOtp trigger URL'lerinden kopyalayın.
  static const _sendPasswordResetOtpUrl    =
      'https://sendpasswordresetotp-f4wn5fkbva-uc.a.run.app';
  static const _verifyPasswordResetOtpUrl  =
      'https://verifypasswordresetotp-f4wn5fkbva-uc.a.run.app';
  static const _resetPasswordWithOtpUrl    =
      'https://resetpasswordwithotp-f4wn5fkbva-uc.a.run.app';


  // ────────────────────────────────────────────────────────────
  // 1) Kayıt (Registration) için OTP gönder:
  //    Parametre: email
  //    Dönen:  HTTP 200 ve { success: true } ise başarılı.
  // ────────────────────────────────────────────────────────────
  static Future<bool> sendRegistrationOtp(String email) async {
    final uri = Uri.parse(_sendRegistrationOtpUrl);
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email}),
    );
    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      return (body['success'] == true);
    }
    return false;
  }

  // ────────────────────────────────────────────────────────────
  // 2) Kayıt (Registration) için OTP doğrulama:
  //    Parametre: email, otp
  //    Dönen: { valid: true } ise geçerli.
  // ────────────────────────────────────────────────────────────
  static Future<bool> verifyRegistrationOtp(String email, String otp) async {
    final uri = Uri.parse(_verifyRegistrationOtpUrl);
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'otp': otp}),
    );
    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      return (body['valid'] == true);
    }
    return false;
  }

  // ────────────────────────────────────────────────────────────
  // 3) Şifre Sıfırlama (Password Reset) için OTP gönder:
  //    Parametre: email
  //    Dönen:  HTTP 200 ve { success: true } ise başarılı.
  // ────────────────────────────────────────────────────────────
  static Future<bool> sendPasswordResetOtp(String email) async {
    final uri = Uri.parse(_sendPasswordResetOtpUrl);
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email}),
    );
    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      return (body['success'] == true);
    }
    return false;
  }

  // ────────────────────────────────────────────────────────────
  // 4) Şifre Sıfırlama (Password Reset) için OTP doğrulama:
  //    Parametre: email, otp
  //    Dönen: { valid: true } ise geçerli.
  // ────────────────────────────────────────────────────────────
  static Future<bool> verifyPasswordResetOtp(String email, String otp) async {
    final uri = Uri.parse(_verifyPasswordResetOtpUrl);
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'otp': otp}),
    );
    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      return (body['valid'] == true);
    }
    return false;
  }

  // ────────────────────────────────────────────────────────────
  // 5) OTP geçerliyse şifreyi güncelle:
  //    Parametre: email, otp, newPassword
  //    Dönen:  HTTP 200 ve { success: true } ise başarılı.
  // ────────────────────────────────────────────────────────────
  static Future<bool> resetPasswordWithOtp(
      String email,
      String otp,
      String newPassword,
      ) async {
    final uri = Uri.parse(_resetPasswordWithOtpUrl);
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'otp': otp,
        'newPassword': newPassword,
      }),
    );
    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      return (body['success'] == true);
    }
    return false;
  }
}
