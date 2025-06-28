import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';

class HighSchoolRegionCoordinatorIdAuthPage extends StatefulWidget {
  const HighSchoolRegionCoordinatorIdAuthPage({super.key});

  @override
  State<HighSchoolRegionCoordinatorIdAuthPage> createState() => _HighSchoolRegionCoordinatorIdAuthPageState();
}

class _HighSchoolRegionCoordinatorIdAuthPageState extends State<HighSchoolRegionCoordinatorIdAuthPage> {
  final TextEditingController _idController = TextEditingController();
  String? _selectedRole;
  bool _isLoading = false;
  String _message = '';
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final List<String> _roles = [
    'highSchoolUnitCoordinator',
    'user',
  ];

  Future<void> assignRole(String role, String id) async {
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
      if (targetUserRole == 'admin' || targetUserRole == 'countryCoordinator' || targetUserRole == 'regionCoordinator') {
        setState(() {
          _message = 'Permission Denied!';
          _isLoading = false;
        });
        return;
      }

      final targetUsername = userDoc.data()?['username'] as String? ?? 'User';

      if (targetUserRole == role) {
        setState(() {
          _message =
              '$targetUsername already has the ${_getRoleTitle(role)} role!';
          _isLoading = false;
        });
        return;
      }

      final currentUserUid = FirebaseAuth.instance.currentUser!.uid;
      await _firestore.collection('users').doc(id).update({
        'role': role,
        'assignedBy': currentUserUid,
      });
      final assignedToRef = _firestore.collection('users').doc(currentUserUid);
      await assignedToRef.set({
        'assignedTo': FieldValue.arrayUnion([id])
      }, SetOptions(merge: true));

      setState(() {
        _message = '${_getRoleTitle(role)} successfully assigned to $targetUsername!';
        _isLoading = false;
      });
      _idController.clear();
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
      case 'highSchoolUnitCoordinator':
        return 'High School Unit Coordinator';
      case 'user':
        return 'User';
      default:
        return 'User';
    }
  }

  @override
  Widget build(BuildContext context) {
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
                labelText: 'Enter Supervisor ID',
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
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 16),
              ),
            ),
            const SizedBox(height: 20),
            Center(
              child: ElevatedButton(
                onPressed: _isLoading
                    ? null
                    : () {
                        if (_idController.text.isNotEmpty &&
                            _selectedRole != null) {
                          assignRole(
                            _selectedRole!,
                            _idController.text.trim(),
                          );
                        } else {
                          setState(() {
                            _message =
                                'Please enter a User ID and select a role!';
                          });
                        }
                      },
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
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
                  color: _message.contains('successfully')
                      ? Colors.green
                      : Colors.red,
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
    super.dispose();
  }
} 