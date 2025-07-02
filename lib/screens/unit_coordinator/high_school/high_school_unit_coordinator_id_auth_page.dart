import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/services.dart';
import 'package:glassmorphism/glassmorphism.dart';
import 'package:dropdown_button2/dropdown_button2.dart';

class HighSchoolUnitCoordinatorIdAuthPage extends StatefulWidget {
  const HighSchoolUnitCoordinatorIdAuthPage({super.key});

  @override
  State<HighSchoolUnitCoordinatorIdAuthPage> createState() =>
      _HighSchoolUnitCoordinatorIdAuthPageState();
}

class _HighSchoolUnitCoordinatorIdAuthPageState
    extends State<HighSchoolUnitCoordinatorIdAuthPage> {
  final TextEditingController _idController = TextEditingController();
  String? _selectedRole;
  bool _isLoading = false;
  String _message = '';
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? _currentUserRoleText;
  bool _isCheckingUserRole = false;
  String? _currentUserName;

  // New state variables for the new architecture
  List<Map<String, dynamic>> _mentorshipGroups = [];
  String? _selectedMentorshipGroupId;
  bool _isLoadingGroups = true;
  String? _unitPath; // Path of the unit this coordinator manages
  String? _unitGenderType; // e.g., 'Male', 'Female', 'Mixed'

  final List<String> _roles = ['mentor', 'user'];

  @override
  void initState() {
    super.initState();
    _fetchUnitAndGroups();
    _idController.addListener(_onIdChanged);
  }

  @override
  void dispose() {
    _idController.removeListener(_onIdChanged);
    _idController.dispose();
    super.dispose();
  }

  Future<void> _fetchUnitAndGroups() async {
    setState(() {
      _isLoadingGroups = true;
      _mentorshipGroups = []; // Reset
      _unitPath = null; // Reset
    });
    final currentUserUid = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserUid == null) {
      setState(() {
        _isLoadingGroups = false;
        _message = "Authentication error. Please login again.";
      });
      return;
    }

    try {
      final userDoc =
          await _firestore.collection('users').doc(currentUserUid).get();
      final entityPath = userDoc.data()?['managesEntity'] as String?;

      if (entityPath == null || !entityPath.startsWith('organizationalUnits/')) {
        setState(() {
          _isLoadingGroups = false;
          _message = "Error: Your account is not configured to manage a unit.";
        });
        return;
      }
      
      final unitDoc = await _firestore.doc(entityPath).get();
      if (!unitDoc.exists) {
        setState(() {
          _isLoadingGroups = false;
          _message = "Error: Managed unit not found in the database.";
        });
        return;
      }

      // If we've reached here, the path is valid. Let's set it.
      setState(() {
        _unitPath = entityPath;
        _unitGenderType = unitDoc.data()?['gender'] as String? ?? 'Mixed';
      });

      // Now, fetch groups using the now-guaranteed-to-be-non-null _unitPath
      final groupsSnapshot = await _firestore
          .collection('organizationalUnits')
          .where('parentUnit', isEqualTo: _firestore.doc(_unitPath!)) // Use parentUnit reference
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

      setState(() {
        _mentorshipGroups = groups;
        _isLoadingGroups = false;
      });

    } catch (e) {
      setState(() {
        _isLoadingGroups = false;
        _message = "An error occurred while fetching data: $e";
      });
    }
  }

  Future<void> _updateRole() async {
    if (_selectedRole == null || _idController.text.trim().isEmpty) {
      setState(() => _message = 'Please select a role and enter a User ID.');
      return;
    }
    if (_selectedRole == 'mentor' && _selectedMentorshipGroupId == null) {
      setState(
          () => _message = 'Please select a class for the mentor.');
      return;
    }

    setState(() {
      _isLoading = true;
      _message = '';
    });

    final targetUserId = _idController.text.trim();
    final currentUserUid = FirebaseAuth.instance.currentUser!.uid;

    if (targetUserId == currentUserUid) {
      setState(() {
        _message = 'You cannot assign a role to yourself.';
        _isLoading = false;
      });
      return;
    }

    try {
      final userDoc = await _firestore.collection('users').doc(targetUserId).get();
      if (!userDoc.exists) {
        setState(() {
          _message = 'User ID does not exist!';
          _isLoading = false;
        });
        return;
      }
      
      final targetUserRole = userDoc.data()?['role'] as String? ?? '';
      final targetFirstName = userDoc.data()?['firstName'] as String? ?? '';
      final targetLastName = userDoc.data()?['lastName'] as String? ?? '';
      final targetFullName = ('$targetFirstName $targetLastName').trim();
      
      if (targetUserRole == _selectedRole) {
        if (_selectedRole == 'mentor') {
          final managesEntity = userDoc.data()?['managesEntity'] as String?;
          if (managesEntity == 'organizationalUnits/$_selectedMentorshipGroupId') {
            setState(() {
              _message = '${targetFullName.isNotEmpty ? targetFullName : 'User'} is already the mentor of this class!';
              _isLoading = false;
            });
            return;
          }
        } else {
            setState(() {
              _message = '${targetFullName.isNotEmpty ? targetFullName : 'User'} already has this role!';
              _isLoading = false;
            });
            return;
        }
      }

      final batch = _firestore.batch();
      final targetUserRef = userDoc.reference;
      final unitCoordinatorRef = _firestore.collection('users').doc(currentUserUid);

      if (_selectedRole == 'mentor') {
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
            'parentUnit': _firestore.doc(_unitPath!),
            'createdAt': FieldValue.serverTimestamp(),
            'gender': _unitGenderType,
            'currentMentorId': targetUserId,
          });

          batch.update(targetUserRef, {
            'role': 'mentor',
            'managesEntity': newGroupRef.path,
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
          batch.update(targetUserRef, { 'role': 'mentor', 'managesEntity': groupRef.path });
        }
      } else if (_selectedRole == 'user') {
        final previousManagedEntity = userDoc.data()?['managesEntity'] as String?;
        if (previousManagedEntity != null && previousManagedEntity.startsWith('organizationalUnits/')) {
            final oldGroupDoc = await _firestore.doc(previousManagedEntity).get();
            if(oldGroupDoc.exists && oldGroupDoc.data()?['type'] == 'mentorshipGroup') {
                batch.update(oldGroupDoc.reference, {'currentMentorId': FieldValue.delete()});
            }
        }
        
        batch.update(targetUserRef, {
          'role': 'user',
          'managesEntity': FieldValue.delete(),
          'parentId': FieldValue.delete(), 
        });
        
        batch.update(unitCoordinatorRef, {'assignedTo': FieldValue.arrayRemove([targetUserId])});
      }

      await batch.commit();

      setState(() {
        _message = 'Role successfully updated for $targetFullName!';
        _isLoading = false;
        _idController.clear();
        _selectedRole = null;
        _selectedMentorshipGroupId = null;
        _currentUserName = null;
        _currentUserRoleText = null;
        _fetchUnitAndGroups(); 
      });

    } catch (e) {
      setState(() {
        _message = 'An error occurred: $e';
        _isLoading = false;
      });
    }
  }

  void _onIdChanged() async {
    final id = _idController.text.trim();
    if (id.isEmpty) {
      setState(() {
        _currentUserRoleText = null;
        _currentUserName = null;
      });
      return;
    }
    setState(() {
      _isCheckingUserRole = true;
    });
    try {
      final userDoc = await _firestore.collection('users').doc(id).get();
      if (!userDoc.exists) {
        setState(() {
          _currentUserRoleText = 'User not found.';
          _currentUserName = null;
          _isCheckingUserRole = false;
        });
        return;
      }
      final role = userDoc.data()?['role'] as String?;
      final name = userDoc.data()?['firstName'] as String?;
      final lastName = userDoc.data()?['lastName'] as String?;
      final currentUserUid = FirebaseAuth.instance.currentUser!.uid;
      final currentUserDoc = await _firestore.collection('users').doc(currentUserUid).get();
      final parentId = currentUserDoc.data()?['parentId'] as String?;
      if (id == currentUserUid) {
        final fullName = _getFullNameFromFields(name, lastName, id: id);
        final roleTitle = _getRoleTitle(role ?? '-');
        setState(() {
          _currentUserName = fullName;
          _currentUserRoleText = roleTitle == '-' ? '$fullName (You)' : '$fullName (You) ($roleTitle)';
          _isCheckingUserRole = false;
        });
        return;
      }
      if (id == parentId || role == 'admin' || role == 'countryCoordinator' || (role?.contains('regionCoordinator') ?? false) || (role?.contains('unitCoordinator') ?? false) || (role?.contains('student') ?? false)) {
        setState(() {
          _currentUserRoleText = 'You are not allowed to view this user.';
          _currentUserName = null;
          _isCheckingUserRole = false;
        });
        return;
      }
      setState(() {
        _currentUserName = _getFullNameFromFields(name, lastName, id: id);
        _currentUserRoleText = (role != null && name != null)
            ? "$name's current role is: ${_getRoleTitle(role)}"
            : (role != null ? "Current role is: ${_getRoleTitle(role)}" : 'No role information found.');
        _isCheckingUserRole = false;
      });
    } catch (e) {
      setState(() {
        _currentUserRoleText = 'Could not get role information.';
        _currentUserName = null;
        _isCheckingUserRole = false;
      });
    }
  }

  String _getRoleTitle(String role) {
    switch (role) {
      case 'admin':
        return 'Admin';
      case 'country-coordinator':
        return 'Country Coordinator';
      case 'region-coordinator':
        return 'Region Coordinator';
      case 'unit-coordinator':
        return 'Unit Coordinator';
      case 'mentor':
        return 'Mentor';
      case 'user':
        return 'User';
      default:
        return '-';
    }
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

  String _getBaseGradeName(int grade) {
    final suffix = _getOrdinalSuffix(grade);
    return '$grade$suffix Grade';
  }

  void _createMentorshipGroup(int grade) {
    if (_unitPath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Cannot create class: Unit path not found.")),
      );
      return;
    }

    final gradeNameBase = _getBaseGradeName(grade);
    
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
    // For high school, grades are 9, 10, 11, 12.
    const List<int> allGrades = [9, 10, 11, 12];
    
    showDialog(
      context: context,
      builder: (context) {
        return SimpleDialog(
          title: const Text('Create New Class'),
          children: allGrades.map((grade) {
            return SimpleDialogOption(
              onPressed: () {
                Navigator.of(context).pop();
                _createMentorshipGroup(grade);
              },
              child: Center(child: Text(_getBaseGradeName(grade))),
            );
          }).toList(),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text('Assign Role'),
        centerTitle: true,
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF8EC5FC), Color(0xFFE0C3FC)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.only(top: kToolbarHeight - 8.0, bottom: 0.0),
              child: GlassmorphicContainer(
                width: MediaQuery.of(context).size.width * 0.95 > 500
                    ? 500
                    : MediaQuery.of(context).size.width * 0.95,
                height: MediaQuery.of(context).size.height * 0.85,
                constraints: BoxConstraints(minHeight: MediaQuery.of(context).size.height * 0.7),
                borderRadius: 32,
                blur: 18,
                alignment: Alignment.center,
                border: 2,
                linearGradient: LinearGradient(
                  colors: [
                    Colors.white.withOpacity(0.25),
                    Colors.white.withOpacity(0.05),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderGradient: LinearGradient(
                  colors: [
                    Colors.white.withOpacity(0.3),
                    Colors.white.withOpacity(0.1),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Authorize User',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            shadows: [
                              Shadow(
                                blurRadius: 10.0,
                                color: Colors.black26,
                                offset: Offset(2.0, 2.0),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Enter a User ID and assign a role within your unit.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white70, fontSize: 16),
                        ),
                        const SizedBox(height: 24),
                        TextField(
                          controller: _idController,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: 'User ID',
                            labelStyle: const TextStyle(color: Colors.white70),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(15.0),
                              borderSide: BorderSide(color: Colors.white.withOpacity(0.5)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(15.0),
                              borderSide: const BorderSide(color: Colors.white),
                            ),
                            prefixIcon: const Icon(Icons.person, color: Colors.white70),
                             suffix: _isCheckingUserRole
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : null,
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]')),
                          ],
                        ),
                         if (_currentUserName != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              _currentUserRoleText ?? '',
                              style: const TextStyle(color: Colors.white, fontSize: 16),
                            ),
                          ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField2<String>(
                          value: _selectedRole,
                          isExpanded: true,
                          decoration: InputDecoration(
                            contentPadding: const EdgeInsets.symmetric(vertical: 16),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                            filled: true,
                            fillColor: Colors.white.withOpacity(0.8),
                          ),
                          hint: const Text(
                            'Select Role to Assign',
                            style: TextStyle(fontSize: 14),
                          ),
                          onChanged: (value) {
                            setState(() {
                              _selectedRole = value;
                              if (value != 'mentor') {
                                _selectedMentorshipGroupId = null;
                              }
                            });
                          },
                          items: _roles
                              .map((item) => DropdownMenuItem<String>(
                                    value: item,
                                    child: Text(
                                      _getRoleTitle(item),
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                  ))
                              .toList(),
                        ),
                        const SizedBox(height: 16),
                        if (_selectedRole == 'mentor')
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (_isLoadingGroups)
                              const Center(child: CircularProgressIndicator(color: Colors.white,))
                            else if (_mentorshipGroups.isEmpty)
                               Center(
                                 child: Column(
                                   children: [
                                     const Text('You need to create a class first.', style: TextStyle(color: Colors.white70)),
                                     const SizedBox(height: 10),
                                     if (_unitPath != null)
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
                                  'Select a class',
                                  style: TextStyle(fontSize: 14),
                                ),
                                onChanged: (value) {
                                  setState(() {
                                    _selectedMentorshipGroupId = value;
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
                              const SizedBox(height: 16),
                          ],
                        ),
                        
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _updateRole,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.deepPurple,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15.0),
                              ),
                              elevation: 8,
                              shadowColor: Colors.deepPurple.shade300,
                            ),
                            child: _isLoading
                                ? const CircularProgressIndicator(color: Colors.white)
                                : const Text(
                                    'Update Role',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        if (_message.isNotEmpty)
                          Text(
                            _message,
                            style: TextStyle(
                                color: _message.contains('success')
                                    ? Colors.greenAccent
                                    : Colors.redAccent,
                                fontSize: 16,
                                fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center,
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
} 