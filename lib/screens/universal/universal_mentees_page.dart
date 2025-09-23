import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'dart:ui';
import 'dart:math';

// Location dropdown cascade imports
import '../../widgets/location_picker/location_dropdown_cascade.dart';

// 🌍 Google Places Location System - Much simpler!

// 🎓 Virtual Mentee Data Structure
class VirtualMentee {
  final String id;
  final String memberId;
  final String virtualUserId;
  final String firstName;
  final String lastName;
  final String gender;
  final String country;
  final String city;
  final String province;
  final String gradeLevel;
  final String school;
  final String assignedMentorId;
  final DateTime assignedDate;
  final DateTime joinDate;
  final String status;
  final String createdBy;
  final DateTime createdAt;
  bool isExpanded;

  VirtualMentee({
    required this.id,
    required this.memberId,
    required this.virtualUserId,
    required this.firstName,
    required this.lastName,
    required this.gender,
    required this.country,
    required this.city,
    required this.province,
    required this.gradeLevel,
    required this.school,
    required this.assignedMentorId,
    required this.assignedDate,
    required this.joinDate,
    required this.status,
    required this.createdBy,
    required this.createdAt,
    this.isExpanded = false,
  });

  String get fullName => '$firstName $lastName'.trim();
}

// 🌳 Hierarchy Node Data Structure (extended for mentees)
class HierarchyNode {
  final String id;
  final String name;
  final String email;
  final String role;
  final String country;
  final String city;
  final String province;
  final String gender;
  final String status;
  String? className;
  final DateTime? joinDate;
  final bool isMentor;
  List<HierarchyNode> children;
  List<VirtualMentee> mentees; // 🆕 Add mentees list
  bool isExpanded;

  HierarchyNode({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.country,
    required this.city,
    required this.province,
    required this.gender,
    required this.status,
    this.className,
    this.joinDate,
    required this.isMentor,
    this.children = const [],
    this.mentees = const [], // 🆕 Initialize mentees list
    this.isExpanded = false,
  });
}

class UniversalMenteesPage extends StatefulWidget {
  const UniversalMenteesPage({super.key});

  @override
  State<UniversalMenteesPage> createState() => _UniversalMenteesPageState();
}

class _UniversalMenteesPageState extends State<UniversalMenteesPage> {
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
    // Reset mentees expansion too
    for (final mentee in node.mentees) {
      mentee.isExpanded = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text(
          'Mentees Management',
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
      floatingActionButton: _isAuthorized && !_isLoading
          ? FloatingActionButton(
              onPressed: _showAddMenteeBottomSheet,
              backgroundColor: const Color(0xFF38A169),
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
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
              'You don\'t have permission to access Mentees Management.\n\nOnly coordinators and administrators can access this feature.',
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
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
            Icons.groups_outlined,
            color: Colors.white.withOpacity(0.6),
            size: 80,
          ),
          const SizedBox(height: 16),
          const Text(
            'No Mentees Found',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'No mentees are currently assigned to your supervision.',
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

  // 🔄 Show add mentee bottom sheet
  Future<void> _showAddMenteeBottomSheet() async {
    HapticFeedback.mediumImpact();

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildAddMenteeBottomSheet(),
    );
  }

  // 🎨 Build add mentee bottom sheet
  Widget _buildAddMenteeBottomSheet() {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Color(0xFF2D3748),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF38A169).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.person_add,
                    color: Color(0xFF38A169),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Add New Mentee',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(
                    Icons.close,
                    color: Colors.white.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),

          // Form content
          Expanded(
            child: _AddMenteeForm(
              availableGrades: _getAvailableGradesByRole(_currentRole ?? ''),
              availableMentors: _getAvailableMentors(),
              currentRole: _currentRole ?? '',
              onSubmit: _handleFormSubmit,
              buildSectionHeader: _buildSectionHeader,
              buildTextField: _buildTextField,
              buildDropdown: _buildDropdown,
            ),
          ),
        ],
      ),
    );
  }

  // 🎨 Build section header
  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  // 🎨 Build text field
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    bool enabled = true,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.8),
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          enabled: enabled,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
            prefixIcon: Icon(icon, color: Colors.white.withOpacity(0.7)),
            filled: true,
            fillColor: enabled
                ? Colors.white.withOpacity(0.1)
                : Colors.white.withOpacity(0.05),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: Color(0xFF38A169),
                width: 2,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // 🎨 Build dropdown
  Widget _buildDropdown<T>({
    required T? value,
    required String label,
    required IconData icon,
    String? hint,
    required List<DropdownMenuItem<T>> items,
    void Function(T?)? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.8),
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(icon, color: Colors.white.withOpacity(0.7)),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButton<T>(
                  value: value,
                  hint: hint != null
                      ? Text(
                          hint,
                          style:
                              TextStyle(color: Colors.white.withOpacity(0.5)),
                        )
                      : null,
                  dropdownColor: const Color(0xFF2D3748),
                  underline: const SizedBox(),
                  style: const TextStyle(color: Colors.white),
                  isExpanded: true,
                  menuMaxHeight: 300, // Limit dropdown height to 300 pixels
                  items: items,
                  onChanged: onChanged,
                ),
              ),
            ],
          ),
        ),
      ],
    );
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
          } else if (roleItem is Map<String, dynamic> &&
              roleItem['role'] != null) {
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
          currentUserUnitPath =
              'organizationalUnits/${userManagedUnits.docs.first.id}';
        } else {
          _hierarchyNodes = [];
          return;
        }
      }

      // Find subordinate units (parentUnit = current user's unit)
      final subordinateUnitsQuery = await FirebaseFirestore.instance
          .collection('organizationalUnits')
          .where('parentUnit',
              isEqualTo: FirebaseFirestore.instance.doc(currentUserUnitPath))
          .where('status', isEqualTo: 'active')
          .get();

      await _buildHierarchyFromUnits(subordinateUnitsQuery);
    } catch (e) {
      _hierarchyNodes = [];
    }
  }

  // 🆕 Load mentees for a specific mentor
  Future<List<VirtualMentee>> _loadMenteesForMentor(String mentorId) async {
    try {
      // Simplified query to avoid index requirement
      final menteesQuery = await FirebaseFirestore.instance
          .collection('virtualMentees')
          .where('assignedMentorId', isEqualTo: mentorId)
          .get();

      final mentees = <VirtualMentee>[];

      for (final menteeDoc in menteesQuery.docs) {
        final menteeData = menteeDoc.data();

        // Client-side filtering for active status
        if (menteeData['status'] != 'active') continue;

        mentees.add(VirtualMentee(
          id: menteeDoc.id,
          memberId: menteeData['memberId'] as String? ?? '',
          virtualUserId: menteeData['virtualUserId'] as String? ?? '',
          firstName: menteeData['firstName'] as String? ?? '',
          lastName: menteeData['lastName'] as String? ?? '',
          gender: menteeData['gender'] as String? ?? '',
          country: menteeData['country'] as String? ??
              'Canada', // Default to Canada for existing data
          city: menteeData['city'] as String? ?? '',
          province: menteeData['province'] as String? ?? '',
          gradeLevel: menteeData['gradeLevel'] as String? ?? '',
          school: menteeData['school'] as String? ?? '',
          assignedMentorId: menteeData['assignedMentorId'] as String? ?? '',
          assignedDate: (menteeData['assignedDate'] as Timestamp?)?.toDate() ??
              DateTime.now(),
          joinDate: (menteeData['joinDate'] as Timestamp?)?.toDate() ??
              DateTime.now(),
          status: menteeData['status'] as String? ?? 'active',
          createdBy: menteeData['createdBy'] as String? ?? '',
          createdAt: (menteeData['createdAt'] as Timestamp?)?.toDate() ??
              DateTime.now(),
        ));
      }

      // Sort by first name client-side
      mentees.sort((a, b) => a.firstName.compareTo(b.firstName));

      return mentees;
    } catch (e) {
      return [];
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
        final coordinatorUnitData =
            coordinatorUnit.data() as Map<String, dynamic>;
        final coordinatorId = coordinatorUnitData['managedBy'] as String?;

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
        if (!coordinatorRole.contains('middleSchool') &&
            !coordinatorRole.contains('highSchool')) {
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
          final subLevel = subUnitData['level'] as String? ?? '';
          final subManagerId = subUnitData['managedBy'] as String?;

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
          if (subLevel.contains('assistant') ||
              subLevel == 'assistantCoordinator') {
            // Find mentors under this assistant
            final mentorUnitsQuery = await FirebaseFirestore.instance
                .collection('organizationalUnits')
                .where('parentUnit', isEqualTo: subUnit.reference)
                .where('status', isEqualTo: 'active')
                .get();

            for (final mentorUnit in mentorUnitsQuery.docs) {
              final mentorUnitData = mentorUnit.data();
              final mentorId = mentorUnitData['managedBy'] as String?;

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

              // 🆕 Load mentees for this mentor
              final mentees = await _loadMenteesForMentor(mentorId);

              final mentorNode = HierarchyNode(
                id: mentorId,
                name: fullName,
                email: mentorUserData['email'] as String? ?? '',
                role: mentorUserData['role'] ?? 'mentor',
                country: mentorUnitData['country'] as String? ?? 'Canada',
                city: mentorUnitData['city'] as String? ?? '',
                province: mentorUnitData['province'] as String? ?? '',
                gender: mentorUnitData['gender'] as String? ?? '',
                status: mentorUnitData['status'] as String? ?? 'active',
                className: mentorUnitData['class'] as String?,
                joinDate: joinDate,
                isMentor: true,
                children: [],
                mentees: mentees, // 🆕 Assign mentees
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
            country: subUserData['country'] as String? ?? 'Canada',
            city: subUserData['city'] as String? ?? '',
            province: subUserData['province'] as String? ?? '',
            gender: subUserData['gender'] as String? ?? '',
            status: 'active',
            className: null,
            joinDate: null,
            isMentor:
                subLevel.contains('mentor') || subLevel.contains('Mentor'),
            children: mentorChildren,
            mentees: [], // Assistant coordinators don't have direct mentees
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
          country: coordinatorUserData['country'] as String? ?? 'Canada',
          city: coordinatorUserData['city'] as String? ?? '',
          province: coordinatorUserData['province'] as String? ?? '',
          gender: coordinatorUserData['gender'] as String? ?? '',
          status: 'active',
          className: null,
          joinDate: null,
          isMentor: false,
          children: coordinatorChildren,
          mentees: [], // Coordinators don't have direct mentees
          isExpanded: false,
        ));
      }

      // If no coordinators found, build assistant coordinator nodes
      if (hierarchyNodes.isEmpty) {
        final assistantUnits =
            unitsByLevel['middleSchoolAssistantCoordinator'] ??
                unitsByLevel['highSchoolAssistantCoordinator'] ??
                unitsByLevel['assistantCoordinator'] ??
                []; // Fallback for generic level

        for (final assistantUnit in assistantUnits) {
          final assistantUnitData =
              assistantUnit.data() as Map<String, dynamic>;
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
              .where('level',
                  whereIn: ['middleSchoolMentor', 'highSchoolMentor'])
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

            // 🆕 Load mentees for this mentor
            final mentees = await _loadMenteesForMentor(mentorId);

            mentorChildren.add(HierarchyNode(
              id: mentorId,
              name: fullName,
              email: mentorUserData['email'] as String? ?? '',
              role: mentorUserData['role'] ?? 'mentor',
              country: mentorUnitData['country'] as String? ?? 'Canada',
              city: mentorUnitData['city'] as String? ?? '',
              province: mentorUnitData['province'] as String? ?? '',
              gender: mentorUnitData['gender'] as String? ?? '',
              status: mentorUnitData['status'] as String? ?? 'active',
              className: mentorUnitData['class'] as String?,
              joinDate: joinDate,
              isMentor: true,
              children: [],
              mentees: mentees, // 🆕 Assign mentees
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
            country: assistantUserData['country'] as String? ?? 'Canada',
            city: assistantUserData['city'] as String? ?? '',
            province: assistantUserData['province'] as String? ?? '',
            gender: assistantUserData['gender'] as String? ?? '',
            status: 'active',
            className: null,
            joinDate: null,
            isMentor: false,
            children: mentorChildren,
            mentees: [], // Assistant coordinators don't have direct mentees
            isExpanded: false,
          ));
        }

        // If no assistant coordinators, look for direct mentors
        if (hierarchyNodes.isEmpty) {
          final mentorUnits = unitsByLevel['middleSchoolMentor'] ??
              unitsByLevel['highSchoolMentor'] ??
              [];

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

            // 🆕 Load mentees for this mentor
            final mentees = await _loadMenteesForMentor(mentorId);

            hierarchyNodes.add(HierarchyNode(
              id: mentorId,
              name: fullName,
              email: mentorUserData['email'] as String? ?? '',
              role: mentorUserData['role'] ?? 'mentor',
              country: mentorUnitData['country'] as String? ?? 'Canada',
              city: mentorUnitData['city'] as String? ?? '',
              province: mentorUnitData['province'] as String? ?? '',
              gender: mentorUnitData['gender'] as String? ?? '',
              status: mentorUnitData['status'] as String? ?? 'active',
              className: mentorUnitData['class'] as String?,
              joinDate: joinDate,
              isMentor: true,
              children: [],
              mentees: mentees, // 🆕 Assign mentees
            ));
          }
        }
      }

      _hierarchyNodes = hierarchyNodes;
    } catch (e) {
      _hierarchyNodes = [];
    }
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
                      return _buildNestedHierarchyCard(
                          child, 1); // Level 1 indentation
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
                  node.isExpanded
                      ? Icons.keyboard_arrow_down
                      : Icons.keyboard_arrow_right,
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
          8),
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
            ...node.children
                .map((mentor) => _buildMentorCard(mentor, level + 1)),
        ],
      ),
    );
  }

  // 🎨 Build mentor card with mentees (collapsible)
  Widget _buildMentorCard(HierarchyNode mentor, int level) {
    final indentation = level * 24.0; // 24px per level
    final menteeCount = mentor.mentees.length;

    return Container(
      margin: EdgeInsets.fromLTRB(
          (indentation + 16)
              .clamp(16.0, 48.0), // Max 48px indentation for mobile
          4,
          16,
          8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08), // Neutral background
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color:
              _getRoleColor(mentor.role).withOpacity(0.4), // Role accent border
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          // Mentor header (clickable)
          InkWell(
            onTap: () => _toggleNode(mentor),
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

                  // 🆕 Mentee count badge
                  if (menteeCount > 0)
                    Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color:
                            const Color(0xFF38A169).withOpacity(0.15), // Green
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFF38A169),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        '$menteeCount mentee${menteeCount != 1 ? 's' : ''}',
                        style: const TextStyle(
                          color: Color(0xFF38A169),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
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

          // 🆕 Expanded mentees list
          if (mentor.isExpanded) ...[
            const Divider(
              color: Colors.white24,
              height: 1,
              thickness: 1,
            ),
            if (menteeCount == 0)
              // No mentees state
              Container(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Icon(
                      Icons.person_off_outlined,
                      color: Colors.white.withOpacity(0.5),
                      size: 48,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No mentees assigned',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Use the + button to add mentees',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.5),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              )
            else
              // Mentees list
              ...mentor.mentees
                  .map((mentee) => _buildMenteeCard(mentee, level + 1)),
          ],
        ],
      ),
    );
  }

  // 🎨 Build mentee card (collapsible with details)
  Widget _buildMenteeCard(VirtualMentee mentee, int level) {
    final indentation = level * 24.0; // 24px per level

    return Container(
      margin: EdgeInsets.fromLTRB(
          (indentation + 16)
              .clamp(24.0, 56.0), // Deeper indentation for mentees
          4,
          16,
          8),
      decoration: BoxDecoration(
        color:
            const Color(0xFF38A169).withOpacity(0.08), // Green tint for mentees
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color:
              const Color(0xFF38A169).withOpacity(0.4), // Green accent border
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          // Mentee header (clickable + long press for edit)
          GestureDetector(
            onTap: () => _toggleMentee(mentee),
            onLongPress: () => _showEditMenteeDialog(mentee),
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
                      color: const Color(0xFF38A169), // Green for mentees
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Mentee icon
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF38A169).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(
                      Icons.person,
                      color: Color(0xFF38A169),
                      size: 18,
                    ),
                  ),

                  const SizedBox(width: 12),

                  // Mentee name and member ID
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          mentee.fullName,
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
                          mentee.gradeLevel,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 8),

                  // Expand/collapse icon
                  Icon(
                    mentee.isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: Colors.white.withOpacity(0.7),
                    size: 20,
                  ),
                ],
              ),
            ),
          ),

          // Expanded mentee details
          if (mentee.isExpanded) ...[
            const Divider(
              color: Colors.white24,
              height: 1,
              thickness: 1,
            ),
            Container(
              padding: const EdgeInsets.all(16),
              child: Stack(
                children: [
                  // Mentee details
                  _buildMenteeDetails(mentee),

                  // Status badge in bottom right corner
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: mentee.status == 'active'
                            ? const Color(0xFF38A169)
                                .withOpacity(0.15) // Green 500
                            : const Color(0xFFE53E3E)
                                .withOpacity(0.15), // Red 500
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: mentee.status == 'active'
                              ? const Color(0xFF38A169) // Green 500
                              : const Color(0xFFE53E3E), // Red 500
                          width: 1,
                        ),
                      ),
                      child: Text(
                        mentee.status == 'active' ? 'ACTIVE' : 'INACTIVE',
                        style: TextStyle(
                          color: mentee.status == 'active'
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

  // 🎨 Build mentee details
  Widget _buildMenteeDetails(VirtualMentee mentee) {
    return Column(
      children: [
        // Location (moved to top)
        _buildTextDetailRow('Location:',
            '${mentee.city}, ${mentee.province}, ${mentee.country}'),

        // Gender (moved down)
        _buildTextDetailRow('Gender:', mentee.gender),

        // School (removed duplicate Grade)
        _buildTextDetailRow('School:', mentee.school),

        // Join Date
        _buildTextDetailRow('Joined:', _formatDate(mentee.joinDate)),
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

  // 🎮 Toggle mentee expansion
  void _toggleMentee(VirtualMentee mentee) {
    setState(() {
      mentee.isExpanded = !mentee.isExpanded;
    });

    HapticFeedback.lightImpact();
  }

  // 🆕 Show edit mentee dialog (placeholder)
  Future<void> _showEditMenteeDialog(VirtualMentee mentee) async {
    HapticFeedback.mediumImpact();

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _EditMenteeBottomSheet(
        mentee: mentee,
        onUpdate: _updateMentee,
        onDelete: _deleteMentee,
      ),
    );
  }

  // 🔄 Update mentee
  Future<void> _updateMentee(
      VirtualMentee mentee, Map<String, dynamic> updates) async {
    try {
      await FirebaseFirestore.instance
          .collection('virtualMentees')
          .doc(mentee.id)
          .update(updates);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 20),
                const SizedBox(width: 12),
                Text('${mentee.firstName} updated successfully!'),
              ],
            ),
            backgroundColor: const Color(0xFF38A169),
            duration: const Duration(seconds: 2),
          ),
        );
        _refreshData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white, size: 20),
                const SizedBox(width: 12),
                Text('Failed to update: ${e.toString()}'),
              ],
            ),
            backgroundColor: const Color(0xFFE53E3E),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  // 🗑️ Delete mentee
  Future<void> _deleteMentee(VirtualMentee mentee) async {
    try {
      await FirebaseFirestore.instance
          .collection('virtualMentees')
          .doc(mentee.id)
          .delete();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 20),
                const SizedBox(width: 12),
                Text('${mentee.firstName} deleted successfully!'),
              ],
            ),
            backgroundColor: const Color(0xFF38A169),
            duration: const Duration(seconds: 2),
          ),
        );
        _refreshData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white, size: 20),
                const SizedBox(width: 12),
                Text('Failed to delete: ${e.toString()}'),
              ],
            ),
            backgroundColor: const Color(0xFFE53E3E),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  // 🎮 Toggle node expansion
  void _toggleNode(HierarchyNode node) {
    // Allow expansion for mentors (to show mentees) or nodes with children
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
    // Reset mentees expansion too
    for (final mentee in node.mentees) {
      mentee.isExpanded = false;
    }
  }

  // 🎨 Get role color (WCAG compliant)
  Color _getRoleColor(String role) {
    switch (role) {
      case 'director':
        return const Color(0xFFE53E3E); // Red 500
      case 'middleSchoolCoordinator':
      case 'highSchoolCoordinator':
        return const Color(0xFF3182CE); // Blue 600
      case 'middleSchoolAssistantCoordinator':
      case 'highSchoolAssistantCoordinator':
        return const Color(0xFF0BC5EA); // Cyan 400
      case 'middleSchoolMentor':
      case 'highSchoolMentor':
        return const Color(0xFFED8936); // Orange 400
      default:
        return const Color(0xFF718096); // Gray 500
    }
  }

  // 🎨 Get role icon
  IconData _getRoleIcon(String role) {
    switch (role) {
      case 'director':
        return Icons.business_center;
      case 'middleSchoolCoordinator':
      case 'highSchoolCoordinator':
        return Icons.manage_accounts;
      case 'middleSchoolAssistantCoordinator':
      case 'highSchoolAssistantCoordinator':
        return Icons.support_agent;
      case 'middleSchoolMentor':
      case 'highSchoolMentor':
        return Icons.school;
      default:
        return Icons.person;
    }
  }

  // 🎨 Get role title
  String _getRoleTitle(String role) {
    switch (role) {
      case 'director':
        return 'Director';
      case 'middleSchoolCoordinator':
        return 'Middle School Coordinator';
      case 'highSchoolCoordinator':
        return 'High School Coordinator';
      case 'middleSchoolAssistantCoordinator':
        return 'Middle School Assistant Coordinator';
      case 'highSchoolAssistantCoordinator':
        return 'High School Assistant Coordinator';
      case 'middleSchoolMentor':
        return 'Middle School Mentor';
      case 'highSchoolMentor':
        return 'High School Mentor';
      default:
        return role;
    }
  }

  // 📅 Format date
  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  // 🎯 Handle form submission
  Future<void> _handleFormSubmit(Map<String, dynamic> formData) async {
    try {
      final success = await _createVirtualMentee(
        firstName: formData['firstName'],
        lastName: formData['lastName'],
        gender: formData['gender'],
        city: formData['city'],
        province: formData['province'],
        gradeLevel: formData['gradeLevel'],
        school: formData['school'],
        mentorId: formData['mentorId'],
      );

      if (success) {
        // Close bottom sheet and refresh data
        if (mounted) {
          Navigator.of(context).pop();
          _refreshData();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // 🎯 Get available grades by role
  List<String> _getAvailableGradesByRole(String role) {
    if (role.contains('middleSchool')) {
      return ['6th Grade', '7th Grade', '8th Grade'];
    } else if (role.contains('highSchool')) {
      return ['9th Grade', '10th Grade', '11th Grade', '12th Grade'];
    } else if (role == 'director') {
      return [
        '6th Grade',
        '7th Grade',
        '8th Grade',
        '9th Grade',
        '10th Grade',
        '11th Grade',
        '12th Grade'
      ];
    }
    return [];
  }

  // 👥 Get available mentors under current user's supervision
  List<HierarchyNode> _getAvailableMentors() {
    final mentors = <HierarchyNode>[];

    void collectMentors(HierarchyNode node) {
      if (node.isMentor) {
        mentors.add(node);
      }
      for (final child in node.children) {
        collectMentors(child);
      }
    }

    for (final node in _hierarchyNodes) {
      collectMentors(node);
    }

    return mentors;
  }

  // 💾 Create virtual mentee in Firestore
  Future<bool> _createVirtualMentee({
    required String firstName,
    required String lastName,
    required String gender,
    required String city,
    required String province,
    required String gradeLevel,
    required String school,
    required String mentorId,
  }) async {
    // Check if currentUserId is null
    if (_currentUserId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Authentication error: User ID not found'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return false;
    }

    try {
      // Generate unique IDs
      final virtualUserId = _generateUuid();
      final memberId = await _generateMemberId();

      final menteeData = {
        'memberId': memberId,
        'virtualUserId': virtualUserId,
        'firstName': firstName,
        'lastName': lastName,
        'gender': gender,
        'city': city,
        'province': province,
        'gradeLevel': gradeLevel,
        'school': school,
        'assignedMentorId': mentorId,
        'assignedDate': FieldValue.serverTimestamp(),
        'joinDate': FieldValue.serverTimestamp(),
        'status': 'active',
        'createdBy': _currentUserId,
        'createdAt': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance
          .collection('virtualMentees')
          .add(menteeData);

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Mentee "$firstName $lastName" added successfully!',
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

      return true;
    } catch (e) {
      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('Failed to create mentee: ${e.toString()}'),
                ),
              ],
            ),
            backgroundColor: const Color(0xFFE53E3E),
            duration: const Duration(seconds: 5),
          ),
        );
      }
      return false;
    }
  }

  // 🆔 Generate UUID (simple implementation)
  String _generateUuid() {
    final random = Random();
    const chars = '0123456789abcdef';
    return List.generate(32, (index) => chars[random.nextInt(chars.length)])
        .join();
  }

  // 🎫 Generate member ID with VM- prefix
  Future<String> _generateMemberId() async {
    try {
      // Get current year
      final year = DateTime.now().year;

      // Get count of existing virtual mentees this year
      final existingCount = await FirebaseFirestore.instance
          .collection('virtualMentees')
          .where('memberId', isGreaterThanOrEqualTo: 'VM-$year-')
          .where('memberId', isLessThan: 'VM-${year + 1}-')
          .get();

      final nextNumber = existingCount.docs.length + 1;
      return 'VM-$year-${nextNumber.toString().padLeft(6, '0')}';
    } catch (e) {
      // Fallback to simple random ID
      final random = Random();
      final randomId = random.nextInt(999999).toString().padLeft(6, '0');
      return 'VM-${DateTime.now().year}-$randomId';
    }
  }
}

// 📝 Add Mentee Form Widget
class _AddMenteeForm extends StatefulWidget {
  final List<String> availableGrades;
  final List<HierarchyNode> availableMentors;
  final String currentRole;
  final Future<void> Function(Map<String, dynamic>) onSubmit;
  final Widget Function(String) buildSectionHeader;
  final Widget Function({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType keyboardType,
    bool enabled,
  }) buildTextField;
  final Widget Function<T>({
    required T? value,
    required String label,
    required IconData icon,
    String? hint,
    required List<DropdownMenuItem<T>> items,
    void Function(T?)? onChanged,
  }) buildDropdown;

  const _AddMenteeForm({
    required this.availableGrades,
    required this.availableMentors,
    required this.currentRole,
    required this.onSubmit,
    required this.buildSectionHeader,
    required this.buildTextField,
    required this.buildDropdown,
  });

  @override
  State<_AddMenteeForm> createState() => _AddMenteeFormState();
}

class _AddMenteeFormState extends State<_AddMenteeForm> {
  // Form controllers
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();

  // Form state
  String _selectedGender = 'Male';
  Map<String, dynamic>? _selectedLocation; // Google Places location data
  String? _selectedGradeLevel;
  String? _selectedSchool;
  String? _selectedMentorId;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // No need to load anything - Google Places handles everything!
  }

  // 🚀 Google Places - No complex loading methods needed!

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Personal Information Section
          widget.buildSectionHeader('Personal Information'),
          const SizedBox(height: 16),

          // First Name & Last Name
          Row(
            children: [
              Expanded(
                child: widget.buildTextField(
                  controller: _firstNameController,
                  label: 'First Name',
                  hint: '',
                  icon: Icons.person,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: widget.buildTextField(
                  controller: _lastNameController,
                  label: 'Last Name',
                  hint: '',
                  icon: Icons.person_outline,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Gender (full width)
          widget.buildDropdown<String>(
            value: _selectedGender,
            label: 'Gender',
            icon: Icons.wc,
            items: ['Male', 'Female']
                .map((gender) =>
                    DropdownMenuItem(value: gender, child: Text(gender)))
                .toList(),
            onChanged: (value) {
              setState(() {
                _selectedGender = value!;
              });
            },
          ),

          const SizedBox(height: 24),

          // Location Information Section
          widget.buildSectionHeader('Location Information'),
          const SizedBox(height: 16),

          // 🚀 Location Dropdown Cascade - Country → Province → City
          LocationDropdownCascade(
            onLocationSelected: (locationData) {
              setState(() {
                _selectedLocation = locationData;
              });
              print('📍 Selected location: $locationData');
            },
          ),

          const SizedBox(height: 24),

          // Academic Information Section
          widget.buildSectionHeader('Academic Information'),
          const SizedBox(height: 16),

          // Grade Level
          widget.buildDropdown<String>(
            value: _selectedGradeLevel,
            label: 'Grade Level',
            icon: Icons.school,
            hint: 'Select grade level',
            items: widget.availableGrades
                .map((grade) =>
                    DropdownMenuItem(value: grade, child: Text(grade)))
                .toList(),
            onChanged: (value) {
              setState(() {
                _selectedGradeLevel = value;
                // Auto-update school based on grade level
                _selectedSchool = _getSchoolByGrade(value, widget.currentRole);
              });
            },
          ),

          const SizedBox(height: 16),

          // School (auto-filled based on grade/role)
          widget.buildTextField(
            controller: TextEditingController(text: _selectedSchool ?? ''),
            label: 'School',
            hint: '',
            icon: Icons.business,
            enabled: false,
          ),

          const SizedBox(height: 24),

          // Mentor Assignment Section
          widget.buildSectionHeader('Mentor Assignment'),
          const SizedBox(height: 16),

          // Select Mentor
          widget.buildDropdown<String>(
            value: _selectedMentorId,
            label: 'Select Mentor',
            icon: Icons.supervisor_account,
            hint: 'Choose a mentor',
            items: widget.availableMentors
                .map((mentor) => DropdownMenuItem(
                    value: mentor.id,
                    child: Text('${mentor.name} (${mentor.city})')))
                .toList(),
            onChanged: (value) {
              setState(() {
                _selectedMentorId = value;
              });
            },
          ),

          // Error message
          if (_errorMessage != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFE53E3E).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: const Color(0xFFE53E3E).withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error, color: Color(0xFFE53E3E), size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(
                        color: Color(0xFFFC8181),
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 32),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed:
                      _isLoading ? null : () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.white.withOpacity(0.3)),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Cancel',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleSubmit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF38A169),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text(
                          'Add Mentee',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),
        ],
      ),
    );
  }

  String _getSchoolByGrade(String? gradeLevel, String role) {
    if (gradeLevel == null) return '';

    final gradeNumber = int.tryParse(gradeLevel.split('th')[0]);
    if (gradeNumber == null) return '';

    if (role == 'director') {
      return gradeNumber <= 8 ? 'Middle School' : 'High School';
    } else if (role.contains('middleSchool')) {
      return 'Middle School';
    } else if (role.contains('highSchool')) {
      return 'High School';
    }

    return '';
  }

  Future<void> _handleSubmit() async {
    // Validate form
    final validation = _validateForm();

    if (validation != null) {
      setState(() {
        _errorMessage = validation;
      });
      return;
    }

    // Clear error and show loading
    setState(() {
      _errorMessage = null;
      _isLoading = true;
    });

    // Submit form with Google Places data
    final formData = {
      'firstName': _firstNameController.text.trim(),
      'lastName': _lastNameController.text.trim(),
      'gender': _selectedGender,
      'gradeLevel': _selectedGradeLevel!,
      'school': _selectedSchool!,
      'mentorId': _selectedMentorId!,
    };

    // Add location data from Google Places
    if (_selectedLocation != null) {
      _selectedLocation!.forEach((key, value) {
        formData[key] = value?.toString() ?? '';
      });
    }

    await widget.onSubmit(formData);

    setState(() {
      _isLoading = false;
    });
  }

  String? _validateForm() {
    if (_firstNameController.text.trim().isEmpty) {
      return 'First name is required';
    }
    if (_lastNameController.text.trim().isEmpty) return 'Last name is required';

    // 🚀 Google Places validation - much simpler!
    if (_selectedLocation == null) return 'Location is required';

    if (_selectedGradeLevel == null) return 'Grade level is required';
    if (_selectedMentorId == null) return 'Mentor selection is required';

    return null;
  }
}

// 📝 Edit Mentee Bottom Sheet Widget
class _EditMenteeBottomSheet extends StatefulWidget {
  final VirtualMentee mentee;
  final Future<void> Function(VirtualMentee, Map<String, dynamic>) onUpdate;
  final Future<void> Function(VirtualMentee) onDelete;

  const _EditMenteeBottomSheet({
    required this.mentee,
    required this.onUpdate,
    required this.onDelete,
  });

  @override
  State<_EditMenteeBottomSheet> createState() => _EditMenteeBottomSheetState();
}

class _EditMenteeBottomSheetState extends State<_EditMenteeBottomSheet> {
  late String _selectedGender;
  Map<String, dynamic>? _selectedLocation; // Google Places location data
  late String _selectedGradeLevel;

  // Loading states
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _selectedGender = widget.mentee.gender;
    _selectedGradeLevel = widget.mentee.gradeLevel;

    // Initialize with existing mentee location data
    if (widget.mentee.city.isNotEmpty) {
      _selectedLocation = {
        'formattedAddress':
            '${widget.mentee.city}, ${widget.mentee.province}, ${widget.mentee.country}',
        'country': widget.mentee.country,
        'city': widget.mentee.city,
        'province': widget.mentee.province,
      };
    }
  }

  // 🚀 Google Places - No complex loading methods needed!

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: Color(0xFF2D3748),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF38A169).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.edit,
                    color: Color(0xFF38A169),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Edit Mentee',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        widget.mentee.fullName,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(
                    Icons.close,
                    color: Colors.white.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),

          // Form content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Grade Level Section
                  _buildSectionHeader('Academic Information'),
                  const SizedBox(height: 16),
                  _buildDropdown<String>(
                    value: _selectedGradeLevel,
                    label: 'Grade Level',
                    icon: Icons.school,
                    items: [
                      '6th Grade',
                      '7th Grade',
                      '8th Grade',
                      '9th Grade',
                      '10th Grade',
                      '11th Grade',
                      '12th Grade'
                    ]
                        .map((grade) =>
                            DropdownMenuItem(value: grade, child: Text(grade)))
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedGradeLevel = value!;
                      });
                    },
                  ),

                  const SizedBox(height: 24),

                  // Location Section
                  _buildSectionHeader('Location Information'),
                  const SizedBox(height: 16),

                  // 🚀 Location Dropdown Cascade for Edit
                  LocationDropdownCascade(
                    initialLocation: _selectedLocation,
                    onLocationSelected: (locationData) {
                      setState(() {
                        _selectedLocation = locationData;
                      });
                      print('📍 Updated location: $locationData');
                    },
                  ),

                  // Show selected location info

                  const SizedBox(height: 24),

                  // Personal Information Section
                  _buildSectionHeader('Personal Information'),
                  const SizedBox(height: 16),
                  _buildDropdown<String>(
                    value: _selectedGender,
                    label: 'Gender',
                    icon: Icons.wc,
                    items: ['Male', 'Female']
                        .map((gender) => DropdownMenuItem(
                            value: gender, child: Text(gender)))
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedGender = value!;
                      });
                    },
                  ),

                  const SizedBox(height: 32),

                  // Action buttons
                  Row(
                    children: [
                      // Delete button
                      Expanded(
                        child: OutlinedButton(
                          onPressed:
                              _isLoading ? null : _showDeleteConfirmation,
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFFE53E3E)),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.delete,
                                  color: Color(0xFFE53E3E), size: 18),
                              const SizedBox(width: 8),
                              Text(
                                'Delete',
                                style: TextStyle(
                                  color: Colors.red.shade400,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Update button
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _handleUpdate,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF38A169),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white),
                                  ),
                                )
                              : const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.save, size: 18),
                                    SizedBox(width: 8),
                                    Text(
                                      'Update',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildDropdown<T>({
    required T? value,
    required String label,
    required IconData icon,
    required List<DropdownMenuItem<T>> items,
    void Function(T?)? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.8),
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(icon, color: Colors.white.withOpacity(0.7)),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButton<T>(
                  value: value,
                  dropdownColor: const Color(0xFF2D3748),
                  underline: const SizedBox(),
                  style: const TextStyle(color: Colors.white),
                  isExpanded: true,
                  menuMaxHeight: 300, // Limit dropdown height to 300 pixels
                  items: items,
                  onChanged: onChanged,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _handleUpdate() async {
    setState(() {
      _isLoading = true;
    });

    final updates = <String, dynamic>{};

    if (_selectedGradeLevel != widget.mentee.gradeLevel) {
      updates['gradeLevel'] = _selectedGradeLevel;
    }

    // 🚀 Google Places location updates - much simpler!
    if (_selectedLocation != null) {
      // Check if location has changed
      final currentLocation =
          '${widget.mentee.city}, ${widget.mentee.province}, ${widget.mentee.country}';
      final newLocation = _selectedLocation!['formattedAddress'] ?? '';

      if (currentLocation != newLocation) {
        // Add all location data from Google Places
        _selectedLocation!.forEach((key, value) {
          updates[key] = value?.toString() ?? '';
        });
      }
    }

    if (_selectedGender != widget.mentee.gender) {
      updates['gender'] = _selectedGender;
    }

    if (updates.isNotEmpty) {
      await widget.onUpdate(widget.mentee, updates);
    }

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  void _showDeleteConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2D3748),
        title: const Text(
          'Delete Mentee',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'Are you sure you want to delete ${widget.mentee.fullName}? This action cannot be undone.',
          style: TextStyle(color: Colors.white.withOpacity(0.8)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop(); // Close dialog
              Navigator.of(context).pop(); // Close bottom sheet
              await widget.onDelete(widget.mentee);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE53E3E),
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
