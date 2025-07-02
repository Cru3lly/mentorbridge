import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter/services.dart';

class AdminIdAuthPage extends StatefulWidget {
  const AdminIdAuthPage({super.key});

  @override
  _AdminIdAuthPageState createState() => _AdminIdAuthPageState();
}

class _AdminIdAuthPageState extends State<AdminIdAuthPage> {
  final TextEditingController _idController = TextEditingController();
  final TextEditingController _supervisorIdController = TextEditingController();
  // New controllers for organizational units
  final TextEditingController _unitNameController = TextEditingController();
  String? _selectedUnitGender;

  String? _selectedRole;
  bool _isLoading = false;
  String _message = '';
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // State for live validation
  String? _targetUserName;
  String? _targetUserRole;
  bool _isCheckingTargetUser = false;
  
  String? _supervisorUserName;
  String? _supervisorUserRole;
  bool _isCheckingSupervisor = false;
  bool? _supervisorRoleMatches;

  // New state for wizard flow
  String? _selectedCity;
  String? _selectedCountry;
  String? _supervisorCountry;
  String? _targetUserGender;

  // State for mentor assignment
  List<Map<String, dynamic>> _mentorshipGroups = [];
  String? _selectedMentorshipGroupId;
  bool _isLoadingGroups = false;
  String? _supervisorUnitPath;
  String? _supervisorUnitGender;

  // Mock data - in a real app, this might come from a DB
  final List<String> _countries = ['Canada', 'USA', 'UK'];
  final Map<String, List<String>> _citiesByCountry = {
    'Canada': ['Toronto', 'Montreal', 'Vancouver', 'Calgary', 'Ottawa'],
    'USA': ['New York', 'Los Angeles', 'Chicago', 'Houston', 'Phoenix'],
    'UK': ['London', 'Manchester', 'Birmingham', 'Glasgow', 'Liverpool'],
  };

  final List<String> _roles = [
    'countryCoordinator',
    'middleSchoolRegionCoordinator',
    'highSchoolRegionCoordinator',
    'universityRegionCoordinator',
    'middleSchoolUnitCoordinator',
    'highSchoolUnitCoordinator',
    'universityUnitCoordinator',
    'mentor',
    'student',
    'user',
  ];

  final List<String> _genders = ['Male', 'Female'];

  // Defines the required supervisor role for a given role.
  static const Map<String, String> _supervisorRoleHierarchy = {
    'countryCoordinator': 'admin',
    'middleSchoolRegionCoordinator': 'countryCoordinator',
    'highSchoolRegionCoordinator': 'countryCoordinator',
    'universityRegionCoordinator': 'countryCoordinator',
    'middleSchoolUnitCoordinator': 'middleSchoolRegionCoordinator',
    'highSchoolUnitCoordinator': 'highSchoolRegionCoordinator',
    'universityUnitCoordinator': 'universityRegionCoordinator',
  };
  
  // Defines roles that manage a new organizational unit upon assignment.
  static const Set<String> _unitManagingRoles = {
    'countryCoordinator',
    'middleSchoolRegionCoordinator',
    'highSchoolRegionCoordinator',
    'universityRegionCoordinator',
    'middleSchoolUnitCoordinator',
    'highSchoolUnitCoordinator',
    'universityUnitCoordinator',
  };

  // Defines roles that require a supervisor but don't create a new unit.
  static const Set<String> _dependentRoles = {'student'};

  Future<void> assignRole() async {
    setState(() { _isLoading = true; _message = ''; });
    final targetUserId = _idController.text.trim();
    final supervisorId = _supervisorIdController.text.trim();
    
    // For Country Coordinator, supervisor is the admin themselves
    final finalSupervisorId = _selectedRole == 'countryCoordinator' 
        ? FirebaseAuth.instance.currentUser!.uid 
        : supervisorId;

    if (targetUserId.isEmpty || _selectedRole == null) {
      setState(() { _message = 'Please enter a User ID and select a role!'; _isLoading = false; });
      return;
    }

    final batch = _firestore.batch();

    try {
      final targetUserRef = _firestore.collection('users').doc(targetUserId);
      final targetUserDoc = await targetUserRef.get();
      if (!targetUserDoc.exists) {
        setState(() { _message = 'User ID does not exist!'; _isLoading = false; });
        return;
      }

      final targetUserData = targetUserDoc.data();
      if (targetUserData != null && (targetUserData)['role'] == 'admin') {
         setState(() { _message = 'Cannot change the role of another admin.'; _isLoading = false; });
        return;
      }

      DocumentReference? parentUnitRef;
      DocumentSnapshot? supervisorDoc;
      String? newUnitName;
      String? parentUnitName;
      String? countryName;

      // Validate supervisor and get parent unit path
      final requiredSupervisorRole = _supervisorRoleHierarchy[_selectedRole];
      if (requiredSupervisorRole != null) {
        if (finalSupervisorId.isEmpty) {
          setState(() { _message = 'This role requires a Supervisor ID.'; _isLoading = false; });
          return;
        }
        supervisorDoc = await _firestore.collection('users').doc(finalSupervisorId).get();
        if (!supervisorDoc.exists) {
          setState(() { _message = 'Supervisor ID does not exist.'; _isLoading = false; });
          return;
        }
        final supervisorData = supervisorDoc.data() as Map<String, dynamic>?;
        if (supervisorData == null) {
          setState(() { _message = 'Could not read supervisor data.'; _isLoading = false; });
          return;
        }
        final supervisorRole = supervisorData['role'];
        if (supervisorRole != requiredSupervisorRole) {
          setState(() { _message = 'Invalid Supervisor. Expected role: ${_getRoleTitle(requiredSupervisorRole)}.'; _isLoading = false; });
          return;
        }
        
        final parentEntityPath = supervisorData['managesEntity'] as String?;
        if (parentEntityPath != null) {
          parentUnitRef = _firestore.doc(parentEntityPath);
          final parentUnitDoc = await parentUnitRef.get();
          final parentUnitData = parentUnitDoc.data() as Map<String, dynamic>?;
          parentUnitName = parentUnitData?['name'] as String?;
          countryName = parentUnitData?['country'] as String?; // For region coordinators
        }
      }

      // Prepare new unit data
      if (_unitManagingRoles.contains(_selectedRole)) {
        
        // For Region Coordinators, the unit name is the city name from the dropdown
        if (_selectedRole!.contains('RegionCoordinator')) {
          if (_selectedCity == null) {
            setState(() { _message = 'Please select a City for the new region.'; _isLoading = false; });
            return;
          }
          newUnitName = _selectedCity;
        } 
        // For Unit Coordinators, auto-generate the name, so no text input is needed.
        else if (_selectedRole!.contains('UnitCoordinator')) {
           if (parentUnitName == null) {
              setState(() { _message = 'Could not determine the region name from the supervisor.'; _isLoading = false; });
              return;
           }
           final level = _getRoleTitle(_selectedRole!).replaceAll(' Unit Coordinator', ''); // e.g., "High School"
           newUnitName = '$parentUnitName - $level Unit ($_selectedUnitGender)';
        }
        // For Country Coordinator
        else if (_selectedRole == 'countryCoordinator') {
          if (_selectedCountry == null) {
            setState(() { _message = 'Please select a Country.'; _isLoading = false; });
            return;
          }
          newUnitName = _selectedCountry;
        }

        if (_unitManagingRoles.contains(_selectedRole) && _selectedUnitGender == null) {
          setState(() {
            _message = 'Please select a gender for the unit.';
            _isLoading = false;
          });
          return;
        }
        final String? unitGender = _selectedUnitGender;
        
        // Redundancy check before committing
        final currentUserRole = (targetUserDoc.data() as Map<String, dynamic>)['role'] as String?;
        final currentManagesEntityPath = (targetUserDoc.data() as Map<String, dynamic>)['managesEntity'] as String?;

        if (currentUserRole == _selectedRole) {
            bool isRedundant = false;
            if (_selectedRole == 'user') {
                isRedundant = true;
            } else if (_dependentRoles.contains(_selectedRole)) {
                if (currentManagesEntityPath != null && currentManagesEntityPath == (supervisorDoc?.data() as Map<String, dynamic>?)?['managesEntity']) {
                    isRedundant = true;
                }
            } else if (_unitManagingRoles.contains(_selectedRole)) {
                if (currentManagesEntityPath != null) {
                    final currentUserUnitDoc = await _firestore.doc(currentManagesEntityPath).get();
                    if (currentUserUnitDoc.exists) {
                        final currentUserUnitData = currentUserUnitDoc.data() as Map<String, dynamic>;
                        final currentParentUnitRef = currentUserUnitData['parentUnit'] as DocumentReference?;
                        final newParentPath = parentUnitRef?.path;
                        final currentParentPath = currentParentUnitRef?.path;

                        if (currentUserUnitData['name'] == newUnitName &&
                            currentUserUnitData['gender'] == unitGender &&
                            currentParentPath == newParentPath) {
                            isRedundant = true;
                        }
                    }
                }
            }

            if (isRedundant) {
                setState(() {
                    _message = 'This user already has this exact role and assignment.';
                    _isLoading = false;
                });
                return;
            }
        }
        
        DocumentReference newUnitRef = _firestore.collection('organizationalUnits').doc();
        
        String? newUnitLevel;
        if (_selectedRole!.contains('UnitCoordinator')) {
          newUnitLevel = 'unit';
        } else if (_selectedRole!.contains('RegionCoordinator')) newUnitLevel = 'region';
        else if (_selectedRole! == 'countryCoordinator') newUnitLevel = 'country';

        batch.set(newUnitRef, {
          'name': newUnitName,
          'type': 'unit',
          'level': newUnitLevel,
          if(parentUnitRef != null) 'parentUnit': parentUnitRef,
          'country': _selectedRole == 'countryCoordinator' ? newUnitName : countryName,
          if(unitGender != null) 'gender': unitGender,
          'createdAt': FieldValue.serverTimestamp(),
        });
        
        // Update user with the path of the new unit they manage
        batch.update(targetUserRef, {
          'role': _selectedRole,
          'managesEntity': newUnitRef.path,
          'parentId': FieldValue.delete(),
          'assignedTo': FieldValue.delete(),
          'assignedBy': FirebaseAuth.instance.currentUser!.uid,
        });

      } else if (_selectedRole == 'mentor') {
        if (finalSupervisorId.isEmpty) {
          setState(() { _message = 'Mentor role requires a Supervisor ID (Unit Coordinator).'; _isLoading = false; });
          return;
        }
        
        // Final validation for mentor supervisor
        final supervisorDocForMentor = await _firestore.collection('users').doc(finalSupervisorId).get();
        if (!supervisorDocForMentor.exists) {
          setState(() { _message = 'Supervisor ID does not exist.'; _isLoading = false; });
          return;
        }
        final supervisorDataForMentor = supervisorDocForMentor.data() as Map<String, dynamic>;
        final supervisorRoleForMentor = supervisorDataForMentor['role'] as String?;
        const validMentorSupervisors = {'middleSchoolUnitCoordinator', 'highSchoolUnitCoordinator'};
        if (!validMentorSupervisors.contains(supervisorRoleForMentor)) {
           setState(() { _message = 'Invalid Supervisor. Expected role: Middle or High School Unit Coordinator.'; _isLoading = false; });
           return;
        }

        if (_selectedMentorshipGroupId == null) {
          setState(() { _message = 'Please select a class for the mentor.'; _isLoading = false; });
          return;
        }

        final selectedGroupData = _mentorshipGroups.firstWhere((g) => g['id'] == _selectedMentorshipGroupId);

        if (selectedGroupData['isPending'] == true) {
          final newGroupRef = _firestore.collection('organizationalUnits').doc();
          
          batch.set(newGroupRef, {
            'name': selectedGroupData['name'],
            'type': 'mentorshipGroup',
            'parentUnit': _firestore.doc(_supervisorUnitPath!),
            'createdAt': FieldValue.serverTimestamp(),
            'gender': _supervisorUnitGender,
            'currentMentorId': targetUserId,
          });

          batch.update(targetUserRef, {
            'role': 'mentor',
            'managesEntity': newGroupRef.path,
            'parentId': FieldValue.delete(),
            'assignedTo': FieldValue.delete(),
            'assignedBy': FirebaseAuth.instance.currentUser!.uid,
          });

        } else {
          final groupPath = 'organizationalUnits/${selectedGroupData['id']}';
          final groupRef = _firestore.doc(groupPath);

          final groupDoc = await groupRef.get();
          if(groupDoc.exists && groupDoc.data()?['currentMentorId'] != null) {
            setState(() { _message = 'This class is already assigned to another mentor.'; _isLoading = false; });
            return;
          }

          batch.update(groupRef, {'currentMentorId': targetUserId});
          batch.update(targetUserRef, {
            'role': 'mentor',
            'managesEntity': groupRef.path,
            'parentId': FieldValue.delete(),
            'assignedTo': FieldValue.delete(),
            'assignedBy': FirebaseAuth.instance.currentUser!.uid,
          });
        }

      } else if (_dependentRoles.contains(_selectedRole)) {
          // Logic for Student who don't create units but are linked to their supervisor's unit
          if (finalSupervisorId.isEmpty) {
            setState(() { _message = 'This role requires a Supervisor ID.'; _isLoading = false; });
            return;
          }
           final supervisorDoc = await _firestore.collection('users').doc(finalSupervisorId).get();
           if (!supervisorDoc.exists) {
              setState(() { _message = 'Supervisor ID does not exist.'; _isLoading = false; });
              return;
           }

           final supervisorData = supervisorDoc.data() as Map<String, dynamic>;
           final supervisorRole = supervisorData['role'] as String?;

          // Specific validation for student role
          if (_selectedRole == 'student' && supervisorRole != 'universityUnitCoordinator') {
            setState(() { _message = 'Invalid Supervisor. Expected role: ${_getRoleTitle('universityUnitCoordinator')}.'; _isLoading = false; });
            return;
          }

           final managedEntity = supervisorData['managesEntity'];
           if(managedEntity == null) {
                setState(() { _message = 'Supervisor does not manage any unit.'; _isLoading = false; });
                return;
           }
           batch.update(targetUserRef, {
            'role': _selectedRole,
            'managesEntity': managedEntity,
            'parentId': FieldValue.delete(),
            'assignedTo': FieldValue.delete(),
            'assignedBy': FirebaseAuth.instance.currentUser!.uid,
          });

      } else { // For 'user' or other simple roles
         batch.update(targetUserRef, {
          'role': _selectedRole,
          'managesEntity': FieldValue.delete(),
          'parentId': FieldValue.delete(),
          'assignedTo': FieldValue.delete(),
          'assignedBy': FirebaseAuth.instance.currentUser!.uid,
        });
      }

      await batch.commit();
      
      // Temporarily remove listeners to prevent the success message from being cleared by the text field controllers.
      _idController.removeListener(_onIdChanged);
      _supervisorIdController.removeListener(_onSupervisorIdChanged);

      setState(() {
        _message = '${_getRoleTitle(_selectedRole!)} successfully assigned!';
        _isLoading = false;
        _idController.clear();
        _supervisorIdController.clear();
        _selectedRole = null;
        _selectedUnitGender = null;
        _selectedCity = null;
        _selectedCountry = null;
        _selectedMentorshipGroupId = null;
        _mentorshipGroups = [];
        _targetUserName = null;
        _targetUserRole = null;
        _isCheckingTargetUser = false;
        _targetUserGender = null;
      });

      // Re-add listeners for the next operation.
      _idController.addListener(_onIdChanged);
      _supervisorIdController.addListener(_onSupervisorIdChanged);

    } catch (e) {
      setState(() { _message = 'An error occurred: $e'; _isLoading = false; });
    }
  }

  String _getRoleTitle(String role) {
    switch (role) {
      case 'admin': return 'Admin';
      case 'countryCoordinator': return 'Country Coordinator';
      case 'middleSchoolRegionCoordinator': return 'Middle School Region Coordinator';
      case 'highSchoolRegionCoordinator': return 'High School Region Coordinator';
      case 'universityRegionCoordinator': return 'University Region Coordinator';
      case 'middleSchoolUnitCoordinator': return 'Middle School Unit Coordinator';
      case 'highSchoolUnitCoordinator': return 'High School Unit Coordinator';
      case 'universityUnitCoordinator': return 'University Unit Coordinator';
      case 'mentor': return 'Mentor';
      case 'student': return 'Student';
      case 'user': return 'User';
      default: return 'User';
    }
  }

  @override
  void initState() {
    super.initState();
    _idController.addListener(_onIdChanged);
    _supervisorIdController.addListener(_onSupervisorIdChanged);
  }

  void _onIdChanged() async {
    final id = _idController.text.trim();
    setState(() => _message = '');
     if (id.isEmpty) {
      setState(() {
        _targetUserName = null;
        _targetUserRole = null;
        _isCheckingTargetUser = false;
        _targetUserGender = null;
      });
      return;
    }
    setState(() => _isCheckingTargetUser = true);
    try {
      final userDoc = await _firestore.collection('users').doc(id).get();
      if (!mounted) return;
      if (userDoc.exists) {
        final userData = userDoc.data();
        setState(() {
          _targetUserName = "${userData?['firstName'] ?? ''} ${userData?['lastName'] ?? ''}".trim();
          _targetUserRole = userData?['role'] as String?;
          _targetUserGender = userData?['gender'] as String?;
        });
      } else {
        setState(() {
          _targetUserName = 'User not found';
          _targetUserRole = null;
          _targetUserGender = null;
        });
      }
    } catch (e) {
      setState(() {
        _targetUserName = 'Error fetching user';
         _targetUserRole = null;
         _targetUserGender = null;
      });
    } finally {
       if (mounted) setState(() => _isCheckingTargetUser = false);
    }
  }

  void _onSupervisorIdChanged() async {
    final id = _supervisorIdController.text.trim();
    setState(() { 
      _message = '';
      // Reset mentor-specific fields whenever supervisor changes
      _mentorshipGroups = [];
      _selectedMentorshipGroupId = null;
      _isLoadingGroups = false;
      _supervisorUnitPath = null;
      _supervisorUnitGender = null;
    });
     if (id.isEmpty || _selectedRole == null) {
      setState(() {
        _supervisorUserName = null;
        _supervisorUserRole = null;
        _isCheckingSupervisor = false;
        _supervisorRoleMatches = null;
        _supervisorCountry = null;
        _selectedCity = null;
      });
      return;
    }
    setState(() => _isCheckingSupervisor = true);
    try {
       final supervisorDoc = await _firestore.collection('users').doc(id).get();
       if (!mounted) return;
        if (supervisorDoc.exists) {
          final supervisorData = supervisorDoc.data();
          final supervisorRole = supervisorData?['role'] as String?;
          final requiredSupervisorRole = _supervisorRoleHierarchy[_selectedRole];
          
          bool isMatch = false;
          if (_selectedRole == 'mentor') {
              const validMentorSupervisors = {'middleSchoolUnitCoordinator', 'highSchoolUnitCoordinator'};
              isMatch = validMentorSupervisors.contains(supervisorRole);
          } else if (_selectedRole == 'student') {
              isMatch = supervisorRole == 'universityUnitCoordinator';
          } else if (requiredSupervisorRole != null) {
              isMatch = supervisorRole == requiredSupervisorRole;
          } else {
              isMatch = true; // No supervisor needed
          }

          String? tempSupervisorCountry;
          final parentEntityPath = supervisorData?['managesEntity'] as String?;
          if (_selectedRole!.contains('RegionCoordinator') && parentEntityPath != null) {
             try {
                final unitDoc = await _firestore.doc(parentEntityPath).get();
                if(unitDoc.exists) {
                   tempSupervisorCountry = unitDoc.data()?['country'] as String?;
                }
             } catch(e) {
                // Silently ignore if path is invalid or other error
             }
          }

          setState(() {
             _supervisorUserName = "${supervisorData?['firstName'] ?? ''} ${supervisorData?['lastName'] ?? ''}".trim();
             _supervisorUserRole = supervisorRole;
             _supervisorCountry = tempSupervisorCountry;
             _supervisorRoleMatches = isMatch;
             if (_supervisorRoleMatches != true) {
               _selectedCity = null;
             }
          });

          if (isMatch && _selectedRole == 'mentor' && parentEntityPath != null) {
            final unitDoc = await _firestore.doc(parentEntityPath).get();
            if (unitDoc.exists) {
              if (mounted) {
                setState(() {
                  _supervisorUnitPath = parentEntityPath;
                  _supervisorUnitGender = unitDoc.data()?['gender'] as String?;
                });
              }
              _fetchMentorshipGroupsForUnit(parentEntityPath);
            }
          }

        } else {
           setState(() {
            _supervisorUserName = 'User not found';
            _supervisorUserRole = null;
            _supervisorRoleMatches = false;
            _supervisorCountry = null;
            _selectedCity = null;
          });
        }
    } catch (e) {
       setState(() {
        _supervisorUserName = 'Error fetching user';
        _supervisorUserRole = null;
        _supervisorRoleMatches = false;
        _supervisorCountry = null;
        _selectedCity = null;
      });
    } finally {
       if (mounted) setState(() => _isCheckingSupervisor = false);
    }
  }

  Future<void> _fetchMentorshipGroupsForUnit(String unitPath) async {
    setState(() {
      _isLoadingGroups = true;
      _mentorshipGroups = [];
      _selectedMentorshipGroupId = null;
    });

    try {
      final unitRef = _firestore.doc(unitPath);
      final groupsSnapshot = await _firestore
          .collection('organizationalUnits')
          .where('parentUnit', isEqualTo: unitRef)
          .where('type', isEqualTo: 'mentorshipGroup')
          .get();

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
        for (var doc in mentorDocs.docs) {
          mentorNames[doc.id] =
              _getFullNameFromFields(doc.data()['firstName'], doc.data()['lastName']);
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

      if (mounted) {
        setState(() {
          _mentorshipGroups = groups;
          _isLoadingGroups = false;
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
    if (_supervisorUnitPath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Cannot create class: Supervisor's unit path not found.")),
      );
      return;
    }

    final gradeNameBase = _getBaseGradeName(grade, unitType);
    
    final allGroupsForGrade = _mentorshipGroups
        .where((doc) => (doc['name'] as String).startsWith(gradeNameBase))
        .toList();

    final newSuffix = String.fromCharCode('A'.codeUnitAt(0) + allGroupsForGrade.length);
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
      _message = '';
    });
  }

  void _showCreateGroupDialog() async {
    final supervisorRole = _supervisorUserRole;
    if (supervisorRole == null) return;
    
    String unitType;
    List<int> allGrades;

    if (supervisorRole.contains('highSchool')) {
      unitType = 'highSchool';
      allGrades = [9, 10, 11, 12];
    } else if (supervisorRole.contains('middleSchool')) {
      unitType = 'middleSchool';
      allGrades = [6, 7, 8];
    } else if (supervisorRole.contains('university')) {
      unitType = 'university';
      allGrades = [1, 2, 3, 4];
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Cannot determine unit type from supervisor's role.")),
      );
      return;
    }
    
    showDialog(
      context: context,
      builder: (context) {
        return SimpleDialog(
          title: const Text('Create New Class'),
          children: allGrades.map((grade) {
            return SimpleDialogOption(
              onPressed: () {
                Navigator.of(context).pop();
                _createMentorshipGroup(grade, unitType);
              },
              child: Center(child: Text(_getBaseGradeName(grade, unitType))),
            );
          }).toList(),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    bool requiresSupervisor = _supervisorRoleHierarchy.containsKey(_selectedRole) || _dependentRoles.contains(_selectedRole) || _selectedRole == 'mentor';
    bool createsUnit = _unitManagingRoles.contains(_selectedRole);
    bool isUnit = _selectedRole?.contains('UnitCoordinator') ?? false;
    bool isRegion = _selectedRole?.contains('RegionCoordinator') ?? false;
    bool isCountry = _selectedRole == 'countryCoordinator';

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.pop(),
        ),
        title: const Text('Assign Role (Admin)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
       body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF8EC5FC), Color(0xFFE0C3FC)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SingleChildScrollView(
          padding: EdgeInsets.only(
            top: kToolbarHeight + MediaQuery.of(context).viewPadding.top + 20,
            bottom: 20,
            left: 20,
            right: 20,
          ),
          child: Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 500),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Authorize User',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Assign roles, create units, and manage the organizational hierarchy.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white70, fontSize: 16),
                    ),
                    const SizedBox(height: 24),
                    _buildTextField(_idController, 'Enter User ID'),
                    if (_isCheckingTargetUser)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8.0),
                        child: Center(child: Text("Checking user...", style: TextStyle(color: Colors.white70, fontStyle: FontStyle.italic)))),
                    if (!_isCheckingTargetUser && _targetUserName != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0, left: 4.0),
                        child: Row(
                          children: [
                            Icon(
                              _targetUserName == 'User not found' ? Icons.error : Icons.check_circle,
                              color: _targetUserName == 'User not found' ? const Color(0xFFC62828) : const Color(0xFF2E7D32),
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                _targetUserName == 'User not found' 
                                  ? 'User not found.' 
                                  : "$_targetUserName (${_getRoleTitle(_targetUserRole ?? 'user')})",
                                style: TextStyle(
                                  color: _targetUserName == 'User not found' ? const Color(0xFFC62828) : const Color(0xFF2E7D32),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                    const SizedBox(height: 10),
                    _buildDropdown(_roles, _selectedRole, 'Select Role to Assign', (value) {
                      setState(() {
                         _message = '';
                         _selectedRole = value;
                         _supervisorIdController.clear();
                         _supervisorRoleMatches = null;
                         _supervisorUserName = null;
                         _selectedCity = null;
                         _selectedCountry = null;
                         _selectedUnitGender = null;
                         _onSupervisorIdChanged();
                      });
                    }),
                    
                    if (requiresSupervisor && !isCountry) ...[
                      const SizedBox(height: 20),
                      _buildTextField(_supervisorIdController, 'Enter Supervisor ID'),
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0, left: 4.0, right: 4.0),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline, color: Colors.white70, size: 18),
                            const SizedBox(width: 8),
                            Flexible(
                              child: RichText(
                                text: TextSpan(
                                  style: const TextStyle(color: Colors.white70, fontStyle: FontStyle.italic),
                                  children: <TextSpan>[
                                    const TextSpan(text: "Supervisor's role must be: "),
                                    TextSpan(
                                      text: _getSupervisorTitleForRole(_selectedRole!),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_isCheckingSupervisor)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8.0),
                          child: Center(child: Text("Checking supervisor...", style: TextStyle(color: Colors.white70, fontStyle: FontStyle.italic)))),
                      if (!_isCheckingSupervisor && _supervisorUserName != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0, left: 4.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    _supervisorRoleMatches == true ? Icons.check_circle : Icons.error,
                                    color: _supervisorRoleMatches == true ? const Color(0xFF2E7D32) : const Color(0xFFC62828),
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Text(
                                      _supervisorUserName == 'User not found'
                                        ? 'Supervisor not found.'
                                        : "Supervisor: $_supervisorUserName (${_getRoleTitle(_supervisorUserRole ?? 'user')})",
                                      style: TextStyle(
                                        color: _supervisorRoleMatches == true ? const Color(0xFF2E7D32) : const Color(0xFFC62828),
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              if (_supervisorRoleMatches != null && _supervisorUserName != 'User not found')
                                Padding(
                                  padding: const EdgeInsets.only(left: 28.0, top: 4.0),
                                  child: Text(
                                    _supervisorRoleMatches!
                                        ? "This user is a valid supervisor for the selected role."
                                        : "Error: This user cannot supervise the selected role. A '${_getSupervisorTitleForRole(_selectedRole!)}' is required.",
                                    style: TextStyle(
                                      color: _supervisorRoleMatches! ? const Color(0xFF2E7D32) : const Color(0xFFC62828),
                                      fontWeight: FontWeight.bold
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                    ],
                    
                    // Country Dropdown for Country Coordinator
                    if (isCountry) ...[
                      const SizedBox(height: 20),
                      _buildDropdown(_countries, _selectedCountry, 'Select Country', (value) {
                         setState(() {
                           _selectedCountry = value;
                           _message = '';
                         });
                      }),
                    ],

                    // City Dropdown for Region Coordinator
                    if (isRegion && _supervisorRoleMatches == true) ...[
                      const SizedBox(height: 20),
                      _buildDropdown(
                        _citiesByCountry[_supervisorCountry] ?? [],
                        _selectedCity,
                        'Select City for the Region',
                         (value) {
                           setState(() {
                             _selectedCity = value;
                             _message = '';
                            });
                         }
                      ),
                    ],
                    
                    // Gender Toggle for Unit and Region Coordinators
                    if ((isUnit && _supervisorRoleMatches == true) || (isRegion && _selectedCity != null) || (isCountry && _selectedCountry != null)) ...[
                       const SizedBox(height: 20),
                       _buildGenderToggle(),
                    ],
                    
                    if (_selectedRole == 'mentor' && _supervisorRoleMatches == true) ...[
                      const SizedBox(height: 20),
                      if (_isLoadingGroups)
                        const Center(child: CircularProgressIndicator(color: Colors.white))
                      else if (_mentorshipGroups.isEmpty)
                        Center(
                          child: Column(
                            children: [
                              const Padding(
                                padding: EdgeInsets.all(8.0),
                                child: Text(
                                  "This unit has no classes (mentorship groups) to assign.",
                                  style: TextStyle(color: Colors.white70, fontStyle: FontStyle.italic),
                                  textAlign: TextAlign.center,
                                  ),
                              ),
                              const SizedBox(height: 10),
                              ElevatedButton.icon(
                                icon: const Icon(Icons.add),
                                label: const Text('Create New Class'),
                                onPressed: _showCreateGroupDialog,
                                style: ElevatedButton.styleFrom(
                                  foregroundColor: Colors.deepPurple,
                                  backgroundColor: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        DropdownButtonFormField2<String>(
                          isExpanded: true,
                          value: _selectedMentorshipGroupId,
                           decoration: InputDecoration(
                            contentPadding: const EdgeInsets.symmetric(vertical: 16),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                            filled: true,
                            fillColor: Colors.white.withOpacity(0.8),
                          ),
                          hint: const Text(
                            'Select a class to assign',
                            style: TextStyle(fontSize: 14),
                          ),
                          onChanged: (value) {
                            setState(() {
                              _selectedMentorshipGroupId = value;
                              _message = '';
                            });
                          },
                          items: [
                            ..._mentorshipGroups.map((group) {
                              final mentorText = group['mentorName'] != null
                                  ? ' (Mentor: ${group['mentorName']})'
                                  : ' (Empty)';
                              final isAssigned = group['currentMentorId'] != null;
                              return DropdownMenuItem<String>(
                                value: group['id'],
                                enabled: !isAssigned,
                                child: Text(
                                  '${group['name']}$mentorText',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: isAssigned ? Colors.grey : Colors.black,
                                    fontStyle: isAssigned ? FontStyle.italic : FontStyle.normal,
                                  ),
                                ),
                              );
                            }),
                            const DropdownMenuItem<String>(
                              enabled: false,
                              child: Divider(),
                            ),
                            DropdownMenuItem<String>(
                              enabled: false,
                              child: Center(
                                child: TextButton.icon(
                                  icon: const Icon(Icons.add),
                                  label: const Text('Create New Class'),
                                  onPressed: _showCreateGroupDialog,
                                ),
                              ),
                            ),
                          ],
                        ),
                    ],

                    const SizedBox(height: 30),
                    Center(
                      child: SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                           style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.deepPurple,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15.0),
                            ),
                            elevation: 8,
                            shadowColor: Colors.deepPurple.shade300,
                          ),
                          onPressed: _isLoading ? null : assignRole,
                          child: _isLoading
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Text('Authorize Role', style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (_message.isNotEmpty)
                      Center(
                        child: Text(
                          _message,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: _message.contains('success') || _message.contains('successfully') ? const Color(0xFF2E7D32) : const Color(0xFFC62828),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGenderToggle() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Select Gender for the Unit/Region", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        ToggleButtons(
          isSelected: [ _selectedUnitGender == 'Male', _selectedUnitGender == 'Female' ],
          onPressed: (index) {
            setState(() {
              _message = '';
              _selectedUnitGender = index == 0 ? 'Male' : 'Female';
            });
          },
          borderRadius: BorderRadius.circular(15.0),
          selectedColor: Colors.white,
          color: Colors.white70,
          fillColor: Colors.deepPurple.withOpacity(0.5),
          selectedBorderColor: Colors.deepPurple,
          borderColor: Colors.white.withOpacity(0.5),
          children: const [
            Padding(padding: EdgeInsets.symmetric(horizontal: 24.0), child: Text('Male')),
            Padding(padding: EdgeInsets.symmetric(horizontal: 24.0), child: Text('Female')),
          ],
        ),
      ],
    );
  }

  Widget _buildTextField(TextEditingController controller, String label) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white70),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15.0),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.5)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15.0),
          borderSide: const BorderSide(color: Colors.white),
        ),
        suffixIcon: IconButton(
          icon: const Icon(Icons.paste, color: Colors.white70),
          tooltip: 'Paste',
          onPressed: () async {
            final data = await Clipboard.getData(Clipboard.kTextPlain);
            final text = data?.text;
            if (text != null) {
              controller.text = text;
              controller.selection = TextSelection.fromPosition(
                TextPosition(offset: controller.text.length),
              );
            }
          },
        ),
      ),
    );
  }

  Widget _buildDropdown(List<String> items, String? value, String hint, ValueChanged<String?> onChanged) {
    return DropdownButtonFormField2<String>(
      value: value,
      isExpanded: true,
      decoration: InputDecoration(
        contentPadding: const EdgeInsets.symmetric(vertical: 16),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
        filled: true,
        fillColor: Colors.white.withOpacity(0.8),
      ),
      hint: Text(hint, style: const TextStyle(fontSize: 14)),
      onChanged: onChanged,
      items: items.map((item) => DropdownMenuItem<String>(
        value: item,
        child: Text(
          items == _roles ? _getRoleTitle(item) : item,
          style: const TextStyle(fontSize: 14),
        ),
      )).toList(),
    );
  }

  @override
  void dispose() {
    _idController.removeListener(_onIdChanged);
    _supervisorIdController.removeListener(_onSupervisorIdChanged);
    _idController.dispose();
    _supervisorIdController.dispose();
    super.dispose();
  }

  String _getFullNameFromFields(String? name, String? lastName, {String id = ''}) {
    if ((name == null || name.isEmpty) && (lastName == null || lastName.isEmpty)) {
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

  String _getSupervisorTitleForRole(String role) {
    if (role == 'mentor') {
      return 'Middle or High School Unit Coordinator';
    }
    if (role == 'student') {
      return _getRoleTitle('universityUnitCoordinator');
    }
    final requiredRole = _supervisorRoleHierarchy[role];
    if (requiredRole != null) {
      return _getRoleTitle(requiredRole);
    }
    return 'valid supervisor';
  }
}
