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
      final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
      if (pickedFile == null) return null;

      CroppedFile? croppedFile = await ImageCropper().cropImage(
        sourcePath: pickedFile.path,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: '',
            toolbarColor: Colors.white,
            toolbarWidgetColor: Colors.black,
            hideBottomControls: true,
            lockAspectRatio: true,
            cropStyle: CropStyle.circle,
            aspectRatioPresets: [CropAspectRatioPreset.square],
            initAspectRatio: CropAspectRatioPreset.square,
          ),
          IOSUiSettings(
            title: '',
            aspectRatioLockEnabled: true,
            cropStyle: CropStyle.circle,
            aspectRatioPickerButtonHidden: true,
          ),
          WebUiSettings(
            context: context,
          ),
        ],
      );
      if (croppedFile == null) return null;
      return File(croppedFile.path);
    } catch (e) {
      // Eğer izin hatası ise kullanıcıya rehberlik et
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please grant photo access permission from settings.')),
      );
      return null;
    }
  }

  /// Kırpılmış fotoğrafı Firebase Storage'a yükle ve download url döndür.
  static Future<String?> uploadProfilePhoto(File file, String uid) async {
    try {
      final storageRef = FirebaseStorage.instance.ref().child('profile_photos/$uid.jpg');
      await storageRef.putFile(file);
      final url = await storageRef.getDownloadURL();
      return url;
    } catch (e) {
      return null;
    }
  }

  /// Avatar picker: Kullanıcıya avatar seçtirir ve seçilen avatarın asset path'ini döndürür.
  static Future<String?> pickAvatar(BuildContext context) async {
    final avatars = List.generate(30, (i) => 'assets/avatars/avatar${i + 1}.png');
    return await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          padding: const EdgeInsets.all(16),
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
      ),
    );
  }
} 