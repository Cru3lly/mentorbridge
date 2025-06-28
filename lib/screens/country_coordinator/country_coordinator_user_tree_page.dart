import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:glassmorphism/glassmorphism.dart';

class CountryCoordinatorUserTreePage extends StatefulWidget {
  const CountryCoordinatorUserTreePage({super.key});

  @override
  State<CountryCoordinatorUserTreePage> createState() => _CountryCoordinatorUserTreePageState();
}

class _CountryCoordinatorUserTreePageState extends State<CountryCoordinatorUserTreePage> {
  late final String currentUserId;
  bool _isLoading = true;
  List<Map<String, dynamic>> _regionCoordinators = [];

  // Current user info
  String? _currentUserName;
  String? _currentUserSurname;
  String? _currentUsername;

  @override
  void initState() {
    super.initState();
    currentUserId = FirebaseAuth.instance.currentUser!.uid;
    _fetchCurrentUser();
    _fetchRegionCoordinators();
  }

  Future<void> _fetchCurrentUser() async {
    final doc = await FirebaseFirestore.instance.collection('users').doc(currentUserId).get();
    final data = doc.data();
    setState(() {
      _currentUserName = data?['firstName'] as String?;
      _currentUserSurname = data?['lastName'] as String?;
      _currentUsername = data?['username'] as String?;
    });
  }

  Future<void> _fetchRegionCoordinators() async {
    setState(() => _isLoading = true);
    final regionRoles = [
      'middleSchoolRegionCoordinator',
      'highSchoolRegionCoordinator',
      'universityRegionCoordinator',
    ];
    final regionQuery = await FirebaseFirestore.instance
        .collection('users')
        .where('role', whereIn: regionRoles)
        .where('parentId', isEqualTo: currentUserId)
        .get();
    final regionCoordinators = regionQuery.docs.map((doc) => {
      'id': doc.id,
      ...doc.data(),
    }).toList();
    setState(() {
      _regionCoordinators = regionCoordinators;
      _isLoading = false;
    });
  }

  Future<List<Map<String, dynamic>>> _fetchUnitCoordinators(String regionId) async {
    final unitRoles = [
      'middleSchoolUnitCoordinator',
      'highSchoolUnitCoordinator',
      'universityUnitCoordinator',
    ];
    final unitQuery = await FirebaseFirestore.instance
        .collection('users')
        .where('role', whereIn: unitRoles)
        .where('parentId', isEqualTo: regionId)
        .get();
    return unitQuery.docs.map((doc) => {
      'id': doc.id,
      ...doc.data(),
    }).toList();
  }

  Future<List<Map<String, dynamic>>> _fetchMentors(String unitId) async {
    final mentorQuery = await FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'mentor')
        .where('parentId', isEqualTo: unitId)
        .get();
    return mentorQuery.docs.map((doc) => {
      'id': doc.id,
      ...doc.data(),
    }).toList();
  }

  Future<List<Map<String, dynamic>>> _fetchStudents(String mentorId) async {
    final studentQuery = await FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'student')
        .where('parentId', isEqualTo: mentorId)
        .get();
    return studentQuery.docs.map((doc) => {
      'id': doc.id,
      ...doc.data(),
    }).toList();
  }

  Future<List<Map<String, dynamic>>> _fetchMenteesForMentor(String mentorId) async {
    final mentorDoc = await FirebaseFirestore.instance.collection('users').doc(mentorId).get();
    final assignedTo = (mentorDoc.data()?['assignedTo'] as List?)?.cast<String>() ?? [];
    if (assignedTo.isEmpty) return [];
    final menteeDocs = await Future.wait(
      assignedTo.map((menteeId) => FirebaseFirestore.instance.collection('users').doc(menteeId).get())
    );
    return menteeDocs
        .where((doc) => doc.exists)
        .map((doc) => {'id': doc.id, ...doc.data()!})
        .toList();
  }

  Future<List<Map<String, dynamic>>> _fetchStudentsForUnitCoordinator(String unitId) async {
    final studentQuery = await FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'student')
        .where('parentId', isEqualTo: unitId)
        .get();
    return studentQuery.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
  }

  Future<List<Map<String, dynamic>>> _fetchNothing(String id) async => [];

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
      default:
        return role;
    }
  }

  Icon _getRoleIcon(String role) {
    switch (role) {
      case 'middleSchoolRegionCoordinator':
      case 'highSchoolRegionCoordinator':
      case 'universityRegionCoordinator':
        return const Icon(Icons.account_tree, color: Colors.blueAccent);
      case 'middleSchoolUnitCoordinator':
      case 'highSchoolUnitCoordinator':
      case 'universityUnitCoordinator':
        return const Icon(Icons.group, color: Colors.teal);
      case 'mentor':
        return const Icon(Icons.person, color: Colors.deepPurple);
      case 'student':
        return const Icon(Icons.school, color: Colors.orange);
      default:
        return const Icon(Icons.person_outline, color: Colors.grey);
    }
  }

  String _getFullName(Map<String, dynamic> user) {
    final first = (user['firstName'] ?? '').toString().trim();
    final last = (user['lastName'] ?? '').toString().trim();
    if (first.isNotEmpty && last.isNotEmpty) return '$first $last';
    if (first.isNotEmpty) return first;
    return user['id'] ?? '';
  }

  Color _getCountColor(String role) {
    switch (role) {
      case 'middleSchoolRegionCoordinator':
      case 'highSchoolRegionCoordinator':
      case 'universityRegionCoordinator':
        return Colors.blue;
      case 'middleSchoolUnitCoordinator':
      case 'highSchoolUnitCoordinator':
      case 'universityUnitCoordinator':
        return Colors.teal;
      case 'mentor':
        return Colors.deepPurple;
      default:
        return Colors.orange;
    }
  }

  Future<Widget> _buildUserTree({
    required Map<String, dynamic> user,
    required String role,
    int level = 0,
  }) async {
    final id = user['id'] ?? '';
    final name = _getFullName(user);
    int count = 0;
    if (role == 'middleSchoolRegionCoordinator' || role == 'highSchoolRegionCoordinator' || role == 'universityRegionCoordinator') {
      final unitRoles = [
        if (role == 'middleSchoolRegionCoordinator') 'middleSchoolUnitCoordinator',
        if (role == 'highSchoolRegionCoordinator') 'highSchoolUnitCoordinator',
        if (role == 'universityRegionCoordinator') 'universityUnitCoordinator',
      ];
      final query = await FirebaseFirestore.instance
          .collection('users')
          .where('role', whereIn: unitRoles)
          .where('parentId', isEqualTo: id)
          .get();
      count = query.docs.length;
    } else if (role == 'middleSchoolUnitCoordinator' || role == 'highSchoolUnitCoordinator' || role == 'universityUnitCoordinator') {
      if (role == 'universityUnitCoordinator') {
        final query = await FirebaseFirestore.instance
            .collection('users')
            .where('role', isEqualTo: 'student')
            .where('parentId', isEqualTo: id)
            .get();
        count = query.docs.length;
      } else {
        final query = await FirebaseFirestore.instance
            .collection('users')
            .where('role', isEqualTo: 'mentor')
            .where('parentId', isEqualTo: id)
            .get();
        count = query.docs.length;
      }
    } else if (role == 'mentor') {
      final doc = await FirebaseFirestore.instance.collection('users').doc(id).get();
      final assignedTo = (doc.data()?['assignedTo'] as List?)?.cast<String>() ?? [];
      count = assignedTo.length;
    }
    List<Map<String, dynamic>> children = [];
    Future<List<Map<String, dynamic>>> Function(String)? fetchChildren;
    if (role == 'countryCoordinator') {
      fetchChildren = (parentId) async {
        final regionRoles = [
          'middleSchoolRegionCoordinator',
          'highSchoolRegionCoordinator',
          'universityRegionCoordinator',
        ];
        final query = await FirebaseFirestore.instance
            .collection('users')
            .where('role', whereIn: regionRoles)
            .where('parentId', isEqualTo: parentId)
            .get();
        return query.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
      };
    } else if (role == 'middleSchoolRegionCoordinator' || role == 'highSchoolRegionCoordinator' || role == 'universityRegionCoordinator') {
      fetchChildren = (parentId) async {
        final unitRoles = [
          if (role == 'middleSchoolRegionCoordinator') 'middleSchoolUnitCoordinator',
          if (role == 'highSchoolRegionCoordinator') 'highSchoolUnitCoordinator',
          if (role == 'universityRegionCoordinator') 'universityUnitCoordinator',
        ];
        final query = await FirebaseFirestore.instance
            .collection('users')
            .where('role', whereIn: unitRoles)
            .where('parentId', isEqualTo: parentId)
            .get();
        return query.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
      };
    } else if (role == 'middleSchoolUnitCoordinator' || role == 'highSchoolUnitCoordinator') {
      fetchChildren = (parentId) async {
        final query = await FirebaseFirestore.instance
            .collection('users')
            .where('role', isEqualTo: 'mentor')
            .where('parentId', isEqualTo: parentId)
            .get();
        return query.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
      };
    } else if (role == 'mentor') {
      fetchChildren = _fetchMenteesForMentor;
    } else if (role == 'universityUnitCoordinator') {
      fetchChildren = _fetchStudentsForUnitCoordinator;
    } else if (role == 'student' || role == 'mentee') {
      fetchChildren = _fetchNothing;
    }
    if (fetchChildren != null) {
      children = await fetchChildren(id);
    }
    if (children.isEmpty) {
      return ListTile(
        key: ValueKey('leaf-$id'),
        leading: _getRoleIcon(role),
        title: count > 0
            ? Text.rich(
                TextSpan(
                  text: name,
                  style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                  children: [
                    TextSpan(
                      text: ' ($count)',
                      style: TextStyle(color: _getCountColor(role), fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              )
            : Text(name, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        subtitle: Text(_getRoleTitle(role)),
        dense: true,
      );
    }
    return _LazyExpansionTile(
      key: ValueKey('exp-$id'),
      title: count > 0
          ? Text.rich(
              TextSpan(
                text: name,
                style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                children: [
                  TextSpan(
                    text: ' ($count)',
                    style: TextStyle(color: _getCountColor(role), fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            )
          : Text(name, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
      subtitle: Text(_getRoleTitle(role)),
      leading: _getRoleIcon(role),
      fetchChildren: () async {
        return await Future.wait(children.map((child) => _buildUserTree(
          user: child,
          role: child['role'] ?? '',
          level: level + 1,
        )));
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
        title: const Text('Relationship Map'),
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
            padding: EdgeInsets.only(top: kToolbarHeight + 64,),
            child: GlassmorphicContainer(
              width: MediaQuery.of(context).size.width * 0.95 > 500 ? 500 : MediaQuery.of(context).size.width * 0.95,
              height: MediaQuery.of(context).size.height * 0.92,
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
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 18.0),
                child: Column(
                  children: [
                    // User card (You)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      child: GlassmorphicContainer(
                        width: double.infinity,
                        height: 90,
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
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                          child: Row(
                            children: [
                              const Icon(Icons.flag, color: Colors.indigo, size: 36),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          _currentUserName != null
                                            ? (_currentUserSurname != null
                                                ? '${_currentUserName!} ${_currentUserSurname!}'
                                                : _currentUserName!)
                                            : 'You',
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                        ),
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.indigo.shade50,
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: const Text(
                                            '(You)',
                                            style: TextStyle(fontSize: 13, color: Colors.indigo, fontWeight: FontWeight.w600),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Country Coordinator',
                                      style: const TextStyle(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.w500),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: _isLoading
                            ? const Center(child: CircularProgressIndicator())
                            : _regionCoordinators.isEmpty
                                ? const Center(child: Text('No users found'))
                                : FutureBuilder<List<Widget>>(
                                    future: () async {
                                      // Her region coordinator için ayrı bir tree dalı oluştur
                                      return await Future.wait(_regionCoordinators.map((region) => _buildUserTree(
                                        user: region,
                                        role: region['role'] ?? '',
                                      )));
                                    }(),
                                    builder: (context, snapshot) {
                                      if (!snapshot.hasData) {
                                        return const Center(child: CircularProgressIndicator());
                                      }
                                      return ListView(
                                        padding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                                        children: snapshot.data!,
                                      );
                                    },
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
}

// Lazy loading ExpansionTile
class _LazyExpansionTile extends StatefulWidget {
  final Widget title;
  final Widget? subtitle;
  final Widget? leading;
  final Future<List<Widget>> Function() fetchChildren;

  const _LazyExpansionTile({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    required this.fetchChildren,
  });

  @override
  State<_LazyExpansionTile> createState() => _LazyExpansionTileState();
}

class _LazyExpansionTileState extends State<_LazyExpansionTile> {
  bool _expanded = false;
  bool _loading = false;
  List<Widget>? _children;

  void _onExpand(bool expanded) async {
    if (expanded && _children == null) {
      setState(() => _loading = true);
      final children = await widget.fetchChildren();
      setState(() {
        _children = children;
        _loading = false;
      });
    }
    setState(() => _expanded = expanded);
  }

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      key: widget.key,
      title: widget.title,
      subtitle: widget.subtitle,
      leading: widget.leading,
      onExpansionChanged: _onExpand,
      initiallyExpanded: _expanded,
      children: _loading
          ? [const Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator())]
          : (_children ?? []),
    );
  }
} 