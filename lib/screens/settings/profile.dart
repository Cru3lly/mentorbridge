import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'profile_photo_helper.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';

class Profile extends StatefulWidget {
  const Profile({super.key});

  @override
  State<Profile> createState() => _ProfileState();
}

class _ProfileState extends State<Profile> {
  final _usernameController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  String? _country;
  String? _selectedProvince;
  String? _selectedCity;
  String? _uid;
  bool _loading = true;
  bool _isEditMode = false;
  bool _isSaving = false;

  String? _photoUrl;
  String? _avatarEmoji;

  String? _email;
  String? _role;
  DateTime? _createdAt;

  // Değişiklik algılama için orijinal değerleri sakla
  String? _originalUsername;
  String? _originalFirstName;
  String? _originalLastName;
  String? _originalCountry;
  String? _originalProvince;
  String? _originalCity;
  String? _gender;
  String? _originalGender;
  
  // User data cache for member ID access
  Map<String, dynamic> _userData = {};
  final List<String> _genders = ['Male', 'Female', 'Prefer not to answer'];

  // 🔹 Pending photo/avatar changes
  File? _pendingPhotoFile;
  String? _pendingAvatar;
  bool _hasPendingPhotoChanges = false;

  final Map<String, List<String>> _provinceCityMap = {
    'Ontario': ['Toronto', 'Ottawa', 'Mississauga', 'Hamilton', 'London'],
    'British Columbia': ['Vancouver', 'Victoria', 'Surrey', 'Kelowna'],
    'Alberta': ['Calgary', 'Edmonton', 'Red Deer'],
    'Quebec': ['Montreal', 'Quebec City', 'Laval'],
  };

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    _uid = user.uid;
    final doc = await FirebaseFirestore.instance.collection('users').doc(_uid).get();

    if (doc.exists) {
      final data = doc.data()!;
      _userData = data; // Cache user data for member ID access
      _usernameController.text = data['username'] ?? '';
      _firstNameController.text = data['firstName'] ?? '';
      _lastNameController.text = data['lastName'] ?? '';
      _photoUrl = data['photoUrl'];
      _avatarEmoji = data['avatarEmoji'];
      _country = data['country'] ?? '';
      _selectedProvince = data['province'];
      _selectedCity = data['city'];
      _email = data['email'] ?? user.email;
      _role = data['role'] ?? 'user';
      _createdAt = data['createdAt']?.toDate();
      _gender = data['gender'];
      // Orijinal değerleri sakla
      _originalUsername = _usernameController.text;
      _originalFirstName = _firstNameController.text;
      _originalLastName = _lastNameController.text;
      _originalCountry = _country;
      _originalProvince = _selectedProvince;
      _originalCity = _selectedCity;
      _originalGender = _gender;
    }
    setState(() => _loading = false);
  }

  Future<void> _handleProfilePhotoChange() async {
    try {
      final croppedFile = await ProfilePhotoHelper.pickAndCropPhoto(context);
      if (croppedFile == null) {
        print('Profile: No file selected or cropping cancelled');
        return;
      }

      print('Profile: Photo selected, setting as pending...');
      
      if (mounted) {
        setState(() {
          _pendingPhotoFile = croppedFile;
          _pendingAvatar = null; // Clear pending avatar if photo is selected
          _hasPendingPhotoChanges = true;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('📷 Photo selected! Click Save to upload.'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      print('Profile: Error in _handleProfilePhotoChange: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ An error occurred: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  Future<void> _handleAvatarPick() async {
    final selected = await ProfilePhotoHelper.pickAvatar(context);
    if (selected != null) {
      print('Profile: Avatar selected, setting as pending...');
      
      if (mounted) {
        setState(() {
          _pendingAvatar = selected;
          _pendingPhotoFile = null; // Clear pending photo if avatar is selected
          _hasPendingPhotoChanges = true;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('👤 Avatar selected! Click Save to apply.'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<bool> _isUsernameUnique(String username) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;
    final query = await FirebaseFirestore.instance
        .collection('users')
        .where('username', isEqualTo: username)
        .get();
    // Eğer query'de sadece kendi kaydı varsa unique sayılır
    if (query.docs.isEmpty) return true;
    if (query.docs.length == 1 && query.docs.first.id == user.uid) return true;
    return false;
  }

  Future<void> _saveProfileChanges() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    setState(() => _isSaving = true);
    try {
      if (_gender == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select your gender.')),
        );
        return;
      }
      if (_usernameController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Username is required.')),
        );
        return;
      }
      if (_firstNameController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('First name is required.')),
        );
        return;
      }
      if (_lastNameController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Last name is required.')),
        );
        return;
      }
      if (_country == null || _country!.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Country is required.')),
        );
        return;
      }
      if (_selectedProvince == null || _selectedProvince!.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Province is required.')),
        );
        return;
      }
      if (_selectedCity == null || _selectedCity!.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('City is required.')),
        );
        return;
      }
      final isUnique = await _isUsernameUnique(_usernameController.text.trim());
      if (!isUnique) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('This username is already taken.')),
        );
        return;
      }
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null || currentUser.uid != uid) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unauthorized update attempt.')),
        );
        return;
      }

      // 🔹 Handle pending photo/avatar upload
      String? newPhotoUrl = _photoUrl;
      String? newAvatarEmoji = _avatarEmoji;
      
      if (_hasPendingPhotoChanges) {
        if (_pendingPhotoFile != null) {
          print('Profile: Uploading pending photo...');
          
          // 🔹 Yeni foto upload etmeden önce eski fotoğrafı sil
          if (_photoUrl != null && _photoUrl!.isNotEmpty) {
            await ProfilePhotoHelper.deleteOldProfilePhoto(_photoUrl);
          }
          
          newPhotoUrl = await ProfilePhotoHelper.uploadProfilePhoto(_pendingPhotoFile!, uid);
          if (newPhotoUrl != null) {
            newAvatarEmoji = null; // Clear avatar if photo uploaded
            print('Profile: Photo uploaded successfully');
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('❌ Photo upload failed. Please try again.')),
            );
            return;
          }
        } else if (_pendingAvatar != null) {
          print('Profile: Setting pending avatar...');
          
          // 🔹 Avatar seçilmişse eski fotoğrafı sil
          if (_photoUrl != null && _photoUrl!.isNotEmpty) {
            // Arka planda sil, hata olsa bile devam et
            ProfilePhotoHelper.deleteOldProfilePhoto(_photoUrl);
          }
          
          newAvatarEmoji = _pendingAvatar;
          newPhotoUrl = null; // Clear photo if avatar selected
        }
      }

      String lastNameToSave = _lastNameController.text.trim();
      final oldUsername = _originalUsername;
      final newUsername = _usernameController.text.trim();
      final email = _email;
      if (oldUsername != null && oldUsername != newUsername) {
        try {
          await FirebaseFirestore.instance.collection('usernames').doc(oldUsername).delete();
        } catch (e) {
          debugPrint('Failed to delete old username: $e');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Warning: Old username could not be deleted.')),
          );
        }
        await FirebaseFirestore.instance.collection('usernames').doc(newUsername).set({'email': email});
      }

      // 🔹 Update Firestore with all changes including photo/avatar
      final updateData = {
        'username': newUsername,
        'firstName': _firstNameController.text.trim(),
        'lastName': lastNameToSave,
        'country': _country,
        'province': _selectedProvince,
        'city': _selectedCity,
        'gender': _gender,
      };

      // Add photo/avatar updates if there were changes
      if (_hasPendingPhotoChanges) {
        updateData['photoUrl'] = newPhotoUrl;
        updateData['avatarEmoji'] = newAvatarEmoji;
      }

      await FirebaseFirestore.instance.collection('users').doc(uid).update(updateData);
      
      setState(() {
        _isEditMode = false;
        _originalUsername = newUsername;
        // 🔹 Update local state and clear pending changes
        if (_hasPendingPhotoChanges) {
          _photoUrl = newPhotoUrl;
          _avatarEmoji = newAvatarEmoji;
          _pendingPhotoFile = null;
          _pendingAvatar = null;
          _hasPendingPhotoChanges = false;
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Profile updated successfully!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('An error occurred. Please try again.')),
      );
    } finally {
      setState(() => _isSaving = false);
    }
  }

  bool get _hasUnsavedChanges {
    return _usernameController.text != (_originalUsername ?? '') ||
        _firstNameController.text != (_originalFirstName ?? '') ||
        _lastNameController.text != (_originalLastName ?? '') ||
        _country != _originalCountry ||
        _selectedProvince != _originalProvince ||
        _selectedCity != _originalCity ||
        _gender != _originalGender ||
        _hasPendingPhotoChanges;
  }

  Future<void> _onEditCancel() async {
    if (_hasUnsavedChanges) {
      final discard = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Discard changes?'),
          content: const Text('Are you sure you want to discard changes?'),
          actions: [
            TextButton(
              onPressed: () => context.pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => context.pop(true),
              child: const Text('Discard'),
            ),
          ],
        ),
      );
      if (discard != true) return;
    }
    setState(() {
      _isEditMode = false;
      // 🔹 Clear pending photo/avatar changes
      _pendingPhotoFile = null;
      _pendingAvatar = null;
      _hasPendingPhotoChanges = false;
      _loadUserData();
    });
  }

  // 🗑️ Storage'dan kullanıcıya ait tüm dosyaları sil
  Future<void> _deleteAllUserStorageFiles(String userId, Map<String, dynamic>? userData) async {
    try {
      final storage = FirebaseStorage.instance;
      int deletedCount = 0;
      
      print('🗑️ Starting storage cleanup for user: $userId');
      
      // 1. Profile fotoğrafını sil (userData'dan photoUrl)
      final photoUrl = userData?['photoUrl'];
      if (photoUrl != null && photoUrl.toString().isNotEmpty) {
        try {
          await ProfilePhotoHelper.deleteOldProfilePhoto(photoUrl);
          deletedCount++;
          print('✅ Deleted profile photo from photoUrl');
        } catch (e) {
          print('❌ Profile photo deletion failed: $e');
        }
      }
      
      // 2. profile_photos/ klasöründe user ID ile başlayan dosyaları bul
      try {
        final profilePhotosRef = storage.ref().child('profile_photos');
        final listResult = await profilePhotosRef.listAll();
        
        for (final item in listResult.items) {
          // Dosya adı user ID ile başlıyorsa sil
          if (item.name.startsWith(userId)) {
            try {
              await item.delete();
              deletedCount++;
              print('✅ Deleted storage file: ${item.fullPath}');
            } catch (e) {
              print('❌ Failed to delete ${item.fullPath}: $e');
            }
          }
        }
      } catch (e) {
        print('❌ Error listing profile_photos: $e');
      }
      
      // 3. Diğer potansiyel klasörleri kontrol et
      final potentialFolders = [
        'users/$userId',           // Kullanıcı klasörü
        'documents/$userId',       // Belgeler
        'uploads/$userId',         // Yüklemeler  
        'avatars/$userId',         // Avatarlar
      ];
      
      for (final folderPath in potentialFolders) {
        try {
          final folderRef = storage.ref().child(folderPath);
          final listResult = await folderRef.listAll();
          
          // Klasördeki tüm dosyaları sil
          for (final item in listResult.items) {
            try {
              await item.delete();
              deletedCount++;
              print('✅ Deleted: ${item.fullPath}');
            } catch (e) {
              print('❌ Failed to delete ${item.fullPath}: $e');
            }
          }
          
          // Alt klasörleri de kontrol et
          for (final prefix in listResult.prefixes) {
            await _deleteStorageFolder(prefix);
          }
          
        } catch (e) {
          print('❌ Error accessing folder $folderPath: $e');
        }
      }
      
      print('🎯 Storage cleanup completed. Deleted $deletedCount files for user: $userId');
      
    } catch (e) {
      print('❌ Error during storage cleanup: $e');
      // Storage hatası ana silme işlemini durdurmasın
    }
  }
  
  // 📁 Recursive klasör silme
  Future<void> _deleteStorageFolder(Reference folderRef) async {
    try {
      final listResult = await folderRef.listAll();
      
      // Dosyaları sil
      for (final item in listResult.items) {
        try {
          await item.delete();
          print('✅ Deleted: ${item.fullPath}');
        } catch (e) {
          print('❌ Failed to delete ${item.fullPath}: $e');
        }
      }
      
      // Alt klasörleri recursive sil
      for (final prefix in listResult.prefixes) {
        await _deleteStorageFolder(prefix);
      }
      
    } catch (e) {
      print('❌ Error deleting folder ${folderRef.fullPath}: $e');
    }
  }

  // 🗑️ Kullanıcı hesabı silinirken ilgili verileri temizle
  Future<void> _cleanupUserRelatedData(String userId, Map<String, dynamic>? userData) async {
    try {
      if (userData == null) return;
      
      final batch = FirebaseFirestore.instance.batch();
      
      // Kullanıcının yönettiği organizational units'leri bul ve temizle
      final managedUnits = await FirebaseFirestore.instance
          .collection('organizationalUnits')
          .where('managedBy', isEqualTo: userId)
          .get();
      
      for (final unitDoc in managedUnits.docs) {
        final unitData = unitDoc.data();
        
        // Unit'i "pendingReassignment" olarak işaretle, tamamen silme
        batch.update(unitDoc.reference, {
          'managedBy': null, // Clear manager
          'status': 'pendingReassignment',
          'lastManagerId': userId, // Track last manager for recovery
          'managerChangedAt': FieldValue.serverTimestamp(), // 🆕 Yeni timestamp sistemi
          'needsReassignment': true,
        });
      }
      
      // Mentor olarak atanmış olduğu mentorship groups'ları temizle
      final mentorGroups = await FirebaseFirestore.instance
          .collection('organizationalUnits')
          .where('currentMentorId', isEqualTo: userId)
          .get();
      
      for (final groupDoc in mentorGroups.docs) {
        batch.update(groupDoc.reference, {
          'currentMentorId': null,
          'mentorName': null,
          'status': 'pending',
          'lastMentorId': userId,
          'mentorRemovedAt': FieldValue.serverTimestamp(),
        });
      }
      
      // Multi-role sistemi: roles array'ından yönetilen entityleri de kontrol et
      final roles = userData['roles'];
      if (roles != null && roles is List) {
        for (final role in roles) {
          final managesEntity = role['managesEntity'];
          if (managesEntity != null) {
            try {
              final entityRef = FirebaseFirestore.instance.doc(managesEntity);
              final entityDoc = await entityRef.get();
              
              if (entityDoc.exists) {
                batch.update(entityRef, {
                  'managedBy': null, // Clear manager
                  'status': 'pendingReassignment',
                  'lastManagerId': userId, // Track last manager for recovery
                  'managerDeletedAt': FieldValue.serverTimestamp(),
                  'deletedUserRole': role['role'],
                });
              }
            } catch (e) {
              print('Error updating entity $managesEntity: $e');
            }
          }
        }
      }
      
      // Batch işlemini uygula
      await batch.commit();
      
      print('User-related data cleanup completed for user: $userId');
      
    } catch (e) {
      print('Error during user data cleanup: $e');
      // Cleanup hatası ana silme işlemini durdurmasın
    }
  }

  @override
  Widget build(BuildContext context) {
    final roleColors = {
      'admin': Colors.red,
      'director': Colors.orange,
      'middleSchoolCoordinator': Colors.amber,
      'highSchoolCoordinator': Colors.purple,
      'universityCoordinator': Colors.indigo,
      'housingCoordinator': Colors.cyan,
      'middleSchoolAssistantCoordinator': Colors.green,
      'highSchoolAssistantCoordinator': Colors.teal,
      'universityAssistantCoordinator': Colors.blueGrey,
      'housingAssistantCoordinator': Colors.lightGreen,
      'middleSchoolMentor': Colors.blue,
      'highSchoolMentor': Colors.blue,
      'houseLeader': Colors.indigo,
      'student': Colors.deepPurple,
      'accountant': Colors.brown,
      'moderator': Colors.purple,
      'user': Colors.grey,
    };
    final roleLabels = {
      'admin': 'Admin',
      'director': 'Director',
      'middleSchoolCoordinator': 'Middle School Coordinator',
      'highSchoolCoordinator': 'High School Coordinator',
      'universityCoordinator': 'University Coordinator',
      'housingCoordinator': 'Housing Coordinator',
      'middleSchoolAssistantCoordinator': 'Middle School Assistant Coordinator',
      'highSchoolAssistantCoordinator': 'High School Assistant Coordinator',
      'universityAssistantCoordinator': 'University Assistant Coordinator',
      'housingAssistantCoordinator': 'Housing Assistant Coordinator',
      'middleSchoolMentor': 'Middle School Mentor',
      'highSchoolMentor': 'High School Mentor',
      'houseLeader': 'House Leader',
      'student': 'Student',
      'accountant': 'Accountant',
      'moderator': 'Moderator',
      'user': 'User',
    };
    return Scaffold(
      appBar: AppBar(
        leading: !_isEditMode
            ? IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () {
                  context.pop();
                },
              )
            : null,
        title: const Text('Your Profile'),
        actions: [
          _isEditMode
              ? IconButton(
                  icon: const Icon(Icons.close, size: 28),
                  tooltip: 'Cancel Edit',
                  onPressed: _onEditCancel,
                )
              : IconButton(
                  icon: const Icon(Icons.edit, size: 28),
                  tooltip: 'Edit',
                  onPressed: () {
                    setState(() {
                      _isEditMode = true;
                    });
                  },
                ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Kullanıcı kartı
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                    child: Column(
                      children: [
                        // Avatar
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            GestureDetector(
                              onTap: _isEditMode
                                  ? () {
                                      showModalBottomSheet(
                                        context: context,
                                        builder: (context) => SafeArea(
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              ListTile(
                                                leading: const Icon(Icons.photo_camera),
                                                title: const Text('Upload Photo'),
                                                onTap: () {
                                                  Navigator.pop(context);
                                                  _handleProfilePhotoChange();
                                                },
                                              ),
                                              ListTile(
                                                leading: const Icon(Icons.account_circle),
                                                title: const Text('Choose Avatar'),
                                                onTap: () {
                                                  Navigator.pop(context);
                                                  _handleAvatarPick();
                                                },
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    }
                                  : null,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  CircleAvatar(
                                    radius: 64,
                                    backgroundImage: _pendingPhotoFile != null
                                        ? FileImage(_pendingPhotoFile!) as ImageProvider
                                        : _photoUrl != null
                                            ? NetworkImage(_photoUrl!)
                                            : (_pendingAvatar != null && _pendingAvatar!.startsWith('assets/avatars'))
                                                ? AssetImage(_pendingAvatar!) as ImageProvider
                                                : (_avatarEmoji != null && _avatarEmoji!.startsWith('assets/avatars'))
                                                    ? AssetImage(_avatarEmoji!) as ImageProvider
                                                    : null,
                                    backgroundColor: Colors.grey.shade300,
                                    child: (_pendingPhotoFile == null && _photoUrl == null && _pendingAvatar == null && (_avatarEmoji == null || !_avatarEmoji!.startsWith('assets/avatars')))
                                        ? const Icon(Icons.person, size: 48, color: Colors.white)
                                        : null,
                                  ),
                                  if (_isEditMode)
                                    Positioned(
                                      bottom: 8,
                                      right: 8,
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: _hasPendingPhotoChanges ? Colors.orange : Colors.black54,
                                          shape: BoxShape.circle,
                                        ),
                                        padding: const EdgeInsets.all(6),
                                        child: Icon(
                                          _hasPendingPhotoChanges ? Icons.pending : Icons.camera_alt, 
                                          color: Colors.white, 
                                          size: 28
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // E-posta
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.email, size: 18, color: Colors.grey),
                            const SizedBox(width: 6),
                            Text(_email ?? '-', style: const TextStyle(fontSize: 15)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        // Kayıt tarihi
                        if (_createdAt != null)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                              const SizedBox(width: 6),
                              Text('Joined: ${DateFormat.yMMMMd().format(_createdAt!)}', style: const TextStyle(fontSize: 13)),
                            ],
                          ),
                        if (_role != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 14.0, bottom: 2.0),
                            child: Center(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                                decoration: BoxDecoration(
                                  color: roleColors[_role] ?? Colors.grey,
                                  borderRadius: BorderRadius.circular(32),
                                ),
                                child: Text(
                                  roleLabels[_role] ?? 'User',
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                // Bilgi alanları
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8)],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Username
                      _isEditMode
                          ? ProfileField(
                              controller: _usernameController,
                              label: 'Username',
                              icon: Icons.person,
                            )
                          : ProfileListTile(
                              icon: Icons.person,
                              title: 'Username',
                              subtitle: _usernameController.text,
                            ),
                      // First Name
                      _isEditMode
                          ? ProfileField(
                              controller: _firstNameController,
                              label: 'First Name',
                              icon: Icons.badge,
                            )
                          : ProfileListTile(
                              icon: Icons.badge,
                              title: 'First Name',
                              subtitle: _firstNameController.text,
                            ),
                      // Last Name
                      _isEditMode
                          ? ProfileField(
                              controller: _lastNameController,
                              label: 'Last Name',
                              icon: Icons.badge_outlined,
                            )
                          : ProfileListTile(
                              icon: Icons.badge_outlined,
                              title: 'Last Name',
                              subtitle: _lastNameController.text,
                            ),
                      // Gender (Dropdown olarak, Last Name'den sonra)
                      _isEditMode
                          ? DropdownButtonFormField<String>(
                              value: _gender,
                              items: _genders
                                  .map((g) => DropdownMenuItem(
                                        value: g,
                                        child: Text(g),
                                      ))
                                  .toList(),
                              onChanged: (val) {
                                setState(() {
                                  _gender = val;
                                });
                              },
                              decoration: const InputDecoration(
                                labelText: 'Gender *',
                                prefixIcon: Icon(Icons.wc),
                              ),
                            )
                          : ProfileListTile(
                              icon: Icons.wc,
                              title: 'Gender',
                              subtitle: _gender ?? '-',
                            ),
                      // Country
                      _isEditMode
                          ? DropdownButtonFormField<String>(
                              value: _country,
                              items: ['Canada', 'USA']
                                  .map((c) => DropdownMenuItem(
                                        value: c,
                                        child: Text(c),
                                      ))
                                  .toList(),
                              onChanged: (val) {
                                setState(() {
                                  _country = val;
                                });
                              },
                              decoration: const InputDecoration(labelText: 'Country', prefixIcon: Icon(Icons.flag)),
                            )
                          : ProfileListTile(
                              icon: Icons.flag,
                              title: 'Country',
                              subtitle: _country ?? '-',
                            ),
                      // Province
                      _isEditMode
                          ? DropdownButtonFormField<String>(
                              value: _selectedProvince,
                              items: _provinceCityMap.keys
                                  .map((prov) => DropdownMenuItem(
                                        value: prov,
                                        child: Text(prov),
                                      ))
                                  .toList(),
                              onChanged: (val) {
                                setState(() {
                                  _selectedProvince = val;
                                  _selectedCity = null;
                                });
                              },
                              decoration: const InputDecoration(labelText: 'Province', prefixIcon: Icon(Icons.location_city)),
                            )
                          : ProfileListTile(
                              icon: Icons.location_city,
                              title: 'Province',
                              subtitle: _selectedProvince ?? '-',
                            ),
                      // City
                      _isEditMode
                          ? DropdownButtonFormField<String>(
                              value: _selectedCity,
                              items: (_provinceCityMap[_selectedProvince] ?? [])
                                  .map((city) => DropdownMenuItem(
                                        value: city,
                                        child: Text(city),
                                      ))
                                  .toList(),
                              onChanged: (val) {
                                setState(() {
                                  _selectedCity = val;
                                });
                              },
                              decoration: const InputDecoration(labelText: 'City', prefixIcon: Icon(Icons.location_on)),
                            )
                          : ProfileListTile(
                              icon: Icons.location_on,
                              title: 'City',
                              subtitle: _selectedCity ?? '-',
                            ),
                      // Member ID
                      ProfileListTile(
                        icon: Icons.credit_card,
                        title: 'Member ID',
                        subtitle: _userData['memberId'] ?? 'Not assigned yet',
                        trailing: !_isEditMode && _userData['memberId'] != null
                            ? IconButton(
                                icon: const Icon(Icons.copy, size: 20),
                                tooltip: 'Copy Member ID',
                                onPressed: () {
                                  Clipboard.setData(ClipboardData(text: _userData['memberId']));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Member ID copied!')),
                                  );
                                },
                              )
                            : null,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                TextButton(
                  onPressed: () async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Delete Account'),
                        content: const Text('Are you sure you want to delete your account? This action cannot be undone.'),
                        actions: [
                          TextButton(onPressed: () => context.pop(false), child: const Text('Cancel')),
                          TextButton(onPressed: () => context.pop(true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
                        ],
                      ),
                    );
                    if (confirmed == true) {
                      try {
                        final user = FirebaseAuth.instance.currentUser;
                        if (user != null) {
                          // 1. Kullanıcı bilgilerini al
                          final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
                          final userData = userDoc.data();
                          final username = userData?['username'];
                          
                          // 2. Username dokümanını sil
                          if (username != null && username.toString().isNotEmpty) {
                            await FirebaseFirestore.instance.collection('usernames').doc(username).delete();
                          }
                          
                          // 3. Storage'dan kullanıcıya ait tüm dosyaları sil
                          await _deleteAllUserStorageFiles(user.uid, userData);
                          
                          // 4. Organizational units ve ilgili verileri temizle
                          await _cleanupUserRelatedData(user.uid, userData);
                          
                          // 5. Users collection'dan kullanıcı dokümanını sil
                          await FirebaseFirestore.instance.collection('users').doc(user.uid).delete();
                          
                          // 6. Firebase Auth'dan kullanıcıyı sil  
                          await user.delete();
                        }
                        
                        if (context.mounted) {
                          context.go('/login');
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Account deletion failed. Please re-login and try again.')),
                          );
                        }
                      }
                    }
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.red,
                    textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                  child: const Text('Delete Account'),
                ),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: _isEditMode
          ? SizedBox(
              height: 38,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveProfileChanges,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFFF5E6FA),
                  foregroundColor: Colors.black87,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 0),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  elevation: 2,
                  textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                  minimumSize: const Size(80, 38),
                ),
                child: _isSaving
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(_hasPendingPhotoChanges ? 'Save & Upload' : 'Save'),
              ),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}

class ProfileField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final bool enabled;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;

  const ProfileField({
    super.key,
    required this.controller,
    required this.label,
    required this.icon,
    this.enabled = true,
    this.keyboardType,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      keyboardType: keyboardType,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
      ),
    );
  }
}

class ProfileListTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const ProfileListTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: trailing,
      onTap: onTap,
    );
  }
}
