import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:syncfusion_flutter_xlsio/xlsio.dart' as xlsio;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'dart:io';
// ignore: avoid_web_libraries_in_flutter
// HTML import removed for mobile compatibility
import 'package:csv/csv.dart';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'dart:ui';
import 'package:intl/intl.dart';

class HighSchoolAssistantCoordinatorStatsActivityCountsPage extends StatefulWidget {
  final Map<String, dynamic> filters;
  const HighSchoolAssistantCoordinatorStatsActivityCountsPage({super.key, required this.filters});

  @override
  State<HighSchoolAssistantCoordinatorStatsActivityCountsPage> createState() => _HighSchoolAssistantCoordinatorStatsActivityCountsPageState();
}

class _HighSchoolAssistantCoordinatorStatsActivityCountsPageState extends State<HighSchoolAssistantCoordinatorStatsActivityCountsPage> {
  final _firestore = FirebaseFirestore.instance;
  bool _isLoading = true;
  bool _isExporting = false;
  Map<String, dynamic> _data = {};
  String? _error;
  final ScrollController _scrollController = ScrollController();
  bool _showDownArrow = false;
  final GlobalKey _contentKey = GlobalKey();
  Map<String, int> _cityNoActivityCounts = {};
  final Map<String, bool> _cityExpanded = {};

  @override
  void initState() {
    super.initState();
    _fetchActivityCountsReport();
    _scrollController.addListener(_scrollListener);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollListener();
      _checkScrollableContent();
    });
  }

  void _checkScrollableContent() {
    final RenderBox? renderBox = _contentKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox != null) {
      final contentHeight = renderBox.size.height;
      final screenHeight = MediaQuery.of(context).size.height - 180; // AppBar ve padding çıkarıldı
      final shouldShow = contentHeight > screenHeight;
      if (_showDownArrow != shouldShow) {
        setState(() {
          _showDownArrow = shouldShow;
        });
      }
    }
  }

  void _scrollListener() {
    if (!_scrollController.hasClients) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final atBottom = _scrollController.offset >= (maxScroll - 8);
    final isScrollable = maxScroll > 0;
    if (!isScrollable && _showDownArrow) {
      setState(() => _showDownArrow = false);
    } else if (isScrollable) {
      if (atBottom && _showDownArrow) {
        setState(() => _showDownArrow = false);
      } else if (!atBottom && !_showDownArrow) {
        setState(() => _showDownArrow = true);
      }
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchActivityCountsReport() async {
    try {
      final selectedMentorUids = (widget.filters['selectedMentors'] as Map<String, bool>?)?.entries.where((e) => e.value).map((e) => e.key).toList() ?? [];
      final selectedCity = widget.filters['selectedCity'] as List<String>? ?? [];
      final selectedUnit = widget.filters['selectedUnit'] as List<String>? ?? [];
      final selectedGrades = widget.filters['selectedGrades'] as List<String>? ?? [];
      final selectedGenders = widget.filters['selectedGenders'] as List<String>? ?? [];
      final selectedActivityTypes = widget.filters['selectedActivityTypes'] as List<String>? ?? [];
      final startDate = widget.filters['startDate'] as DateTime?;
      final endDate = widget.filters['endDate'] as DateTime?;

      if (selectedMentorUids.isEmpty) {
        setState(() {
          _isLoading = false;
          _data = {};
          _error = 'Please select at least one mentor.';
        });
        return;
      }
      if (startDate == null || endDate == null) {
        setState(() {
          _isLoading = false;
          _data = {};
          _error = 'Please select a start and end date.';
        });
        return;
      }
      // 1. Get all mentee UIDs from the selected mentors
      final allMenteeUids = <String>{};
      final mentorDocs = await _firestore.collection('users').where(FieldPath.documentId, whereIn: selectedMentorUids).get();
      final Map<String, String> mentorCities = {};
      for (var mentorDoc in mentorDocs.docs) {
        final city = mentorDoc.data()['city'] ?? 'Unknown';
        mentorCities[mentorDoc.id] = city;
        final assignedMentees = List<String>.from(mentorDoc.data()['assignedTo'] ?? []);
        allMenteeUids.addAll(assignedMentees);
      }
      if (allMenteeUids.isEmpty) {
        setState(() {
          _isLoading = false;
          _data = {};
        });
        return;
      }
      // 2. Fetch all potential mentee documents first
      final menteeQuery = await _firestore
          .collection('users')
          .where(FieldPath.documentId, whereIn: allMenteeUids.toList())
          .get();
      // 3. Filter these mentees locally based on the filter criteria
      final List<DocumentSnapshot> filteredMentees = menteeQuery.docs.where((doc) {
        final data = doc.data();
        final isActive = data['isActive'] == true;
        final cityMatch = selectedCity.isNotEmpty && selectedCity.contains(data['city']);
        final schoolMatch = selectedUnit.isNotEmpty && selectedUnit.contains(data['school']);
        final gradeMatch = selectedGrades.isNotEmpty && selectedGrades.contains(data['gradeLevel']);
        final genderMatch = selectedGenders.isNotEmpty && selectedGenders.contains(data['gender']);
        return isActive && cityMatch && schoolMatch && gradeMatch && genderMatch;
      }).toList();
      final filteredMenteeUids = filteredMentees.map((doc) => doc.id).toList();
      if (filteredMenteeUids.isEmpty) {
        setState(() {
          _isLoading = false;
          _data = {};
        });
        return;
      }
      // 4. Fetch reports for selected mentors within date range
      final reportData = <String, dynamic>{}; // city > gender > school > grade > activity
      final cityNoActivityCounts = <String, int>{};
      for (String mentorId in selectedMentorUids) {
        final reportsSnapshot = await _firestore
            .collection('weekendReports')
            .doc(mentorId)
            .collection('reports')
            .get();
        for (var reportDoc in reportsSnapshot.docs) {
          final report = reportDoc.data();
          final reportId = reportDoc.id;
          // Tarih aralığı kontrolü
          DateTime? reportDate;
          try {
            // ID'nin ilk 10 karakteri tarih (yyyy-MM-dd)
            final dateStr = reportId.substring(0, 10);
            reportDate = DateTime.parse(dateStr);
          } catch (e) {
            reportDate = null;
          }
          if (reportDate == null) continue;
          if (reportDate.isBefore(startDate)) continue;
          if (reportDate.isAfter(endDate)) continue;

          final isNoActivity = report['noActivityThisWeek'] == true;
          final activityType = isNoActivity ? 'No Activity' : (report['activity'] as String?);

          final filterHasNoActivity = selectedActivityTypes.contains('No Activity');
          if (selectedActivityTypes.isNotEmpty) {
            if (isNoActivity && !filterHasNoActivity) continue;
            if (!isNoActivity && (activityType == null || !selectedActivityTypes.contains(activityType))) continue;
          }

          if (report['mentees'] is Map<String, dynamic> && (report['mentees'] as Map).isNotEmpty) {
            final reportMentees = report['mentees'] as Map<String, dynamic>;
            for (String menteeId in reportMentees.keys) {
              if (filteredMenteeUids.contains(menteeId)) {
                final menteeDoc = filteredMentees.firstWhere((doc) => doc.id == menteeId);
                final menteeData = menteeDoc.data() as Map<String, dynamic>;
                final city = menteeData['city'] ?? 'Unknown';
                final gender = menteeData['gender'] ?? 'Unknown';
                final school = menteeData['school'] ?? 'Unknown';
                final grade = menteeData['gradeLevel'] ?? 'Unknown';
                // Aggregate data: city > gender > school > grade > activity
                reportData.putIfAbsent(city, () => {});
                reportData[city].putIfAbsent(gender, () => {});
                reportData[city][gender].putIfAbsent(school, () => {});
                reportData[city][gender][school].putIfAbsent(grade, () => {});
                reportData[city][gender][school][grade].putIfAbsent(activityType, () => 0);
                reportData[city][gender][school][grade][activityType]++;
              }
            }
          } else if (isNoActivity) {
            // Mentorun city'sine göre şehir bazında No Activity sayısını artır
            final mentorCity = mentorCities[mentorId] ?? 'Unknown';
            cityNoActivityCounts[mentorCity] = (cityNoActivityCounts[mentorCity] ?? 0) + 1;
          }
        }
      }
      setState(() {
        _isLoading = false;
        _data = reportData;
        _cityNoActivityCounts = cityNoActivityCounts;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _data = {};
        _error = 'An error occurred while fetching data.';
      });
    }
  }

  // --- Calculation Methods ---

  int _calculateTotal(Map data) {
    int total = 0;
    if (data.isEmpty) return 0;
    if (data.values.every((v) => v is int)) {
      data.forEach((key, value) {
        total += (value as int? ?? 0);
      });
      return total;
    }
    data.forEach((key, value) {
      if (value is Map) {
        total += _calculateTotal(value);
      }
    });
    return total;
  }

  int _calculateOverallTotal() {
    return _calculateTotal(_data);
  }

  // --- UI Builder Methods ---

  @override
  Widget build(BuildContext context) {
    final cityKeys = _data.keys.toList();
    int overallTotal = _calculateOverallTotal();
    final startDate = widget.filters['startDate'] as DateTime?;
    final endDate = widget.filters['endDate'] as DateTime?;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Activity Counts Report',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.pop(),
        ),
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
          ),
          if (_isLoading)
            const Center(child: CircularProgressIndicator()),
          if (!_isLoading && _error != null)
            Center(child: Text(_error!, style: const TextStyle(color: Colors.white, fontSize: 18))),
          if (!_isLoading && _error == null)
            SafeArea(
              child: SingleChildScrollView(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: Column(
                  key: _contentKey,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 20),
                    const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline, color: Colors.white70, size: 16),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'This report shows activity counts grouped by city, gender, school, and grade.',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white70,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (startDate != null && endDate != null) ...[
                      const SizedBox(height: 16),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'Date Range: ${DateFormat.yMMMd().format(startDate)} - ${DateFormat.yMMMd().format(endDate)}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    if (cityKeys.isEmpty)
                      _buildEmptyState()
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: cityKeys.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 16),
                        itemBuilder: (context, cityIdx) {
                          final city = cityKeys[cityIdx];
                          final genderData =
                              Map<String, dynamic>.from(_data[city] as Map);
                          return _buildCityCard(
                            context,
                            city,
                            genderData,
                            _cityExpanded[city] ?? false,
                            (expanded) {
                              setState(() {
                                _cityExpanded[city] = expanded;
                              });
                              if (expanded) {
                                WidgetsBinding.instance.addPostFrameCallback((_) => _checkScrollableContent());
                              } else {
                                Future.delayed(const Duration(milliseconds: 350), () {
                                  if (mounted) {
                                    _checkScrollableContent();
                                  }
                                });
                              }
                            },
                          );
                        },
                      ),
                    if (cityKeys.isNotEmpty) ...[
                      const SizedBox(height: 28),
                      _buildOverallTotalCard(overallTotal),
                      const SizedBox(height: 32),
                      Center(
                        child: DownloadDropdownButton(
                          onSelected: (value) async {
                            if (value == 'excel') await _exportToExcel();
                            if (value == 'pdf') await _exportToPdf();
                            if (value == 'csv') await exportToCsv();
                            if (value == 'text') await exportToText();
                            if (value == 'html') await exportToHtml();
                          },
                        ),
                      ),
                    ]
                  ],
                ),
              ),
            ),
          if (_showDownArrow)
            Positioned(
              left: 0,
              right: 0,
              bottom: 24,
              child: Center(
                child: GestureDetector(
                  onTap: () {
                    final position = _scrollController.position;
                    if (position.hasContentDimensions && position.maxScrollExtent > 0) {
                      _scrollController.animateTo(
                        position.maxScrollExtent,
                        duration: const Duration(milliseconds: 500),
                        curve: Curves.easeOut,
                      );
                    }
                  },
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.6),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.10),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.arrow_downward,
                        size: 20,
                        color: Color(0xFF7C3AED), // purple
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildOverallTotalCard(int overallTotal) {
    return Center(
      child: IntrinsicWidth(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              height: 55,
              padding: const EdgeInsets.symmetric(horizontal: 40.0),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.5), width: 1),
              ),
              child: Center(
                child: Text(
                  'Overall Total: $overallTotal',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          width: double.infinity,
          height: 150,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.5), width: 1),
          ),
          child: const Center(
            child: Text(
              'No activity data found for the selected filters.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCityCard(
      BuildContext context,
      String city,
      Map<String, dynamic> genderData,
      bool isExpanded,
      Function(bool) onExpansionChanged,
  ) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20.0),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20.0),
            color: Colors.white.withOpacity(0.15),
            border: Border.all(
              color: Colors.white.withOpacity(0.2),
              width: 1.0,
            ),
          ),
          child: Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              childrenPadding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              title: Text(
                city,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  fontSize: 18,
                ),
              ),
              iconColor: Colors.white,
              collapsedIconColor: Colors.white,
              initiallyExpanded: isExpanded,
              onExpansionChanged: onExpansionChanged,
              children: [
                if (isExpanded && (_cityNoActivityCounts[city] ?? 0) > 0)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Row(
                      children: [
                        const Icon(Icons.not_interested, color: Colors.redAccent, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          'No Activity: ${_cityNoActivityCounts[city] ?? 0}',
                          style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                      ],
                    ),
                  ),
                ...genderData.entries.map((entry) {
                  final gender = entry.key;
                  final schoolData = Map<String, dynamic>.from(entry.value as Map);
                  return _buildCategoryBlock(
                      title: gender,
                      data: schoolData,
                      level: 0,
                      nextLevelBuilder: (school, gradeData) => _buildCategoryBlock(
                            title: school,
                            data: gradeData,
                            level: 1,
                            nextLevelBuilder: (grade, activityData) =>
                                _buildCategoryBlock(
                              title: grade,
                              data: activityData,
                              level: 2,
                              isLastLevel: true,
                            ),
                          ));
                }),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryBlock({
    required String title,
    required Map<String, dynamic> data,
    required int level,
    Widget Function(String key, Map<String, dynamic> value)? nextLevelBuilder,
    bool isLastLevel = false,
  }) {
    final colors = [
      Colors.amberAccent,
      Colors.lightBlueAccent,
      Colors.pinkAccent,
    ];
    final titleStyles = [
      const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
      const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
      const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Colors.white),
    ];

    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border(left: BorderSide(color: colors[level], width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: titleStyles[level]),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: colors[level].withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_calculateTotal(data)}',
                  style: TextStyle(
                      color: colors[level],
                      fontWeight: FontWeight.bold,
                      fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (isLastLevel)
            ...data.entries
                .map((entry) => _buildActivityRow(entry.key, entry.value))
          else if (nextLevelBuilder != null)
            ...data.entries.map((entry) =>
                nextLevelBuilder(entry.key, Map<String, dynamic>.from(entry.value as Map)))
        ],
      ),
    );
  }

  Widget _buildActivityRow(String activity, int count) {
    if (count == 0) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(left: 4.0, top: 4, bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            activity,
            style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontSize: 14,
                fontWeight: FontWeight.w400),
          ),
          Text(
            '$count',
            style: TextStyle(
                color: Colors.white.withOpacity(1),
                fontSize: 14,
                fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Future<void> _exportToExcel() async {
    setState(() => _isExporting = true);
    final workbook = xlsio.Workbook();
    final sheet = workbook.worksheets[0];
    sheet.showGridlines = false;

    // Styles
    final titleStyle = workbook.styles.add('titleStyle')
      ..fontSize = 24
      ..bold = true
      ..fontColor = '#000000'
      ..hAlign = xlsio.HAlignType.left
      ..vAlign = xlsio.VAlignType.center
      ..wrapText = true;
    final subtitleStyle = workbook.styles.add('subtitleStyle')
      ..fontSize = 11
      ..fontColor = '#555555' // Hafif gri
      ..hAlign = xlsio.HAlignType.left
      ..vAlign = xlsio.VAlignType.center
      ..wrapText = true;
    final dateStyle = workbook.styles.add('dateStyle')
      ..fontSize = 14
      ..fontColor = '#000000'
      ..bold = true
      ..hAlign = xlsio.HAlignType.left
      ..vAlign = xlsio.VAlignType.bottom
      ..wrapText = true;
    final tableHeaderStyle = workbook.styles.add('tableHeaderStyle')
      ..fontSize = 16 // Font 16
      ..bold = true
      ..fontColor = '#000000'
      ..hAlign = xlsio.HAlignType.center
      ..vAlign = xlsio.VAlignType.center
      ..backColor = '#83CCEB'
      ..borders.all.lineStyle = xlsio.LineStyle.thin
      ..borders.all.color = '#000000'
      ..wrapText = true;
    final cellStyle = workbook.styles.add('cellStyle')
      ..fontSize = 13 // Font 14
      ..fontColor = '#000000'
      ..hAlign = xlsio.HAlignType.center
      ..vAlign = xlsio.VAlignType.center
      ..borders.all.lineStyle = xlsio.LineStyle.thin
      ..borders.all.color = '#000000'
      ..wrapText = true;
    final totalTitleStyle = workbook.styles.add('totalTitleStyle')
      ..fontSize = 14
      ..bold = true
      ..fontColor = '#000000'
      ..hAlign = xlsio.HAlignType.center
      ..vAlign = xlsio.VAlignType.center
      ..backColor = '#F7C037'
      ..borders.all.lineStyle = xlsio.LineStyle.thin
      ..borders.all.color = '#000000'
      ..wrapText = true;
    final totalRowStyle = workbook.styles.add('totalRowStyle')
      ..fontSize = 13
      ..bold = true
      ..fontColor = '#000000'
      ..hAlign = xlsio.HAlignType.center
      ..vAlign = xlsio.VAlignType.center
      ..backColor = '#F7C037'
      ..borders.all.lineStyle = xlsio.LineStyle.thin
      ..borders.all.color = '#000000'
      ..wrapText = true;
    final totalValueStyle = workbook.styles.add('totalValueStyle')
      ..fontSize = 13
      ..bold = true
      ..fontColor = '#000000'
      ..hAlign = xlsio.HAlignType.center
      ..vAlign = xlsio.VAlignType.center
      ..backColor = '#F7C037'
      ..borders.all.lineStyle = xlsio.LineStyle.thin
      ..borders.all.color = '#000000'
      ..wrapText = true;

    // Set column widths (px)
    sheet.getRangeByName('A1').columnWidth = 11;
    sheet.getRangeByName('B1').columnWidth = 13;
    sheet.getRangeByName('C1').columnWidth = 17;
    sheet.getRangeByName('D1').columnWidth = 13;
    sheet.getRangeByName('F1').columnWidth = 10;
    // E sütunu (Activity Type) otomatik genişlik için sonra ayarlanacak

    int row = 1;
    // Başlık
    sheet.getRangeByIndex(row, 1, row, 6).merge();
    sheet.getRangeByIndex(row, 1).setText('Activity Counts');
    sheet.getRangeByIndex(row, 1).cellStyle = titleStyle;
    sheet.getRangeByIndex(row, 1).cellStyle.borders.all.lineStyle = xlsio.LineStyle.none;
    sheet.setRowHeightInPixels(row, 44);
    row++;
    // Açıklama
    sheet.getRangeByIndex(row, 1, row, 6).merge();
    sheet.getRangeByIndex(row, 1).setText('This report shows activity counts grouped by: Gender, School level, Grade level, and Activity type');
    sheet.getRangeByIndex(row, 1).cellStyle = subtitleStyle;
    sheet.setRowHeightInPixels(row, 26);
    row++;
    // Boş satır
    row++;
    // Date Range
    String? rangeText;
    final startDate = widget.filters['startDate'] as DateTime?;
    final endDate = widget.filters['endDate'] as DateTime?;
    if (startDate != null && endDate != null) {
      String formatDate(DateTime d) {
        final months = [
          'January', 'February', 'March', 'April', 'May', 'June',
          'July', 'August', 'September', 'October', 'November', 'December'
        ];
        return '${months[d.month - 1]} ${d.day}, ${d.year}';
      }
      rangeText = 'Date Range: ${formatDate(startDate)} - ${formatDate(endDate)}';
      sheet.getRangeByIndex(row, 1, row, 6).merge();
      sheet.getRangeByIndex(row, 1).setText(rangeText);
      sheet.getRangeByIndex(row, 1).cellStyle = dateStyle;
      sheet.getRangeByIndex(row, 1).cellStyle.hAlign = xlsio.HAlignType.left;
      sheet.getRangeByIndex(row, 1).cellStyle.vAlign = xlsio.VAlignType.bottom;
      sheet.setRowHeightInPixels(row, 21);
      row++;
    }

    // Tablo başlıkları
    final headers = ['City', 'Gender', 'School Level', 'Grade', 'Activity Type', 'Count'];
    for (int i = 0; i < headers.length; i++) {
      sheet.getRangeByIndex(row, i + 1).setText(headers[i]);
      sheet.getRangeByIndex(row, i + 1).cellStyle = tableHeaderStyle;
    }
    sheet.setRowHeightInPixels(row, 27);
    row++;

    // Tüm verileri düz tabloya ekle (grade'e göre küçükten büyüğe sıralı)
    List<Map<String, dynamic>> flatRows = [];
    _data.forEach((city, genderMap) {
      (genderMap as Map).forEach((gender, schoolMap) {
        (schoolMap as Map).forEach((school, gradeMap) {
          (gradeMap as Map).forEach((grade, activityMap) {
            (activityMap as Map).forEach((activity, count) {
              if (activity == 'No Activity' && count == 0) return; // 0 ise ekleme
              flatRows.add({
                'City': city,
                'Gender': gender,
                'School Level': school,
                'Grade': grade,
                'Activity Type': activity,
                'Count': count,
              });
            });
          });
        });
      });
    });
    // Grade sıralaması için özel bir sıralama fonksiyonu
    int gradeOrder(String grade) {
      final match = RegExp(r'^(\d+)').firstMatch(grade);
      return match != null ? int.tryParse(match.group(1) ?? '') ?? 0 : 0;
    }
    flatRows.sort((a, b) {
      int cmp = gradeOrder(a['Grade']).compareTo(gradeOrder(b['Grade']));
      if (cmp != 0) return cmp;
      return a['City'].toString().compareTo(b['City'].toString());
    });
    // Tabloya yaz
    for (final rowData in flatRows) {
      for (int i = 0; i < headers.length; i++) {
        final value = rowData[headers[i]];
        final cell = sheet.getRangeByIndex(row, i + 1);
        if (i == 5 && value is int) {
          cell.setNumber(value.toDouble());
        } else {
          cell.setText(value.toString());
        }
        cell.cellStyle = cellStyle;
      }
      sheet.setRowHeightInPixels(row, 23);
      row++;
    }

    // 2 boş satır
    row++;
    row++;
    

    // --- Toplamlar ---
    // Her grade ve cinsiyet için toplamlar
    Map<String, Map<String, int>> gradeGenderTotals = {};
    Map<String, int> genderTotals = {};
    Map<String, int> cityTotals = {};
    Map<String, int> schoolTotals = {};
    int grandTotal = 0;
    for (final rowData in flatRows) {
      final grade = rowData['Grade'];
      final gender = rowData['Gender'];
      final city = rowData['City'];
      final school = rowData['School Level'];
      final count = rowData['Count'] as int;
      gradeGenderTotals.putIfAbsent(grade, () => {});
      gradeGenderTotals[grade]![gender] = (gradeGenderTotals[grade]![gender] ?? 0) + count;
      genderTotals[gender] = (genderTotals[gender] ?? 0) + count;
      cityTotals[city] = (cityTotals[city] ?? 0) + count;
      schoolTotals[school] = (schoolTotals[school] ?? 0) + count;
      grandTotal += count;
    }
    
    // Başlık (A:D merge)
    final totalsTitleRange = sheet.getRangeByIndex(row, 1, row, 4);
    totalsTitleRange.merge();
    totalsTitleRange.setText('Totals by City, School, Grade and Gender');
    totalsTitleRange.cellStyle = totalTitleStyle;
    sheet.setRowHeightInPixels(row, 27);
    row++;

    // City toplamları
    for (final city in cityTotals.keys) {
      final range = sheet.getRangeByIndex(row, 1, row, 3);
      range.merge();
      range.setText('$city total');
      range.cellStyle = totalRowStyle;
      sheet.getRangeByIndex(row, 4).setNumber(cityTotals[city]!.toDouble());
      sheet.getRangeByIndex(row, 4).cellStyle = totalValueStyle;
      sheet.setRowHeightInPixels(row, 24);
      row++;
    }
    // School Level toplamları
    for (final school in schoolTotals.keys) {
      final range = sheet.getRangeByIndex(row, 1, row, 3);
      range.merge();
      range.setText('$school total');
      range.cellStyle = totalRowStyle;
      sheet.getRangeByIndex(row, 4).setNumber(schoolTotals[school]!.toDouble());
      sheet.getRangeByIndex(row, 4).cellStyle = totalValueStyle;
      sheet.setRowHeightInPixels(row, 24);
      row++;
    }
    // Grade + Gender toplamları
    for (final grade in gradeGenderTotals.keys) {
      for (final gender in gradeGenderTotals[grade]!.keys) {
        final range = sheet.getRangeByIndex(row, 1, row, 3);
        range.merge();
        range.setText('$gender $grade total');
        range.cellStyle = totalRowStyle;
        sheet.getRangeByIndex(row, 4).setNumber(gradeGenderTotals[grade]![gender]!.toDouble());
        sheet.getRangeByIndex(row, 4).cellStyle = totalValueStyle;
        sheet.setRowHeightInPixels(row, 24);
        row++;
      }
    }
    // Genel cinsiyet toplamları
    for (final gender in genderTotals.keys) {
      final range = sheet.getRangeByIndex(row, 1, row, 3);
      range.merge();
      range.setText('All $gender total');
      range.cellStyle = totalRowStyle;
      sheet.getRangeByIndex(row, 4).setNumber(genderTotals[gender]!.toDouble());
      sheet.getRangeByIndex(row, 4).cellStyle = totalValueStyle;
      sheet.setRowHeightInPixels(row, 24);
      row++;
    }
    // Grand total
    final range = sheet.getRangeByIndex(row, 1, row, 3);
    range.merge();
    range.setText('Grand Total');
    range.cellStyle = totalRowStyle;
    sheet.getRangeByIndex(row, 4).setNumber(grandTotal.toDouble());
    sheet.getRangeByIndex(row, 4).cellStyle = totalValueStyle;
    sheet.setRowHeightInPixels(row, 24);
    row++;

    // E sütunu (Activity Type) genişliğini otomatik ayarla
    sheet.autoFitColumn(5);

    final List<int> bytes = workbook.saveAsStream();
    workbook.dispose();
    // Web download removed - only mobile/desktop support
    final directory = await getApplicationDocumentsDirectory();
    final path = '${directory.path}/Activity Counts.xlsx';
    final file = File(path);
    await file.writeAsBytes(bytes, flush: true);
    setState(() => _isExporting = false);
    OpenFile.open(path);
  }

  Future<void> _exportToPdf() async {
    setState(() => _isExporting = true);
    final pdf = pw.Document();
    // Load NotoSans fonts from assets/fonts/
    final fontData = await rootBundle.load('assets/fonts/NotoSans-Regular.ttf');
    final boldFontData = await rootBundle.load('assets/fonts/NotoSans-Bold.ttf');
    final notoFont = pw.Font.ttf(fontData);
    final notoBoldFont = pw.Font.ttf(boldFontData);
    // Colors
    final tableHeaderColor = PdfColor.fromHex('#83CCEB');
    final totalBgColor = PdfColor.fromHex('#F7C037');
    final borderColor = PdfColors.black;
    // Prepare flatRows as in Excel export
    List<Map<String, dynamic>> flatRows = [];
    _data.forEach((city, genderMap) {
      (genderMap as Map).forEach((gender, schoolMap) {
        (schoolMap as Map).forEach((school, gradeMap) {
          (gradeMap as Map).forEach((grade, activityMap) {
            (activityMap as Map).forEach((activity, count) {
              if (activity == 'No Activity' && count == 0) return; // 0 ise ekleme
              flatRows.add({
                'City': city,
                'Gender': gender,
                'School Level': school,
                'Grade': grade,
                'Activity Type': activity,
                'Count': count,
              });
            });
          });
        });
      });
    });
    int gradeOrder(String grade) {
      final match = RegExp(r'^(\\d+)').firstMatch(grade);
      return match != null ? int.tryParse(match.group(1) ?? '') ?? 0 : 0;
    }
    flatRows.sort((a, b) {
      int cmp = gradeOrder(a['Grade']).compareTo(gradeOrder(b['Grade']));
      if (cmp != 0) return cmp;
      return a['City'].toString().compareTo(b['City'].toString());
    });
    // Totals
    Map<String, Map<String, int>> gradeGenderTotals = {};
    Map<String, int> genderTotals = {};
    Map<String, int> cityTotals = {};
    Map<String, int> schoolTotals = {};
    int grandTotal = 0;
    for (final rowData in flatRows) {
      final grade = rowData['Grade'];
      final gender = rowData['Gender'];
      final city = rowData['City'];
      final school = rowData['School Level'];
      final count = rowData['Count'] as int;
      gradeGenderTotals.putIfAbsent(grade, () => {});
      gradeGenderTotals[grade]![gender] = (gradeGenderTotals[grade]![gender] ?? 0) + count;
      genderTotals[gender] = (genderTotals[gender] ?? 0) + count;
      cityTotals[city] = (cityTotals[city] ?? 0) + count;
      schoolTotals[school] = (schoolTotals[school] ?? 0) + count;
      grandTotal += count;
    }
    // PDF page
    pdf.addPage(
      pw.MultiPage(
        margin: const pw.EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        build: (pw.Context context) {
          List<pw.Widget> widgets = [];
          // Title
          widgets.add(
            pw.Container(
              padding: const pw.EdgeInsets.only(bottom: 6),
              child: pw.Text('Activity Counts', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: PdfColors.black, font: notoBoldFont)),
            ),
          );
          widgets.add(
            pw.Container(
              padding: const pw.EdgeInsets.only(bottom: 8),
              child: pw.Text('This report shows activity counts grouped by: Gender, School level, Grade level, and Activity type', style: pw.TextStyle(fontSize: 11, color: PdfColors.grey600, font: notoFont)),
            ),
          );
          // Date Range
          final startDate = widget.filters['startDate'] as DateTime?;
          final endDate = widget.filters['endDate'] as DateTime?;
          if (startDate != null && endDate != null) {
            String formatDate(DateTime d) {
              final months = [
                'January', 'February', 'March', 'April', 'May', 'June',
                'July', 'August', 'September', 'October', 'November', 'December'
              ];
              return '${months[d.month - 1]} ${d.day}, ${d.year}';
            }
            widgets.add(
              pw.Container(
                alignment: pw.Alignment.bottomLeft,
                padding: const pw.EdgeInsets.only(bottom: 10),
                child: pw.Text('Date Range: ${formatDate(startDate)} - ${formatDate(endDate)}', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.black, font: notoBoldFont)),
              ),
            );
          }
          // Table headers
          final headers = ['City', 'Gender', 'School Level', 'Grade', 'Activity Type', 'Count'];
          widgets.add(
            pw.Table(
              border: pw.TableBorder.all(color: borderColor, width: 0.7),
              defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
              children: [
                pw.TableRow(
                  decoration: pw.BoxDecoration(color: tableHeaderColor),
                  children: [
                    for (final h in headers)
                      pw.Container(
                        alignment: pw.Alignment.center,
                        padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 2),
                        child: pw.Text(h, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.black, font: notoBoldFont)),
                      ),
                  ],
                ),
                ...flatRows.map((rowData) => pw.TableRow(
                  decoration: pw.BoxDecoration(color: PdfColors.white),
                  children: [
                    for (int i = 0; i < headers.length; i++)
                      pw.Container(
                        alignment: pw.Alignment.center,
                        padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                        child: pw.Text(
                          i == 5 ? rowData[headers[i]].toString() : rowData[headers[i]].toString(),
                          style: pw.TextStyle(fontSize: 13, color: PdfColors.black, font: notoFont),
                        ),
                      ),
                  ],
                )),
              ],
            ),
          );
          widgets.add(pw.SizedBox(height: 18));
          // Totals Title (yellow, only first two columns, with border)
          widgets.add(
            pw.Container(
              width: 270, // toplam tablo genişliği kadar
              padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 8),
              decoration: pw.BoxDecoration(
                color: totalBgColor,
                border: pw.Border.all(color: borderColor, width: 1),
              ),
              alignment: pw.Alignment.center,
              child: pw.Text(
                'Totals by City, School, Grade and Gender',
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.black,
                  font: notoBoldFont,
                ),
              ),
            ),
          );
          // Helper for yellow total rows
          pw.Widget totalRow(String label, String value) {
            return pw.Row(
              mainAxisSize: pw.MainAxisSize.min,
              children: [
                pw.Container(
                  width: 220,
                  padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                  decoration: pw.BoxDecoration(
                    color: totalBgColor,
                    border: pw.Border.all(color: borderColor, width: 1),
                  ),
                  alignment: pw.Alignment.center,
                  child: pw.Text(label, textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: PdfColors.black, font: notoBoldFont)),
                ),
                pw.Container(
                  width: 50,
                  alignment: pw.Alignment.center,
                  padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                  decoration: pw.BoxDecoration(
                    color: totalBgColor,
                    border: pw.Border.all(color: borderColor, width: 1),
                  ),
                  child: pw.Text(value, textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: PdfColors.black, font: notoBoldFont)),
                ),
              ],
            );
          }
          // City totals
          for (final city in cityTotals.keys) {
            widgets.add(totalRow('$city total', cityTotals[city].toString()));
          }
          // School totals
          for (final school in schoolTotals.keys) {
            widgets.add(totalRow('$school total', schoolTotals[school].toString()));
          }
          // Grade + Gender totals
          for (final grade in gradeGenderTotals.keys) {
            for (final gender in gradeGenderTotals[grade]!.keys) {
              widgets.add(totalRow('$gender $grade total', gradeGenderTotals[grade]![gender].toString()));
            }
          }
          // Gender totals
          for (final gender in genderTotals.keys) {
            widgets.add(totalRow('All $gender total', genderTotals[gender].toString()));
          }
          // Grand total
          widgets.add(totalRow('Grand Total', grandTotal.toString()));
          return widgets;
        },
      ),
    );
    final bytes = await pdf.save();
    // Web download removed - only mobile/desktop support  
    final directory = await getApplicationDocumentsDirectory();
    final path = '${directory.path}/Activity Counts.pdf';
    final file = File(path);
    await file.writeAsBytes(bytes, flush: true);
    setState(() => _isExporting = false);
    OpenFile.open(path);
  }

  Future<void> exportToCsv() async {
    List<List<String>> rows = [];
    // Sadece temel başlıklar
    rows.add([
      'city',
      'gender',
      'school',
      'grade',
      'activity_type',
      'count',
    ]);
    // Düzleştirilmiş veri (flatRows mantığı)
    List<Map<String, dynamic>> flatRows = [];
    _data.forEach((city, genderMap) {
      (genderMap as Map).forEach((gender, schoolMap) {
        (schoolMap as Map).forEach((school, gradeMap) {
          (gradeMap as Map).forEach((grade, activityMap) {
            (activityMap as Map).forEach((activity, count) {
              if (activity == 'No Activity' && count == 0) return; // 0 ise ekleme
              flatRows.add({
                'city': city,
                'gender': gender,
                'school': school,
                'grade': grade,
                'activity_type': activity,
                'count': count,
              });
            });
          });
        });
      });
    });
    // Satırları ekle
    for (final row in flatRows) {
      rows.add([
        row['city'] ?? '',
        row['gender'] ?? '',
        row['school'] ?? '',
        row['grade'] ?? '',
        row['activity_type'] ?? '',
        row['count'].toString(),
      ]);
    }
    String csvData = const ListToCsvConverter().convert(rows);
    final bytes = utf8.encode(csvData);
    // Web download removed - only mobile/desktop support
    final directory = await getApplicationDocumentsDirectory();
    final path = '${directory.path}/Activity Counts.csv';
    final file = File(path);
    await file.writeAsBytes(bytes, flush: true);
    OpenFile.open(path);
  }

  Future<void> exportToText() async {
    List<String> lines = [];
    lines.add('city | gender | school | grade | activity_type | count');
    List<Map<String, dynamic>> flatRows = [];
    _data.forEach((city, genderMap) {
      (genderMap as Map).forEach((gender, schoolMap) {
        (schoolMap as Map).forEach((school, gradeMap) {
          (gradeMap as Map).forEach((grade, activityMap) {
            (activityMap as Map).forEach((activity, count) {
              if (activity == 'No Activity' && count == 0) return; // 0 ise ekleme
              flatRows.add({
                'city': city,
                'gender': gender,
                'school': school,
                'grade': grade,
                'activity_type': activity,
                'count': count,
              });
            });
          });
        });
      });
    });
    for (final row in flatRows) {
      lines.add([
        row['city'] ?? '',
        row['gender'] ?? '',
        row['school'] ?? '',
        row['grade'] ?? '',
        row['activity_type'] ?? '',
        row['count'].toString(),
      ].join(' | '));
    }
    final bytes = utf8.encode(lines.join('\n'));
    // Web download removed - only mobile/desktop support
    final directory = await getApplicationDocumentsDirectory();
    final path = '${directory.path}/Activity Counts.txt';
    final file = File(path);
    await file.writeAsBytes(bytes, flush: true);
    OpenFile.open(path);
  }

  Future<void> exportToHtml() async {
    final buffer = StringBuffer();
    buffer.writeln('<!DOCTYPE html>');
    buffer.writeln('<html lang="en"><head><meta charset="UTF-8"><title>Activity Counts</title>');
    buffer.writeln('<style>');
    buffer.writeln('body { font-family: Arial, sans-serif; background: #fff; }');
    buffer.writeln('h1 { color: #222; }');
    buffer.writeln('h2 { color: #333; }');
    buffer.writeln('table { border-collapse: collapse; margin-bottom: 32px; }');
    buffer.writeln('th, td { border: 1px solid #000; padding: 8px; text-align: center; font-size: 14px; }');
    buffer.writeln('th { background: #83CCEB; color: #000; font-weight: bold; }');
    buffer.writeln('.totals-title { background: #F7C037; color: #000; font-weight: bold; font-size: 15px; border: 1px solid #000; text-align: center; }');
    buffer.writeln('.totals-cell { background: #F7C037; color: #000; font-weight: bold; border: 1px solid #000; text-align: center; }');
    buffer.writeln('</style></head><body>');
    // Başlık
    buffer.writeln('<h1>Activity Counts</h1>');
    buffer.writeln('<div style="color:#555;font-size:15px;margin-bottom:8px;">This report shows activity counts grouped by: Gender, School level, Grade level, and Activity type</div>');
    // Tarih aralığı
    final startDate = widget.filters['startDate'] as DateTime?;
    final endDate = widget.filters['endDate'] as DateTime?;
    if (startDate != null && endDate != null) {
      String formatDate(DateTime d) {
        final months = [
          'January', 'February', 'March', 'April', 'May', 'June',
          'July', 'August', 'September', 'October', 'November', 'December'
        ];
        return '${months[d.month - 1]} ${d.day}, ${d.year}';
      }
      buffer.writeln('<div style="font-size:15px;font-weight:bold;margin-bottom:16px;text-align:left;vertical-align:bottom;">Date Range: ${formatDate(startDate)} - ${formatDate(endDate)}</div>');
    }
    // Ana tablo
    final headers = ['City', 'Gender', 'School Level', 'Grade', 'Activity Type', 'Count'];
    List<Map<String, dynamic>> flatRows = [];
    _data.forEach((city, genderMap) {
      (genderMap as Map).forEach((gender, schoolMap) {
        (schoolMap as Map).forEach((school, gradeMap) {
          (gradeMap as Map).forEach((grade, activityMap) {
            (activityMap as Map).forEach((activity, count) {
              if (activity == 'No Activity' && count == 0) return; // 0 ise ekleme
              flatRows.add({
                'City': city,
                'Gender': gender,
                'School Level': school,
                'Grade': grade,
                'Activity Type': activity,
                'Count': count,
              });
            });
          });
        });
      });
    });
    int gradeOrder(String grade) {
      final match = RegExp(r'^(\\d+)').firstMatch(grade);
      return match != null ? int.tryParse(match.group(1) ?? '') ?? 0 : 0;
    }
    flatRows.sort((a, b) {
      int cmp = gradeOrder(a['Grade']).compareTo(gradeOrder(b['Grade']));
      if (cmp != 0) return cmp;
      return a['City'].toString().compareTo(b['City'].toString());
    });
    buffer.writeln('<table>');
    buffer.writeln('<tr>${headers.map((h) => '<th>$h</th>').join('')}</tr>');
    for (final row in flatRows) {
      buffer.writeln('<tr>${headers.map((h) => '<td>${row[h] ?? ''}</td>').join('')}</tr>');
    }
    buffer.writeln('</table>');
    // Totals hesaplama
    Map<String, Map<String, int>> gradeGenderTotals = {};
    Map<String, int> genderTotals = {};
    Map<String, int> cityTotals = {};
    Map<String, int> schoolTotals = {};
    int grandTotal = 0;
    for (final rowData in flatRows) {
      final grade = rowData['Grade'];
      final gender = rowData['Gender'];
      final city = rowData['City'];
      final school = rowData['School Level'];
      final count = rowData['Count'] as int;
      gradeGenderTotals.putIfAbsent(grade, () => {});
      gradeGenderTotals[grade]![gender] = (gradeGenderTotals[grade]![gender] ?? 0) + count;
      genderTotals[gender] = (genderTotals[gender] ?? 0) + count;
      cityTotals[city] = (cityTotals[city] ?? 0) + count;
      schoolTotals[school] = (schoolTotals[school] ?? 0) + count;
      grandTotal += count;
    }
    // Totals tablosu
    buffer.writeln('<table style="margin-top:24px;">');
    buffer.writeln('<tr><td class="totals-title" colspan="2">Totals by City, School, Grade and Gender</td></tr>');
    for (final city in cityTotals.keys) {
      buffer.writeln('<tr><td class="totals-cell">$city total</td><td class="totals-cell">${cityTotals[city]}</td></tr>');
    }
    for (final school in schoolTotals.keys) {
      buffer.writeln('<tr><td class="totals-cell">$school total</td><td class="totals-cell">${schoolTotals[school]}</td></tr>');
    }
    for (final grade in gradeGenderTotals.keys) {
      for (final gender in gradeGenderTotals[grade]!.keys) {
        buffer.writeln('<tr><td class="totals-cell">$gender $grade total</td><td class="totals-cell">${gradeGenderTotals[grade]![gender]}</td></tr>');
      }
    }
    for (final gender in genderTotals.keys) {
      buffer.writeln('<tr><td class="totals-cell">All $gender total</td><td class="totals-cell">${genderTotals[gender]}</td></tr>');
    }
    buffer.writeln('<tr><td class="totals-cell">Grand Total</td><td class="totals-cell">$grandTotal</td></tr>');
    buffer.writeln('</table>');
    buffer.writeln('</body></html>');
    final bytes = utf8.encode(buffer.toString());
    // Web download removed - only mobile/desktop support
    final directory = await getApplicationDocumentsDirectory();
    final path = '${directory.path}/Activity Counts.html';
    final file = File(path);
    await file.writeAsBytes(bytes, flush: true);
    OpenFile.open(path);
  }
}

class DownloadDropdownButton extends StatelessWidget {
  final void Function(String) onSelected;
  const DownloadDropdownButton({super.key, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'Download',
      offset: const Offset(0, 40),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onSelected: onSelected,
      child: ElevatedButton.icon(
        icon: const Icon(Icons.download, color: Color(0xFF4B2FE8)),
        label: const Text('Download', style: TextStyle(color: Color(0xFF2D115C), fontWeight: FontWeight.bold)),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFB8AFFF), // fallback for gradient
          foregroundColor: const Color(0xFF2D115C),
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
          elevation: 6,
          shadowColor: Colors.deepPurple.withOpacity(0.3),
        ).copyWith(
          backgroundColor: WidgetStateProperty.resolveWith<Color>((states) {
            if (states.contains(WidgetState.pressed) || states.contains(WidgetState.hovered) || states.contains(WidgetState.focused)) {
              return const Color(0xFF8EC5FC);
            }
            return Colors.transparent;
          }),
          // Use a decoration for gradient
          surfaceTintColor: WidgetStateProperty.all(Colors.transparent),
          overlayColor: WidgetStateProperty.all(const Color(0xFFE0C3FC).withOpacity(0.18)),
        ),
        onPressed: null, // disables default tap, only dropdown works
      ),
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'excel',
          child: Row(
            children: const [
              Icon(Icons.table_chart, color: Colors.green),
              SizedBox(width: 8),
              Text('Microsoft Excel'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'pdf',
          child: Row(
            children: const [
              Icon(Icons.picture_as_pdf, color: Colors.red),
              SizedBox(width: 8),
              Text('Adobe PDF'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'csv',
          child: Row(
            children: const [
              Icon(Icons.text_snippet, color: Colors.blue),
              SizedBox(width: 8),
              Text('CSV'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'text',
          child: Row(
            children: const [
              Icon(Icons.description, color: Colors.grey),
              SizedBox(width: 8),
              Text('Text'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'html',
          child: Row(
            children: const [
              Icon(Icons.language, color: Colors.orange),
              SizedBox(width: 8),
              Text('HTML'),
            ],
          ),
        ),
      ],
    );
  }
} 