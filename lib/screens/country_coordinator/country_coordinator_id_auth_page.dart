import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:glassmorphism/glassmorphism.dart';
import 'dart:ui';
import 'package:dropdown_button2/dropdown_button2.dart';

class CountryCoordinatorIdAuthPage extends StatefulWidget {
  const CountryCoordinatorIdAuthPage({super.key});

  @override
  State<CountryCoordinatorIdAuthPage> createState() => _CountryCoordinatorIdAuthPageState();
}

class _CountryCoordinatorIdAuthPageState extends State<CountryCoordinatorIdAuthPage> {
  final TextEditingController _idController = TextEditingController();
  final TextEditingController _parentIdController = TextEditingController();
  String? _selectedRole;
  bool _isLoading = false;
  String _message = '';
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? _currentUserRoleText;
  bool _isCheckingUserRole = false;
  String? _currentUserName;
  String? _parentUserName;
  String? _parentUserRole;
  bool _isCheckingParentUser = false;
  bool? _parentRoleMatches;

  final List<String> _roles = [
    // 'admin', // asla eklenmeyecek
    // 'countryCoordinator', // asla eklenmeyecek
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

  final Set<String> _regionRoles = {
    'middleSchoolRegionCoordinator',
    'highSchoolRegionCoordinator',
    'universityRegionCoordinator',
  };

  final Set<String> _rolesRequireParent = {
    'middleSchoolUnitCoordinator',
    'highSchoolUnitCoordinator',
    'universityUnitCoordinator',
    'mentor',
    'student',
  };

  // Assign role function
  Future<void> assignRole(String role, String id, {String? parentId}) async {
    setState(() {
      _isLoading = true;
      _message = '';
    });

    final currentUserUid = FirebaseAuth.instance.currentUser!.uid;
    if (id == currentUserUid) {
      setState(() {
        _message = 'You cannot assign a role to yourself.';
        _isLoading = false;
      });
      return;
    }

    if (id.isEmpty) {
      setState(() {
        _message = 'Please enter a valid User ID!';
        _isLoading = false;
      });
      return;
    }
    if (_rolesRequireParent.contains(role) && (parentId == null || parentId.isEmpty)) {
      setState(() {
        _message = 'Please enter a valid Supervisor ID!';
        _isLoading = false;
      });
      return;
    }

    // Unit coordinator atanırken parentId'nin doğru region coordinator olup olmadığını kontrol et
    final Map<String, String> unitToRegion = {
      'middleSchoolUnitCoordinator': 'middleSchoolRegionCoordinator',
      'highSchoolUnitCoordinator': 'highSchoolRegionCoordinator',
      'universityUnitCoordinator': 'universityRegionCoordinator',
    };
    if (role == 'student') {
      final parentDoc = await _firestore.collection('users').doc(parentId).get();
      final parentRole = parentDoc.data()?['role'] as String?;
      if (parentRole != 'universityUnitCoordinator') {
        setState(() {
          _message = 'Supervisor ID must belong to a University Unit Coordinator!';
          _isLoading = false;
        });
        return;
      }
    } else if (role == 'mentor') {
      final parentDoc = await _firestore.collection('users').doc(parentId).get();
      final parentRole = parentDoc.data()?['role'] as String?;
      if (parentRole != 'middleSchoolUnitCoordinator' && parentRole != 'highSchoolUnitCoordinator') {
        setState(() {
          _message = 'Supervisor ID must belong to a Middle School or High School Unit Coordinator!';
          _isLoading = false;
        });
        return;
      }
    } else {
      // Eski unit/region mantığı
      final Map<String, String> unitToRegion = {
        'middleSchoolUnitCoordinator': 'middleSchoolRegionCoordinator',
        'highSchoolUnitCoordinator': 'highSchoolRegionCoordinator',
        'universityUnitCoordinator': 'universityRegionCoordinator',
      };
      if (unitToRegion.containsKey(role)) {
        final parentDoc = await _firestore.collection('users').doc(parentId).get();
        final parentRole = parentDoc.data()?['role'] as String?;
        if (parentRole != unitToRegion[role]) {
          setState(() {
            _message = 'Supervisor ID must belong to a ${_getRoleTitle(unitToRegion[role]!)}!';
            _isLoading = false;
          });
          return;
        }
      }
    }

    // Region rollerine atama yapılırken parentId otomatik atanacak, inputtan alınmayacak
    if (_regionRoles.contains(role)) {
      parentId = currentUserUid;
    }

    try {
      final userDoc = await _firestore.collection('users').doc(id).get();
      if (!userDoc.exists) {
        setState(() {
          _message = 'User ID does not exist!';
          _isLoading = false;
        });
        return;
      }

      final targetUserRole = userDoc.data()?['role'] as String? ?? '';
      if (targetUserRole == 'admin' || targetUserRole == 'countryCoordinator') {
        setState(() {
          _message = 'You are not allowed to change this user\'s role.';
          _isLoading = false;
        });
        return;
      }

      final targetFirstName = userDoc.data()?['firstName'] as String? ?? '';
      final targetLastName = userDoc.data()?['lastName'] as String? ?? '';
      final targetFullName = ('$targetFirstName $targetLastName').trim();

      if (targetUserRole == role) {
        setState(() {
          _message = '${targetFullName.isNotEmpty ? targetFullName : 'User'} already has the ${_getRoleTitle(role)} role!';
          _isLoading = false;
        });
        return;
      }

      final Map<String, dynamic> updateData = {
        'role': role,
        'assignedBy': currentUserUid,
      };
      if ((_rolesRequireParent.contains(role) && parentId != null) || _regionRoles.contains(role)) {
        updateData['parentId'] = parentId!;
      }
      if (role == 'user') {
        updateData['parentId'] = FieldValue.delete();
      }
      await _firestore.collection('users').doc(id).update(updateData);
      final assignedToRef = _firestore.collection('users').doc(currentUserUid);
      await assignedToRef.set({
        'assignedTo': FieldValue.arrayUnion([id])
      }, SetOptions(merge: true));

      setState(() {
        _message = '${_getRoleTitle(role)} successfully assigned to $targetFullName!';
        _isLoading = false;
        _currentUserName = null;
        _selectedRole = null;
        _parentUserName = null;
        _parentUserRole = null;
        _parentRoleMatches = null;
      });
      _idController.clear();
      _parentIdController.clear();
      setState(() => _selectedRole = null);
    } catch (e) {
      setState(() {
        _message = 'An error occurred: $e';
        _isLoading = false;
      });
    }
  }

  String _getRoleTitle(String role) {
    switch (role) {
      case 'middleSchoolRegionCoordinator':
        return 'Middle School Region Coordinator';
      case 'highSchoolRegionCoordinator':
        return 'High School Region Coordinator';
      case 'universityRegionCoordinator':
        return 'University Region Coordinator';
      case 'middleSchoolUnitCoordinator':
        return 'Middle School Unit Coordinator';
      case 'highSchoolUnitCoordinator':
        return 'High School Unit Coordinator';
      case 'universityUnitCoordinator':
        return 'University Unit Coordinator';
      case 'mentor':
        return 'Mentor';
      case 'student':
        return 'Student';
      case 'user':
        return 'User';
      default:
        return 'User';
    }
  }

  @override
  void initState() {
    super.initState();
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
      if (id == currentUserUid) {
        final fullName = _getFullNameFromFields(name, lastName, id: id);
        setState(() {
          _currentUserName = fullName;
          _currentUserRoleText = '$fullName (You)';
          _isCheckingUserRole = false;
        });
        return;
      }
      if (role == 'admin' || role == 'countryCoordinator') {
        setState(() {
          _currentUserRoleText = 'You are not allowed to view the information of this user.';
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

  void _onParentIdChanged() async {
    setState(() => _message = '');
    final id = _parentIdController.text.trim();
    if (id.isEmpty) {
      setState(() {
        _parentUserName = null;
        _parentUserRole = null;
        _parentRoleMatches = null;
      });
      return;
    }
    setState(() {
      _isCheckingParentUser = true;
    });
    try {
      final userDoc = await _firestore.collection('users').doc(id).get();
      if (!userDoc.exists) {
        setState(() {
          _parentUserName = null;
          _parentUserRole = 'User not found.';
          _parentRoleMatches = null;
          _isCheckingParentUser = false;
        });
        return;
      }
      final name = userDoc.data()?['firstName'] as String?;
      final lastName = userDoc.data()?['lastName'] as String?;
      final role = userDoc.data()?['role'] as String?;
      if (role == 'admin' || role == 'countryCoordinator') {
        setState(() {
          _parentUserRole = 'You are not allowed to view the information of this user.';
          _parentUserName = null;
          _parentRoleMatches = null;
          _isCheckingParentUser = false;
        });
        return;
      }
      // Yeni parent kontrol mantığı
      bool? match;
      if (_selectedRole == 'student') {
        match = (role == 'universityUnitCoordinator');
      } else if (_selectedRole == 'mentor') {
        match = (role == 'middleSchoolUnitCoordinator' || role == 'highSchoolUnitCoordinator');
      } else {
        // Eski unit/region mantığı
        final Map<String, String> unitToRegion = {
          'middleSchoolUnitCoordinator': 'middleSchoolRegionCoordinator',
          'highSchoolUnitCoordinator': 'highSchoolRegionCoordinator',
          'universityUnitCoordinator': 'universityRegionCoordinator',
        };
        if (unitToRegion.containsKey(_selectedRole)) {
          match = (role == unitToRegion[_selectedRole]);
        } else {
          match = true; // Diğer roller için parent kontrolü yok
        }
      }
      setState(() {
        _parentUserName = _getFullNameFromFields(name, lastName, id: id);
        _parentUserRole = role != null ? _getRoleTitle(role) : null;
        _parentRoleMatches = match;
        _isCheckingParentUser = false;
      });
    } catch (e) {
      setState(() {
        _parentUserName = null;
        _parentUserRole = 'Could not get user information.';
        _parentRoleMatches = null;
        _isCheckingParentUser = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final showParentId = _rolesRequireParent.contains(_selectedRole);
    final isRegionRole = _regionRoles.contains(_selectedRole);
    final selectedRoleTitle = _selectedRole != null ? _getRoleTitle(_selectedRole!) : null;
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
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => context.push('/settings'),
            tooltip: 'Settings',
          ),
        ],
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
          child: Padding(
            padding: const EdgeInsets.only(top: kToolbarHeight + 16.0),
            child: GlassmorphicContainer(
              width: MediaQuery.of(context).size.width * 0.95 > 500 ? 500 : MediaQuery.of(context).size.width * 0.95,
              height: MediaQuery.of(context).size.height * 0.9 - kToolbarHeight,
              constraints: BoxConstraints(minHeight: MediaQuery.of(context).size.height * 0.9 - kToolbarHeight),
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
                  Colors.white.withOpacity(0.60),
                  Colors.white.withOpacity(0.10),
                ],
              ),
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      // User ID - custom glass container for dynamic height
                      Padding(
                        padding: const EdgeInsets.only(bottom: 0),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                            child: Container(
                              constraints: const BoxConstraints(minHeight: 120),
                              width: double.infinity,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(color: Colors.white.withOpacity(0.4), width: 1.5),
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.white.withOpacity(0.18),
                                    Colors.white.withOpacity(0.04),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('User ID', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87)),
                                    const SizedBox(height: 8),
                                    TextField(
                                      controller: _idController,
                                      maxLength: 40,
                                      style: const TextStyle(fontSize: 16, color: Colors.black87),
                                      decoration: InputDecoration(
                                        filled: true,
                                        fillColor: Colors.white.withOpacity(0.18),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(12),
                                          borderSide: BorderSide(color: Colors.white),
                                        ),
                                        isDense: true,
                                        suffixIcon: IconButton(
                                          icon: const Icon(Icons.paste),
                                          tooltip: 'Paste',
                                          onPressed: () async {
                                            final data = await Clipboard.getData('text/plain');
                                            if (data?.text != null) {
                                              _idController.text = data!.text!;
                                              _idController.selection = TextSelection.fromPosition(
                                                TextPosition(offset: _idController.text.length),
                                              );
                                              setState(() => _message = '');
                                              _onIdChanged();
                                            }
                                          },
                                        ),
                                      ),
                                      onChanged: (val) {
                                        setState(() => _message = '');
                                        _onIdChanged();
                                      },
                                    ),
                                    if (_idController.text.trim().isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 8.0),
                                        child: _isCheckingUserRole
                                            ? const Text('Checking user...', style: TextStyle(fontSize: 13, color: Colors.grey))
                                            : Row(
                                                children: [
                                                  Icon(
                                                    _currentUserRoleText?.contains('current role is:') == true
                                                        ? Icons.check_circle
                                                        : Icons.error,
                                                    color: _currentUserRoleText?.contains('current role is:') == true
                                                        ? Colors.green
                                                        : Colors.red,
                                                    size: 18,
                                                  ),
                                                  const SizedBox(width: 6),
                                                  Flexible(
                                                    child: Text(
                                                      _currentUserName != null && _currentUserRoleText?.contains('current role is:') == true
                                                          ? '${_currentUserName!} (${_currentUserRoleText!.split(": ").last})'
                                                          : _currentUserRoleText ?? '',
                                                      style: TextStyle(
                                                        fontSize: 13,
                                                        color: _currentUserRoleText?.contains('current role is:') == true
                                                            ? Colors.green
                                                            : Colors.red,
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
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),
                      // Role Dropdown Glass Field
                      GlassmorphicContainer(
                        width: double.infinity,
                        height: 120,
                        borderRadius: 18,
                        blur: 12,
                        border: 1.5,
                        linearGradient: LinearGradient(
                          colors: [
                            Colors.white.withOpacity(0.18),
                            Colors.white.withOpacity(0.04),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderGradient: LinearGradient(
                          colors: [
                            Colors.white.withOpacity(0.40),
                            Colors.white.withOpacity(0.10),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Role', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87)),
                              const SizedBox(height: 8),
                              DropdownButtonFormField2<String>(
                                value: _selectedRole,
                                isExpanded: true,
                                decoration: InputDecoration(
                                  filled: true,
                                  fillColor: Colors.white.withOpacity(0.18),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: Colors.white),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                                ),
                                style: const TextStyle(fontSize: 16, color: Colors.black87),
                                hint: const Text("Select role", style: TextStyle(color: Colors.black54)),
                                items: _roles.map((role) {
                                  Color bgColor;
                                  if (role.contains('RegionCoordinator')) {
                                    bgColor = const Color(0xFFE3F2FD); // Mavi
                                  } else if (role.contains('UnitCoordinator')) {
                                    bgColor = const Color(0xFFE8F5E9); // Yeşil
                                  } else if (role == 'mentor' || role == 'student') {
                                    bgColor = const Color(0xFFFFF3E0); // Turuncu
                                  } else if (role == 'user') {
                                    bgColor = const Color(0xFFF3E5F5); // Mor
                                  } else {
                                    bgColor = Colors.white;
                                  }
                                  return DropdownMenuItem<String>(
                                    value: role,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: bgColor,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                                      child: Text(_getRoleTitle(role), style: const TextStyle(fontSize: 16, color: Colors.black87)),
                                    ),
                                  );
                                }).toList(),
                                selectedItemBuilder: (context) {
                                  return _roles.map((role) {
                                    return Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 0.0),
                                      child: Text(
                                        _getRoleTitle(role),
                                        style: const TextStyle(fontSize: 15, color: Colors.black87),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    );
                                  }).toList();
                                },
                                onChanged: (value) {
                                  setState(() {
                                    _selectedRole = value;
                                    _message = '';
                                  });
                                  if (_parentIdController.text.trim().isNotEmpty) {
                                    _onParentIdChanged();
                                  }
                                },
                                dropdownStyleData: DropdownStyleData(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(16),
                                    color: Colors.white,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.08),
                                        blurRadius: 12,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  elevation: 4,
                                  offset: const Offset(0, 4),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      // Only add spacing if Supervisor ID is not shown
                      if (!(showParentId && !isRegionRole)) const SizedBox(height: 28),
                      // Supervisor ID - custom glass container for dynamic height
                      if (showParentId && !isRegionRole) ...[
                        const SizedBox(height: 28),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 0),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(18),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                              child: Container(
                                constraints: const BoxConstraints(minHeight: 120),
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(color: Colors.white.withOpacity(0.4), width: 1.5),
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.white.withOpacity(0.18),
                                      Colors.white.withOpacity(0.04),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Supervisor ID', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87)),
                                      const SizedBox(height: 8),
                                      TextField(
                                        controller: _parentIdController,
                                        maxLength: 40,
                                        style: const TextStyle(fontSize: 16, color: Colors.black87),
                                        decoration: InputDecoration(
                                          filled: true,
                                          fillColor: Colors.white.withOpacity(0.18),
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(12),
                                            borderSide: BorderSide(color: Colors.white),
                                          ),
                                          isDense: true,
                                          suffixIcon: IconButton(
                                            icon: const Icon(Icons.paste),
                                            tooltip: 'Paste',
                                            onPressed: () async {
                                              final data = await Clipboard.getData('text/plain');
                                              if (data?.text != null) {
                                                _parentIdController.text = data!.text!;
                                                _parentIdController.selection = TextSelection.fromPosition(
                                                  TextPosition(offset: _parentIdController.text.length),
                                                );
                                                setState(() => _message = '');
                                                _onParentIdChanged();
                                              }
                                            },
                                          ),
                                        ),
                                        onChanged: (val) {
                                          setState(() => _message = '');
                                          _onParentIdChanged();
                                        },
                                      ),
                                      if (_parentIdController.text.trim().isNotEmpty)
                                        Padding(
                                          padding: const EdgeInsets.only(top: 8.0),
                                          child: _isCheckingParentUser
                                              ? const Text('Checking Supervisor user...', style: TextStyle(fontSize: 13, color: Colors.grey))
                                              : Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Row(
                                                      children: [
                                                        Icon(
                                                          _parentRoleMatches == true ? Icons.check_circle : Icons.cancel,
                                                          color: _parentRoleMatches == true ? Colors.green : Colors.red,
                                                          size: 18,
                                                        ),
                                                        const SizedBox(width: 6),
                                                        Flexible(
                                                          child: _parentUserName != null && _parentUserRole != null
                                                              ? Text(
                                                                  'Supervisor: $_parentUserName (${_parentUserRole!})',
                                                                  style: TextStyle(
                                                                    fontSize: 13,
                                                                    color: _parentRoleMatches == true ? Colors.green : Colors.red,
                                                                  ),
                                                                )
                                                              : (_parentUserRole != null
                                                                  ? Text(_parentUserRole!, style: const TextStyle(fontSize: 13, color: Colors.red))
                                                                  : const SizedBox.shrink()),
                                                        ),
                                                      ],
                                                    ),
                                                    if (_parentRoleMatches == true)
                                                      const Padding(
                                                        padding: EdgeInsets.only(left: 24.0, top: 2),
                                                        child: Text(
                                                          'Supervisor role matches.',
                                                          style: TextStyle(fontSize: 13, color: Colors.green),
                                                        ),
                                                      ),
                                                    if (_parentRoleMatches == false)
                                                      Padding(
                                                        padding: const EdgeInsets.only(left: 24.0, top: 2),
                                                        child: Column(
                                                          crossAxisAlignment: CrossAxisAlignment.start,
                                                          children: [
                                                            const Text(
                                                              'Supervisor role does not match.',
                                                              style: TextStyle(fontSize: 13, color: Colors.red),
                                                            ),
                                                            if (_selectedRole == 'mentor')
                                                              const Text(
                                                                'The Supervisor must be a Middle School Unit Coordinator or High School Unit Coordinator.',
                                                                style: TextStyle(fontSize: 13, color: Colors.red),
                                                              )
                                                            else if (_selectedRole == 'student')
                                                              const Text(
                                                                'The Supervisor must be a University Unit Coordinator.',
                                                                style: TextStyle(fontSize: 13, color: Colors.red),
                                                              )
                                                            else if (_selectedRole == 'middleSchoolUnitCoordinator' || _selectedRole == 'highSchoolUnitCoordinator' || _selectedRole == 'universityUnitCoordinator')
                                                              const Text(
                                                                'The Supervisor must be the relevant Region Coordinator.',
                                                                style: TextStyle(fontSize: 13, color: Colors.red),
                                                              )
                                                            else
                                                              const Text(
                                                                'Supervisor role does not match. Make sure you have selected the correct upper authority.',
                                                                style: TextStyle(fontSize: 13, color: Colors.red),
                                                              ),
                                                          ],
                                                        ),
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
                        ),
                        const SizedBox(height: 28),
                      ],
                      // Summary Glass Card - custom glass container for dynamic height
                      Padding(
                        padding: const EdgeInsets.only(bottom: 0),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                            child: Container(
                              constraints: const BoxConstraints(minHeight: 120),
                              width: double.infinity,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(color: Colors.white.withOpacity(0.4), width: 1.5),
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.white.withOpacity(0.18),
                                    Colors.white.withOpacity(0.04),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Wrap(
                                      crossAxisAlignment: WrapCrossAlignment.center,
                                      spacing: 6,
                                      children: [
                                        const Icon(Icons.info_outline, color: Colors.blueGrey, size: 18),
                                        Text('Summary:', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    // User summary
                                    Wrap(
                                      crossAxisAlignment: WrapCrossAlignment.center,
                                      spacing: 6,
                                      children: [
                                        const Icon(Icons.person, size: 18, color: Colors.grey),
                                        Text('User: ', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
                                        Text(
                                          (_idController.text.trim() == FirebaseAuth.instance.currentUser?.uid)
                                              ? (_currentUserName != null ? '$_currentUserName (You)' : _idController.text.trim())
                                              : _currentUserName ?? _idController.text.trim(),
                                          style: TextStyle(
                                            color: _currentUserRoleText?.contains('current role is:') == true
                                                ? Colors.green
                                                : (_currentUserRoleText == 'User not found.' || _currentUserRoleText == 'You are not allowed to view the information of this user.')
                                                    ? Colors.red
                                                    : Colors.black87,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    // Role to assign summary
                                    Text.rich(
                                      TextSpan(
                                        children: [
                                          const WidgetSpan(
                                            child: Icon(Icons.assignment_ind, size: 18, color: Colors.grey),
                                          ),
                                          const WidgetSpan(child: SizedBox(width: 6)),
                                          const TextSpan(text: 'Role to assign: ', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
                                          TextSpan(
                                            text: selectedRoleTitle ?? '',
                                            style: TextStyle(
                                              color: (showParentId && !isRegionRole && _parentIdController.text.trim().isNotEmpty)
                                                  ? (_parentRoleMatches == true
                                                      ? Colors.green
                                                      : (_parentRoleMatches == false ? Colors.red : Colors.black87))
                                                  : Colors.black87,
                                            ),
                                          ),
                                        ],
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    // Parent summary
                                    if (showParentId && !isRegionRole && _parentIdController.text.trim().isNotEmpty)
                                      Wrap(
                                        crossAxisAlignment: WrapCrossAlignment.center,
                                        spacing: 6,
                                        children: [
                                          const Icon(Icons.supervisor_account, size: 18, color: Colors.grey),
                                          Text('Supervisor: ', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
                                          Text(
                                            _parentUserName ?? _parentIdController.text.trim(),
                                            style: TextStyle(
                                              color: _parentRoleMatches == true
                                                  ? Colors.green
                                                  : Colors.red,
                                            ),
                                          ),
                                        ],
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),
                      // Error or Success Message - custom glass container for dynamic height
                      if (_message.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 0),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(18),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                              child: Container(
                                constraints: const BoxConstraints(minHeight: 48),
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(color: Colors.white.withOpacity(0.4), width: 1.5),
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.white.withOpacity(0.18),
                                      Colors.white.withOpacity(0.04),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 12.0),
                                  child: Text(
                                    _message,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: _message.contains('successfully')
                                          ? Colors.green
                                          : Colors.red,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      SizedBox(height: _message.isNotEmpty && _message.length > 50 ? 56 : 28),
                      // Authorize Button - modern glass effect with transparent button
                      Center(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(30),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                            child: Container(
                              width: 200,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(30),
                                border: Border.all(color: Colors.white.withOpacity(0.5), width: 1.5),
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.white.withOpacity(0.25),
                                    Colors.white.withOpacity(0.05),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                              ),
                              child: OutlinedButton(
                                onPressed: _isLoading
                                    ? null
                                    : () {
                                  if (_idController.text.isNotEmpty && _selectedRole != null) {
                                    if (_regionRoles.contains(_selectedRole)) {
                                      assignRole(
                                        _selectedRole!,
                                        _idController.text.trim(),
                                      );
                                    } else if (showParentId) {
                                      assignRole(
                                        _selectedRole!,
                                        _idController.text.trim(),
                                        parentId: _parentIdController.text.trim(),
                                      );
                                    } else {
                                      assignRole(
                                        _selectedRole!,
                                        _idController.text.trim(),
                                      );
                                    }
                                  } else {
                                    setState(() {
                                      _message =
                                      'Please enter a User ID and select a role!';
                                    });
                                  }
                                },
                                style: OutlinedButton.styleFrom(
                                  minimumSize: const Size(180, 52),
                                  side: BorderSide(color: Colors.white.withOpacity(0.8), width: 2),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                                  backgroundColor: Colors.transparent,
                                  foregroundColor: Colors.white,
                                  textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                                ),
                                child: _isLoading
                                    ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                                    : Text('Assign Role', style: TextStyle(color: const Color.fromARGB(255, 75, 96, 232), fontWeight: FontWeight.w600, fontSize: 18)),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 64),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _idController.dispose();
    _parentIdController.dispose();
    super.dispose();
  }

  // Helper to get full name from user map or fields
  String _getFullNameFromFields(String? first, String? last, {String? id}) {
    final f = (first ?? '').trim();
    final l = (last ?? '').trim();
    if (f.isNotEmpty && l.isNotEmpty) return '$f $l';
    if (f.isNotEmpty) return f;
    return id ?? '';
  }
}
