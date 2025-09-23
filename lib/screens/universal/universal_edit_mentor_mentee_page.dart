import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:ui';

class UniversalEditMentorMenteePage extends StatefulWidget {
  const UniversalEditMentorMenteePage({super.key});

  @override
  State<UniversalEditMentorMenteePage> createState() => _UniversalEditMentorMenteePageState();
}

class _UniversalEditMentorMenteePageState extends State<UniversalEditMentorMenteePage> {
  // 🔐 Authorization
  bool _isLoading = true;
  bool _isAuthorized = false;
  String? _currentRole;
  
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
    _checkAuthorization();
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
          _isLoading = false;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text(
          'Mentor & Mentee Management',
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
          child: _buildContent(),
        ),
      ),
    );
  }

  // 🎨 Build content based on authorization state
  Widget _buildContent() {
    if (_isLoading) {
      return _buildLoadingState();
    }
    
    if (!_isAuthorized) {
      return _buildUnauthorizedState();
    }
    
    return _buildAuthorizedContent();
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
            'Checking permissions...',
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
              'You don\'t have permission to access Mentor/Mentee Management.\n\nOnly coordinators and administrators can access this feature.',
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

  // ✅ Authorized content
  Widget _buildAuthorizedContent() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildActionCard(
            icon: Icons.school_rounded,
            title: 'Mentors',
            description: 'View, assign and manage mentor assignments',
            color: Colors.blue,
            onTap: _navigateToMentors,
          ),
          
          const SizedBox(height: 24),
          
          _buildActionCard(
            icon: Icons.person_add_rounded,
            title: 'Mentees',
            description: 'Add, edit and manage virtual mentees',
            color: Colors.purple,
            onTap: _navigateToMentees,
          ),
        ],
      ),
    );
  }



  // 🎨 Build modern action card
  Widget _buildActionCard({
    required IconData icon,
    required String title,
    required String description,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Container(
      width: double.infinity,
      height: 120,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () {
                  HapticFeedback.lightImpact();
                  onTap();
                },
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(
                          icon,
                          color: color,
                          size: 32,
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              description,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.8),
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.arrow_forward_ios,
                        color: Colors.white.withOpacity(0.6),
                        size: 20,
                      ),
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

  // 🎯 Navigate to mentors page
  void _navigateToMentors() {
    context.push('/universalMentors');
  }

  // 🎯 Navigate to mentees page
  void _navigateToMentees() {
    context.push('/universalMentees');
  }
} 