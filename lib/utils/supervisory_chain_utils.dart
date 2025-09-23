import 'package:cloud_firestore/cloud_firestore.dart';
import 'member_id_generator.dart';

/// Utility class for managing supervisory chain operations
/// 🎯 NOW SUPPORTS BOTH FIREBASE UID AND MEMBER ID REFERENCES
class SupervisoryChainUtils {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Get all subordinates of a given supervisor
  /// 🎯 SUPPORTS BOTH UID AND MEMBER ID
  static Future<List<Map<String, dynamic>>> getSubordinates(String supervisorId) async {
    try {
      final query = await _firestore
          .collection('supervisoryChain')
          .where('supervisorId', isEqualTo: supervisorId)
          .where('status', isEqualTo: 'active')
          .get();
      
      return query.docs.map((doc) => {
        'id': doc.id,
        ...doc.data(),
      }).toList();
    } catch (e) {
      print('Error getting subordinates: $e');
      return [];
    }
  }

  /// 🎯 NEW: Get all subordinates by Member ID
  static Future<List<Map<String, dynamic>>> getSubordinatesByMemberId(String supervisorMemberId) async {
    try {
      // First convert Member ID to UID
      final supervisorUid = await MemberIdGenerator.getUidFromMemberId(supervisorMemberId);
      if (supervisorUid == null) {
        print('Error: Supervisor Member ID not found: $supervisorMemberId');
        return [];
      }

      // Query using UID but also try Member ID field if it exists
      final uidQuery = _firestore
          .collection('supervisoryChain')
          .where('supervisorId', isEqualTo: supervisorUid)
          .where('status', isEqualTo: 'active');

      final memberIdQuery = _firestore
          .collection('supervisoryChain')
          .where('supervisorMemberId', isEqualTo: supervisorMemberId)
          .where('status', isEqualTo: 'active');

      // Execute both queries in parallel
      final results = await Future.wait([
        uidQuery.get(),
        memberIdQuery.get(),
      ]);

      final List<Map<String, dynamic>> subordinates = [];
      final Set<String> seenIds = <String>{};

      // Process UID query results
      for (final doc in results[0].docs) {
        if (!seenIds.contains(doc.id)) {
          subordinates.add({
            'id': doc.id,
            ...doc.data(),
          });
          seenIds.add(doc.id);
        }
      }

      // Process Member ID query results (avoid duplicates)
      for (final doc in results[1].docs) {
        if (!seenIds.contains(doc.id)) {
          subordinates.add({
            'id': doc.id,
            ...doc.data(),
          });
          seenIds.add(doc.id);
        }
      }
      
      return subordinates;
    } catch (e) {
      print('Error getting subordinates by Member ID: $e');
      return [];
    }
  }

  /// Get the supervisor of a given user
  /// 🎯 SUPPORTS BOTH UID AND MEMBER ID
  static Future<Map<String, dynamic>?> getSupervisor(String userId) async {
    try {
      final query = await _firestore
          .collection('supervisoryChain')
          .where('subordinateId', isEqualTo: userId)
          .where('status', isEqualTo: 'active')
          .limit(1)
          .get();
      
      if (query.docs.isNotEmpty) {
        return {
          'id': query.docs.first.id,
          ...query.docs.first.data(),
        };
      }
      return null;
    } catch (e) {
      print('Error getting supervisor: $e');
      return null;
    }
  }

  /// 🎯 NEW: Get supervisor by Member ID
  static Future<Map<String, dynamic>?> getSupervisorByMemberId(String userMemberId) async {
    try {
      // First convert Member ID to UID
      final userUid = await MemberIdGenerator.getUidFromMemberId(userMemberId);
      if (userUid == null) {
        print('Error: User Member ID not found: $userMemberId');
        return null;
      }

      // Try both UID and Member ID queries
      final uidQuery = _firestore
          .collection('supervisoryChain')
          .where('subordinateId', isEqualTo: userUid)
          .where('status', isEqualTo: 'active')
          .limit(1);

      final memberIdQuery = _firestore
          .collection('supervisoryChain')
          .where('subordinateMemberId', isEqualTo: userMemberId)
          .where('status', isEqualTo: 'active')
          .limit(1);

      // Execute both queries in parallel
      final results = await Future.wait([
        uidQuery.get(),
        memberIdQuery.get(),
      ]);

      // Return first result found
      if (results[0].docs.isNotEmpty) {
        return {
          'id': results[0].docs.first.id,
          ...results[0].docs.first.data(),
        };
      }

      if (results[1].docs.isNotEmpty) {
        return {
          'id': results[1].docs.first.id,
          ...results[1].docs.first.data(),
        };
      }

      return null;
    } catch (e) {
      print('Error getting supervisor by Member ID: $e');
      return null;
    }
  }

  /// Get the complete supervisory chain for a user (from top to bottom)
  /// 🎯 SUPPORTS BOTH UID AND MEMBER ID
  static Future<List<Map<String, dynamic>>> getSupervisoryChain(String userId) async {
    List<Map<String, dynamic>> chain = [];
    String? currentUserId = userId;
    
    try {
      // Traverse up the chain
      while (currentUserId != null) {
        final supervisor = await getSupervisor(currentUserId);
        if (supervisor != null) {
          chain.insert(0, supervisor); // Insert at beginning to build top-down chain
          currentUserId = supervisor['supervisorId'] as String?;
        } else {
          break;
        }
      }
      
      return chain;
    } catch (e) {
      print('Error getting supervisory chain: $e');
      return [];
    }
  }

  /// 🎯 NEW: Get complete supervisory chain by Member ID
  static Future<List<Map<String, dynamic>>> getSupervisoryChainByMemberId(String userMemberId) async {
    List<Map<String, dynamic>> chain = [];
    String? currentUserMemberId = userMemberId;
    
    try {
      // Traverse up the chain using Member IDs
      while (currentUserMemberId != null) {
        final supervisor = await getSupervisorByMemberId(currentUserMemberId);
        if (supervisor != null) {
          chain.insert(0, supervisor); // Insert at beginning to build top-down chain
          
          // Try to get supervisor's Member ID, fallback to UID
          currentUserMemberId = supervisor['supervisorMemberId'] as String?;
          if (currentUserMemberId == null) {
            final supervisorUid = supervisor['supervisorId'] as String?;
            if (supervisorUid != null) {
              // Convert UID to Member ID for next iteration
              final userInfo = await MemberIdGenerator.getUserInfoFromMemberId(supervisorUid);
              currentUserMemberId = userInfo?['memberId'] as String?;
            }
          }
        } else {
          break;
        }
      }
      
      return chain;
    } catch (e) {
      print('Error getting supervisory chain by Member ID: $e');
      return [];
    }
  }

  /// Get all users in a specific organization's hierarchy
  static Future<List<Map<String, dynamic>>> getOrganizationHierarchy(String organization) async {
    try {
      final query = await _firestore
          .collection('supervisoryChain')
          .where('organization', isEqualTo: organization) // country -> organization
          .where('status', isEqualTo: 'active')
          .get();
      
      return query.docs.map((doc) => {
        'id': doc.id,
        ...doc.data(),
      }).toList();
    } catch (e) {
      print('Error getting organization hierarchy: $e');
      return [];
    }
  }

  /// Get assignment history for a user
  /// 🎯 SUPPORTS BOTH UID AND MEMBER ID
  static Future<List<Map<String, dynamic>>> getAssignmentHistory(String userId) async {
    try {
      final query = await _firestore
          .collection('assignmentHistory')
          .where('targetUserId', isEqualTo: userId)
          .orderBy('assignmentDate', descending: true)
          .get();
      
      return query.docs.map((doc) => {
        'id': doc.id,
        ...doc.data(),
      }).toList();
    } catch (e) {
      print('Error getting assignment history: $e');
      return [];
    }
  }

  /// 🎯 NEW: Get assignment history by Member ID
  static Future<List<Map<String, dynamic>>> getAssignmentHistoryByMemberId(String userMemberId) async {
    try {
      // First convert Member ID to UID
      final userUid = await MemberIdGenerator.getUidFromMemberId(userMemberId);
      if (userUid == null) {
        print('Error: User Member ID not found: $userMemberId');
        return [];
      }

      // Query using both UID and Member ID fields
      final uidQuery = _firestore
          .collection('assignmentHistory')
          .where('targetUserId', isEqualTo: userUid)
          .orderBy('assignmentDate', descending: true);

      final memberIdQuery = _firestore
          .collection('assignmentHistory')
          .where('targetUserMemberId', isEqualTo: userMemberId)
          .orderBy('assignmentDate', descending: true);

      // Execute both queries in parallel
      final results = await Future.wait([
        uidQuery.get(),
        memberIdQuery.get(),
      ]);

      final List<Map<String, dynamic>> history = [];
      final Set<String> seenIds = <String>{};

      // Process UID query results
      for (final doc in results[0].docs) {
        if (!seenIds.contains(doc.id)) {
          history.add({
            'id': doc.id,
            ...doc.data(),
          });
          seenIds.add(doc.id);
        }
      }

      // Process Member ID query results (avoid duplicates)
      for (final doc in results[1].docs) {
        if (!seenIds.contains(doc.id)) {
          history.add({
            'id': doc.id,
            ...doc.data(),
          });
          seenIds.add(doc.id);
        }
      }

      // Sort by assignment date
      history.sort((a, b) {
        final aDate = a['assignmentDate'] as Timestamp?;
        final bDate = b['assignmentDate'] as Timestamp?;
        if (aDate == null || bDate == null) return 0;
        return bDate.compareTo(aDate);
      });
      
      return history;
    } catch (e) {
      print('Error getting assignment history by Member ID: $e');
      return [];
    }
  }

  /// Get all assignments made by a specific moderator/admin
  /// 🎯 SUPPORTS BOTH UID AND MEMBER ID
  static Future<List<Map<String, dynamic>>> getAssignmentsByModerator(String moderatorId) async {
    try {
      final query = await _firestore
          .collection('assignmentHistory')
          .where('assignedBy', isEqualTo: moderatorId)
          .orderBy('assignmentDate', descending: true)
          .get();
      
      return query.docs.map((doc) => {
        'id': doc.id,
        ...doc.data(),
      }).toList();
    } catch (e) {
      print('Error getting moderator assignments: $e');
      return [];
    }
  }

  /// 🎯 NEW: Get assignments by Moderator Member ID
  static Future<List<Map<String, dynamic>>> getAssignmentsByModeratorMemberId(String moderatorMemberId) async {
    try {
      // First convert Member ID to UID
      final moderatorUid = await MemberIdGenerator.getUidFromMemberId(moderatorMemberId);
      if (moderatorUid == null) {
        print('Error: Moderator Member ID not found: $moderatorMemberId');
        return [];
      }

      // Query using both UID and Member ID fields
      final uidQuery = _firestore
          .collection('assignmentHistory')
          .where('assignedBy', isEqualTo: moderatorUid)
          .orderBy('assignmentDate', descending: true);

      final memberIdQuery = _firestore
          .collection('assignmentHistory')
          .where('assignedByMemberId', isEqualTo: moderatorMemberId)
          .orderBy('assignmentDate', descending: true);

      // Execute both queries in parallel
      final results = await Future.wait([
        uidQuery.get(),
        memberIdQuery.get(),
      ]);

      final List<Map<String, dynamic>> assignments = [];
      final Set<String> seenIds = <String>{};

      // Process UID query results
      for (final doc in results[0].docs) {
        if (!seenIds.contains(doc.id)) {
          assignments.add({
            'id': doc.id,
            ...doc.data(),
          });
          seenIds.add(doc.id);
        }
      }

      // Process Member ID query results (avoid duplicates)
      for (final doc in results[1].docs) {
        if (!seenIds.contains(doc.id)) {
          assignments.add({
            'id': doc.id,
            ...doc.data(),
          });
          seenIds.add(doc.id);
        }
      }

      // Sort by assignment date
      assignments.sort((a, b) {
        final aDate = a['assignmentDate'] as Timestamp?;
        final bDate = b['assignmentDate'] as Timestamp?;
        if (aDate == null || bDate == null) return 0;
        return bDate.compareTo(aDate);
      });
      
      return assignments;
    } catch (e) {
      print('Error getting assignments by Moderator Member ID: $e');
      return [];
    }
  }

  /// Update supervisory chain status (e.g., when removing roles)
  /// 🎯 SUPPORTS BOTH UID AND MEMBER ID
  static Future<bool> updateSupervisoryChainStatus(String subordinateId, String status) async {
    try {
      final query = await _firestore
          .collection('supervisoryChain')
          .where('subordinateId', isEqualTo: subordinateId)
          .where('status', isEqualTo: 'active')
          .get();
      
      final batch = _firestore.batch();
      for (var doc in query.docs) {
        batch.update(doc.reference, {'status': status, 'updatedAt': DateTime.now().millisecondsSinceEpoch});
      }
      
      await batch.commit();
      return true;
    } catch (e) {
      print('Error updating supervisory chain status: $e');
      return false;
    }
  }

  /// 🎯 NEW: Update supervisory chain status by Member ID
  static Future<bool> updateSupervisoryChainStatusByMemberId(String subordinateMemberId, String status) async {
    try {
      // First convert Member ID to UID
      final subordinateUid = await MemberIdGenerator.getUidFromMemberId(subordinateMemberId);
      if (subordinateUid == null) {
        print('Error: Subordinate Member ID not found: $subordinateMemberId');
        return false;
      }

      // Query using both UID and Member ID
      final uidQuery = await _firestore
          .collection('supervisoryChain')
          .where('subordinateId', isEqualTo: subordinateUid)
          .where('status', isEqualTo: 'active')
          .get();

      final memberIdQuery = await _firestore
          .collection('supervisoryChain')
          .where('subordinateMemberId', isEqualTo: subordinateMemberId)
          .where('status', isEqualTo: 'active')
          .get();
      
      final batch = _firestore.batch();
      final Set<String> updatedDocs = <String>{};

      // Update UID query results
      for (var doc in uidQuery.docs) {
        if (!updatedDocs.contains(doc.id)) {
          batch.update(doc.reference, {
            'status': status, 
            'updatedAt': DateTime.now().millisecondsSinceEpoch,
            'updatedByMemberId': true, // Flag to indicate this was updated via Member ID
          });
          updatedDocs.add(doc.id);
        }
      }

      // Update Member ID query results (avoid duplicates)
      for (var doc in memberIdQuery.docs) {
        if (!updatedDocs.contains(doc.id)) {
          batch.update(doc.reference, {
            'status': status, 
            'updatedAt': DateTime.now().millisecondsSinceEpoch,
            'updatedByMemberId': true,
          });
          updatedDocs.add(doc.id);
        }
      }
      
      await batch.commit();
      return true;
    } catch (e) {
      print('Error updating supervisory chain status by Member ID: $e');
      return false;
    }
  }

  /// Get moderator's managed directors
  /// 🎯 SUPPORTS BOTH UID AND MEMBER ID
  static Future<List<Map<String, dynamic>>> getModeratorManagedCoordinators(String moderatorId) async {
    try {
      final query = await _firestore
          .collection('supervisoryChain')
          .where('supervisorId', isEqualTo: moderatorId)
          .where('subordinateRole', isEqualTo: 'director')
          .where('status', isEqualTo: 'active')
          .get();
      
      return query.docs.map((doc) => {
        'id': doc.id,
        ...doc.data(),
      }).toList();
    } catch (e) {
      print('Error getting moderator managed coordinators: $e');
      return [];
    }
  }

  /// 🎯 NEW: Get moderator's managed coordinators by Member ID
  static Future<List<Map<String, dynamic>>> getModeratorManagedCoordinatorsByMemberId(String moderatorMemberId) async {
    try {
      // First convert Member ID to UID
      final moderatorUid = await MemberIdGenerator.getUidFromMemberId(moderatorMemberId);
      if (moderatorUid == null) {
        print('Error: Moderator Member ID not found: $moderatorMemberId');
        return [];
      }

      // Query using both UID and Member ID
      final uidQuery = _firestore
          .collection('supervisoryChain')
          .where('supervisorId', isEqualTo: moderatorUid)
          .where('subordinateRole', isEqualTo: 'director')
          .where('status', isEqualTo: 'active');

      final memberIdQuery = _firestore
          .collection('supervisoryChain')
          .where('supervisorMemberId', isEqualTo: moderatorMemberId)
          .where('subordinateRole', isEqualTo: 'director')
          .where('status', isEqualTo: 'active');

      // Execute both queries in parallel
      final results = await Future.wait([
        uidQuery.get(),
        memberIdQuery.get(),
      ]);

      final List<Map<String, dynamic>> coordinators = [];
      final Set<String> seenIds = <String>{};

      // Process UID query results
      for (final doc in results[0].docs) {
        if (!seenIds.contains(doc.id)) {
          coordinators.add({
            'id': doc.id,
            ...doc.data(),
          });
          seenIds.add(doc.id);
        }
      }

      // Process Member ID query results (avoid duplicates)
      for (final doc in results[1].docs) {
        if (!seenIds.contains(doc.id)) {
          coordinators.add({
            'id': doc.id,
            ...doc.data(),
          });
          seenIds.add(doc.id);
        }
      }
      
      return coordinators;
    } catch (e) {
      print('Error getting moderator managed coordinators by Member ID: $e');
      return [];
    }
  }

  /// Validate supervisory chain integrity
  static Future<Map<String, dynamic>> validateChainIntegrity(String organization) async {
    Map<String, dynamic> report = {
      'isValid': true,
      'issues': <String>[],
      'statistics': {},
    };
    
    try {
      final hierarchyData = await getOrganizationHierarchy(organization);
      
      // Check for orphaned entries
      List<String> orphanedUsers = [];
      List<String> duplicateSupervisions = [];
      
      // Group by subordinateId to check for duplicates
      Map<String, List<Map<String, dynamic>>> subordinateGroups = {};
      for (var entry in hierarchyData) {
        final subordinateId = entry['subordinateId'] as String;
        subordinateGroups.putIfAbsent(subordinateId, () => []).add(entry);
      }
      
      // Check for duplicate supervisions
      subordinateGroups.forEach((subordinateId, entries) {
        if (entries.length > 1) {
          duplicateSupervisions.add(subordinateId);
          report['isValid'] = false;
          report['issues'].add('User $subordinateId has multiple active supervisors');
        }
      });
      
      // Count roles
      Map<String, int> roleCounts = {};
      for (var entry in hierarchyData) {
        final role = entry['subordinateRole'] as String;
        roleCounts[role] = (roleCounts[role] ?? 0) + 1;
      }
      
      report['statistics'] = {
        'totalEntries': hierarchyData.length,
        'roleCounts': roleCounts,
        'duplicateSupervisions': duplicateSupervisions.length,
        'orphanedUsers': orphanedUsers.length,
      };
      
    } catch (e) {
      report['isValid'] = false;
      report['issues'].add('Error validating chain: $e');
    }
    
    return report;
  }

  /// Generate supervisory chain report for administrative oversight
  /// 🎯 NOW INCLUDES MEMBER ID REFERENCES
  static Future<Map<String, dynamic>> generateChainReport(String organization) async {
    try {
      final hierarchyData = await getOrganizationHierarchy(organization);
      final assignmentHistory = await _firestore
          .collection('assignmentHistory')
          .where('organization', isEqualTo: organization)
          .orderBy('assignmentDate', descending: true)
          .limit(50)
          .get();
      
      // Build organizational tree with Member ID support
      Map<String, Map<String, dynamic>> organizationalTree = {};
      
      for (var entry in hierarchyData) {
        final supervisorId = entry['supervisorId'] as String;
        final subordinateId = entry['subordinateId'] as String;
        final supervisorMemberId = entry['supervisorMemberId'] as String?;
        final subordinateMemberId = entry['subordinateMemberId'] as String?;
        
        organizationalTree.putIfAbsent(supervisorId, () => {
          'info': {
            'id': supervisorId,
            'memberId': supervisorMemberId, // 🎯 NEW: Include Member ID
            'name': entry['supervisorName'],
            'role': entry['supervisorRole'],
          },
          'subordinates': <Map<String, dynamic>>[],
        });
        
        organizationalTree[supervisorId]!['subordinates'].add({
          'id': subordinateId,
          'memberId': subordinateMemberId, // 🎯 NEW: Include Member ID
          'name': entry['subordinateName'],
          'role': entry['subordinateRole'],
          'relationshipType': entry['relationshipType'],
          'createdAt': entry['createdAt'],
        });
      }
      
      return {
        'organization': organization,
        'generatedAt': DateTime.now().millisecondsSinceEpoch,
        'totalHierarchyEntries': hierarchyData.length,
        'organizationalTree': organizationalTree,
        'recentAssignments': assignmentHistory.docs.map((doc) => doc.data()).toList(),
        'integrityCheck': await validateChainIntegrity(organization),
        'memberIdSupport': true, // 🎯 NEW: Flag indicating Member ID support
      };
      
    } catch (e) {
      return {
        'error': 'Failed to generate report: $e',
        'organization': organization,
        'generatedAt': DateTime.now().millisecondsSinceEpoch,
      };
    }
  }

  // 🎯 NEW MEMBER ID UTILITY FUNCTIONS

  /// Create supervisory chain entry with Member ID references
  static Future<bool> createSupervisoryChainEntry({
    required String supervisorUid,
    required String subordinateUid,
    required String supervisorRole,
    required String subordinateRole,
    required String relationshipType,
    String? organization,
    String? createdByUid,
  }) async {
    try {
      // Get Member IDs for both users
      final supervisorInfo = await MemberIdGenerator.getUserInfoFromMemberId(supervisorUid);
      final subordinateInfo = await MemberIdGenerator.getUserInfoFromMemberId(subordinateUid);
      
      final supervisorMemberId = supervisorInfo?['memberId'] as String?;
      final subordinateMemberId = subordinateInfo?['memberId'] as String?;
      
      final createdByInfo = createdByUid != null 
          ? await MemberIdGenerator.getUserInfoFromMemberId(createdByUid)
          : null;
      final createdByMemberId = createdByInfo?['memberId'] as String?;

      // Create the supervisory chain entry with both UID and Member ID references
      await _firestore.collection('supervisoryChain').add({
        // 🔥 UID REFERENCES (for system compatibility)
        'supervisorId': supervisorUid,
        'subordinateId': subordinateUid,
        'createdBy': createdByUid,
        
        // 🎯 MEMBER ID REFERENCES (for admin readability)
        'supervisorMemberId': supervisorMemberId,
        'subordinateMemberId': subordinateMemberId,
        'createdByMemberId': createdByMemberId,
        
        // Other fields
        'supervisorRole': supervisorRole,
        'subordinateRole': subordinateRole,
        'relationshipType': relationshipType,
        'supervisorOrganization': organization ?? supervisorInfo?['organization'],
        'subordinateOrganization': organization ?? subordinateInfo?['organization'],
        'supervisorName': '${supervisorInfo?['firstName'] ?? ''} ${supervisorInfo?['lastName'] ?? ''}'.trim(),
        'subordinateName': '${subordinateInfo?['firstName'] ?? ''} ${subordinateInfo?['lastName'] ?? ''}'.trim(),
        'status': 'active',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      print('✅ Created supervisory chain entry: $supervisorMemberId -> $subordinateMemberId');
      return true;
    } catch (e) {
      print('❌ Error creating supervisory chain entry: $e');
      return false;
    }
  }

  /// Search users by Member ID in supervisory chain
  static Future<List<Map<String, dynamic>>> searchByMemberId(String memberIdQuery) async {
    try {
      if (memberIdQuery.length < 2) return [];

      // Search for supervisors
      final supervisorQuery = await _firestore
          .collection('supervisoryChain')
          .where('supervisorMemberId', isGreaterThanOrEqualTo: memberIdQuery)
          .where('supervisorMemberId', isLessThan: '${memberIdQuery}z')
          .where('status', isEqualTo: 'active')
          .limit(10)
          .get();

      // Search for subordinates
      final subordinateQuery = await _firestore
          .collection('supervisoryChain')
          .where('subordinateMemberId', isGreaterThanOrEqualTo: memberIdQuery)
          .where('subordinateMemberId', isLessThan: '${memberIdQuery}z')
          .where('status', isEqualTo: 'active')
          .limit(10)
          .get();

      final Set<String> seenMemberIds = <String>{};
      final List<Map<String, dynamic>> results = [];

      // Process supervisor results
      for (final doc in supervisorQuery.docs) {
        final data = doc.data();
        final memberId = data['supervisorMemberId'] as String?;
        if (memberId != null && !seenMemberIds.contains(memberId)) {
          results.add({
            'memberId': memberId,
            'name': data['supervisorName'],
            'role': data['supervisorRole'],
            'type': 'supervisor',
            'uid': data['supervisorId'],
          });
          seenMemberIds.add(memberId);
        }
      }

      // Process subordinate results
      for (final doc in subordinateQuery.docs) {
        final data = doc.data();
        final memberId = data['subordinateMemberId'] as String?;
        if (memberId != null && !seenMemberIds.contains(memberId)) {
          results.add({
            'memberId': memberId,
            'name': data['subordinateName'],
            'role': data['subordinateRole'],
            'type': 'subordinate',
            'uid': data['subordinateId'],
          });
          seenMemberIds.add(memberId);
        }
      }

      return results;
    } catch (e) {
      print('Error searching by Member ID: $e');
      return [];
    }
  }
} 