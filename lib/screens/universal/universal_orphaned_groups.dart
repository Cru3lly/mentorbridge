import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:ui';
import 'package:go_router/go_router.dart';

// 🎯 Orphaned Groups Permissions System
class OrphanedGroupsPermissions {
  // 🔗 Hierarchical chain - who can see whose orphaned groups
  static const Map<String, List<String>> visibleOrphanedRoles = {
    'admin': ['*'], // Admin can see everything
    'moderator': ['*'], // Moderator can see everything
    'director': [
      'middleSchoolCoordinator', 'highSchoolCoordinator', 'universityCoordinator', 'housingCoordinator',
      'middleSchoolAssistantCoordinator', 'highSchoolAssistantCoordinator', 'universityAssistantCoordinator', 'housingAssistantCoordinator',
      'middleSchoolMentor', 'highSchoolMentor', 'houseLeader', 'studentHouseLeader'
    ],
    'middleSchoolCoordinator': ['middleSchoolAssistantCoordinator', 'middleSchoolMentor'],
    'highSchoolCoordinator': ['highSchoolAssistantCoordinator', 'highSchoolMentor'],
    'universityCoordinator': ['universityAssistantCoordinator', 'studentHouseLeader'],
    'housingCoordinator': ['housingAssistantCoordinator', 'houseLeader'],
    'middleSchoolAssistantCoordinator': ['middleSchoolMentor'],
    'highSchoolAssistantCoordinator': ['highSchoolMentor'],
    'universityAssistantCoordinator': ['studentHouseLeader'],
    'housingAssistantCoordinator': ['houseLeader'],
  };

  // 🎯 Check if viewer can see this orphaned group
  static bool canSeeOrphanedGroup(
    String viewerRole,
    String? viewerCity,
    String? viewerGender,
    String orphanedGroupCity,
    String orphanedGroupGender,
    String orphanedGroupLastManagerRole,
  ) {
    // Admin can see everything (all countries)
    if (viewerRole == 'admin') {
      return true;
    }

    // Moderator can see everything BUT only within their own country
    if (viewerRole == 'moderator') {
      // Moderator must have same country (city filtering for country-level)
      if (viewerCity != null && viewerCity != orphanedGroupCity) {
        return false; // Different country
      }
      return true; // Same country - can see all roles within country
    }

    // Check role hierarchy for other roles
    final visibleRoles = visibleOrphanedRoles[viewerRole] ?? [];
    if (!visibleRoles.contains(orphanedGroupLastManagerRole)) {
      return false;
    }

    // Location and gender filtering for coordinator-level roles
    if (viewerCity != null && viewerCity != orphanedGroupCity) {
      return false;
    }
    if (viewerGender != null && viewerGender != orphanedGroupGender) {
      return false;
    }

    return true;
  }

  // 🎯 Get viewer's location and gender from Firebase (to be implemented)
  static Future<Map<String, String?>> getViewerLocationAndGender(String userId) async {
    // TODO: Implement Firebase query to get user's city and gender
    // This will be used for filtering
    return {
      'city': null, // Will be fetched from user document
      'gender': null, // Will be fetched from user document
    };
  }
}

class UniversalOrphanedGroups extends StatefulWidget {
  final String? contextRole;
  
  const UniversalOrphanedGroups({
    super.key,
    this.contextRole,
  });

  @override
  State<UniversalOrphanedGroups> createState() => _UniversalOrphanedGroupsState();
}

class _UniversalOrphanedGroupsState extends State<UniversalOrphanedGroups> with WidgetsBindingObserver {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<Map<String, dynamic>> _orphanedUnits = [];
  bool _isLoading = true;
  String _message = '';
  String? _error;
  String _selectedFilter = 'all'; // all, critical, high, medium, low
  
  // 🎯 Authorized roles that can access this page
  final List<String> _authorizedRoles = [
    'admin', 'moderator', 'director',
    'middleSchoolCoordinator', 'highSchoolCoordinator', 'universityCoordinator', 'housingCoordinator',
    'middleSchoolAssistantCoordinator', 'highSchoolAssistantCoordinator', 'universityAssistantCoordinator', 'housingAssistantCoordinator'
  ];
  
  // 🚀 Cache for subordinate counts to avoid recalculation
  final Map<String, int> _subordinateCountCache = {};
  
  // 🎯 Management roles list (synchronized with universal_role_assignment_page.dart)
  final List<String> managementRoles = [
    'moderator', 'director', 'middleSchoolCoordinator', 'highSchoolCoordinator', 
    'universityCoordinator', 'housingCoordinator', 'middleSchoolAssistantCoordinator',
    'highSchoolAssistantCoordinator', 'universityAssistantCoordinator', 'housingAssistantCoordinator',
    'middleSchoolMentor', 'highSchoolMentor', 'houseLeader', 'studentHouseLeader',
    'houseMember', 'studentHouseMember'
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _fetchOrphanedUnits();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // Refresh when app becomes active (e.g., returning from another screen)
    if (state == AppLifecycleState.resumed) {
      _fetchOrphanedUnits();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // This will be called when returning from another route
    // Small delay to ensure the page is fully visible
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        _fetchOrphanedUnits();
      }
    });
  }

  Future<void> _fetchOrphanedUnits() async {
    setState(() {
      _isLoading = true;
      _message = 'Loading orphaned groups...';
    });

    try {
      // Query for orphaned organizational units
      // Note: Removed orderBy to avoid composite index requirement
      // We'll sort by priority and days orphaned in memory instead
      final orphanedQuery = await _firestore
          .collection('organizationalUnits')
          .where('status', whereIn: ['pendingReassignment'])
          .get();

      List<Map<String, dynamic>> units = [];
      final contextRole = widget.contextRole ?? 'user';

      // 🎯 Get viewer's location and gender for filtering
      // TODO: Implement actual user data fetching
      String? viewerCity;
      String? viewerGender;

      for (int i = 0; i < orphanedQuery.docs.length; i++) {
        final doc = orphanedQuery.docs[i];
        final data = doc.data();
        final unitData = Map<String, dynamic>.from(data);
        unitData['id'] = doc.id;

        // 🎯 Show progress to user
        setState(() {
          _message = 'Analyzing group ${i + 1} of ${orphanedQuery.docs.length}...';
        });

        // 🎯 Apply role-based filtering
        final lastManagerRole = unitData['lastManagerRole'] as String? ?? '';
        final unitCity = unitData['city'] as String? ?? '';
        final unitGender = unitData['gender'] as String? ?? '';

        // Check if viewer can see this orphaned group
        if (!OrphanedGroupsPermissions.canSeeOrphanedGroup(
          contextRole,
          viewerCity,
          viewerGender,
          unitCity,
          unitGender,
          lastManagerRole,
        )) {
          continue; // Skip this orphaned group
        }

        // Calculate priority and impact
        final priority = await _calculatePriority(unitData, doc.id);
        final impact = await _calculateImpact(unitData, doc.id);
        
        unitData['priority'] = priority;
        unitData['impact'] = impact;
        unitData['subordinateCount'] = impact['totalSubordinates'];
        unitData['daysOrphaned'] = _calculateDaysOrphaned(data);
        
        // 🎯 Pre-calculate actual subordinate count to avoid UI flickering
        // Use the same method as details dialog for consistency
        final actualUserIds = await _getAllRecursiveUsers(doc.id);
        final actualCount = actualUserIds.length;
        unitData['actualSubordinateCount'] = actualCount;
        
        // 🚀 Cache the result for future use
        _subordinateCountCache[doc.id] = actualCount;

        units.add(unitData);
      }

      // Sort by priority first, then by days orphaned (most urgent first)
      units.sort((a, b) {
        // Primary sort: Priority (Critical > High > Medium > Low)
        final priorityOrder = {'Critical': 4, 'High': 3, 'Medium': 2, 'Low': 1};
        final aPriority = priorityOrder[a['priority']] ?? 0;
        final bPriority = priorityOrder[b['priority']] ?? 0;
        
        if (aPriority != bPriority) {
          return bPriority.compareTo(aPriority);
        }
        
        // Secondary sort: Days orphaned (more days = higher priority)
        final aDaysOrphaned = a['daysOrphaned'] as int? ?? 0;
        final bDaysOrphaned = b['daysOrphaned'] as int? ?? 0;
        return bDaysOrphaned.compareTo(aDaysOrphaned);
      });

      setState(() {
        _orphanedUnits = units;
        _isLoading = false;
      });

    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = _getErrorMessage(e);
        _message = '';
      });
    }
  }

  String _getErrorMessage(dynamic error) {
    final errorString = error.toString().toLowerCase();
    
    if (errorString.contains('network') || errorString.contains('connection')) {
      return 'No internet connection. Please check your network and try again.';
    } else if (errorString.contains('permission') || errorString.contains('denied')) {
      return 'Permission denied. Please contact your administrator.';
    } else if (errorString.contains('timeout')) {
      return 'Request timed out. Please try again.';
    } else if (errorString.contains('firestore') || errorString.contains('firebase')) {
      return 'Server temporarily unavailable. Please try again in a moment.';
    } else {
      return 'Something went wrong. Please try again.';
    }
  }

  Future<String> _calculatePriority(Map<String, dynamic> unitData, String unitId) async {
    // 🎯 NEW: Calculate priority based on affected member count
    final affectedMemberCount = await _getRecursiveSubordinateCount(unitId);
    
    // Priority based on affected member count:
    // Critical: 15+ affected members
    if (affectedMemberCount >= 15) {
      return 'Critical';
    }
    
    // High: 10-14 affected members  
    if (affectedMemberCount >= 10) {
      return 'High';
    }
    
    // Medium: 5-9 affected members
    if (affectedMemberCount >= 5) {
      return 'Medium';
    }
    
    // Low: 0-4 affected members
    return 'Low';
  }

  Future<Map<String, dynamic>> _calculateImpact(Map<String, dynamic> unitData, String unitId) async {
    try {
      // 🎯 Use recursive counting for accurate results
      final totalSubordinates = await _getRecursiveSubordinateCount(unitId);
      
      // Count affected units (direct children only)
      final unitDocRef = _firestore.collection('organizationalUnits').doc(unitId);
      final childUnitsQuery = await _firestore
            .collection('organizationalUnits')
          .where('parentUnit', isEqualTo: unitDocRef)
            .get();

    return {
      'totalSubordinates': totalSubordinates,
        'directReports': 0, // Will be calculated in recursive method
        'indirectReports': 0, // Will be calculated in recursive method
        'affectedUnits': childUnitsQuery.docs.length,
      };
    } catch (e) {
      return {
        'totalSubordinates': 0,
        'directReports': 0,
        'indirectReports': 0,
        'affectedUnits': 0,
      };
    }
  }

  int _calculateDaysOrphaned(Map<String, dynamic> unitData) {
    try {
      // Use managerChangedAt as the primary timestamp
      final managerChangedAt = unitData['managerChangedAt'] as Timestamp?;
      
      if (managerChangedAt != null) {
        final now = DateTime.now();
        final changeDate = managerChangedAt.toDate();
        final daysDiff = now.difference(changeDate).inDays;
        return daysDiff > 0 ? daysDiff : 0; // Ensure non-negative
      }
      
      return 0; // No timestamp available
    } catch (e) {
      return 0;
    }
  }

  List<Map<String, dynamic>> get _filteredUnits {
    if (_selectedFilter == 'all') return _orphanedUnits;
    return _orphanedUnits.where((unit) => 
      (unit['priority'] as String).toLowerCase() == _selectedFilter.toLowerCase()
    ).toList();
  }





  String _getRequiredSupervisorType(Map<String, dynamic> unit) {
    // Get the last manager role
    final lastManagerRole = unit['lastManagerRole'] as String?;
    
    // If we have the last manager role, that's exactly what we need again
    if (lastManagerRole != null && lastManagerRole.isNotEmpty) {
      return _getRoleTitle(lastManagerRole);
    }
    
    // Fallback: If no lastManagerRole, return generic supervisor
    return 'Supervisor';
  }


  
  String _getRoleTitle(String role) {
    switch (role) {
      case 'admin': return 'Admin';
      case 'moderator': return 'Moderator';
      case 'director': return 'Director';
      case 'middleSchoolCoordinator': return 'Middle School Coordinator';
      case 'highSchoolCoordinator': return 'High School Coordinator';
      case 'universityCoordinator': return 'University Coordinator';
      case 'housingCoordinator': return 'Housing Coordinator';
      case 'middleSchoolAssistantCoordinator': return 'Middle School Assistant Coordinator';
      case 'highSchoolAssistantCoordinator': return 'High School Assistant Coordinator';
      case 'universityAssistantCoordinator': return 'University Assistant Coordinator';
      case 'housingAssistantCoordinator': return 'Housing Assistant Coordinator';
      case 'middleSchoolMentor': return 'Middle School Mentor';
      case 'highSchoolMentor': return 'High School Mentor';
      case 'houseLeader': return 'House Leader';
      case 'studentHouseLeader': return 'Student House Leader';
      case 'houseMember': return 'House Member';
      case 'studentHouseMember': return 'Student House Member';
      case 'mentee': return 'Mentee';
      case 'accountant': return 'Accountant';
      case 'user': return 'User';
      // Backward compatibility for lowercase versions
      case 'middleschoolmentor': return 'Middle School Mentor';
      case 'highschoolmentor': return 'High School Mentor';
      case 'houseleader': return 'House Leader';
      case 'student': return 'Student'; // Backward compatibility
      default: return 'User';
    }
  }

  // 🎯 Check if current user's role is authorized to access this page
  bool _isAuthorizedRole() {
    final contextRole = widget.contextRole;
    if (contextRole == null || contextRole.isEmpty) {
      return false; // No context role provided
    }
    return _authorizedRoles.contains(contextRole);
  }

  // 🚫 Build unauthorized access screen
  Widget _buildUnauthorizedAccess() {
    return Scaffold(
      body: Container(
        height: MediaQuery.of(context).size.height,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF8EC5FC), Color(0xFFE0C3FC)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Container(
              margin: const EdgeInsets.all(40),
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.red.withOpacity(0.3)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Error icon
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(40),
                    ),
                    child: Icon(
                      Icons.block,
                      color: Colors.red.shade300,
                      size: 40,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Access Denied',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'You don\'t have permission to access Fix Orphaned Groups.\n\nOnly Coordinators and above can manage orphaned organizational units.',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                      height: 1.4,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
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
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 🎯 Role authorization check
    if (!_isAuthorizedRole()) {
      return _buildUnauthorizedAccess();
    }
    
    return Scaffold(
      body: Container(
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
              vertical: 20,
            ),
            child: Column(
              children: [
                // Header - Responsive design
                Row(
                  children: [
                    IconButton(
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        context.pop();
                      },
                      icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 28),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      splashRadius: 24,
                    ),
                    SizedBox(width: MediaQuery.of(context).size.width > 600 ? 24 : 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Orphaned Groups',
                            style: TextStyle(
                              fontSize: MediaQuery.of(context).size.width > 600 ? 32 : 28,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              letterSpacing: -0.5,
                            ),
                          ),
                          if (MediaQuery.of(context).size.width > 400)
                            const Text(
                              'Manage units without supervisors',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.white70,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        HapticFeedback.mediumImpact();
                        _fetchOrphanedUnits();
                      },
                      icon: const Icon(Icons.refresh_rounded, color: Colors.white, size: 28),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      splashRadius: 24,
                    ),
                  ],
                ),

                // Filter buttons - sadece loading bittikten sonra göster
                if (!_isLoading) ...[
                  const SizedBox(height: 20),
                  // Icon-only filter buttons - Always horizontal
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withOpacity(0.2)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildIconFilterButton('all', '📋', 'All'),
                        _buildIconFilterButton('critical', '🔴', 'Critical'),
                        _buildIconFilterButton('high', '🟠', 'High'),
                        _buildIconFilterButton('medium', '🟡', 'Medium'),
                        _buildIconFilterButton('low', '🟢', 'Low'),
                      ],
                    ),
                  ),
                ],

                // Statistics bar
                if (!_isLoading && _orphanedUnits.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  // Responsive Statistics bar - Always horizontal
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: Colors.white.withOpacity(0.2)),
                    ),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final isVerySmallScreen = constraints.maxWidth < 320;
                        final isSmallScreen = constraints.maxWidth < 400;
                        
                        return Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            Expanded(
                              child: _buildStatItem(
                                isVerySmallScreen ? 'Total' : (isSmallScreen ? 'Total' : 'Total Orphaned'), 
                                '${_orphanedUnits.length}', 
                                Icons.group_work, 
                                isCompact: isSmallScreen,
                              ),
                            ),
                            Expanded(
                              child: _buildStatItem(
                                'Critical', 
                                '${_orphanedUnits.where((u) => u['priority'] == 'Critical').length}', 
                                Icons.error, 
                                isCompact: isSmallScreen,
                              ),
                            ),
                            Expanded(
                              child: _buildStatItem(
                                isVerySmallScreen ? 'Users' : (isSmallScreen ? 'Affected' : 'Affected Users'), 
                                '${_orphanedUnits.fold(0, (sum, unit) => sum + (unit['subordinateCount'] as int))}', 
                                Icons.people, 
                                isCompact: isSmallScreen,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ],

                const SizedBox(height: 20),

                // Content
                Expanded(
                  child: _buildContent(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }



  Widget _buildIconFilterButton(String filter, String emoji, String tooltip) {
    final isSelected = _selectedFilter == filter;
    final filterColor = _getFilterColor(filter);
    
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            setState(() => _selectedFilter = filter);
            HapticFeedback.selectionClick();
          },
          borderRadius: BorderRadius.circular(16),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: isSelected 
                  ? filterColor.withOpacity(0.3) 
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
              border: isSelected 
                  ? Border.all(color: filterColor.withOpacity(0.6), width: 2)
                  : Border.all(color: Colors.white.withOpacity(0.1)),
              boxShadow: isSelected ? [
                BoxShadow(
                  color: filterColor.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ] : null,
            ),
            child: Center(
              child: AnimatedScale(
                duration: const Duration(milliseconds: 150),
                scale: isSelected ? 1.1 : 1.0,
                child: Text(
                  emoji,
                  style: const TextStyle(fontSize: 20),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Color _getFilterColor(String filter) {
    switch (filter) {
      case 'critical':
        return Colors.red;
      case 'high':
        return Colors.orange;
      case 'medium':
        return Colors.yellow;
      case 'low':
        return Colors.green;
      default:
        return Colors.blue;
    }
  }

  Widget _buildStatItem(String label, String value, IconData icon, {bool isCompact = false}) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: isCompact ? 4 : 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon, 
            color: Colors.white, 
            size: isCompact ? 18 : 24,
          ),
          SizedBox(height: isCompact ? 2 : 4),
          Text(
            value,
            style: TextStyle(
              fontSize: isCompact ? 16 : 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: isCompact ? 9 : 12,
              color: Colors.white70,
              fontWeight: FontWeight.w400,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildAdminMenu(Map<String, dynamic> unit) {
    return PopupMenuButton<String>(
      icon: const Icon(
        Icons.more_vert,
        color: Colors.white70,
        size: 20,
      ),
      color: Colors.grey[900],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      offset: const Offset(-10, 30),
      onSelected: (value) {
        if (value == 'delete') {
          _showDeleteUnitDialog(unit);
        }
      },
      itemBuilder: (BuildContext context) => [
        PopupMenuItem<String>(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete_forever, color: Colors.red.shade400, size: 18),
              const SizedBox(width: 12),
              Text(
                'Delete Unit',
                style: TextStyle(
                  color: Colors.red.shade400,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showDeleteUnitDialog(Map<String, dynamic> unit) {
    final unitName = unit['name'] as String? ?? 'Unnamed Unit';
    final subordinateCount = unit['actualSubordinateCount'] as int? ?? 0;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: AlertDialog(
          backgroundColor: Colors.grey[900],
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Icon(Icons.warning, color: Colors.red.shade400, size: 28),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Delete Unit',
                  style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '⚠️ CRITICAL WARNING',
                style: TextStyle(
                  color: Colors.red.shade400,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'You are about to permanently delete:',
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      unitName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$subordinateCount affected users will lose their organizational structure',
                      style: TextStyle(color: Colors.red.shade300, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'This action CANNOT be undone and will:',
                style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              const Text(
                '• Remove all organizational relationships\n'
                '• Orphan all subordinate users\n'
                '• Delete historical data\n'
                '• Break reporting structures',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _showConfirmDeleteDialog(unit);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade600,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Continue', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _showConfirmDeleteDialog(Map<String, dynamic> unit) {
    final unitName = unit['name'] as String? ?? 'Unnamed Unit';
    final TextEditingController confirmController = TextEditingController();
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: AlertDialog(
          backgroundColor: Colors.grey[900],
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text(
            'Final Confirmation',
            style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Type "DELETE" to confirm permanent deletion of:',
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
              const SizedBox(height: 8),
              Text(
                unitName,
                style: TextStyle(
                  color: Colors.red.shade300,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: confirmController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Type DELETE here',
                  hintStyle: const TextStyle(color: Colors.white54),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.red.shade400),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.red.shade400, width: 2),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: confirmController,
              builder: (context, value, child) {
                final isValid = value.text.trim().toUpperCase() == 'DELETE';
                return ElevatedButton(
                  onPressed: isValid ? () {
                    Navigator.of(context).pop();
                    _deleteUnit(unit);
                  } : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isValid ? Colors.red.shade600 : Colors.grey.shade700,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text(
                    'DELETE FOREVER',
                    style: TextStyle(
                      color: isValid ? Colors.white : Colors.grey.shade500,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _deleteUnit(Map<String, dynamic> unit) async {
    // TODO: Implement actual unit deletion logic
    // This should:
    // 1. Remove unit from Firestore
    // 2. Update all subordinate users
    // 3. Log the action for audit
    // 4. Refresh the orphaned units list
    
    HapticFeedback.heavyImpact();
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Unit "${unit['name']}" deletion initiated...'),
        backgroundColor: Colors.red.shade600,
        action: SnackBarAction(
          label: 'Undo',
          textColor: Colors.white,
          onPressed: () {
            // TODO: Implement undo logic
          },
        ),
      ),
    );
    
    // Refresh the list
    _fetchOrphanedUnits();
  }

  Widget _buildLoadingState() {
    return Column(
      children: [
        // Skeleton for filter buttons
        const SizedBox(height: 20),
        _buildSkeletonFilterButtons(),
        
        const SizedBox(height: 20),
        
        // Skeleton for stats
        _buildSkeletonStats(),
        
        const SizedBox(height: 20),
        
        // Loading animation with message
        Expanded(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Modern loading indicator
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: const Center(
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 3,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  _message.isNotEmpty ? _message : 'Loading orphaned groups...',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Please wait while we analyze your organization',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSkeletonFilterButtons() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(5, (index) => 
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: _buildShimmerEffect(),
          ),
        ),
      ),
    );
  }

  Widget _buildSkeletonStats() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: List.generate(3, (index) => 
          Column(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: _buildShimmerEffect(),
              ),
              const SizedBox(height: 4),
              Container(
                width: 30,
                height: 18,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: _buildShimmerEffect(),
              ),
              const SizedBox(height: 2),
              Container(
                width: 50,
                height: 12,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: _buildShimmerEffect(),
              ),
            ],
          ),
        ),
      ),
    );
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

  Widget _buildEmptyState() {
    final isAllFilter = _selectedFilter == 'all';
    
    return Center(
      child: Container(
        margin: const EdgeInsets.all(20),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.2)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Animated icon
            TweenAnimationBuilder<double>(
              duration: const Duration(milliseconds: 800),
              tween: Tween(begin: 0.8, end: 1.0),
              builder: (context, value, child) {
                return Transform.scale(
                  scale: value,
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: isAllFilter ? Colors.green.withOpacity(0.2) : Colors.blue.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(40),
                    ),
                    child: Icon(
                      isAllFilter ? Icons.check_circle : Icons.filter_list_off,
                      color: isAllFilter ? Colors.green.shade200 : Colors.blue.shade200,
                      size: 40,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 24),
            Text(
              isAllFilter 
                  ? '🎉 Excellent!'
                  : 'No Results',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              isAllFilter 
                  ? 'No orphaned groups found!\nAll organizational units have active supervisors.'
                  : 'No $_selectedFilter priority orphaned groups found.\nTry selecting a different filter.',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 16,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            if (!isAllFilter) ...[
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  setState(() => _selectedFilter = 'all');
                  HapticFeedback.lightImpact();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white.withOpacity(0.2),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                child: const Text('Show All Groups'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(20),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.red.withOpacity(0.3)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Animated error icon
            TweenAnimationBuilder<double>(
              duration: const Duration(milliseconds: 800),
              tween: Tween(begin: 0.8, end: 1.0),
              builder: (context, value, child) {
                return Transform.scale(
                  scale: value,
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(40),
                    ),
                    child: Icon(
                      Icons.wifi_off_rounded,
                      color: Colors.red.shade300,
                      size: 40,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 24),
            const Text(
              'Connection Error',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              _error!,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 16,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                OutlinedButton(
                  onPressed: () {
                    setState(() => _error = null);
                    HapticFeedback.lightImpact();
                  },
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.white54),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                  child: const Text(
                    'Dismiss',
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: () {
                    setState(() => _error = null);
                    _fetchOrphanedUnits();
                    HapticFeedback.mediumImpact();
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
                      Icon(Icons.refresh, size: 18),
                      SizedBox(width: 6),
                      Text('Try Again'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return _buildLoadingState();
    }

    if (_error != null) {
      return _buildErrorState();
    }

    final filteredUnits = _filteredUnits;

    if (filteredUnits.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.builder(
      itemCount: filteredUnits.length,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 20),
      itemBuilder: (context, index) {
        final unit = filteredUnits[index];
        return AnimatedContainer(
          duration: Duration(milliseconds: 200 + (index * 50)),
          curve: Curves.easeOutBack,
          child: _buildOrphanedUnitCard(unit, index),
        );
      },
    );
  }

  Widget _buildOrphanedUnitCard(Map<String, dynamic> unit, int index) {
    final String priority = (unit['priority'] as String?)?.trim() ?? 'Low';
    final Color priorityColor = _getPriorityColor(priority);
    final int daysOrphaned = (unit['daysOrphaned'] as int?) ?? 0;
    final String unitName = (unit['name'] as String?)?.trim() ?? 'Unnamed Unit';
    final String requiredSupervisor = _getRequiredSupervisorType(unit);
    final int subordinateCount = (unit['actualSubordinateCount'] as int?) ?? 0;

    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 300 + (index * 100)),
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, animationValue, child) {
        return Transform.translate(
          offset: Offset(0, 50 * (1 - animationValue)),
          child: Opacity(
            opacity: animationValue,
            child: Container(
              margin: const EdgeInsets.only(bottom: 16.0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16.0),
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.white.withOpacity(0.15),
                          Colors.white.withOpacity(0.08),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16.0),
                      border: Border.all(
                        color: priorityColor.withOpacity(0.3),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: priorityColor.withOpacity(0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          _showRecoveryDialog(unit);
                        },
                        borderRadius: BorderRadius.circular(16.0),
            child: Row(
              children: [
                // Priority Indicator Bar
                Container(
                  width: 6,
                  // The height will be determined by the card content
                  color: priorityColor,
                ),
                // Main Content
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Unit Name, Priority Tag & Admin Menu
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                unitName,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Priority tag
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: priorityColor.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: priorityColor.withOpacity(0.4)),
                              ),
                              child: Text(
                                priority.toUpperCase(),
                                style: TextStyle(
                                  color: priorityColor,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Admin-only 3-dots menu
                            _buildAdminMenu(unit),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // Required Role
                        Row(
                          children: [
                            Icon(Icons.support_agent_rounded, color: Colors.white70, size: 16),
                            const SizedBox(width: 8),
                            const Text(
                              'Requires: ',
                              style: TextStyle(color: Colors.white70, fontSize: 14),
                            ),
                            Expanded(
                              child: Text(
                                requiredSupervisor,
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
                        const SizedBox(height: 16),
                        // Bottom row with stats and actions
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Stats
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _buildStatIcon(Icons.people_alt_outlined, '$subordinateCount', Colors.white70),
                                const SizedBox(width: 16),
                                _buildStatIcon(Icons.update_rounded, '$daysOrphaned day${daysOrphaned == 1 ? "" : "s"}', Colors.white70),
                              ],
                            ),
                            // Actions
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                TextButton(
                                  onPressed: () => _showAffectedMembersDialog(unit),
                                  style: TextButton.styleFrom(
                                    foregroundColor: Colors.white70,
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  ),
                                  child: const Text('Details'),
                                ),
                                const SizedBox(width: 8),
                                ElevatedButton(
                                  onPressed: () => _showRecoveryDialog(unit),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: priorityColor,
                                    foregroundColor: priorityColor.computeLuminance() > 0.5 ? Colors.black : Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    elevation: 2,
                                  ),
                                  child: const Text('Assign'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
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
            ),
          ),
        );
      },
    );
  }

  // Helper widget for stats, also redesigned
  Widget _buildStatIcon(IconData icon, String text, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 6),
        Text(
          text,
          style: TextStyle(
            fontSize: 14,
            color: color,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }



  // 🎯 NEW: Recursive method to count all subordinates in the hierarchy
  Future<int> _getRecursiveSubordinateCount(String unitId, [Set<String>? visitedUnits]) async {
    visitedUnits ??= <String>{};
    
    // Prevent infinite loops
    if (visitedUnits.contains(unitId)) {
      return 0;
    }
    visitedUnits.add(unitId);
    
    Set<String> allAffectedUsers = {};
    
    // Step 1: Find all child units of this unit
    final unitDocRef = FirebaseFirestore.instance.collection('organizationalUnits').doc(unitId);
    final childUnitsQuery = await FirebaseFirestore.instance
        .collection('organizationalUnits')
        .where('parentUnit', isEqualTo: unitDocRef)
        .get();
    
    // Step 2: For each child unit, get its users and recursively count its children
    for (final childUnitDoc in childUnitsQuery.docs) {
      final childUnitId = childUnitDoc.id;
      
      // Get users directly managed by this child unit
      final childUsers = await _getUsersForUnit(childUnitId);
      allAffectedUsers.addAll(childUsers);
      
      // Recursively count subordinates of this child unit
      await _getRecursiveSubordinateCount(childUnitId, visitedUnits);
    }
    
    // Step 3: Also check if any users are directly managed by this unit (rare but possible)
    final directUsers = await _getUsersForUnit(unitId);
    allAffectedUsers.addAll(directUsers);
    
    return allAffectedUsers.length;
  }

  // 🎯 Helper: Get all users managed by a specific unit (OPTIMIZED + FILTERED)
  Future<Set<String>> _getUsersForUnit(String unitId) async {
    Set<String> userIds = {};
    
    // 🎯 Get unit data to find lastManagerId (excluded from affected users)
    String? lastManagerId;
    try {
      final unitDoc = await FirebaseFirestore.instance
          .collection('organizationalUnits')
          .doc(unitId)
          .get();
      if (unitDoc.exists) {
        final unitData = unitDoc.data() ?? {};
        lastManagerId = unitData['lastManagerId'] as String?;
      }
    } catch (e) {
      // Ignore error, continue without filtering
    }


    
    // 🚀 NEW APPROACH: Query all users and check their roles array (since managesEntity is now in roles array)
    try {
      final allUsersQuery = await FirebaseFirestore.instance
          .collection('users')
          .get();
      
      final possiblePaths = [
        'organizationalUnits/$unitId',
        unitId,
      ];
      
      for (final userDoc in allUsersQuery.docs) {
        final userData = userDoc.data();
        final roles = userData['roles'] as List<dynamic>? ?? [];
        
        // Check each role in the roles array
        for (final role in roles) {
          if (role is Map) {
            final managesEntity = role['managesEntity'] as String?;
            final roleType = role['role'] as String?;
            
            // Check if this role manages our unit
            if (managesEntity != null && possiblePaths.contains(managesEntity)) {
              // Check if this is a subordinate role
              final subordinateRoles = [
                'director', 'middleSchoolCoordinator', 'highSchoolCoordinator', 'universityCoordinator', 'housingCoordinator',
                'middleSchoolAssistantCoordinator', 'highSchoolAssistantCoordinator',
                'universityAssistantCoordinator', 'housingAssistantCoordinator',
                'middleSchoolMentor', 'highSchoolMentor', 'houseLeader', 'studentHouseLeader',
                'houseMember', 'studentHouseMember', 'mentee'
              ];
              
              if (roleType != null && subordinateRoles.contains(roleType)) {
                // Add user if they are subordinates and not the removed manager
                if (userDoc.id != lastManagerId) {
                  userIds.add(userDoc.id);
                }
              }
              break; // Found a matching role, no need to check others
            }
          }
        }
      }
    } catch (e) {
      // Ignore error, fallback to old method
    }
    
    // 🚀 FALLBACK: Use targeted queries instead of scanning all users (if new approach didn't find anyone)
    if (userIds.isEmpty) {
      final possiblePaths = [
        'organizationalUnits/$unitId',
        unitId,
      ];
      
      // Query 1: managesEntity field (most common)
    for (final path in possiblePaths) {
      try {
        final query = await FirebaseFirestore.instance
            .collection('users')
            .where('managesEntity', isEqualTo: path)
            .get();
        
        for (final doc in query.docs) {
          final userData = doc.data();
          final roles = userData['roles'] as List<dynamic>? ?? [];
          
          // 🎯 FILTER: Only include users who are SUBORDINATES, not the removed supervisor
          // Skip anyone who only has basic roles (user, student) - they're likely the removed supervisor
          final subordinateRoles = [
            'moderator',
            'director',
            'middleSchoolCoordinator', 'highSchoolCoordinator', 'universityCoordinator', 'housingCoordinator',
            'middleSchoolAssistantCoordinator', 'highSchoolAssistantCoordinator', 
            'universityAssistantCoordinator', 'housingAssistantCoordinator',
            'middleSchoolMentor', 'highSchoolMentor', 'houseLeader', 'studentHouseLeader',
            'houseMember', 'studentHouseMember', 'mentee'
          ];
          
          bool isActualSubordinate = false;
          for (final role in roles) {
            if (role is String && subordinateRoles.contains(role)) {
              isActualSubordinate = true;
              break;
            } else if (role is Map && role['role'] is String && 
                       subordinateRoles.contains(role['role'].toString())) {
              isActualSubordinate = true;
              break;
            }
          }
          
          // Only add if they are actual subordinates (mentors, house leaders)
          // AND not the removed manager
          if (isActualSubordinate && doc.id != lastManagerId) {
            userIds.add(doc.id);
          }
        }
      } catch (e) {
        // Ignore query errors
      }
    }
    
    // Query 2: managedEntity field (alternative/backward compatibility)
    for (final path in possiblePaths) {
      try {
        final query = await FirebaseFirestore.instance
            .collection('users')
            .where('managedEntity', isEqualTo: path)
            .get();
        
        for (final doc in query.docs) {
          final userData = doc.data();
          final roles = userData['roles'] as List<dynamic>? ?? [];
          
          // Same filtering logic as above - only subordinates
          final subordinateRoles = [
            
            'director',
            'middleSchoolCoordinator', 'highSchoolCoordinator', 'universityCoordinator', 'housingCoordinator',
            'middleSchoolAssistantCoordinator', 'highSchoolAssistantCoordinator', 
            'universityAssistantCoordinator', 'housingAssistantCoordinator',
            'middleSchoolMentor', 'highSchoolMentor', 'houseLeader', 'studentHouseLeader',
            'houseMember', 'studentHouseMember', 'mentee'
          ];
          
          bool isActualSubordinate = false;
          for (final role in roles) {
            if (role is String && subordinateRoles.contains(role)) {
              isActualSubordinate = true;
              break;
            } else if (role is Map && role['role'] is String && 
                       subordinateRoles.contains(role['role'].toString())) {
              isActualSubordinate = true;
              break;
            }
          }
          
          if (isActualSubordinate && doc.id != lastManagerId) {
            userIds.add(doc.id);
          }
        }
      } catch (e) {
        // Ignore query errors
      }
    }
    } // End of fallback if block
    
    return userIds;
  }


  // 🎯 Show detailed information about affected members in the orphaned group
  void _showAffectedMembersDialog(Map<String, dynamic> unit) async {
    final unitId = unit['id'] as String? ?? '';
    
    showDialog(
      context: context,
      barrierDismissible: false,
            builder: (context) => Container(
        margin: const EdgeInsets.all(40),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Material(
            color: Colors.transparent,
            child: Container(
                            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withOpacity(0.25),
                    Colors.white.withOpacity(0.15),
                  ],
                ),
                border: Border.all(
                  color: Colors.white.withOpacity(0.3),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
            ),
          ],
        ),
            child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                    color: Colors.white.withOpacity(0.05),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.group, color: Colors.blue, size: 28),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Affected Members',
                          style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close, color: Colors.white70),
            ),
          ],
        ),
                ),
                
                // Content
                Expanded(
                  child: Container(
                    width: double.maxFinite,
                    padding: const EdgeInsets.all(20),
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: _getAffectedMembersDetails(unitId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(color: Colors.blue),
                      SizedBox(height: 16),
                      Text('Loading affected members...', style: TextStyle(color: Colors.white70)),
        ],
      ),
    );
  }

              final members = snapshot.data ?? [];
              if (members.isEmpty) {
                return const Center(
                  child: Text('No affected members found', style: TextStyle(color: Colors.white70)),
                );
              }
              
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Members list (removed unit info header)
                  Expanded(
                    child: ListView.builder(
                      itemCount: members.length,
                      itemBuilder: (context, index) {
                        final member = members[index];
                        final name = member['name'] as String? ?? 'Unknown User';
                        final roles = (member['roles'] as List<dynamic>? ?? []).cast<String>();

                        
                        // Get the highest priority role for display
                        String displayRole = '';
                        if (roles.isNotEmpty) {
                          final roleOrder = [
                            'admin', 'moderator', 'director', 
                            'middleSchoolCoordinator', 'highSchoolCoordinator', 'universityCoordinator', 'housingCoordinator',
                            'middleSchoolAssistantCoordinator', 'highSchoolAssistantCoordinator', 'universityAssistantCoordinator', 'housingAssistantCoordinator',
                            'middleSchoolMentor', 'highSchoolMentor', 'houseLeader', 'accountant', 'student', 'user'
                          ];
                          
                          int highestIndex = 999;
                          for (final role in roles) {
                            final index = roleOrder.indexOf(role.toString());
                            if (index != -1 && index < highestIndex) {
                              highestIndex = index;
                              displayRole = role;
                            }
                          }
                        }
                        
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white.withOpacity(0.15)),
        ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                              // Name (always show, even if Unknown)
                  Text(
                                name,
                    style: const TextStyle(
                                  color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              
                              const SizedBox(height: 8),
                              
                              // Role (removed email, full role name without ellipsis)
                              if (displayRole.isNotEmpty) ...[
                                Row(
                                  children: [
                                    Icon(Icons.badge, color: Colors.purple.shade300, size: 16),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        _getRoleTitle(displayRole),
                                        style: TextStyle(
                                          color: Colors.purple.shade300,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                        ),
                                        softWrap: true,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                              ],
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
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
    ));
  }

  // 🎯 Get affected members details - FIXED to use recursive search
  Future<List<Map<String, dynamic>>> _getAffectedMembersDetails(String unitId) async {
    try {
      // Use the same recursive logic as count calculation
      final allUserIds = await _getAllRecursiveUsers(unitId);
      
      final List<Map<String, dynamic>> members = [];
      
      // Fetch user details in batches to avoid too many simultaneous requests
      const batchSize = 10;
      for (int i = 0; i < allUserIds.length; i += batchSize) {
        final batch = allUserIds.skip(i).take(batchSize);
        final futures = batch.map((userId) => _getUserDetails(userId));
        final batchResults = await Future.wait(futures);
        members.addAll(batchResults.where((member) => member.isNotEmpty));
      }
      
      // Sort by role hierarchy (most senior first) - FIXED
      members.sort((a, b) {
        final aRoles = a['roles'] as List<dynamic>? ?? [];
        final bRoles = b['roles'] as List<dynamic>? ?? [];
        
        if (aRoles.isEmpty && bRoles.isEmpty) return 0;
        if (aRoles.isEmpty) return 1;
        if (bRoles.isEmpty) return -1;
        
        // Use the same hierarchy as admin_id_auth_page
        final roleOrder = [
          'admin', 'moderator', 'director', 
          'middleSchoolCoordinator', 'highSchoolCoordinator', 'universityCoordinator', 'housingCoordinator',
          'middleSchoolAssistantCoordinator', 'highSchoolAssistantCoordinator', 'universityAssistantCoordinator', 'housingAssistantCoordinator',
          'middleSchoolMentor', 'highSchoolMentor', 'houseLeader', 'accountant', 'student', 'user'
        ];
        
        // Get the highest role for each user
        int getHighestRoleIndex(List<dynamic> roles) {
          int highestIndex = 999;
          for (final role in roles) {
            final index = roleOrder.indexOf(role.toString());
            if (index != -1 && index < highestIndex) {
              highestIndex = index;
            }
          }
          return highestIndex == 999 ? roleOrder.length : highestIndex;
        }
        
        final aIndex = getHighestRoleIndex(aRoles);
        final bIndex = getHighestRoleIndex(bRoles);
        
        return aIndex.compareTo(bIndex);
      });
      
      return members;
    } catch (e) {
      rethrow;
    }
  }

  // 🎯 Get all users recursively (same logic as count but returns user IDs)
  Future<Set<String>> _getAllRecursiveUsers(String unitId, [Set<String>? visitedUnits]) async {
    visitedUnits ??= <String>{};
    
    // Prevent infinite loops
    if (visitedUnits.contains(unitId)) {
      return <String>{};
    }
    visitedUnits.add(unitId);
    
    Set<String> allUsers = {};
    
    // Step 1: Find all child units of this unit
    final unitDocRef = FirebaseFirestore.instance.collection('organizationalUnits').doc(unitId);
    final childUnitsQuery = await FirebaseFirestore.instance
          .collection('organizationalUnits')
        .where('parentUnit', isEqualTo: unitDocRef)
          .get();

    // Step 2: For each child unit, get its users and recursively get children's users
    for (final childUnitDoc in childUnitsQuery.docs) {
      final childUnitId = childUnitDoc.id;
      
      // Get users directly managed by this child unit
      final childUsers = await _getUsersForUnit(childUnitId);
      allUsers.addAll(childUsers);
      
      // Recursively get users from child's children
      final recursiveUsers = await _getAllRecursiveUsers(childUnitId, visitedUnits);
      allUsers.addAll(recursiveUsers);
    }
    
    // Step 3: Also get users directly managed by this unit
    final directUsers = await _getUsersForUnit(unitId);
    allUsers.addAll(directUsers);
    
    return allUsers;
  }

  // 🎯 Get detailed user information - FIXED name field
  Future<Map<String, dynamic>> _getUserDetails(String userId) async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      
      if (!userDoc.exists) return {};
      
      final userData = userDoc.data() ?? {};
      
      // Try multiple name field combinations
      String finalName = 'Unknown User';
      
      // Option 1: firstName + lastName
      final firstName = userData['firstName'] as String? ?? '';
      final lastName = userData['lastName'] as String? ?? '';
      if (firstName.isNotEmpty || lastName.isNotEmpty) {
        finalName = '$firstName $lastName'.trim();
      }
      
      // Option 2: name field
      else if (userData['name'] != null && userData['name'].toString().isNotEmpty) {
        finalName = userData['name'].toString();
      }
      
      // Option 3: displayName field
      else if (userData['displayName'] != null && userData['displayName'].toString().isNotEmpty) {
        finalName = userData['displayName'].toString();
      }
      
      // Option 4: email username as fallback
      else if (userData['email'] != null && userData['email'].toString().isNotEmpty) {
        final email = userData['email'].toString();
        finalName = email.split('@').first.replaceAll('.', ' ').replaceAll('_', ' '); // Clean email username
      }
      
      // Debug and parse roles properly
      final rawRoles = userData['roles'];
      List<String> parsedRoles = [];
      
      if (rawRoles != null) {
        if (rawRoles is List) {
          // If it's already a list
          for (final role in rawRoles) {
            if (role is String) {
              parsedRoles.add(role);
            } else if (role is Map) {
              // If roles are stored as objects with role field
              final roleStr = role['role'] as String?;
              if (roleStr != null) parsedRoles.add(roleStr);
            }
          }
        } else if (rawRoles is Map) {
          // If roles is a map, extract role values
          for (final value in rawRoles.values) {
            if (value is String) {
              parsedRoles.add(value);
            } else if (value is Map && value['role'] is String) {
              parsedRoles.add(value['role']);
            }
          }
        } else if (rawRoles is String) {
          // If it's a single string
          parsedRoles.add(rawRoles);
        }
      }
      
      // 🎯 Get managesEntity from roles array (like admin_id_auth_page.dart)
      String? managesEntityForUser;
      final userRoles = userData['roles'] as List<dynamic>?;
      if (userRoles != null) {
        // Find first management role with managesEntity
        final managementRole = userRoles.firstWhere(
          (r) => r is Map && 
                 r['managesEntity'] != null &&
                 managementRoles.contains(r['role']?.toString()),
          orElse: () => null,
        );
        if (managementRole != null && managementRole is Map) {
          managesEntityForUser = managementRole['managesEntity'] as String?;
        }
      }
      // Fallback to top-level managesEntity for backward compatibility
      managesEntityForUser ??= userData['managesEntity'] as String?;
      // Also check managedEntity for backward compatibility
      managesEntityForUser ??= userData['managedEntity'] as String?;
      
      return {
        'id': userId,
        'name': finalName,
        'email': userData['email'] ?? '',
        'roles': parsedRoles,
        'managesEntity': managesEntityForUser ?? '',
      };
    } catch (e) {
      return {};
    }
  }





  void _showRecoveryDialog(Map<String, dynamic> unit) {
    final unitName = unit['name'] as String? ?? 'Unnamed Unit';
    final daysOrphaned = unit['daysOrphaned'] as int;
    final requiredSupervisor = _getRequiredSupervisorType(unit);


    showDialog(
      context: context,
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            constraints: const BoxConstraints(maxHeight: 350),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.grey[900]!.withOpacity(0.9),
                  Colors.grey[800]!.withOpacity(0.85),
                ],
              ),
              border: Border.all(
                color: Colors.white.withOpacity(0.3),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.5),
                  blurRadius: 25,
                  offset: const Offset(0, 15),
                ),
              ],
            ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                  color: Colors.white.withOpacity(0.1),
                ),
                child: Row(
                  children: [
                    Icon(Icons.person_add_rounded, color: Colors.green, size: 24),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Assign Supervisor',
                        style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close, color: Colors.white70),
                    ),
                  ],
                ),
              ),
              
              // Content
              Flexible(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue.withOpacity(0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          unitName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(Icons.assignment_ind, color: Colors.green, size: 18),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                'Required: $requiredSupervisor',
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.green,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${unit['actualSubordinateCount'] ?? 0} affected users • $daysOrphaned days',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Footer buttons
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(20),
                    bottomRight: Radius.circular(20),
                  ),
                  color: Colors.white.withOpacity(0.1),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: Colors.white.withOpacity(0.3)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(color: Colors.white70, fontSize: 16),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                                              child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context);
                            context.push('/universalRoleAssignmentPage');
                          },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 3,
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.arrow_forward, color: Colors.white, size: 18),
                            SizedBox(width: 6),
                            Text(
                              'Continue',
                              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ],
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
    ));
  }

  Color _getPriorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'critical':
        return Colors.red;
      case 'high':
        return Colors.orange;
      case 'medium':
        return Colors.yellow;
      case 'low':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }
}
