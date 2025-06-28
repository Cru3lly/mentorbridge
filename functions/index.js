// index.js

const functions   = require('firebase-functions');
const admin       = require('firebase-admin');
const nodemailer  = require('nodemailer');
const cors        = require('cors')({ origin: true });

admin.initializeApp();
const db = admin.firestore();


// --------------------------------------------------------------------
// A) Kayıt (Registration) için OTP Gönderme
//
//    Endpoint: /sendRegistrationOtp
//    Request Body: { email: string }
//
//    İşleyiş:
//    1) 6 haneli bir kod (OTP) üretir.
//    2) Firestore’un 'registration_otps' koleksiyonuna,
//       belgenin ID’si olarak kullanıcının e-postasıyla { otp, expiresAt } kaydeder.
//    3) “MentorBridge – Registration Verification Code” başlıklı e-posta yollar.
// --------------------------------------------------------------------
exports.sendRegistrationOtp = functions.https.onRequest((req, res) => {
  return cors(req, res, async () => {
    try {
      const { email } = req.body;
      if (!email || typeof email !== 'string' || !email.includes('@')) {
        console.error('sendRegistrationOtp → Geçersiz e-posta:', email);
        return res.status(400).json({ success: false, error: 'Invalid email.' });
      }

      // 1) 6 haneli OTP üret:
      const otp = Math.floor(100000 + Math.random() * 900000).toString();
      const expiresAt = admin.firestore.Timestamp.fromDate(
        new Date(Date.now() + 15 * 60 * 1000) // 15 dakika geçerli
      );

      // 2) Firestore’a kaydet ('registration_otps' koleksiyonu)
      await db.collection('registration_otps').doc(email).set({
        otp,
        expiresAt
      });
      console.log('sendRegistrationOtp → Firestore kaydedildi, OTP:', otp);

      // 3) Nodemailer ayarları (Gmail + App Password)
      const transporter = nodemailer.createTransport({
        service: 'gmail',
        auth: {
          user: 'tahaaki34@gmail.com',
          pass: 'eidjiqmcioiccqoa'  // 16 haneli App Password
        }
      });

      // 4) E-posta içeriği (Registration Verification)
      const mailOptions = {
        from: 'tahaaki34@gmail.com',
        to: email,
        subject: 'MentorBridge – Registration Verification Code',
        html: `
          <p>Hello,</p>
          <p>You have requested to verify your email address for MentorBridge. Use the following code:</p>
          <h2 style="font-weight:bold; color:#000000;">${otp}</h2>
          <p>This code will expire in 15 minutes.</p>
          <p>Best regards,<br>MentorBridge Team</p>
        `
      };

      // 5) E-postayı gönder
      await transporter.sendMail(mailOptions);
      console.log('sendRegistrationOtp → E-posta gönderildi:', email);

      return res.json({ success: true });
    } catch (error) {
      console.error('sendRegistrationOtp → Hata:', error);
      return res.status(500).json({ success: false, error: 'Server error.' });
    }
  });
});


// --------------------------------------------------------------------
// B) Kayıt (Registration) için OTP Doğrulama
//
//    Endpoint: /verifyRegistrationOtp
//    Request Body: { email: string, otp: string }
//
//    İşleyiş:
//    1) Firestore’daki 'registration_otps/{email}' belgesini okur.
//    2) Eğer belge yoksa hata döner.
//    3) “expiresAt” geçme süresini kontrol eder; geçmişse belgeyi siler ve hata döner.
//    4) Kullanıcının girdiği OTP’yi saklanan ‘otp’ ile eşleştirir.
//    5) Eğer eşleşme doğruysa Firestore’daki belgeyi silebilir (opsiyonel) ve { valid: true } döner.
// --------------------------------------------------------------------
exports.verifyRegistrationOtp = functions.https.onRequest((req, res) => {
  return cors(req, res, async () => {
    try {
      const { email, otp } = req.body;
      if (!email || !otp) {
        return res.status(400).json({ valid: false, reason: 'Missing parameters.' });
      }

      // 1) Firestore’dan belgeyi al:
      const docRef = db.collection('registration_otps').doc(email);
      const doc = await docRef.get();
      if (!doc.exists) {
        return res.json({ valid: false, reason: 'Code not found.' });
      }
      const data = doc.data();
      if (!data) {
        return res.json({ valid: false, reason: 'Error reading code data.' });
      }

      const savedOtp  = data.otp;
      const expiresAt = data.expiresAt.toDate();

      // 2) Süre dolmuş mu?
      if (Date.now() > expiresAt.getTime()) {
        await docRef.delete();
        return res.json({ valid: false, reason: 'Code has expired.' });
      }

      // 3) Kullanıcının girdiği kod ile sakladığımız kod eşleşiyor mu?
      if (otp !== savedOtp) {
        return res.json({ valid: false, reason: 'Incorrect code.' });
      }

      // 4) Kod doğru → Firestore’dan belgeyi silebilirsiniz (isteğe bağlı):
      await docRef.delete();
      return res.json({ valid: true });
    } catch (error) {
      console.error('verifyRegistrationOtp → Hata:', error);
      return res.status(500).json({ valid: false, reason: 'Server error.' });
    }
  });
});


// --------------------------------------------------------------------
// C) Şifre Sıfırlama (Password Reset) için OTP Gönderme
//
//    Endpoint: /sendPasswordResetOtp
//    Request Body: { email: string }
//
//    İşleyiş:
//    1) 6 haneli bir kod üretir.
//    2) Firestore’un 'password_reset_otps' koleksiyonuna,
//       belgenin ID’si olarak e-postayla { otp, expiresAt } kaydeder.
//    3) “MentorBridge – Password Reset Code” başlıklı e-posta yollar.
// --------------------------------------------------------------------
exports.sendPasswordResetOtp = functions.https.onRequest((req, res) => {
  return cors(req, res, async () => {
    try {
      const { email } = req.body;
      if (!email || typeof email !== 'string' || !email.includes('@')) {
        console.error('sendPasswordResetOtp → Geçersiz e-posta:', email);
        return res.status(400).json({ success: false, error: 'Invalid email.' });
      }

      // 1) 6 haneli OTP üret:
      const otp = Math.floor(100000 + Math.random() * 900000).toString();
      const expiresAt = admin.firestore.Timestamp.fromDate(
        new Date(Date.now() + 15 * 60 * 1000) // 15 dakika geçerli
      );

      // 2) Firestore’a kaydet ('password_reset_otps' koleksiyonu)
      await db.collection('password_reset_otps').doc(email).set({
        otp,
        expiresAt
      });
      console.log('sendPasswordResetOtp → Firestore kaydedildi, OTP:', otp);

      // 3) Nodemailer ayarları (Gmail + App Password)
      const transporter = nodemailer.createTransport({
        service: 'gmail',
        auth: {
          user: 'tahaaki34@gmail.com',
          pass: 'eidjiqmcioiccqoa'
        }
      });

      // 4) E-posta içeriği (Password Reset)
      const mailOptions = {
        from: 'tahaaki34@gmail.com',
        to: email,
        subject: 'MentorBridge – Password Reset Code',
        html: `
          <p>Hello,</p>
          <p>You have requested to reset your password. Use the following code:</p>
          <h2 style="font-weight:bold; color:#000000;">${otp}</h2>
          <p>This code will expire in 15 minutes.</p>
          <p>Best regards,<br>MentorBridge Team</p>
        `
      };

      // 5) E-postayı gönder
      await transporter.sendMail(mailOptions);
      console.log('sendPasswordResetOtp → E-posta gönderildi:', email);

      return res.json({ success: true });
    } catch (error) {
      console.error('sendPasswordResetOtp → Hata:', error);
      return res.status(500).json({ success: false, error: 'Server error.' });
    }
  });
});


// --------------------------------------------------------------------
// D) Şifre Sıfırlama (Password Reset) için OTP Doğrulama
//
//    Endpoint: /verifyPasswordResetOtp
//    Request Body: { email: string, otp: string }
//
//    İşleyiş:
//    1) Firestore’daki 'password_reset_otps/{email}' belgesini okur.
//    2) Süre kontrolü ve kod eşleşmesi yapar.
//    3) Eğer doğruysa { valid:true } döner.
// --------------------------------------------------------------------
exports.verifyPasswordResetOtp = functions.https.onRequest((req, res) => {
  return cors(req, res, async () => {
    try {
      const { email, otp } = req.body;
      if (!email || !otp) {
        return res.status(400).json({ valid: false, reason: 'Missing parameters.' });
      }

      const docRef = db.collection('password_reset_otps').doc(email);
      const doc = await docRef.get();
      if (!doc.exists) {
        return res.json({ valid: false, reason: 'Code not found.' });
      }
      const data = doc.data();
      if (!data) {
        return res.json({ valid: false, reason: 'Error reading code data.' });
      }

      const savedOtp  = data.otp;
      const expiresAt = data.expiresAt.toDate();

      // 1) Süre dolmuş mu?
      if (Date.now() > expiresAt.getTime()) {
        await docRef.delete();
        return res.json({ valid: false, reason: 'Code has expired.' });
      }

      // 2) Kod eşleşiyor mu?
      if (otp !== savedOtp) {
        return res.json({ valid: false, reason: 'Incorrect code.' });
      }

      // 3) İsterseniz belgeden silebilirsiniz:
      // await docRef.delete();

      return res.json({ valid: true });
    } catch (error) {
      console.error('verifyPasswordResetOtp → Hata:', error);
      return res.status(500).json({ valid: false, reason: 'Server error.' });
    }
  });
});


// --------------------------------------------------------------------
// E) Şifre Sıfırlama (Password Reset) – Kod geçerliyse yeni şifreyi güncelle
//
//    Endpoint: /resetPasswordWithOtp
//    Request Body: { email: string, otp: string, newPassword: string }
//
//    İşleyiş:
//    1) Yukarıdaki ‘password_reset_otps/{email}’ belgesini tekrar kontrol eder.
//    2) Süre ve kod eşleşmesi doğruysa, Firebase Auth üzerindeki
//       kullanıcıyı `getUserByEmail(email)` ile bulur ve `updateUser(uid,{password})` çağırır.
//    3) Firestore’daki belgeyi siler (isteğe bağlı).
// --------------------------------------------------------------------
exports.resetPasswordWithOtp = functions.https.onRequest((req, res) => {
  return cors(req, res, async () => {
    try {
      const { email, otp, newPassword } = req.body;
      if (!email || !otp || !newPassword) {
        return res.status(400).json({ success: false, reason: 'Missing parameters.' });
      }

      // 1) Firestore’dan belgeyi al:
      const docRef = db.collection('password_reset_otps').doc(email);
      const doc = await docRef.get();
      if (!doc.exists) {
        return res.json({ success: false, reason: 'Code not found.' });
      }
      const data = doc.data();
      if (!data) {
        return res.json({ success: false, reason: 'Error reading code data.' });
      }

      const savedOtp  = data.otp;
      const expiresAt = data.expiresAt.toDate();

      // 2) Süre dolmuş mu?
      if (Date.now() > expiresAt.getTime()) {
        return res.json({ success: false, reason: 'Code has expired.' });
      }
      // 3) Kod eşleşiyor mu?
      if (otp !== savedOtp) {
        return res.json({ success: false, reason: 'Incorrect code.' });
      }

      // 4) Kod geçerli → Firebase Auth şifresini güncelle:
      const userRecord = await admin.auth().getUserByEmail(email);
      const uid = userRecord.uid;
      await admin.auth().updateUser(uid, { password: newPassword });

      // 5) Firestore’daki belgeyi silebilirsiniz (opsiyonel):
      await docRef.delete();

      return res.json({ success: true });
    } catch (error) {
      console.error('resetPasswordWithOtp → Hata:', error);
      return res.status(500).json({ success: false, reason: 'Server error.' });
    }
  });
});
