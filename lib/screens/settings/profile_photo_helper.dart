import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:firebase_storage/firebase_storage.dart';

class ProfilePhotoHelper {
  static final ImagePicker _picker = ImagePicker();

  /// Fotoğraf seç, kırp ve File döndür. Kırpma iptal edilirse null döner.
  static Future<File?> pickAndCropPhoto(BuildContext context) async {
    try {
      // Image picker için options belirle
      final pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1080,
        maxHeight: 1080,
        imageQuality: 85,
      );
      
      if (pickedFile == null) {
        print('ProfilePhotoHelper: No image selected');
        return null;
      }

      print('ProfilePhotoHelper: Image picked successfully from ${pickedFile.path}');

      // İlk olarak orijinal fotoğrafı File olarak hazırla (fallback için)
      final originalFile = File(pickedFile.path);

      // Image cropper için platform specific ayarlar - try-catch ile wrap
      try {
        final croppedFile = await ImageCropper().cropImage(
          sourcePath: pickedFile.path,
          compressFormat: ImageCompressFormat.jpg,
          compressQuality: 85,
          maxWidth: 512,
          maxHeight: 512,
          uiSettings: [
            AndroidUiSettings(
              toolbarTitle: 'Crop Photo',
              toolbarColor: Colors.deepPurple,
              toolbarWidgetColor: Colors.white,
              statusBarColor: Colors.deepPurple,
              activeControlsWidgetColor: Colors.deepPurple,
              hideBottomControls: false,
              lockAspectRatio: true,
              cropStyle: CropStyle.circle,
              aspectRatioPresets: [CropAspectRatioPreset.square],
              initAspectRatio: CropAspectRatioPreset.square,
              showCropGrid: false,
              cropFrameColor: Colors.deepPurple,
              cropGridColor: Colors.white,
              dimmedLayerColor: Colors.black54,
            ),
            IOSUiSettings(
              title: 'Crop Photo',
              aspectRatioLockEnabled: true,
              cropStyle: CropStyle.circle,
              aspectRatioPickerButtonHidden: true,
            ),
            WebUiSettings(
              context: context,
            ),
          ],
        );
        
        if (croppedFile != null) {
          print('ProfilePhotoHelper: Image cropped successfully');
          return File(croppedFile.path);
        } else {
          print('ProfilePhotoHelper: Cropping cancelled by user');
          return null;
        }
        
      } catch (cropError) {
        print('ProfilePhotoHelper: Crop error: $cropError');
        
        // Crop hatası durumunda kullanıcıya bilgi ver ve orijinal fotoğrafı kullan
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Image cropping failed. Using original image.'),
              duration: Duration(seconds: 2),
            ),
          );
        }
        
        // Orijinal fotoğrafı döndür
        print('ProfilePhotoHelper: Using original image as fallback');
        return originalFile;
      }
      
    } catch (e) {
      print('ProfilePhotoHelper: General error: $e');
      if (context.mounted) {
        String errorMessage = 'An error occurred while selecting photo.';
        if (e.toString().contains('permission')) {
          errorMessage = 'Please grant photo access permission from settings.';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage)),
        );
      }
      return null;
    }
  }

  /// Kırpılmış fotoğrafı Firebase Storage'a yükle ve download url döndür.
  static Future<String?> uploadProfilePhoto(File file, String uid) async {
    try {
      print('ProfilePhotoHelper: Starting upload for user $uid');
      
      // Dosya boyutunu kontrol et
      final fileSize = await file.length();
      print('ProfilePhotoHelper: File size: ${fileSize / 1024 / 1024} MB');
      
      if (fileSize > 5 * 1024 * 1024) { // 5MB limit
        print('ProfilePhotoHelper: File too large');
        return null;
      }

      final storageRef = FirebaseStorage.instance
          .ref()
          .child('profile_photos')
          .child('$uid.jpg');
      
      final uploadTask = storageRef.putFile(
        file,
        SettableMetadata(
          contentType: 'image/jpeg',
          customMetadata: {'uploaded_by': uid},
        ),
      );
      
      // Upload progress'i takip et (opsiyonel)
      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        final progress = (snapshot.bytesTransferred / snapshot.totalBytes) * 100;
        print('ProfilePhotoHelper: Upload progress: ${progress.toStringAsFixed(1)}%');
      });
      
      final snapshot = await uploadTask;
      final url = await snapshot.ref.getDownloadURL();
      
      print('ProfilePhotoHelper: Upload completed successfully');
      return url;
      
    } catch (e) {
      print('ProfilePhotoHelper: Upload error: $e');
      return null;
    }
  }

  /// Eski profil fotoğrafını Firebase Storage'dan sil
  static Future<bool> deleteOldProfilePhoto(String? photoUrl) async {
    if (photoUrl == null || photoUrl.isEmpty) {
      return true; // Silinecek foto yok, başarılı sayıyoruz
    }

    try {
      // Firebase Storage URL'inden reference al
      final ref = FirebaseStorage.instance.refFromURL(photoUrl);
      await ref.delete();
      
      return true;
      
    } catch (e) {
      // Dosya zaten silinmişse veya bulunamıyorsa hata vermeyerek devam et
      if (e.toString().contains('object-not-found') || 
          e.toString().contains('not-found')) {
        return true;
      }
      return false;
    }
  }

  /// Avatar picker: Kullanıcıya avatar seçtirir ve seçilen avatarın asset path'ini döndürür.
  static Future<String?> pickAvatar(BuildContext context) async {
    // 🔹 Sadece mevcut avatar dosyalarını listele (pubspec.yaml'da 5 avatar var)
    final avatars = List.generate(5, (i) => 'assets/avatars/avatar${i + 1}.png');
    return await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Choose Avatar',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                children: avatars.map((path) => GestureDetector(
                  onTap: () {
                    Navigator.pop(context, path);
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: CircleAvatar(
                      radius: 40,
                      backgroundImage: AssetImage(path),
                    ),
                  ),
                )).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }
} 