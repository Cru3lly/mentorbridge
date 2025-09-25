import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'dart:ui';

// 🌳 Hierarchy Node Data Structure
class HierarchyNode {
  final String id;
  final String name;
  final String email;
  final String role;
  final String city;
  final String province;
  final String gender;
  final String status;
  String? className;
  final DateTime? joinDate;
  final bool isMentor;
  List<HierarchyNode> children;
  bool isExpanded;

  HierarchyNode({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.city,
    required this.province,
    required this.gender,
    required this.status,
    this.className,
    this.joinDate,
    required this.isMentor,
    this.children = const [],
    this.isExpanded = false,
  });
}

class UniversalMentorsPage extends StatefulWidget {
  const UniversalMentorsPage({super.key});

  @override
  State<UniversalMentorsPage> createState() => _UniversalMentorsPageState();
}

class _UniversalMentorsPageState extends State<UniversalMentorsPage> {
  
  // 🔐 Authorization
  bool _isLoading = true;
  bool _isAuthorized = false;
  String? _currentRole;
  String? _currentUserId;
  
  // 🌳 Hierarchical Data
  List<HierarchyNode> _hierarchyNodes = [];
  final Set<String> _expandedNodes = {};
  
  // 🎯 Authorized roles for this page
  static const List<String> _authorizedRoles = [
    'admin',
    'moderator', 
    'director',
    'middleSchoolCoordinator',
    'highSchoolCoordinator',
    'middleSchoolAssistantCoordinator',
    'highSchoolAssistantCoordinator',
  ];

  @override
  void initState() {
    super.initState();
    _initializePage();
  }

  // 🎯 Initialize page with authorization and data loading
  Future<void> _initializePage() async {
    await _checkAuthorization();
    if (_isAuthorized) {
      await _loadHierarchicalData();
    }
    setState(() {
      _isLoading = false;
    });
  }

  // 🔄 Refresh data (with loading state)
  Future<void> _refreshData() async {
    setState(() {
      _isLoading = true;
      // Reset all expansion states
      _expandedNodes.clear();
      _hierarchyNodes.clear();
    });

    if (_isAuthorized) {
      await _loadHierarchicalData();
      
      // Reset all nodes to collapsed state
      for (final node in _hierarchyNodes) {
        _resetNodeAndChildren(node);
      }
    }

    setState(() {
      _isLoading = false;
    });
  }

  // 🔄 Reset node and all its children recursively
  void _resetNodeAndChildren(HierarchyNode node) {
    node.isExpanded = false;
    for (final child in node.children) {
      _resetNodeAndChildren(child);
    }
  }

  // ✏️ Show edit mentor dialog with validation
  Future<void> _showEditMentorDialog(HierarchyNode mentor) async {
    HapticFeedback.mediumImpact();
    
    // Extract current grade number (e.g., "11" from "11th Grade - A")
    String currentGrade = '';
    String currentSection = 'A';
    if (mentor.className != null) {
      final match = RegExp(r'(\d+)(?:th|st|nd|rd)?\s*Grade\s*-\s*([A-Z])').firstMatch(mentor.className!);
      if (match != null) {
        currentGrade = match.group(1) ?? '';
        currentSection = match.group(2) ?? 'A';
      }
    }
    
    final TextEditingController gradeController = TextEditingController(text: currentGrade);
    String selectedSection = currentSection;
    String? validationError;
    
    final result = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF2D3748),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Row(
                children: [
                  Icon(
                    Icons.edit,
                    color: _getRoleColor(mentor.role),
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Edit ${mentor.name}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Class Assignment',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  // Grade number input
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: gradeController,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: 'Grade',
                            labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                            hintText: '11',
                            hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                            filled: true,
                            fillColor: Colors.white.withOpacity(0.1),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: _getRoleColor(mentor.role),
                                width: 2,
                              ),
                            ),
                          ),
                          onChanged: (value) async {
                            if (value.isNotEmpty) {
                              final gradeValidation = _validateGradeNumber(mentor.role, value);
                              if (gradeValidation != null) {
                                setDialogState(() {
                                  validationError = gradeValidation;
                                });
                              } else {
                                final suggestion = await _validateAndSuggestClass(mentor, value, selectedSection);
                                setDialogState(() {
                                  validationError = suggestion;
                                });
                              }
                            } else {
                              setDialogState(() {
                                validationError = null;
                              });
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'th Grade -',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(width: 12),
                      
                      // Section dropdown
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _getRoleColor(mentor.role).withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: DropdownButton<String>(
                          value: selectedSection,
                          dropdownColor: const Color(0xFF2D3748),
                          underline: const SizedBox(),
                          style: const TextStyle(color: Colors.white),
                          items: ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H'].map((section) {
                            return DropdownMenuItem(
                              value: section,
                              child: Text(section),
                            );
                          }).toList(),
                          onChanged: (value) async {
                            if (value != null) {
                              selectedSection = value;
                              if (gradeController.text.isNotEmpty) {
                                final gradeValidation = _validateGradeNumber(mentor.role, gradeController.text);
                                if (gradeValidation != null) {
                                  setDialogState(() {
                                    validationError = gradeValidation;
                                  });
                                } else {
                                  final suggestion = await _validateAndSuggestClass(mentor, gradeController.text, value);
                                  setDialogState(() {
                                    validationError = suggestion;
                                  });
                                }
                              }
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  
                  // Validation error/suggestion
                  if (validationError != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: validationError!.contains('already exists')
                          ? const Color(0xFFE53E3E).withOpacity(0.1)
                          : const Color(0xFF4299E1).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: validationError!.contains('already exists')
                            ? const Color(0xFFE53E3E)
                            : const Color(0xFF4299E1),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        validationError!,
                        style: TextStyle(
                          color: validationError!.contains('already exists')
                            ? const Color(0xFFFC8181)
                            : const Color(0xFF90CDF4),
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    'Cancel',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: validationError != null
                    ? null // Disable if any validation error
                    : () {
                        final grade = gradeController.text.trim();
                        if (grade.isNotEmpty) {
                          final gradeValidation = _validateGradeNumber(mentor.role, grade);
                          if (gradeValidation == null) {
                            final newClass = '${grade}th Grade - $selectedSection';
                            Navigator.of(context).pop(newClass);
                          }
                        }
                      },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _getRoleColor(mentor.role),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
    
    if (result != null && result != mentor.className) {
      await _updateMentorClass(mentor, result);
    }
  }

  // 💾 Update mentor class in Firestore
  Future<void> _updateMentorClass(HierarchyNode mentor, String newClass) async {
    try {
      // Show loading
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
                const SizedBox(width: 12),
                Text('Updating ${mentor.name}\'s class...'),
              ],
            ),
            backgroundColor: const Color(0xFF4A5568),
            duration: const Duration(seconds: 2),
          ),
        );
      }

      // Find mentor's organizational unit
      final mentorUnitsQuery = await FirebaseFirestore.instance
          .collection('organizationalUnits')
          .where('managedBy', isEqualTo: mentor.id)
          .where('status', isEqualTo: 'active')
          .get();

      if (mentorUnitsQuery.docs.isNotEmpty) {
        final mentorUnitDoc = mentorUnitsQuery.docs.first;
        
        // Update class field
        await mentorUnitDoc.reference.update({
          'class': newClass.isEmpty ? null : newClass,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        // Update local data
        setState(() {
          mentor.className = newClass.isEmpty ? null : newClass;
        });

        // Show success
        if (mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Updated ${mentor.name}\'s class successfully!',
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
              backgroundColor: const Color(0xFF38A169),
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      // Show error
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white, size: 20),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Failed to update class. Please try again.',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFFE53E3E),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  // 📊 Validate grade number based on mentor role
  String? _validateGradeNumber(String mentorRole, String grade) {
    final gradeNum = int.tryParse(grade);
    if (gradeNum == null) {
      return 'Please enter a valid grade number.';
    }
    
    if (mentorRole.contains('middleSchool')) {
      // Middle School: 6, 7, 8
      if (gradeNum < 6 || gradeNum > 8) {
        return 'Middle School mentors can only teach grades 6, 7, or 8.';
      }
    } else if (mentorRole.contains('highSchool')) {
      // High School: 9, 10, 11, 12
      if (gradeNum < 9 || gradeNum > 12) {
        return 'High School mentors can only teach grades 9, 10, 11, or 12.';
      }
    }
    
    return null; // Valid grade
  }

  // 🔍 Validate class and suggest alternatives
  Future<String?> _validateAndSuggestClass(HierarchyNode mentor, String grade, String section) async {
    try {
      final proposedClass = '${grade}th Grade - $section';
      
      // Check if class already exists in same city, gender, level
      final existingClassQuery = await FirebaseFirestore.instance
          .collection('organizationalUnits')
          .where('class', isEqualTo: proposedClass)
          .where('status', isEqualTo: 'active')
          .get();
      
      // Filter by same city, gender, and level
      bool classExists = false;
      for (final doc in existingClassQuery.docs) {
        final unitData = doc.data();
        
        // Skip if it's the same mentor's current unit
        if (unitData['managedBy'] == mentor.id) continue;
        
        // Get manager to check city/gender
        final managerId = unitData['managedBy'] as String?;
        if (managerId != null) {
          final managerDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(managerId)
              .get();
          
          if (managerDoc.exists) {
            final managerData = managerDoc.data()!;
            final managerCity = managerData['city'] as String? ?? '';
            final managerGender = managerData['gender'] as String? ?? '';
            final managerRole = managerData['role'] as String? ?? '';
            
            // Check if same city, gender, and mentor level
            if (managerCity == mentor.city && 
                managerGender == mentor.gender &&
                managerRole == mentor.role) {
              classExists = true;
              break;
            }
          }
        }
      }
      
      if (classExists) {
        // Suggest next available section
        final nextSection = String.fromCharCode(section.codeUnitAt(0) + 1);
        if (nextSection.codeUnitAt(0) <= 'E'.codeUnitAt(0)) {
          return 'Class "$proposedClass" already exists in ${mentor.city}. Try "${grade}th Grade - $nextSection" instead.';
        } else {
          return 'Class "$proposedClass" already exists in ${mentor.city}. Please choose a different grade number.';
        }
      }
      
      return null; // No validation error
    } catch (e) {
      return 'Unable to validate class. Please check your connection.';
    }
  }

  // 🔐 Check if user is authorized to access this page
  Future<void> _checkAuthorization() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() {
          _isAuthorized = false;
          _isLoading = false;
        });
        return;
      }

      _currentUserId = user.uid;
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (userDoc.exists) {
        final userData = userDoc.data()!;
        final rolesData = userData['roles'] ?? [];
        
        // Extract role strings from mixed format (String or Map)
        final roles = <String>[];
        for (final roleItem in rolesData) {
          if (roleItem is String) {
            roles.add(roleItem);
          } else if (roleItem is Map<String, dynamic> && roleItem['role'] != null) {
            roles.add(roleItem['role'] as String);
          }
        }
        
        // Get highest ranking role
        _currentRole = _getHighestRankingRole(roles);
        
        setState(() {
          _isAuthorized = _authorizedRoles.contains(_currentRole);
        });
      } else {
        setState(() {
          _isAuthorized = false;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _isAuthorized = false;
        _isLoading = false;
      });
    }
  }

  // 🎯 Get highest ranking role from user roles
  String _getHighestRankingRole(List<String> roles) {
    const roleHierarchy = [
      'admin',
      'moderator',
      'director',
      'middleSchoolCoordinator',
      'highSchoolCoordinator',
      'universityCoordinator',
      'housingCoordinator',
      'middleSchoolAssistantCoordinator',
      'highSchoolAssistantCoordinator',
      'universityAssistantCoordinator',
      'housingAssistantCoordinator',
      'middleSchoolMentor',
      'highSchoolMentor',
      'houseLeader',
      'studentHouseLeader',
      'houseMember',
      'studentHouseMember',
      'accountant',
      'mentee',
      'user',
    ];

    for (String role in roleHierarchy) {
      if (roles.contains(role)) {
        return role;
      }
    }
    return 'user';
  }

  // 📊 Load hierarchical data based on user role and managesEntity
  Future<void> _loadHierarchicalData() async {
    try {
      // Get current user's managed organizational unit
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUserId!)
          .get();
      
      if (!userDoc.exists) return;
      
      final userData = userDoc.data()!;
      
      // Get user's managesEntity from roles array
      String? currentUserUnitPath;
      final roles = userData['roles'] as List<dynamic>? ?? [];
      
      for (final role in roles) {
        if (role is Map<String, dynamic> && role['managesEntity'] != null) {
          currentUserUnitPath = role['managesEntity'] as String;
          break;
        }
      }
      
      if (currentUserUnitPath == null) {
        // Try alternative: look for organizational unit managed by this user
        final userManagedUnits = await FirebaseFirestore.instance
            .collection('organizationalUnits')
            .where('managedBy', isEqualTo: _currentUserId)
            .get();
        
        if (userManagedUnits.docs.isNotEmpty) {
          // Use the first managed unit as the reference
          currentUserUnitPath = 'organizationalUnits/${userManagedUnits.docs.first.id}';
        } else {
          _hierarchyNodes = [];
          return;
        }
      }
      
      // Find subordinate units (parentUnit = current user's unit)
      final subordinateUnitsQuery = await FirebaseFirestore.instance
          .collection('organizationalUnits')
          .where('parentUnit', isEqualTo: FirebaseFirestore.instance.doc(currentUserUnitPath))
          .where('status', isEqualTo: 'active')
          .get();
      
      await _buildHierarchyFromUnits(subordinateUnitsQuery);
      
    } catch (e) {
      _hierarchyNodes = [];
    }
  }

  // 🌳 Build hierarchy from organizational units
  Future<void> _buildHierarchyFromUnits(QuerySnapshot subordinateUnits) async {
    try {
      final hierarchyNodes = <HierarchyNode>[];
      
      // Group units by level for hierarchy building
      final Map<String, List<QueryDocumentSnapshot>> unitsByLevel = {};
      
      for (final unitDoc in subordinateUnits.docs) {
        final unitData = unitDoc.data() as Map<String, dynamic>;
        final level = unitData['level'] as String? ?? '';
        
        if (!unitsByLevel.containsKey(level)) {
          unitsByLevel[level] = [];
        }
        unitsByLevel[level]!.add(unitDoc);
      }
      
      // Build coordinator nodes first (for Director level)
      final coordinatorUnits = unitsByLevel['coordinator'] ?? [];
      
      for (final coordinatorUnit in coordinatorUnits) {
                    final coordinatorUnitData = coordinatorUnit.data();
        final coordinatorId = (coordinatorUnitData as Map<String, dynamic>)['managedBy'] as String?;
        
        if (coordinatorId == null) continue;
        
        // Get coordinator user data
        final coordinatorUserDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(coordinatorId)
            .get();
        
        if (!coordinatorUserDoc.exists) continue;
        
        final coordinatorUserData = coordinatorUserDoc.data()!;
        final coordinatorRole = coordinatorUserData['role'] as String? ?? '';
        
        // 🎯 FILTER: Only show Middle School and High School coordinators
        if (!coordinatorRole.contains('middleSchool') && !coordinatorRole.contains('highSchool')) {
          continue; // Skip University and Housing coordinators
        }
        
        // Find assistants and mentors under this coordinator
        final coordinatorSubUnitsQuery = await FirebaseFirestore.instance
            .collection('organizationalUnits')
            .where('parentUnit', isEqualTo: coordinatorUnit.reference)
            .where('status', isEqualTo: 'active')
            .get();
        
        final coordinatorChildren = <HierarchyNode>[];
        
        // Process coordinator's subordinate units
        for (final subUnit in coordinatorSubUnitsQuery.docs) {
          final subUnitData = subUnit.data();
          final subLevel = (subUnitData)['level'] as String? ?? '';
          final subManagerId = (subUnitData)['managedBy'] as String?;
          
          if (subManagerId == null) continue;
          
          // Get subordinate user data
          final subUserDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(subManagerId)
              .get();
          
          if (!subUserDoc.exists) continue;
          
          final subUserData = subUserDoc.data()!;
          
          // If it's an assistant coordinator, get their mentors
          List<HierarchyNode> mentorChildren = [];
          if (subLevel.contains('assistant') || subLevel == 'assistantCoordinator') {
            // Find mentors under this assistant
            final mentorUnitsQuery = await FirebaseFirestore.instance
                .collection('organizationalUnits')
                .where('parentUnit', isEqualTo: subUnit.reference)
                .where('status', isEqualTo: 'active')
                .get();
            
            for (final mentorUnit in mentorUnitsQuery.docs) {
              final mentorUnitData = mentorUnit.data();
              final mentorId = (mentorUnitData)['managedBy'] as String?;
              
              if (mentorId == null) continue;
              
              final mentorUserDoc = await FirebaseFirestore.instance
                  .collection('users')
                  .doc(mentorId)
                  .get();
              
              if (!mentorUserDoc.exists) continue;
              
              final mentorUserData = mentorUserDoc.data()!;
              
              DateTime? joinDate;
              final managerChangedAt = mentorUnitData['managerChangedAt'];
              if (managerChangedAt != null) {
                joinDate = (managerChangedAt as Timestamp).toDate();
              }
              
              final firstName = mentorUserData['firstName'] as String? ?? '';
              final lastName = mentorUserData['lastName'] as String? ?? '';
              final fullName = '$firstName $lastName'.trim();
              
              final mentorNode = HierarchyNode(
                id: mentorId,
                name: fullName,
                email: mentorUserData['email'] as String? ?? '',
                role: mentorUserData['role'] ?? 'mentor',
                city: mentorUnitData['city'] as String? ?? '',
                province: mentorUnitData['province'] as String? ?? '',
                gender: mentorUnitData['gender'] as String? ?? '',
                status: mentorUnitData['status'] as String? ?? 'active',
                className: mentorUnitData['class'] as String?,
                joinDate: joinDate,
                isMentor: true,
                children: [],
              );
              
              mentorChildren.add(mentorNode);
            }
          }
          
          // Create subordinate node (assistant coordinator or direct mentor)
          final firstName = subUserData['firstName'] as String? ?? '';
          final lastName = subUserData['lastName'] as String? ?? '';
          final fullName = '$firstName $lastName'.trim();
          
          final assistantNode = HierarchyNode(
            id: subManagerId,
            name: fullName,
            email: subUserData['email'] as String? ?? '',
            role: subUserData['role'] ?? subLevel,
            city: subUserData['city'] as String? ?? '',
            province: subUserData['province'] as String? ?? '',
            gender: subUserData['gender'] as String? ?? '',
            status: 'active',
            className: null,
            joinDate: null,
            isMentor: subLevel.contains('mentor') || subLevel.contains('Mentor'),
            children: mentorChildren,
            isExpanded: false,
          );
          
          coordinatorChildren.add(assistantNode);
        }
        
        // Create coordinator node
        final firstName = coordinatorUserData['firstName'] as String? ?? '';
        final lastName = coordinatorUserData['lastName'] as String? ?? '';
        final fullName = '$firstName $lastName'.trim();
        
        hierarchyNodes.add(HierarchyNode(
          id: coordinatorId,
          name: fullName,
          email: coordinatorUserData['email'] as String? ?? '',
          role: coordinatorUserData['role'] ?? 'coordinator',
          city: coordinatorUserData['city'] as String? ?? '',
          province: coordinatorUserData['province'] as String? ?? '',
          gender: coordinatorUserData['gender'] as String? ?? '',
          status: 'active',
          className: null,
          joinDate: null,
          isMentor: false,
          children: coordinatorChildren,
          isExpanded: false,
        ));
      }
      
      // If no coordinators found, build assistant coordinator nodes
      if (hierarchyNodes.isEmpty) {
        final assistantUnits = unitsByLevel['middleSchoolAssistantCoordinator'] ?? 
                              unitsByLevel['highSchoolAssistantCoordinator'] ?? 
                              unitsByLevel['assistantCoordinator'] ?? []; // Fallback for generic level
      
      for (final assistantUnit in assistantUnits) {
        final assistantUnitData = assistantUnit.data() as Map<String, dynamic>;
        final assistantId = assistantUnitData['managedBy'] as String?;
        
        if (assistantId == null) continue;
        
        // Get assistant coordinator user data
        final assistantUserDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(assistantId)
            .get();
        
        if (!assistantUserDoc.exists) continue;
        
        final assistantUserData = assistantUserDoc.data()!;
        
        // Find mentors under this assistant coordinator
        final mentorUnitsQuery = await FirebaseFirestore.instance
            .collection('organizationalUnits')
            .where('parentUnit', isEqualTo: assistantUnit.reference)
            .where('level', whereIn: ['middleSchoolMentor', 'highSchoolMentor'])
            .where('status', isEqualTo: 'active')
            .get();
        
        final mentorChildren = <HierarchyNode>[];
        
        for (final mentorUnit in mentorUnitsQuery.docs) {
          final mentorUnitData = mentorUnit.data();
          final mentorId = mentorUnitData['managedBy'] as String?;
          
          if (mentorId == null) continue;
          
          // Get mentor user data
          final mentorUserDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(mentorId)
              .get();
          
          if (!mentorUserDoc.exists) continue;
          
          final mentorUserData = mentorUserDoc.data()!;
          
          // Get join date from managerChangedAt
          DateTime? joinDate;
          final managerChangedAt = mentorUnitData['managerChangedAt'];
          if (managerChangedAt != null) {
            joinDate = (managerChangedAt as Timestamp).toDate();
          }
          
          final firstName = mentorUserData['firstName'] as String? ?? '';
          final lastName = mentorUserData['lastName'] as String? ?? '';
          final fullName = '$firstName $lastName'.trim();
          
          mentorChildren.add(HierarchyNode(
            id: mentorId,
            name: fullName,
            email: mentorUserData['email'] as String? ?? '',
            role: mentorUserData['role'] ?? 'mentor',
            city: mentorUnitData['city'] as String? ?? '',
            province: mentorUnitData['province'] as String? ?? '',
            gender: mentorUnitData['gender'] as String? ?? '',
            status: mentorUnitData['status'] as String? ?? 'active',
            className: mentorUnitData['class'] as String?,
            joinDate: joinDate,
            isMentor: true,
            children: [],
          ));
        }
        
        // Create assistant coordinator node
        final firstName = assistantUserData['firstName'] as String? ?? '';
        final lastName = assistantUserData['lastName'] as String? ?? '';
        final fullName = '$firstName $lastName'.trim();
        
        hierarchyNodes.add(HierarchyNode(
          id: assistantId,
          name: fullName,
          email: assistantUserData['email'] as String? ?? '',
          role: assistantUserData['role'] ?? 'assistantCoordinator',
          city: assistantUserData['city'] as String? ?? '',
          province: assistantUserData['province'] as String? ?? '',
          gender: assistantUserData['gender'] as String? ?? '',
          status: 'active',
          className: null,
          joinDate: null,
          isMentor: false,
          children: mentorChildren,
          isExpanded: false,
        ));
      }
      
      // If no assistant coordinators, look for direct mentors
      if (hierarchyNodes.isEmpty) {
        final mentorUnits = unitsByLevel['middleSchoolMentor'] ?? 
                           unitsByLevel['highSchoolMentor'] ?? [];
        
        for (final mentorUnit in mentorUnits) {
          final mentorUnitData = mentorUnit.data() as Map<String, dynamic>;
          final mentorId = mentorUnitData['managedBy'] as String?;
          
          if (mentorId == null) continue;
          
          // Get mentor user data
          final mentorUserDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(mentorId)
              .get();
          
          if (!mentorUserDoc.exists) continue;
          
          final mentorUserData = mentorUserDoc.data()!;
          
          // Get join date from managerChangedAt
          DateTime? joinDate;
          final managerChangedAt = mentorUnitData['managerChangedAt'];
          if (managerChangedAt != null) {
            joinDate = (managerChangedAt as Timestamp).toDate();
          }
          
          final firstName = mentorUserData['firstName'] as String? ?? '';
          final lastName = mentorUserData['lastName'] as String? ?? '';
          final fullName = '$firstName $lastName'.trim();
          
          hierarchyNodes.add(HierarchyNode(
            id: mentorId,
            name: fullName,
            email: mentorUserData['email'] as String? ?? '',
            role: mentorUserData['role'] ?? 'mentor',
            city: mentorUnitData['city'] as String? ?? '',
            province: mentorUnitData['province'] as String? ?? '',
            gender: mentorUnitData['gender'] as String? ?? '',
            status: mentorUnitData['status'] as String? ?? 'active',
            className: mentorUnitData['class'] as String?,
            joinDate: joinDate,
            isMentor: true,
            children: [],
          ));
        }
      }
      }
      
      _hierarchyNodes = hierarchyNodes;
      
    } catch (e) {
      _hierarchyNodes = [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text(
          'Mentors Management',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            HapticFeedback.lightImpact();
            context.pop();
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () {
              HapticFeedback.mediumImpact();
              _refreshData();
            },
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF667eea), Color(0xFF764ba2)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return _buildContent();
            },
          ),
        ),
      ),
    );
  }

  // 🎨 Build content based on state
  Widget _buildContent() {
    if (_isLoading) {
      return _buildLoadingState();
    }
    
    if (!_isAuthorized) {
      return _buildUnauthorizedState();
    }
    
    return _buildHierarchicalView();
  }

  // ⏳ Loading state
  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Colors.white),
          SizedBox(height: 16),
          Text(
            'Loading...',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
                  ),
          ),
        ],
      ),
    );
  }

  // 🚫 Unauthorized access state
  Widget _buildUnauthorizedState() {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(32),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.red.withOpacity(0.3)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.block,
              color: Colors.red.shade300,
              size: 64,
            ),
            const SizedBox(height: 16),
            const Text(
              'Access Denied',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'You don\'t have permission to access Mentors Management.\n\nOnly coordinators and administrators can access this feature.',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 16,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                HapticFeedback.lightImpact();
                context.pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.withOpacity(0.8),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.arrow_back, size: 18),
                  SizedBox(width: 6),
                  Text('Go Back'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 🌳 Build hierarchical view
  Widget _buildHierarchicalView() {
    if (_hierarchyNodes.isEmpty) {
      return _buildEmptyState();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // Responsive padding based on screen width
        final horizontalPadding = constraints.maxWidth > 600 ? 24.0 : 16.0;
        
        return ListView.builder(
          padding: EdgeInsets.symmetric(
            horizontal: horizontalPadding,
            vertical: 16,
          ),
          itemCount: _hierarchyNodes.length,
          itemBuilder: (context, index) {
            return _buildHierarchyCard(_hierarchyNodes[index]);
          },
        );
      },
    );
  }

  // 📭 Empty state
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.school_outlined,
            color: Colors.white.withOpacity(0.6),
            size: 80,
          ),
          const SizedBox(height: 16),
          const Text(
            'No Mentors Found',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'No mentors are currently assigned to your supervision.',
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 16,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // 🎨 Build hierarchy card (coordinator or mentor)
  Widget _buildHierarchyCard(HierarchyNode node) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: Column(
              children: [
                // Main card header
                _buildNodeHeader(node),
                
                // Expanded children (if any)
                if (node.isExpanded && node.children.isNotEmpty)
                  ...node.children.map((child) {
                    // If child has children (assistant coordinator), render as nested hierarchy
                    if (child.children.isNotEmpty) {
                      return _buildNestedHierarchyCard(child, 1); // Level 1 indentation
                    }
                    // Otherwise render as mentor card with indentation
                    return _buildMentorCard(child, 1); // Level 1 indentation
                  }),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 🎨 Build node header
  Widget _buildNodeHeader(HierarchyNode node) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _toggleNode(node),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Role icon
              Container(
                width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                  color: _getRoleColor(node.role).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _getRoleIcon(node.role),
                  color: _getRoleColor(node.role),
                  size: 28,
                ),
              ),
              
              const SizedBox(width: 16),
              
              // Name and role
              Expanded(
                        child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                    Text(
                      node.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _getRoleTitle(node.role),
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
              
              // Expand indicator
              if (node.children.isNotEmpty)
                Icon(
                  node.isExpanded ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_right,
                  color: Colors.white.withOpacity(0.8),
                  size: 24,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 🎨 Build nested hierarchy card (assistant coordinator with indentation)
  Widget _buildNestedHierarchyCard(HierarchyNode node, int level) {
    final indentation = level * 24.0; // 24px per level
    
    return Container(
      margin: EdgeInsets.fromLTRB(
        indentation.clamp(16.0, 32.0), // Max 32px indentation for mobile
        8, 
        16, 
        8
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(
          colors: [
            _getRoleColor(node.role).withOpacity(0.15),
            _getRoleColor(node.role).withOpacity(0.05),
          ],
        ),
        border: Border.all(
          color: _getRoleColor(node.role).withOpacity(0.3),
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          // Assistant coordinator header
          InkWell(
            onTap: () => _toggleNode(node),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // Connection line indicator
                  Container(
                    width: 3,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _getRoleColor(node.role),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 12),
                  
                  // Role icon
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _getRoleColor(node.role).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _getRoleIcon(node.role),
                      color: _getRoleColor(node.role),
                      size: 20,
                    ),
                  ),
                  
                  const SizedBox(width: 12),
                  
                  // Name and role
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          node.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _getRoleTitle(node.role),
                          style: TextStyle(
                            color: _getRoleColor(node.role),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Expand/collapse icon
                  Icon(
                    node.isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: Colors.white.withOpacity(0.7),
                    size: 24,
                  ),
                ],
              ),
            ),
          ),
          
          // Expanded mentors
          if (node.isExpanded && node.children.isNotEmpty)
            ...node.children.map((mentor) => _buildMentorCard(mentor, level + 1)),
        ],
      ),
    );
  }

  // 🎨 Build mentor card with indentation (collapsible)
  Widget _buildMentorCard(HierarchyNode mentor, int level) {
    final indentation = level * 24.0; // 24px per level
    
    return Container(
      margin: EdgeInsets.fromLTRB(
        (indentation + 16).clamp(16.0, 48.0), // Max 48px indentation for mobile
        4, 
        16, 
        8
      ),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08), // Neutral background
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _getRoleColor(mentor.role).withOpacity(0.4), // Role accent border
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          // Mentor header (clickable + long press for edit)
          GestureDetector(
            onTap: () => _toggleNode(mentor),
            onLongPress: () => _showEditMentorDialog(mentor),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  // Connection line
                  Container(
                    width: 3,
                    height: 30,
                    decoration: BoxDecoration(
                      color: _getRoleColor(mentor.role),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 12),
                  
                  // Mentor icon
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: _getRoleColor(mentor.role).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(
                      _getRoleIcon(mentor.role),
                      color: _getRoleColor(mentor.role),
                      size: 18,
                    ),
                  ),
                  
                  const SizedBox(width: 12),
                  
                  // Mentor name and role
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          mentor.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _getRoleTitle(mentor.role),
                          style: TextStyle(
                            color: _getRoleColor(mentor.role),
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(width: 8),
                  
                  // Expand/collapse icon
                  Icon(
                    mentor.isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: Colors.white.withOpacity(0.7),
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
          
          // Expanded mentor details
          if (mentor.isExpanded) ...[
            const Divider(
              color: Colors.white24,
              height: 1,
              thickness: 1,
            ),
            Container(
              padding: const EdgeInsets.all(16),
              child: Stack(
                children: [
                  // Mentor details
                  _buildMentorDetails(mentor),
                  
                  // Status badge in bottom right corner
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: mentor.status == 'active' 
                          ? const Color(0xFF38A169).withOpacity(0.15) // Green 500
                          : const Color(0xFFE53E3E).withOpacity(0.15), // Red 500
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: mentor.status == 'active' 
                            ? const Color(0xFF38A169) // Green 500
                            : const Color(0xFFE53E3E), // Red 500
                          width: 1,
                        ),
                      ),
                      child: Text(
                        mentor.status == 'active' ? 'ACTIVE' : 'INACTIVE',
                        style: TextStyle(
                          color: mentor.status == 'active' 
                            ? const Color(0xFF38A169) // Green 500
                            : const Color(0xFFE53E3E), // Red 500
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // 🎨 Build mentor details
  Widget _buildMentorDetails(HierarchyNode mentor) {
    return Column(
      children: [
        // Email
        _buildTextDetailRow('Email:', mentor.email),
        
        // Location
        _buildTextDetailRow('Location:', '${mentor.city}, ${mentor.province}'),
        
        // Gender
        _buildTextDetailRow('Gender:', mentor.gender),
        
        if (mentor.className != null)
          _buildTextDetailRow('Class:', mentor.className!),
        
        if (mentor.joinDate != null)
          _buildTextDetailRow('Since:', _formatDate(mentor.joinDate!)),
      ],
    );
  }

  // 🎨 Build text detail row (clean table-like)
  Widget _buildTextDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Fixed width label (like a table column)
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          
          // Value with proper wrapping
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w400,
                height: 1.3,
              ),
              softWrap: true,
            ),
          ),
        ],
      ),
    );
  }

  // 🎨 Build detail row (icon version - kept for compatibility)
  Widget _buildDetailRow(IconData icon, String text, Color color) {
    return Row(
      children: [
        Icon(
          icon,
          color: color,
          size: 16,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }

  // 🎨 Build child card (mentor details) - OLD VERSION
  Widget _buildChildCard(HierarchyNode child) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
          width: 1,
        ),
      ),
            child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
              children: [

          // Mentor header
          Row(
                      children: [
              Icon(
                Icons.school,
                color: Colors.orange,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                child.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              _buildStatusBadge(child.status),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // Mentor details
          _buildDetailRow(Icons.email, child.email, Colors.blue),
          const SizedBox(height: 6),
          _buildDetailRow(Icons.location_on, '${child.city}, ${child.province}', Colors.red),
          const SizedBox(height: 6),
          _buildDetailRow(
            child.gender.toLowerCase() == 'male' ? Icons.male : Icons.female,
            child.gender,
            child.gender.toLowerCase() == 'male' ? Colors.blue : Colors.pink,
          ),
          if (child.className != null) ...[
            const SizedBox(height: 6),
            _buildDetailRow(Icons.class_, 'Class: ${child.className}', Colors.purple),
          ],
          if (child.joinDate != null) ...[
            const SizedBox(height: 6),
            _buildDetailRow(Icons.calendar_today, 'Since: ${_formatDate(child.joinDate!)}', Colors.green),
          ],
                              ],
                            ),
                          );
  }



  // 🎨 Build status badge
  Widget _buildStatusBadge(String status) {
    final isActive = status.toLowerCase() == 'active';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
        color: (isActive ? Colors.green : Colors.red).withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isActive ? Colors.green : Colors.red,
          width: 1,
        ),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: isActive ? Colors.green : Colors.red,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  // 🎮 Toggle node expansion
  void _toggleNode(HierarchyNode node) {
    // Allow expansion for mentors (to show details) or nodes with children
    if (node.children.isEmpty && !node.isMentor) return;
    
    setState(() {
      node.isExpanded = !node.isExpanded;
      if (node.isExpanded) {
        _expandedNodes.add(node.id);
      } else {
        _expandedNodes.remove(node.id);
        // Reset all children to collapsed state when parent is collapsed
        _resetChildrenExpansion(node);
      }
    });
    
    HapticFeedback.lightImpact();
  }

  // 🔄 Reset all children to collapsed state recursively
  void _resetChildrenExpansion(HierarchyNode node) {
    for (final child in node.children) {
      if (child.isExpanded) {
        child.isExpanded = false;
        _expandedNodes.remove(child.id);
        // Recursively reset grandchildren too
        _resetChildrenExpansion(child);
      }
    }
  }

  // 🎨 Get role color (WCAG compliant)
  Color _getRoleColor(String role) {
    switch (role) {
      case 'director': return const Color(0xFFE53E3E); // Red 500
      case 'middleSchoolCoordinator':
      case 'highSchoolCoordinator': return const Color(0xFF3182CE); // Blue 600
      case 'middleSchoolAssistantCoordinator':
      case 'highSchoolAssistantCoordinator': return const Color(0xFF0BC5EA); // Cyan 400
      case 'middleSchoolMentor':
      case 'highSchoolMentor': return const Color(0xFFED8936); // Orange 400
      default: return const Color(0xFF718096); // Gray 500
    }
  }

  // 🎨 Get role icon
  IconData _getRoleIcon(String role) {
    switch (role) {
      case 'director': return Icons.business_center;
      case 'middleSchoolCoordinator':
      case 'highSchoolCoordinator': return Icons.manage_accounts;
      case 'middleSchoolAssistantCoordinator':
      case 'highSchoolAssistantCoordinator': return Icons.support_agent;
      case 'middleSchoolMentor':
      case 'highSchoolMentor': return Icons.school;
      default: return Icons.person;
    }
  }

  // 🎨 Get role title
  String _getRoleTitle(String role) {
    switch (role) {
      case 'director': return 'Director';
      case 'middleSchoolCoordinator': return 'Middle School Coordinator';
      case 'highSchoolCoordinator': return 'High School Coordinator';
      case 'middleSchoolAssistantCoordinator': return 'Middle School Assistant Coordinator';
      case 'highSchoolAssistantCoordinator': return 'High School Assistant Coordinator';
      case 'middleSchoolMentor': return 'Middle School Mentor';
      case 'highSchoolMentor': return 'High School Mentor';
      default: return role;
    }
  }

  // 📅 Format date
  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
} 