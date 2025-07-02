import 'package:flutter/material.dart';
import 'package:glassmorphism/glassmorphism.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import 'package:url_launcher/url_launcher.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'dart:ui';
import 'package:go_router/go_router.dart';

class HighSchoolUnitCoordinatorAcademicCalendar extends StatefulWidget {
  const HighSchoolUnitCoordinatorAcademicCalendar({super.key});

  @override
  State<HighSchoolUnitCoordinatorAcademicCalendar> createState() => _HighSchoolUnitCoordinatorAcademicCalendarState();
}

class _HighSchoolUnitCoordinatorAcademicCalendarState extends State<HighSchoolUnitCoordinatorAcademicCalendar> {
  final List<String> months = [
    'September', 'October', 'November', 'December', 'January', 'February', 
    'March', 'April', 'May', 'June', 'July', 'August'
  ];
  final List<String> monthShort = [
    'Sep', 'Oct', 'Nov', 'Dec', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 
    'Jul', 'Aug'
  ];
  String selectedAcademicYear = '2025-2026';
  String? _selectedMonth;
  
  String get unitCoordinatorId => FirebaseAuth.instance.currentUser?.uid ?? '';
  
  Map<String, TextEditingController> titleControllers = {};
  Map<String, TextEditingController> descControllers = {};
  Map<String, List<Map<String, dynamic>>> linkControllers = {};
  Map<String, List<Map<String, dynamic>>> attachmentControllers = {};
  Map<String, List<dynamic>> pendingUploads = {};
  Map<String, List<String>> pendingUploadNames = {};
  Map<String, List<String>> pendingDeleteUrls = {};

  // Holds all week data for the selected year, loaded once.
  // Key: "month-weekNumber", Value: week data map
  final Map<String, Map<String, dynamic>> _calendarDataForYear = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeToCurrentDate();
    _loadAllWeeksForYear();
  }

  void _initializeToCurrentDate() {
    final now = DateTime.now();
    const monthNumToName = {
        1: 'January', 2: 'February', 3: 'March', 4: 'April', 5: 'May', 6: 'June', 
        7: 'July', 8: 'August', 9: 'September', 10: 'October', 11: 'November', 12: 'December'
    };
    final currentMonthName = monthNumToName[now.month]!;

    int startYear;
    // Academic year is Sep-Aug.
    if (now.month >= 9) { // September to December
      startYear = now.year;
    } else { // January to August
      startYear = now.year - 1;
    }
    final endYear = startYear + 1;
    
    // Set the initial state. No need for setState as it's in initState.
    selectedAcademicYear = '$startYear-$endYear';
    _selectedMonth = currentMonthName;
  }

  // Loads all week data for the selected year from Firestore.
  Future<void> _loadAllWeeksForYear() async {
    if (unitCoordinatorId.isEmpty) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    if (mounted) setState(() => _isLoading = true);
    
    _calendarDataForYear.clear();

    try {
      final baseRef = FirebaseFirestore.instance.collection('academicCalendars').doc(unitCoordinatorId);
      
      final Map<String, Future<QuerySnapshot<Map<String, dynamic>>>> monthFutures = {};

      for (final month in months) {
        final calendarYear = getCalendarYearForMonth(month);
        monthFutures[month] = baseRef.collection(calendarYear.toString()).doc(month).collection('weeks').get();
      }

      // Wait for all futures
      final allSnapshots = await Future.wait(monthFutures.values);

      // Process the results
      final monthKeys = monthFutures.keys.toList();
      for (var i = 0; i < allSnapshots.length; i++) {
        final month = monthKeys[i];
        final weeksSnapshot = allSnapshots[i];
        for (final weekDoc in weeksSnapshot.docs) {
          final weekNumber = int.tryParse(weekDoc.id.split('_').last) ?? 0;
          if (weekNumber > 0) {
            final key = weekKey(month, weekNumber);
            _calendarDataForYear[key] = weekDoc.data();
          }
        }
      }
    } catch (e) {
      print('Error loading calendar data: $e');
      // Optionally show an error message to the user
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Helper to get week key
  String weekKey(String month, int weekNumber) => '$month-$weekNumber';

  // Helper to get calendar year for a given academic month
  int getCalendarYearForMonth(String month) {
    final parts = selectedAcademicYear.split('-');
    final startYear = int.parse(parts[0]);
    final endYear = int.parse(parts[1]);
    
    if (['September', 'October', 'November', 'December'].contains(month)) {
      return startYear;
    }
    return endYear;
  }

  // Helper to get month number (1-12)
  int getMonthNumber(String month) {
    const monthMap = {
        'January': 1, 'February': 2, 'March': 3, 'April': 4, 'May': 5, 'June': 6, 
        'July': 7, 'August': 8, 'September': 9, 'October': 10, 'November': 11, 'December': 12
    };
    return monthMap[month]!;
  }

  List<Map<String, dynamic>> getWeeksForMonth(String month) {
    final parts = selectedAcademicYear.split('-');
    final startYear = int.parse(parts[0]);
    final endYear = int.parse(parts[1]);

    final targetMonthNumber = getMonthNumber(month);
    final targetCalendarYear = getCalendarYearForMonth(month);
    DateTime firstDayOfMonth = DateTime(targetCalendarYear, targetMonthNumber, 1);

    // 1. Find the first Monday of the current month.
    DateTime firstMonday = firstDayOfMonth;
    while (firstMonday.weekday != DateTime.monday) {
      firstMonday = firstMonday.add(const Duration(days: 1));
    }

    // 2. Find the first Monday of the NEXT month to know where to stop.
    int nextMonthNumber = targetMonthNumber == 12 ? 1 : targetMonthNumber + 1;
    int nextMonthYear = targetMonthNumber == 12 ? targetCalendarYear + 1 : targetCalendarYear;
    DateTime nextMonthFirstDay = DateTime(nextMonthYear, nextMonthNumber, 1);
    DateTime nextMonthFirstMonday = nextMonthFirstDay;
    while (nextMonthFirstMonday.weekday != DateTime.monday) {
      nextMonthFirstMonday = nextMonthFirstMonday.add(const Duration(days: 1));
    }

    List<Map<String, dynamic>> monthWeeks = [];
    int localWeekCounter = 1;
    const globalMonthShort = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

    DateTime weekStart = firstMonday;
    while (weekStart.isBefore(nextMonthFirstMonday)) {
      // Only include weeks that START in the current month
      if (weekStart.month == targetMonthNumber && weekStart.year == targetCalendarYear) {
        DateTime weekEnd = weekStart.add(const Duration(days: 6));
        
        final start = weekStart;
        final end = weekEnd;
        final startMonthStr = globalMonthShort[start.month - 1];
        final endMonthStr = globalMonthShort[end.month - 1];
        String range;
        if (start.year == end.year) {
          range = '$startMonthStr ${start.day} - $endMonthStr ${end.day}, ${end.year}';
        } else {
          range = '$startMonthStr ${start.day}, ${start.year} - $endMonthStr ${end.day}, ${end.year}';
        }
        monthWeeks.add({
          'localWeekNumber': localWeekCounter++,
          'dateRange': range,
          'start': start,
          'end': end,
        });
      }
      weekStart = weekStart.add(const Duration(days: 7));
    }
    return monthWeeks;
  }

  // This function is no longer needed as we load all data at once.
  // Future<Map<String, dynamic>?> fetchWeekData(String month, int weekNumber) async ...

  // Saves a single week's data to Firestore.
  Future<void> saveWeekData(String month, int localWeekNumber, Map<String, dynamic> data) async {
    if (unitCoordinatorId.isEmpty) {
      print('ERROR: unitCoordinatorId is empty! Cannot save to Firestore.');
      return;
    }
    final calendarYear = getCalendarYearForMonth(month);
    final ref = FirebaseFirestore.instance
        .collection('academicCalendars')
        .doc(unitCoordinatorId)
        .collection(calendarYear.toString())
        .doc(month)
        .collection('weeks')
        .doc('week_$localWeekNumber');
    print('Saving week data to Firestore: ${ref.path}');
    await ref.set(data, SetOptions(merge: true));
  }

  Future<String> fetchPageTitle(String url) async {
    try {
      if (url.contains('youtube.com') || url.contains('youtu.be')) {
        // Use oEmbed for YouTube: simpler, no API key needed.
        final oembedUrl = 'https://www.youtube.com/oembed?url=${Uri.encodeComponent(url)}&format=json';
        final response = await http.get(Uri.parse(oembedUrl));
        if (response.statusCode == 200) {
          final data = json.decode(response.body); // http package handles charset
          if (data['title'] != null) {
            return data['title'];
          }
        }
      } else {
        // For other websites, try to fetch the HTML title.
        final response = await http.get(
          Uri.parse(url),
          headers: {
            'User-Agent': 'Mozilla/5.0 (compatible; Googlebot/2.1; +http://www.google.com/bot.html)'
          },
        );
        // Explicitly decode as UTF-8 for robustness, as some sites don't set charset header.
        final body = utf8.decode(response.bodyBytes, allowMalformed: true);
        final reg = RegExp(r'<title>(.*?)</title>', caseSensitive: false, dotAll: true);
        final match = reg.firstMatch(body);
        if (match != null) {
          var title = match.group(1) ?? url;
          // Basic unescaping for common HTML entities without adding a dependency.
          return title
              .replaceAll('&quot;', '"')
              .replaceAll('&amp;', '&')
              .replaceAll('&#39;', "'")
              .trim();
        }
      }
    } catch (e) {
      print("Error fetching page title for $url: $e");
    }
    return url; // Fallback to the original URL if everything fails.
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
            : null,
        title: Text(
          _selectedMonth != null 
              ? '$_selectedMonth ${getCalendarYearForMonth(_selectedMonth!)}'
              : 'Academic Calendar',
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
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF8EC5FC), Color(0xFFE0C3FC)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Colors.white))
                : SafeArea(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 400),
                      transitionBuilder: (child, animation) {
                        return FadeTransition(opacity: animation, child: child);
                      },
                      child: _selectedMonth == null
                          ? _buildYearView()
                          : _buildMonthView(_selectedMonth!),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildYearView() {
    return Column(
      key: const ValueKey('yearView'),
      children: [
        const SizedBox(height: 11),
        _buildYearSelector(),
        const SizedBox(height: 11),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(12),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 0.8,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: months.length,
            itemBuilder: (context, index) {
              final month = months[index];
              return _buildMonthCell(month);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMonthCell(String month) {
    final year = getCalendarYearForMonth(month);
    final monthNumber = getMonthNumber(month);
    final firstDayOfMonth = DateTime(year, monthNumber, 1);
    // DateTime.monday is 1, ..., DateTime.sunday is 7.
    // The number of empty cells before the 1st day.
    final startOffset = firstDayOfMonth.weekday - 1; 
    final daysInMonth = DateTime(year, monthNumber + 1, 0).day;

    final now = DateTime.now();
    final bool isCurrentMonth = now.year == year && now.month == monthNumber;

    return GestureDetector(
      onTap: () => setState(() => _selectedMonth = month),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 12.0),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: isCurrentMonth 
                  ? Colors.amber.withOpacity(0.4) 
                  : Colors.black.withOpacity(0.1),
              border: Border.all(color: Colors.white.withOpacity(0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  month,
                  style: const TextStyle(
                    fontFamily: 'NotoSans',
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: GridView.builder(
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 7,
                      childAspectRatio: 1.0,
                      mainAxisSpacing: 1,
                      crossAxisSpacing: 1,
                    ),
                    itemCount: daysInMonth + startOffset,
                    itemBuilder: (context, index) {
                      if (index < startOffset) {
                        return Container(); // Empty cell
                      }
                      final day = index - startOffset + 1;
                      return Center(
                        child: Text(
                          '$day',
                          style: TextStyle(
                            fontFamily: 'NotoSans',
                            fontSize: 9,
                            color: Colors.white.withOpacity(0.85),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMonthView(String month) {
    final weeks = getWeeksForMonth(month);
    return ListView.builder(
      key: ValueKey(month),
      padding: const EdgeInsets.all(16),
      itemCount: weeks.length,
      itemBuilder: (context, index) {
        final week = weeks[index];
        return _buildWeekCard(month, week);
      },
    );
  }

  Widget _buildWeekCard(String month, Map<String, dynamic> weekData) {
    final key = weekKey(month, weekData['localWeekNumber']);
    final data = _calendarDataForYear[key];
    final title = data?['title'] ?? '';

    final now = DateTime.now();
    final weekStart = weekData['start'] as DateTime;
    final weekEnd = weekData['end'] as DateTime;
    // Check if today is within the start (inclusive) and end (inclusive) of the week
    final isCurrentWeek = !now.isBefore(weekStart) && now.isBefore(weekEnd.add(const Duration(days: 1)));

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: Container(
            decoration: BoxDecoration(
              color: isCurrentWeek 
                  ? Colors.amber.withOpacity(0.5)
                  : Colors.black.withOpacity(0.15),
              border: Border.all(color: Colors.white.withOpacity(0.2)),
            ),
            child: InkWell(
              onTap: () {
                _showWeekDetailsDialog(month, weekData);
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Week ${weekData['localWeekNumber']}',
                      style: const TextStyle(fontFamily: 'NotoSans', fontWeight: FontWeight.bold, fontSize: 20, color: Colors.white),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      weekData['dateRange'],
                      style: const TextStyle(fontFamily: 'NotoSans', fontSize: 14, color: Colors.white70),
                    ),
                    if (title.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      const Divider(color: Colors.white54, thickness: 0.8),
                      const SizedBox(height: 12),
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontFamily: 'NotoSans', fontSize: 16, color: Colors.white),
                      ),
                    ]
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildYearSelector() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          width: 160,
          height: 45,
          padding: const EdgeInsets.symmetric(horizontal: 12.0),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.2)),
          ),
          child: Center(
            child: Text(
              selectedAcademicYear,
              style: const TextStyle(fontFamily: 'NotoSans', fontWeight: FontWeight.bold, fontSize: 20, color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: Colors.grey[700], fontSize: 14),
      filled: true,
      fillColor: Colors.white.withOpacity(0.7),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2),
      ),
    );
  }

  void _initializeControllersForKey(String key) {
    final initialData = _calendarDataForYear[key];
    titleControllers[key] = TextEditingController(text: initialData?['title'] ?? '');
    descControllers[key] = TextEditingController(text: initialData?['description'] ?? '');
    linkControllers[key] = List<Map<String, dynamic>>.from(initialData?['links'] ?? []);
    attachmentControllers[key] = List<Map<String, dynamic>>.from(initialData?['attachments'] ?? []);
    
    pendingUploads[key] = [];
    pendingUploadNames[key] = [];
    pendingDeleteUrls[key] = [];
  }

  Future<void> _showWeekDetailsDialog(String month, Map<String, dynamic> weekData) async {
    final String key = weekKey(month, weekData['localWeekNumber']);
    _initializeControllersForKey(key);

    await showGeneralDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.2),
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      transitionDuration: const Duration(milliseconds: 350),
      pageBuilder: (context, animation, secondaryAnimation) {
        final TextEditingController linkInputController = TextEditingController();
        final TextEditingController linkTitleInputController = TextEditingController();
        bool isEditMode = false;
        bool isDirty = false;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            
            Future<bool> handlePop() async {
              if (isEditMode && isDirty) {
                final discard = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Discard Changes?'),
                    content: const Text('Are you sure you want to discard your changes?'),
                    actions: [
                      TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('No')),
                      TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Yes')),
                    ],
                  ),
                ) ?? false;
                if (discard) {
                  _initializeControllersForKey(key);
                }
                return discard;
              }
              return true;
            }

            Widget buildReadOnlyContent() {
              final title = titleControllers[key]!.text;
              final description = descControllers[key]!.text;
              final links = linkControllers[key]!;
              final attachments = attachmentControllers[key]!;
              final hasContent = title.isNotEmpty || description.isNotEmpty || links.isNotEmpty || attachments.isNotEmpty;

              if (!hasContent) {
                return Container(
                  height: 150,
                  alignment: Alignment.center,
                  child: const Text(
                    "No content added yet.",
                    style: TextStyle(fontFamily: 'NotoSans', fontStyle: FontStyle.italic, color: Colors.black54),
                  ),
                );
              }

              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (title.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8, bottom: 8.0),
                        child: Text(title, style: const TextStyle(fontFamily: 'NotoSans', fontWeight: FontWeight.bold, fontSize: 18, color: Colors.black87)),
                      ),
                    if (description.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16.0),
                        child: Text(description, style: TextStyle(fontFamily: 'NotoSans', fontSize: 14, height: 1.5, color: Colors.black.withOpacity(0.7))),
                      ),
                    if (links.isNotEmpty)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: _buildReadOnlyLinks(links),
                      ),
                    if (attachments.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: _buildReadOnlyAttachments(attachments),
                        ),
                      ),
                  ],
                ),
              );
            }

            Widget buildEditableContent() {
              return SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                     TextField(
                      controller: titleControllers[key],
                      decoration: _inputDecoration('Title'),
                      onChanged: (_) => setDialogState(() => isDirty = true),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descControllers[key],
                      decoration: _inputDecoration('Description'),
                      maxLines: 3,
                      onChanged: (_) => setDialogState(() => isDirty = true),
                    ),
                    const SizedBox(height: 20),
                    const Text("Links", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(height: 8),
                    ..._buildEditableLinks(key, linkControllers[key]!, linkInputController, linkTitleInputController, () => setDialogState(() => isDirty = true)),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const Text("Files", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: Icon(Icons.add_circle_outline_rounded, color: Theme.of(context).primaryColorDark, size: 28),
                          onPressed: () async {
                            await _pickAndAddFileToPending(key, () {
                              setDialogState(() => isDirty = true);
                            });
                          },
                        )
                      ],
                    ),
                    const SizedBox(height: 8),
                    ..._buildEditableAttachments(key, attachmentControllers[key]!, () => setDialogState(() => isDirty = true)),
                    if (pendingUploadNames[key]!.isNotEmpty) ..._buildPendingUploads(key, () => setDialogState(() {})),
                  ],
                ),
              );
            }

            return WillPopScope(
              onWillPop: handlePop,
              child: AlertDialog(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                  side: BorderSide(color: Colors.white.withOpacity(0.3), width: 1.5)
                ),
                backgroundColor: Colors.white.withOpacity(0.4),
                title: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Week ${weekData['localWeekNumber']}',
                      style: const TextStyle(fontFamily: 'NotoSans', fontWeight: FontWeight.bold, fontSize: 22, color: Colors.black87),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${weekData['dateRange']}',
                      style: TextStyle(fontFamily: 'NotoSans', fontStyle: FontStyle.italic, fontSize: 14, color: Colors.grey[800]),
                    ),
                  ],
                ),
                content: SizedBox(
                  width: double.maxFinite,
                  child: isEditMode ? buildEditableContent() : buildReadOnlyContent(),
                ),
                actionsAlignment: isEditMode ? MainAxisAlignment.spaceBetween : MainAxisAlignment.end,
                actions: isEditMode
                    ? [ // Edit mode buttons
                        TextButton(
                          child: const Text('Cancel', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                          onPressed: () async {
                            if (await handlePop()) {
                              Navigator.of(context).pop();
                            }
                          },
                        ),
                        TextButton(
                          child: Text('Save', style: TextStyle(color: Theme.of(context).primaryColorDark, fontWeight: FontWeight.bold)),
                          onPressed: () async {
                            Navigator.of(context).pop(); // Close dialog
                            await _saveSingleWeek(key, weekData['localWeekNumber']);
                            setState(() {}); // Rebuild the main screen to show updated dot/title
                          },
                        ),
                      ]
                    : [ // View mode buttons
                        IconButton(
                          icon: Icon(Icons.edit, color: Colors.black.withOpacity(0.7)),
                          onPressed: () {
                            setDialogState(() {
                              isEditMode = true;
                            });
                          },
                        ),
                      ],
              ),
            );
          },
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 4 * animation.value, sigmaY: 4 * animation.value),
          child: FadeTransition(
            opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
            child: child,
          ),
        );
      },
    ).then((_) {
      // After the dialog is popped, rebuild the main screen.
      // This is crucial to reflect any changes if save was hit.
      setState(() {});
    });
  }

  List<Widget> _buildReadOnlyLinks(List<Map<String, dynamic>> links) {
    return links.map((link) {
      String url = link['url'];
      String title = link['title'] ?? url;
      Widget? preview;
      if (url.contains('youtube.com') || url.contains('youtu.be')) {
        String? videoId = _getYoutubeId(url);
        if (videoId != null) {
          preview = ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            child: Image.network(
              'https://img.youtube.com/vi/$videoId/0.jpg',
              height: 150,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          );
        }
      }
      return Card(
        elevation: 2,
        margin: const EdgeInsets.symmetric(vertical: 6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: InkWell(
          onTap: () => launchUrl(Uri.parse(url)),
          borderRadius: BorderRadius.circular(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (preview != null) preview,
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Text(title, style: const TextStyle(color: Colors.blue, decoration: TextDecoration.underline, fontSize: 14)),
              ),
            ],
          ),
        ),
      );
    }).toList();
  }

  List<Widget> _buildReadOnlyAttachments(List<Map<String, dynamic>> attachments) {
    return attachments.map((att) {
      Widget leadingIcon;
      if (att['type'] == 'image') {
        leadingIcon = ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(att['url'], width: 40, height: 40, fit: BoxFit.cover),
        );
      } else if (att['type'] == 'pdf') {
        leadingIcon = const Icon(Icons.picture_as_pdf, color: Colors.red, size: 30);
      } else {
        leadingIcon = const Icon(Icons.insert_drive_file, color: Colors.blueGrey, size: 30);
      }
      return Card(
        elevation: 2,
        margin: const EdgeInsets.symmetric(vertical: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: ListTile(
          leading: leadingIcon,
          title: Text(att['name'], style: const TextStyle(fontSize: 14)),
          onTap: () => launchUrl(Uri.parse(att['url'])),
          trailing: const Icon(Icons.open_in_new, color: Colors.blue),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }).toList();
  }

  List<Widget> _buildEditableLinks(String key, List<Map<String, dynamic>> currentLinks, TextEditingController linkController, TextEditingController linkTitleController, VoidCallback onStateChange) {
    return [
      Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: TextField(
              controller: linkController,
              decoration: _inputDecoration('Add link URL'),
              onChanged: (_) => onStateChange(),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.add_link, color: Colors.green, size: 30),
            onPressed: () async {
              String url = linkController.text.trim();
              if (url.isNotEmpty) {
                String title = linkTitleController.text.trim();
                if (title.isEmpty) {
                  title = await fetchPageTitle(url);
                }
                currentLinks.add({'url': url, 'title': title});
                linkController.clear();
                linkTitleController.clear();
                onStateChange();
              }
            },
          ),
        ],
      ),
      const SizedBox(height: 8),
      TextField(
        controller: linkTitleController,
        decoration: _inputDecoration('Title (optional)'),
        onChanged: (_) => onStateChange(),
      ),
      const SizedBox(height: 12),
      ...currentLinks.asMap().entries.map((entry) {
        int idx = entry.key;
        String url = entry.value['url'];
        String title = entry.value['title'] ?? url;
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 4),
          elevation: 1,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          child: ListTile(
            title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text(url, maxLines: 1, overflow: TextOverflow.ellipsis),
            leading: const Icon(Icons.link, color: Colors.blue),
            trailing: IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () {
                currentLinks.removeAt(idx);
                onStateChange();
              },
            ),
          ),
        );
      }),
    ];
  }

  List<Widget> _buildEditableAttachments(String key, List<Map<String, dynamic>> currentAttachments, VoidCallback onStateChange) {
    return currentAttachments.asMap().entries.map((entry) {
      int idx = entry.key;
      var att = entry.value;
      Widget leadingIcon;
      if (att['type'] == 'image') {
        leadingIcon = Image.network(att['url'], width: 40, height: 40, fit: BoxFit.cover);
      } else if (att['type'] == 'pdf') {
        leadingIcon = const Icon(Icons.picture_as_pdf, color: Colors.red);
      } else {
        leadingIcon = const Icon(Icons.insert_drive_file, color: Colors.blueGrey);
      }
      return Card(
        margin: const EdgeInsets.symmetric(vertical: 4),
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        child: ListTile(
          leading: leadingIcon,
          title: Text(att['name'], maxLines: 1, overflow: TextOverflow.ellipsis),
          trailing: IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            onPressed: () {
              pendingDeleteUrls[key]!.add(att['url']);
              currentAttachments.removeAt(idx);
              onStateChange();
            },
          ),
        ),
      );
    }).toList();
  }

  List<Widget> _buildPendingUploads(String key, VoidCallback onStateChange) {
    return pendingUploadNames[key]!.asMap().entries.map((entry) {
      final idx = entry.key;
      final name = entry.value;
      return Card(
        margin: const EdgeInsets.symmetric(vertical: 4),
        color: Colors.orange[100],
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        child: ListTile(
          leading: const Icon(Icons.upload_file, color: Colors.orange),
          title: Text(name),
          trailing: IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            onPressed: () {
              pendingUploads[key]!.removeAt(idx);
              pendingUploadNames[key]!.removeAt(idx);
              onStateChange();
            },
          ),
        ),
      );
    }).toList();
  }

  String? _getYoutubeId(String url) {
    if (url.contains('youtube.com') || url.contains('youtu.be')) {
      if (url.contains('v=')) {
        return Uri.parse(url).queryParameters['v'];
      } else if (url.contains('youtu.be/')) {
        return url.split('youtu.be/').last.split('?').first;
      }
    }
    return null;
  }

  Future<void> _pickAndAddFileToPending(String key, VoidCallback onStateChange) async {
    // Web file upload removed - only mobile/desktop support
      FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.any);
      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        pendingUploads[key]!.add(file);
        pendingUploadNames[key]!.add(result.files.single.name);
        onStateChange();
    }
  }

  Future<void> _saveSingleWeek(String key, int localWeekNumber) async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    final parts = key.split('-');
    final month = parts[0];
    // localWeekNumber is already provided
    
    List<Map<String, dynamic>> finalAttachments = List<Map<String, dynamic>>.from(attachmentControllers[key] ?? []);

    // 1. Delete files from Storage that were removed from the UI
    if (pendingDeleteUrls[key] != null && pendingDeleteUrls[key]!.isNotEmpty) {
      for (final url in pendingDeleteUrls[key]!) {
        try {
          final ref = FirebaseStorage.instance.refFromURL(url);
          await ref.delete();
        } catch (e) {
          print('Storage silme hatası: $e');
        }
      }
    }

    // 2. Upload pending files and add them to the attachments list (mobile/desktop only)
    if (pendingUploads.containsKey(key) && pendingUploads[key]!.isNotEmpty) {
        for (var i = 0; i < pendingUploads[key]!.length; i++) {
          final file = pendingUploads[key]![i] as File;
          String fileName = pendingUploadNames[key]![i];
          String ext = fileName.split('.').last.toLowerCase();
          final calendarYear = getCalendarYearForMonth(month);
          String storagePath = 'calendar_files/$unitCoordinatorId/$calendarYear/${month}_$localWeekNumber/$fileName';
          final ref = FirebaseStorage.instance.ref().child(storagePath);
          await ref.putFile(file);
          String url = await ref.getDownloadURL();
          String type = ["jpg", "jpeg", "png", "gif", "bmp", "webp"].contains(ext) ? 'image' : (ext == 'pdf' ? 'pdf' : 'file');
          finalAttachments.add({'type': type, 'url': url, 'name': fileName});
      }
    }

    // 3. Prepare final data for Firestore
    final Map<String, dynamic> weekDataToSave = {
      'title': titleControllers[key]?.text ?? '',
      'description': descControllers[key]?.text ?? '',
      'links': linkControllers[key] ?? [],
      'attachments': finalAttachments,
    };

    // 4. Save to Firestore
    await saveWeekData(month, localWeekNumber, weekDataToSave);

    // 5. Update local state
    _calendarDataForYear[key] = weekDataToSave;
    attachmentControllers[key] = finalAttachments;
    pendingUploads[key]!.clear();
    pendingUploadNames[key]!.clear();
    pendingDeleteUrls[key]!.clear();

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> saveAllDirtyWeeks() async {
    // This function may no longer be needed if we only save one week at a time.
    // However, we can keep it for a potential "save all" feature in the future.
    if (!mounted) return;
    setState(() => _isLoading = true);

    final dirtyKeys = _calendarDataForYear.keys; // This needs to be smarter if we track dirtiness
    print("saveAllDirtyWeeks is called, but its logic needs review for the new model.");

    // for (final key in dirtyKeys) {
    //   await _saveSingleWeek(key);
    // }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> showDiscardDialogWithDetails() async {
    // This logic needs to be re-evaluated as we now handle discards per-dialog.
    print("showDiscardDialogWithDetails is called, but it's likely deprecated.");
  }

  void _discardChanges() {
    // This logic is now handled inside the dialog's cancel button.
    print("_discardChanges is called, but it's likely deprecated.");
  }
}

class _TextGlassButton extends StatelessWidget {
  final VoidCallback onTap;
  final String label;
  final Color textColor;
  final double fontSize;
  final FontWeight fontWeight;

  const _TextGlassButton({
    required this.onTap,
    required this.label,
    this.textColor = Colors.white,
    this.fontSize = 14.0,
    this.fontWeight = FontWeight.normal,
  });

  @override
  Widget build(BuildContext context) {
    return GlassmorphicContainer(
      width: 100,
      height: 40,
      borderRadius: 25,
      blur: 10,
      border: 1.5,
      linearGradient: LinearGradient(
        colors: [Colors.white.withOpacity(0.25), Colors.white.withOpacity(0.15)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderGradient: LinearGradient(
        colors: [Colors.white.withOpacity(0.5), Colors.white.withOpacity(0.2)],
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(25),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontFamily: 'NotoSans',
              color: textColor,
              fontWeight: fontWeight,
              fontSize: fontSize,
            ),
          ),
        ),
      ),
    );
  }
}