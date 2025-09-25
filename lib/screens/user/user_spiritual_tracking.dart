import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../widgets/drag_lock.dart';
import 'package:glassmorphism/glassmorphism.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../utils/habit_period_utils.dart';

class UserSpiritualTracking extends StatefulWidget {
  const UserSpiritualTracking({super.key});

  @override
  State<UserSpiritualTracking> createState() => _UserSpiritualTrackingState();
}

class _UserSpiritualTrackingState extends State<UserSpiritualTracking> with WidgetsBindingObserver {
  DateTime _selectedDate = DateTime.now();
  List<Map<String, dynamic>> _userHabits = [];
  bool _isLoading = true;
  String? _error;
  bool _isConnected = true;
  
  // For super fast drag tracking
  bool _isDragging = false;
  DateTime? _dragStartTime;
  int? _currentDragActivity;
  
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
        _isConnected = true; // Assume connected, will be checked during Firebase operations
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
      final weeklyKey = HabitPeriodUtils.generateDateKey(_selectedDate, 'Weekly');
      final monthlyKey = HabitPeriodUtils.generateDateKey(_selectedDate, 'Monthly');
      
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
            'target': data['target'] ?? data['goal'] ?? 1, // Handle both field names
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
      case 'mosque': return Icons.mosque;
      case 'menu_book': return Icons.menu_book;
      case 'favorite': return Icons.favorite;
      case 'pan_tool': return Icons.pan_tool;
      case 'volunteer_activism': return Icons.volunteer_activism;
      case 'self_improvement': return Icons.self_improvement;
      case 'no_food': return Icons.no_food;
      case 'nightlight': return Icons.nightlight;
      case 'psychology': return Icons.psychology;
      case 'school': return Icons.school;
      case 'fitness_center': return Icons.fitness_center;
      case 'directions_walk': return Icons.directions_walk;
      case 'restaurant': return Icons.restaurant;
      case 'bedtime': return Icons.bedtime;
      default: return Icons.mosque;
    }
  }

  Color _getColorFromName(String colorName) {
    switch (colorName) {
      case 'green': return Colors.green;
      case 'blue': return Colors.blue;
      case 'purple': return Colors.purple;
      case 'orange': return Colors.orange;
      case 'red': return Colors.red;
      case 'teal': return Colors.teal;
      case 'amber': return Colors.amber;
      case 'indigo': return Colors.indigo;
      case 'cyan': return Colors.cyan;
      case 'brown': return Colors.brown;
      default: return Colors.green;
    }
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

    return DragLock.listen(
      context: context,
      builder: (context, locked) {
        return Scaffold(
          backgroundColor: Colors.transparent,
          body: GestureDetector(
            // When locked, capture horizontal gestures ONLY from empty areas
            onHorizontalDragStart: locked ? (_) {
              // Block horizontal drag when card is being dragged
            } : null,
            onHorizontalDragUpdate: locked ? (_) {
              // Block horizontal drag when card is being dragged
            } : null,
            // Only intercept when locked, otherwise let everything pass through
            behavior: locked ? HitTestBehavior.translucent : HitTestBehavior.deferToChild,
            child: SafeArea(
              child: Column(
            children: [
              // Date navigation (moved up with less top padding)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Semantics(
                      label: 'Previous day',
                      child: Material(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () {
                            HapticFeedback.lightImpact();
                            _changeDate(-1);
                          },
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            constraints: const BoxConstraints(
                              minWidth: 44,
                              minHeight: 44,
                            ),
                            child: const Icon(Icons.chevron_left, color: Colors.white, size: 28),
                          ),
                        ),
                      ),
                    ),
                    Semantics(
                      label: 'Select date',
                      child: Material(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(20),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: () {
                            HapticFeedback.lightImpact();
                            _showDatePicker();
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            constraints: const BoxConstraints(
                              minHeight: 44,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.white.withOpacity(0.3)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.calendar_today, color: Colors.white, size: 16),
                                const SizedBox(width: 8),
                                Text(
                                  DateFormat('EEEE, MMM d').format(_selectedDate),
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    Semantics(
                      label: 'Next day',
                      child: Material(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () {
                            HapticFeedback.lightImpact();
                            _changeDate(1);
                          },
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            constraints: const BoxConstraints(
                              minWidth: 44,
                              minHeight: 44,
                            ),
                            child: const Icon(Icons.chevron_right, color: Colors.white, size: 28),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Progress indicator (moved up)
              Container(
                margin: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                child: Column(
                  children: [
                    Text(
                      _getOverallProgressText(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 10),
                    LinearProgressIndicator(
                      value: _getOverallProgress(),
                      backgroundColor: Colors.white.withOpacity(0.3),
                      valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 10),

              // Activities grid or empty state (more space utilized)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(left: 20, right: 20, bottom: 100),
                  child: _userHabits.isEmpty 
                    ? _buildEmptyState()
                    : DragLock.listen(
                        context: context,
                        builder: (context, locked) {
                          return GridView.builder(
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              childAspectRatio: 1.1, // Smaller, more square cards
                              crossAxisSpacing: 16,
                              mainAxisSpacing: 16,
                            ),
                            itemCount: _userHabits.length,
                            physics: locked 
                                ? const NeverScrollableScrollPhysics()
                                : const BouncingScrollPhysics(),
                            itemBuilder: (context, index) {
                              return _buildCircularActivityCard(_userHabits[index]);
                            },
                          );
                        },
                      ),
                ),
              ),
              ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.add_circle_outline,
            size: 80,
            color: Colors.white.withOpacity(0.6),
          ),
          const SizedBox(height: 20),
          Text(
            'No habits yet',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white.withOpacity(0.8),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Tap the + button to add your first spiritual habit',
            style: TextStyle(
              fontSize: 16,
              color: Colors.white.withOpacity(0.6),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildCircularActivityCard(Map<String, dynamic> activity) {
    final double progress = activity['current'] / activity['target'];
    final bool isBeingDragged = _isDragging && _currentDragActivity == _userHabits.indexOf(activity);
    final bool isCompleted = activity['current'] >= activity['target'];
    
    final lock = DragLock.of(context);
    
    return Semantics(
      label: '${activity['name']} habit. Progress: ${activity['current']} of ${activity['target']}. ${isCompleted ? 'Completed' : 'In progress'}',
      hint: 'Drag to increase progress',
      child: AbsorbPointer(
        // BYPASS GLOBAL BLOCKING - Cards should always work
        absorbing: false, // Never absorb, let cards work freely
        child: Listener(
          // DRAGLOCK SYSTEM - Lock/unlock global scrolling
          onPointerDown: (_) {
            lock.lock();
          },
          onPointerUp: (_) {
            lock.unlock();
          },
          onPointerCancel: (_) {
            lock.unlock();
          },
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanStart: (details) {
              _handleDragStart(details, activity);
            },
            onPanUpdate: (details) => _handleDragProgress(activity, details),
            onPanEnd: (details) {
              _handleDragEnd(activity);
            },
            child: AnimatedScale(
              scale: isBeingDragged ? 1.05 : 1.0, // Slight scale up when dragging
              duration: const Duration(milliseconds: 100),
              child: GlassmorphicContainer(
                width: double.infinity,
                height: double.infinity,
                borderRadius: 20,
                blur: 15,
                border: 1.5,
                linearGradient: LinearGradient(
                  colors: [
                    Colors.white.withOpacity(0.1),
                    Colors.white.withOpacity(0.05),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderGradient: LinearGradient(
                  colors: [
                    Colors.white.withOpacity(0.2),
                    Colors.white.withOpacity(0.1),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                child: Container(
                  width: double.infinity,
                  height: double.infinity,
                  padding: const EdgeInsets.all(20), // Reduced padding for smaller cards
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Large Circular Progress (takes most of the card space)
                      Expanded(
                        flex: 3,
                        child: AspectRatio(
                          aspectRatio: 1.0,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // Background circle
                              Container(
                              width: double.infinity,
                              height: double.infinity,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withOpacity(0.1),
                              ),
                            ),
                            // Progress circle (thick stroke for visibility)
                            SizedBox(
                              width: double.infinity,
                              height: double.infinity,
                              child: CircularProgressIndicator(
                                value: progress.clamp(0.0, 1.0),
                                strokeWidth: 8, // Much thicker stroke
                                backgroundColor: Colors.white.withOpacity(0.2),
                                valueColor: AlwaysStoppedAnimation<Color>(activity['color']),
                                strokeCap: StrokeCap.round, // Rounded ends
                              ),
                            ),
                            // Large icon in center
                            Container(
                              width: 70,
                              height: 70,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: activity['color'].withOpacity(0.2),
                                border: Border.all(
                                  color: activity['color'].withOpacity(0.3),
                                  width: 2,
                                ),
                              ),
                              child: Icon(
                                activity['icon'],
                                color: Colors.white,
                                size: 40, // Much larger icon
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    // Text section (fixed height to prevent overflow)
                    SizedBox(
                      height: 50, // Fixed height
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Activity name
                          Text(
                            activity['name'],
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          
                          const SizedBox(height: 2),
                          
                          // Progress text
                          Text(
                            _getActivityProgress(activity),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: activity['color'],
                            ),
                            textAlign: TextAlign.center,
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
    ));
  }

  void _handleDragStart(DragStartDetails details, Map<String, dynamic> activity) {
    _isDragging = true;
    _dragStartTime = DateTime.now();
    
    // Store the specific activity being dragged
    _currentDragActivity = _userHabits.indexOf(activity);
  }

  void _handleDragProgress(Map<String, dynamic> activity, DragUpdateDetails details) {
    if (!_isDragging || _dragStartTime == null) return;
    
    // Calculate drag velocity and time
    final now = DateTime.now();
    final dragDuration = now.difference(_dragStartTime!).inMilliseconds;
    final dragDelta = details.delta;
    
    // Calculate movement (any direction counts as progress)
    final movement = (dragDelta.dx.abs() + dragDelta.dy.abs());
    
    // CONTROLLED FAST SYSTEM: More reasonable speed progression
    double speedMultiplier = 1.0;
    
    if (dragDuration > 800) {
      // After 0.8 seconds, start accelerating gradually
      speedMultiplier = 1.0 + (dragDuration - 800) / 1000; // Gradual increase
    }
    
    if (dragDuration > 1500) {
      // After 1.5 seconds, faster but controlled
      speedMultiplier = 2.0 + (dragDuration - 1500) / 2000; // Max ~5x speed
    }
    
    // Limit maximum speed to prevent going too crazy
    speedMultiplier = speedMultiplier.clamp(1.0, 6.0);
    
    // Base increment per movement (reduced from 0.5 to 0.2)
    final baseIncrement = movement * 0.2;
    final totalIncrement = baseIncrement * speedMultiplier;
    
    if (totalIncrement > 0.1) {
      final int currentValue = activity['current'];
      final int targetValue = activity['target'];
      final int newValue = (currentValue + totalIncrement).clamp(0, targetValue).round();
      
      if (newValue != currentValue) {
        setState(() {
          activity['current'] = newValue;
        });
        
        // Haptic feedback only occasionally to avoid spam
        if (newValue % 5 == 0) {
          _triggerHapticFeedback();
        }
      }
    }
  }

  void _handleDragEnd(Map<String, dynamic> activity) {
    _isDragging = false;
    _dragStartTime = null;
    _currentDragActivity = null;
    
    _updateActivityInFirebase(activity);
  }

  void _triggerHapticFeedback() {
    // Light haptic feedback for smooth UX
    HapticFeedback.lightImpact();
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
      final dateKey = HabitPeriodUtils.generateDateKey(_selectedDate, goalPeriod);
      
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
    
    final completedCount = _userHabits.where((habit) => 
      habit['current'] >= habit['target']).length;
    
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
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          children: [
            // Loading skeleton for date navigation
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  Container(
                    width: 200,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ],
              ),
            ),
            
            // Loading skeleton for progress bar
            Container(
              margin: const EdgeInsets.fromLTRB(20, 0, 20, 10),
              child: Column(
                children: [
                  Container(
                    width: 150,
                    height: 16,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Loading indicator
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Loading habits...',
                      style: TextStyle(
                        fontSize: isLargeScreen ? 18 : 16,
                        color: Colors.white.withOpacity(0.8),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(bool isLargeScreen) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _isConnected ? Icons.error_outline : Icons.wifi_off,
                  size: isLargeScreen ? 80 : 64,
                  color: Colors.white.withOpacity(0.8),
                ),
                const SizedBox(height: 24),
                Text(
                  _isConnected ? 'Something went wrong' : 'No Internet Connection',
                  style: TextStyle(
                    fontSize: isLargeScreen ? 24 : 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  _error ?? 'An unexpected error occurred',
                  style: TextStyle(
                    fontSize: isLargeScreen ? 16 : 14,
                    color: Colors.white.withOpacity(0.9),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                Semantics(
                  label: 'Try again',
                  child: ElevatedButton.icon(
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      setState(() {
                        _error = null;
                      });
                      _loadUserHabits();
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('Try Again'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white.withOpacity(0.2),
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(
                        horizontal: isLargeScreen ? 32 : 24,
                        vertical: isLargeScreen ? 16 : 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}