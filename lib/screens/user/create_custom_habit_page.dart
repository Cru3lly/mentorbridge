import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import '../../../utils/habit_period_utils.dart';
import '../../../services/notification_service.dart';

class CreateCustomHabitPage extends StatefulWidget {
  const CreateCustomHabitPage({super.key});

  @override
  State<CreateCustomHabitPage> createState() => _CreateCustomHabitPageState();
}

class _CreateCustomHabitPageState extends State<CreateCustomHabitPage> with TickerProviderStateMixin {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _goalValueController = TextEditingController();
  final TextEditingController _reminderMessageController = TextEditingController();
  
  // Selected values
  Color _selectedColor = Colors.blue;
  String _habitType = 'Build'; // Build or Quit
  // String _habitCategory = 'Personal'; // Islamic, Health, Personal, Family, Community (for future use)
  String _goalPeriod = 'Daily'; // Daily, Weekly, Monthly
  String _timeRange = 'Anytime'; // Anytime, Morning, Afternoon, Evening
  String _taskDays = 'Every Day'; // Every Day, Weekdays, Weekends, Custom
  String _unit = 'times'; // times, minutes, steps, pages, etc.
  bool _remindersEnabled = true;
  TimeOfDay _reminderTime = const TimeOfDay(hour: 19, minute: 30);
  final DateTime _startDate = DateTime.now();
  DateTime? _endDate;
  
  // Animation and loading states
  bool _isLoading = false;
  bool _hasUnsavedChanges = false;
  bool _isAdvancedSettingsExpanded = false;
  late AnimationController _fadeController;
  late AnimationController _scaleController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  
  // Available options
  final List<Color> _availableColors = [
    // Islamic & Spiritual Colors
    const Color(0xFF2E7D32), // Deep Green (Islamic)
    const Color(0xFF1565C0), // Deep Blue (Quran)
    const Color(0xFF5E35B1), // Purple (Evening)
    const Color(0xFFD32F2F), // Red (Heart/Love)
    const Color(0xFF00695C), // Teal (Wisdom)
    const Color(0xFF37474F), // Dark Grey (Fajr)
    
    // Vibrant Colors
    const Color(0xFFFF8F00), // Amber (Morning)
    const Color(0xFFE65100), // Deep Orange (Energy)
    const Color(0xFF6A1B9A), // Deep Purple (Spirituality)
    const Color(0xFF1976D2), // Blue (Knowledge)
    const Color(0xFF388E3C), // Green (Nature)
    const Color(0xFF795548), // Brown (Earth)
    
    // Modern Colors
    const Color(0xFF0288D1), // Light Blue (Water)
    const Color(0xFFE91E63), // Pink (Compassion)
    const Color(0xFF00BCD4), // Cyan (Clarity)
    const Color(0xFF8BC34A), // Light Green (Growth)
    const Color(0xFFFF5722), // Deep Orange (Passion)
    const Color(0xFF9C27B0), // Purple (Creativity)
    const Color(0xFF607D8B), // Blue Grey (Balance)
    const Color(0xFFFFB300), // Golden (Success)
  ];
  
  final List<String> _availableUnits = [
    // Count-based units
    'times', 'prayers', 'verses', 'dhikr', 'dua', 'chapters',
    'reps', 'sets', 'cycles', 'rounds', 'sessions',
    
    // Time-based units  
    'minutes', 'hours', 'seconds',
    
    // Distance & Movement
    'steps', 'kilometers', 'meters', 'miles',
    
    // Volume & Quantity
    'glasses', 'cups', 'liters', 'pages', 'books', 'articles',
    
    // Health & Fitness
    'calories', 'breaths', 'stretches',
    
    // Learning & Development
    'words', 'lessons', 'exercises', 'tasks', 'goals',
    
    // Islamic specific
    'surahs', 'ayahs', 'tasbeeh', 'istighfar', 'salawat'
  ];
  
  final List<IconData> _availableIcons = [
    // Islamic & Spiritual Icons
    Icons.mosque, Icons.menu_book, Icons.favorite, Icons.pan_tool,
    Icons.volunteer_activism, Icons.self_improvement, Icons.wb_sunny, Icons.nightlight_round,
    Icons.nights_stay, Icons.wb_twilight, Icons.auto_awesome, Icons.psychology,
    
    // Health & Fitness
    Icons.fitness_center, Icons.directions_walk, Icons.accessibility_new, Icons.air,
    Icons.local_drink, Icons.restaurant, Icons.breakfast_dining, Icons.bedtime,
    Icons.spa, Icons.healing, Icons.monitor_heart, Icons.medical_services,
    
    // Learning & Development  
    Icons.school, Icons.library_books, Icons.import_contacts, Icons.translate,
    Icons.edit_note, Icons.track_changes, Icons.psychology_alt, Icons.schedule,
    Icons.lightbulb, Icons.science, Icons.calculate, Icons.language,
    
    // Family & Community
    Icons.family_restroom, Icons.call, Icons.cleaning_services, Icons.groups,
    Icons.handshake, Icons.groups_2, Icons.group, Icons.campaign,
    Icons.location_city, Icons.home, Icons.child_care, Icons.elderly,
    
    // Activities & Hobbies
    Icons.music_note, Icons.brush, Icons.code, Icons.sports,
    Icons.camera_alt, Icons.palette, Icons.theater_comedy, Icons.games,
    Icons.travel_explore, Icons.nature, Icons.pets, Icons.park,
    
    // Work & Productivity
    Icons.work, Icons.business, Icons.laptop, Icons.phone,
    Icons.email, Icons.calendar_today, Icons.task_alt, Icons.timer,
    Icons.trending_up, Icons.analytics, Icons.assessment, Icons.insights,
    
    // General & Popular
    Icons.star, Icons.check_circle, Icons.thumb_up, Icons.emoji_events,
    Icons.diamond, Icons.local_fire_department, Icons.flash_on, Icons.rocket_launch
  ];

  @override
  void initState() {
    super.initState();
    
    // Initialize animation controllers
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    ));
    
    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _scaleController,
      curve: Curves.elasticOut,
    ));
    
    // Add listeners to track form changes
    _nameController.addListener(_markAsChanged);
    _descriptionController.addListener(_markAsChanged);
    _goalValueController.addListener(_markAsChanged);
    _reminderMessageController.addListener(_markAsChanged);
    
    // Start animations
    _fadeController.forward();
    _scaleController.forward();
  }
  
  void _markAsChanged() {
    if (!_hasUnsavedChanges) {
      setState(() {
        _hasUnsavedChanges = true;
      });
    }
  }
  
  void _updateSelectedColor(Color color) {
    setState(() {
      _selectedColor = color;
    });
    _markAsChanged();
  }
  
  void _updateSelectedIcon(IconData icon) {
    setState(() {
      _selectedIcon = icon;
    });
    _markAsChanged();
  }
  
  void _updateHabitType(String type) {
    setState(() {
      _habitType = type;
    });
    _markAsChanged();
  }
  
  Future<bool> _showDiscardChangesDialog() async {
    if (!_hasUnsavedChanges) return true;
    
    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        final isLargeScreen = MediaQuery.of(context).size.width > 600;
        
        return AlertDialog(
          backgroundColor: Colors.white.withOpacity(0.95),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: const Color(0xFFFF8F00),
                size: isLargeScreen ? 28 : 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Unsaved Changes',
                  style: TextStyle(
                    color: const Color(0xFF1A237E),
                    fontSize: isLargeScreen ? 20 : 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          content: Text(
            'You have unsaved changes. Are you sure you want to discard them?',
            style: TextStyle(
              color: const Color(0xFF37474F),
              fontSize: isLargeScreen ? 16 : 14,
              height: 1.4,
            ),
          ),
          actions: [
            // Cancel Button
            Semantics(
              label: 'Cancel and stay on page',
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.symmetric(
                    horizontal: isLargeScreen ? 24 : 20,
                    vertical: isLargeScreen ? 12 : 10,
                  ),
                ),
                child: Text(
                  'Cancel',
                  style: TextStyle(
                    color: const Color(0xFF1976D2),
                    fontSize: isLargeScreen ? 16 : 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            // Discard Button
            Semantics(
              label: 'Discard changes and leave page',
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: TextButton.styleFrom(
                  backgroundColor: const Color(0xFFD32F2F).withOpacity(0.1),
                  padding: EdgeInsets.symmetric(
                    horizontal: isLargeScreen ? 24 : 20,
                    vertical: isLargeScreen ? 12 : 10,
                  ),
                ),
                child: Text(
                  'Discard',
                  style: TextStyle(
                    color: const Color(0xFFD32F2F),
                    fontSize: isLargeScreen ? 16 : 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    ) ?? false;
  }
  
  IconData _selectedIcon = Icons.star;

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _showDiscardChangesDialog,
      child: Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF42A5F5), Color(0xFF64B5F6), Color(0xFF90CAF9)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: ScaleTransition(
              scale: _scaleAnimation,
          child: Column(
            children: [
              // Custom App Bar
              _buildCustomAppBar(),
              
              // Content - Modern Design
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. Habit Name Section - Most Important
                      _buildHabitNameSection(),
                      
                      const SizedBox(height: 16),
                      
                      // 2. Visual Identity Section - Color & Icon
                      _buildVisualIdentitySection(),
                      
                      const SizedBox(height: 16),
                      
                      // 3. Goal Configuration Section - Very Important  
                      _buildGoalConfigurationSection(),
                      
                      const SizedBox(height: 16),
                      
                      // 4. Habit Type Section
                      _buildHabitTypeSection(),
                      
                      const SizedBox(height: 16),
                      
                      // 5. Advanced Settings Section
                      _buildAdvancedSettingsSection(),
                      
                      const SizedBox(height: 24),
                      
                      // 6. Action Buttons
                      _buildActionButtons(),
                      
                      const SizedBox(height: 100), // Space above bottom nav
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
    );
  }

  Future<void> _pickReminderTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _reminderTime,
    );
    if (picked != null) {
      setState(() => _reminderTime = picked);
      _markAsChanged();
    }
  }

  Widget _buildCustomAppBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      child: Row(
        children: [
          // Back Button with proper accessibility
          Semantics(
            label: 'Go back to add habit page',
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () async {
                  HapticFeedback.lightImpact();
                  final shouldPop = await _showDiscardChangesDialog();
                  if (shouldPop && mounted) {
                    context.pop();
                  }
                },
            child: Container(
              padding: const EdgeInsets.all(8),
                  constraints: const BoxConstraints(
                    minWidth: 48, // Apple Store minimum
                    minHeight: 48,
                  ),
              decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.white.withOpacity(0.25),
                        Colors.white.withOpacity(0.15),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.3),
                      width: 1,
                    ),
              ),
              child: const Icon(
                Icons.arrow_back_ios_new,
                color: Colors.white,
                size: 20,
                  ),
                ),
              ),
            ),
          ),
          
          const SizedBox(width: 15),
          
          // Icon Preview with animation
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  _selectedColor.withOpacity(0.4),
                  _selectedColor.withOpacity(0.2),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _selectedColor.withOpacity(0.5),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
              color: _selectedColor.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(
              _selectedIcon,
              color: Colors.white,
              size: 28,
            ),
          ),
          
          const SizedBox(width: 15),
          
          // Title
          const Expanded(
            child: Text(
              'Create Custom Habit',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  


  Future<void> _saveCustomHabit() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please enter a habit name'),
          backgroundColor: Colors.red,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 100), // Above app bar
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      // Create document ID from habit name (URL safe)
      final habitId = _nameController.text.trim().toLowerCase()
          .replaceAll(' ', '-')
          .replaceAll(RegExp(r'[^a-z0-9\-]'), '');

      final today = DateTime.now();
      final dateKey = HabitPeriodUtils.generateDateKey(today, _goalPeriod);

      // Check if habit already exists for today
      final existingHabit = await FirebaseFirestore.instance
          .collection('habits')
          .doc(currentUser.uid)
          .collection(dateKey)
          .doc(habitId)
          .get();

      if (existingHabit.exists) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.warning, color: Colors.white),
                const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                children: [
                      const Text(
                        'Habit Already Exists',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text('${_nameController.text.trim()} is already added for this ${_goalPeriod.toLowerCase()}'),
                ],
              ),
            ),
              ],
            ),
            backgroundColor: Colors.orange,
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 100), // Above app bar
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
        setState(() => _isLoading = false);
        return;
      }

      // Get color name and icon name for storage
      final colorName = _getColorName(_selectedColor);
      final iconName = _getIconName(_selectedIcon);

      // Create habit data
      final habitData = {
        'name': _nameController.text.trim(),
        'category': 'custom',
        'current': 0,
        'goal': int.tryParse(_goalValueController.text) ?? 1,
        'completed': false,
        'completedAt': null,
        'type': _habitType.toLowerCase() == 'build' ? 'count' : 'quit',
        'unit': _unit,
        'iconName': iconName,
        'colorName': colorName,
        'goalPeriod': _goalPeriod,
        'timeRange': _timeRange,
        'taskDays': _taskDays,
        'periodKey': dateKey, // Store the period key for reference
        'remindersEnabled': _remindersEnabled,
        'reminderTime': _remindersEnabled ? '${_reminderTime.hour}:${_reminderTime.minute}' : null,
        'reminderMessage': _reminderMessageController.text.trim(),
        'startDate': Timestamp.fromDate(_startDate),
        'endDate': _endDate != null ? Timestamp.fromDate(_endDate!) : null,
        'createdAt': FieldValue.serverTimestamp(),
        'isCustom': true,
      };

      // Add habit to Firebase
      await FirebaseFirestore.instance
          .collection('habits')
          .doc(currentUser.uid)
          .collection(dateKey)
          .doc(habitId)
          .set(habitData);

      // Schedule notification if reminders are enabled
      if (_remindersEnabled) {
        final notificationId = NotificationService.generateNotificationId(
          _nameController.text.trim(), 
          _goalPeriod
        );
        
        await NotificationService.scheduleHabitReminder(
          id: notificationId,
          title: '🎯 ${_nameController.text.trim()}',
          body: _reminderMessageController.text.trim().isNotEmpty 
              ? _reminderMessageController.text.trim()
              : 'Time for your ${_goalPeriod.toLowerCase()} habit!',
          hour: _reminderTime.hour,
          minute: _reminderTime.minute,
          habitId: habitId,
          period: _goalPeriod.toLowerCase(),
        );
        
        debugPrint('✅ Scheduled ${_goalPeriod.toLowerCase()} reminder for ${_nameController.text.trim()}');
      }

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
      children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
      children: [
                    const Text(
                      'Custom Habit Created!',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text('${_nameController.text.trim()} has been added successfully'),
                  ],
                ),
              ),
            ],
          ),
          backgroundColor: Colors.green,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 100), // Above app bar
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      
      // Reset unsaved changes flag
      setState(() {
        _hasUnsavedChanges = false;
      });

      // Navigate back
      context.pop();
      
    } catch (e) {
      debugPrint('Error creating custom habit: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Failed to create habit. Please try again.'),
          backgroundColor: Colors.red,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 100), // Above app bar
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  String _getColorName(Color color) {
    if (color == Colors.blue) return 'blue';
    if (color == Colors.green) return 'green';
    if (color == Colors.purple) return 'purple';
    if (color == Colors.orange) return 'orange';
    if (color == Colors.red) return 'red';
    if (color == Colors.teal) return 'teal';
    if (color == Colors.amber) return 'amber';
    if (color == Colors.indigo) return 'indigo';
    if (color == Colors.cyan) return 'cyan';
    if (color == Colors.brown) return 'brown';
    if (color == Colors.pink) return 'pink';
    if (color == Colors.lime) return 'lime';
    return 'blue';
  }

  String _getIconName(IconData icon) {
    if (icon == Icons.star) return 'star';
    if (icon == Icons.favorite) return 'favorite';
    if (icon == Icons.fitness_center) return 'fitness_center';
    if (icon == Icons.directions_walk) return 'directions_walk';
    if (icon == Icons.book) return 'book';
    if (icon == Icons.music_note) return 'music_note';
    if (icon == Icons.brush) return 'brush';
    if (icon == Icons.code) return 'code';
    if (icon == Icons.restaurant) return 'restaurant';
    if (icon == Icons.local_drink) return 'local_drink';
    if (icon == Icons.bedtime) return 'bedtime';
    if (icon == Icons.psychology) return 'psychology';
    if (icon == Icons.self_improvement) return 'self_improvement';
    if (icon == Icons.school) return 'school';
    if (icon == Icons.work) return 'work';
    if (icon == Icons.sports) return 'sports';
    return 'star';
  }

  // ===== MODERN UI SECTIONS =====
  
  Widget _buildHabitNameSection() {
    final isLargeScreen = MediaQuery.of(context).size.width > 600;
    
    return Container(
      padding: EdgeInsets.all(isLargeScreen ? 24 : 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
        colors: [
            Colors.white.withOpacity(0.25),
            Colors.white.withOpacity(0.15),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withOpacity(0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _selectedColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  _selectedIcon,
                  color: _selectedColor,
                  size: isLargeScreen ? 24 : 20,
                ),
              ),
              const SizedBox(width: 12),
            Expanded(
                child: Text(
                  'Habit Name',
                  style: TextStyle(
                    fontSize: isLargeScreen ? 20 : 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white.withOpacity(0.2),
                width: 1,
              ),
            ),
              child: TextField(
              controller: _nameController,
              style: TextStyle(
                  color: Colors.white,
                fontSize: isLargeScreen ? 18 : 16,
                fontWeight: FontWeight.w500,
                ),
                decoration: InputDecoration(
                hintText: 'e.g., Morning Prayer, Daily Exercise',
                  hintStyle: TextStyle(
                  color: Colors.white.withOpacity(0.6),
                  fontSize: isLargeScreen ? 16 : 14,
                  ),
                  border: InputBorder.none,
                contentPadding: EdgeInsets.all(isLargeScreen ? 20 : 16),
                ),
              ),
            ),
          ],
      ),
    );
  }

  Widget _buildVisualIdentitySection() {
    final isLargeScreen = MediaQuery.of(context).size.width > 600;
    
    return Container(
      padding: EdgeInsets.all(isLargeScreen ? 24 : 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white.withOpacity(0.25),
            Colors.white.withOpacity(0.15),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withOpacity(0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
          Text(
            'Visual Identity',
            style: TextStyle(
              fontSize: isLargeScreen ? 18 : 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          
          // Color Selection
        Text(
          'Color',
          style: TextStyle(
              fontSize: isLargeScreen ? 14 : 12,
              fontWeight: FontWeight.w600,
            color: Colors.white.withOpacity(0.8),
              letterSpacing: 0.5,
          ),
        ),
          const SizedBox(height: 12),
        SizedBox(
            height: isLargeScreen ? 60 : 50,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _availableColors.length,
            itemBuilder: (context, index) {
              final color = _availableColors[index];
              final isSelected = color == _selectedColor;
              
              return GestureDetector(
                  onTap: () => _updateSelectedColor(color),
                child: Container(
                    width: isLargeScreen ? 50 : 44,
                    height: isLargeScreen ? 50 : 44,
                    margin: EdgeInsets.only(right: isLargeScreen ? 12 : 10),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? Colors.white : Colors.white.withOpacity(0.3),
                        width: isSelected ? 3 : 1,
                      ),
                      boxShadow: isSelected ? [
                        BoxShadow(
                          color: color.withOpacity(0.5),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ] : null,
                  ),
                  child: isSelected
                        ? const Icon(Icons.check, color: Colors.white, size: 20)
                      : null,
                ),
              );
            },
          ),
        ),
          
          const SizedBox(height: 20),
          
          // Icon Selection
        Text(
          'Icon',
          style: TextStyle(
              fontSize: isLargeScreen ? 14 : 12,
              fontWeight: FontWeight.w600,
            color: Colors.white.withOpacity(0.8),
              letterSpacing: 0.5,
          ),
        ),
          const SizedBox(height: 12),
        SizedBox(
            height: isLargeScreen ? 60 : 50,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _availableIcons.length,
            itemBuilder: (context, index) {
              final icon = _availableIcons[index];
              final isSelected = icon == _selectedIcon;
              
              return GestureDetector(
                  onTap: () => _updateSelectedIcon(icon),
                child: Container(
                    width: isLargeScreen ? 50 : 44,
                    height: isLargeScreen ? 50 : 44,
                    margin: EdgeInsets.only(right: isLargeScreen ? 12 : 10),
                  decoration: BoxDecoration(
                      gradient: isSelected ? LinearGradient(
                        colors: [_selectedColor, _selectedColor.withOpacity(0.7)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ) : null,
                      color: isSelected ? null : Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? Colors.white.withOpacity(0.5) : Colors.white.withOpacity(0.2),
                        width: 1,
                      ),
                  ),
                  child: Icon(
                    icon,
                      color: isSelected ? Colors.white : Colors.white.withOpacity(0.7),
                      size: isLargeScreen ? 24 : 20,
                  ),
                ),
              );
            },
          ),
        ),
      ],
      ),
    );
  }
  
  Widget _buildGoalConfigurationSection() {
    final isLargeScreen = MediaQuery.of(context).size.width > 600;
    
    return Container(
      padding: EdgeInsets.all(isLargeScreen ? 24 : 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white.withOpacity(0.25),
            Colors.white.withOpacity(0.15),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withOpacity(0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
            ),
          ],
        ),
      child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
            'Goal Configuration',
          style: TextStyle(
              fontSize: isLargeScreen ? 18 : 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          
          // Goal Period Dropdown
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: isLargeScreen ? 20 : 16,
              vertical: isLargeScreen ? 16 : 14,
            ),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _goalPeriod,
                isExpanded: true,
                dropdownColor: _selectedColor.withOpacity(0.9),
                style: TextStyle(
                  color: Colors.white,
                  fontSize: isLargeScreen ? 16 : 14,
                  fontWeight: FontWeight.w500,
                ),
                icon: Icon(
                  Icons.keyboard_arrow_down,
                  color: Colors.white.withOpacity(0.7),
                  size: isLargeScreen ? 24 : 20,
                ),
                items: ['Daily', 'Weekly', 'Monthly'].map((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _goalPeriod = value!;
                  });
                  _markAsChanged();
                },
                menuMaxHeight: (MediaQuery.of(context).size.height * 0.5),
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Goal Value and Unit - Unit gets MORE space!
          Row(
            children: [
              // Goal Value - Takes 35% of space
              Expanded(
                flex: 35,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Goal',
                      style: TextStyle(
                        fontSize: isLargeScreen ? 14 : 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withOpacity(0.8),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: isLargeScreen ? 16 : 14,
                        vertical: isLargeScreen ? 16 : 14,
                      ),
        decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                      child: TextField(
                        controller: _goalValueController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: TextStyle(
                  color: Colors.white,
                          fontSize: isLargeScreen ? 16 : 14,
                          fontWeight: FontWeight.w500,
                ),
                        decoration: InputDecoration(
                          hintText: '1',
                          hintStyle: TextStyle(
                            color: Colors.white.withOpacity(0.6),
                            fontSize: isLargeScreen ? 14 : 12,
              ),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
          ),
        ),
      ),
                  ],
                ),
              ),
              
              const SizedBox(width: 12),
              
              // Unit Dropdown - Takes 65% of space (MUCH MORE PROMINENT!)
            Expanded(
                flex: 65,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                      'Unit',
                    style: TextStyle(
                        fontSize: isLargeScreen ? 14 : 12,
                        fontWeight: FontWeight.w600,
                      color: Colors.white.withOpacity(0.8),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: isLargeScreen ? 20 : 16,
                        vertical: isLargeScreen ? 16 : 14,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _unit,
                          isExpanded: true,
                          dropdownColor: _selectedColor.withOpacity(0.9),
                      style: TextStyle(
                            color: Colors.white,
                            fontSize: isLargeScreen ? 16 : 14,
                            fontWeight: FontWeight.w500,
                      ),
                          icon: Icon(
                            Icons.keyboard_arrow_down,
                            color: Colors.white.withOpacity(0.7),
                            size: isLargeScreen ? 24 : 20,
                    ),
                          items: _availableUnits.map((String value) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Text(value),
                );
              }).toList(),
                          onChanged: (value) {
                            setState(() {
                              _unit = value!;
                            });
                            _markAsChanged();
                          },
                          menuMaxHeight: (MediaQuery.of(context).size.height * 0.5),
                        ),
                      ),
                    ),
                  ],
              ),
            ),
          ],
        ),
        ],
      ),
    );
  }

  Widget _buildHabitTypeSection() {
    final isLargeScreen = MediaQuery.of(context).size.width > 600;
    
    return Container(
      padding: EdgeInsets.all(isLargeScreen ? 24 : 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
              colors: [
            Colors.white.withOpacity(0.25),
            Colors.white.withOpacity(0.15),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withOpacity(0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
            'Habit Type',
                    style: TextStyle(
              fontSize: isLargeScreen ? 18 : 16,
              fontWeight: FontWeight.bold,
                        color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildModernToggleButton(
                  text: 'Build',
                  icon: Icons.trending_up,
                  isSelected: _habitType == 'Build',
                  onTap: () => _updateHabitType('Build'),
                  color: const Color(0xFF4CAF50),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildModernToggleButton(
                  text: 'Quit',
                  icon: Icons.block,
                  isSelected: _habitType == 'Quit',
                  onTap: () => _updateHabitType('Quit'),
                  color: const Color(0xFFFF5722),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildAdvancedSettingsSection() {
    final isLargeScreen = MediaQuery.of(context).size.width > 600;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {
              HapticFeedback.lightImpact();
              setState(() => _isAdvancedSettingsExpanded = !_isAdvancedSettingsExpanded);
            },
            child: Container(
              padding: EdgeInsets.all(isLargeScreen ? 20 : 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
          colors: [
                    Colors.white.withOpacity(0.15),
                    Colors.white.withOpacity(0.08),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.white.withOpacity(0.2),
                  width: 1,
                ),
              ),
          child: Row(
            children: [
                  Icon(
                    Icons.settings,
                    color: Colors.white.withOpacity(0.7),
                    size: isLargeScreen ? 20 : 18,
                  ),
                  const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                          'Advanced Settings',
                      style: TextStyle(
                            fontSize: isLargeScreen ? 14 : 12,
                            fontWeight: FontWeight.w600,
                        color: Colors.white.withOpacity(0.8),
                      ),
                    ),
                    Text(
                          'Schedule, reminders & more',
                          style: TextStyle(
                            fontSize: isLargeScreen ? 11 : 10,
                            color: Colors.white.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              ),
              AnimatedRotation(
                turns: _isAdvancedSettingsExpanded ? 0.25 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  Icons.keyboard_arrow_right,
                  color: Colors.white.withOpacity(0.5),
                  size: 16,
                ),
              ),
            ],
          ),
        ),
      ),
        ),
        
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          height: _isAdvancedSettingsExpanded ? null : 0,
          clipBehavior: Clip.hardEdge,
          decoration: const BoxDecoration(),
          child: _isAdvancedSettingsExpanded ? Container(
            padding: const EdgeInsets.only(top: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.white.withOpacity(0.15),
                  Colors.white.withOpacity(0.08),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: Padding(
              padding: EdgeInsets.all(MediaQuery.of(context).size.width > 600 ? 20 : 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                // Task Days
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isLargeScreen ? 20 : 16,
                    vertical: isLargeScreen ? 14 : 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _taskDays,
                      isExpanded: true,
                      dropdownColor: _selectedColor.withOpacity(0.9),
                      style: TextStyle(color: Colors.white, fontSize: isLargeScreen ? 16 : 14),
                      icon: Icon(Icons.keyboard_arrow_down, color: Colors.white.withOpacity(0.7), size: isLargeScreen ? 24 : 20),
                      items: ['Every Day', 'Weekdays', 'Weekends', 'Custom'].map((String value) {
                        return DropdownMenuItem<String>(value: value, child: Text(value));
                      }).toList(),
                      onChanged: (value) {
                        setState(() => _taskDays = value!);
                        _markAsChanged();
                      },
                      menuMaxHeight: (MediaQuery.of(context).size.height * 0.5),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Time Range
                LayoutBuilder(
                  builder: (context, constraints) {
                    final bool isTight = constraints.maxWidth < 360;
                    if (isTight) {
                      final double itemWidth = (constraints.maxWidth - 8) / 2;
                      return Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          SizedBox(width: itemWidth, child: _buildModernToggleButton(text: 'Anytime', icon: Icons.access_time, isSelected: _timeRange == 'Anytime', onTap: () { setState(() { _timeRange = 'Anytime'; }); _markAsChanged(); }, color: const Color(0xFF42A5F5))),
                          SizedBox(width: itemWidth, child: _buildModernToggleButton(text: 'Morning', icon: Icons.wb_sunny, isSelected: _timeRange == 'Morning', onTap: () { setState(() { _timeRange = 'Morning'; }); _markAsChanged(); }, color: const Color(0xFFFFB300))),
                          SizedBox(width: itemWidth, child: _buildModernToggleButton(text: 'Afternoon', icon: Icons.wb_twilight, isSelected: _timeRange == 'Afternoon', onTap: () { setState(() { _timeRange = 'Afternoon'; }); _markAsChanged(); }, color: const Color(0xFF64B5F6))),
                          SizedBox(width: itemWidth, child: _buildModernToggleButton(text: 'Evening', icon: Icons.nightlight_round, isSelected: _timeRange == 'Evening', onTap: () { setState(() { _timeRange = 'Evening'; }); _markAsChanged(); }, color: const Color(0xFF5E35B1))),
                        ],
                      );
                    }
                    return Row(
                      children: [
                        Expanded(child: _buildModernToggleButton(text: 'Anytime', icon: Icons.access_time, isSelected: _timeRange == 'Anytime', onTap: () { setState(() { _timeRange = 'Anytime'; }); _markAsChanged(); }, color: const Color(0xFF42A5F5))),
                        const SizedBox(width: 8),
                        Expanded(child: _buildModernToggleButton(text: 'Morning', icon: Icons.wb_sunny, isSelected: _timeRange == 'Morning', onTap: () { setState(() { _timeRange = 'Morning'; }); _markAsChanged(); }, color: const Color(0xFFFFB300))),
                        const SizedBox(width: 8),
                        Expanded(child: _buildModernToggleButton(text: 'Afternoon', icon: Icons.wb_twilight, isSelected: _timeRange == 'Afternoon', onTap: () { setState(() { _timeRange = 'Afternoon'; }); _markAsChanged(); }, color: const Color(0xFF64B5F6))),
                        const SizedBox(width: 8),
                        Expanded(child: _buildModernToggleButton(text: 'Evening', icon: Icons.nightlight_round, isSelected: _timeRange == 'Evening', onTap: () { setState(() { _timeRange = 'Evening'; }); _markAsChanged(); }, color: const Color(0xFF5E35B1))),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 12),

                // Reminders
                Container(
                  padding: EdgeInsets.all(isLargeScreen ? 16 : 14),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Reminders', style: TextStyle(color: Colors.white.withOpacity(0.9), fontWeight: FontWeight.w600, fontSize: isLargeScreen ? 16 : 14)),
                          Switch(
                            value: _remindersEnabled,
                            onChanged: (v) { setState(() => _remindersEnabled = v); _markAsChanged(); },
                            activeColor: Colors.blue,
                          ),
                        ],
                      ),
                      if (_remindersEnabled) ...[
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: _pickReminderTime,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Time: ${_reminderTime.format(context)}', style: const TextStyle(color: Colors.white)),
                              const Icon(Icons.access_time, color: Colors.white70, size: 18),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _reminderMessageController,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            hintText: 'Reminder message',
                            hintStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
                            border: InputBorder.none,
                          ),
                          onChanged: (_) => _markAsChanged(),
                        ),
                      ],
                    ],
                  ),
                ),
                ],
              ),
            ),
          ) : null,
        ),
      ],
    );
  }
  
  Widget _buildActionButtons() {
    final isLargeScreen = MediaQuery.of(context).size.width > 600;
    
    return Row(
      children: [
        // Cancel Button
            Expanded(
          flex: 2,
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () async {
                HapticFeedback.lightImpact();
                final shouldPop = await _showDiscardChangesDialog();
                if (shouldPop && mounted) {
                  context.pop();
                }
              },
                child: Container(
                height: isLargeScreen ? 56 : 50,
                  decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.3),
                    width: 1,
                  ),
                  ),
                  child: Center(
                    child: Text(
                    'Cancel',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: isLargeScreen ? 16 : 14,
                      fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ),
        
        const SizedBox(width: 12),
        
        // Save Button
        Expanded(
          flex: 3,
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () {
                if (_isLoading) return;
                HapticFeedback.lightImpact();
                _saveCustomHabit();
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                height: isLargeScreen ? 56 : 50,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: _isLoading 
                      ? [Colors.grey.withOpacity(0.6), Colors.grey.withOpacity(0.4)]
                      : [_selectedColor, _selectedColor.withOpacity(0.7)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
                  boxShadow: _isLoading ? null : [
              BoxShadow(
                      color: _selectedColor.withOpacity(0.4),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Center(
            child: _isLoading
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: isLargeScreen ? 20 : 16,
                            height: isLargeScreen ? 20 : 16,
                            child: const CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Saving...',
                    style: TextStyle(
                      color: Colors.white,
                              fontSize: isLargeScreen ? 16 : 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.save_rounded,
                            color: Colors.white,
                            size: isLargeScreen ? 20 : 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Create Habit',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: isLargeScreen ? 16 : 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
  
  Widget _buildModernToggleButton({
    required String text,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
    required Color color,
  }) {
    final isLargeScreen = MediaQuery.of(context).size.width > 600;
    
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          constraints: BoxConstraints(
            minHeight: 48, // Apple Store minimum
            minWidth: 48,
          ),
          padding: EdgeInsets.symmetric(
            vertical: isLargeScreen ? 16 : 14,
            horizontal: isLargeScreen ? 20 : 16,
          ),
          decoration: BoxDecoration(
            gradient: isSelected ? LinearGradient(
              colors: [color, color.withOpacity(0.7)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ) : null,
            color: isSelected ? null : Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? Colors.white.withOpacity(0.5) : Colors.white.withOpacity(0.2),
              width: isSelected ? 2 : 1,
            ),
            boxShadow: isSelected ? [
              BoxShadow(
                color: color.withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ] : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: Colors.white,
                size: isLargeScreen ? 20 : 18,
              ),
              const SizedBox(width: 8),
              Text(
                text,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: isLargeScreen ? 16 : 14,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    // Remove listeners
    _nameController.removeListener(_markAsChanged);
    _descriptionController.removeListener(_markAsChanged);
    _goalValueController.removeListener(_markAsChanged);
    _reminderMessageController.removeListener(_markAsChanged);
    
    // Dispose controllers
    _nameController.dispose();
    _descriptionController.dispose();
    _goalValueController.dispose();
    _reminderMessageController.dispose();
    _fadeController.dispose();
    _scaleController.dispose();
    super.dispose();
  }
}
