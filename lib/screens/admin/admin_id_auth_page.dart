import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';

class AdminIdAuthPage extends StatefulWidget {
  const AdminIdAuthPage({super.key});

  @override
  _AdminIdAuthPageState createState() => _AdminIdAuthPageState();
}

class _AdminIdAuthPageState extends State<AdminIdAuthPage> {
  final TextEditingController _idController = TextEditingController();
  final TextEditingController _parentIdController = TextEditingController();
  String? _selectedRole;
  bool _isLoading = false;
  String _message = '';
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // All 11 assignable roles
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

  // Roles that require a parentId
  final Set<String> _rolesRequireParent = {
    'middleSchoolRegionCoordinator',
    'highSchoolRegionCoordinator',
    'universityRegionCoordinator',
    'middleSchoolUnitCoordinator',
    'highSchoolUnitCoordinator',
    'universityUnitCoordinator',
    'mentor',
    'student',
  };

  Future<void> assignRole(String role, String id, {String? parentId}) async {
    setState(() {
      _isLoading = true;
      _message = '';
    });

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
      final targetUsername = userDoc.data()?['username'] as String? ?? 'User';

      // Admin cannot assign to another admin unless keeping as admin
      if (targetUserRole == 'admin' && role != 'admin') {
        setState(() {
          _message = 'Permission Denied! Cannot change another admin\'s role.';
          _isLoading = false;
        });
        return;
      }

      if (targetUserRole == role) {
        setState(() {
          _message = '$targetUsername already has the ${_getRoleTitle(role)} role!';
          _isLoading = false;
        });
        return;
      }

      final currentUserUid = FirebaseAuth.instance.currentUser!.uid;
      final updateData = {
        'role': role,
        'assignedBy': currentUserUid,
      };
      if (_rolesRequireParent.contains(role) && parentId != null) {
        updateData['parentId'] = parentId;
      }
      await _firestore.collection('users').doc(id).update(updateData);
      final assignedToRef = _firestore.collection('users').doc(currentUserUid);
      await assignedToRef.set({
        'assignedTo': FieldValue.arrayUnion([id])
      }, SetOptions(merge: true));

      setState(() {
        _message = '${_getRoleTitle(role)} successfully assigned to $targetUsername!';
        _isLoading = false;
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
      case 'countryCoordinator':
        return 'Country Coordinator';
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
  Widget build(BuildContext context) {
    final showParentId = _rolesRequireParent.contains(_selectedRole);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text('Assign Role'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _idController,
              decoration: const InputDecoration(
                labelText: 'Enter User ID to authorize role',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            DropdownButtonFormField<String>(
              value: _selectedRole,
              hint: const Text("Select Role"),
              items: _roles.map((role) {
                return DropdownMenuItem(
                  value: role,
                  child: Text(_getRoleTitle(role)),
                );
              }).toList(),
              onChanged: (value) => setState(() => _selectedRole = value),
              decoration: const InputDecoration(
                filled: false,
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
              ),
            ),
            if (showParentId) ...[
              const SizedBox(height: 20),
              TextField(
                controller: _parentIdController,
                decoration: const InputDecoration(
                  labelText: 'Enter Supervisor ID',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
            const SizedBox(height: 20),
            Center(
              child: ElevatedButton(
                onPressed: _isLoading
                    ? null
                    : () {
                        if (_idController.text.isNotEmpty && _selectedRole != null) {
                          if (showParentId) {
                            assignRole(_selectedRole!, _idController.text.trim(), parentId: _parentIdController.text.trim());
                          } else {
                            assignRole(_selectedRole!, _idController.text.trim());
                          }
                        } else {
                          setState(() {
                            _message = 'Please enter a User ID and select a role!';
                          });
                        }
                      },
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Text('Authorize'),
              ),
            ),
            const SizedBox(height: 20),
            Center(
              child: Text(
                _message,
                style: TextStyle(
                  fontSize: 16,
                  color: _message.contains('successfully') ? Colors.green : Colors.red,
                ),
              ),
            ),
          ],
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
}
