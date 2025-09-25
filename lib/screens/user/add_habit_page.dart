import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'create_custom_habit_page.dart';

class AddHabitPage extends StatefulWidget {
  const AddHabitPage({super.key});

  @override
  State<AddHabitPage> createState() => _AddHabitPageState();
}

class _AddHabitPageState extends State<AddHabitPage> with WidgetsBindingObserver, TickerProviderStateMixin {
  String _selectedCategory = 'Popular';
  String? _loadingHabitName; // Track which habit is loading instead of global loading
  String? _error;
  
  // Success message timer and animation state
  Timer? _successMessageTimer;
  bool _showSuccessMessage = false;
  int _countdown = 5;
  double _progressValue = 1.0;
  String _successMessage = '';
  
  // Animation controller for slide out effect
  late AnimationController _slideAnimationController;
  late Animation<Offset> _slideAnimation;
  
  final Map<String, List<Map<String, dynamic>>> _habitCategories = {
    'Popular': [
      {'name': 'Prayer (Salah)', 'category': 'islamic', 'icon': Icons.mosque, 'color': const Color(0xFF2E7D32)},
      {'name': 'Quran Reading', 'category': 'islamic', 'icon': Icons.menu_book, 'color': const Color(0xFF1565C0)},
      {'name': 'Morning Dhikr', 'category': 'islamic', 'icon': Icons.wb_sunny, 'color': const Color(0xFFFF8F00)},
      {'name': 'Evening Dhikr', 'category': 'islamic', 'icon': Icons.nightlight_round, 'color': const Color(0xFF5E35B1)},
      {'name': 'Istighfar', 'category': 'islamic', 'icon': Icons.favorite, 'color': const Color(0xFFD32F2F)},
      {'name': 'Water Intake', 'category': 'health', 'icon': Icons.local_drink, 'color': const Color(0xFF0288D1)},
    ],
    'Islamic': [
      {'name': 'Fajr Prayer', 'category': 'islamic', 'icon': Icons.wb_twilight, 'color': const Color(0xFF37474F)},
      {'name': 'Tahajjud', 'category': 'islamic', 'icon': Icons.nights_stay, 'color': const Color(0xFF283593)},
      {'name': 'Quran Memorization', 'category': 'islamic', 'icon': Icons.psychology, 'color': const Color(0xFF00695C)},
      {'name': 'Islamic Study', 'category': 'islamic', 'icon': Icons.school, 'color': const Color(0xFF5D4037)},
      {'name': 'Sadaqah/Charity', 'category': 'islamic', 'icon': Icons.volunteer_activism, 'color': const Color(0xFFE65100)},
      {'name': 'Dua Making', 'category': 'islamic', 'icon': Icons.pan_tool, 'color': const Color(0xFF6A1B9A)},
      {'name': 'Sunnah Fasting', 'category': 'islamic', 'icon': Icons.no_food, 'color': const Color(0xFF795548)},
      {'name': 'Seeking Knowledge', 'category': 'islamic', 'icon': Icons.library_books, 'color': const Color(0xFF1976D2)},
      {'name': 'Salawat/Durood', 'category': 'islamic', 'icon': Icons.auto_awesome, 'color': const Color(0xFF388E3C)},
    ],
    'Health': [
      {'name': 'Morning Exercise', 'category': 'health', 'icon': Icons.fitness_center, 'color': const Color(0xFFD32F2F)},
      {'name': 'Daily Walk', 'category': 'health', 'icon': Icons.directions_walk, 'color': const Color(0xFF388E3C)},
      {'name': 'Healthy Breakfast', 'category': 'health', 'icon': Icons.breakfast_dining, 'color': const Color(0xFFFF8F00)},
      {'name': 'Early Sleep', 'category': 'health', 'icon': Icons.bedtime, 'color': const Color(0xFF5E35B1)},
      {'name': 'Meditation', 'category': 'health', 'icon': Icons.self_improvement, 'color': const Color(0xFF00695C)},
      {'name': 'Stretching', 'category': 'health', 'icon': Icons.accessibility_new, 'color': const Color(0xFF1976D2)},
      {'name': 'Deep Breathing', 'category': 'health', 'icon': Icons.air, 'color': const Color(0xFF0288D1)},
    ],
    'Personal': [
      {'name': 'Reading Books', 'category': 'personal', 'icon': Icons.import_contacts, 'color': const Color(0xFF5D4037)},
      {'name': 'Learning Arabic', 'category': 'personal', 'icon': Icons.translate, 'color': const Color(0xFF1565C0)},
      {'name': 'Journaling', 'category': 'personal', 'icon': Icons.edit_note, 'color': const Color(0xFF6A1B9A)},
      {'name': 'Goal Setting', 'category': 'personal', 'icon': Icons.track_changes, 'color': const Color(0xFFE65100)},
      {'name': 'Skill Practice', 'category': 'personal', 'icon': Icons.psychology_alt, 'color': const Color(0xFF2E7D32)},
      {'name': 'Time Management', 'category': 'personal', 'icon': Icons.schedule, 'color': const Color(0xFF37474F)},
    ],
    'Family': [
      {'name': 'Family Time', 'category': 'family', 'icon': Icons.family_restroom, 'color': const Color(0xFFD32F2F)},
      {'name': 'Call Parents', 'category': 'family', 'icon': Icons.call, 'color': const Color(0xFF388E3C)},
      {'name': 'Help with Chores', 'category': 'family', 'icon': Icons.cleaning_services, 'color': const Color(0xFF1976D2)},
      {'name': 'Family Dua', 'category': 'family', 'icon': Icons.groups, 'color': const Color(0xFF5E35B1)},
      {'name': 'Teaching Kids', 'category': 'family', 'icon': Icons.school, 'color': const Color(0xFF00695C)},
      {'name': 'Family Meal', 'category': 'family', 'icon': Icons.restaurant, 'color': const Color(0xFFFF8F00)},
    ],
    'Community': [
      {'name': 'Mosque Visit', 'category': 'community', 'icon': Icons.location_city, 'color': const Color(0xFF2E7D32)},
      {'name': 'Help Neighbor', 'category': 'community', 'icon': Icons.handshake, 'color': const Color(0xFF1565C0)},
      {'name': 'Volunteer Work', 'category': 'community', 'icon': Icons.volunteer_activism, 'color': const Color(0xFFE65100)},
      {'name': 'Community Service', 'category': 'community', 'icon': Icons.groups_2, 'color': const Color(0xFF6A1B9A)},
      {'name': 'Islamic Circle', 'category': 'community', 'icon': Icons.group, 'color': const Color(0xFF37474F)},
      {'name': 'Da\'wah Activity', 'category': 'community', 'icon': Icons.campaign, 'color': const Color(0xFF5D4037)},
    ],
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    // Initialize slide animation controller
    _slideAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.0, 0.0),
      end: const Offset(0.0, -1.0),
    ).animate(CurvedAnimation(
      parent: _slideAnimationController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _successMessageTimer?.cancel();
    _slideAnimationController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Refresh data if needed
      setState(() {
        _error = null;
      });
    }
  }

  // Show success message with timer and animation
  void _showSuccessMessageWithTimer(String message) {
    setState(() {
      _successMessage = message;
      _showSuccessMessage = true;
      _countdown = 5;
      _progressValue = 1.0;
    });

    // Reset slide animation to start position
    _slideAnimationController.reset();

    _successMessageTimer?.cancel();
    _successMessageTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      setState(() {
        _progressValue -= 0.02; // 100ms * 50 = 5000ms = 5 seconds
        _countdown = (_progressValue * 5).ceil(); // Real-time countdown from progress
        
        if (_progressValue <= 0) {
          timer.cancel();
          // Start slide down animation
          _slideAnimationController.forward().then((_) {
            setState(() {
              _showSuccessMessage = false;
              _successMessage = '';
            });
          });
        }
      });
    });
  }

  // Clear success message when user interacts
  void _clearSuccessMessage() {
    if (_showSuccessMessage) {
      _successMessageTimer?.cancel();
      // Start slide down animation for manual clear too
      _slideAnimationController.forward().then((_) {
        setState(() {
          _showSuccessMessage = false;
          _successMessage = '';
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final isLargeScreen = mediaQuery.size.width > 600;
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF42A5F5), Color(0xFF64B5F6), Color(0xFF90CAF9)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          stops: [0.0, 0.5, 1.0],
        ),
      ),
      child: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
            // Header
            Padding(
              padding: EdgeInsets.all(isLargeScreen ? 24 : 20),
              child: Row(
                children: [
                  Semantics(
                    label: 'Go back',
                    child: Material(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () {
                          HapticFeedback.lightImpact();
                          context.go('/unifiedDashboard');
                        },
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          constraints: const BoxConstraints(
                            minWidth: 44,
                            minHeight: 44,
                          ),
                          child: Icon(
                            Icons.arrow_back, 
                            color: Colors.white, 
                            size: isLargeScreen ? 32 : 28,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      'Add New Habit',
                      style: TextStyle(
                        fontSize: isLargeScreen ? 28 : 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  SizedBox(width: isLargeScreen ? 56 : 48), // Balance the back button
                ],
              ),
            ),
            
            // Category tabs
            Container(
              height: isLargeScreen ? 60 : 50,
              margin: EdgeInsets.symmetric(horizontal: isLargeScreen ? 24 : 20),
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: _habitCategories.keys.map((category) {
                  final isSelected = _selectedCategory == category;
                  return Semantics(
                    label: '$category category${isSelected ? ', selected' : ''}',
                    child: Material(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(25),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(25),
                        onTap: () {
                          HapticFeedback.selectionClick();
                          _clearSuccessMessage(); // Clear success message when changing category
                          setState(() => _selectedCategory = category);
                        },
                        child: Container(
                          margin: const EdgeInsets.only(right: 12),
                          padding: EdgeInsets.symmetric(
                            horizontal: isLargeScreen ? 28 : 24, 
                            vertical: isLargeScreen ? 16 : 12,
                          ),
                          constraints: const BoxConstraints(
                            minHeight: 44,
                          ),
                          decoration: BoxDecoration(
                            gradient: isSelected
                              ? const LinearGradient(
                                  colors: [Color(0xFFFFFFFF), Color(0xFFF8F9FA)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                )
                              : LinearGradient(
                                  colors: [
                                    Colors.white.withOpacity(0.15),
                                    Colors.white.withOpacity(0.08),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                            borderRadius: BorderRadius.circular(25),
                            border: Border.all(
                              color: isSelected 
                                ? Colors.white.withOpacity(0.8)
                                : Colors.white.withOpacity(0.3),
                              width: isSelected ? 2 : 1,
                            ),
                            boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: Colors.white.withOpacity(0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : null,
                          ),
                          child: Center(
                            child: Text(
                              category,
                              style: TextStyle(
                                color: isSelected 
                                  ? const Color(0xFF1A237E)
                                  : Colors.white,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                fontSize: isLargeScreen ? 18 : 16,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            
            SizedBox(height: isLargeScreen ? 24 : 20),
            
            // Error display
            if (_error != null) ...[
              Container(
                margin: EdgeInsets.symmetric(horizontal: isLargeScreen ? 24 : 20),
                padding: EdgeInsets.all(isLargeScreen ? 16 : 12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(isLargeScreen ? 16 : 12),
                  border: Border.all(
                    color: Colors.red.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.error_outline,
                      color: Colors.red.shade700,
                      size: isLargeScreen ? 24 : 20,
                    ),
                    SizedBox(width: isLargeScreen ? 12 : 8),
                    Expanded(
                      child: Text(
                        _error!,
                        style: TextStyle(
                          color: Colors.red.shade700,
                          fontSize: isLargeScreen ? 16 : 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Semantics(
                      label: 'Dismiss error',
                      child: Material(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(16),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () {
                            setState(() {
                              _error = null;
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            constraints: const BoxConstraints(
                              minWidth: 32,
                              minHeight: 32,
                            ),
                            child: Icon(
                              Icons.close,
                              color: Colors.red.shade700,
                              size: isLargeScreen ? 20 : 16,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: isLargeScreen ? 16 : 12),
            ],
            
            // Habits list - Takes remaining space
            Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: isLargeScreen ? 24 : 20),
                child: ListView.builder(
                  padding: EdgeInsets.zero, // No padding needed
                  itemCount: _habitCategories[_selectedCategory]!.length,
                  physics: const BouncingScrollPhysics(),
                  cacheExtent: 200,
                  itemBuilder: (context, index) {
                    final habit = _habitCategories[_selectedCategory]![index];
                    return _buildHabitItem(habit, isLargeScreen);
                  },
                ),
              ),
            ),
            
            // Custom Button - Fixed at bottom, no overlap
            Container(
              padding: EdgeInsets.fromLTRB(
                isLargeScreen ? 24 : 20,
                isLargeScreen ? 20 : 16,
                isLargeScreen ? 24 : 20,
                isLargeScreen ? 24 : 20,
              ),
              child: _buildCustomButton(isLargeScreen),
            ),
              ],
            ),
            
            // Success message popup
            if (_showSuccessMessage)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: _buildSuccessMessage(isLargeScreen),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // Build success message popup
  Widget _buildSuccessMessage(bool isLargeScreen) {
    return Container(
      margin: EdgeInsets.all(isLargeScreen ? 20 : 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF4CAF50), Color(0xFF45A049)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(isLargeScreen ? 16 : 12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(isLargeScreen ? 16 : 12),
        child: InkWell(
          borderRadius: BorderRadius.circular(isLargeScreen ? 16 : 12),
          onTap: _clearSuccessMessage,
          child: Padding(
            padding: EdgeInsets.all(isLargeScreen ? 20 : 16),
            child: Row(
              children: [
                Icon(
                  Icons.check_circle,
                  color: Colors.white,
                  size: isLargeScreen ? 28 : 24,
                ),
                SizedBox(width: isLargeScreen ? 16 : 12),
                Expanded(
                  child: Text(
                    _successMessage,
                    style: TextStyle(
                      fontSize: isLargeScreen ? 16 : 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
                SizedBox(width: isLargeScreen ? 16 : 12),
                // Circular progress with countdown
                SizedBox(
                  width: isLargeScreen ? 44 : 40,
                  height: isLargeScreen ? 44 : 40,
                  child: Stack(
                    children: [
                      CircularProgressIndicator(
                        value: _progressValue,
                        strokeWidth: 3,
                        backgroundColor: Colors.white.withOpacity(0.3),
                        valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: Center(
                          child: Transform.translate(
                            offset: const Offset(-2, -2), // Hafif sola ve yukarı kaydır
                            child: Text(
                              '$_countdown',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: isLargeScreen ? 16 : 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
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
    );
  }

  Widget _buildHabitItem(Map<String, dynamic> habit, bool isLargeScreen) {
    return Semantics(
      label: 'Add ${habit['name']} habit from ${habit['category']} category',
      child: Container(
        margin: EdgeInsets.only(bottom: isLargeScreen ? 16 : 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.white.withOpacity(0.25),
              Colors.white.withOpacity(0.15),
              Colors.white.withOpacity(0.08),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            stops: const [0.0, 0.5, 1.0],
          ),
          borderRadius: BorderRadius.circular(isLargeScreen ? 20 : 16),
          border: Border.all(
            color: Colors.white.withOpacity(0.3),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
            BoxShadow(
              color: Colors.white.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(isLargeScreen ? 20 : 16),
          child: InkWell(
            borderRadius: BorderRadius.circular(isLargeScreen ? 20 : 16),
            onTap: _loadingHabitName != null ? null : () {
              HapticFeedback.lightImpact();
              _addHabit(habit);
            },
            child: Padding(
              padding: EdgeInsets.all(isLargeScreen ? 20 : 16),
              child: Row(
                children: [
                  // Enhanced Icon
                  Container(
                    width: isLargeScreen ? 56 : 48,
                    height: isLargeScreen ? 56 : 48,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          habit['color'].withOpacity(0.3),
                          habit['color'].withOpacity(0.1),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(isLargeScreen ? 16 : 14),
                      border: Border.all(
                        color: habit['color'].withOpacity(0.4),
                        width: 1,
                      ),
                    ),
                    child: Icon(
                      habit['icon'],
                      color: habit['color'],
                      size: isLargeScreen ? 30 : 26,
                    ),
                  ),
                  
                  SizedBox(width: isLargeScreen ? 20 : 16),
                  
                  // Enhanced Text
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          habit['name'],
                          style: TextStyle(
                            fontSize: isLargeScreen ? 18 : 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                            letterSpacing: 0.3,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: isLargeScreen ? 6 : 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: habit['color'].withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: habit['color'].withOpacity(0.3),
                              width: 0.5,
                            ),
                          ),
                          child: Text(
                            habit['category'].toString().toUpperCase(),
                            style: TextStyle(
                              fontSize: isLargeScreen ? 11 : 9,
                              color: habit['color'],
                              letterSpacing: 0.8,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  SizedBox(width: isLargeScreen ? 16 : 12),
                  
                  // Enhanced Add button
                  Container(
                    width: isLargeScreen ? 48 : 40,
                    height: isLargeScreen ? 48 : 40,
                    constraints: const BoxConstraints(
                      minWidth: 44,
                      minHeight: 44,
                    ),
                    decoration: BoxDecoration(
                      gradient: _loadingHabitName == habit['name']
                        ? LinearGradient(
                            colors: [
                              Colors.white.withOpacity(0.1),
                              Colors.white.withOpacity(0.05),
                            ],
                          )
                        : const LinearGradient(
                            colors: [Color(0xFFFFFFFF), Color(0xFFF8F9FA)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                      borderRadius: BorderRadius.circular(isLargeScreen ? 16 : 14),
                      border: Border.all(
                        color: _loadingHabitName == habit['name']
                          ? Colors.white.withOpacity(0.2)
                          : Colors.white.withOpacity(0.8),
                        width: 1.5,
                      ),
                      boxShadow: _loadingHabitName == habit['name']
                        ? null
                        : [
                            BoxShadow(
                              color: Colors.white.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                    ),
                    child: _loadingHabitName == habit['name']
                      ? Center(
                          child: SizedBox(
                            width: isLargeScreen ? 20 : 16,
                            height: isLargeScreen ? 20 : 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white.withOpacity(0.7),
                              ),
                            ),
                          ),
                        )
                      : Icon(
                          Icons.add_rounded,
                          color: const Color(0xFF1A237E),
                          size: isLargeScreen ? 28 : 24,
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

  Widget _buildCustomButton(bool isLargeScreen) {
    return Semantics(
      label: 'Create custom habit',
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(isLargeScreen ? 18 : 16),
        child: InkWell(
          borderRadius: BorderRadius.circular(isLargeScreen ? 18 : 16),
          onTap: () {
            HapticFeedback.lightImpact();
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const CreateCustomHabitPage(),
              ),
            );
          },
          child: Container(
            width: double.infinity,
            height: isLargeScreen ? 70 : 60,
            constraints: const BoxConstraints(
              minHeight: 44,
            ),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFFFFFF), Color(0xFFF8F9FA), Color(0xFFE3F2FD)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                stops: [0.0, 0.5, 1.0],
              ),
              borderRadius: BorderRadius.circular(isLargeScreen ? 20 : 18),
              border: Border.all(
                color: Colors.white.withOpacity(0.8),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.white.withOpacity(0.4),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    'Create Custom Habit',
                    style: TextStyle(
                      color: const Color(0xFF1A237E),
                      fontSize: isLargeScreen ? 18 : 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
                SizedBox(width: isLargeScreen ? 12 : 8),
                Container(
                  padding: EdgeInsets.all(isLargeScreen ? 8 : 6),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF1A237E).withOpacity(0.1),
                        const Color(0xFF3949AB).withOpacity(0.05),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(isLargeScreen ? 12 : 10),
                    border: Border.all(
                      color: const Color(0xFF1A237E).withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: Icon(
                    Icons.add_circle_outline_rounded,
                    color: const Color(0xFF1A237E),
                    size: isLargeScreen ? 22 : 20,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _addHabit(Map<String, dynamic> habit) async {
    if (_loadingHabitName != null) return; // Prevent multiple simultaneous requests
    
    setState(() {
      _loadingHabitName = habit['name'];
      _error = null;
    });

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      // Simulate network connectivity check (basic implementation)
      await _checkNetworkConnectivity();

      // Create document ID from habit name (URL safe)
      final habitId = habit['name'].toString().toLowerCase()
          .replaceAll(' ', '-')
          .replaceAll(RegExp(r'[^a-z0-9\-]'), '');
      
      final today = DateTime.now();
      final dateKey = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
      
      // Check if habit already exists for today with shorter timeout
      final existingHabit = await FirebaseFirestore.instance
          .collection('habits')
          .doc(currentUser.uid)
          .collection(dateKey)
          .doc(habitId)
          .get()
          .timeout(
            const Duration(seconds: 3),
            onTimeout: () => throw TimeoutException('Connection timeout', const Duration(seconds: 3)),
          );

      if (existingHabit.exists) {
        throw Exception('${habit['name']} already exists for today!');
      }

      // Create habit data (optimized structure)
      final habitData = {
        'name': habit['name'],
        'category': habit['category'],
        'current': 0,
        'target': _getDefaultTarget(habit['name']),
        'completed': false,
        'completedAt': null,
        'type': _getDefaultType(habit['name']),
        'unit': _getDefaultUnit(habit['name']),
        'iconName': _getIconName(habit['icon']),
        'colorName': _getColorName(habit['color']),
        'createdAt': FieldValue.serverTimestamp(),
      };

      // Use batch write for better performance
      final batch = FirebaseFirestore.instance.batch();
      final habitRef = FirebaseFirestore.instance
          .collection('habits')
          .doc(currentUser.uid)
          .collection(dateKey)
          .doc(habitId);
      
      batch.set(habitRef, habitData);
      
      // Commit batch with shorter timeout
      await batch.commit().timeout(
        const Duration(seconds: 3),
        onTimeout: () => throw TimeoutException('Failed to save habit', const Duration(seconds: 3)),
      );

      if (mounted) {
        // Show success popup instead of navigation
        _showSuccessMessageWithTimer('${habit['name']} added successfully!');
      }
    } on TimeoutException catch (e) {
      debugPrint('Timeout error: $e');
      setState(() {
        _error = 'Connection timeout. Please check your internet connection.';
      });
      if (mounted) {
        _showErrorSnackBar('Connection timeout. Please check your internet connection.');
      }
    } on FirebaseException catch (e) {
      debugPrint('Firebase error: ${e.code} - ${e.message}');
      setState(() {
        _error = _getFirebaseErrorMessage(e.code);
      });
      if (mounted) {
        _showErrorSnackBar(_getFirebaseErrorMessage(e.code));
      }
    } catch (e) {
      debugPrint('Error adding habit: $e');
      String errorMessage = e.toString();
      if (errorMessage.contains('already exists')) {
        // Only show warning snackbar, don't set error state
        if (mounted) {
          _showWarningSnackBar(errorMessage.replaceAll('Exception: ', ''));
        }
      } else if (errorMessage.contains('not authenticated')) {
        setState(() {
          _error = 'Please log in to add habits';
        });
        if (mounted) {
          _showErrorSnackBar('Please log in to add habits');
        }
      } else {
        setState(() {
          _error = 'Failed to add habit. Please try again.';
        });
        if (mounted) {
          _showErrorSnackBar('Failed to add habit. Please try again.');
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _loadingHabitName = null;
        });
      }
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.white, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.red.shade600,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 100),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  void _showWarningSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.warning_amber, color: Colors.white, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.orange.shade600,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 100),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  String _getFirebaseErrorMessage(String code) {
    switch (code) {
      case 'permission-denied':
        return 'Permission denied. Please check your account permissions.';
      case 'unavailable':
        return 'Service temporarily unavailable. Please try again later.';
      case 'deadline-exceeded':
        return 'Request timed out. Please try again.';
      case 'resource-exhausted':
        return 'Too many requests. Please wait a moment and try again.';
      case 'unauthenticated':
        return 'Please log in to add habits.';
      default:
        return 'An error occurred. Please try again.';
    }
  }

  Future<void> _checkNetworkConnectivity() async {
    try {
      // Quick network connectivity check with shorter timeout
      await FirebaseAuth.instance.currentUser?.reload().timeout(
        const Duration(seconds: 2),
        onTimeout: () => throw TimeoutException('Network connectivity check failed'),
      );
    } catch (e) {
      throw Exception('No internet connection. Please check your network settings.');
    }
  }

  String _getIconName(IconData icon) {
    if (icon == Icons.mosque) return 'mosque';
    if (icon == Icons.menu_book) return 'menu_book';
    if (icon == Icons.favorite) return 'favorite';
    if (icon == Icons.pan_tool) return 'pan_tool';
    if (icon == Icons.volunteer_activism) return 'volunteer_activism';
    if (icon == Icons.self_improvement) return 'self_improvement';
    if (icon == Icons.no_food) return 'no_food';
    if (icon == Icons.nightlight) return 'nightlight';
    if (icon == Icons.psychology) return 'psychology';
    if (icon == Icons.school) return 'school';
    if (icon == Icons.fitness_center) return 'fitness_center';
    if (icon == Icons.directions_walk) return 'directions_walk';
    if (icon == Icons.restaurant) return 'restaurant';
    if (icon == Icons.bedtime) return 'bedtime';
    return 'mosque';
  }

  String _getColorName(Color color) {
    if (color == Colors.green) return 'green';
    if (color == Colors.blue) return 'blue';
    if (color == Colors.purple) return 'purple';
    if (color == Colors.orange) return 'orange';
    if (color == Colors.red) return 'red';
    if (color == Colors.teal) return 'teal';
    if (color == Colors.amber) return 'amber';
    if (color == Colors.indigo) return 'indigo';
    if (color == Colors.cyan) return 'cyan';
    if (color == Colors.brown) return 'brown';
    return 'green';
  }

  String _getDefaultType(String habitName) {
    if (habitName.contains('Reading') || habitName.contains('Exercise') || 
        habitName.contains('Reflection') || habitName.contains('Study')) {
      return 'duration';
    }
    return 'count';
  }

  int _getDefaultTarget(String habitName) {
    switch (habitName) {
      case 'Prayer (Salah)': return 5;
      case 'Fajr Prayer': return 1;
      case 'Quran Reading': return 30;
      case 'Quran Memorization': return 15;
      case 'Morning Dhikr': return 1;
      case 'Evening Dhikr': return 1;
      case 'Istighfar': return 100;
      case 'Dua Making': return 5;
      case 'Tahajjud': return 1;
      case 'Sadaqah/Charity': return 1;
      case 'Sunnah Fasting': return 1;
      case 'Salawat/Durood': return 100;
      case 'Morning Exercise': return 30;
      case 'Daily Walk': return 30;
      case 'Water Intake': return 8;
      case 'Early Sleep': return 1;
      case 'Meditation': return 10;
      case 'Reading Books': return 30;
      case 'Learning Arabic': return 20;
      case 'Journaling': return 15;
      case 'Family Time': return 60;
      case 'Call Parents': return 1;
      case 'Mosque Visit': return 1;
      case 'Help Neighbor': return 1;
      default: return 1;
    }
  }

  String _getDefaultUnit(String habitName) {
    if (habitName.contains('Reading') || habitName.contains('Exercise') || 
        habitName.contains('Reflection') || habitName.contains('Walking')) {
      return 'min';
    }
    return '';
  }
}
