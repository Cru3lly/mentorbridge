import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import '../../widgets/clean_card.dart';
import '../../theme/app_theme.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../utils/habit_period_utils.dart';

// Custom PanGestureRecognizer for winning gesture arena
class HabitCardPanRecognizer extends PanGestureRecognizer {
  HabitCardPanRecognizer({Object? debugOwner}) : super(debugOwner: debugOwner);

  @override
  void addAllowedPointer(PointerDownEvent event) {
    super.addAllowedPointer(event);
    // Win gesture arena immediately for horizontal movements
    resolve(GestureDisposition.accepted);
  }

  @override
  void handleEvent(PointerEvent event) {
    super.handleEvent(event);

    if (event is PointerMoveEvent) {
      // Horizontal movement priority
      final dx = event.delta.dx.abs();
      final dy = event.delta.dy.abs();

      if (dx > dy && dx > 2.0) {
        // Accept gesture immediately for horizontal movement
        resolve(GestureDisposition.accepted);
        print('🏆 Habit Card Gesture WON the arena! dx=$dx, dy=$dy');
      }
    }
  }

  @override
  void acceptGesture(int pointer) {
    super.acceptGesture(pointer);
    print('🏆 Arena Victory - Gesture Accepted!');
  }

  @override
  String get debugDescription => 'HabitCard Arena Winner Pan';
}

class UserSpiritualTracking extends StatefulWidget {
  const UserSpiritualTracking({super.key});

  @override
  State<UserSpiritualTracking> createState() => _UserSpiritualTrackingState();
}

class _UserSpiritualTrackingState extends State<UserSpiritualTracking>
    with WidgetsBindingObserver {
  DateTime _selectedDate = DateTime.now();
  List<Map<String, dynamic>> _userHabits = [];
  bool _isLoading = true;
  String? _error;
  bool _isConnected = true;
  bool _isPanningOnCard = false; // Gesture arena control

  // Listener state variables
  double _startX = 0;
  double _startY = 0;
  double _lastX = 0; // Track last position for delta calculation
  bool _isListenerPanning = false;

  // DragLock removed: drag tracking disabled

  // Caching for performance
  final Map<String, List<Map<String, dynamic>>> _habitsCache = {};
  Timer? _cacheTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeConnectivity();
    _loadUserHabits();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cacheTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadUserHabits();
    }
  }

  Future<void> _initializeConnectivity() async {
    try {
      // Simple connectivity check by attempting to resolve a DNS
      // This is a basic check without external dependencies
      setState(() {
        _isConnected =
            true; // Assume connected, will be checked during Firebase operations
      });
    } catch (e) {
      setState(() {
        _isConnected = false;
      });
    }
  }

  Future<void> _loadUserHabits() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Check connectivity first
      if (!_isConnected) {
        throw Exception('No internet connection available');
      }

      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      // Check cache first - Load ALL periods for selected date
      final dailyKey = HabitPeriodUtils.generateDateKey(_selectedDate, 'Daily');
      final weeklyKey =
          HabitPeriodUtils.generateDateKey(_selectedDate, 'Weekly');
      final monthlyKey =
          HabitPeriodUtils.generateDateKey(_selectedDate, 'Monthly');

      // Try cache first
      final cacheKey = 'combined_${_selectedDate.millisecondsSinceEpoch}';
      if (_habitsCache.containsKey(cacheKey)) {
        if (mounted) {
          setState(() {
            _userHabits = _habitsCache[cacheKey]!;
            _isLoading = false;
          });
        }
        return;
      }

      // Load habits from Firebase for ALL periods
      final List<Future<QuerySnapshot>> futures = [
        FirebaseFirestore.instance
            .collection('habits')
            .doc(currentUser.uid)
            .collection(dailyKey)
            .orderBy('createdAt', descending: false)
            .get()
            .timeout(const Duration(seconds: 10)),
        FirebaseFirestore.instance
            .collection('habits')
            .doc(currentUser.uid)
            .collection(weeklyKey)
            .orderBy('createdAt', descending: false)
            .get()
            .timeout(const Duration(seconds: 10)),
        FirebaseFirestore.instance
            .collection('habits')
            .doc(currentUser.uid)
            .collection(monthlyKey)
            .orderBy('createdAt', descending: false)
            .get()
            .timeout(const Duration(seconds: 10)),
      ];

      final List<QuerySnapshot> snapshots = await Future.wait(futures);

      // Combine all habits from different periods
      final List<Map<String, dynamic>> habits = [];

      for (final snapshot in snapshots) {
        for (final doc in snapshot.docs) {
          final data = doc.data() as Map<String, dynamic>;

          // Apply filters: taskDays and timeRange
          final taskDays = data['taskDays'] ?? 'Every Day';
          final timeRange = data['timeRange'] ?? 'Anytime';

          // Check if habit should be shown today
          if (!HabitPeriodUtils.shouldShowHabitToday(taskDays, _selectedDate)) {
            continue; // Skip this habit
          }

          // Check if current time is within range (optional filter)
          if (!HabitPeriodUtils.isWithinTimeRange(timeRange)) {
            // Still show habit but maybe with different styling
          }

          habits.add({
            'id': doc.id,
            'name': data['name'] ?? '',
            'category': data['category'] ?? 'spiritual',
            'icon': _getIconFromName(data['iconName'] ?? 'mosque'),
            'color': _getColorFromName(data['colorName'] ?? 'green'),
            'type': data['type'] ?? 'count',
            'target':
                data['target'] ?? data['goal'] ?? 1, // Handle both field names
            'current': data['current'] ?? 0,
            'unit': data['unit'] ?? '',
            'completed': data['completed'] ?? false,
            'completedAt': data['completedAt'],
            'goalPeriod': data['goalPeriod'] ?? 'Daily',
            'timeRange': timeRange,
            'taskDays': taskDays,
          });
        }
      }

      // Sort habits: incomplete first, completed last
      habits.sort((a, b) {
        final aCompleted = a['current'] >= a['target'];
        final bCompleted = b['current'] >= b['target'];

        if (aCompleted && !bCompleted) return 1; // a goes to bottom
        if (!aCompleted && bCompleted) return -1; // a stays on top

        // If both same completion status, sort by progress (less progress first)
        if (!aCompleted && !bCompleted) {
          final aProgress = a['current'] / a['target'];
          final bProgress = b['current'] / b['target'];
          return aProgress.compareTo(bProgress);
        }

        return 0; // Keep original order for completed items
      });

      // Cache the results
      _habitsCache[cacheKey] = habits;

      // Set cache expiry timer
      _cacheTimer?.cancel();
      _cacheTimer = Timer(const Duration(minutes: 5), () {
        _habitsCache.remove(cacheKey);
      });

      if (mounted) {
        setState(() {
          _userHabits = habits;
          _isLoading = false;
        });
      }
    } on FirebaseException catch (e) {
      _handleError('Firebase error: ${e.message ?? 'Unknown error'}');
    } on TimeoutException catch (_) {
      _handleError('Request timed out. Please check your connection.');
    } catch (e) {
      _handleError('Failed to load habits: ${e.toString()}');
    }
  }

  void _handleError(String error) {
    if (mounted) {
      setState(() {
        _error = error;
        _isLoading = false;
      });
    }
  }

  // This method is no longer needed with new structure
  // Progress is directly stored in the document for each date

  IconData _getIconFromName(String iconName) {
    switch (iconName) {
      case 'mosque':
        return Icons.mosque;
      case 'menu_book':
        return Icons.menu_book;
      case 'favorite':
        return Icons.favorite;
      case 'pan_tool':
        return Icons.pan_tool;
      case 'volunteer_activism':
        return Icons.volunteer_activism;
      case 'self_improvement':
        return Icons.self_improvement;
      case 'no_food':
        return Icons.no_food;
      case 'nightlight':
        return Icons.nightlight;
      case 'psychology':
        return Icons.psychology;
      case 'school':
        return Icons.school;
      case 'fitness_center':
        return Icons.fitness_center;
      case 'directions_walk':
        return Icons.directions_walk;
      case 'restaurant':
        return Icons.restaurant;
      case 'bedtime':
        return Icons.bedtime;
      default:
        return Icons.mosque;
    }
  }

  Color _getColorFromName(String colorName) {
    print('🎨 Color parsing: "$colorName"'); // DEBUG

    // Handle both old format (color names) and new format (hex strings)
    if (colorName.startsWith('0x')) {
      try {
        // Parse hex color string
        final color = Color(int.parse(colorName));
        print('🎨 Hex parsed: $color'); // DEBUG
        return color;
      } catch (e) {
        print('🎨 Hex parsing failed: $e'); // DEBUG
        // Fallback to default if parsing fails
        return AppColors.habitColors[0];
      }
    }

    // Legacy support for old color names
    final colorMap = {
      'green': AppColors.habitColors[0],
      'blue': AppColors.habitColors[1],
      'purple': AppColors.habitColors[2],
      'orange': AppColors.habitColors[3],
      'red': AppColors.habitColors[4],
      'teal': AppColors.habitColors[5],
      'amber': AppColors.habitColors[6],
      'indigo': AppColors.habitColors[7],
      'cyan': AppColors.habitColors[8],
      'brown': AppColors.habitColors[9],
    };
    final legacyColor = colorMap[colorName] ?? AppColors.habitColors[0];
    print('🎨 Legacy color "$colorName" → $legacyColor'); // DEBUG
    return legacyColor;
  }

  void _changeDate(int days) {
    setState(() {
      _selectedDate = _selectedDate.add(Duration(days: days));
      _isLoading = true;
    });
    _loadUserHabits(); // Reload habits for the new date
  }

  Future<void> _showDatePicker() async {
    try {
      final DateTime? pickedDate = await showDatePicker(
        context: context,
        initialDate: _selectedDate,
        firstDate: DateTime(2020),
        lastDate: DateTime.now().add(const Duration(days: 365)),
        builder: (context, child) {
          return Theme(
            data: Theme.of(context).copyWith(
              colorScheme: const ColorScheme.light(
                primary: Colors.deepPurple,
                onPrimary: Colors.white,
                surface: Colors.white,
                onSurface: Colors.black,
              ),
            ),
            child: child!,
          );
        },
      );

      if (pickedDate != null && pickedDate != _selectedDate) {
        HapticFeedback.selectionClick();
        setState(() {
          _selectedDate = pickedDate;
          _isLoading = true;
        });
        await _loadUserHabits();
      }
    } catch (e) {
      _handleError('Failed to show date picker');
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final isLargeScreen = mediaQuery.size.width > 600;

    if (_error != null) {
      return _buildErrorState(isLargeScreen);
    }

    if (_isLoading) {
      return _buildLoadingState(isLargeScreen);
    }

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      body: SafeArea(
        child: Column(
          children: [
            // Clean Date Navigation - En üste çok yakın
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenPadding,
                2, // Daha da minimal top padding
                AppSpacing.screenPadding,
                AppSpacing.md,
              ),
              child: _buildDateNavigation(),
            ),

            // Clean Progress Section
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.screenPadding),
              child: _buildProgressSection(),
            ),

            const SizedBox(height: 10),

            // Habits Grid
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screenPadding,
                  AppSpacing.sectionSpacing,
                  AppSpacing.screenPadding,
                  AppSpacing.lg, // Bottom navigation için yer bırak
                ),
                child: _userHabits.isEmpty
                    ? _buildEmptyState()
                    : _buildHabitsGrid(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppBorderRadius.card),
              ),
              child: Icon(
                Icons.self_improvement,
                size: 40,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Start Your Spiritual Journey',
              style: AppTextStyles.headline.copyWith(
                color: isDark
                    ? AppColors.textPrimaryDark
                    : AppColors.textPrimaryLight,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Create meaningful habits to strengthen your spiritual connection.',
              style: AppTextStyles.body.copyWith(
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateNavigation() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Row(
      children: [
        // Previous day button
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              HapticFeedback.lightImpact();
              _changeDate(-1);
            },
            borderRadius: BorderRadius.circular(AppBorderRadius.button),
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: Icon(
                Icons.chevron_left,
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
                size: 24,
              ),
            ),
          ),
        ),

        // Date selector
        Expanded(
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                HapticFeedback.lightImpact();
                _showDatePicker();
              },
              borderRadius: BorderRadius.circular(AppBorderRadius.button),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                alignment: Alignment.center,
                child: Text(
                  DateFormat('EEEE, MMM d').format(_selectedDate),
                  style: AppTextStyles.headline.copyWith(
                    color: isDark
                        ? AppColors.textPrimaryDark
                        : AppColors.textPrimaryLight,
                  ),
                ),
              ),
            ),
          ),
        ),

        // Next day button
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              HapticFeedback.lightImpact();
              _changeDate(1);
            },
            borderRadius: BorderRadius.circular(AppBorderRadius.button),
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: Icon(
                Icons.chevron_right,
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
                size: 24,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProgressSection() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final progress = _getOverallProgress();

    return CleanCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Today\'s Progress',
                style: AppTextStyles.subheadline.copyWith(
                  color: isDark
                      ? AppColors.textPrimaryDark
                      : AppColors.textPrimaryLight,
                ),
              ),
              Text(
                _getOverallProgressText(),
                style: AppTextStyles.bodySecondary.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          CleanProgressIndicator(
            value: progress,
            color: progress >= 1.0 ? AppColors.success : AppColors.primary,
          ),
          if (progress >= 1.0) ...[
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Icon(
                  Icons.check_circle,
                  color: AppColors.success,
                  size: 16,
                ),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  'All habits completed!',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.success,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHabitsGrid() {
    return ListView.builder(
      itemCount: _userHabits.length,
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.zero,
      itemBuilder: (context, index) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: index == _userHabits.length - 1 ? 0 : AppSpacing.md,
          ),
          child: _buildHabitCard(_userHabits[index]),
        );
      },
    );
  }

  Widget _buildHabitCard(Map<String, dynamic> activity) {
    final double progress = activity['current'] / activity['target'];
    final bool isCompleted = activity['current'] >= activity['target'];
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Semantics(
      label:
          '${activity['name']} habit. Progress: ${activity['current']} of ${activity['target']}. ${isCompleted ? 'Completed' : 'In progress'}',
      hint: 'Swipe anywhere to increase progress',
      child: Listener(
        onPointerDown: (event) {
          _startX = event.position.dx;
          _startY = event.position.dy;
          _lastX = event.position.dx; // Reset last position
          _isListenerPanning = false;
          print(
              '👆 Pointer DOWN at x=${event.position.dx}, y=${event.position.dy}');
        },
        onPointerMove: (event) {
          final dx = event.position.dx - _startX;
          final dy = event.position.dy - _startY;

          // Simplified horizontal movement detection (ChatGPT fix)
          if (dx.abs() > 5 && dx.abs() > dy.abs() && !_isListenerPanning) {
            _isListenerPanning = true;
            setState(() => _isPanningOnCard = true);
            print(
                '🔥 Listener Pan Started: dx=$dx, dy=$dy on ${activity['name']}');
          }

          if (_isListenerPanning && dx > 0) {
            // Calculate delta movement since last frame
            final deltaX = event.position.dx - _lastX;
            if (deltaX > 0) {
              // Only process forward movement
              print('🔥 Listener Pan Progress: deltaX=$deltaX (total dx=$dx)');
              _handleListenerSwipeProgress(activity, deltaX);
              _lastX = event.position.dx; // Update last position
            }
          }
        },
        onPointerUp: (event) {
          if (_isListenerPanning) {
            print('🔥 Listener Pan Ended on ${activity['name']}');
            _handleSwipeEnd(activity);
            _isListenerPanning = false;
            setState(() => _isPanningOnCard = false);
          }
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            print('🔥 Listener TAP on ${activity['name']}');
            _handleTapProgress(activity);
          },
          child: Container(
            height: 60, // Reduced from 80 to 60 (like professional apps)
            margin: const EdgeInsets.symmetric(horizontal: 0),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppBorderRadius.card),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  offset: const Offset(0, 2),
                  blurRadius: 8,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppBorderRadius.card),
              child: Stack(
                children: [
                  // Background with habit color (always visible)
                  Container(
                    width: double.infinity,
                    height: 60, // Updated to match new card height
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          (activity['color'] as Color).withOpacity(0.3),
                          (activity['color'] as Color).withOpacity(0.2),
                        ],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                    ),
                  ),

                  // Progress fill (animated overlay) - ALWAYS uses habit color
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: (progress.clamp(0.0, 1.0)) *
                        MediaQuery.of(context).size.width,
                    height: 60, // Updated to match new card height
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          (activity['color'] as Color).withOpacity(0.7),
                          activity['color'] as Color,
                        ],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                    ),
                  ),

                  // Content overlay
                  Container(
                    width: double.infinity,
                    height: 60, // Updated to match new card height
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing
                          .sm, // Reduced vertical padding for thinner cards
                    ),
                    child: Row(
                      children: [
                        // Left side: Icon + Habit name
                        Expanded(
                          flex: 3,
                          child: Row(
                            children: [
                              // Habit icon (responsive size)
                              Container(
                                width: 32, // Further reduced for thinner cards
                                height: 32, // Further reduced for thinner cards
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius:
                                      BorderRadius.circular(AppBorderRadius.md),
                                ),
                                child: Icon(
                                  activity[
                                      'icon'], // Always show original icon, no green checkmark
                                  color: progress > 0.3
                                      ? Colors.white
                                      : (activity['color'] as Color),
                                  size:
                                      16, // Further reduced for 32x32 container
                                ),
                              ),

                              const SizedBox(
                                  width: AppSpacing.sm), // Reduced spacing

                              // Habit name + progress text
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      activity['name'],
                                      style: AppTextStyles.body.copyWith(
                                        // Changed from subheadline to body (smaller)
                                        color: progress > 0.3
                                            ? Colors.white
                                            : (isDark
                                                ? Colors.white
                                                : Colors.black87),
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14, // Explicit smaller size
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(
                                        height: 1), // Reduced spacing
                                    Text(
                                      _getActivityProgress(activity),
                                      style: AppTextStyles.caption.copyWith(
                                        color: progress > 0.3
                                            ? Colors.white.withOpacity(0.8)
                                            : (isDark
                                                ? Colors.white70
                                                : Colors.black54),
                                        fontSize: 11, // Smaller caption text
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Right side: Progress percentage (always show percentage, no checkmark)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '${(progress * 100).round()}%',
                              style: AppTextStyles.body.copyWith(
                                // Changed from title to body
                                color: progress > 0.3
                                    ? Colors.white
                                    : (activity['color'] as Color),
                                fontWeight: FontWeight.bold,
                                fontSize: 13, // Much smaller for thinner cards
                              ),
                            ),
                          ],
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
    );
  }

  // Gesture handlers
  void _handleTapProgress(Map<String, dynamic> activity) {
    final int currentValue = activity['current'];
    final int targetValue = activity['target'];

    // Already completed? Reset to 0
    if (currentValue >= targetValue) {
      setState(() {
        activity['current'] = 0;
      });
      print('🔄 Reset ${activity['name']} to 0');
      HapticFeedback.lightImpact();
      return;
    }

    // Increment by 1 for tap
    final int newValue = (currentValue + 1).clamp(0, targetValue);
    setState(() {
      activity['current'] = newValue;
    });

    print('🎉 Tap increment: ${activity['name']} $currentValue → $newValue');
    HapticFeedback.lightImpact();

    // Completion haptic
    if (newValue >= targetValue) {
      print('🏆 Habit completed by tap!');
      HapticFeedback.heavyImpact();
    }

    // Save to Firebase
    _updateActivityInFirebase(activity);
  }

  void _handleSwipeStart(
      Map<String, dynamic> activity, DragStartDetails details) {
    // Initialize drag state for direction detection
  }

  void _handleSwipeProgress(
      Map<String, dynamic> activity, DragUpdateDetails details) {
    // print('🔍 Swipe Debug: dx=${details.delta.dx}, dy=${details.delta.dy}'); // Debug disabled

    // Direction-based gesture handling to avoid PageView conflicts
    final double horizontalDelta = details.delta.dx.abs();
    final double verticalDelta = details.delta.dy.abs();

    // Minimum movement threshold to avoid accidental triggers (increased)
    const double minMovementThreshold = 0.8;

    // Only handle if horizontal movement is dominant AND significant
    if (horizontalDelta < verticalDelta ||
        horizontalDelta < minMovementThreshold) {
      print('❌ Gesture ignored: h=$horizontalDelta, v=$verticalDelta');
      return;
    }

    // Only handle right swipe (positive delta.dx) for progress
    if (details.delta.dx <= 0) {
      print('❌ Left swipe ignored: dx=${details.delta.dx}');
      return;
    }

    print('✅ Processing swipe for ${activity['name']}');

    final int currentValue = activity['current'];
    final int targetValue = activity['target'];

    // Already completed? Do nothing
    if (currentValue >= targetValue) return;

    // Smart sensitivity based on target value
    final double swipeSpeed = details.delta.dx.abs();
    double sensitivityMultiplier;

    if (targetValue >= 10000) {
      // Very large targets (10K+ steps) → Controlled increment
      sensitivityMultiplier = targetValue / 5000; // 50K steps = 10x (was 50x)
    } else if (targetValue >= 1000) {
      // Large targets (1K-10K) → Moderate increment
      sensitivityMultiplier = targetValue / 1000; // 2K target = 2x (was 10x)
    } else if (targetValue >= 100) {
      // Medium targets (100-1K) → Slow increment
      sensitivityMultiplier = targetValue / 500; // 500 target = 1x (was 10x)
    } else if (targetValue >= 10) {
      // Small targets (10-99) → Very slow increment
      sensitivityMultiplier = 1.0; // Conservative for targets like 30 min
    } else {
      // Very small targets (<10) → Ultra conservative
      sensitivityMultiplier = 0.3; // Ultra slow for 5 prayers, 1 dhikr
    }

    // Calculate increment with reduced sensitivity (much lower base multiplier)
    final double increment = swipeSpeed * 0.05 * sensitivityMultiplier;

    print(
        '📊 Target: $targetValue, Speed: $swipeSpeed, Multiplier: $sensitivityMultiplier, Increment: $increment');

    // Only increment if significant movement (increased threshold)
    if (increment > 0.5) {
      final int newValue =
          (currentValue + increment).clamp(0, targetValue).round();

      if (newValue != currentValue) {
        print(
            '🎉 Progress updated: $currentValue → $newValue (${((newValue / targetValue) * 100).round()}%)');

        setState(() {
          activity['current'] = newValue;
        });

        // Haptic feedback for progress
        HapticFeedback.lightImpact();

        // Extra celebration haptic when completed
        if (newValue >= targetValue && currentValue < targetValue) {
          print('🏆 Habit completed!');
          HapticFeedback.heavyImpact();
        }
      } else {
        print('⚠️ No change: value stayed at $currentValue');
      }
    }
  }

  void _handleSwipeEnd(Map<String, dynamic> activity) {
    // Save to Firebase when swipe ends
    _updateActivityInFirebase(activity);
  }

  // FIXED: Delta-based swipe handler (prevents exponential growth)
  void _handleListenerSwipeProgress(
      Map<String, dynamic> activity, double deltaX) {
    if (deltaX <= 0) return; // Only right swipe

    final int currentValue = activity['current'];
    final int targetValue = activity['target'];

    if (currentValue >= targetValue) return;

    // FIXED: Balanced sensitivity for all target ranges
    final double sensitivityMultiplier = targetValue >= 10000
        ? 8.0 // Very large targets (10K+ steps) - faster now
        : targetValue >= 1000
            ? 6.0 // Large targets (1K-10K) - much faster
            : targetValue >= 100
                ? 2.0 // Medium targets - keep same
                : targetValue >= 10
                    ? 4.0 // Small targets - keep same
                    : 8.0; // Very small targets - keep same

    // FIXED: Use deltaX with balanced base multiplier
    final double increment = deltaX * 0.1 * sensitivityMultiplier;

    print(
        '📊 Listener - Target: $targetValue, deltaX: $deltaX, Multiplier: $sensitivityMultiplier, Increment: $increment');

    // Lower threshold for smoother progress
    if (increment > 0.1) {
      final int newValue =
          (currentValue + increment).clamp(0, targetValue).round();

      if (newValue != currentValue) {
        setState(() {
          activity['current'] = newValue;
        });

        HapticFeedback.lightImpact();

        if (newValue >= targetValue && currentValue < targetValue) {
          print('🏆 Habit completed by listener swipe!');
          HapticFeedback.heavyImpact();
        }
      }
    }
  }

  Future<void> _updateActivityInFirebase(Map<String, dynamic> activity) async {
    if (!mounted) return;

    try {
      // Check connectivity first
      if (!_isConnected) {
        throw Exception('No internet connection');
      }

      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      final habitId = activity['id'];
      final goalPeriod = activity['goalPeriod'] ?? 'Daily';
      final dateKey =
          HabitPeriodUtils.generateDateKey(_selectedDate, goalPeriod);

      final currentValue = activity['current'];
      final isCompleted = currentValue >= activity['target'];

      // Update Firebase with new structure and timeout
      await FirebaseFirestore.instance
          .collection('habits')
          .doc(currentUser.uid)
          .collection(dateKey)
          .doc(habitId)
          .update({
        'current': currentValue,
        'completed': isCompleted,
        'completedAt': isCompleted ? FieldValue.serverTimestamp() : null,
        'lastUpdated': FieldValue.serverTimestamp(),
      }).timeout(const Duration(seconds: 10));

      // Update cache
      final cacheKey = 'combined_${_selectedDate.millisecondsSinceEpoch}';
      if (_habitsCache.containsKey(cacheKey)) {
        final cachedHabits = _habitsCache[cacheKey]!;
        final habitIndex = cachedHabits.indexWhere((h) => h['id'] == habitId);
        if (habitIndex != -1) {
          cachedHabits[habitIndex] = activity;
        }
      }

      // Check if target is reached and show celebration
      if (isCompleted && !activity['completed']) {
        activity['completed'] = true;
        HapticFeedback.heavyImpact(); // Celebration haptic
        _showTargetReachedDialog(activity);
      }
    } on FirebaseException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Firebase error: ${e.message ?? 'Unknown error'}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } on TimeoutException catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Update timed out. Please check your connection.'),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update: ${e.toString()}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _showTargetReachedDialog(Map<String, dynamic> activity) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white.withOpacity(0.95),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.celebration, color: activity['color'], size: 32),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Amazing Work!',
                style: TextStyle(
                  color: Colors.black87,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'You\'ve completed your ${activity['name']} goal for today!',
              style: const TextStyle(
                color: Colors.black87,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: activity['color'].withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: activity['color'].withOpacity(0.3)),
              ),
              child: Text(
                '${activity['current']}/${activity['target']} ✓',
                style: TextStyle(
                  color: activity['color'],
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Keep up the great spiritual journey!',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
                fontStyle: FontStyle.italic,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            style: TextButton.styleFrom(
              backgroundColor: activity['color'].withOpacity(0.1),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(
              'Continue',
              style: TextStyle(
                color: activity['color'],
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ],
        actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
      ),
    );
  }

  String _getActivityProgress(Map<String, dynamic> activity) {
    final current = activity['current'];
    final target = activity['target'];
    final type = activity['type'];
    final unit = activity['unit'] ?? '';

    switch (type) {
      case 'count':
        return '$current/$target';
      case 'duration':
        return '$current/$target $unit';
      case 'steps':
        return '$current/$target $unit';
      default:
        return '$current/$target';
    }
  }

  String _getOverallProgressText() {
    if (_userHabits.isEmpty) return 'NO HABITS';

    final completedCount = _userHabits
        .where((habit) => habit['current'] >= habit['target'])
        .length;

    return '$completedCount/${_userHabits.length} COMPLETED';
  }

  double _getOverallProgress() {
    if (_userHabits.isEmpty) return 0.0;

    double totalProgress = 0.0;
    for (final habit in _userHabits) {
      final progress = (habit['current'] / habit['target']).clamp(0.0, 1.0);
      totalProgress += progress;
    }

    return totalProgress / _userHabits.length;
  }

  Widget _buildLoadingState(bool isLargeScreen) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 48,
                height: 48,
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                  strokeWidth: 3,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Loading your habits...',
                style: AppTextStyles.subheadline.copyWith(
                  color: isDark
                      ? AppColors.textPrimaryDark
                      : AppColors.textPrimaryLight,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState(bool isLargeScreen) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.screenPadding),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: AppColors.error.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppBorderRadius.card),
                  ),
                  child: Icon(
                    _isConnected ? Icons.error_outline : Icons.wifi_off,
                    size: 40,
                    color: AppColors.error,
                  ),
                ),
                const SizedBox(height: AppSpacing.sectionSpacing),
                Text(
                  _isConnected
                      ? 'Something went wrong'
                      : 'No Internet Connection',
                  style: AppTextStyles.headline.copyWith(
                    color: isDark
                        ? AppColors.textPrimaryDark
                        : AppColors.textPrimaryLight,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  _error ??
                      'An unexpected error occurred while loading your habits',
                  style: AppTextStyles.body.copyWith(
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.sectionSpacing),
                ElevatedButton(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    setState(() {
                      _error = null;
                    });
                    _loadUserHabits();
                  },
                  child: const Text('Try Again'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
