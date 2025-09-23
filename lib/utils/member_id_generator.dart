import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Member ID Generator - Fixed Unique ID System
/// 
/// SIMPLE & CLEAN APPROACH:
/// - Random letter (A-Z) + 7 random digits
/// - NO role-based prefixes
/// - NEVER changes regardless of role changes
/// - Examples: K2944143, P1234567, X9876543, B5555555
/// 
/// BENEFITS:
/// ✅ Unique forever - never changes
/// ✅ Simple to understand and remember 
/// ✅ No role confusion
/// ✅ Easy to implement
/// ✅ User-friendly like TransferWise
class MemberIdGenerator {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final Random _random = Random();

  /// Available letters for Member ID prefix (excluding confusing ones)
  /// Excluded: I, O, Q (can be confused with 1, 0, etc.)
  static const List<String> _availableLetters = [
    'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'J', 'K', 'L', 'M', 
    'N', 'P', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z'
  ];

  /// Generate a unique Member ID
  /// Format: [Random Letter][7 digits]
  /// Example: K2944143, P1234567, X9876543
  static Future<String> generateUniqueMemberId() async {
    // Try to generate a unique ID (max 15 attempts)
    for (int attempt = 0; attempt < 15; attempt++) {
      final letter = _getRandomLetter();
      final numbers = _generateRandomNumbers();
      final memberId = '$letter$numbers';
      
      // Check if this ID already exists
      final exists = await _checkMemberIdExists(memberId);
      if (!exists) {
        return memberId;
      }
    }
    
    // Fallback: use timestamp-based ID if all random attempts fail
    final letter = _getRandomLetter();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final fallbackNumbers = (timestamp % 10000000).toString().padLeft(7, '0');
    return '$letter$fallbackNumbers';
  }

  /// Get random letter from available letters
  static String _getRandomLetter() {
    return _availableLetters[_random.nextInt(_availableLetters.length)];
  }

  /// Generate random 7-digit numbers (1000000 - 9999999)
  static String _generateRandomNumbers() {
    final number = _random.nextInt(9000000) + 1000000;
    return number.toString();
  }

  /// Check if Member ID already exists in database
  static Future<bool> _checkMemberIdExists(String memberId) async {
    try {
      final query = await _firestore
          .collection('users')
          .where('memberId', isEqualTo: memberId)
          .limit(1)
          .get();
      
      return query.docs.isNotEmpty;
    } catch (e) {
      print('Error checking Member ID existence: $e');
      return false; // Assume it doesn't exist if we can't check
    }
  }

  /// Batch generate Member IDs for multiple users (for migration)
  static Future<Map<String, String>> batchGenerateMemberIds(
    List<QueryDocumentSnapshot> users,
  ) async {
    final Map<String, String> memberIds = {};
    
    for (final user in users) {
      final userData = user.data() as Map<String, dynamic>;
      final uid = user.id;
      final currentMemberId = userData['memberId'] as String?;
      
      // Skip if user already has a valid Member ID
      if (currentMemberId != null && isValidMemberIdFormat(currentMemberId)) {
        print('✅ User $uid already has valid Member ID: $currentMemberId');
        continue;
      }
      
      try {
        final memberId = await generateUniqueMemberId();
        memberIds[uid] = memberId;
        print('✅ Generated Member ID: $memberId for user $uid');
      } catch (e) {
        print('❌ Failed to generate Member ID for user $uid: $e');
        // Generate fallback ID
        final fallback = '${_getRandomLetter()}${DateTime.now().millisecondsSinceEpoch % 10000000}';
        memberIds[uid] = fallback;
      }
    }
    
    return memberIds;
  }

  /// Convert Member ID to Firebase UID
  static Future<String?> getUidFromMemberId(String memberId) async {
    try {
      // Validate format first
      if (!isValidMemberIdFormat(memberId)) {
        return null;
      }
      
      final query = await _firestore
          .collection('users')
          .where('memberId', isEqualTo: memberId)
          .limit(1)
          .get();
      
      if (query.docs.isEmpty) {
        return null;
      }
      
      return query.docs.first.id; // Return Firebase UID
    } catch (e) {
      print('Error converting Member ID to UID: $e');
      return null;
    }
  }

  /// Get user info from Member ID
  static Future<Map<String, dynamic>?> getUserInfoFromMemberId(String memberId) async {
    try {
      final uid = await getUidFromMemberId(memberId);
      if (uid == null) return null;
      
      final userDoc = await _firestore.collection('users').doc(uid).get();
      if (!userDoc.exists) return null;
      
      final userData = userDoc.data() as Map<String, dynamic>;
      userData['uid'] = uid; // Include UID for internal operations
      return userData;
    } catch (e) {
      print('Error getting user info from Member ID: $e');
      return null;
    }
  }

  /// Assign Member ID to user (if they don't have one)
  static Future<String?> assignMemberIdToUser(String userId) async {
    try {
      // Check if user already has a Member ID
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) return null;
      
      final userData = userDoc.data() as Map<String, dynamic>;
      final existingMemberId = userData['memberId'] as String?;
      
      // If user already has a valid Member ID, return it
      if (existingMemberId != null && isValidMemberIdFormat(existingMemberId)) {
        return existingMemberId;
      }
      
      // Generate new Member ID
      final newMemberId = await generateUniqueMemberId();
      
      // Update user document
      await _firestore.collection('users').doc(userId).update({
        'memberId': newMemberId,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      print('✅ Assigned Member ID: $newMemberId to user: $userId');
      return newMemberId;
      
    } catch (e) {
      print('❌ Error assigning Member ID to user $userId: $e');
      return null;
    }
  }

  /// Validate Member ID format
  /// Valid format: 1 letter + 7 digits (e.g. K2944143)
  static bool isValidMemberIdFormat(String memberId) {
    // Check format: 1 letter + 7 digits  
    final regex = RegExp(r'^[A-Z]\d{7}$');
    return regex.hasMatch(memberId);
  }

  /// Get Member ID statistics
  static Future<Map<String, dynamic>> getMemberIdStats() async {
    try {
      final usersSnapshot = await _firestore.collection('users').get();
      
      int totalUsers = usersSnapshot.docs.length;
      int usersWithMemberId = 0;
      int usersWithoutMemberId = 0;
      Map<String, int> letterDistribution = {};
      
      for (final doc in usersSnapshot.docs) {
        final userData = doc.data();
        final memberId = userData['memberId'] as String?;
        
        if (memberId != null && isValidMemberIdFormat(memberId)) {
          usersWithMemberId++;
          
          // Count letter distribution
          final letter = memberId[0];
          letterDistribution[letter] = (letterDistribution[letter] ?? 0) + 1;
        } else {
          usersWithoutMemberId++;
        }
      }
      
      return {
        'totalUsers': totalUsers,
        'usersWithMemberId': usersWithMemberId,
        'usersWithoutMemberId': usersWithoutMemberId,
        'migrationProgress': totalUsers > 0 ? (usersWithMemberId / totalUsers) * 100 : 0,
        'letterDistribution': letterDistribution,
      };
    } catch (e) {
      print('Error getting Member ID stats: $e');
      return {};
    }
  }

  /// Generate sample Member IDs for testing/preview
  static List<String> generateSampleMemberIds(int count) {
    final samples = <String>[];
    
    for (int i = 0; i < count; i++) {
      final letter = _getRandomLetter();
      final numbers = _generateRandomNumbers();
      samples.add('$letter$numbers');
    }
    
    return samples;
  }

  /// Get letter from Member ID
  static String? getLetterFromMemberId(String memberId) {
    if (!isValidMemberIdFormat(memberId)) return null;
    return memberId[0];
  }

  /// Get numbers from Member ID
  static String? getNumbersFromMemberId(String memberId) {
    if (!isValidMemberIdFormat(memberId)) return null;
    return memberId.substring(1);
  }

  /// Search users by Member ID pattern
  static Future<List<Map<String, dynamic>>> searchUsersByMemberIdPattern(String pattern) async {
    try {
      // Simple search - you can enhance this with more complex patterns
      final query = await _firestore
          .collection('users')
          .where('memberId', isGreaterThanOrEqualTo: pattern)
          .where('memberId', isLessThan: '${pattern}z')
          .limit(50)
          .get();
      
      return query.docs.map((doc) {
        final data = doc.data();
        data['uid'] = doc.id;
        return data;
      }).toList();
      
    } catch (e) {
      print('Error searching users by Member ID pattern: $e');
      return [];
    }
  }
}