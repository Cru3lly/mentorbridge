import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';

class MiddleSchoolMentorAcademicCalendarPage extends StatefulWidget {
  const MiddleSchoolMentorAcademicCalendarPage({super.key});

  @override
  State<MiddleSchoolMentorAcademicCalendarPage> createState() => _MiddleSchoolMentorAcademicCalendarPageState();
}

class _MiddleSchoolMentorAcademicCalendarPageState extends State<MiddleSchoolMentorAcademicCalendarPage> {
  final List<String> months = [
    'September', 'October', 'November', 'December', 'January', 'February',
    'March', 'April', 'May', 'June', 'July', 'August'
  ];
  String selectedAcademicYear = '2025-2026';
  String? _selectedMonth;
  String? _assistantCoordinatorId; 

  final Map<String, Map<String, dynamic>> _calendarDataForYear = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeToCurrentDate();
    _fetchAssistantCoordinatorIdAndLoadData();
  }

  void _initializeToCurrentDate() {
    final now = DateTime.now();
    const monthNumToName = {
        1: 'January', 2: 'February', 3: 'March', 4: 'April', 5: 'May', 6: 'June',
        7: 'July', 8: 'August', 9: 'September', 10: 'October', 11: 'November', 12: 'December'
    };
    final currentMonthName = monthNumToName[now.month]!;

    int startYear;
    if (now.month >= 9) {
      startYear = now.year;
    } else {
      startYear = now.year - 1;
    }
    final endYear = startYear + 1;
    
    selectedAcademicYear = '$startYear-$endYear';
    _selectedMonth = currentMonthName;
  }

  Future<void> _fetchAssistantCoordinatorIdAndLoadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(currentUser.uid).get();
      final parentId = userDoc.data()?['parentId'] as String?;

      if (parentId != null && parentId.isNotEmpty) {
        _assistantCoordinatorId = parentId;
        await _loadAllWeeksForYear();
      } else {
         if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadAllWeeksForYear() async {
    // Implementation placeholder
    if (mounted) setState(() => _isLoading = false);
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        leading: _selectedMonth != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
                onPressed: () => setState(() => _selectedMonth = null),
              )
            : IconButton(
                icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
                onPressed: () => context.pop(),
              ),
        title: Text(
          _selectedMonth != null 
              ? '$_selectedMonth ${getCalendarYearForMonth(_selectedMonth!)}'
              : 'Middle School Academic Calendar',
          style: const TextStyle(fontFamily: 'NotoSans', fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white),
            tooltip: 'Settings',
            onPressed: () {
              context.push('/settings');
            },
          ),
        ],
      ),
      body: const Center(
        child: Text(
          'Middle School Academic Calendar\n(Implementation in progress)',
          style: TextStyle(color: Colors.white, fontSize: 16),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
  
  // Placeholder fonksiyonlar
  int getCalendarYearForMonth(String month) {
    final parts = selectedAcademicYear.split('-');
    final startYear = int.parse(parts[0]);
    if (['September', 'October', 'November', 'December'].contains(month)) {
      return startYear;
    }
    return int.parse(parts[1]);
  }
} 