import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/services.dart';
import 'package:glassmorphism/glassmorphism.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'dart:ui';

class HighSchoolUnitCoordinatorIdAuthPage extends StatefulWidget {
  const HighSchoolUnitCoordinatorIdAuthPage({super.key});

  @override
  State<HighSchoolUnitCoordinatorIdAuthPage> createState() => _HighSchoolUnitCoordinatorIdAuthPageState();
}

class _HighSchoolUnitCoordinatorIdAuthPageState extends State<HighSchoolUnitCoordinatorIdAuthPage> {
  final TextEditingController _idController = TextEditingController();
  String? _selectedRole;
  bool _isLoading = false;
  String _message = '';
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? _currentUserRoleText;
  bool _isCheckingUserRole = false;
  String? _currentUserName;

  final List<String> _roles = [
    'mentor',
    'user',
  ];

  Future<void> assignRole(String role, String id) async {
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
      if (targetUserRole == 'admin' || targetUserRole == 'countryCoordinator' || (targetUserRole.contains('regionCoordinator')) || (targetUserRole.contains('unitCoordinator')) || (targetUserRole.contains('student'))) {
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

      final currentUserUid = FirebaseAuth.instance.currentUser!.uid;
      final updateData = {
        'role': role,
        'assignedBy': currentUserUid,
      };
      if (role == 'mentor') {
        updateData['parentId'] = currentUserUid;
        await _firestore.collection('users').doc(id).update(updateData);
      } else if (role == 'user') {
        await _firestore.collection('users').doc(id).update(updateData);
        await _firestore.collection('users').doc(id).update({'parentId': FieldValue.delete()});
      } else {
        await _firestore.collection('users').doc(id).update(updateData);
      }
      final assignedToRef = _firestore.collection('users').doc(currentUserUid);
      await assignedToRef.set({
        'assignedTo': FieldValue.arrayUnion([id])
      }, SetOptions(merge: true));

      setState(() {
        _message = '${_getRoleTitle(role)} successfully assigned to $targetFullName!';
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
      case 'mentor':
        return 'Mentor';
      case 'user':
        return 'User';
      default:
        return '-';
    }
  }

  String _getFullNameFromFields(String? first, String? last, {String? id}) {
    final f = (first ?? '').trim();
    final l = (last ?? '').trim();
    if (f.isNotEmpty && l.isNotEmpty) return '$f $l';
    if (f.isNotEmpty) return f;
    return id ?? '';
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
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Settings',
            onPressed: () {
              context.push('/settings');
            },
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
            padding: const EdgeInsets.only(top: kToolbarHeight - 8.0, bottom: 0.0),
            child: GlassmorphicContainer(
              width: MediaQuery.of(context).size.width * 0.95 > 500 ? 500 : MediaQuery.of(context).size.width * 0.95,
              height: MediaQuery.of(context).size.height * 0.78,
              constraints: BoxConstraints(minHeight: MediaQuery.of(context).size.height * 0.65),
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
                  padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 10.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      // User ID
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8.0, top: 2.0),
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
                      const SizedBox(height: 16),
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
                                  if (role == 'mentor') {
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
                                onChanged: (value) => setState(() => _selectedRole = value),
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
                      const SizedBox(height: 16),
                      // Summary Glass Card
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8.0, top: 2.0),
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
                                    Wrap(
                                      crossAxisAlignment: WrapCrossAlignment.center,
                                      spacing: 6,
                                      children: [
                                        const Icon(Icons.person, size: 18, color: Colors.grey),
                                        Text('User: ', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
                                        Text(
                                          (_idController.text.trim() == FirebaseAuth.instance.currentUser?.uid)
                                              ? (_currentUserName != null
                                                  ? (_getRoleTitle((FirebaseAuth.instance.currentUser)?.uid == _idController.text.trim() ? (FirebaseAuth.instance.currentUser)?.displayName ?? '-' : '-') == '-'
                                                      ? '$_currentUserName (You)'
                                                      : '$_currentUserName (You) (${_getRoleTitle((FirebaseAuth.instance.currentUser)?.uid == _idController.text.trim() ? (FirebaseAuth.instance.currentUser)?.displayName ?? '-' : '-')})')
                                                  : _idController.text.trim())
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
                                    Text.rich(
                                      TextSpan(
                                        children: [
                                          const WidgetSpan(
                                            child: Icon(Icons.assignment_ind, size: 18, color: Colors.grey),
                                          ),
                                          const WidgetSpan(child: SizedBox(width: 6)),
                                          const TextSpan(text: 'Role to assign: ', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
                                          TextSpan(
                                            text: _selectedRole != null ? _getRoleTitle(_selectedRole!) : '',
                                            style: const TextStyle(color: Colors.black87),
                                          ),
                                        ],
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (_message.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8.0, top: 2.0),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(18),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                              child: Container(
                                constraints: const BoxConstraints(minHeight: 48, maxHeight: 120),
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
                      const SizedBox(height: 16),
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
                      const SizedBox(height: 16),
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
    super.dispose();
  }
} 