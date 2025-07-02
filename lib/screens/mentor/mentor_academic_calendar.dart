import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:ui';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

class MentorAcademicCalendarPage extends StatefulWidget {
  const MentorAcademicCalendarPage({super.key});

  @override
  State<MentorAcademicCalendarPage> createState() => _MentorAcademicCalendarPageState();
}

class _MentorAcademicCalendarPageState extends State<MentorAcademicCalendarPage> {
  final List<String> months = [
    'September', 'October', 'November', 'December', 'January', 'February',
    'March', 'April', 'May', 'June', 'July', 'August'
  ];
  String selectedAcademicYear = '2025-2026';
  String? _selectedMonth;
  String? _unitCoordinatorId; 

  final Map<String, Map<String, dynamic>> _calendarDataForYear = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeToCurrentDate();
    _fetchUnitCoordinatorIdAndLoadData();
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

  Future<void> _fetchUnitCoordinatorIdAndLoadData() async {
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
        _unitCoordinatorId = parentId;
        await _loadAllWeeksForYear();
      } else {
         if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadAllWeeksForYear() async {
    if (_unitCoordinatorId == null || _unitCoordinatorId!.isEmpty) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    
    _calendarDataForYear.clear();

    try {
      final baseRef = FirebaseFirestore.instance.collection('academicCalendars').doc(_unitCoordinatorId);
      
      final Map<String, Future<QuerySnapshot<Map<String, dynamic>>>> monthFutures = {};

      for (final month in months) {
        final calendarYear = getCalendarYearForMonth(month);
        monthFutures[month] = baseRef.collection(calendarYear.toString()).doc(month).collection('weeks').get();
      }

      final allSnapshots = await Future.wait(monthFutures.values);
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
      // ignore
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String weekKey(String month, int weekNumber) => '$month-$weekNumber';

  int getCalendarYearForMonth(String month) {
    final parts = selectedAcademicYear.split('-');
    final startYear = int.parse(parts[0]);
    final endYear = int.parse(parts[1]);
    
    if (['September', 'October', 'November', 'December'].contains(month)) {
      return startYear;
    }
    return endYear;
  }

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

    final targetMonthNumber = getMonthNumber(month);
    final targetCalendarYear = getCalendarYearForMonth(month);
    DateTime firstDayOfMonth = DateTime(targetCalendarYear, targetMonthNumber, 1);

    DateTime firstMonday = firstDayOfMonth;
    while (firstMonday.weekday != DateTime.monday) {
      firstMonday = firstMonday.add(const Duration(days: 1));
    }

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
                : _unitCoordinatorId == null 
                  ? const Center(child: Text("Your coordinator has not set up a calendar.", style: TextStyle(color: Colors.white, fontSize: 16)))
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
                        return Container();
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

  Future<void> _showWeekDetailsDialog(String month, Map<String, dynamic> weekData) async {
    final String key = weekKey(month, weekData['localWeekNumber']);
    final data = _calendarDataForYear[key];

    final title = data?['title'] ?? '';
    final description = data?['description'] ?? '';
    final links = List<Map<String, dynamic>>.from(data?['links'] ?? []);
    final attachments = List<Map<String, dynamic>>.from(data?['attachments'] ?? []);

    await showGeneralDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.2),
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      transitionDuration: const Duration(milliseconds: 350),
      pageBuilder: (context, animation, secondaryAnimation) {
        return AlertDialog(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(color: Colors.white.withOpacity(0.3), width: 1.5)
          ),
          backgroundColor: Colors.white.withOpacity(0.85),
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
            child: buildReadOnlyContent(title, description, links, attachments),
          ),
          actions: [
            TextButton(
              child: const Text('Close'),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
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
    );
  }

  Widget buildReadOnlyContent(String title, String description, List<Map<String, dynamic>> links, List<Map<String, dynamic>> attachments) {
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
          onTap: () async {
            final uri = Uri.parse(att['url']);
            if (await canLaunchUrl(uri)) {
              await launchUrl(uri);
            }
          },
          trailing: const Icon(Icons.open_in_new, color: Colors.blue),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
} 