import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../role_dashboard_wrapper.dart';
import 'universal_role_assignment_page.dart';
import 'universal_user_tree_page.dart';
import '../../theme/app_theme.dart';
import '../../widgets/clean_card.dart';

class UniversalRoleDashboard extends StatefulWidget {
  final String currentRole;
  final List<String> allUserRoles;

  const UniversalRoleDashboard({
    super.key,
    required this.currentRole,
    required this.allUserRoles,
  });

  @override
  State<UniversalRoleDashboard> createState() => _UniversalRoleDashboardState();
}

class _UniversalRoleDashboardState extends State<UniversalRoleDashboard> {
  @override
  Widget build(BuildContext context) {
    return RoleDashboardWrapper(
      roleTitle: _getRoleTitle(widget.currentRole),
      topWidget: _buildTopWidget(widget.currentRole),
      menuItems: _getMenuItems(widget.currentRole),
      onTopWidgetTap: null,
    );
  }

  // 🎯 Get role-specific title
  String _getRoleTitle(String role) {
    switch (role) {
      case 'admin':
        return 'Admin Dashboard';
      case 'moderator':
        return 'Moderator Dashboard';
      case 'director':
        return 'Director Dashboard';
      case 'middleSchoolCoordinator':
        return 'Middle School Coordinator Dashboard';
      case 'highSchoolCoordinator':
        return 'High School Coordinator Dashboard';
      case 'universityCoordinator':
        return 'University Coordinator Dashboard';
      case 'housingCoordinator':
        return 'Housing Coordinator Dashboard';
      case 'middleSchoolAssistantCoordinator':
        return 'Middle School Assistant Coordinator Dashboard';
      case 'highSchoolAssistantCoordinator':
        return 'High School Assistant Coordinator Dashboard';
      case 'universityAssistantCoordinator':
        return 'University Assistant Coordinator Dashboard';
      case 'housingAssistantCoordinator':
        return 'Housing Assistant Coordinator Dashboard';
      case 'middleSchoolMentor':
        return 'Middle School Mentor Dashboard';
      case 'highSchoolMentor':
        return 'High School Mentor Dashboard';
      case 'houseLeader':
        return 'House Leader Dashboard';
      case 'studentHouseLeader':
        return 'Student House Leader Dashboard';
      case 'houseMember':
        return 'House Member Dashboard';
      case 'studentHouseMember':
        return 'Student House Member Dashboard';
      case 'accountant':
        return 'Accountant Dashboard';
      default:
        return 'Dashboard';
    }
  }

  // 🎯 Build role-specific top widget
  Widget _buildTopWidget(String role) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final mediaQuery = MediaQuery.of(context);
        final screenWidth = mediaQuery.size.width;
        final isLargeScreen = screenWidth > 600;
        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;

        // Mock notification data - bu gerçek verilerle değiştirilecek
        final notifications = _getMockNotifications();

        return _buildDynamicNotificationContainer(
            notifications, isLargeScreen, isDark);
      },
    );
  }

  // Mock notifications - gerçek veri için bu method değiştirilecek
  List<Map<String, String>> _getMockNotifications() {
    // Test için farklı durumları simüle edebiliriz
    // Boş liste = "Şu an bildirim yok"
    return [];

    // Tek notification = tüm kutuyu kapla
    // return [
    //   {
    //     'title': 'System Update',
    //     'message': 'New features available',
    //     'time': '2 min ago'
    //   },
    // ];

    // Çoklu notification = kaydırılabilir
    // return [
    //   {
    //     'title': 'System Update',
    //     'message': 'New features available',
    //     'time': '2 min ago'
    //   },
    //   {
    //     'title': 'New Assignment',
    //     'message': 'Role assignment pending',
    //     'time': '5 min ago'
    //   },
    // ];
  }

  Widget _buildDynamicNotificationContainer(
      List<Map<String, String>> notifications,
      bool isLargeScreen,
      bool isDark) {
    if (notifications.isEmpty) {
      return _buildEmptyNotificationState(isLargeScreen, isDark);
    } else if (notifications.length == 1) {
      return _buildSingleNotificationState(
          notifications.first, isLargeScreen, isDark);
    } else {
      return _buildMultipleNotificationState(
          notifications, isLargeScreen, isDark);
    }
  }

  Widget _buildEmptyNotificationState(bool isLargeScreen, bool isDark) {
    return Container(
      height: 120,
      margin: EdgeInsets.all(isLargeScreen ? AppSpacing.md : AppSpacing.sm),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(isLargeScreen ? 20 : 16),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.notifications_off_outlined,
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
              size: isLargeScreen ? 32 : 28,
            ),
            SizedBox(height: AppSpacing.sm),
            Text(
              'All caught up! No new notifications',
              style: AppTextStyles.body.copyWith(
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
                fontSize: isLargeScreen ? 16 : 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSingleNotificationState(
      Map<String, String> notification, bool isLargeScreen, bool isDark) {
    return Container(
      margin: EdgeInsets.all(isLargeScreen ? AppSpacing.md : AppSpacing.sm),
      padding: EdgeInsets.all(isLargeScreen ? AppSpacing.lg : AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(isLargeScreen ? 20 : 16),
      ),
      child: Row(
        children: [
          Container(
            width: isLargeScreen ? 52 : 44,
            height: isLargeScreen ? 52 : 44,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.2),
              borderRadius: BorderRadius.circular(isLargeScreen ? 14 : 12),
            ),
            child: Icon(
              Icons.notifications_outlined,
              color: AppColors.primary,
              size: isLargeScreen ? 26 : 22,
            ),
          ),
          SizedBox(width: isLargeScreen ? AppSpacing.lg : AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  notification['title'] ?? 'Notification',
                  style: AppTextStyles.subheadline.copyWith(
                    fontSize: isLargeScreen ? 18 : 16,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? AppColors.textPrimaryDark
                        : AppColors.textPrimaryLight,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  notification['message'] ?? '',
                  style: AppTextStyles.caption.copyWith(
                    fontSize: isLargeScreen ? 14 : 12,
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                  ),
                ),
                if (notification['time'] != null)
                  Text(
                    notification['time']!,
                    style: AppTextStyles.caption.copyWith(
                      fontSize: isLargeScreen ? 12 : 10,
                      color: isDark
                          ? AppColors.textSecondaryDark.withOpacity(0.7)
                          : AppColors.textSecondaryLight.withOpacity(0.7),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMultipleNotificationState(
      List<Map<String, String>> notifications,
      bool isLargeScreen,
      bool isDark) {
    return Container(
      height: 140,
      margin: EdgeInsets.all(isLargeScreen ? AppSpacing.md : AppSpacing.sm),
      child: PageView.builder(
        itemCount: notifications.length,
        itemBuilder: (context, index) {
          final notification = notifications[index];
          return Container(
            margin: EdgeInsets.symmetric(horizontal: 4),
            padding:
                EdgeInsets.all(isLargeScreen ? AppSpacing.lg : AppSpacing.md),
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(isLargeScreen ? 20 : 16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: isLargeScreen ? 40 : 36,
                      height: isLargeScreen ? 40 : 36,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.2),
                        borderRadius:
                            BorderRadius.circular(isLargeScreen ? 12 : 10),
                      ),
                      child: Icon(
                        Icons.notifications_outlined,
                        color: AppColors.primary,
                        size: isLargeScreen ? 20 : 18,
                      ),
                    ),
                    SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            notification['title'] ?? 'Notification',
                            style: AppTextStyles.subheadline.copyWith(
                              fontSize: isLargeScreen ? 16 : 14,
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? AppColors.textPrimaryDark
                                  : AppColors.textPrimaryLight,
                            ),
                          ),
                          Text(
                            notification['time'] ?? '',
                            style: AppTextStyles.caption.copyWith(
                              fontSize: isLargeScreen ? 12 : 10,
                              color: isDark
                                  ? AppColors.textSecondaryDark.withOpacity(0.7)
                                  : AppColors.textSecondaryLight
                                      .withOpacity(0.7),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: AppSpacing.sm),
                Text(
                  notification['message'] ?? '',
                  style: AppTextStyles.body.copyWith(
                    fontSize: isLargeScreen ? 14 : 12,
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // 🎯 Get role-specific menu items
  List<Map<String, dynamic>> _getMenuItems(String role) {
    switch (role) {
      case 'admin':
        return _getAdminMenuItems();
      case 'moderator':
        return _getModeratorMenuItems();
      case 'director':
        return _getDirectorMenuItems();
      case 'middleSchoolCoordinator':
      case 'highSchoolCoordinator':
      case 'universityCoordinator':
      case 'housingCoordinator':
        return _getCoordinatorMenuItems(role);
      case 'middleSchoolAssistantCoordinator':
      case 'highSchoolAssistantCoordinator':
      case 'universityAssistantCoordinator':
      case 'housingAssistantCoordinator':
        return _getAssistantCoordinatorMenuItems(role);
      case 'middleSchoolMentor':
      case 'highSchoolMentor':
        return _getMentorMenuItems(role);
      case 'houseLeader':
      case 'studentHouseLeader':
        return _getHouseLeaderMenuItems(role);
      case 'houseMember':
      case 'studentHouseMember':
        return _getHouseMemberMenuItems(role);
      case 'accountant':
        return _getAccountantMenuItems();
      default:
        return [];
    }
  }

  // 🎯 Handle top widget tap
  void _handleTopWidgetTap(String role) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${_getRoleTitle(role)} overview widget tapped')),
    );
  }

  // 🎯 Navigate to Universal Role Assignment with context
  void _navigateToRoleAssignment() {
    context.push('/universalRoleAssignment?contextRole=${widget.currentRole}');
  }

  // 🎯 Navigate to Universal Orphaned Groups with context
  void _navigateToOrphanedGroups() {
    context.push('/universalOrphanedGroups?contextRole=${widget.currentRole}');
  }

  // 🌳 Navigate to Universal User Tree
  void _navigateToUserTree() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => UniversalUserTreePage(
          currentRole: widget.currentRole,
          userId: 'current_user_id', // TODO: Get actual user ID
        ),
      ),
    );
  }

  // 🎯 Navigate to Mentor/Mentee Management
  void _navigateToMentorMentee() {
    context.push('/universalEditMentorMentee');
  }

  // ===== TOP WIDGETS =====

  // Back-compat helper to avoid undefined refs in old code sections
  Widget _addNotificationOverlay(Widget child, bool isLargeScreen) {
    return Stack(
      children: [
        child,
        Positioned(
          top: 0,
          left: 0,
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: isLargeScreen ? 8 : 6,
              vertical: isLargeScreen ? 4 : 3,
            ),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'Notification',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // 🔔 Enhanced notification widget - refined minimal style
  Widget _buildEmptyNotificationWidget(bool isLargeScreen) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return CleanCard.elevated(
      child: Padding(
        padding: EdgeInsets.all(isLargeScreen ? AppSpacing.lg : AppSpacing.md),
        child: Row(
          children: [
            // Left side - Quick overview
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Dashboard Overview',
                    style: AppTextStyles.subheadline.copyWith(
                      fontSize: isLargeScreen ? 17 : 15,
                      fontWeight: FontWeight.w700,
                      color: isDark
                          ? AppColors.textPrimaryDark
                          : AppColors.textPrimaryLight,
                    ),
                  ),
                  SizedBox(
                      height: isLargeScreen ? AppSpacing.sm : AppSpacing.xs),
                  Row(
                    children: [
                      _buildMinimalStatChip(
                        label: 'Active',
                        value: '12',
                        color: AppColors.success,
                        isLargeScreen: isLargeScreen,
                      ),
                      SizedBox(
                          width: isLargeScreen ? AppSpacing.sm : AppSpacing.xs),
                      _buildMinimalStatChip(
                        label: 'Pending',
                        value: '3',
                        color: AppColors.warning,
                        isLargeScreen: isLargeScreen,
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Right side - Icon
            Container(
              width: isLargeScreen ? 50 : 44,
              height: isLargeScreen ? 50 : 44,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppBorderRadius.md),
              ),
              child: Icon(
                Icons.dashboard_outlined,
                color: AppColors.primary,
                size: isLargeScreen ? 24 : 20,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Minimal stat chip for notification widget
  Widget _buildMinimalStatChip({
    required String label,
    required String value,
    required Color color,
    required bool isLargeScreen,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isLargeScreen ? AppSpacing.sm : AppSpacing.xs,
        vertical: isLargeScreen ? AppSpacing.xs : 3,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppBorderRadius.sm),
        border: Border.all(
          color: color.withOpacity(0.2),
          width: 0.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: AppTextStyles.caption.copyWith(
              fontSize: isLargeScreen ? 12 : 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
          SizedBox(width: isLargeScreen ? AppSpacing.xs : 3),
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              fontSize: isLargeScreen ? 11 : 10,
              fontWeight: FontWeight.w500,
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdminTopWidget(bool isLargeScreen, bool isMediumScreen) =>
      _buildEmptyNotificationWidget(isLargeScreen);

  Widget _buildModeratorTopWidget(bool isLargeScreen, bool isMediumScreen) =>
      _buildEmptyNotificationWidget(isLargeScreen);

  Widget _buildDirectorTopWidget(bool isLargeScreen, bool isMediumScreen) =>
      _buildEmptyNotificationWidget(isLargeScreen);

  Widget _buildCoordinatorTopWidget(
          String role, bool isLargeScreen, bool isMediumScreen) =>
      _buildEmptyNotificationWidget(isLargeScreen);

  Widget _buildAssistantCoordinatorTopWidget(
          String role, bool isLargeScreen, bool isMediumScreen) =>
      _buildEmptyNotificationWidget(isLargeScreen);

  Widget _buildAssistantCoordinatorTopWidget_OLD(
      String role, bool isLargeScreen, bool isMediumScreen) {
    String department = _getDepartmentFromRole(role);
    IconData icon = _getIconForRole(role);
    Color color = _getColorForRole(role);

    return _addNotificationOverlay(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                color: Colors.white,
                size: isLargeScreen
                    ? 36
                    : isMediumScreen
                        ? 32
                        : 28,
              ),
              SizedBox(width: isLargeScreen ? 16 : 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$department Assistant',
                      style: TextStyle(
                        fontSize: isLargeScreen
                            ? 20
                            : isMediumScreen
                                ? 18
                                : 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: -0.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.visible,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Support $department coordination activities',
                      style: TextStyle(
                        fontSize: isLargeScreen
                            ? 14
                            : isMediumScreen
                                ? 12
                                : 11,
                        color: Colors.white70,
                        height: 1.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isLargeScreen ? 14 : 10,
                  vertical: isLargeScreen ? 8 : 6,
                ),
                constraints: const BoxConstraints(
                  minWidth: 70,
                  minHeight: 28,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      color.withOpacity(0.3),
                      color.withOpacity(0.2),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(isLargeScreen ? 16 : 12),
                  border: Border.all(color: color.withOpacity(0.4)),
                ),
                child: Center(
                  child: Text(
                    'ASST',
                    style: TextStyle(
                      fontSize: isLargeScreen ? 12 : 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: isLargeScreen ? 12 : 8),
          Row(
            children: [
              Expanded(
                child: _buildQuickStat(
                  'Mentors',
                  '8',
                  Icons.psychology,
                  isLargeScreen,
                  isMediumScreen,
                ),
              ),
              SizedBox(width: isLargeScreen ? 20 : 16),
              Expanded(
                child: _buildQuickStat(
                  'Activities',
                  '15',
                  Icons.event,
                  isLargeScreen,
                  isMediumScreen,
                ),
              ),
            ],
          ),
        ],
      ),
      isLargeScreen,
    );
  }

  Widget _buildMentorTopWidget(
      String role, bool isLargeScreen, bool isMediumScreen) {
    String department = _getDepartmentFromRole(role);
    IconData icon = Icons.psychology;
    Color color = _getColorForRole(role);

    return Stack(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  color: Colors.white,
                  size: isLargeScreen
                      ? 36
                      : isMediumScreen
                          ? 32
                          : 28,
                ),
                SizedBox(width: isLargeScreen ? 16 : 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$department Mentorship',
                        style: TextStyle(
                          fontSize: isLargeScreen
                              ? 20
                              : isMediumScreen
                                  ? 18
                                  : 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: -0.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.visible,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Guide and support $department students',
                        style: TextStyle(
                          fontSize: isLargeScreen
                              ? 14
                              : isMediumScreen
                                  ? 12
                                  : 11,
                          color: Colors.white70,
                          height: 1.2,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isLargeScreen ? 14 : 10,
                    vertical: isLargeScreen ? 8 : 6,
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 70,
                    minHeight: 28,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        color.withOpacity(0.3),
                        color.withOpacity(0.2),
                      ],
                    ),
                    borderRadius:
                        BorderRadius.circular(isLargeScreen ? 16 : 12),
                    border: Border.all(color: color.withOpacity(0.4)),
                  ),
                  child: Center(
                    child: Text(
                      'MENTOR',
                      style: TextStyle(
                        fontSize: isLargeScreen ? 12 : 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        // Notification text in top-left corner
        Positioned(
          top: 0,
          left: 0,
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: isLargeScreen ? 8 : 6,
              vertical: isLargeScreen ? 4 : 3,
            ),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'Notification',
              style: TextStyle(
                fontSize: isLargeScreen ? 12 : 10,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHouseLeaderTopWidget(
          String role, bool isLargeScreen, bool isMediumScreen) =>
      _buildEmptyNotificationWidget(isLargeScreen);

  Widget _buildHouseLeaderTopWidget_OLD(
      String role, bool isLargeScreen, bool isMediumScreen) {
    String houseType = role == 'studentHouseLeader' ? 'Student House' : 'House';
    IconData icon = Icons.home;
    Color color = role == 'studentHouseLeader' ? Colors.blue : Colors.green;

    return _addNotificationOverlay(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                color: Colors.white,
                size: isLargeScreen
                    ? 36
                    : isMediumScreen
                        ? 32
                        : 28,
              ),
              SizedBox(width: isLargeScreen ? 16 : 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$houseType Leadership',
                      style: TextStyle(
                        fontSize: isLargeScreen
                            ? 20
                            : isMediumScreen
                                ? 18
                                : 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Lead and manage house community',
                      style: TextStyle(
                        fontSize: isLargeScreen
                            ? 14
                            : isMediumScreen
                                ? 12
                                : 11,
                        color: Colors.white70,
                        height: 1.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isLargeScreen ? 14 : 10,
                  vertical: isLargeScreen ? 8 : 6,
                ),
                constraints: const BoxConstraints(
                  minWidth: 70,
                  minHeight: 28,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      color.withOpacity(0.3),
                      color.withOpacity(0.2),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(isLargeScreen ? 16 : 12),
                  border: Border.all(color: color.withOpacity(0.4)),
                ),
                child: Center(
                  child: Text(
                    'LEADER',
                    style: TextStyle(
                      fontSize: isLargeScreen ? 12 : 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: isLargeScreen ? 12 : 8),
          Row(
            children: [
              Expanded(
                child: _buildQuickStat(
                  'Members',
                  '12',
                  Icons.people,
                  isLargeScreen,
                  isMediumScreen,
                ),
              ),
              SizedBox(width: isLargeScreen ? 20 : 16),
              Expanded(
                child: _buildQuickStat(
                  'Events',
                  '6',
                  Icons.event,
                  isLargeScreen,
                  isMediumScreen,
                ),
              ),
            ],
          ),
        ],
      ),
      isLargeScreen,
    );
  }

  Widget _buildHouseMemberTopWidget(
          String role, bool isLargeScreen, bool isMediumScreen) =>
      _buildEmptyNotificationWidget(isLargeScreen);

  Widget _buildHouseMemberTopWidget_OLD(
      String role, bool isLargeScreen, bool isMediumScreen) {
    String houseType = role == 'studentHouseMember' ? 'Student House' : 'House';
    IconData icon = Icons.home_outlined;
    Color color =
        role == 'studentHouseMember' ? Colors.lightBlue : Colors.lightGreen;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              icon,
              color: Colors.white,
              size: isLargeScreen
                  ? 36
                  : isMediumScreen
                      ? 32
                      : 28,
            ),
            SizedBox(width: isLargeScreen ? 16 : 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$houseType Community',
                    style: TextStyle(
                      fontSize: isLargeScreen
                          ? 20
                          : isMediumScreen
                              ? 18
                              : 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Participate in house activities and programs',
                    style: TextStyle(
                      fontSize: isLargeScreen
                          ? 14
                          : isMediumScreen
                              ? 12
                              : 11,
                      color: Colors.white70,
                      height: 1.2,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: isLargeScreen ? 14 : 10,
                vertical: isLargeScreen ? 8 : 6,
              ),
              constraints: const BoxConstraints(
                minWidth: 70,
                minHeight: 28,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    color.withOpacity(0.3),
                    color.withOpacity(0.2),
                  ],
                ),
                borderRadius: BorderRadius.circular(isLargeScreen ? 16 : 12),
                border: Border.all(color: color.withOpacity(0.4)),
              ),
              child: Center(
                child: Text(
                  'MEMBER',
                  style: TextStyle(
                    fontSize: isLargeScreen ? 12 : 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: isLargeScreen ? 12 : 8),
        Row(
          children: [
            Expanded(
              child: _buildQuickStat(
                'Activities',
                '8',
                Icons.event_available,
                isLargeScreen,
                isMediumScreen,
              ),
            ),
            SizedBox(width: isLargeScreen ? 20 : 16),
            Expanded(
              child: _buildQuickStat(
                'Points',
                '245',
                Icons.star,
                isLargeScreen,
                isMediumScreen,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAccountantTopWidget(bool isLargeScreen, bool isMediumScreen) =>
      _buildEmptyNotificationWidget(isLargeScreen);

  Widget _buildAccountantTopWidget_OLD(
      bool isLargeScreen, bool isMediumScreen) {
    return _addNotificationOverlay(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.account_balance,
                color: Colors.white,
                size: isLargeScreen
                    ? 36
                    : isMediumScreen
                        ? 32
                        : 28,
              ),
              SizedBox(width: isLargeScreen ? 16 : 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Financial Management',
                      style: TextStyle(
                        fontSize: isLargeScreen
                            ? 20
                            : isMediumScreen
                                ? 18
                                : 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Manage finances and accounting records',
                      style: TextStyle(
                        fontSize: isLargeScreen
                            ? 14
                            : isMediumScreen
                                ? 12
                                : 11,
                        color: Colors.white70,
                        height: 1.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isLargeScreen ? 14 : 10,
                  vertical: isLargeScreen ? 8 : 6,
                ),
                constraints: const BoxConstraints(
                  minWidth: 70,
                  minHeight: 28,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.warning,
                      Colors.amber.withOpacity(0.2),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(isLargeScreen ? 16 : 12),
                  border: Border.all(color: Colors.amber.withOpacity(0.4)),
                ),
                child: Center(
                  child: Text(
                    'ACC',
                    style: TextStyle(
                      fontSize: isLargeScreen ? 12 : 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: isLargeScreen ? 12 : 8),
          Row(
            children: [
              Expanded(
                child: _buildQuickStat(
                  'Transactions',
                  '156',
                  Icons.receipt,
                  isLargeScreen,
                  isMediumScreen,
                ),
              ),
              SizedBox(width: isLargeScreen ? 20 : 16),
              Expanded(
                child: _buildQuickStat(
                  'Balance',
                  '\$12.5K',
                  Icons.account_balance_wallet,
                  isLargeScreen,
                  isMediumScreen,
                ),
              ),
            ],
          ),
        ],
      ),
      isLargeScreen,
    );
  }

  Widget _buildDefaultTopWidget(bool isLargeScreen, bool isMediumScreen) =>
      _buildEmptyNotificationWidget(isLargeScreen);

  Widget _buildDefaultTopWidget_OLD(bool isLargeScreen, bool isMediumScreen) {
    return _addNotificationOverlay(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.dashboard,
                color: Colors.white,
                size: isLargeScreen
                    ? 36
                    : isMediumScreen
                        ? 32
                        : 28,
              ),
              SizedBox(width: isLargeScreen ? 16 : 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Dashboard',
                      style: TextStyle(
                        fontSize: isLargeScreen
                            ? 20
                            : isMediumScreen
                                ? 18
                                : 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Welcome to your dashboard',
                      style: TextStyle(
                        fontSize: isLargeScreen
                            ? 14
                            : isMediumScreen
                                ? 12
                                : 11,
                        color: Colors.white70,
                        height: 1.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      isLargeScreen,
    );
  }

  Widget _buildQuickStat(String label, String value, IconData icon,
      bool isLargeScreen, bool isMediumScreen) {
    return Container(
      padding: EdgeInsets.all(isLargeScreen ? 12 : 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withOpacity(0.15),
            Colors.white.withOpacity(0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(isLargeScreen ? 12 : 8),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(isLargeScreen ? 8 : 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(isLargeScreen ? 8 : 6),
            ),
            child: Icon(
              icon,
              color: Colors.white70,
              size: isLargeScreen
                  ? 20
                  : isMediumScreen
                      ? 18
                      : 16,
            ),
          ),
          SizedBox(width: isLargeScreen ? 10 : 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: isLargeScreen
                        ? 16
                        : isMediumScreen
                            ? 14
                            : 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: -0.2,
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: isLargeScreen
                        ? 12
                        : isMediumScreen
                            ? 11
                            : 10,
                    color: Colors.white70,
                    height: 1.1,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ===== MENU ITEMS =====

  List<Map<String, dynamic>> _getAdminMenuItems() {
    return [
      {
        'label': 'Assign Role',
        'icon': Icons.person_add,
        'color': AppColors.primary,
        'onTap': () {
          HapticFeedback.lightImpact();
          _navigateToRoleAssignment();
        },
      },
      {
        'label': 'Fix Orphaned Groups',
        'icon': Icons.healing,
        'color': AppColors.warning,
        'onTap': () {
          HapticFeedback.lightImpact();
          _navigateToOrphanedGroups();
        },
      },
      {
        'label': 'System Reset',
        'icon': Icons.restore,
        'color': AppColors.error,
        'onTap': () {
          HapticFeedback.heavyImpact();
          _showSystemResetConfirmation();
        },
      },
    ];
  }

  List<Map<String, dynamic>> _getModeratorMenuItems() {
    return [
      {
        'label': 'Assign Role',
        'icon': Icons.person_add,
        'color': AppColors.primary,
        'onTap': () {
          HapticFeedback.lightImpact();
          _navigateToRoleAssignment();
        },
      },
      {
        'label': 'Fix Orphaned Groups',
        'icon': Icons.healing,
        'color': AppColors.warning,
        'onTap': () {
          HapticFeedback.lightImpact();
          _navigateToOrphanedGroups();
        },
      },
    ];
  }

  List<Map<String, dynamic>> _getDirectorMenuItems() {
    final items = [
      {
        'label': 'Assign Role',
        'icon': Icons.person_add,
        'color': AppColors.primary,
        'onTap': () {
          HapticFeedback.lightImpact();
          _navigateToRoleAssignment();
        },
      },
      {
        'label': 'Fix Orphaned Groups',
        'icon': Icons.healing,
        'color': AppColors.warning,
        'onTap': () {
          HapticFeedback.lightImpact();
          _navigateToOrphanedGroups();
        },
      },
      {
        'label': 'User Tree',
        'icon': Icons.account_tree,
        'color': AppColors.success,
        'onTap': () {
          HapticFeedback.lightImpact();
          _navigateToUserTree();
        },
      },
      {
        'label': 'Mentor & Mentee',
        'icon': Icons.school,
        'color': AppColors.info,
        'onTap': () {
          HapticFeedback.lightImpact();
          _navigateToMentorMentee();
        },
      },
    ];
    return items;
  }

  List<Map<String, dynamic>> _getCoordinatorMenuItems(String role) {
    final items = [
      {
        'label': 'Assign Role',
        'icon': Icons.person_add,
        'color': AppColors.primary,
        'onTap': () {
          HapticFeedback.lightImpact();
          _navigateToRoleAssignment();
        },
      },
      {
        'label': 'Fix Orphaned Groups',
        'icon': Icons.healing,
        'color': AppColors.warning,
        'onTap': () {
          HapticFeedback.lightImpact();
          _navigateToOrphanedGroups();
        },
      },
    ];

    // Only add Mentor/Mentee button for Middle School and High School coordinators
    if (role == 'middleSchoolCoordinator' || role == 'highSchoolCoordinator') {
      items.add({
        'label': 'Mentor & Mentee',
        'icon': Icons.school,
        'color': AppColors.info,
        'onTap': () {
          HapticFeedback.lightImpact();
          _navigateToMentorMentee();
        },
      });
    }

    return items;
  }

  List<Map<String, dynamic>> _getAssistantCoordinatorMenuItems(String role) {
    final items = [
      {
        'label': 'Assign Role',
        'icon': Icons.person_add,
        'color': AppColors.primary,
        'onTap': () {
          HapticFeedback.lightImpact();
          _navigateToRoleAssignment();
        },
      },
      {
        'label': 'Fix Orphaned Groups',
        'icon': Icons.healing,
        'color': AppColors.warning,
        'onTap': () {
          HapticFeedback.lightImpact();
          _navigateToOrphanedGroups();
        },
      },
    ];

    // Only add Mentor/Mentee button for Middle School and High School assistant coordinators
    if (role == 'middleSchoolAssistantCoordinator' ||
        role == 'highSchoolAssistantCoordinator') {
      items.add({
        'label': 'Mentor & Mentee',
        'icon': Icons.school,
        'color': AppColors.info,
        'onTap': () {
          HapticFeedback.lightImpact();
          _navigateToMentorMentee();
        },
      });
    }

    return items;
  }

  List<Map<String, dynamic>> _getMentorMenuItems(String role) {
    // Only show Weekend Report for middle school and high school mentors
    final items = <Map<String, dynamic>>[];

    if (role == 'middleSchoolMentor' || role == 'highSchoolMentor') {
      items.add({
        'label': 'Weekend Report',
        'icon': Icons.assignment,
        'color': AppColors.info,
        'onTap': () {
          HapticFeedback.lightImpact();
          context.push('/universalMentorWeekendReport');
        },
      });
    }

    items.add({
      'label': 'Resources',
      'icon': Icons.library_books,
      'color': AppColors.warning,
      'onTap': () {
        HapticFeedback.lightImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  '${_getDepartmentFromRole(role)} Resources - Coming Soon')),
        );
      },
    });

    return items;
  }

  List<Map<String, dynamic>> _getHouseLeaderMenuItems(String role) {
    return [
      {
        'label': 'Assign Role',
        'icon': Icons.person_add,
        'color': AppColors.primary,
        'onTap': () {
          HapticFeedback.lightImpact();
          _navigateToRoleAssignment();
        },
      },
    ];
  }

  List<Map<String, dynamic>> _getHouseMemberMenuItems(String role) {
    // House Member rollerinde "Assign Role" butonu YOK
    return [
      {
        'label': 'My Contributions',
        'icon': Icons.star,
        'color': AppColors.warning,
        'onTap': () {
          HapticFeedback.lightImpact();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('My Contributions - Coming Soon')),
          );
        },
      },
    ];
  }

  List<Map<String, dynamic>> _getAccountantMenuItems() {
    // Accountant rolünde "Assign Role" butonu YOK
    return [
      {
        'label': 'Financial Reports',
        'icon': Icons.assessment,
        'color': AppColors.info,
        'onTap': () {
          HapticFeedback.lightImpact();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Financial Reports - Coming Soon')),
          );
        },
      },
    ];
  }

  // ===== HELPER METHODS =====

  String _getDepartmentFromRole(String role) {
    if (role.contains('middleSchool')) return 'Middle School';
    if (role.contains('highSchool')) return 'High School';
    if (role.contains('university')) return 'University';
    if (role.contains('housing')) return 'Housing';
    return 'Department';
  }

  IconData _getIconForRole(String role) {
    if (role.contains('middleSchool')) return Icons.school;
    if (role.contains('highSchool')) return Icons.school;
    if (role.contains('university')) return Icons.account_balance;
    if (role.contains('housing')) return Icons.home;
    return Icons.work;
  }

  Color _getColorForRole(String role) {
    if (role.contains('middleSchool')) return Colors.green;
    if (role.contains('highSchool')) return Colors.blue;
    if (role.contains('university')) return Colors.purple;
    if (role.contains('housing')) return Colors.teal;
    return Colors.grey;
  }

  // 🎯 System Reset functionality (from AdminDashboardWrapper)
  void _showSystemResetConfirmation() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isLargeScreen = screenWidth > 600;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(isLargeScreen ? 24 : 20),
        ),
        contentPadding: EdgeInsets.all(isLargeScreen ? 24 : 20),
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.red, size: 28),
            SizedBox(width: 12),
            Text(
              'System Reset',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '⚠️ This will perform a complete system reset:',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            Text(
              '• Reset all users to basic "user" role\n'
              '• Clear all top-level managesEntity fields\n'
              '• Delete all organizational units (except admin)\n'
              '• Clean all role-specific data\n'
              '• Preserve admin account and personal data',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
            SizedBox(height: 16),
            Text(
              '🔴 This action cannot be undone!',
              style: TextStyle(
                  color: Colors.red, fontSize: 14, fontWeight: FontWeight.bold),
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
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('System Reset - Coming Soon')),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Reset System',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
