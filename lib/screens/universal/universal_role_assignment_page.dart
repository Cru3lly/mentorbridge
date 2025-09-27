import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import '../../../utils/member_id_generator.dart';

// 🎯 NEW: Role Permissions System
class RolePermissions {
  // Hangi rol hangi rolleri atayabilir/silebilir
  static const Map<String, List<String>> assignableRoles = {
    'admin': ['*'], // Herkesi
    'moderator': [
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
      'accountant'
    ],
    'director': [
      'middleSchoolCoordinator',
      'highSchoolCoordinator',
      'universityCoordinator',
      'housingCoordinator'
    ],
    'middleSchoolCoordinator': ['middleSchoolAssistantCoordinator'],
    'highSchoolCoordinator': ['highSchoolAssistantCoordinator'],
    'universityCoordinator': ['universityAssistantCoordinator'],
    'housingCoordinator': ['housingAssistantCoordinator'],
    'middleSchoolAssistantCoordinator': ['middleSchoolMentor'],
    'highSchoolAssistantCoordinator': ['highSchoolMentor'],
    'universityAssistantCoordinator': ['studentHouseLeader'],
    'housingAssistantCoordinator': ['houseLeader'],
    'houseLeader': ['houseMember'],
    'studentHouseLeader': ['studentHouseMember'],
    // Mentor, Student, Accountant rolleri atama yetkisi yok
  };

  // İsim/Email/UID ile arama yapabileceği roller (Member ID ile herkes herkesi bulabilir)
  static const Map<String, List<String>> nameSearchableRoles = {
    'admin': ['*'], // Herkesi
    'moderator': [
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
      'accountant'
    ], // Admin/Moderator hariç herkesi
    'director': [
      'middleSchoolCoordinator',
      'highSchoolCoordinator',
      'universityCoordinator',
      'housingCoordinator'
    ],
    'middleSchoolCoordinator': ['middleSchoolAssistantCoordinator'],
    'highSchoolCoordinator': ['highSchoolAssistantCoordinator'],
    'universityCoordinator': ['universityAssistantCoordinator'],
    'housingCoordinator': ['housingAssistantCoordinator'],
    'middleSchoolAssistantCoordinator': ['middleSchoolMentor'],
    'highSchoolAssistantCoordinator': ['highSchoolMentor'],
    'universityAssistantCoordinator': ['studentHouseLeader'],
    'housingAssistantCoordinator': ['houseLeader'],
    'houseLeader': ['houseMember'],
    'studentHouseLeader': ['studentHouseMember'],
    // Mentor, Student, Accountant sadece user-only kişileri bulabilir
    'middleSchoolMentor': ['user-only'],
    'highSchoolMentor': ['user-only'],
    'accountant': ['user-only'],
  };

  // Rol atama yetkisi kontrolü
  static bool canAssignRole(String currentUserRole, String targetRole) {
    final assignable = assignableRoles[currentUserRole] ?? [];
    return assignable.contains('*') || assignable.contains(targetRole);
  }

  // İsimle arama yetkisi kontrolü
  static bool canSearchUserByName(
      String currentUserRole, List<String> targetUserRoles) {
    final searchable = nameSearchableRoles[currentUserRole] ?? [];

    // Admin her türlü arayabilir
    if (searchable.contains('*')) return true;

    // User-only kişileri herkes bulabilir
    if (targetUserRoles.isEmpty ||
        (targetUserRoles.length == 1 && targetUserRoles.contains('user'))) {
      return true;
    }

    // Hedef kullanıcının rollerinden herhangi biri aranabilir mi?
    return targetUserRoles
        .any((role) => role != 'user' && searchable.contains(role));
  }

  // Kullanıcının atayabileceği rollerin listesi
  static List<String> getAssignableRoles(String currentUserRole) {
    return assignableRoles[currentUserRole] ?? [];
  }
}

class UniversalRoleAssignmentPage extends StatefulWidget {
  final String?
      contextRole; // Role context from which dashboard this was called

  const UniversalRoleAssignmentPage({
    super.key,
    this.contextRole,
  });

  @override
  _UniversalRoleAssignmentPageState createState() =>
      _UniversalRoleAssignmentPageState();
}

class _UniversalRoleAssignmentPageState
    extends State<UniversalRoleAssignmentPage> with TickerProviderStateMixin {
  // 🚀 NEW: Modern search system controllers
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  // 🎯 Management roles list for checking user permissions
  final List<String> managementRoles = [
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
    'houseLeader',
    'studentHouseLeader',
    'middleSchoolMentor',
    'highSchoolMentor'
  ];
  // New controllers for organizational units
  String? _selectedUnitGender;

  // 🚀 NEW: Search system state with caching
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;
  Timer? _searchDebounce;

  // Performance optimization - Search cache
  final Map<String, List<Map<String, dynamic>>> _searchCache = {};
  final Map<String, DateTime> _cacheTimestamps = {};
  static const Duration _cacheExpiry = Duration(minutes: 5);

  // Supervisor cache for performance
  final Map<String, Map<String, List<Map<String, dynamic>>>> _supervisorCache =
      {};
  final Map<String, DateTime> _supervisorCacheTimestamps = {};

  // Mentorship groups cache for lazy loading
  final Map<String, List<Map<String, dynamic>>> _mentorshipGroupsCache = {};
  final Map<String, DateTime> _mentorshipCacheTimestamps = {};
  // 🚀 NEW: Selected users
  Map<String, dynamic>? _selectedUser;

  String? _selectedRole;
  bool _isLoading = false;
  String _message = '';
  String? _error;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Success message timer and animation state
  Timer? _successMessageTimer;
  bool _showSuccessMessage = false;
  bool _showDeletionMessage = false; // New flag for red deletion messages
  int _countdown = 5;
  double _progressValue = 1.0;

  // Animation controller for slide out effect
  late AnimationController _slideAnimationController;
  late Animation<Offset> _slideAnimation;

  // State for live validation
  String? _targetUserName;
  String? _supervisorUserName;
  String? _supervisorUserRole;

  bool? _supervisorRoleMatches;

  // New state for wizard flow
  String? _selectedCity;
  String? _selectedCountry;
  String? _selectedProvince;

  // _targetUserGender no longer used; Step 4 gender is _selectedUnitGender

  // State for mentor assignment
  List<Map<String, dynamic>> _mentorshipGroups = [];
  String? _selectedMentorshipGroupId;
  String?
      _selectedMentorshipGroupName; // 🎯 Cached selected class name to survive refetches

  // 🚀 NEW: Supervisor dropdown system

  Map<String, List<Map<String, dynamic>>> _supervisorsByCity = {};
  bool _isLoadingSupervisors = false;
  String? _selectedSupervisorId;

  bool _isLoadingGroups = false;
  // String? _supervisorUnitPath; // removed unused field

  // Simple step system
  int _currentStep = 1;
  int get _totalSteps {
    // 🎯 NEW: Always 5 steps for consistency
    if (_selectedRole == null)
      return 2; // Still 2 for initial steps (search + role selection)

    bool needsSupervisor =
        _supervisorRoleHierarchy.containsKey(_selectedRole) ||
            _dependentRoles.contains(_selectedRole);

    if (!needsSupervisor) {
      // Step 1: Search, Step 2: Role Selection, Step 3: Groups Need Supervision
      return 3;
    }

    // 🎯 Management roles (unit-managing, mentors) always get full flow:
    // Step 1: Search, Step 2: Role, Step 3: Supervisor, Step 4: Details, Step 5: Groups Need Supervision
    if (_unitManagingRoles.contains(_selectedRole)) {
      return 5;
    }

    // 🎯 Other roles with supervisor (like student):
    // Step 1: Search, Step 2: Role, Step 3: Supervisor, Step 4: Groups Need Supervision
    return 4;
  }

  // TODO: Country/Province/City data should come from a centralized service
  final List<String> _countries = ['Canada', 'USA', 'UK'];

  final Map<String, List<String>> _provincesByCountry = {
    'Canada': [
      'Ontario',
      'Quebec',
      'British Columbia',
      'Alberta',
      'Manitoba',
      'Saskatchewan'
    ],
    'USA': [
      'New York',
      'California',
      'Illinois',
      'Texas',
      'Arizona',
      'Florida'
    ],
    'UK': ['England', 'Scotland', 'Wales', 'Northern Ireland'],
  };

  final Map<String, List<String>> _citiesByProvince = {
    // Canada
    'Ontario': ['Toronto', 'Ottawa', 'Mississauga', 'Hamilton', 'London'],
    'Quebec': ['Montreal', 'Quebec City', 'Laval', 'Gatineau'],
    'British Columbia': ['Vancouver', 'Victoria', 'Surrey', 'Kelowna'],
    'Alberta': ['Calgary', 'Edmonton', 'Red Deer', 'Lethbridge'],
    'Manitoba': ['Winnipeg', 'Brandon'],
    'Saskatchewan': ['Saskatoon', 'Regina'],

    // USA
    'New York': ['New York City', 'Albany', 'Buffalo', 'Rochester'],
    'California': ['Los Angeles', 'San Francisco', 'San Diego', 'Sacramento'],
    'Illinois': ['Chicago', 'Springfield', 'Rockford'],
    'Texas': ['Houston', 'Dallas', 'Austin', 'San Antonio'],
    'Arizona': ['Phoenix', 'Tucson', 'Mesa'],
    'Florida': ['Miami', 'Orlando', 'Tampa', 'Jacksonville'],

    // UK
    'England': ['London', 'Manchester', 'Birmingham', 'Liverpool', 'Bristol'],
    'Scotland': ['Glasgow', 'Edinburgh', 'Aberdeen', 'Dundee'],
    'Wales': ['Cardiff', 'Swansea', 'Newport'],
    'Northern Ireland': ['Belfast', 'Derry', 'Lisburn'],
  };

  // Helper functions for location data
  List<String> _getProvincesForCountry(String country) {
    return _provincesByCountry[country] ?? [];
  }

  List<String> _getCitiesForProvince(String province) {
    return _citiesByProvince[province] ?? [];
  }

  // 🚀 NEW: Role hierarchy for determining primary role (highest rank first)
  static const List<String> _roleHierarchy = [
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
    'accountant',
    'middleSchoolMentor',
    'highSchoolMentor',
    'houseLeader',
    'studentHouseLeader',
    'houseMember',
    'studentHouseMember',
  ];

  // 🚀 NEW: Get the highest ranking role from a list of roles
  static String _getHighestRankingRole(List<String> roles) {
    for (String hierarchyRole in _roleHierarchy) {
      if (roles.contains(hierarchyRole)) {
        return hierarchyRole;
      }
    }
    return roles.isNotEmpty ? roles.first : 'user';
  }

  // Defines the required supervisor role for a given role.
  static const Map<String, String> _supervisorRoleHierarchy = {
    'moderator': 'admin',
    'director': 'moderator',
    'middleSchoolCoordinator': 'director',
    'highSchoolCoordinator': 'director',
    'universityCoordinator': 'director',
    'housingCoordinator': 'director',
    'middleSchoolAssistantCoordinator': 'middleSchoolCoordinator',
    'highSchoolAssistantCoordinator': 'highSchoolCoordinator',
    'universityAssistantCoordinator': 'universityCoordinator',
    'housingAssistantCoordinator': 'housingCoordinator',
    'middleSchoolMentor': 'middleSchoolAssistantCoordinator',
    'highSchoolMentor': 'highSchoolAssistantCoordinator',
    'accountant': 'director',
    'houseLeader':
        'housingAssistantCoordinator', // 🎯 UPDATED: Housing assistant coordinator
    'studentHouseLeader':
        'universityAssistantCoordinator', // 🎯 NEW: University housing
    'houseMember':
        'houseLeader', // 🎯 NEW: House member supervised by house leader
    'studentHouseMember':
        'studentHouseLeader', // 🎯 NEW: Student house member supervised by student house leader
  };

  // Defines roles that manage a new organizational unit upon assignment.
  static const Set<String> _unitManagingRoles = {
    'moderator', // 🎯 NEW: Moderator now creates organizational unit
    'director',
    'middleSchoolCoordinator',
    'highSchoolCoordinator',
    'universityCoordinator',
    'housingCoordinator',
    'middleSchoolAssistantCoordinator',
    'highSchoolAssistantCoordinator',
    'universityAssistantCoordinator',
    'housingAssistantCoordinator',
    'accountant',
    'houseLeader', // 🎯 NEW: House Leader manages organizational unit
    'studentHouseLeader', // 🎯 NEW: Student House Leader manages organizational unit
    'middleSchoolMentor', // 🎯 NEW: Mentor manages organizational unit
    'highSchoolMentor', // 🎯 NEW: Mentor manages organizational unit
  };

  // Defines roles that require a supervisor but don't create a new unit.
  static const Set<String> _dependentRoles = {
    'houseMember',
    'studentHouseMember'
  };

  // Sadece seçilebilir rolleri ayrı bir liste olarak tut
  final List<String> _selectableRoles = [
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
    'studentHouseLeader', // 🎯 NEW: Student house leader role
    'houseMember', // 🎯 NEW: House member role
    'studentHouseMember', // 🎯 NEW: Student house member role
    'accountant',
    // 'user', // Herkes zaten user rolüne sahip
  ];

  // 🚀 State variables for multi-role system
  bool _isAddingNewRole =
      true; // TODO: Remove after refactoring to operation-based logic
  List<Map<String, dynamic>> _existingUserRoles = [];

  // 🚀 New state variables for the enhanced multi-role system
  String _currentOperation = ''; // 'add', 'delete'
  String? _selectedExistingRole; // For delete operations

  bool _showRoleSelection = false; // Show dropdown after operation selected

  // 🎯 NEW: Current user role detection for permission system
  String? _currentUserRole;
  List<String> _currentUserRoles = [];

  // 🚀 NEW: Orphaned units choice variables
  List<Map<String, dynamic>> _availableOrphanedUnits = [];
  bool _hasOrphanedUnits = false;
  String? _orphanedUnitChoice; // 'recover', 'create_new'
  String? _selectedOrphanedUnitId;

  // 🎯 NEW: Role hierarchy for consistent sorting (highest to lowest authority)
  static const List<String> _roleHierarchyOrder = [
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
    'studentHouseLeader', // 🎯 NEW: Student house leader role
    'houseMember', // 🎯 NEW: House member role
    'studentHouseMember', // 🎯 NEW: Student house member role
    'accountant',
    'user'
  ];

  // 🎯 NEW: Sort roles by hierarchy (highest to lowest authority)
  List<Map<String, dynamic>> _sortRolesByHierarchy(
      List<Map<String, dynamic>> roles) {
    return roles
      ..sort((a, b) {
        final aIndex = _roleHierarchyOrder.indexOf(a['role'] as String);
        final bIndex = _roleHierarchyOrder.indexOf(b['role'] as String);

        // If role not found in hierarchy, put it at the end
        final aPos = aIndex == -1 ? _roleHierarchyOrder.length : aIndex;
        final bPos = bIndex == -1 ? _roleHierarchyOrder.length : bIndex;

        return aPos.compareTo(bPos);
      });
  }

  // 🎯 NEW: Sort role strings by hierarchy (highest to lowest authority)
  List<String> _sortRoleStringsByHierarchy(List<String> roles) {
    return roles
      ..sort((a, b) {
        final aIndex = _roleHierarchyOrder.indexOf(a);
        final bIndex = _roleHierarchyOrder.indexOf(b);

        // If role not found in hierarchy, put it at the end
        final aPos = aIndex == -1 ? _roleHierarchyOrder.length : aIndex;
        final bPos = bIndex == -1 ? _roleHierarchyOrder.length : bIndex;

        return aPos.compareTo(bPos);
      });
  }

  // 🚀 NEW: Find orphaned units that could be recovered for the current role
  Future<void> _checkForOrphanedUnits() async {
    if (!_unitManagingRoles.contains(_selectedRole)) {
      setState(() {
        _availableOrphanedUnits = [];
        _hasOrphanedUnits = false;
        _orphanedUnitChoice = null;
        _selectedOrphanedUnitId = null;
      });
      return;
    }

    try {
      // Determine expected unit characteristics
      String? expectedUnitLevel;

      // 🎯 NEW SYSTEM: Updated expected unit characteristics
      if (_selectedRole == 'moderator') {
        expectedUnitLevel = 'moderator';
      } else if (_selectedRole == 'director') {
        expectedUnitLevel = 'director';
      } else if (_selectedRole!.contains('Coordinator') &&
          !_selectedRole!.contains('AssistantCoordinator')) {
        expectedUnitLevel = 'coordinator';
      } else if (_selectedRole!.contains('AssistantCoordinator')) {
        expectedUnitLevel = 'assistantCoordinator';
      } else if (_selectedRole == 'accountant') {
        expectedUnitLevel = 'accountant';
      } else if (_selectedRole == 'middleSchoolMentor') {
        expectedUnitLevel = 'middleSchoolMentor';
      } else if (_selectedRole == 'highSchoolMentor') {
        expectedUnitLevel = 'highSchoolMentor';
      } else if (_selectedRole == 'houseLeader') {
        expectedUnitLevel = 'houseLeader';
      } else if (_selectedRole == 'studentHouseLeader') {
        expectedUnitLevel = 'studentHouseLeader';
      } else if (_selectedRole == 'houseMember') {
        expectedUnitLevel = 'houseMember';
      } else if (_selectedRole == 'studentHouseMember') {
        expectedUnitLevel = 'studentHouseMember';
      }

      // 🚀 NEW: Admin/Moderator exception - they see orphaned units based on their scope
      final currentUser = FirebaseAuth.instance.currentUser;
      bool isAdmin = false;
      bool isModerator = false;
      if (currentUser != null) {
        final currentUserDoc =
            await _firestore.collection('users').doc(currentUser.uid).get();
        final currentUserData = currentUserDoc.data();
        final currentUserRoles = currentUserData?['roles'] as List<dynamic>?;
        isAdmin =
            currentUserRoles?.any((role) => role['role'] == 'admin') == true;
        isModerator =
            currentUserRoles?.any((role) => role['role'] == 'moderator') ==
                true;
      }

      // Search for orphaned units
      var query = _firestore
          .collection('organizationalUnits')
          .where('status', isEqualTo: 'pendingReassignment');

      // Add level filter if available
      if (expectedUnitLevel != null) {
        query = query.where('level', isEqualTo: expectedUnitLevel);
      }

      // 🎯 Location-based filtering
      if (isAdmin) {
        // Admin sees all orphaned units globally - no filtering
      } else if (isModerator) {
        // Moderator sees all orphaned units in their country
        if (_selectedCountry != null) {
          query = query.where('country', isEqualTo: _selectedCountry);
        }
      } else {
        // Other roles: filter by city and country
        if (_selectedCity != null) {
          query = query.where('city', isEqualTo: _selectedCity);
        }
        if (_selectedCountry != null) {
          query = query.where('country', isEqualTo: _selectedCountry);
        }
      }

      final results = await query.get();

      List<Map<String, dynamic>> orphanedUnits = [];

      for (final doc in results.docs) {
        final data = doc.data();
        final unitName = data['name'] as String?;
        final unitLevel = data['level'] as String?;

        // 🎯 NEW SYSTEM: Check if this unit is relevant for the current role
        bool isRelevant = false;

        if (_selectedRole == 'moderator' && unitLevel == 'moderator') {
          isRelevant = true;
        } else if (_selectedRole == 'director' && unitLevel == 'director') {
          isRelevant = true;
        } else if (_selectedRole!.contains('Coordinator') &&
            !_selectedRole!.contains('AssistantCoordinator') &&
            unitLevel == 'coordinator') {
          // Check if it matches the education level
          final roleEducationLevel =
              _selectedRole!.replaceAll('Coordinator', '').toLowerCase();
          final unitNameLower = unitName?.toLowerCase() ?? '';
          if (unitNameLower
              .contains(roleEducationLevel.replaceAll('school', ' school'))) {
            isRelevant = true;
          }
        } else if (_selectedRole!.contains('AssistantCoordinator') &&
            unitLevel == 'assistantCoordinator') {
          // For assistant coordinators, check if it matches the education level
          final roleEducationLevel = _selectedRole!
              .replaceAll('AssistantCoordinator', '')
              .toLowerCase();
          final unitNameLower = unitName?.toLowerCase() ?? '';
          if (unitNameLower
              .contains(roleEducationLevel.replaceAll('school', ' school'))) {
            isRelevant = true;
          }
        } else if (_selectedRole == 'accountant' && unitLevel == 'accountant') {
          isRelevant = true;
        } else if ((_selectedRole == 'middleSchoolMentor' ||
                _selectedRole == 'highSchoolMentor') &&
            unitLevel == 'mentor') {
          // Check if it matches the education level
          final roleEducationLevel =
              _selectedRole!.replaceAll('Mentor', '').toLowerCase();
          final unitNameLower = unitName?.toLowerCase() ?? '';
          if (unitNameLower
              .contains(roleEducationLevel.replaceAll('school', ' school'))) {
            isRelevant = true;
          }
        } else if (_selectedRole == 'houseLeader' &&
            unitLevel == 'houseLeader') {
          isRelevant = true;
        }

        if (isRelevant) {
          final unitData = Map<String, dynamic>.from(data);
          unitData['id'] = doc.id;
          unitData['path'] = doc.reference.path;
          orphanedUnits.add(unitData);
        }
      }

      setState(() {
        _availableOrphanedUnits = orphanedUnits;
        _hasOrphanedUnits = orphanedUnits.isNotEmpty;
        _orphanedUnitChoice = null;
        _selectedOrphanedUnitId = null;
      });
    } catch (e) {
// print('Error checking for orphaned units: $e');
      setState(() {
        _availableOrphanedUnits = [];
        _hasOrphanedUnits = false;
        _orphanedUnitChoice = null;
        _selectedOrphanedUnitId = null;
      });
    }
  }

  // 🚀 NEW: Build orphaned units choice step
  Widget _buildOrphanedUnitsChoiceStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment:
          MainAxisAlignment.start, // 🎯 Force content to start from top
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Groups Need Supervision',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _availableOrphanedUnits.isNotEmpty
                      ? 'Found ${_availableOrphanedUnits.length} group${_availableOrphanedUnits.length == 1 ? '' : 's'} without supervision. Choose what to do:'
                      : 'Choose what to do:',
                  style: const TextStyle(fontSize: 16, color: Colors.white70),
                ),
                const SizedBox(height: 30),

                // Choice options
                _buildChoiceOption(
                  'create_new',
                  'Create New Group',
                  'Start fresh with a completely new group',
                  Icons.group_add,
                  Colors.green,
                ),
                const SizedBox(height: 16),
                _buildChoiceOption(
                  'recover',
                  'Take Over Existing Group',
                  'Assign supervision to a group that needs help',
                  Icons.supervisor_account,
                  Colors.blue,
                ),

                // Show available orphaned units if recover is selected
                if (_orphanedUnitChoice == 'recover') ...[
                  const SizedBox(height: 24),
                  const Text(
                    'Choose Group:',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ..._availableOrphanedUnits.asMap().entries.map((entry) {
                    final index = entry.key;
                    final unit = entry.value;
                    return _buildOrphanedUnitOption(unit, index);
                  }),
                ],

                const SizedBox(height: 40),

                // Progress indicator
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                      decoration: BoxDecoration(
                        color: _orphanedUnitChoice != null &&
                                (_orphanedUnitChoice != 'recover' ||
                                    _selectedOrphanedUnitId != null)
                            ? Colors.green.withOpacity(0.2)
                            : Colors.orange.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _orphanedUnitChoice != null &&
                                  (_orphanedUnitChoice != 'recover' ||
                                      _selectedOrphanedUnitId != null)
                              ? Colors.green.withOpacity(0.4)
                              : Colors.orange.withOpacity(0.4),
                        ),
                      ),
                      child: Text(
                        _orphanedUnitChoice != null &&
                                (_orphanedUnitChoice != 'recover' ||
                                    _selectedOrphanedUnitId != null)
                            ? 'Ready to assign'
                            : 'Choose an option above',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 30),

                // Navigation buttons
                Row(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        color: Colors.white.withOpacity(0.2),
                        border:
                            Border.all(color: Colors.white.withOpacity(0.3)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ElevatedButton.icon(
                        onPressed: _goToPreviousStep,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          foregroundColor: Colors.white,
                          shadowColor: Colors.transparent,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 32, vertical: 16),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20)),
                        ),
                        icon: const Icon(Icons.arrow_back_rounded, size: 20),
                        label: const Text('Back',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const Spacer(),
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        color: (_orphanedUnitChoice != null &&
                                (_orphanedUnitChoice != 'recover' ||
                                    _selectedOrphanedUnitId != null))
                            ? Colors.green.withOpacity(0.3)
                            : Colors.white.withOpacity(0.1),
                        border: Border.all(
                          color: (_orphanedUnitChoice != null &&
                                  (_orphanedUnitChoice != 'recover' ||
                                      _selectedOrphanedUnitId != null))
                              ? Colors.green.withOpacity(0.5)
                              : Colors.white.withOpacity(0.2),
                        ),
                        boxShadow: (_orphanedUnitChoice != null &&
                                (_orphanedUnitChoice != 'recover' ||
                                    _selectedOrphanedUnitId != null))
                            ? [
                                BoxShadow(
                                  color: Colors.green.withOpacity(0.2),
                                  blurRadius: 15,
                                  offset: const Offset(0, 8),
                                ),
                              ]
                            : [],
                      ),
                      child: ElevatedButton.icon(
                        onPressed: (_orphanedUnitChoice != null &&
                                (_orphanedUnitChoice != 'recover' ||
                                    _selectedOrphanedUnitId != null))
                            ? assignRole // Step 5 is always the final step
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          foregroundColor: Colors.white,
                          shadowColor: Colors.transparent,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 32, vertical: 16),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20)),
                        ),
                        icon: const Icon(Icons.check_circle_rounded, size: 20),
                        label: const Text('Complete',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildChoiceOption(String value, String title, String description,
      IconData icon, Color color) {
    final isSelected = _orphanedUnitChoice == value;
    final isDisabled = value == 'recover' && _availableOrphanedUnits.isEmpty;

    return GestureDetector(
      onTap: isDisabled
          ? null
          : () {
              setState(() {
                _orphanedUnitChoice = value;
                if (value != 'recover') {
                  _selectedOrphanedUnitId = null;
                }
              });
            },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDisabled
              ? Colors.grey.withOpacity(0.35) // Daha belirgin
              : isSelected
                  ? color.withOpacity(0.2)
                  : Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDisabled
                ? Colors.grey.withOpacity(0.6) // Daha belirgin border
                : isSelected
                    ? color.withOpacity(0.5)
                    : Colors.white.withOpacity(0.3),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDisabled
                    ? Colors.grey
                        .withOpacity(0.3) // Disabled için daha belirgin
                    : color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon,
                  color: isDisabled ? Colors.grey.shade300 : color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isDisabled
                        ? 'Take Over Existing Group\n(No groups available)'
                        : title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDisabled ? Colors.grey.shade400 : Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isDisabled
                        ? 'There are currently no orphaned groups to take over'
                        : description,
                    style: TextStyle(
                      fontSize: 14,
                      color: isDisabled ? Colors.grey.shade500 : Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected) Icon(Icons.check_circle, color: color, size: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildOrphanedUnitOption(Map<String, dynamic> unit, int index) {
    final isSelected = _selectedOrphanedUnitId == unit['id'];
    final unitName = unit['name'] as String? ?? 'Unknown Unit';
    final status = unit['status'] as String? ?? 'unknown';
    final daysOrphaned = _calculateDaysOrphaned(unit);

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedOrphanedUnitId = unit['id'];
        });
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.blue.withOpacity(0.2)
              : Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? Colors.blue.withOpacity(0.5)
                : Colors.white.withOpacity(0.3),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    unitName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _getUnitStatusText(status, daysOrphaned),
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle, color: Colors.blue, size: 20),
          ],
        ),
      ),
    );
  }

  int _calculateDaysOrphaned(Map<String, dynamic> unit) {
    try {
      final reassignmentNeeded = unit['reassignmentNeededAt'];
      if (reassignmentNeeded != null) {
        final timestamp = reassignmentNeeded is Timestamp
            ? reassignmentNeeded.toDate()
            : DateTime.parse(reassignmentNeeded.toString());
        return DateTime.now().difference(timestamp).inDays;
      }
    } catch (e) {
      // Ignore errors
    }
    return 0;
  }

  String _getUnitStatusText(String status, int daysOrphaned) {
    String statusText;
    switch (status.toLowerCase()) {
      case 'pendingreassignment':
        statusText = 'Pending reassignment';
        break;
      default:
        statusText = 'Needs help';
    }

    if (daysOrphaned > 0) {
      return '$statusText • $daysOrphaned day${daysOrphaned == 1 ? '' : 's'} ago';
    }
    return statusText;
  }

  // 🚀 NEW: Check for existing organizational units to prevent duplicates
  Future<Map<String, dynamic>?> _findExistingOrganizationalUnit(
    String? unitName,
    String? unitType,
    String? unitLevel,
    String? country,
  ) async {
    if (unitName == null) return null;

    try {
      // Search for existing organizational units with same characteristics
      final results = await _firestore
          .collection('organizationalUnits')
          .where('name', isEqualTo: unitName)
          .get();

      for (final doc in results.docs) {
        final data = doc.data();

        // Additional validation for exact match
        if (unitType != null && data['type'] != unitType) continue;
        if (unitLevel != null && data['level'] != unitLevel) continue;
        if (country != null && data['country'] != country) continue;

        // Found exact match
        final unitData = Map<String, dynamic>.from(data);
        unitData['id'] = doc.id;
        unitData['path'] = doc.reference.path;
        return unitData;
      }

      return null; // No existing unit found
    } catch (e) {
// print('Error searching for existing organizational unit: $e');
      return null;
    }
  }

  // 🚀 New methods for enhanced multi-role system

  void _selectOperation(String operation) {
    setState(() {
      // 🚀 FIXED: Don't reset state completely - only reset what's necessary
      _currentOperation = operation;
      _showRoleSelection = true;
      _selectedRole = null;
      _selectedExistingRole = null;
      _message = '';
      // 🚀 FIXED: Don't reset user data - keep the validated user info
      // _targetUserName = null;
      _supervisorUserName = null;
      _supervisorUserRole = null;
      _supervisorRoleMatches = false;
      // 🚀 FIXED: Don't reset to step 2, stay on current step
      // _currentStep = 2; // Reset to step 2 (role selection)
      // 🚀 FIXED: Don't clear existing user roles - we need them for UI
      // _existingUserRoles.clear();

      // Clear all validation states for next steps
      _selectedCountry = null;
      _selectedCity = null;
      _selectedUnitGender = null;
      _selectedMentorshipGroupId = null;
      _mentorshipGroups.clear();

      // Clear supervisor selection state
      _selectedSupervisorId = null;

      // 🚀 FIXED: Legacy onIdChanged removed
    });

    // 🎯 UX IMPROVEMENT: Smooth scroll to role selection section
    // Give setState a moment to rebuild UI, then scroll
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToRoleSelection();
    });
  }

  // 🎯 UX IMPROVEMENT: Smooth scroll to role selection section
  void _scrollToRoleSelection() {
    if (!_scrollController.hasClients) return;

    // Calculate approximate position of role selection section
    // This is roughly after the operation buttons section
    final screenHeight = MediaQuery.of(context).size.height;
    final scrollOffset =
        screenHeight * 0.4; // Scroll down about 40% of screen height

    _scrollController.animateTo(
      scrollOffset,
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeOutCubic,
    );
  }

  // 🎯 UX IMPROVEMENT: Smooth scroll to mentor class section after gender selection
  void _scrollToMentorClassSection() {
    if (!_scrollController.hasClients) return;

    // Give setState a moment to rebuild the UI with mentor class section
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Calculate approximate position where mentor class section appears
      // This is roughly after gender selection in the details step
      final screenHeight = MediaQuery.of(context).size.height;
      final scrollOffset =
          screenHeight * 0.7; // Scroll down about 70% of screen height

      _scrollController.animateTo(
        scrollOffset,
        duration: const Duration(milliseconds: 800),
        curve: Curves.easeOutCubic,
      );
    });
  }

  void _proceedToNextStep() {
    if (_currentOperation == 'delete') {
      _showDeleteConfirmation();
    } else {
      // 🎯 NEW: Use consistent step navigation
      _goToNextStep();
      setState(() {
        _showRoleSelection = false;
      });
    }
  }

  void _showDeleteConfirmation() {
    if (_selectedExistingRole == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.red, size: 24),
            SizedBox(width: 12),
            Text(
              'Confirm Role Deletion',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'You are about to delete the following role from $_targetUserName:',
              style: const TextStyle(color: Colors.white70, fontSize: 16),
            ),
            const SizedBox(height: 16),

            // Role to be deleted
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.withOpacity(0.4)),
              ),
              child: Row(
                children: [
                  Icon(_getRoleIcon(_selectedExistingRole!),
                      color: Colors.red, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _getRoleTitle(_selectedExistingRole!),
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),
            Text(
              'After deletion, the user will have these roles:',
              style: const TextStyle(color: Colors.white70, fontSize: 16),
            ),
            const SizedBox(height: 8),

            // Remaining roles (excluding user role)
            if (_existingUserRoles
                .where((r) =>
                    r['role'] != _selectedExistingRole && r['role'] != 'user')
                .isNotEmpty)
              ...(_sortRolesByHierarchy(_existingUserRoles
                      .where((r) =>
                          r['role'] != _selectedExistingRole &&
                          r['role'] != 'user')
                      .toList())
                  .map(
                    (role) => Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                        border:
                            Border.all(color: Colors.green.withOpacity(0.4)),
                      ),
                      child: Row(
                        children: [
                          Icon(_getRoleIcon(role['role']),
                              color: Colors.green, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _getRoleTitle(role['role']),
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 14),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList())
            else
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.withOpacity(0.4)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.grey, size: 16),
                    SizedBox(width: 8),
                    Text(
                      'No roles assigned',
                      style: TextStyle(color: Colors.white, fontSize: 14),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 16),
            const Text(
              'Are you sure you want to proceed?',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Cancel button - Sol alt
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.withOpacity(0.4)),
                  ),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(
                        color: Colors.grey,
                        fontSize: 14,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ),

              // Confirm button - Sağ alt
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _performRoleDeletion();
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.red.withOpacity(0.4)),
                  ),
                  child: const Text(
                    'Confirm',
                    style: TextStyle(
                        color: Colors.red,
                        fontSize: 14,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _performRoleDeletion() async {
    setState(() => _isLoading = true);

    try {
      // Try multiple sources for target user ID
      String targetUserId = '';
      if (_selectedUser != null) {
        // Try both 'uid' and 'id' fields since search results use 'id'
        targetUserId = _selectedUser!['uid'] ?? _selectedUser!['id'] ?? '';
      } else {
        // Try to find user by Member ID if available
        for (final result in _searchResults) {
          if (result['firstName'] == _targetUserName?.split(' ').first &&
              result['lastName'] == _targetUserName?.split(' ').last) {
            targetUserId = result['uid'] ?? result['id'] ?? '';
            if (targetUserId.isNotEmpty) {
              break;
            }
          }
        }
      }

      if (targetUserId.isEmpty) {
        setState(() {
          _message =
              'Error: Could not find target user ID. Please try selecting the user again.';
          _isLoading = false;
        });
        return;
      }

      final targetUserRef = _firestore.collection('users').doc(targetUserId);

      // Get current data
      final targetUserDoc = await targetUserRef.get();
      final userData = targetUserDoc.data();

      if (userData == null) {
        throw Exception('User data not found');
      }

      // 🚀 NEW: Remove selected role and recalculate primary role
      // Remove the role from roles array
      List<Map<String, dynamic>> updatedRoles = List.from(_existingUserRoles);
      updatedRoles.removeWhere((r) => r['role'] == _selectedExistingRole);

      // Determine the new primary role after deletion
      String newPrimaryRole = 'user'; // Default to user
      if (updatedRoles.isNotEmpty) {
        // Find the first non-user role, or default to user
        final nonUserRole = updatedRoles.firstWhere(
          (r) => r['role'] != 'user',
          orElse: () => updatedRoles.first,
        );
        newPrimaryRole = nonUserRole['role'];
      }

      // Prepare comprehensive cleanup for role deletion
      final updateData = <String, dynamic>{
        'roles': updatedRoles,
        'role':
            newPrimaryRole, // Update primary role for backward compatibility
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // 🎯 Check if user still has any management roles after deletion

      // If user now only has 'user' role, clean up all role-specific data
      if (newPrimaryRole == 'user' && updatedRoles.length == 1) {
        // Clean up assignment metadata
        updateData['assignedBy'] = FieldValue.delete();
        updateData['assignedAt'] = FieldValue.delete();
        updateData['assignedCountry'] = FieldValue.delete();
        // Note: managesEntity is now handled per-role in roles array, no top-level field

        // Clean up role-specific geographic data (only if they were role-specific)
        // Keep personal data like firstName, lastName, email, gender, createdAt
        updateData['parentUnit'] = FieldValue.delete();
        updateData['department'] = FieldValue.delete();

        // Note: We keep city, country, province as they might be personal info
        // 🔧 REMOVED: Username deletion logic that was causing usernames to disappear
        // Previous code was deleting usernames that contained role keywords, which was too aggressive
        // and could delete legitimate usernames. Personal usernames should be preserved.
      }
      // 🎯 NEW: If deleted role was management role, it's already removed from roles array
      // No need to clear top-level managesEntity as we use per-role managesEntity
      // User still has other roles, only clean up deleted role specific data
      else {
        // You might want to check if the specific deleted role had assignedCountry etc.
        if (_selectedExistingRole == 'moderator') {
          updateData['assignedCountry'] = FieldValue.delete();
        }
      }

      // Update user document with comprehensive cleanup
      await targetUserRef.update(updateData);

      // Update organizationalUnits collection for role deletion
      await _handleOrganizationalUnitForRoleDeletion(
          targetUserId, _selectedExistingRole!);

      // 🔧 FIX: Create success message before clearing any data
      final userName = _selectedUser != null
          ? '${_selectedUser!['firstName'] ?? ''} ${_selectedUser!['lastName'] ?? ''}'
              .trim()
          : (_targetUserName ?? 'Unknown User');
      final successMessage =
          '${_getRoleTitle(_selectedExistingRole!)} role removed successfully from $userName!';

      // Clear controllers BEFORE setting success message to avoid triggering listeners
      _searchController.clear();
      _searchController.clear();

      // 🚨 FIX: Clear search cache to prevent stale data when searching same user again
      _searchCache.clear();
      _cacheTimestamps.clear();

      // 🚀 Show deletion success message with red styling
      _showDeletionSuccessMessageWithTimer(successMessage);

      setState(() {
        _isLoading = false;
        _currentStep = 1;
        _showRoleSelection = false;
        _currentOperation = '';
        _selectedExistingRole = null;
        _existingUserRoles = updatedRoles;

        // 🔧 FIX: Clear other form data (controllers already cleared above)
        _selectedUser = null;
        _searchResults = [];
        _selectedRole = null;
        _targetUserName = null;
        // _targetUserRole removed
      });
    } catch (e) {
      setState(() {
        _message = 'Error deleting role: $e';
        _isLoading = false;
      });
    }
  }

  // 🚀 Get existing roles with backward compatibility
  Future<List<Map<String, dynamic>>> _getExistingRoles(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) return [];

      final userData = userDoc.data();
      if (userData == null) return [];

      // New system: roles array exists
      if (userData['roles'] != null) {
        return List<Map<String, dynamic>>.from(userData['roles']);
      }

      // Old system: single role field - convert to new format
      if (userData['role'] != null) {
        // 🎯 Get managesEntity from roles array if available, fallback to top-level for backward compatibility
        String? managesEntityForRole;
        final existingRoles = userData['roles'] as List<dynamic>?;
        if (existingRoles != null) {
          final matchingRole = existingRoles.firstWhere(
            (r) => r is Map && r['role'] == userData['role'],
            orElse: () => null,
          );
          if (matchingRole != null && matchingRole is Map) {
            managesEntityForRole = matchingRole['managesEntity'] as String?;
          }
        }
        // Fallback to top-level managesEntity for backward compatibility
        managesEntityForRole ??= userData['managesEntity'] as String?;

        return [
          {
            'role': userData['role'],
            'managesEntity': managesEntityForRole,
            'assignedBy': userData['assignedBy'] ?? 'system',
            'assignedAt':
                userData['assignedAt'] ?? DateTime.now().millisecondsSinceEpoch,
            'isDefault': userData['role'] == 'user',
          }
        ];
      }

      return [];
    } catch (e) {
      return [];
    }
  }

  // 🚀 Comprehensive multi-role assignment function
  Future<void> _performMultiRoleAssignment() async {
    final targetMemberId = _selectedUser?['memberId'] ?? '';
    final supervisorMemberId = _selectedSupervisorId ?? '';

    // 🎉 NEW: Convert Member ID to UID for target user
    final targetUserId = await _getUidFromMemberId(targetMemberId);
    if (targetUserId == null) {
      setState(() {
        _message = 'Target Member ID not found.';
        _isLoading = false;
      });
      return;
    }

    // 🎉 NEW: Convert Member ID to UID for supervisor
    String? finalSupervisorId;
    if (supervisorMemberId.isNotEmpty) {
      finalSupervisorId = await _getUidFromMemberId(supervisorMemberId);

      if (finalSupervisorId == null) {
        setState(() {
          _message = 'Supervisor Member ID not found.';
          _isLoading = false;
        });
        return;
      }
    }

    final batch = _firestore.batch();

    try {
      if (targetUserId.isEmpty) {
        throw Exception('Target user ID is empty');
      }

      final targetUserRef = _firestore.collection('users').doc(targetUserId);

      final targetUserDoc = await targetUserRef.get();
      if (!targetUserDoc.exists) {
        throw Exception('Target user document does not exist: $targetUserId');
      }

      // targetUserData not used

      // Get existing roles

      _existingUserRoles = await _getExistingRoles(targetUserId);

      // Ensure user role exists (everyone must have user role)

      bool hasUserRole = _existingUserRoles.any((r) => r['role'] == 'user');
      if (!hasUserRole) {
        _existingUserRoles.add({
          'role': 'user',
          'managesEntity': null,
          'assignedBy': 'system',
          'assignedAt':
              DateTime.now().millisecondsSinceEpoch, // Use regular timestamp
          'isDefault': true,
        });
      } else {}

      // Handle role assignment

      List<Map<String, dynamic>> updatedRoles = List.from(_existingUserRoles);
      if (!_isAddingNewRole) {
        // Legacy behavior: remove all non-user roles

        updatedRoles.removeWhere((r) => r['role'] != 'user');
      } else {}

      // Supervisor validation

      DocumentReference? parentUnitRef;
      DocumentSnapshot? supervisorDoc;
      // newUnitName is set later inside creation methods
      String? parentUnitName;

      final requiredSupervisorRole = _supervisorRoleHierarchy[_selectedRole];

      if (requiredSupervisorRole != null) {
        if (finalSupervisorId == null || finalSupervisorId.isEmpty) {
          setState(() {
            _message = 'This role requires a Supervisor Member ID.';
            _isLoading = false;
          });
          return;
        }

        supervisorDoc =
            await _firestore.collection('users').doc(finalSupervisorId).get();
        if (!supervisorDoc.exists) {
          setState(() {
            _message = 'Supervisor Member ID does not exist.';
            _isLoading = false;
          });
          return;
        }

        final supervisorData = supervisorDoc.data() as Map<String, dynamic>?;
        if (supervisorData == null) {
          setState(() {
            _message = 'Could not read supervisor data.';
            _isLoading = false;
          });
          return;
        }

        final supervisorRole = supervisorData['role'] as String?;

        // Supervisor role validation
        bool isValidSupervisor = false;
        if (_selectedRole == 'director') {
          isValidSupervisor = (supervisorRole == 'moderator');
          if (!isValidSupervisor) {
            setState(() {
              _message = 'Invalid Supervisor. Expected role: Moderator.';
              _isLoading = false;
            });
            return;
          }
        } else if (_selectedRole == 'moderator') {
          isValidSupervisor = (supervisorRole == 'admin');
          if (!isValidSupervisor) {
            setState(() {
              _message = 'Invalid Supervisor. Expected role: Admin.';
              _isLoading = false;
            });
            return;
          }
        } else if (_selectedRole == 'houseLeader') {
          // 🎯 UPDATED: houseLeader now supervised only by housing assistant coordinator
          isValidSupervisor = (supervisorRole == 'housingAssistantCoordinator');
          if (!isValidSupervisor) {
            setState(() {
              _message =
                  'Invalid Supervisor. Expected role: Housing Assistant Coordinator.';
              _isLoading = false;
            });
            return;
          }
        } else if (_selectedRole == 'studentHouseLeader') {
          // 🎯 NEW: studentHouseLeader supervised by university assistant coordinator
          isValidSupervisor =
              (supervisorRole == 'universityAssistantCoordinator');
          if (!isValidSupervisor) {
            setState(() {
              _message =
                  'Invalid Supervisor. Expected role: University Assistant Coordinator.';
              _isLoading = false;
            });
            return;
          }
        } else if (_selectedRole == 'houseMember') {
          // 🎯 NEW: houseMember supervised by house leader
          isValidSupervisor = (supervisorRole == 'houseLeader');
          if (!isValidSupervisor) {
            setState(() {
              _message = 'Invalid Supervisor. Expected role: House Leader.';
              _isLoading = false;
            });
            return;
          }
        } else if (_selectedRole == 'studentHouseMember') {
          // 🎯 NEW: studentHouseMember supervised by student house leader
          isValidSupervisor = (supervisorRole == 'studentHouseLeader');
          if (!isValidSupervisor) {
            setState(() {
              _message =
                  'Invalid Supervisor. Expected role: Student House Leader.';
              _isLoading = false;
            });
            return;
          }
        } else if (supervisorRole != requiredSupervisorRole) {
          setState(() {
            _message =
                'Invalid Supervisor. Expected role: ${_getRoleTitle(requiredSupervisorRole)}.';
            _isLoading = false;
          });
          return;
        }

        // 🎯 Get supervisor's managesEntity from their roles array
        String? parentEntityPath;
        final supervisorRoles = supervisorData['roles'] as List<dynamic>?;
        if (supervisorRoles != null) {
          // Find supervisor's management role and get its managesEntity
          final managementRole = supervisorRoles.firstWhere(
            (r) {
              final role = r is Map ? r['role']?.toString() : null;
              final roleLower = role?.toLowerCase();
              // 🎯 FIX: Compare with lowercase versions of management roles
              final managementRolesLower =
                  managementRoles.map((r) => r.toLowerCase()).toList();
              return r is Map && managementRolesLower.contains(roleLower);
            },
            orElse: () => null,
          );
          if (managementRole != null && managementRole is Map) {
            parentEntityPath = managementRole['managesEntity'] as String?;
          }
        }
        // Fallback to top-level managesEntity for backward compatibility
        parentEntityPath ??= supervisorData['managesEntity'] as String?;

        // Only process parent entity for roles that actually need it
        // Moderator role doesn't need parent entity information
        if (parentEntityPath != null &&
            parentEntityPath.isNotEmpty &&
            _selectedRole != 'moderator') {
          try {
            parentUnitRef = _firestore.doc(parentEntityPath);

            final parentUnitDoc = await parentUnitRef.get();
            if (parentUnitDoc.exists) {
              final parentUnitData =
                  parentUnitDoc.data() as Map<String, dynamic>?;
              parentUnitName = parentUnitData?['name'] as String?;
            } else {
              parentUnitRef = null; // Reset to null if document doesn't exist
            }
          } catch (e) {
            parentUnitRef = null; // Reset to null on error
            parentUnitName = null;
          }
        } else {}
      }

      // Create organizational unit and assign role based on type
      String? managesEntityPath;

      if (_unitManagingRoles.contains(_selectedRole)) {
        managesEntityPath = await _createOrganizationalUnitWithDeduplication(
            batch, parentUnitRef, parentUnitName, targetUserId);
      } else if (_dependentRoles.contains(_selectedRole)) {
        final supervisorData = supervisorDoc?.data() as Map<String, dynamic>?;

        // 🎯 Get supervisor's managesEntity from their roles array
        String? supervisorManagesEntity;
        final supervisorRoles = supervisorData?['roles'] as List<dynamic>?;
        if (supervisorRoles != null) {
          final managementRole = supervisorRoles.firstWhere(
            (r) {
              final role = r is Map ? r['role']?.toString() : null;
              final roleLower = role?.toLowerCase();
              // 🎯 FIX: Compare with lowercase versions of management roles
              final managementRolesLower =
                  managementRoles.map((r) => r.toLowerCase()).toList();
              return r is Map && managementRolesLower.contains(roleLower);
            },
            orElse: () => null,
          );
          if (managementRole != null && managementRole is Map) {
            supervisorManagesEntity =
                managementRole['managesEntity'] as String?;
          }
        }
        // Fallback to top-level managesEntity for backward compatibility
        managesEntityPath = supervisorManagesEntity ??
            supervisorData?['managesEntity'] as String?;
      } else {
        managesEntityPath = null; // For roles that don't manage units
      }

      // Add new role to roles array
      final currentTimestamp = DateTime.now().millisecondsSinceEpoch;
      final currentUserMemberId = await _getCurrentUserMemberId();

      final newRoleData = <String, dynamic>{
        'role': _selectedRole!,
        'assignedBy': FirebaseAuth
            .instance.currentUser!.uid, // ✅ Keep UID for backward compatibility
        'assignedByMemberId':
            currentUserMemberId, // 🎉 NEW: Member ID reference
        'assignedAt':
            currentTimestamp, // Use regular timestamp instead of FieldValue.serverTimestamp()
        'isDefault': false,
      };

      // Only add managesEntity if it's not null
      if (managesEntityPath != null) {
        newRoleData['managesEntity'] = managesEntityPath;
      } else {}

      updatedRoles.add(newRoleData);

      // 🚀 NEW: Determine the highest ranking role for primary role field
      List<String> allRoleNames =
          updatedRoles.map((r) => r['role'] as String).toList();
      String primaryRole = _getHighestRankingRole(allRoleNames);

      // Update user document with multi-role support
      final updateData = <String, dynamic>{
        'roles': updatedRoles,
        'role':
            primaryRole, // Primary role based on hierarchy (highest ranking)
        'assignedBy': FirebaseAuth
            .instance.currentUser!.uid, // ✅ Keep UID for backward compatibility
        'assignedByMemberId':
            currentUserMemberId, // 🎉 NEW: Member ID reference
        'assignedAt': currentTimestamp, // Use same timestamp as role entry
        'parentId': FieldValue.delete(),
        'assignedTo': FieldValue.delete(),
      };

      // 🎯 No longer setting top-level managesEntity - it's handled per-role in roles array
      // The managesEntity is already set in newRoleData above

      // Add country assignment for moderator role (backward compatibility)
      if (_selectedRole == 'moderator' && _selectedCountry != null) {
        updateData['assignedCountry'] = _selectedCountry;
      }

      batch.update(targetUserRef, updateData);

      await batch.commit();

      // Success - reset form
      _resetFormAfterSuccess();
    } catch (e) {
      setState(() {
        _message = 'An error occurred during role assignment: $e';
        _isLoading = false;
      });
    }
  }

  // 🚀 Create organizational unit based on role type
  Future<String?> _createOrganizationalUnit(
    WriteBatch batch,
    DocumentReference? parentUnitRef,
    String? parentUnitName,
    String targetUserId,
  ) async {
    final newUnitRef = _firestore.collection('organizationalUnits').doc();
    String? newUnitName;
    String? newUnitLevel;

    // 🎯 NEW SYSTEM: Set unit name and level based on role type with consistent naming
    if (_selectedRole == 'moderator') {
      newUnitName = '${_selectedCountry!} - National Moderator';
      newUnitLevel = 'moderator';
    } else if (_selectedRole == 'director') {
      newUnitName = '${_selectedCity!} - Director (${_selectedUnitGender!})';
      newUnitLevel = 'director';
    } else if (_selectedRole!.contains('Coordinator') &&
        !_selectedRole!.contains('AssistantCoordinator')) {
      final roleTitle = _getRoleTitle(_selectedRole!);
      newUnitName = '${_selectedCity!} - $roleTitle (${_selectedUnitGender!})';
      newUnitLevel = 'coordinator';
    } else if (_selectedRole!.contains('AssistantCoordinator')) {
      final roleTitle = _getRoleTitle(_selectedRole!);
      newUnitName = '${_selectedCity!} - $roleTitle (${_selectedUnitGender!})';
      newUnitLevel = 'assistantCoordinator';
    } else if (_selectedRole == 'accountant') {
      newUnitName = '${_selectedCity!} - Accountant (${_selectedUnitGender!})';
      newUnitLevel = 'accountant';
    } else if (_selectedRole == 'houseLeader') {
      newUnitName =
          '${_selectedCity!} - House Leader (${_selectedUnitGender!})';
      newUnitLevel = 'houseLeader';
    } else if (_selectedRole == 'studentHouseLeader') {
      newUnitName =
          '${_selectedCity!} - Student House Leader (${_selectedUnitGender!})';
      newUnitLevel = 'studentHouseLeader';
    } else if (_selectedRole == 'middleSchoolMentor') {
      newUnitName =
          '${_selectedCity!} - Middle School Mentor (${_selectedUnitGender!})';
      newUnitLevel = 'middleSchoolMentor';
    } else if (_selectedRole == 'highSchoolMentor') {
      newUnitName =
          '${_selectedCity!} - High School Mentor (${_selectedUnitGender!})';
      newUnitLevel = 'highSchoolMentor';
    }

    // Province comes from Step 4 selection - no need for legacy logic

    // Get Member IDs for references
    final targetMemberId = await _getUidToMemberId(targetUserId);
    final currentUserMemberId = await _getCurrentUserMemberId();

    // Create the organizational unit with standard fields
    final unitData = <String, dynamic>{
      'name': newUnitName,
      'type': 'unit', // 🎉 NEW: All roles use 'unit' (including accountant)
      'level': newUnitLevel,
      'status': 'active', // 🎉 NEW: Add status field
      'country': _selectedCountry!, // 🎉 Step 4'te seçilen country (mandatory)
      'city': _selectedCity!,
      'gender': _selectedUnitGender!,
      'managedBy': targetUserId,
      'managedByMemberId': targetMemberId,
      'managerChangedAt':
          FieldValue.serverTimestamp(), // 🆕 Yeni timestamp sistemi
      'createdAt': FieldValue.serverTimestamp(),
      'createdByMemberId': currentUserMemberId,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    // 🎯 NEW: Add class field for mentor roles (prefer cached name)
    if ((_selectedRole == 'middleSchoolMentor' ||
        _selectedRole == 'highSchoolMentor')) {
      if (_selectedMentorshipGroupName != null &&
          _selectedMentorshipGroupName!.isNotEmpty) {
        unitData['class'] =
            _selectedMentorshipGroupName; // Use cached name to survive refetches
      } else if (_selectedMentorshipGroupId != null) {
        final selectedGroupData = _mentorshipGroups.firstWhere(
            (g) => g['id'] == _selectedMentorshipGroupId,
            orElse: () => <String, dynamic>{});

        if (selectedGroupData.isNotEmpty && selectedGroupData['name'] != null) {
          unitData['class'] = selectedGroupData['name']; // Add class reference
        } else {}
      } else {}
    }

    // Only add parentUnit if it's not null
    if (parentUnitRef != null) {
      unitData['parentUnit'] = parentUnitRef;
    } else if (_selectedRole == 'moderator') {
      // 🎯 FIX: Moderator's parent unit should be Admin's unit
      // Find Admin's organizational unit
      await _setAdminAsParentUnit(unitData);
    } else if (_selectedRole == 'director') {
      // Ensure director's parent is the selected supervisor's management unit (moderator)

      await _setSupervisorUnitAsParent(unitData);
    } else {
      // For other roles, default to supervisor's management unit if available

      await _setSupervisorUnitAsParent(unitData);
    }

    // Add province from Step 3 selection (auto-set to 'National' for moderator)
    unitData['province'] = _selectedProvince!; // Mandatory from Step 3

    // Enforce parentUnit for unit-managing roles

    if (_unitManagingRoles.contains(_selectedRole) &&
        unitData['parentUnit'] == null) {
      setState(() {
        _message =
            'Parent unit could not be determined. Please select a supervisor or ensure an Admin unit exists.';
        _isLoading = false;
      });
      return null;
    }

    batch.set(newUnitRef, unitData);

    return newUnitRef.path;
  }

  // 🎯 NEW: Set Admin's organizational unit as parent unit
  Future<void> _setAdminAsParentUnit(Map<String, dynamic> unitData) async {
    try {
      // Find Admin's organizational unit - try multiple approaches

      // Approach 1: Find by type 'admin'
      var adminUnitsQuery = await _firestore
          .collection('organizationalUnits')
          .where('type', isEqualTo: 'admin')
          .limit(1)
          .get();

      if (adminUnitsQuery.docs.isNotEmpty) {
        final adminUnitDoc = adminUnitsQuery.docs.first;
        unitData['parentUnit'] = adminUnitDoc.reference;

        return;
      }

      // Approach 2: Find by current admin user
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        adminUnitsQuery = await _firestore
            .collection('organizationalUnits')
            .where('managedBy', isEqualTo: currentUser.uid)
            .limit(1)
            .get();

        if (adminUnitsQuery.docs.isNotEmpty) {
          final adminUnitDoc = adminUnitsQuery.docs.first;
          unitData['parentUnit'] = adminUnitDoc.reference;
          return;
        }
      }

      // Approach 3: Find first available unit as fallback
      adminUnitsQuery =
          await _firestore.collection('organizationalUnits').limit(1).get();

      if (adminUnitsQuery.docs.isNotEmpty) {
        final adminUnitDoc = adminUnitsQuery.docs.first;
        unitData['parentUnit'] = adminUnitDoc.reference;
        return;
      }
    } catch (e) {
      // Error setting Admin as parent unit - continue without parent
    }
  }

  // 🎯 NEW: Set selected supervisor's management unit as parent unit when needed
  Future<void> _setSupervisorUnitAsParent(Map<String, dynamic> unitData) async {
    try {
      final supervisorMemberId = _selectedSupervisorId ?? '';

      if (supervisorMemberId.isEmpty) {
        return;
      }

      final supervisorUid = await _getUidFromMemberId(supervisorMemberId);

      if (supervisorUid == null) {
        return;
      }

      final supervisorDoc =
          await _firestore.collection('users').doc(supervisorUid).get();

      if (!supervisorDoc.exists) {
        return;
      }

      final supervisorData = supervisorDoc.data();
      final supervisorRoles = supervisorData?['roles'] as List<dynamic>?;

      String? parentEntityPath;

      if (supervisorRoles != null) {
        final managementRolesLower =
            managementRoles.map((r) => r.toLowerCase()).toList();

        final managementRole = supervisorRoles.firstWhere(
          (r) {
            final role = r is Map ? r['role']?.toString() : null;
            final roleLower = role?.toLowerCase();
            return r is Map && managementRolesLower.contains(roleLower);
          },
          orElse: () => null,
        );
        if (managementRole != null && managementRole is Map) {
          parentEntityPath = managementRole['managesEntity'] as String?;
        } else {}
      }

      // Fallback to top-level managesEntity
      parentEntityPath ??= supervisorData?['managesEntity'] as String?;

      if (parentEntityPath != null && parentEntityPath.isNotEmpty) {
        unitData['parentUnit'] = _firestore.doc(parentEntityPath);
      } else {}
    } catch (_) {}
  }

  // 🚀 NEW: Create organizational unit with deduplication checking
  Future<String?> _createOrganizationalUnitWithDeduplication(
    WriteBatch batch,
    DocumentReference? parentUnitRef,
    String? parentUnitName,
    String targetUserId,
  ) async {
    // Prepare unit characteristics for search
    String? unitName;
    String? unitType;
    String? unitLevel;

    // 🎯 NEW SYSTEM: Determine characteristics based on role
    if (_selectedRole == 'moderator') {
      unitName = '${_selectedCountry!} - National Moderator';
      unitLevel = 'moderator';
      unitType = 'unit';
    } else if (_selectedRole == 'director') {
      unitName = '${_selectedCity!} - Director (${_selectedUnitGender!})';
      unitLevel = 'director';
      unitType = 'unit';
    } else if (_selectedRole!.contains('Coordinator') &&
        !_selectedRole!.contains('AssistantCoordinator')) {
      final roleTitle = _getRoleTitle(_selectedRole!);
      unitName = '${_selectedCity!} - $roleTitle (${_selectedUnitGender!})';
      unitLevel = 'coordinator';
      unitType = 'unit';
    } else if (_selectedRole!.contains('AssistantCoordinator')) {
      final roleTitle = _getRoleTitle(_selectedRole!);
      unitName = '${_selectedCity!} - $roleTitle (${_selectedUnitGender!})';
      unitLevel = 'assistantCoordinator';
      unitType = 'unit';
    } else if (_selectedRole == 'accountant') {
      unitName = '${_selectedCity!} - Accountant (${_selectedUnitGender!})';
      unitLevel = 'accountant';
      unitType = 'unit'; // 🎉 NEW: Consistent with other roles
    } else if (_selectedRole == 'houseLeader') {
      unitName = '${_selectedCity!} - House Leader (${_selectedUnitGender!})';
      unitLevel = 'houseLeader';
      unitType = 'unit';
    } else if (_selectedRole == 'studentHouseLeader') {
      unitName =
          '${_selectedCity!} - Student House Leader (${_selectedUnitGender!})';
      unitLevel = 'studentHouseLeader';
      unitType = 'unit';
    } else if (_selectedRole == 'middleSchoolMentor') {
      unitName =
          '${_selectedCity!} - Middle School Mentor (${_selectedUnitGender!})';
      unitLevel = 'middleSchoolMentor';
      unitType = 'unit';
    } else if (_selectedRole == 'highSchoolMentor') {
      unitName =
          '${_selectedCity!} - High School Mentor (${_selectedUnitGender!})';
      unitLevel = 'highSchoolMentor';
      unitType = 'unit';
    }

    // Handle orphaned units choice
    if (_hasOrphanedUnits && _orphanedUnitChoice != null) {
      if (_orphanedUnitChoice == 'recover' && _selectedOrphanedUnitId != null) {
        // User chose to recover a specific orphaned unit

        final selectedUnit = _availableOrphanedUnits.firstWhere(
          (unit) => unit['id'] == _selectedOrphanedUnitId,
          orElse: () => <String, dynamic>{},
        );

        if (selectedUnit.isNotEmpty) {
          final unitRef = _firestore.doc(selectedUnit['path'] as String);
          // Ensure managedByMemberId is set when recovering an orphaned unit
          final recoveredMemberId = await _getUidToMemberId(targetUserId);
          final updateData = <String, dynamic>{
            'managedBy': targetUserId,
            'managedByMemberId': recoveredMemberId,
            'status': 'active',
            'managerChangedAt':
                FieldValue.serverTimestamp(), // 🆕 Yeni timestamp sistemi
            'lastManagerId':
                FieldValue.delete(), // 🧹 Temizlik: Artık orphaned değil
            'lastManagerRole':
                FieldValue.delete(), // 🧹 Temizlik: Artık orphaned değil
            'updatedAt': FieldValue.serverTimestamp(),
          };

          // 🎯 NEW: Add class field for mentor roles when recovering orphaned units (prefer cached name)
          if ((_selectedRole == 'middleSchoolMentor' ||
              _selectedRole == 'highSchoolMentor')) {
            if (_selectedMentorshipGroupName != null &&
                _selectedMentorshipGroupName!.isNotEmpty) {
              updateData['class'] = _selectedMentorshipGroupName;
            } else if (_selectedMentorshipGroupId != null) {
              final selectedGroupData = _mentorshipGroups.firstWhere(
                  (g) => g['id'] == _selectedMentorshipGroupId,
                  orElse: () => <String, dynamic>{});
              if (selectedGroupData.isNotEmpty &&
                  selectedGroupData['name'] != null) {
                updateData['class'] =
                    selectedGroupData['name']; // Add class reference
              } else {}
            } else {}
          }

          batch.update(unitRef, updateData);

          return selectedUnit['path'] as String;
        }
      } else if (_orphanedUnitChoice == 'create_new') {
        // User chose to create new unit despite orphaned units existing

        return await _createOrganizationalUnit(
            batch, parentUnitRef, parentUnitName, targetUserId);
      }
    }

    // Fallback: Check for existing organizational unit automatically (legacy behavior)

    final existingUnit = await _findExistingOrganizationalUnit(
      unitName,
      unitType,
      unitLevel,
      _selectedCountry!,
    );

    if (existingUnit != null) {
      // Found existing unit - check its current status
      final status = existingUnit['status'] as String?;
      final managedBy = existingUnit['managedBy'] as String?;

      if (status == 'pendingReassignment' || managedBy == null) {
        // Existing unit is orphaned - recover it (fallback for when no choice was made)

        // Get Member IDs for references
        final targetMemberId = await _getUidToMemberId(targetUserId);

        final unitRef = _firestore.doc(existingUnit['path'] as String);
        final updateData = <String, dynamic>{
          'managedBy': targetUserId,
          'managedByMemberId': targetMemberId,
          'status': 'active',
          'managerChangedAt':
              FieldValue.serverTimestamp(), // 🆕 Yeni timestamp sistemi
          'lastManagerId':
              FieldValue.delete(), // 🧹 Temizlik: Artık orphaned değil
          'lastManagerRole':
              FieldValue.delete(), // 🧹 Temizlik: Artık orphaned değil
          'updatedAt': FieldValue.serverTimestamp(),
        };

        // 🎯 NEW: Add class field for mentor roles when recovering existing units (prefer cached name)
        if ((_selectedRole == 'middleSchoolMentor' ||
            _selectedRole == 'highSchoolMentor')) {
          if (_selectedMentorshipGroupName != null &&
              _selectedMentorshipGroupName!.isNotEmpty) {
            updateData['class'] = _selectedMentorshipGroupName;
          } else if (_selectedMentorshipGroupId != null) {
            final selectedGroupData = _mentorshipGroups.firstWhere(
                (g) => g['id'] == _selectedMentorshipGroupId,
                orElse: () => <String, dynamic>{});
            if (selectedGroupData.isNotEmpty &&
                selectedGroupData['name'] != null) {
              updateData['class'] =
                  selectedGroupData['name']; // Add class reference
            } else {}
          } else {}
        }

        batch.update(unitRef, updateData);

        return existingUnit['path'] as String;
      } else if (managedBy == targetUserId) {
        // Unit already belongs to this user

        return existingUnit['path'] as String;
      } else {
        // Unit is managed by someone else - create new unit (fallback to original method)

        return await _createOrganizationalUnit(
            batch, parentUnitRef, parentUnitName, targetUserId);
      }
    } else {
      // No existing unit found - create new one

      return await _createOrganizationalUnit(
          batch, parentUnitRef, parentUnitName, targetUserId);
    }
  }

  // 🚀 NEW: Find and suggest cleanup for duplicate organizational units
  Future<List<Map<String, dynamic>>> findDuplicateOrganizationalUnits() async {
    try {
      final allUnits = await _firestore.collection('organizationalUnits').get();
      final duplicateGroups = <String, List<Map<String, dynamic>>>{};

      // Group units by name + type + level
      for (final doc in allUnits.docs) {
        final data = doc.data();
        final name = data['name'] as String?;
        final type = data['type'] as String?;
        final level = data['level'] as String?;

        if (name == null) continue;

        final key = '$name|$type|$level';
        if (!duplicateGroups.containsKey(key)) {
          duplicateGroups[key] = [];
        }

        final unitData = Map<String, dynamic>.from(data);
        unitData['id'] = doc.id;
        unitData['path'] = doc.reference.path;
        duplicateGroups[key]!.add(unitData);
      }

      // Find groups with duplicates
      final duplicates = <Map<String, dynamic>>[];
      for (final group in duplicateGroups.values) {
        if (group.length > 1) {
          duplicates.addAll(group);
        }
      }

      return duplicates;
    } catch (e) {
      return [];
    }
  }

  // 🚀 NEW: Build supervisor cards grouped by city
  Widget _buildSupervisorCards() {
    if (_isLoadingSupervisors) {
      return Center(
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.3)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 48,
                height: 48,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 4,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Loading supervisors...',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_supervisorsByCity.isEmpty) {
      return Center(
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.red.withOpacity(0.2),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.red.withOpacity(0.4)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.3),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.white,
                  size: 32,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'No supervisors found',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'No supervisors available for this role.',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white70,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: _supervisorsByCity.keys.map((city) {
        final supervisors = _supervisorsByCity[city]!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // City header
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: Colors.orange,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    city,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      height: 1,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.orange.withOpacity(0.6),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Supervisors for this city
            ...supervisors
                .map((supervisor) => _buildSupervisorCard(supervisor)),

            const SizedBox(height: 24),
          ],
        );
      }).toList(),
    );
  }

  // 🚀 Build individual supervisor card
  Widget _buildSupervisorCard(Map<String, dynamic> supervisor) {
    final isSelected =
        _selectedSupervisorId == (supervisor['memberId'] ?? supervisor['id']);

    return GestureDetector(
      onTap: () async {
        setState(() {
          _selectedSupervisorId = supervisor['memberId'] ??
              supervisor['id']; // 🎉 NEW: Use Member ID if available
          // Dropdown stores selection in _selectedSupervisorId

          // 🚀 NEW: Set supervisor user role for Create New Class functionality
          final supervisorData =
              supervisor['userData'] as Map<String, dynamic>?;
          if (supervisorData != null) {
            final supervisorRoles = supervisorData['roles'] as List<dynamic>?;
            if (supervisorRoles != null && supervisorRoles.isNotEmpty) {
              // Get the first role that contains school type information
              final schoolRole = supervisorRoles.firstWhere(
                (r) {
                  final role = r is Map ? r['role']?.toString() : null;
                  return role != null &&
                      (role.contains('middleSchool') ||
                          role.contains('highSchool'));
                },
                orElse: () => supervisorRoles.first,
              );
              if (schoolRole is Map) {
                _supervisorUserRole = schoolRole['role']?.toString();
              }
            } else {
              // Fallback to legacy role field
              _supervisorUserRole = supervisorData['role'] as String?;
            }
          }
        });

        // 🎯 NEW: For mentors, set supervisor unit path directly from dropdown data
        if (_selectedRole == 'middleSchoolMentor' ||
            _selectedRole == 'highSchoolMentor') {
          try {
            final supervisorData =
                supervisor['userData'] as Map<String, dynamic>?;
            if (supervisorData != null) {
              // Get supervisor's managesEntity from their roles array
              String? parentEntityPath;
              final supervisorRoles = supervisorData['roles'] as List<dynamic>?;
              if (supervisorRoles != null) {
                final managementRole = supervisorRoles.firstWhere(
                  (r) {
                    final role = r is Map ? r['role']?.toString() : null;
                    final roleLower = role?.toLowerCase();
                    // 🎯 FIX: Compare with lowercase versions of management roles
                    final managementRolesLower =
                        managementRoles.map((r) => r.toLowerCase()).toList();
                    final isManagement =
                        managementRolesLower.contains(roleLower);
                    return r is Map && isManagement;
                  },
                  orElse: () => null,
                );
                if (managementRole != null && managementRole is Map) {
                  parentEntityPath = managementRole['managesEntity'] as String?;
                }
              }
              // Fallback to top-level managesEntity for backward compatibility
              parentEntityPath ??= supervisorData['managesEntity'] as String?;

              if (parentEntityPath != null) {
                final unitDoc = await _firestore.doc(parentEntityPath).get();
                if (unitDoc.exists && mounted) {
                  // Preserve supervisor unit path not needed; directly fetch groups
                  _fetchMentorshipGroupsForUnit(parentEntityPath);
                }
              }
            }
          } catch (e) {}
        }

        // Trigger supervisor validation handled inline now
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? Colors.blue.withOpacity(0.6)
                : Colors.white.withOpacity(0.2),
            width: isSelected ? 2 : 1,
          ),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isSelected
                ? [
                    Colors.blue.withOpacity(0.3),
                    Colors.blue.withOpacity(0.1),
                  ]
                : [
                    Colors.white.withOpacity(0.15),
                    Colors.white.withOpacity(0.05),
                  ],
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.blue.withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Row(
          children: [
            // Profile circle
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isSelected
                      ? [
                          Colors.blue.withOpacity(0.8),
                          Colors.blue.withOpacity(0.6)
                        ]
                      : [
                          Colors.grey.withOpacity(0.6),
                          Colors.grey.withOpacity(0.4)
                        ],
                ),
                border: Border.all(
                  color: Colors.white.withOpacity(0.3),
                  width: 2,
                ),
              ),
              child: Icon(
                Icons.person,
                color: Colors.white,
                size: 24,
              ),
            ),

            const SizedBox(width: 16),

            // Name and role info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    supervisor['name'],
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _getRoleTitle(supervisor['role']),
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.white70,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ],
              ),
            ),

            // Selection indicator
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color:
                      isSelected ? Colors.blue : Colors.white.withOpacity(0.4),
                  width: 2,
                ),
                color: isSelected ? Colors.blue : Colors.transparent,
              ),
              child: isSelected
                  ? Icon(Icons.check, color: Colors.white, size: 16)
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  // 🚀 NEW: Fetch available supervisors based on selected role
  Future<void> _fetchAvailableSupervisors() async {
    if (_selectedRole == null) return;

    // 🎯 FILTERING: Create cache key with city and gender for filtered results
    final cacheKey =
        '${_selectedRole!}_${_selectedCity ?? 'any'}_${_selectedUnitGender ?? 'any'}';
    final cachedTime = _supervisorCacheTimestamps[cacheKey];
    if (cachedTime != null &&
        DateTime.now().difference(cachedTime) < _cacheExpiry &&
        _supervisorCache.containsKey(cacheKey)) {
      setState(() {
        _supervisorsByCity = _supervisorCache[cacheKey]!;
        _isLoadingSupervisors = false;
      });
      return;
    }

    setState(() {
      _isLoadingSupervisors = true;
      _supervisorsByCity = {};
    });

    try {
      // Determine required supervisor role using the proper function that handles dependent roles
      String requiredSupervisorRole =
          _getRequiredSupervisorRole(_selectedRole!);

      // 🎯 UPDATED: All roles now have single supervisor - no special cases needed
      List<String> allowedSupervisorRoles = [requiredSupervisorRole];

      if (allowedSupervisorRoles.isEmpty) {
        setState(() => _isLoadingSupervisors = false);
        return;
      }

      List<Map<String, dynamic>> allSupervisors = [];

      // Fetch supervisors for each allowed role
      for (String supervisorRole in allowedSupervisorRoles) {
        // supervisorSnapshot not used

        // For ALL roles (including admin), ONLY check roles array
        // Primary role field is ignored for supervisor selection
        // Get all users and filter manually since arrayContains doesn't work with partial objects
        final allUsersSnapshot = await _firestore.collection('users').get();

        List<QueryDocumentSnapshot> filteredDocs = [];
        for (var doc in allUsersSnapshot.docs) {
          final userData = doc.data();
          final roles = userData['roles'] as List<dynamic>?;
          if (roles != null) {
            for (var roleObj in roles) {
              if (roleObj is Map<String, dynamic> &&
                  roleObj['role'] == supervisorRole) {
                filteredDocs.add(doc);
                break;
              }
            }
          }
        }

        for (var doc in filteredDocs) {
          final userData = doc.data() as Map<String, dynamic>;
          String displayName = _getFullNameFromFields(
              userData['firstName'], userData['lastName']);

          // Get city information from managesEntity (using 'name' field)
          String? city = 'Other';

          // 🎯 Get managesEntity from user's roles array
          String? managesEntity;
          final userRoles = userData['roles'] as List<dynamic>?;
          if (userRoles != null) {
            // Find first management role with managesEntity
            final managementRole = userRoles.firstWhere(
              (r) => r is Map && r['managesEntity'] != null,
              orElse: () => null,
            );
            if (managementRole != null && managementRole is Map) {
              managesEntity = managementRole['managesEntity'] as String?;
            }
          }
          // Fallback to top-level managesEntity for backward compatibility
          managesEntity ??= userData['managesEntity'] as String?;

          if (managesEntity != null) {
            try {
              final unitDoc = await _firestore.doc(managesEntity).get();
              if (unitDoc.exists) {
                final unitData = unitDoc.data();
                // Extract city name from format "Toronto - Middle School Unit (Male)" -> "Toronto"
                String fullName = unitData?['name'] as String? ?? 'Other';
                if (fullName == 'Other') {
                  city = fullName;
                } else if (fullName.contains(' - ')) {
                  city = fullName.split(' - ').first.trim();
                } else {
                  city = fullName;
                }
              }
            } catch (e) {
              // Keep default city if error
            }
          }

          // 🎯 FILTERING: Get supervisor's gender for filtering
          String? supervisorGender = userData['gender'] as String?;

          allSupervisors.add({
            'id': doc.id,
            'memberId': userData[
                'memberId'], // 🎉 NEW: Include Member ID for supervisor selection
            'name': displayName,
            'role': supervisorRole,
            'city': city,
            'gender': supervisorGender,
            'userData': userData,
          });
        }
      }

      // 🎯 FILTERING: Apply city and gender filters based on Step 3 selections
      List<Map<String, dynamic>> filteredSupervisors = allSupervisors;

      if (_selectedCity != null && _selectedUnitGender != null) {
        filteredSupervisors = allSupervisors.where((supervisor) {
          // 🎯 SPECIAL: Admin and Moderator are always available regardless of location/gender
          if (supervisor['role'] == 'admin' ||
              supervisor['role'] == 'moderator') {
            return true;
          }

          // Filter by city: exact match
          bool cityMatches = supervisor['city'] == _selectedCity;

          // Filter by gender: exact match OR if target role is moderator (Mixed accepts all)
          bool genderMatches = supervisor['gender'] == _selectedUnitGender ||
              _selectedRole ==
                  'moderator'; // Moderator accepts any supervisor gender

          return cityMatches && genderMatches;
        }).toList();
      }

      // Group by city (using filtered supervisors)
      Map<String, List<Map<String, dynamic>>> groupedByCity = {};
      for (var supervisor in filteredSupervisors) {
        String city = supervisor['city'] ?? 'Other';
        if (!groupedByCity.containsKey(city)) {
          groupedByCity[city] = [];
        }
        groupedByCity[city]!.add(supervisor);
      }

      // Sort cities and supervisors within each city
      final sortedCities = groupedByCity.keys.toList()..sort();
      Map<String, List<Map<String, dynamic>>> sortedGrouped = {};
      for (String city in sortedCities) {
        groupedByCity[city]!.sort((a, b) => a['name'].compareTo(b['name']));
        sortedGrouped[city] = groupedByCity[city]!;
      }

      // 🚀 PERFORMANCE: Cache supervisor results
      _supervisorCache[cacheKey] = sortedGrouped;
      _supervisorCacheTimestamps[cacheKey] = DateTime.now();

      // Clean old supervisor cache entries (keep only last 10)
      if (_supervisorCache.length > 10) {
        final oldestKey = _supervisorCacheTimestamps.entries
            .reduce((a, b) => a.value.isBefore(b.value) ? a : b)
            .key;
        _supervisorCache.remove(oldestKey);
        _supervisorCacheTimestamps.remove(oldestKey);
      }

      setState(() {
        _supervisorsByCity = sortedGrouped;
        _isLoadingSupervisors = false;

        // 🚀 REMOVED: Don't auto-select even if only one supervisor
        // User should always choose manually
      });
    } catch (e) {
      setState(() {
        _isLoadingSupervisors = false;
        _message = 'Error fetching supervisors: $e';
      });
    }
  }

  // 🚀 Show success message with timer and animation
  void _showSuccessMessageWithTimer(String message) {
    setState(() {
      _message = message;
      _showSuccessMessage = true;
      _countdown = 10;
      _progressValue = 1.0;
    });

    // Reset slide animation to start position
    _slideAnimationController.reset();

    _successMessageTimer?.cancel();
    _successMessageTimer =
        Timer.periodic(const Duration(milliseconds: 100), (timer) {
      setState(() {
        _progressValue -= 0.01; // 100ms * 100 = 10000ms = 10 seconds
        _countdown =
            (_progressValue * 10).ceil(); // Real-time countdown from progress

        if (_progressValue <= 0) {
          timer.cancel();
          // Start slide down animation
          _slideAnimationController.forward().then((_) {
            setState(() {
              _showSuccessMessage = false;
              _message = '';
            });
          });
        }
      });
    });
  }

  // 🚀 Show deletion success message with red styling
  void _showDeletionSuccessMessageWithTimer(String message) {
    setState(() {
      _message = message;
      _showSuccessMessage = true;
      _showDeletionMessage = true; // New flag for red styling
      _countdown = 10;
      _progressValue = 1.0;
    });

    // Reset slide animation to start position
    _slideAnimationController.reset();

    _successMessageTimer?.cancel();
    _successMessageTimer =
        Timer.periodic(const Duration(milliseconds: 100), (timer) {
      setState(() {
        _progressValue -= 0.01; // 100ms * 100 = 10000ms = 10 seconds
        _countdown =
            (_progressValue * 10).ceil(); // Real-time countdown from progress

        if (_progressValue <= 0) {
          timer.cancel();
          // Start slide down animation
          _slideAnimationController.forward().then((_) {
            setState(() {
              _showSuccessMessage = false;
              _showDeletionMessage = false;
              _message = '';
            });
          });
        }
      });
    });
  }

  // 🚀 Clear success message when user starts typing
  void _clearSuccessMessage() {
    if (_showSuccessMessage) {
      _successMessageTimer?.cancel();
      // Start slide down animation for manual clear too
      _slideAnimationController.forward().then((_) {
        setState(() {
          _showSuccessMessage = false;
          _showDeletionMessage = false;
          _message = '';
        });
      });
    }
  }

  // 🚀 Reset form after successful assignment
  void _resetFormAfterSuccess() {
    // Legacy listeners removed

    // Show success message with timer
    final successMessage = _isAddingNewRole
        ? '${_getRoleTitle(_selectedRole!)} role successfully assigned to ${_targetUserName ?? 'User'}!'
        : '${_getRoleTitle(_selectedRole!)} role successfully assigned to ${_targetUserName ?? 'User'}!';

    _showSuccessMessageWithTimer(successMessage);

    setState(() {
      _isLoading = false;
      _currentStep = 1;
      _searchController.clear();
      _selectedRole = null;
      _selectedExistingRole = null;

      // 🎯 FIX: Clear selected user and search results after successful assignment
      _selectedUser = null;
      _searchResults = [];
      _searchController.clear();

      // 🚨 FIX: Clear search cache to prevent stale data when searching same user again
      _searchCache.clear();
      _cacheTimestamps.clear();

      _currentOperation = '';
      _showRoleSelection = false;
      _selectedUnitGender = null;
      _selectedCity = null;
      _selectedCountry = null;
      _selectedMentorshipGroupId = null;
      _mentorshipGroups = [];
      _selectedSupervisorId = null;
      _supervisorsByCity = {};
      _targetUserName = null;
      // _targetUserRole removed
      _existingUserRoles = [];
      _isAddingNewRole = true;
      _supervisorUserName = null;
      _supervisorUserRole = null;
      _supervisorRoleMatches = null;

      _isLoadingGroups = false;
    });

    // Legacy listeners removed
  }

  Future<void> assignRole() async {
    setState(() {
      _isLoading = true;
      _message = '';
      _error = null;
    });

    try {
      // 🚀 NETWORK: Check connectivity before proceeding
      await _checkNetworkConnectivity();

      // 🚀 Multi-role system: Default to 'add' operation
      await _performAddRole();
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = _getAssignRoleErrorMessage(e);
        });

        // Clear error after 5 seconds
        Timer(const Duration(seconds: 5), () {
          if (mounted) {
            setState(() => _error = null);
          }
        });
      }
    }
  }

  /// Convert Member ID to Firebase UID
  Future<String?> _getUidFromMemberId(String memberId) async {
    return await MemberIdGenerator.getUidFromMemberId(memberId);
  }

  /// Get user info from Member ID
  Future<Map<String, dynamic>?> _getUserInfoFromMemberId(
      String memberId) async {
    return await MemberIdGenerator.getUserInfoFromMemberId(memberId);
  }

  /// Get current user's Member ID
  Future<String?> _getCurrentUserMemberId() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return null;

    final userDoc =
        await _firestore.collection('users').doc(currentUser.uid).get();
    if (!userDoc.exists) return null;

    return userDoc.data()?['memberId'] as String?;
  }

  /// Convert Firebase UID to Member ID for existing references
  Future<String?> _getUidToMemberId(String uid) async {
    try {
      final userDoc = await _firestore.collection('users').doc(uid).get();
      if (!userDoc.exists) return null;

      return userDoc.data()?['memberId'] as String?;
    } catch (e) {
// print('Error converting UID to Member ID: $e');
      return null;
    }
  }

  // 🚀 Add role operation
  Future<void> _performAddRole() async {
    // 🎯 Use _selectedUser (modern system) for Member ID
    final targetMemberId = _selectedUser?['memberId'] ?? '';

    if (targetMemberId.isEmpty || _selectedRole == null) {
      setState(() {
        _message = 'Please enter a Member ID and select a role!';
        _isLoading = false;
      });
      return;
    }

    // Convert Member ID to UID for internal operations

    final targetUserId = await _getUidFromMemberId(targetMemberId);

    if (targetUserId == null) {
      setState(() {
        _message =
            'Member ID not found. Please check the Member ID and try again.';
        _isLoading = false;
      });
      return;
    }

    // Prevent admin role assignment completely
    if (_selectedRole == 'admin') {
      setState(() {
        _message =
            'Admin role cannot be assigned. Only system administrators can be admin.';
        _isLoading = false;
      });
      return;
    }

    try {
      // Check if user already has this role
      bool hasExistingRole =
          _existingUserRoles.any((r) => r['role'] == _selectedRole);

      if (hasExistingRole) {
        setState(() {
          _message =
              'User already has the ${_getRoleTitle(_selectedRole!)} role!';
          _isLoading = false;
        });
        return;
      }

      // Proceed with adding the role

      setState(() => _isAddingNewRole = true);

      _performMultiRoleAssignment();
    } catch (e) {
      setState(() {
        _message = 'An error occurred: $e';
        _isLoading = false;
      });
    }
  }

  String _getRoleTitle(String role) {
    switch (role) {
      case 'admin':
        return 'Admin';
      case 'moderator':
        return 'Moderator';
      case 'director':
        return 'Director';
      case 'middleSchoolCoordinator':
        return 'Middle School Coordinator';
      case 'highSchoolCoordinator':
        return 'High School Coordinator';
      case 'universityCoordinator':
        return 'University Coordinator';
      case 'housingCoordinator':
        return 'Housing Coordinator';
      case 'middleSchoolAssistantCoordinator':
        return 'Middle School Assistant Coordinator';
      case 'highSchoolAssistantCoordinator':
        return 'High School Assistant Coordinator';
      case 'universityAssistantCoordinator':
        return 'University Assistant Coordinator';
      case 'housingAssistantCoordinator':
        return 'Housing Assistant Coordinator';
      case 'middleSchoolMentor':
        return 'Middle School Mentor';
      case 'highSchoolMentor':
        return 'High School Mentor';
      case 'houseLeader':
        return 'House Leader';
      case 'studentHouseLeader':
        return 'Student House Leader'; // 🎯 NEW: Student house leader title
      case 'houseMember':
        return 'House Member'; // 🎯 NEW: House member title
      case 'studentHouseMember':
        return 'Student House Member'; // 🎯 NEW: Student house member title
      case 'accountant':
        return 'Accountant';
      case 'user':
        return 'User';
      default:
        return 'User';
    }
  }

  IconData _getRoleIcon(String role) {
    switch (role) {
      case 'moderator':
        return Icons.security;
      case 'director':
        return Icons.flag;
      case 'middleSchoolCoordinator':
      case 'highSchoolCoordinator':
      case 'universityCoordinator':
      case 'housingCoordinator':
        return Icons.location_city;
      case 'middleSchoolAssistantCoordinator':
      case 'highSchoolAssistantCoordinator':
      case 'universityAssistantCoordinator':
      case 'housingAssistantCoordinator':
        return Icons.business;
      case 'middleSchoolMentor':
      case 'highSchoolMentor':
        return Icons.school;
      case 'houseLeader':
        return Icons.home;
      case 'studentHouseLeader':
        return Icons.home_work; // 🎯 NEW: Student house leader icon
      case 'houseMember':
        return Icons.people; // 🎯 NEW: House member icon
      case 'studentHouseMember':
        return Icons.groups; // 🎯 NEW: Student house member icon
      case 'accountant':
        return Icons.account_balance;
      case 'user':
        return Icons.account_circle;
      default:
        return Icons.account_circle;
    }
  }

  @override
  void initState() {
    super.initState();
    // Legacy listeners removed

    // 🚀 NEW: Modern search listeners
    _searchController.addListener(_onSearchChanged);

    // Initialize slide animation controller
    _slideAnimationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.0, 0.0), // Start at normal position
      end: const Offset(0.0, 1.0), // Slide down (off screen)
    ).animate(CurvedAnimation(
      parent: _slideAnimationController,
      curve: Curves.easeInOut,
    ));

    // 🎯 NEW: Detect current user role for permission system
    _detectCurrentUserRole();
  }

  // 🎯 NEW: Detect current user's highest role for permission system
  Future<void> _detectCurrentUserRole() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      final userDoc =
          await _firestore.collection('users').doc(currentUser.uid).get();
      if (!userDoc.exists) return;

      final userData = userDoc.data()!;
      final roles = userData['roles'] as List<dynamic>?;

      if (roles != null && roles.isNotEmpty) {
        _currentUserRoles = [];
        for (var roleObj in roles) {
          if (roleObj is Map<String, dynamic>) {
            final role = roleObj['role'] as String?;
            if (role != null) {
              _currentUserRoles.add(role);
            }
          }
        }
      }

      // Get highest ranking role for permission checks
      _currentUserRole = _getHighestRankingRole(_currentUserRoles);

      if (mounted) {
        setState(() {
          // Permissions will be checked dynamically in UI methods
        });
      }
    } catch (e) {
      // Handle error silently - default to no permissions
      _currentUserRole = 'user';
      _currentUserRoles = ['user'];
    }
  }

  // 🎯 NEW: Extract user roles from user data
  List<String> _extractUserRoles(Map<String, dynamic> userData) {
    final roles = userData['roles'] as List<dynamic>?;
    List<String> userRoles = [];

    if (roles != null && roles.isNotEmpty) {
      for (var roleObj in roles) {
        if (roleObj is Map<String, dynamic>) {
          final role = roleObj['role'] as String?;
          if (role != null) {
            userRoles.add(role);
          }
        }
      }
    } else {
      // Fallback to old role system
      final role = userData['role'] as String?;
      if (role != null) {
        userRoles.add(role);
      }
    }

    // If no roles found, default to user
    if (userRoles.isEmpty) {
      userRoles.add('user');
    }

    return userRoles;
  }

  // 🚀 NEW: Modern search system methods
  void _onSearchChanged() {
    final query = _searchController.text.trim();

    // 🚀 Clear success message when user starts typing
    if (query.isNotEmpty) {
      _clearSuccessMessage();
    }

    // 🎯 FIX: Clear error messages and selected user when starting new search
    if (query.isNotEmpty &&
        ((_message.isNotEmpty && !_message.contains('successfully')) ||
            _selectedUser != null)) {
      setState(() {
        if (!_message.contains('successfully')) {
          _message = ''; // Clear error messages only
        }
        _selectedUser = null; // Clear selected user
        _targetUserName = null; // Clear target user name
        _existingUserRoles = []; // Clear existing roles
      });
    }

    if (_searchDebounce?.isActive ?? false) _searchDebounce!.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      _performSearch(query, 'main');
    });
  }

  Future<void> _performSearch(String query, String searchType) async {
    if (query.length < 2) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    // 🚀 PERFORMANCE: Check cache first
    final cacheKey = query.toLowerCase().trim();
    final cachedTime = _cacheTimestamps[cacheKey];
    if (cachedTime != null &&
        DateTime.now().difference(cachedTime) < _cacheExpiry &&
        _searchCache.containsKey(cacheKey)) {
      setState(() {
        _searchResults = _searchCache[cacheKey]!;
        _isSearching = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
    });

    try {
      final List<Map<String, dynamic>> results = [];

      // 🎯 NEW: Determine if this is a Member ID search
      bool isMemberIdSearch =
          query.length >= 8 && !query.contains(' ') && !query.contains('@');
      bool foundDirectMatch = false;

      if (isMemberIdSearch) {
        try {
          // 🎉 NEW: First try Member ID search
          final userInfo = await _getUserInfoFromMemberId(query);
          if (userInfo != null) {
            userInfo['id'] = userInfo['uid']; // Use UID as id for consistency
            results.add(userInfo);
            foundDirectMatch = true;
          } else {
            // 🎯 FALLBACK: Try as Firebase UID (backward compatibility)
            final directDoc =
                await _firestore.collection('users').doc(query).get();
            if (directDoc.exists) {
              final data = directDoc.data()!;
              data['id'] = query;
              results.add(data);
              foundDirectMatch = true;
            }
          }
        } catch (e) {
          // Ignore errors for direct ID search
        }
      }

      // 🎯 NEW: Name/email/username search with permission filtering
      if (!foundDirectMatch || query.length < 15) {
        // Continue searching even if direct match found (for short queries)
        // Get all users first, then filter both by text match AND role
        final allUsersSnapshot = await _firestore
            .collection('users')
            .limit(50) // Get more users to filter from
            .get();

        final queryLower = query.toLowerCase();
        final Set<String> addedIds = {};

        for (final doc in allUsersSnapshot.docs) {
          if (addedIds.contains(doc.id)) continue;

          final data = doc.data();
          final firstName = (data['firstName'] as String?)?.toLowerCase() ?? '';
          final lastName = (data['lastName'] as String?)?.toLowerCase() ?? '';
          final username = (data['username'] as String?)?.toLowerCase() ?? '';
          final email = (data['email'] as String?)?.toLowerCase() ?? '';
          final fullName = '$firstName $lastName'.trim();

          // 🔍 CASE-INSENSITIVE: Check if query matches any field
          bool matchesText = firstName.contains(queryLower) ||
              lastName.contains(queryLower) ||
              fullName.contains(queryLower) ||
              username.contains(queryLower) ||
              email.contains(queryLower);

          if (matchesText) {
            // 🎯 NEW: Apply role-based permission filtering for name searches
            if (!isMemberIdSearch && _currentUserRole != null) {
              // Get user's roles for permission check
              final userRoles = _extractUserRoles(data);

              // Check if current user can search this user by name
              if (!RolePermissions.canSearchUserByName(
                  _currentUserRole!, userRoles)) {
                continue; // Skip this user - no permission to find by name
              }
            }
            // 🔒 SECURITY: Check user's role - only show non-"user" roles in search results
            // But allow "user" role if found by direct ID match
            bool canShow = false;

            // Check roles array (new system)
            final roles = data['roles'] as List<dynamic>?;
            if (roles != null && roles.isNotEmpty) {
              for (var roleObj in roles) {
                if (roleObj is Map<String, dynamic>) {
                  final role = roleObj['role'] as String?;
                  if (role != null && role != 'user') {
                    canShow = true;
                    break;
                  }
                }
              }
            } else {
              // Fallback to old role system
              final role = data['role'] as String?;
              if (role != null && role != 'user') {
                canShow = true;
              }
            }

            // Always show if found by direct ID (security exception)
            if (doc.id == query) {
              canShow = true;
            }

            if (canShow) {
              data['id'] = doc.id;
              results.add(data);
              addedIds.add(doc.id);
            }
          }
        }
      }

      // 🔍 ENHANCED SORTING: Better relevance ranking with case-insensitive matching
      results.sort((a, b) {
        final aName = '${a['firstName'] ?? ''} ${a['lastName'] ?? ''}'
            .toLowerCase()
            .trim();
        final bName = '${b['firstName'] ?? ''} ${b['lastName'] ?? ''}'
            .toLowerCase()
            .trim();
        final aUsername = (a['username'] as String?)?.toLowerCase() ?? '';
        final bUsername = (b['username'] as String?)?.toLowerCase() ?? '';
        final aEmail = (a['email'] as String?)?.toLowerCase() ?? '';
        final bEmail = (b['email'] as String?)?.toLowerCase() ?? '';
        final queryLower = query.toLowerCase();

        // Direct ID match gets highest priority
        if (a['id'] == query && b['id'] != query) return -1;
        if (b['id'] == query && a['id'] != query) return 1;

        // Exact full name match
        if (aName == queryLower && bName != queryLower) return -1;
        if (bName == queryLower && aName != queryLower) return 1;

        // Username exact match
        if (aUsername == queryLower && bUsername != queryLower) return -1;
        if (bUsername == queryLower && aUsername != queryLower) return 1;

        // Email exact match
        if (aEmail == queryLower && bEmail != queryLower) return -1;
        if (bEmail == queryLower && aEmail != queryLower) return 1;

        // First name starts with query
        final aFirstName = (a['firstName'] as String?)?.toLowerCase() ?? '';
        final bFirstName = (b['firstName'] as String?)?.toLowerCase() ?? '';
        if (aFirstName.startsWith(queryLower) &&
            !bFirstName.startsWith(queryLower)) return -1;
        if (bFirstName.startsWith(queryLower) &&
            !aFirstName.startsWith(queryLower)) return 1;

        // Last name starts with query
        final aLastName = (a['lastName'] as String?)?.toLowerCase() ?? '';
        final bLastName = (b['lastName'] as String?)?.toLowerCase() ?? '';
        if (aLastName.startsWith(queryLower) &&
            !bLastName.startsWith(queryLower)) return -1;
        if (bLastName.startsWith(queryLower) &&
            !aLastName.startsWith(queryLower)) return 1;

        // Full name starts with query
        if (aName.startsWith(queryLower) && !bName.startsWith(queryLower))
          return -1;
        if (bName.startsWith(queryLower) && !aName.startsWith(queryLower))
          return 1;

        // Username starts with query
        if (aUsername.startsWith(queryLower) &&
            !bUsername.startsWith(queryLower)) return -1;
        if (bUsername.startsWith(queryLower) &&
            !aUsername.startsWith(queryLower)) return 1;

        // Alphabetical by full name
        return aName.compareTo(bName);
      });

      if (!mounted) return;

      // 🚀 PERFORMANCE: Cache results for future use
      final finalResults = results.take(8).toList();
      _searchCache[cacheKey] = finalResults;
      _cacheTimestamps[cacheKey] = DateTime.now();

      // Clean old cache entries (keep only last 20)
      if (_searchCache.length > 20) {
        final oldestKey = _cacheTimestamps.entries
            .reduce((a, b) => a.value.isBefore(b.value) ? a : b)
            .key;
        _searchCache.remove(oldestKey);
        _cacheTimestamps.remove(oldestKey);
      }

      setState(() {
        _searchResults = finalResults;
        _isSearching = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _searchResults = [];
        _isSearching = false;
        _error = _getSearchErrorMessage(e);
      });

      // Clear error after 3 seconds
      Timer(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() => _error = null);
        }
      });
    }
  }

  // Manual cache clear method (unused)
  /* void _clearSearchCache() {
    setState(() {
      _searchCache.clear();
      _cacheTimestamps.clear();
    });
  } */

  String _getSearchErrorMessage(dynamic error) {
    final errorString = error.toString().toLowerCase();

    if (errorString.contains('network') || errorString.contains('connection')) {
      return 'No internet connection. Please check your network.';
    } else if (errorString.contains('permission') ||
        errorString.contains('denied')) {
      return 'Permission denied. Please contact support.';
    } else if (errorString.contains('timeout')) {
      return 'Search timed out. Please try again.';
    } else {
      return 'Search failed. Please try again.';
    }
  }

  Future<void> _checkNetworkConnectivity() async {
    try {
      // Simple connectivity check with timeout
      await _firestore
          .collection('users')
          .limit(1)
          .get()
          .timeout(const Duration(seconds: 5));
    } catch (e) {
      throw Exception(
          'Network connection failed. Please check your internet connection.');
    }
  }

  String _getAssignRoleErrorMessage(dynamic error) {
    final errorString = error.toString().toLowerCase();

    if (errorString.contains('network') || errorString.contains('connection')) {
      return 'Network error. Please check your internet connection and try again.';
    } else if (errorString.contains('permission') ||
        errorString.contains('denied')) {
      return 'Permission denied. You may not have the required permissions.';
    } else if (errorString.contains('timeout')) {
      return 'Operation timed out. Please try again.';
    } else if (errorString.contains('firebase') ||
        errorString.contains('firestore')) {
      return 'Database error. Please try again later.';
    } else {
      return 'Role assignment failed. Please try again.';
    }
  }

  //

  //

  Future<void> _fetchMentorshipGroupsForUnit(String unitPath) async {
    // 🚀 PERFORMANCE: Check mentorship groups cache first
    final cacheKey = unitPath;
    final cachedTime = _mentorshipCacheTimestamps[cacheKey];
    if (cachedTime != null &&
        DateTime.now().difference(cachedTime) < _cacheExpiry &&
        _mentorshipGroupsCache.containsKey(cacheKey)) {
      // 🎯 PRESERVE: Keep selected mentorship group ID when using cache
      final previouslySelectedGroupId = _selectedMentorshipGroupId;

      setState(() {
        final cachedGroups = _mentorshipGroupsCache[cacheKey]!;

        // 🎯 PRESERVE: Keep any pending groups that were created locally
        final existingPendingGroups =
            _mentorshipGroups.where((g) => g['isPending'] == true).toList();
        _mentorshipGroups = [...cachedGroups, ...existingPendingGroups];

        _isLoadingGroups = false;

        // 🎯 RESTORE: Restore previously selected group if it still exists in cache
        if (previouslySelectedGroupId != null) {
          final groupStillExists = _mentorshipGroups
              .any((g) => g['id'] == previouslySelectedGroupId);
          if (groupStillExists) {
            _selectedMentorshipGroupId = previouslySelectedGroupId;
          } else {}
        }
      });
      return;
    }

    // 🎯 PRESERVE: Keep selected mentorship group ID when refetching
    final previouslySelectedGroupId = _selectedMentorshipGroupId;

    setState(() {
      _isLoadingGroups = true;
      _mentorshipGroups = [];
      _selectedMentorshipGroupId =
          null; // Temporarily clear, will restore if group still exists
    });

    try {
      final unitRef = _firestore.doc(unitPath);
      final groupsSnapshot = await _firestore
          .collection('organizationalUnits')
          .where('parentUnit', isEqualTo: unitRef)
          .where('type', isEqualTo: 'mentorshipGroup')
          .get();

      // Determine expected mentor role based on supervisor's role
      String? expectedMentorRole;
      if (_supervisorUserRole?.contains('middleSchool') == true) {
        expectedMentorRole = 'middleSchoolMentor';
      } else if (_supervisorUserRole?.contains('highSchool') == true) {
        expectedMentorRole = 'highSchoolMentor';
      }

      Map<String, String> mentorNames = {};
      List<String> mentorIds = groupsSnapshot.docs
          .map((doc) => doc.data()['currentMentorId'] as String?)
          .where((id) => id != null)
          .cast<String>()
          .toList();

      if (mentorIds.isNotEmpty) {
        final mentorDocs = await _firestore
            .collection('users')
            .where(FieldPath.documentId, whereIn: mentorIds)
            .get();

        // Filter mentors by role compatibility and get names
        for (var doc in mentorDocs.docs) {
          final userData = doc.data();
          final roles = userData['roles'] as List<dynamic>?;

          // Check if mentor has the expected role
          bool hasCorrectRole = false;
          if (roles != null && expectedMentorRole != null) {
            hasCorrectRole = roles.any((role) =>
                role is Map<String, dynamic> &&
                role['role'] == expectedMentorRole);
          }

          // Only include mentors with correct role, or if no role filtering needed
          if (expectedMentorRole == null || hasCorrectRole) {
            mentorNames[doc.id] = _getFullNameFromFields(
                userData['firstName'], userData['lastName']);
          }
        }
      }

      final List<Map<String, dynamic>> groups = groupsSnapshot.docs.map((doc) {
        final data = doc.data();
        final currentMentorId = data['currentMentorId'] as String?;
        return {
          'id': doc.id,
          'name': data['name'] ?? 'Unnamed Group',
          'currentMentorId': currentMentorId,
          'mentorName':
              currentMentorId != null ? mentorNames[currentMentorId] : null,
        };
      }).toList();

      // 🎯 PRESERVE: Keep any pending groups that were created locally
      final existingPendingGroups =
          _mentorshipGroups.where((g) => g['isPending'] == true).toList();
      groups.addAll(existingPendingGroups);

      if (mounted) {
        // 🚀 PERFORMANCE: Cache mentorship groups results
        _mentorshipGroupsCache[cacheKey] = groups;
        _mentorshipCacheTimestamps[cacheKey] = DateTime.now();

        // Clean old mentorship cache entries (keep only last 15)
        if (_mentorshipGroupsCache.length > 15) {
          final oldestKey = _mentorshipCacheTimestamps.entries
              .reduce((a, b) => a.value.isBefore(b.value) ? a : b)
              .key;
          _mentorshipGroupsCache.remove(oldestKey);
          _mentorshipCacheTimestamps.remove(oldestKey);
        }

        setState(() {
          _mentorshipGroups = groups;
          _isLoadingGroups = false;

          // 🎯 RESTORE: Restore previously selected group if it still exists
          if (previouslySelectedGroupId != null) {
            final groupStillExists =
                groups.any((g) => g['id'] == previouslySelectedGroupId);
            if (groupStillExists) {
              _selectedMentorshipGroupId = previouslySelectedGroupId;
            } else {}
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingGroups = false;
          _message = "An error occurred while fetching classes: $e";
        });
      }
    }
  }

  void _createMentorshipGroup(int grade, String unitType) {
    // 🎯 NEW SYSTEM: No supervisor unit path required - class created before supervisor selection
    final gradeNameBase = _getBaseGradeName(grade, unitType);

    final allGroupsForGrade = _mentorshipGroups
        .where((doc) => (doc['name'] as String).startsWith(gradeNameBase))
        .toList();

    final newSuffix =
        String.fromCharCode('A'.codeUnitAt(0) + allGroupsForGrade.length);
    final newGroupName = '$gradeNameBase - $newSuffix';

    final tempId = 'pending_${DateTime.now().millisecondsSinceEpoch}';

    final newGroupData = {
      'id': tempId,
      'name': newGroupName,
      'currentMentorId': null,
      'mentorName': null,
      'isPending': true,
    };

    setState(() {
      _mentorshipGroups.add(newGroupData);
      _selectedMentorshipGroupId = tempId;
      _selectedMentorshipGroupName = newGroupName; // 🎯 Cache name immediately
      _message = '';
    });
  }

  // _deleteClass no longer used; class deletion is managed by group list edits

  void _showCreateGroupDialog() async {
    // 🎯 NEW SYSTEM: Determine school type from selected role instead of supervisor
    String? supervisorRole;

    // For mentors, use the selected role to determine school type
    if (_selectedRole == 'middleSchoolMentor') {
      supervisorRole =
          'middleSchoolAssistantCoordinator'; // Any role containing 'middleSchool'
    } else if (_selectedRole == 'highSchoolMentor') {
      supervisorRole =
          'highSchoolAssistantCoordinator'; // Any role containing 'highSchool'
    }

    if (supervisorRole == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                "Class creation is only available for Middle School and High School mentors.")),
      );
      return;
    }

    String unitType;
    List<int> allGrades;

    if (supervisorRole.contains('highSchool')) {
      unitType = 'highSchool';
      allGrades = [9, 10, 11, 12];
    } else if (supervisorRole.contains('middleSchool')) {
      unitType = 'middleSchool';
      allGrades = [6, 7, 8];
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                "Class creation is only available for High School and Middle School mentors.")),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withOpacity(0.95),
                  Colors.white.withOpacity(0.85),
                ],
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withOpacity(0.3)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 25,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.orange.withOpacity(0.1),
                        Colors.deepOrange.withOpacity(0.1),
                      ],
                    ),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(24),
                      topRight: Radius.circular(24),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(
                          Icons.school_rounded,
                          color: Colors.orange,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Create New Class',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Choose a grade level for the new class',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Content
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      ...allGrades.map((grade) {
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          width: double.infinity,
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () {
                                Navigator.of(context).pop();
                                _createMentorshipGroup(grade, unitType);
                              },
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.orange.withOpacity(0.08),
                                      Colors.deepOrange.withOpacity(0.05),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: Colors.orange.withOpacity(0.2),
                                    width: 1.5,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.orange.withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        grade.toString(),
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.orange,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Text(
                                        _getBaseGradeName(grade, unitType),
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.black87,
                                        ),
                                      ),
                                    ),
                                    Icon(
                                      Icons.arrow_forward_ios_rounded,
                                      size: 16,
                                      color: Colors.grey.shade400,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      }),

                      const SizedBox(height: 16),

                      // Cancel Button
                      SizedBox(
                        width: double.infinity,
                        child: TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: Text(
                            'Cancel',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(
            height: MediaQuery.of(context).size.height,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF8EC5FC), Color(0xFFE0C3FC)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: SafeArea(
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: MediaQuery.of(context).size.width > 600 ? 40 : 20,
                  vertical: MediaQuery.of(context).size.width > 600 ? 20 : 16,
                ),
                child: Column(
                  children: [
                    // Header with back button and title - Responsive centered
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final buttonWidth =
                            MediaQuery.of(context).size.width > 600
                                ? 56.0
                                : 48.0;
                        final iconSize = MediaQuery.of(context).size.width > 600
                            ? 26.0
                            : 24.0;

                        return Row(
                          children: [
                            SizedBox(
                              width: buttonWidth,
                              child: IconButton(
                                onPressed: () {
                                  HapticFeedback.lightImpact();
                                  Navigator.of(context).pop();
                                },
                                icon: Icon(
                                  Icons.arrow_back_ios,
                                  color: Colors.white,
                                  size: iconSize,
                                ),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                splashRadius:
                                    MediaQuery.of(context).size.width > 600
                                        ? 28
                                        : 24,
                              ),
                            ),
                            Expanded(
                              child: Text(
                                'Assign User Role',
                                style: TextStyle(
                                  fontSize: _getResponsiveTitleSize(context),
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  letterSpacing: -0.5,
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            SizedBox(
                                width: buttonWidth), // Balance the left button
                          ],
                        );
                      },
                    ),
                    SizedBox(
                        height:
                            MediaQuery.of(context).size.width > 600 ? 16 : 12),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal:
                            MediaQuery.of(context).size.width > 600 ? 20 : 16,
                        vertical:
                            MediaQuery.of(context).size.width > 600 ? 10 : 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(
                          MediaQuery.of(context).size.width > 600 ? 24 : 20,
                        ),
                        border:
                            Border.all(color: Colors.white.withOpacity(0.3)),
                      ),
                      child: Text(
                        'Step $_currentStep of $_totalSteps',
                        style: TextStyle(
                          fontSize: _getResponsiveStepSize(context),
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),

                    SizedBox(
                        height:
                            MediaQuery.of(context).size.width > 600 ? 20 : 16),

                    // Modern Progress bar with steps - Fully responsive
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final screenWidth = MediaQuery.of(context).size.width;
                        final horizontalMargin = screenWidth > 600
                            ? 40.0
                            : screenWidth > 400
                                ? 20.0
                                : 16.0;

                        return Container(
                          margin: EdgeInsets.symmetric(
                            horizontal: horizontalMargin,
                            vertical: screenWidth > 600 ? 8 : 6,
                          ),
                          child: Column(
                            children: [
                              // Step indicators
                              Row(
                                children: List.generate(_totalSteps, (index) {
                                  final stepNumber = index + 1;
                                  final isActive = stepNumber <= _currentStep;

                                  return Expanded(
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: AnimatedContainer(
                                            duration: const Duration(
                                                milliseconds: 300),
                                            height: 4,
                                            decoration: BoxDecoration(
                                              borderRadius:
                                                  BorderRadius.circular(2),
                                              color: isActive
                                                  ? Colors.white
                                                  : Colors.white
                                                      .withOpacity(0.3),
                                            ),
                                          ),
                                        ),
                                        if (index < _totalSteps - 1)
                                          const SizedBox(width: 8),
                                      ],
                                    ),
                                  );
                                }),
                              ),
                              const SizedBox(height: 8),
                              // Step dots
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: List.generate(_totalSteps, (index) {
                                  final stepNumber = index + 1;
                                  final isActive = stepNumber <= _currentStep;
                                  final isCurrent = stepNumber == _currentStep;

                                  return AnimatedContainer(
                                    duration: const Duration(milliseconds: 300),
                                    width: isCurrent ? 12 : 8,
                                    height: isCurrent ? 12 : 8,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: isActive
                                          ? Colors.white
                                          : Colors.white.withOpacity(0.4),
                                      boxShadow: isCurrent
                                          ? [
                                              BoxShadow(
                                                color: Colors.white
                                                    .withOpacity(0.5),
                                                blurRadius: 8,
                                                offset: const Offset(0, 2),
                                              ),
                                            ]
                                          : null,
                                    ),
                                  );
                                }),
                              ),
                            ],
                          ),
                        );
                      },
                    ),

                    // Step content - Responsive glassmorphic container with accessibility
                    Expanded(
                      child: Semantics(
                        label:
                            'Role assignment step $_currentStep of $_totalSteps',
                        child: Container(
                          margin: const EdgeInsets.only(top: 0),
                          padding: EdgeInsets.all(
                            _getResponsiveContentPadding(context),
                          ),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Colors.white.withOpacity(0.15),
                                Colors.white.withOpacity(0.08),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(
                              MediaQuery.of(context).size.width > 600 ? 28 : 20,
                            ),
                            border: Border.all(
                                color: Colors.white.withOpacity(0.3)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius:
                                    MediaQuery.of(context).size.width > 600
                                        ? 25
                                        : 15,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: _buildCurrentStep(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Success message overlay
          _buildEnhancedSuccessMessage(),
        ],
      ),
    );
  }

  Widget _buildCurrentStep() {
    Widget stepWidget;
    switch (_currentStep) {
      case 1:
        stepWidget = _buildUserIdStep();
        break;
      case 2:
        stepWidget = _buildRoleStep();
        break;
      case 3:
        stepWidget =
            _buildDetailsStep(); // 🎯 REORDERED: Location Details moved to Step 3
        break;
      case 4:
        stepWidget =
            _buildSupervisorStep(); // 🎯 REORDERED: Supervisor moved to Step 4
        break;
      case 5:
        stepWidget = _buildOrphanedUnitsChoiceStep();
        break;
      default:
        stepWidget = _buildUserIdStep();
    }

    // 🎨 ANIMATION: Smooth step transitions
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 400),
      transitionBuilder: (Widget child, Animation<double> animation) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0.3, 0.0),
            end: Offset.zero,
          ).animate(CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          )),
          child: FadeTransition(
            opacity: animation,
            child: child,
          ),
        );
      },
      child: Container(
        key: ValueKey(_currentStep),
        child: stepWidget,
      ),
    );
  }

  Widget _buildUserIdStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment:
          MainAxisAlignment.start, // 🎯 Force content to start from top
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 🚀 NEW: Modern User Search
                _buildModernUserSearch(
                  title: 'Find User',
                  subtitle: 'Search for the user you want to assign a role to.',
                  controller: _searchController,
                  searchResults: _searchResults,
                  isSearching: _isSearching,
                  selectedUser: _selectedUser,
                  onUserSelected: (user) {
                    setState(() {
                      if (user.containsKey('clear')) {
                        // Clear selected user
                        _selectedUser = null;
                        _targetUserName = null;
                        // _targetUserRole removed
                        _existingUserRoles = [];
                        _searchResults = [];
                        // Legacy controller removed
                      } else {
                        _selectedUser = user;

                        // Update legacy variables for backward compatibility
                        _targetUserName =
                            '${user['firstName'] ?? ''} ${user['lastName'] ?? ''}'
                                .trim();
                        // _targetUserRole removed; roles are shown via _existingUserRoles

                        // 🔧 FIX: Store the UID separately for reliable access

                        // Legacy controller removed

                        // Clear search results
                        _searchResults = [];
                        _searchController.clear();

                        // Fetch existing roles for the selected user
                        _getExistingRoles(user['id']).then((roles) {
                          if (mounted) {
                            setState(() {
                              _existingUserRoles = roles;
                            });
                          }
                        });
                      }
                    });
                  },
                  placeholder: "",
                ),

                const SizedBox(height: 40),

                // Navigation buttons
                Row(
                  children: [
                    const Spacer(),
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        color: _selectedUser != null
                            ? Colors.green.withOpacity(0.3)
                            : Colors.white.withOpacity(0.2),
                        border: Border.all(
                          color: _selectedUser != null
                              ? Colors.green.withOpacity(0.5)
                              : Colors.white.withOpacity(0.4),
                        ),
                        boxShadow: _selectedUser != null
                            ? [
                                BoxShadow(
                                  color: Colors.green.withOpacity(0.2),
                                  blurRadius: 15,
                                  offset: const Offset(0, 8),
                                ),
                              ]
                            : [],
                      ),
                      child: ElevatedButton.icon(
                        onPressed: _selectedUser != null ? _goToNextStep : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          foregroundColor: Colors.white,
                          shadowColor: Colors.transparent,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 32, vertical: 16),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20)),
                        ),
                        icon: const Icon(Icons.arrow_forward_rounded, size: 20),
                        label: const Text('Next',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRoleStep() {
    return SingleChildScrollView(
      controller: _scrollController,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Current roles section - Clean design
          if (_existingUserRoles.isNotEmpty) ...[
            Row(
              children: [
                Icon(
                  Icons.badge_outlined,
                  color: Colors.blue.shade300,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Text(
                  'Current Roles',
                  style: TextStyle(
                    fontSize: MediaQuery.of(context).size.width > 600 ? 24 : 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: Colors.white.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Check if user has any non-user roles
                  if (_existingUserRoles
                      .where((r) => r['role'] != 'user')
                      .isEmpty) ...[
                    RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: _targetUserName ?? 'User',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const TextSpan(
                            text: ' has no assigned roles yet.',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.grey.withOpacity(0.4)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.info_outline,
                              color: Colors.grey, size: 20),
                          SizedBox(width: 12),
                          Text(
                            'Ready to assign first role',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: _targetUserName ?? 'User',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const TextSpan(
                            text: ' has the following roles:',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Only show non-user roles - sorted by hierarchy
                    ...(_sortRolesByHierarchy(_existingUserRoles
                            .where((role) => role['role'] != 'user')
                            .toList())
                        .map((role) => Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              margin: const EdgeInsets.only(bottom: 8),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                    color: Colors.green.withOpacity(0.4)),
                              ),
                              child: Row(
                                children: [
                                  Icon(_getRoleIcon(role['role']),
                                      color: Colors.green, size: 20),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      _getRoleTitle(role['role']),
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold),
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 2,
                                    ),
                                  ),
                                ],
                              ),
                            ))
                        .toList()),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 30),
          ],

          // Operation selection - Clean design
          Row(
            children: [
              Icon(
                Icons.settings_applications,
                color: Colors.purple.shade300,
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                'Choose Operation',
                style: TextStyle(
                  fontSize: MediaQuery.of(context).size.width > 600 ? 24 : 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Modern operation buttons with better visual hierarchy
          LayoutBuilder(
            builder: (context, constraints) {
              final isWideScreen = constraints.maxWidth > 400;

              if (isWideScreen) {
                // Wide screen: Side by side buttons
                return IntrinsicHeight(
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildOperationButton(
                            'add',
                            'Add Role',
                            Icons.add_circle_outline,
                            Colors.green,
                            'Assign new role to user'),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildOperationButton(
                            'delete',
                            'Delete Role',
                            Icons.delete_outline,
                            Colors.red,
                            'Remove existing role'),
                      ),
                    ],
                  ),
                );
              } else {
                // Narrow screen: Stacked buttons
                return Column(
                  children: [
                    _buildOperationButton(
                        'add',
                        'Add Role',
                        Icons.add_circle_outline,
                        Colors.green,
                        'Assign new role to user'),
                    const SizedBox(height: 12),
                    _buildOperationButton(
                        'delete',
                        'Delete Role',
                        Icons.delete_outline,
                        Colors.red,
                        'Remove existing role'),
                  ],
                );
              }
            },
          ),

          const SizedBox(height: 30),

          // Role selection based on operation
          if (_showRoleSelection) ...[
            _buildRoleSelectionForOperation(),
            const SizedBox(height: 20),
          ],

          // Summary section
          if (_currentOperation.isNotEmpty && _canShowSummary()) ...[
            _buildOperationSummary(),
            const SizedBox(height: 30),
          ],

          // Navigation buttons
          Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: Colors.white.withOpacity(0.2),
                  border: Border.all(color: Colors.white.withOpacity(0.3)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ElevatedButton.icon(
                  onPressed: _goToPreviousStep,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    shadowColor: Colors.transparent,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 32, vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20)),
                  ),
                  icon: const Icon(Icons.arrow_back_rounded, size: 20),
                  label: const Text('Back',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
              const Spacer(),
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: _canProceedToNext()
                      ? Colors.green.withOpacity(0.3)
                      : Colors.white.withOpacity(0.1),
                  border: Border.all(
                    color: _canProceedToNext()
                        ? Colors.green.withOpacity(0.5)
                        : Colors.white.withOpacity(0.2),
                  ),
                  boxShadow: _canProceedToNext()
                      ? [
                          BoxShadow(
                            color: Colors.green.withOpacity(0.2),
                            blurRadius: 15,
                            offset: const Offset(0, 8),
                          ),
                        ]
                      : [],
                ),
                child: ElevatedButton.icon(
                  onPressed: _canProceedToNext()
                      ? () {
                          HapticFeedback.mediumImpact();
                          _proceedToNextStep();
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    shadowColor: Colors.transparent,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 32, vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20)),
                  ),
                  icon: Icon(
                      _currentOperation == 'delete'
                          ? Icons.delete_forever
                          : Icons.arrow_forward_rounded,
                      size: 20),
                  label: Text(
                    _currentOperation == 'delete' ? 'Delete' : 'Next',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 🚀 Build operation button widget - Compact version without description
  Widget _buildOperationButton(String operation, String title, IconData icon,
      Color color, String description) {
    final isSelected = _currentOperation == operation;

    return AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        constraints: BoxConstraints(
          minHeight: MediaQuery.of(context).size.width > 600
              ? 120
              : 100, // Reduced height
          minWidth: double.infinity,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: isSelected
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    color.withOpacity(0.3),
                    color.withOpacity(0.1),
                  ],
                )
              : LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withOpacity(0.15),
                    Colors.white.withOpacity(0.05),
                  ],
                ),
          border: Border.all(
            color: isSelected
                ? color.withOpacity(0.6)
                : Colors.white.withOpacity(0.3),
            width: isSelected ? 2.5 : 1.5,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withOpacity(0.3),
                    blurRadius: 15,
                    offset: const Offset(0, 8),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: Material(
          color: Colors.transparent,
          child: Semantics(
            label: title,
            button: true,
            child: InkWell(
              onTap: () {
                HapticFeedback.lightImpact();
                _selectOperation(operation);
              },
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: MediaQuery.of(context).size.width > 600
                      ? 20
                      : 16, // Reduced padding
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.all(
                          10), // Slightly reduced icon padding
                      decoration: BoxDecoration(
                        color: color.withOpacity(isSelected ? 0.2 : 0.1),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        icon,
                        color: color,
                        size: MediaQuery.of(context).size.width > 600
                            ? 32
                            : 28, // Slightly smaller icon
                      ),
                    ),
                    const SizedBox(height: 8), // Reduced spacing
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: MediaQuery.of(context).size.width > 600
                            ? 18
                            : 16, // Slightly smaller text
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: -0.3,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    // Description removed for compact design
                  ],
                ),
              ),
            ),
          ),
        ));
  }

  // 🚀 Build role selection based on operation with smooth animation
  Widget _buildRoleSelectionForOperation() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutBack,
      child: _showRoleSelection
          ? _buildRoleSelectionContent()
          : const SizedBox.shrink(),
    );
  }

  // 🎯 Role selection content
  Widget _buildRoleSelectionContent() {
    switch (_currentOperation) {
      case 'add':
        return _buildAddRoleSelection();
      case 'delete':
        return _buildDeleteRoleSelection();
      default:
        return const SizedBox.shrink();
    }
  }

  // 🚀 Build add role selection
  Widget _buildAddRoleSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Enhanced role selection with visual hierarchy
        const Row(
          children: [
            Icon(Icons.add_circle_outline, color: Colors.green, size: 28),
            SizedBox(width: 12),
            Text(
              'Add New Role',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Enhanced role selection cards

        // Role selection cards with enhanced UI
        ..._buildRoleSelectionCards(),

        const SizedBox(height: 24),
      ],
    );
  }

  // 🚀 Build enhanced role selection cards with categories
  List<Widget> _buildRoleSelectionCards() {
    // 🎯 NEW: Filter roles based on current user permissions
    List<String> allowedRoles = _selectableRoles;
    if (_currentUserRole != null) {
      final assignableRoles =
          RolePermissions.getAssignableRoles(_currentUserRole!);
      if (!assignableRoles.contains('*')) {
        allowedRoles = _selectableRoles
            .where((role) => assignableRoles.contains(role))
            .toList();
      }
    }

    final selectableRoles = allowedRoles
        .where((role) =>
            !_existingUserRoles.any((existing) => existing['role'] == role))
        .toList();

    if (selectableRoles.isEmpty) {
      return [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.orange.withOpacity(0.2),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: Colors.orange.withOpacity(0.4)),
          ),
          child: const Row(
            children: [
              Icon(Icons.info_outline, color: Colors.orange, size: 24),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'No roles available to assign. This user already has all possible roles.',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
            ],
          ),
        ),
      ];
    }

    // 🚀 Categorize roles
    final Map<String, List<String>> roleCategories = {
      'Moderator': ['moderator'],
      'Director': ['director'],
      'Coordinators': [
        'middleSchoolCoordinator',
        'highSchoolCoordinator',
        'universityCoordinator',
        'housingCoordinator'
      ],
      'Assistant Coordinators': [
        'middleSchoolAssistantCoordinator',
        'highSchoolAssistantCoordinator',
        'universityAssistantCoordinator',
        'housingAssistantCoordinator'
      ],
      'Mentors': ['middleSchoolMentor', 'highSchoolMentor'],
      'House Leader': [
        'houseLeader',
        'studentHouseLeader'
      ], // 🎯 FIXED: Added studentHouseLeader
      'House Member': [
        'houseMember',
        'studentHouseMember'
      ], // 🎯 NEW: House member roles
      'Accountant': ['accountant'],
    };

    List<Widget> widgets = [];

    for (String category in roleCategories.keys) {
      final categoryRoles = roleCategories[category]!
          .where((role) => selectableRoles.contains(role))
          .toList();

      if (categoryRoles.isEmpty) continue;

      // Add category header
      widgets.add(_buildCategoryHeader(category));
      widgets.add(const SizedBox(height: 16));

      // Add roles for this category
      for (String role in categoryRoles) {
        widgets.add(_buildRoleCard(role));
        widgets.add(const SizedBox(height: 12));
      }

      widgets.add(const SizedBox(height: 12)); // Extra space between categories
    }

    return widgets;
  }

  // 🚀 Build category header (similar to supervisor page)
  Widget _buildCategoryHeader(String category) {
    Color categoryColor = _getCategoryColor(category);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: categoryColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            category,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    categoryColor.withOpacity(0.6),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 🚀 Get category color
  Color _getCategoryColor(String category) {
    switch (category) {
      case 'Moderator':
        return Colors.orange;
      case 'Director':
        return Colors.yellow;
      case 'Coordinators':
        return Colors.green;
      case 'Assistant Coordinators':
        return Colors.blue;
      case 'Mentors':
        return Colors.cyan;
      case 'House Leader':
        return Colors.deepPurple;
      case 'House Member':
        return Colors.purple; // 🎯 NEW: House member category color
      case 'Accountant':
        return Colors.teal;
      default:
        return Colors.orange;
    }
  }

  // 🚀 Build individual role card
  Widget _buildRoleCard(String role) {
    final isSelected = _selectedRole == role;
    final roleColor = _getRoleColor(role);

    return Container(
      margin: const EdgeInsets.only(bottom: 0),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            setState(() {
              _selectedRole = role;
              _message = '';

              // 🎯 CRITICAL FIX: Clear location state when role changes to prevent dropdown errors
              _selectedCountry = null;
              _selectedProvince = null;
              _selectedCity = null;
              _selectedUnitGender = null;

              // Also clear supervisor and other dependent states
              _selectedSupervisorId = null;
              _supervisorUserName = null;
              _supervisorUserRole = null;
              _supervisorRoleMatches = null;

              _isLoadingSupervisors = false;
              _supervisorsByCity = {};

              // Clear mentorship groups
              _selectedMentorshipGroupId = null;
              _selectedMentorshipGroupName = null;
              _mentorshipGroups = [];
              _isLoadingGroups = false;

              // Clear orphaned units state
              _hasOrphanedUnits = false;
              _availableOrphanedUnits = [];
              _orphanedUnitChoice = null;
              _selectedOrphanedUnitId = null;
            });
            // 🚀 Fetch supervisors when role is selected
            _fetchAvailableSupervisors();
          },
          borderRadius: BorderRadius.circular(15),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            height: 160, // Sabit yükseklik - daha büyük (accessibility için)
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isSelected
                  ? roleColor.withOpacity(0.2)
                  : Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(
                color: isSelected
                    ? roleColor.withOpacity(0.6)
                    : Colors.white.withOpacity(0.3),
                width: isSelected ? 2 : 1,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: roleColor.withOpacity(0.3),
                        blurRadius: 15,
                        offset: const Offset(0, 5),
                      ),
                    ]
                  : [],
            ),
            child: Stack(
              children: [
                // Ana içerik - check icon olmadan
                Row(
                  children: [
                    // Role icon
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: roleColor.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        _getRoleIcon(role),
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),

                    // Role details - tam genişlik
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _getRoleTitle(role),
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: roleColor.withOpacity(0.9),
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 8),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.supervisor_account,
                                color: Colors.white70,
                                size: 18,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: RichText(
                                  maxLines: 3,
                                  overflow: TextOverflow.clip,
                                  text: TextSpan(
                                    children: [
                                      const TextSpan(
                                        text: 'Supervisor: ',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Color(0xFFE6E6E6),
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      TextSpan(
                                        text: _getSupervisorDisplayText(role),
                                        style: const TextStyle(
                                          fontSize: 15,
                                          color: Colors.white,
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
                  ],
                ),

                // Check icon overlay - sağ üst köşe
                if (isSelected)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: const Icon(
                        Icons.check,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 🚀 Get role color
  Color _getRoleColor(String role) {
    switch (role) {
      case 'admin':
        return Colors.red;
      case 'moderator':
        return Colors.orange;
      case 'director':
        return Colors.yellow;
      case 'middleSchoolCoordinator':
      case 'highSchoolCoordinator':
      case 'universityCoordinator':
      case 'housingCoordinator':
        return Colors.green;
      case 'middleSchoolAssistantCoordinator':
      case 'highSchoolAssistantCoordinator':
      case 'universityAssistantCoordinator':
      case 'housingAssistantCoordinator':
        return Colors.blue;
      case 'middleSchoolMentor':
      case 'highSchoolMentor':
        return Colors.cyan;
      case 'houseLeader':
        return Colors.deepPurple;
      case 'studentHouseLeader':
        return Colors.deepPurple; // 🎯 NEW: Student house leader color
      case 'houseMember':
        return Colors.purple; // 🎯 NEW: House member color
      case 'studentHouseMember':
        return Colors.purple; // 🎯 NEW: Student house member color
      case 'accountant':
        return Colors.teal;
      case 'user':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  // 🚀 Get required supervisor role
  String _getRequiredSupervisorRole(String role) {
    switch (role) {
      case 'moderator':
        return 'admin';
      case 'director':
        return 'moderator';
      case 'middleSchoolCoordinator':
        return 'director';
      case 'highSchoolCoordinator':
        return 'director';
      case 'universityCoordinator':
        return 'director';
      case 'housingCoordinator':
        return 'director';
      case 'middleSchoolAssistantCoordinator':
        return 'middleSchoolCoordinator';
      case 'highSchoolAssistantCoordinator':
        return 'highSchoolCoordinator';
      case 'universityAssistantCoordinator':
        return 'universityCoordinator';
      case 'housingAssistantCoordinator':
        return 'housingCoordinator';
      case 'middleSchoolMentor':
        return 'middleSchoolAssistantCoordinator';
      case 'highSchoolMentor':
        return 'highSchoolAssistantCoordinator';
      case 'houseLeader':
        return 'housingAssistantCoordinator'; // 🎯 UPDATED: Housing assistant coordinator
      case 'studentHouseLeader':
        return 'universityAssistantCoordinator'; // 🎯 NEW: University assistant coordinator
      case 'houseMember':
        return 'houseLeader'; // 🎯 NEW: House member supervised by house leader
      case 'studentHouseMember':
        return 'studentHouseLeader'; // 🎯 NEW: Student house member supervised by student house leader
      case 'accountant':
        return 'director';
      default:
        return 'admin';
    }
  }

  // 🚀 Get supervisor display text for UI
  String _getSupervisorDisplayText(String role) {
    switch (role) {
      case 'middleSchoolMentor':
        return 'Middle School Assistant Coordinator';
      case 'highSchoolMentor':
        return 'High School Assistant Coordinator';
      case 'houseLeader':
        return 'Housing Assistant Coordinator'; // 🎯 UPDATED: Only housing assistant coordinator
      case 'studentHouseLeader':
        return 'University Assistant Coordinator'; // 🎯 NEW: University assistant coordinator
      case 'houseMember':
        return 'House Leader'; // 🎯 NEW: House member supervised by house leader
      case 'studentHouseMember':
        return 'Student House Leader'; // 🎯 NEW: Student house member supervised by student house leader
      default:
        return _getRoleTitle(_getRequiredSupervisorRole(role));
    }
  }

  // 🚀 Build delete role selection
  Widget _buildDeleteRoleSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Enhanced delete section with warning
        Row(
          children: [
            const Icon(Icons.delete_outline, color: Colors.red, size: 28),
            const SizedBox(width: 12),
            const Text(
              'Remove Role',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Important notice section
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.orange.withOpacity(0.15),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: Colors.orange.withOpacity(0.4)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.orange, size: 24),
                  SizedBox(width: 12),
                  Text(
                    'Important Notice',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                'When you remove a role, it affects the person\'s responsibilities and may require reassigning their team members to new supervisors.',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'What happens?',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (_selectedExistingRole == 'houseMember' ||
                        _selectedExistingRole == 'studentHouseMember')
                      Text(
                        '• The person loses this role and its permissions\n• No cascade effects - members don\'t supervise others\n• Personal data and account remain safe',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white70,
                          height: 1.4,
                        ),
                      )
                    else
                      Text(
                        '• The person loses this role and its permissions\n• If they supervise others, they\'ll need a new supervisor assigned\n• Personal data and account remain safe',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white70,
                          height: 1.4,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Role selection cards for deletion - show all roles with permission indicators
        const Text(
          'Select Role to Remove',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 16),

        // 🎯 NEW: Show all roles with permission indicators
        ..._buildDeletableRoleCardsWithPermissions(),

        const SizedBox(height: 24),

        // Impact analysis
        if (_selectedExistingRole != null) ...[
          _buildImpactAnalysis(),
        ],
      ],
    );
  }

  // 🎯 NEW: Build deletable role cards with permission indicators
  List<Widget> _buildDeletableRoleCardsWithPermissions() {
    // Get all non-user roles
    final allRoles =
        _existingUserRoles.where((role) => role['role'] != 'user').toList();

    if (allRoles.isEmpty) {
      return [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.orange.withOpacity(0.2),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: Colors.orange.withOpacity(0.4)),
          ),
          child: const Row(
            children: [
              Icon(Icons.info_outline, color: Colors.orange, size: 24),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'No roles available to remove. This user only has the basic user role.',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
            ],
          ),
        ),
      ];
    }

    // Sort by hierarchy before building cards
    final sortedRoles = _sortRolesByHierarchy(allRoles);
    return sortedRoles.map((roleData) {
      final role = roleData['role'] as String;
      final isSelected = _selectedExistingRole == role;
      final roleColor = _getRoleColor(role);

      // 🎯 NEW: Check if current user can delete this role
      final canDelete = _currentUserRole != null &&
          RolePermissions.canAssignRole(_currentUserRole!, role);

      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: canDelete
                ? () {
                    setState(() {
                      _selectedExistingRole = role;
                      _message = '';
                    });
                  }
                : null, // Disable tap if no permission
            borderRadius: BorderRadius.circular(15),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: !canDelete
                    ? Colors.grey.withOpacity(0.1) // Disabled appearance
                    : isSelected
                        ? Colors.red.withOpacity(0.2)
                        : Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(
                  color: !canDelete
                      ? Colors.grey.withOpacity(0.3) // Disabled border
                      : isSelected
                          ? Colors.red.withOpacity(0.6)
                          : Colors.white.withOpacity(0.3),
                  width: isSelected ? 2 : 1,
                ),
                boxShadow: isSelected && canDelete
                    ? [
                        BoxShadow(
                          color: Colors.red.withOpacity(0.3),
                          blurRadius: 15,
                          offset: const Offset(0, 5),
                        ),
                      ]
                    : [],
              ),
              child: Row(
                children: [
                  // Role icon
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: canDelete
                          ? roleColor.withOpacity(0.2)
                          : Colors.grey.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      _getRoleIcon(role),
                      color: canDelete ? roleColor : Colors.grey,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),

                  // Role info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _getRoleTitle(role),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: canDelete ? Colors.white : Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          canDelete
                              ? 'Tap to select for deletion'
                              : 'Insufficient permissions to delete',
                          style: TextStyle(
                            fontSize: 12,
                            color: canDelete ? Colors.white70 : Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Permission indicator
                  Icon(
                    canDelete ? Icons.delete_outline : Icons.lock_outline,
                    color: canDelete ? Colors.red : Colors.grey,
                    size: 24,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }).toList();
  }

  // 🚀 Build deletable role cards (legacy method - removed, replaced with permission-aware version)

  // 🚀 Build simple impact summary
  Widget _buildImpactAnalysis() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.15),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.blue.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.info_outline, color: Colors.blue, size: 24),
              SizedBox(width: 12),
              Text(
                'Summary',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Simple summary
          Text(
            'Removing the ${_getRoleTitle(_selectedExistingRole!)} role from this person.',
            style: const TextStyle(
              fontSize: 16,
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          if (_selectedExistingRole != 'houseMember' &&
              _selectedExistingRole != 'studentHouseMember')
            Text(
              'If they supervise others, those people will need a new supervisor assigned.',
              style: const TextStyle(
                fontSize: 14,
                color: Colors.white70,
              ),
            )
          else
            Text(
              'This will have no cascade effects.',
              style: const TextStyle(
                fontSize: 14,
                color: Colors.green,
                fontWeight: FontWeight.w500,
              ),
            ),

          const SizedBox(height: 16),

          // Simple helpful tip
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green.withOpacity(0.3)),
            ),
            child: const Row(
              children: [
                Icon(Icons.lightbulb_outline, color: Colors.green, size: 18),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'This will permanently remove the role from the user.',
                    style: TextStyle(
                      fontSize: 14,
                      color: Color.fromARGB(255, 255, 255, 255),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Legacy impact helpers removed

  // 🚀 Check if we can show summary
  bool _canShowSummary() {
    switch (_currentOperation) {
      case 'add':
        return _selectedRole != null;
      case 'delete':
        return _selectedExistingRole != null;
      default:
        return false;
    }
  }

  // 🚀 Build operation summary - Modern redesign for 40-50+ users
  Widget _buildOperationSummary() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.indigo.withOpacity(0.15),
            Colors.purple.withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.2), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Modern header with icon
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Icon(
                  Icons.summarize_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              const Text(
                'Summary',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildSummaryContent(),
        ],
      ),
    );
  }

  // 🚀 Build summary content - User-friendly English for 40-50+ age group
  Widget _buildSummaryContent() {
    switch (_currentOperation) {
      case 'add':
        final nonUserRoles =
            _existingUserRoles.where((role) => role['role'] != 'user').toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Operation description card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.15),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.green.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.person_add_rounded,
                          color: Colors.green, size: 24),
                      const SizedBox(width: 12),
                      const Text(
                        'Adding New Role',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  RichText(
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    text: TextSpan(
                      children: [
                        const TextSpan(
                          text: 'User: ',
                          style: TextStyle(fontSize: 16, color: Colors.white70),
                        ),
                        TextSpan(
                          text: _targetUserName ?? 'Unknown',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  RichText(
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                    text: TextSpan(
                      children: [
                        const TextSpan(
                          text: 'Role to Add: ',
                          style: TextStyle(fontSize: 16, color: Colors.white70),
                        ),
                        TextSpan(
                          text: _getRoleTitle(_selectedRole!),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Roles after operation
            const Text(
              'Roles After Operation:',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            // Show existing roles
            if (nonUserRoles.isNotEmpty) ...[
              const Text(
                'Current Roles:',
                style: TextStyle(fontSize: 16, color: Colors.white70),
              ),
              const SizedBox(height: 8),
              ...(_sortRolesByHierarchy(nonUserRoles)
                  .map((role) => _buildRoleSummaryItem(
                      role['role'], Colors.blue,
                      isExisting: true))
                  .toList()),
              const SizedBox(height: 12),
            ],
            const Text(
              'New Role Added:',
              style: TextStyle(fontSize: 16, color: Colors.white70),
            ),
            const SizedBox(height: 8),
            _buildRoleSummaryItem(_selectedRole!, Colors.green, isNew: true),
          ],
        );

      case 'delete':
        final remainingRoles = _existingUserRoles
            .where((role) =>
                role['role'] != _selectedExistingRole && role['role'] != 'user')
            .toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Operation description card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.15),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.red.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.person_remove_rounded,
                          color: Colors.red, size: 24),
                      const SizedBox(width: 12),
                      const Text(
                        'Removing Role',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  RichText(
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    text: TextSpan(
                      children: [
                        const TextSpan(
                          text: 'User: ',
                          style: TextStyle(fontSize: 16, color: Colors.white70),
                        ),
                        TextSpan(
                          text: _targetUserName ?? 'Unknown',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  RichText(
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                    text: TextSpan(
                      children: [
                        const TextSpan(
                          text: 'Role to Remove: ',
                          style: TextStyle(fontSize: 16, color: Colors.white70),
                        ),
                        TextSpan(
                          text: _getRoleTitle(_selectedExistingRole!),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.red,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            const Text(
              'Roles After Operation:',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            if (remainingRoles.isNotEmpty) ...[
              ...(_sortRolesByHierarchy(remainingRoles)
                  .map((role) => _buildRoleSummaryItem(
                      role['role'], Colors.blue,
                      isExisting: true))
                  .toList())
            ] else
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.withOpacity(0.4)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline_rounded,
                        color: Colors.grey, size: 20),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'User will have no special roles',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.visible,
                        softWrap: true,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );
      default:
        return const SizedBox.shrink();
    }
  }

  // 🚀 Build role summary item - Enhanced for better readability
  Widget _buildRoleSummaryItem(String role, Color color,
      {bool isNew = false, bool isExisting = false}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(isNew ? 0.2 : 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(isNew ? 0.5 : 0.3),
          width: isNew ? 2 : 1,
        ),
        boxShadow: isNew
            ? [
                BoxShadow(
                  color: color.withOpacity(0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ]
            : [],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(_getRoleIcon(role), color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _getRoleTitle(role),
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: isNew ? FontWeight.bold : FontWeight.w500,
                  ),
                ),
                if (isNew)
                  const Text(
                    'Newly Added',
                    style: TextStyle(
                      color: Colors.green,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                if (isExisting)
                  const Text(
                    'Existing Role',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
          if (isNew)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'NEW',
                style: TextStyle(
                  color: Colors.green,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // 🚀 Check if we can proceed to next step
  bool _canProceedToNext() {
    // Step 2: Role selection step
    if (_currentStep == 2) {
      // First check if operation is selected
      if (_currentOperation.isEmpty) return false;

      switch (_currentOperation) {
        case 'add':
          return _selectedRole != null;
        case 'delete':
          return _selectedExistingRole != null;
        default:
          return false;
      }
    }

    // For other steps, check if user is selected first
    if (_selectedUser == null) return false;

    switch (_currentOperation) {
      case 'add':
        return _selectedRole != null;
      case 'delete':
        return _selectedExistingRole != null;
      default:
        return false;
    }
  }

  Widget _buildSupervisorStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Select Supervisor',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.blue.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.info_outline,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: RichText(
                  text: TextSpan(
                    children: [
                      const TextSpan(
                        text: 'This role requires a ',
                        style: TextStyle(
                          fontSize: 15,
                          color: Colors.white,
                          height: 1.3,
                        ),
                      ),
                      TextSpan(
                        text: _getSupervisorDisplayText(_selectedRole!)
                            .toLowerCase(),
                        style: const TextStyle(
                          fontSize: 15,
                          color: Colors.white,
                          height: 1.3,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const TextSpan(
                        text: ' supervisor.',
                        style: TextStyle(
                          fontSize: 15,
                          color: Colors.white,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // 🚀 NEW: Card-based supervisor selection
        _buildSupervisorCards(),

        const SizedBox(height: 40),

        // Navigation buttons with glassmorphic design
        Row(
          children: [
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: Colors.white.withOpacity(0.2),
                border: Border.all(color: Colors.white.withOpacity(0.3)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ElevatedButton.icon(
                onPressed: _goToPreviousStep,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  shadowColor: Colors.transparent,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20)),
                ),
                icon: const Icon(Icons.arrow_back_rounded, size: 20),
                label: const Text('Back',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
            const Spacer(),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: _selectedSupervisorId != null
                    ? Colors.green.withOpacity(0.3)
                    : Colors.white.withOpacity(0.1),
                border: Border.all(
                  color: _selectedSupervisorId != null
                      ? Colors.green.withOpacity(0.5)
                      : Colors.white.withOpacity(0.2),
                ),
                boxShadow: _selectedSupervisorId != null
                    ? [
                        BoxShadow(
                          color: Colors.green.withOpacity(0.2),
                          blurRadius: 15,
                          offset: const Offset(0, 8),
                        ),
                      ]
                    : [],
              ),
              child: ElevatedButton.icon(
                onPressed: _selectedSupervisorId != null ? _goToNextStep : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  shadowColor: Colors.transparent,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20)),
                ),
                icon: Icon(
                    (_currentStep < _totalSteps)
                        ? Icons.arrow_forward_rounded
                        : Icons.check_rounded,
                    size: 20),
                label: Text(
                  (_currentStep < _totalSteps) ? 'Next' : 'Complete',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDetailsStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Location Details',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Where will this role be performed? Please specify the location details.',
          style: TextStyle(fontSize: 16, color: Colors.white70),
        ),
        const SizedBox(height: 30),

        Expanded(
          child: SingleChildScrollView(
            controller: _scrollController,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Country Selection
                const Text(
                  "Country *",
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white),
                ),
                const SizedBox(height: 8),
                _buildGlassmorphicDropdown(
                  _countries,
                  _selectedCountry,
                  '',
                  (value) {
                    setState(() {
                      _selectedCountry = value;
                      _selectedCity = null; // Reset city when country changes

                      // 🎯 MODERATOR: Auto-set National values
                      if (_selectedRole == 'moderator' && value != null) {
                        _selectedProvince = 'National';
                        _selectedCity = 'National';
                        _selectedUnitGender =
                            'Mixed'; // Auto-set to Mixed for country-wide management
                      }
                    });
                  },
                  isRequired: true,
                ),
                const SizedBox(height: 20),

                // 🎯 MODERATOR: Show special info message
                if (_selectedRole == 'moderator' &&
                    _selectedCountry != null) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: Colors.blue.withOpacity(0.1),
                      border: Border.all(color: Colors.blue.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Moderator manages the entire country.',
                            style: TextStyle(
                              color: Colors.blue.shade300,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                // Province Selection (only show if country is selected AND not moderator)
                if (_selectedCountry != null &&
                    _selectedRole != 'moderator') ...[
                  const Text(
                    "Province/State *",
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white),
                  ),
                  const SizedBox(height: 8),
                  _buildGlassmorphicDropdown(
                    _getProvincesForCountry(_selectedCountry!),
                    _selectedProvince,
                    '',
                    (value) {
                      setState(() {
                        _selectedProvince = value;
                        _selectedCity =
                            null; // Reset city when province changes
                      });
                    },
                    isRequired: true,
                  ),
                  const SizedBox(height: 20),
                ],

                // City Selection (only show if province is selected AND not moderator)
                if (_selectedProvince != null &&
                    _selectedRole != 'moderator') ...[
                  const Text(
                    "City *",
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white),
                  ),
                  const SizedBox(height: 8),
                  _buildGlassmorphicDropdown(
                    _getCitiesForProvince(_selectedProvince!),
                    _selectedCity,
                    '',
                    (value) {
                      setState(() => _selectedCity = value);
                    },
                    isRequired: true,
                  ),
                  const SizedBox(height: 20),
                ],

                // Gender Selection (show if city is selected, but NOT for moderator)
                if (_selectedCity != null && _selectedRole != 'moderator') ...[
                  _buildGlassmorphicGenderToggle(isRequired: true),
                  const SizedBox(height: 30),
                ],

                // Role-specific additional details (only show if gender is selected)
                if (_selectedCity != null &&
                    _selectedUnitGender != null &&
                    (_selectedRole == 'middleSchoolMentor' ||
                        _selectedRole == 'highSchoolMentor')) ...[
                  const Text(
                    "Mentorship Class Assignment",
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white),
                  ),
                  const SizedBox(height: 16),
                  _buildGlassmorphicMentorClassSelection(),
                  const SizedBox(height: 20),
                ],
              ],
            ),
          ),
        ),

        // Navigation buttons with glassmorphic design
        Row(
          children: [
            // Back button (show if not on first step)
            if (_currentStep > 1) ...[
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: Colors.white.withOpacity(0.1),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.2),
                  ),
                ),
                child: ElevatedButton.icon(
                  onPressed: _goToPreviousStep,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    foregroundColor: Colors.white70,
                    shadowColor: Colors.transparent,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20)),
                  ),
                  icon: const Icon(Icons.arrow_back_rounded, size: 20),
                  label: const Text(
                    'Back',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(width: 16),
            ],
            const Spacer(),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: _canComplete()
                    ? Colors.green.withOpacity(0.3)
                    : Colors.white.withOpacity(0.1),
                border: Border.all(
                  color: _canComplete()
                      ? Colors.green.withOpacity(0.5)
                      : Colors.white.withOpacity(0.2),
                ),
                boxShadow: _canComplete()
                    ? [
                        BoxShadow(
                          color: Colors.green.withOpacity(0.2),
                          blurRadius: 15,
                          offset: const Offset(0, 8),
                        ),
                      ]
                    : [],
              ),
              child: ElevatedButton.icon(
                onPressed: _canComplete()
                    ? () {
                        HapticFeedback.mediumImpact();
                        _goToNextStep();
                      }
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  shadowColor: Colors.transparent,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20)),
                ),
                icon: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.arrow_forward_rounded, size: 20),
                label: _isLoading
                    ? const Text('')
                    : const Text('Next',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildGlassmorphicGenderToggle({bool isRequired = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Gender *",
          style: TextStyle(
              fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        const SizedBox(height: 4),
        const Text(
          "Which group will this person work with?",
          style: TextStyle(fontSize: 13, color: Colors.white70),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () {
                  setState(() => _selectedUnitGender = 'Male');
                  // 🎯 AUTO-SCROLL: Show mentor class options after gender selection
                  if (_selectedRole == 'middleSchoolMentor' ||
                      _selectedRole == 'highSchoolMentor') {
                    _scrollToMentorClassSection();
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: _selectedUnitGender == 'Male'
                        ? Colors.white.withOpacity(0.3)
                        : Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(
                      color: _selectedUnitGender == 'Male'
                          ? Colors.white.withOpacity(0.6)
                          : Colors.white.withOpacity(0.3),
                    ),
                    boxShadow: _selectedUnitGender == 'Male'
                        ? [
                            BoxShadow(
                              color: Colors.white.withOpacity(0.2),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : [],
                  ),
                  child: Text(
                    'Male',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: _selectedUnitGender == 'Male'
                          ? Colors.white
                          : Colors.white70,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: GestureDetector(
                onTap: () {
                  setState(() => _selectedUnitGender = 'Female');
                  // 🎯 AUTO-SCROLL: Show mentor class options after gender selection
                  if (_selectedRole == 'middleSchoolMentor' ||
                      _selectedRole == 'highSchoolMentor') {
                    _scrollToMentorClassSection();
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: _selectedUnitGender == 'Female'
                        ? Colors.white.withOpacity(0.3)
                        : Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(
                      color: _selectedUnitGender == 'Female'
                          ? Colors.white.withOpacity(0.6)
                          : Colors.white.withOpacity(0.3),
                    ),
                    boxShadow: _selectedUnitGender == 'Female'
                        ? [
                            BoxShadow(
                              color: Colors.white.withOpacity(0.2),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : [],
                  ),
                  child: Text(
                    'Female',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: _selectedUnitGender == 'Female'
                          ? Colors.white
                          : Colors.white70,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildGlassmorphicDropdown(List<String> items, String? value,
      String label, ValueChanged<String?> onChanged,
      {bool isRequired = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label.isNotEmpty) ...[
          Text(
            label,
            style: const TextStyle(
                fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 12),
        ],
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            color: Colors.white.withOpacity(0.2),
            border: Border.all(color: Colors.white.withOpacity(0.4)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: DropdownButton<String>(
            value: value,
            isExpanded: true,
            hint: const Text(
              'Select...',
              style: TextStyle(fontSize: 16, color: Colors.white60),
            ),
            style: const TextStyle(
                fontSize: 16, color: Colors.white, fontWeight: FontWeight.w500),
            dropdownColor: const Color(0xFF2D3748),
            iconEnabledColor: Colors.white70,
            iconDisabledColor: Colors.white30,
            borderRadius: BorderRadius.circular(20),
            elevation: 8,
            underline: const SizedBox(), // Alt çizgiyi kaldır
            items: items
                .map((item) => DropdownMenuItem(
                      value: item,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            vertical: 8, horizontal: 4),
                        child: Text(
                          item,
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ))
                .toList(),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  Widget _buildGlassmorphicMentorClassSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_isLoadingGroups)
          const Center(child: CircularProgressIndicator(color: Colors.white))
        else if (_mentorshipGroups.isEmpty)
          Column(
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: Colors.white.withOpacity(0.3)),
                ),
                child: const Text(
                  'No classes available. Create a new class to assign to this mentor.',
                  style: TextStyle(fontSize: 16, color: Colors.white70),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.add, color: Colors.white),
                  label: const Text('Create New Class',
                      style: TextStyle(color: Colors.white)),
                  onPressed: () {
                    _showCreateGroupDialog();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15)),
                  ),
                ),
              ),
            ],
          )
        else
          Column(
            children: [
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(25),
                  color: Colors.white.withOpacity(0.15),
                  border: Border.all(color: Colors.white.withOpacity(0.3)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                child: DropdownButtonFormField<String>(
                  value: _selectedMentorshipGroupId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    hintText: 'Select Class',
                    hintStyle: TextStyle(fontSize: 16, color: Colors.white70),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 14),
                  ),
                  dropdownColor: Colors.white,
                  items: _mentorshipGroups.map((group) {
                    final mentorText = group['mentorName'] != null
                        ? ' (Mentor: ${group['mentorName']})'
                        : ' (Available)';
                    final isAssigned = group['currentMentorId'] != null;
                    return DropdownMenuItem<String>(
                      value: group['id'],
                      enabled: !isAssigned,
                      child: Text(
                        '${group['name']}$mentorText',
                        style: TextStyle(
                          fontSize: 16,
                          color: isAssigned ? Colors.grey : Colors.black87,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedMentorshipGroupId = value;
                      final selected = _mentorshipGroups.firstWhere(
                        (g) => g['id'] == value,
                        orElse: () => <String, dynamic>{},
                      );
                      _selectedMentorshipGroupName =
                          selected['name'] as String?; // 🎯 Cache selected name
                    });
                  },
                ),
              ),
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.add, color: Colors.white),
                  label: const Text('Create New Class',
                      style: TextStyle(color: Colors.white)),
                  onPressed: () {
                    _showCreateGroupDialog();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15)),
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }

  bool _needsSupervisor() {
    return _supervisorRoleHierarchy.containsKey(_selectedRole) ||
        _dependentRoles.contains(_selectedRole);
  }

  // _needsDetails retained for readability, used by flow-related conditions
  // _needsDetails removed; Step 4 gating is handled directly in _canCompleteAddRole and flow methods

  bool _canComplete() {
    // Basic validation: must have target user and selected role
    if (_targetUserName == null || _selectedRole == null) {
      return false;
    }

    // Operation-specific validations
    switch (_currentOperation) {
      case 'add':
        final result = _canCompleteAddRole();
        return result;
      case 'delete':
        final result = _canCompleteDeleteRole();
        return result;
      default:
        final result = _canCompleteAddRole();
        return result;
    }
  }

  bool _canCompleteAddRole() {
    if (_selectedRole == null) return false;

    // 🎯 REORDERED: Universal Step 3 validation - ALL roles need location data
    if (_currentStep == 3) {
      // 🎯 MODERATOR: Special validation (only country and gender required)
      if (_selectedRole == 'moderator') {
        if (_selectedCountry == null || _selectedUnitGender == null) {
          return false;
        }
      } else {
        // Mandatory fields for NON-MODERATOR roles in Step 3 (Location Details)
        if (_selectedCountry == null ||
            _selectedProvince == null ||
            _selectedCity == null ||
            _selectedUnitGender == null) {
          return false;
        }
      }

      // Role-specific additional requirements
      if (_selectedRole == 'middleSchoolMentor' ||
          _selectedRole == 'highSchoolMentor') {
        // Mentors also need class selection
        if (_selectedMentorshipGroupId == null) {
          return false;
        }
      }

      return true;
    }

    // 🎯 REORDERED: Step 4 validation - Supervisor Selection
    if (_currentStep == 4) {
      // Check if supervisor is required and selected
      if (_needsSupervisor() && _selectedSupervisorId == null) {
        return false;
      }
      return true;
    }

    // Check if supervisor is required and validated (for earlier steps)
    if (_needsSupervisor()) {
      // Special case for moderator: admin can assign moderator role
      if (_selectedRole == 'moderator') {
        // Check supervisor requirement first
        if (_supervisorUserName == null) {
          return false;
        }

        // Validate supervisor role
        if (_supervisorUserRole != 'admin' &&
            _supervisorUserRole?.toLowerCase() != 'admin') {
          return false;
        }

        // For moderator, if we're on step 5, check orphaned units choice
        if (_currentStep == 5 && _hasOrphanedUnits) {
          if (_orphanedUnitChoice == null) return false;
          if (_orphanedUnitChoice == 'recover' &&
              _selectedOrphanedUnitId == null) return false;
        }

        return true;
      }

      // For other roles, use existing validation
      if (_supervisorUserName == null || _supervisorRoleMatches != true) {
        return false;
      }
    }

    // Check orphaned units choice if we're on step 5
    if (_currentStep == 5 && _hasOrphanedUnits) {
      if (_orphanedUnitChoice == null) return false;
      if (_orphanedUnitChoice == 'recover' && _selectedOrphanedUnitId == null)
        return false;
    }

    return true;
  }

  bool _canCompleteDeleteRole() {
    return _selectedExistingRole != null;
  }

  void _goToNextStep() async {
    if (_currentStep < _totalSteps) {
      // 🎯 NEW STRATEGY: Reset next step's state when moving forward
      setState(() {
        _currentStep++;
        _message = ''; // Clear any messages when moving forward
      });

      // 🎯 FORWARD RESET: Clear next step's state when entering it
      if (_currentStep == 2) {
        // Entering Step 2 (Role Selection) - reset operation and role selection
        setState(() {
          _currentOperation = '';
          _selectedRole = null;
          _selectedExistingRole = null;
          _showRoleSelection = false;
        });
      } else if (_currentStep == 3) {
        // Entering Step 3 (Location Details) - reset location state
        setState(() {
          _selectedCountry = null;
          _selectedProvince = null;
          _selectedCity = null;
          _selectedUnitGender = null;

          // Reset mentorship groups for mentor roles
          if (_selectedRole == 'middleSchoolMentor' ||
              _selectedRole == 'highSchoolMentor') {
            _selectedMentorshipGroupId = null;
            _selectedMentorshipGroupName = null;
            _mentorshipGroups = [];
          }
        });
      } else if (_currentStep == 4) {
        // Entering Step 4 (Supervisor Selection) - reset supervisor state
        setState(() {
          _selectedSupervisorId = null;
          _supervisorsByCity = {};
          _supervisorUserName = null;
          _supervisorUserRole = null;
          _supervisorRoleMatches = null;
          _isLoadingSupervisors = false;
        });

        // 🎯 FILTERING: Load supervisors with city and gender filters after state reset
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _fetchAvailableSupervisors();
        });
      } else if (_currentStep == 5) {
        // Entering Step 5 (Orphaned Units Choice) - reset orphaned units state
        setState(() {
          _hasOrphanedUnits = false;
          _availableOrphanedUnits = [];
          _orphanedUnitChoice = null;
          _selectedOrphanedUnitId = null;
        });

        // Check for orphaned units when entering step 5
        if (_unitManagingRoles.contains(_selectedRole)) {
          await _checkForOrphanedUnits();
        }
      }
    } else {
      // 🎯 Final step - always Complete
      assignRole();
    }
  }

  // 🚀 NEW: Go to previous step - PRESERVE previous selections
  void _goToPreviousStep() {
    if (_currentStep > 1) {
      setState(() {
        _currentStep--;
        _message = ''; // Clear any error messages when going back

        // 🎯 NEW STRATEGY: PRESERVE all state when going backward
        // Users should see their previous selections intact
        // No state clearing when going back - everything is preserved!

        // 🎯 SPECIAL CASE: Fix role selection UI visibility when going back to Step 2
        if (_currentStep == 2 && _currentOperation.isNotEmpty) {
          // If user has selected an operation before, show role selection UI
          _showRoleSelection = true;
        }
      });
    }
  }

  @override
  void dispose() {
    // Legacy listeners removed

    // 🚀 NEW: Modern search cleanup
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _scrollController.dispose();

    // Cancel timers
    _searchDebounce?.cancel();
    _successMessageTimer?.cancel();

    // 🚀 PERFORMANCE: Clear all caches to free memory
    _searchCache.clear();
    _cacheTimestamps.clear();
    _supervisorCache.clear();
    _supervisorCacheTimestamps.clear();
    _mentorshipGroupsCache.clear();
    _mentorshipCacheTimestamps.clear();

    // Dispose animation controller
    _slideAnimationController.dispose();

    super.dispose();
  }

  // 🚀 NEW: Enhanced Success Message Widget with Timer
  Widget _buildEnhancedSuccessMessage() {
    if (!_showSuccessMessage || _message.isEmpty)
      return const SizedBox.shrink();

    return Positioned(
      bottom: 100, // Above Next button
      left: 20,
      right: 20,
      child: SlideTransition(
        position: _slideAnimation,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _showDeletionMessage
                ? Colors.red.withOpacity(0.9)
                : Colors.green.withOpacity(0.9),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
                color: _showDeletionMessage
                    ? Colors.red.withOpacity(0.4)
                    : Colors.green.withOpacity(0.4)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(
                  _showDeletionMessage
                      ? Icons.delete_forever
                      : Icons.check_circle,
                  color: Colors.white,
                  size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _message,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Circular progress with countdown
              SizedBox(
                width: 40,
                height: 40,
                child: Stack(
                  children: [
                    CircularProgressIndicator(
                      value: _progressValue,
                      strokeWidth: 3,
                      backgroundColor: Colors.white.withOpacity(0.3),
                      valueColor:
                          const AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: Center(
                        child: Transform.translate(
                          offset: const Offset(
                              -2, -2), // Hafif sola ve yukarı kaydır
                          child: Text(
                            '$_countdown',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 🚀 NEW: Modern User Search Widget
  Widget _buildModernUserSearch({
    required String title,
    required String subtitle,
    required TextEditingController controller,
    required List<Map<String, dynamic>> searchResults,
    required bool isSearching,
    required Map<String, dynamic>? selectedUser,
    required Function(Map<String, dynamic>) onUserSelected,
    String placeholder = "",
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title
        Text(
          title,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: const TextStyle(fontSize: 16, color: Colors.white70),
        ),
        const SizedBox(height: 30),

        // Search Bar
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: Colors.white.withOpacity(0.15),
            border: Border.all(color: Colors.white.withOpacity(0.3)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          child: Row(
            children: [
              Icon(
                Icons.search_rounded,
                color: Colors.white70,
                size: 24,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextField(
                  controller: controller,
                  style: const TextStyle(fontSize: 18, color: Colors.white),
                  decoration: InputDecoration(
                    hintText: placeholder,
                    hintStyle:
                        const TextStyle(fontSize: 16, color: Colors.white70),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
              if (isSearching)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white70,
                    strokeWidth: 2,
                  ),
                )
              else if (controller.text.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.clear, color: Colors.white70),
                  onPressed: () => controller.clear(),
                ),
            ],
          ),
        ),

        // Search hint text
        Padding(
          padding: const EdgeInsets.only(top: 8, left: 16, right: 16),
          child: Text(
            'You can search by name, username, email, or Member ID',
            style: TextStyle(
              fontSize: 13,
              color: Colors.white.withOpacity(0.7),
              fontStyle: FontStyle.italic,
            ),
            textAlign: TextAlign.center,
          ),
        ),

        // Error Display
        if (_error != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.red.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.error_outline, color: Colors.red.shade300, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _error!,
                    style: TextStyle(
                      color: Colors.red.shade300,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 20),

        // Selected User Display
        if (selectedUser != null) ...[
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.green.withOpacity(0.2),
                  Colors.blue.withOpacity(0.15),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.green.withOpacity(0.4)),
              boxShadow: [
                BoxShadow(
                  color: Colors.green.withOpacity(0.1),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.person_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Text(
                        'Selected User',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        // Clear selected user and search results
                        controller.clear();
                        onUserSelected(
                            {'clear': true}); // Special signal to clear
                      },
                      icon: const Icon(
                        Icons.close_rounded,
                        color: Colors.white70,
                        size: 24,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildUserInfoRow(
                    Icons.person,
                    'Name',
                    '${selectedUser['firstName'] ?? ''} ${selectedUser['lastName'] ?? ''}'
                        .trim()),
                _buildUserInfoRow(Icons.alternate_email, 'Username',
                    selectedUser['username'] ?? 'N/A'),
                _buildUserInfoRow(
                    Icons.email, 'Email', selectedUser['email'] ?? 'N/A'),
                _buildUserInfoRow(Icons.fingerprint, 'Member ID',
                    selectedUser['memberId'] ?? selectedUser['id'] ?? 'N/A'),

                // Show all roles
                _buildUserRolesRow(selectedUser),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],

        // Loading Skeleton
        if (isSearching && controller.text.length >= 2) ...[
          Container(
            constraints: const BoxConstraints(maxHeight: 300),
            child: Column(
              children: List.generate(
                3,
                (index) => Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: Colors.white.withOpacity(0.2)),
                  ),
                  child: Row(
                    children: [
                      // Avatar skeleton
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: _buildShimmerEffect(),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Name skeleton
                            Container(
                              height: 16,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: _buildShimmerEffect(),
                            ),
                            const SizedBox(height: 8),
                            // Email skeleton
                            Container(
                              height: 14,
                              width: 200,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(7),
                              ),
                              child: _buildShimmerEffect(),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],

        // Search Results
        if (searchResults.isNotEmpty &&
            selectedUser == null &&
            !isSearching) ...[
          Container(
            constraints: const BoxConstraints(maxHeight: 400),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: searchResults.length,
              itemBuilder: (context, index) {
                final user = searchResults[index];
                return _buildUserSearchResult(user, onUserSelected);
              },
            ),
          ),
        ] else if (controller.text.length >= 2 &&
            !isSearching &&
            searchResults.isEmpty &&
            selectedUser == null) ...[
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: Colors.orange.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.search_off, color: Colors.orange, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'No users found matching "${controller.text}"',
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildUserInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, color: Colors.white70, size: 16),
          const SizedBox(width: 12),
          Text(
            '$label: ',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserRolesRow(Map<String, dynamic> user) {
    // Get all user roles
    List<String> userRoles = [];
    final roles = user['roles'] as List<dynamic>?;

    if (roles != null && roles.isNotEmpty) {
      for (var roleObj in roles) {
        if (roleObj is Map<String, dynamic>) {
          final role = roleObj['role'] as String?;
          if (role != null && role != 'user') {
            userRoles.add(role);
          }
        }
      }
    } else {
      // Fallback to old role system
      final role = user['role'] as String?;
      if (role != null && role != 'user') {
        userRoles.add(role);
      }
    }

    // If no non-user roles found, show user role
    if (userRoles.isEmpty) {
      userRoles.add('user');
    }

    // 🎯 Sort roles by hierarchy
    userRoles = _sortRoleStringsByHierarchy(userRoles);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.badge, color: Colors.white70, size: 16),
          const SizedBox(width: 12),
          Text(
            userRoles.length > 1 ? 'Roles: ' : 'Role: ',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          Expanded(
            child: Wrap(
              spacing: 6,
              runSpacing: 4,
              children: userRoles
                  .map((role) => Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: _getRoleColor(role).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                              color: _getRoleColor(role).withOpacity(0.4)),
                        ),
                        child: Text(
                          _getRoleTitle(role),
                          style: TextStyle(
                            fontSize: 12,
                            color: _getRoleColor(role),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserSearchResult(
      Map<String, dynamic> user, Function(Map<String, dynamic>) onTap) {
    final fullName =
        '${user['firstName'] ?? ''} ${user['lastName'] ?? ''}'.trim();
    final username = user['username'] ?? '';
    final email = user['email'] ?? '';

    // Get all user roles
    List<String> userRoles = [];
    final roles = user['roles'] as List<dynamic>?;

    if (roles != null && roles.isNotEmpty) {
      for (var roleObj in roles) {
        if (roleObj is Map<String, dynamic>) {
          final role = roleObj['role'] as String?;
          if (role != null && role != 'user') {
            userRoles.add(role);
          }
        }
      }
    } else {
      // Fallback to old role system
      final role = user['role'] as String?;
      if (role != null && role != 'user') {
        userRoles.add(role);
      }
    }

    // If no non-user roles found, show user role
    if (userRoles.isEmpty) {
      userRoles.add('user');
    }

    // 🎯 Sort roles by hierarchy
    userRoles = _sortRoleStringsByHierarchy(userRoles);

    // Use primary role for avatar color (first non-user role or user)
    final primaryRole = userRoles.first;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => onTap(user),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.2)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                // Avatar
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        _getRoleColor(primaryRole).withOpacity(0.8),
                        _getRoleColor(primaryRole).withOpacity(0.6),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      _getInitials(fullName),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),

                // User Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Name
                      Text(
                        fullName.isNotEmpty ? fullName : 'Unknown User',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),

                      // Username and Email
                      if (username.isNotEmpty)
                        Text(
                          '@$username',
                          style: TextStyle(
                            fontSize: 14,
                            color: _getRoleColor(primaryRole),
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      if (email.isNotEmpty)
                        Text(
                          email,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.white70,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),

                      const SizedBox(height: 6),

                      // Role Badges - Show all roles
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: userRoles
                            .map((role) => Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: _getRoleColor(role).withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    _getRoleTitle(role),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: _getRoleColor(role),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ))
                            .toList(),
                      ),
                    ],
                  ),
                ),

                // Select Icon
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: Colors.white60,
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getInitials(String name) {
    if (name.isEmpty) return '?';
    final parts = name.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name[0].toUpperCase();
  }

  String _getFullNameFromFields(String? name, String? lastName,
      {String id = ''}) {
    if ((name == null || name.isEmpty) &&
        (lastName == null || lastName.isEmpty)) {
      return id;
    }
    return '${name ?? ''} ${lastName ?? ''}'.trim();
  }

  String _getOrdinalSuffix(int number) {
    if (number % 100 >= 11 && number % 100 <= 13) {
      return 'th';
    }
    switch (number % 10) {
      case 1:
        return 'st';
      case 2:
        return 'nd';
      case 3:
        return 'rd';
      default:
        return 'th';
    }
  }

  String _getBaseGradeName(int grade, String unitType) {
    final suffix = _getOrdinalSuffix(grade);
    switch (unitType) {
      case 'highSchool':
        return '$grade$suffix Grade';
      case 'middleSchool':
        return '$grade$suffix Grade';
      case 'university':
        return '$grade$suffix Year';
      default:
        return '$grade$suffix Level';
    }
  }

  // 🚀 Handle organizational unit updates for role deletion
  Future<void> _handleOrganizationalUnitForRoleDeletion(
      String userId, String deletedRole) async {
    try {
// print('🗑️ Handling organizational units for deleted role: $deletedRole, userId: $userId');

      // 🚀 Handle mentor roles separately (they use currentMentorId, not supervisorId)
      if (deletedRole == 'middleSchoolMentor' ||
          deletedRole == 'highSchoolMentor') {
        await _handleMentorRoleDeletion(userId, deletedRole);
        return;
      }

      // 🚀 Handle unit-managing roles (they use managedBy)
      final unitsQuery = await _firestore
          .collection('organizationalUnits')
          .where('managedBy', isEqualTo: userId)
          .get();

// print('📋 Found ${unitsQuery.docs.length} organizational units supervised by user');

      if (unitsQuery.docs.isEmpty) {
// print('❌ No organizational units found for user $userId');
        return;
      }

      // Check if user still has other unit-managing roles
      final remainingUnitRoles = _existingUserRoles
          .where((r) =>
              r['role'] != deletedRole &&
              r['role'] != 'user' &&
              _unitManagingRoles.contains(r['role']))
          .toList();

// print('📊 User has ${remainingUnitRoles.length} remaining unit-managing roles');

      // Process each organizational unit
      for (final unitDoc in unitsQuery.docs) {
        final unitData = unitDoc.data();
        // unitName not used in logic below
        final unitLevel = unitData['level'] as String? ?? 'unknown';

// print('🏢 Processing unit: $unitName (${unitDoc.id})');

        // Check if this specific unit type can be managed by remaining roles
        bool canStillManageThisUnit = false;

        for (final remainingRole in remainingUnitRoles) {
          final roleStr = remainingRole['role'] as String;

          // Check if the remaining role can manage this unit type
          if (_canRoleManageUnitType(roleStr, unitLevel, unitData)) {
            canStillManageThisUnit = true;
// print('✅ Unit can still be managed by remaining role: $roleStr');
            break;
          }
        }

        if (!canStillManageThisUnit) {
          // User can no longer manage this unit - mark as orphaned
// print('🔄 Marking unit as orphaned: $unitName');
          await _handleOrganizationalUnitTransition(
              unitDoc.reference, unitData, deletedRole, userId);
        } else {
// print('✅ Unit remains under user management via other roles');
        }
      }
    } catch (e) {
// print('❌ Error handling organizational units for role deletion: $e');
      // Don't throw - this shouldn't block the role deletion
    }
  }

  // 🚀 NEW: Handle mentor role deletion specifically
  Future<void> _handleMentorRoleDeletion(
      String userId, String deletedRole) async {
    try {
// print('🎓 Handling mentor role deletion: $deletedRole, userId: $userId');

      // Find all mentorship groups where this user is the current mentor
      // 🎯 NEW: Use standard managedBy field instead of currentMentorId
      final mentorshipGroupsQuery = await _firestore
          .collection('organizationalUnits')
          .where('managedBy', isEqualTo: userId)
          .where('level', isEqualTo: 'mentor')
          .get();

// print('📚 Found ${mentorshipGroupsQuery.docs.length} mentorship groups assigned to this mentor');

      if (mentorshipGroupsQuery.docs.isEmpty) {
// print('❌ No mentorship groups found for mentor $userId');
        return;
      }

      // Check if user has other mentor roles
      final remainingMentorRoles = _existingUserRoles
          .where((r) =>
              r['role'] != deletedRole &&
              (r['role'] == 'middleSchoolMentor' ||
                  r['role'] == 'highSchoolMentor'))
          .toList();

// print('🎯 User has ${remainingMentorRoles.length} remaining mentor roles');

      // Process each mentorship group
      for (final groupDoc in mentorshipGroupsQuery.docs) {
        final groupData = groupDoc.data();
        // groupName and groupType not used in logic below

// print('🏫 Processing mentorship group: $groupName (${groupDoc.id})');

        // Check if user can still mentor this specific group type with remaining roles
        bool canStillMentorThisGroup = false;

        for (final remainingRole in remainingMentorRoles) {
          final roleStr = remainingRole['role'] as String;

          // Check if the remaining mentor role matches this group type
          if (_canMentorRoleManageGroup(roleStr, groupData)) {
            canStillMentorThisGroup = true;
// print('✅ Group can still be mentored by remaining role: $roleStr');
            break;
          }
        }

        if (!canStillMentorThisGroup) {
          // User can no longer mentor this group - mark as awaiting mentor
// print('🔄 Marking mentorship group as awaiting mentor: $groupName');

          await groupDoc.reference.update({
            // 🎯 NEW: Clear standard management fields
            'managedBy': FieldValue.delete(),
            'managedByMemberId': FieldValue.delete(),
            'status': 'pendingReassignment',
            // 🎯 Legacy fields cleanup (if they exist)
            'currentMentorId': FieldValue.delete(),
            'currentMentorMemberId': FieldValue.delete(),
            'mentorName': FieldValue.delete(),
            'mentorRole': FieldValue.delete(),
            // Mentor's own unit will handle recovery tracking
            'updatedAt': FieldValue.serverTimestamp(),
          });

// print('✅ Mentorship group updated successfully');
        } else {
// print('✅ Group remains under user mentorship via other mentor roles');
        }
      }
    } catch (e) {
// print('❌ Error handling mentor role deletion: $e');
      // Don't throw - this shouldn't block the role deletion
    }
  }

  // 🚀 NEW: Check if a mentor role can manage a specific group type
  bool _canMentorRoleManageGroup(
      String mentorRole, Map<String, dynamic> groupData) {
    final groupName = groupData['name'] as String? ?? '';

    // Middle school mentors can only mentor middle school groups
    if (mentorRole == 'middleSchoolMentor') {
      return groupName.toLowerCase().contains('middle') ||
          groupName.toLowerCase().contains('grade') &&
              (groupName.contains('6') ||
                  groupName.contains('7') ||
                  groupName.contains('8'));
    }

    // High school mentors can only mentor high school groups
    if (mentorRole == 'highSchoolMentor') {
      return groupName.toLowerCase().contains('high') ||
          groupName.toLowerCase().contains('grade') &&
              (groupName.contains('9') ||
                  groupName.contains('10') ||
                  groupName.contains('11') ||
                  groupName.contains('12'));
    }

    return false;
  }

  // 🚀 NEW: Check if a role can manage a specific unit type
  bool _canRoleManageUnitType(
      String role, String unitLevel, Map<String, dynamic> unitData) {
    final unitName = unitData['name'] as String? ?? '';

    // 🎯 NEW SYSTEM: Role-unit compatibility based on new levels

    // Moderator can manage moderator-level units
    if (role == 'moderator' && unitLevel == 'moderator') {
      return true;
    }

    // Director can manage director-level units
    if (role == 'director' && unitLevel == 'director') {
      return true;
    }

    // Coordinators can manage coordinator-level units of their education level
    if (role.contains('Coordinator') &&
        !role.contains('AssistantCoordinator') &&
        unitLevel == 'coordinator') {
      final roleEducationLevel =
          role.replaceAll('Coordinator', '').toLowerCase();
      final unitNameLower = unitName.toLowerCase();
      return unitNameLower
          .contains(roleEducationLevel.replaceAll('school', ' school'));
    }

    // Assistant coordinators can manage assistantCoordinator-level units of their education level
    if (role.contains('AssistantCoordinator') &&
        unitLevel == 'assistantCoordinator') {
      final roleEducationLevel =
          role.replaceAll('AssistantCoordinator', '').toLowerCase();
      final unitNameLower = unitName.toLowerCase();
      return unitNameLower
          .contains(roleEducationLevel.replaceAll('school', ' school'));
    }

    // Accountants can manage accountant-level units
    if (role == 'accountant' && unitLevel == 'accountant') {
      return true;
    }

    // Mentors can manage mentor-level units of their education level
    if ((role == 'middleSchoolMentor' || role == 'highSchoolMentor') &&
        unitLevel == 'mentor') {
      final roleEducationLevel = role.replaceAll('Mentor', '').toLowerCase();
      final unitNameLower = unitName.toLowerCase();
      return unitNameLower
          .contains(roleEducationLevel.replaceAll('school', ' school'));
    }

    // House leaders can manage houseLeader-level units
    if (role == 'houseLeader' && unitLevel == 'houseLeader') {
      return true;
    }

    // Student house leaders can manage studentHouseLeader-level units
    if (role == 'studentHouseLeader' && unitLevel == 'studentHouseLeader') {
      return true;
    }

    // House members can manage houseMember-level units (if any)
    if (role == 'houseMember' && unitLevel == 'houseMember') {
      return true;
    }

    // Student house members can manage studentHouseMember-level units (if any)
    if (role == 'studentHouseMember' && unitLevel == 'studentHouseMember') {
      return true;
    }

    return false;
  }

  // 🚀 Handle organizational unit transition when supervisor leaves
  Future<void> _handleOrganizationalUnitTransition(
    DocumentReference unitRef,
    Map<String, dynamic> unitData,
    String deletedRole,
    String userId,
  ) async {
    try {
      // Strategy depends on unit type and deleted role
      if (_unitManagingRoles.contains(deletedRole)) {
        // This was a unit-managing role - mark unit as needing reassignment
        await unitRef.update({
          'managedBy': FieldValue.delete(),
          'managedByMemberId': FieldValue.delete(),
          'status': 'pendingReassignment',
          'lastManagerId': userId, // 🎉 STANDARD: Recovery tracking
          'lastManagerRole': deletedRole, // 🎉 STANDARD: Audit tracking
          'managerChangedAt':
              FieldValue.serverTimestamp(), // 🎉 STANDARD: Change timestamp
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else if (deletedRole == 'middleSchoolMentor' ||
          deletedRole == 'highSchoolMentor') {
        // Mentor role - use standard deletion logic
        await unitRef.update({
          'managedBy': FieldValue.delete(),
          'managedByMemberId': FieldValue.delete(),
          'status': 'pendingReassignment',
          'lastManagerId': userId, // 🎉 STANDARD: Recovery tracking
          'lastManagerRole': deletedRole, // 🎉 STANDARD: Audit tracking
          'managerChangedAt':
              FieldValue.serverTimestamp(), // 🎉 STANDARD: Change timestamp
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        // Other dependent roles - update last known info
        await unitRef.update({
          'lastKnownUserId': userId,
          'lastKnownRoleRemoved': deletedRole,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      // Log error but don't throw - role deletion should still proceed
    }
  }

  // Helper method for responsive title sizing
  double _getResponsiveTitleSize(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth > 600) {
      return 32; // Large screens (tablets)
    } else if (screenWidth > 400) {
      return 28; // Medium screens (large phones)
    } else {
      return 24; // Small screens (small phones)
    }
  }

  // Helper method for responsive step indicator sizing
  double _getResponsiveStepSize(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth > 600) {
      return 16; // Large screens (tablets)
    } else if (screenWidth > 400) {
      return 14; // Medium screens (large phones)
    } else {
      return 12; // Small screens (small phones)
    }
  }

  // Helper method for responsive content padding
  double _getResponsiveContentPadding(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth > 600) {
      return 32; // Large screens (tablets)
    } else if (screenWidth > 400) {
      return 24; // Medium screens (large phones)
    } else {
      return 20; // Small screens (small phones)
    }
  }

  Widget _buildShimmerEffect() {
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 1500),
      tween: Tween(begin: 0.3, end: 0.7),
      builder: (context, value, child) {
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withOpacity(value * 0.3),
                Colors.white.withOpacity(value * 0.1),
                Colors.white.withOpacity(value * 0.3),
              ],
            ),
            borderRadius: BorderRadius.circular(4),
          ),
        );
      },
      onEnd: () {
        // Restart animation
        if (mounted) {
          setState(() {});
        }
      },
    );
  }
}
