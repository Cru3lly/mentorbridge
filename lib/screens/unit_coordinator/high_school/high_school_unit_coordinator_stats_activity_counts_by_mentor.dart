import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:ui';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_xlsio/xlsio.dart' as xlsio;
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'dart:io';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:flutter/services.dart';
import 'package:csv/csv.dart';
import 'dart:convert';

class HighSchoolUnitCoordinatorStatsActivityCountsByMentorPage extends StatefulWidget {
  final Map<String, dynamic> filters;
  const HighSchoolUnitCoordinatorStatsActivityCountsByMentorPage({super.key, required this.filters});

  @override
  State<HighSchoolUnitCoordinatorStatsActivityCountsByMentorPage> createState() => _HighSchoolUnitCoordinatorStatsActivityCountsByMentorPageState();
}

class _HighSchoolUnitCoordinatorStatsActivityCountsByMentorPageState extends State<HighSchoolUnitCoordinatorStatsActivityCountsByMentorPage> {
  final _firestore = FirebaseFirestore.instance;
  bool _isLoading = true;
  bool _isExporting = false;
  List<String> _activityTypes = [];
  List<Map<String, dynamic>> _mentorRows = [];
  String? _error;
  final ScrollController _scrollController = ScrollController();
  bool _showDownArrow = false;
  final GlobalKey _contentKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _fetchMentorActivityCounts();
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
      final screenHeight = MediaQuery.of(context).size.height - 180;
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

  Future<void> _fetchMentorActivityCounts() async {
    setState(() { _isLoading = true; });
    try {
      final selectedCity = widget.filters['selectedCity'] as List<String>? ?? [];
      final selectedUnit = widget.filters['selectedUnit'] as List<String>? ?? [];
      final selectedGrades = widget.filters['selectedGrades'] as List<String>? ?? [];
      final selectedGenders = widget.filters['selectedGenders'] as List<String>? ?? [];
      final selectedActivityTypes = widget.filters['selectedActivityTypes'] as List<String>? ?? [];
      final startDate = widget.filters['startDate'] as DateTime?;
      final endDate = widget.filters['endDate'] as DateTime?;
      final selectedMentorsMap = widget.filters['selectedMentors'] as Map<String, bool>? ?? {};
      final selectedMentorUids = selectedMentorsMap.entries.where((e) => e.value).map((e) => e.key).toList();

      final mentorsSnapshot = await _firestore.collection('users').where('role', isEqualTo: 'mentor').get();
      List<String> mentorIds = mentorsSnapshot.docs.map((d) => d.id).toList();
      Map<String, String> mentorNames = {for (var d in mentorsSnapshot.docs) d.id: '${d['firstName'] ?? ''} ${d['lastName'] ?? ''}'};
      // In-memory filtering if selectedMentorUids is not empty
      if (selectedMentorUids.isNotEmpty) {
        mentorIds = mentorIds.where((id) => selectedMentorUids.contains(id)).toList();
        mentorNames = {for (var id in mentorIds) id: mentorNames[id] ?? ''};
      }

      // 1. Tüm activity type'ları topla (filtrede seçili varsa onu kullan, yoksa global topla)
      Set<String> allActivityTypes = {};
      if (selectedActivityTypes.isNotEmpty) {
        allActivityTypes.addAll(selectedActivityTypes);
      } else {
        // Tüm mentorların tüm raporlarını gezip, unique activity type'ları topla
        for (final mentorId in mentorIds) {
          final reportsSnapshot = await _firestore.collection('weekendReports').doc(mentorId).collection('reports').get();
          for (final doc in reportsSnapshot.docs) { 
            final data = doc.data();
            final isNoActivity = data['noActivityThisWeek'] == true;
            final activityType = isNoActivity ? 'No Activity' : (data['activity'] ?? '');
            if (activityType != null && activityType.toString().isNotEmpty) {
              allActivityTypes.add(activityType);
            }
          }
        }
      }
      allActivityTypes.add('No Activity'); // Her durumda ekle
      final activityTypes = allActivityTypes.where((type) => type.toString().isNotEmpty).toList()..sort();

      // 2. Her mentor için, seçili tarih aralığındaki raporlarını bul ve activity type countlarını hesapla
      List<Map<String, dynamic>> mentorRows = [];
      for (final mentorId in mentorIds) {
        final reportsSnapshot = await _firestore.collection('weekendReports').doc(mentorId).collection('reports').get();
        Map<String, int> counts = {for (var t in activityTypes) t: 0};
        for (final doc in reportsSnapshot.docs) {
          final data = doc.data();
          final isNoActivity = data['noActivityThisWeek'] == true;
          final activityType = isNoActivity ? 'No Activity' : (data['activity'] ?? '');
          // Tarih filtresi: önce startdate, yoksa doc.id
          String? dateStr = data['startdate'];
          if (dateStr == null || dateStr.isEmpty) {
            final reportId = doc.id;
            if (reportId.length >= 10) {
              dateStr = reportId.substring(0, 10);
            } else {
              dateStr = '';
            }
          }
          DateTime? reportDate;
          try {
            reportDate = DateTime.parse(dateStr ?? '');
          } catch (e) {
            continue;
          }
          if (startDate != null && reportDate.isBefore(startDate)) continue;
          if (endDate != null && reportDate.isAfter(endDate)) continue;
          if (activityType != null && activityType.toString().isNotEmpty && counts.containsKey(activityType)) {
            counts[activityType] = (counts[activityType] ?? 0) + 1;
          }
        }
        int total = counts.values.fold(0, (a, b) => a + b);
        if (total > 0) {
          mentorRows.add({
            'mentorName': mentorNames[mentorId] ?? '',
            'activityTypeCounts': counts,
            'total': total,
          });
        }
      }
      setState(() {
        _isLoading = false;
        _activityTypes = activityTypes;
        _mentorRows = mentorRows;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = 'An error occurred while fetching data.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final startDate = widget.filters['startDate'] as DateTime?;
    final endDate = widget.filters['endDate'] as DateTime?;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Activity Counts\nby Mentor Report',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
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
                            'This report shows activity counts for each mentor, grouped by activity type.',
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
                    if (_mentorRows.isEmpty)
                      _buildEmptyState()
                    else ...[
                      _buildGlassmorphicTable(),
                      const SizedBox(height: 32),
                      Center(
                        child: DownloadDropdownButton(
                          onSelected: (value) async {
                            if (value == 'excel') await _exportToExcel();
                            if (value == 'pdf') await _exportToPdf();
                            if (value == 'csv') await _exportToCsvCrosstab();
                            if (value == 'text') await _exportToTextCrosstab();
                            if (value == 'html') await _exportToHtmlCrosstab();
                            // Diğer formatlar daha sonra eklenecek
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

  Widget _buildGlassmorphicTable() {
    if (_mentorRows.isEmpty) {
      return const Center(
        child: Text(
          'No data found for the selected filters.',
          style: TextStyle(color: Colors.white70, fontSize: 16)
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _mentorRows.length,
      separatorBuilder: (context, index) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        final row = _mentorRows[index];
        final mentorName = row['mentorName'] ?? 'Unknown Mentor';
        final activityCounts = row['activityTypeCounts'] as Map<String, dynamic>;
    
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
                  iconColor: Colors.white,
                  collapsedIconColor: Colors.white,
                  title: Text(
                    mentorName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  onExpansionChanged: (expanded) {
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
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: Column(
                        children: [
                          ..._activityTypes.where((type) => (activityCounts[type] ?? 0) > 0).map((type) {
                            final count = activityCounts[type] ?? 0;
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6.0),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    type,
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 15,
                                    ),
                                  ),
                                  Text(
                                    count.toString(),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 15,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                          const Divider(color: Colors.white24, height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Total',
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              Text(
                                row['total'].toString(),
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                            ],
                          ),
                        ]
                      ),
                    )
                  ],
                ),
              ),
            ),
          ),
        );
      },
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

  Future<void> _exportToExcel() async {
    if (_isExporting) return;
    setState(() => _isExporting = true);

    final workbook = xlsio.Workbook();
    final sheet = workbook.worksheets[0];
    sheet.showGridlines = false;

    // Styles
    final titleStyle = workbook.styles.add('titleStyle')
      ..fontSize = 24
      ..bold = true
      ..hAlign = xlsio.HAlignType.left
      ..vAlign = xlsio.VAlignType.center;
    final subtitleStyle = workbook.styles.add('subtitleStyle')
      ..fontSize = 11
      ..fontColor = '#555555'
      ..hAlign = xlsio.HAlignType.left
      ..vAlign = xlsio.VAlignType.center;
    final dateStyle = workbook.styles.add('dateStyle')
      ..fontSize = 14
      ..bold = true
      ..hAlign = xlsio.HAlignType.left
      ..vAlign = xlsio.VAlignType.bottom;
    final headerStyle = workbook.styles.add('headerStyle')
      ..fontSize = 12
      ..bold = true
      ..hAlign = xlsio.HAlignType.center
      ..vAlign = xlsio.VAlignType.center
      ..backColor = '#83CCEB'
      ..borders.all.lineStyle = xlsio.LineStyle.thin
      ..borders.all.color = '#000000';
    final rotatedHeaderStyle = workbook.styles.add('rotatedHeaderStyle')
      ..fontSize = 11
      ..bold = true
      ..hAlign = xlsio.HAlignType.center
      ..vAlign = xlsio.VAlignType.center
      ..rotation = 90
      ..backColor = '#83CCEB'
      ..borders.all.lineStyle = xlsio.LineStyle.thin
      ..borders.all.color = '#000000';
    final cellStyle = workbook.styles.add('cellStyle')
      ..fontSize = 11
      ..hAlign = xlsio.HAlignType.center
      ..vAlign = xlsio.VAlignType.center
      ..borders.all.lineStyle = xlsio.LineStyle.thin
      ..borders.all.color = '#000000';
    final totalRowStyle = workbook.styles.add('totalRowStyle')
      ..fontSize = 11
      ..bold = true
      ..hAlign = xlsio.HAlignType.center
      ..vAlign = xlsio.VAlignType.center
      ..backColor = '#F7C037'
      ..borders.all.lineStyle = xlsio.LineStyle.thin
      ..borders.all.color = '#000000';

    int row = 1;

    // Title
    sheet.getRangeByIndex(row, 1, row, _activityTypes.length + 2).merge();
    sheet.getRangeByIndex(row, 1)
      ..setText('Activity Counts by Mentor')
      ..cellStyle = titleStyle;
    sheet.setRowHeightInPixels(row, 30);
    row++;

    // Subtitle
    sheet.getRangeByIndex(row, 1, row, _activityTypes.length + 2).merge();
    sheet.getRangeByIndex(row, 1)
      ..setText('This report shows activity counts by Mentor grouped by Activity type')
      ..cellStyle = subtitleStyle;
    sheet.setRowHeightInPixels(row, 38);
    sheet.getRangeByIndex(row, 1).cellStyle.hAlign = xlsio.HAlignType.left;
    sheet.getRangeByIndex(row, 1).cellStyle.vAlign = xlsio.VAlignType.center;
    sheet.getRangeByIndex(row, 1).cellStyle.wrapText = true;
    row++;
    row++;

    // Date Range
    final startDate = widget.filters['startDate'] as DateTime?;
    final endDate = widget.filters['endDate'] as DateTime?;
    if (startDate != null && endDate != null) {
      final rangeText = 'Date Range: ${DateFormat.yMMMd().format(startDate)} - ${DateFormat.yMMMd().format(endDate)}';
      sheet.getRangeByIndex(row, 1, row, _activityTypes.length + 2).merge();
      sheet.getRangeByIndex(row, 1)
        ..setText(rangeText)
        ..cellStyle = dateStyle;
      sheet.getRangeByIndex(row, 1).cellStyle.fontSize = 13;
      row++;
    }
    // Add a blank row with height 13 pixels after date range
    sheet.setRowHeightInPixels(row, 13);
    row++;

    // Add Activity Type merged header in row 6 (B6:...)
    final excelActivityTypes = _activityTypes.where((t) => t != 'No Activity').toList();
    final activityTypeStartCol = 2;
    final activityTypeEndCol = 1 + excelActivityTypes.length;
    // Merge B6:E6 (or as many as needed)
    sheet.getRangeByIndex(row, activityTypeStartCol, row, activityTypeEndCol).merge();
    sheet.getRangeByIndex(row, activityTypeStartCol)
      ..setText('Activity Type')
      ..cellStyle = headerStyle;
    // Set blue background and borders for merged cell
    for (int c = activityTypeStartCol; c <= activityTypeEndCol; c++) {
      sheet.getRangeByIndex(row, c).cellStyle.backColor = '#83CCEB';
      sheet.getRangeByIndex(row, c).cellStyle.borders.all.lineStyle = xlsio.LineStyle.thin;
      sheet.getRangeByIndex(row, c).cellStyle.borders.all.color = '#000000';
    }
    // Merge 'Mentor' and 'Total' headers vertically (row 6-7)
    sheet.getRangeByIndex(row, 1, row + 1, 1).merge();
    sheet.getRangeByIndex(row, 1)
      ..setText('Mentor')
      ..cellStyle = headerStyle;
    sheet.getRangeByIndex(row, excelActivityTypes.length + 2, row + 1, excelActivityTypes.length + 2).merge();
    sheet.getRangeByIndex(row, excelActivityTypes.length + 2)
      ..setText('Total')
      ..cellStyle = headerStyle;
    // Activity type rotated headers (row 7)
    for (int i = 0; i < excelActivityTypes.length; i++) {
      final cell = sheet.getRangeByIndex(row + 1, i + 2)
        ..setText(excelActivityTypes[i])
        ..cellStyle = rotatedHeaderStyle;
      cell.cellStyle.wrapText = true;
    }
    // Set all borders for header area
    for (int r = row; r <= row + 1; r++) {
      for (int c = 1; c <= excelActivityTypes.length + 2; c++) {
        sheet.getRangeByIndex(r, c).cellStyle.borders.all.lineStyle = xlsio.LineStyle.thin;
        sheet.getRangeByIndex(r, c).cellStyle.borders.all.color = '#000000';
      }
    }
    sheet.setRowHeightInPixels(row + 1, 100);
    row += 2;

    // Data Rows
    final columnTotals = List<int>.filled(excelActivityTypes.length, 0);
    int grandTotal = 0;

    for (final mentorRow in _mentorRows) {
      sheet.getRangeByIndex(row, 1)
        ..setText(mentorRow['mentorName'])
        ..cellStyle = cellStyle
        ..cellStyle.hAlign = xlsio.HAlignType.left;

      int rowTotal = 0;
      for (int i = 0; i < excelActivityTypes.length; i++) {
        final type = excelActivityTypes[i];
        final count = (mentorRow['activityTypeCounts'][type] ?? 0) as int;
        sheet.getRangeByIndex(row, i + 2)
          ..setNumber(count.toDouble())
          ..cellStyle = cellStyle;
        rowTotal += count;
        columnTotals[i] += count;
      }

      sheet.getRangeByIndex(row, excelActivityTypes.length + 2)
        ..setNumber(rowTotal.toDouble())
        ..cellStyle = cellStyle
        ..cellStyle.bold = true;
      grandTotal += rowTotal;
      sheet.setRowHeightInPixels(row, 23);
      row++;
    }

    // Total Row
    sheet.getRangeByIndex(row, 1)
      ..setText('Total')
      ..cellStyle = totalRowStyle;
    for (int i = 0; i < columnTotals.length; i++) {
      sheet.getRangeByIndex(row, i + 2)
        ..setNumber(columnTotals[i].toDouble())
        ..cellStyle = totalRowStyle;
    }
    sheet.getRangeByIndex(row, excelActivityTypes.length + 2)
      ..setNumber(grandTotal.toDouble())
      ..cellStyle = totalRowStyle;
    sheet.setRowHeightInPixels(row, 23);

    // Autofit columns
    sheet.autoFitColumn(1);
    for (int i = 0; i < excelActivityTypes.length; i++) {
      sheet.getRangeByIndex(1, i + 2).columnWidth = 5;
    }
    sheet.autoFitColumn(excelActivityTypes.length + 2);

    final List<int> bytes = workbook.saveAsStream();
    workbook.dispose();

    // Web download removed - only mobile/desktop support
    final directory = await getApplicationDocumentsDirectory();
    final path = '${directory.path}/Activity Counts By Mentor.xlsx';
    final file = File(path);
    await file.writeAsBytes(bytes, flush: true);
    OpenFile.open(path);

    setState(() => _isExporting = false);
  }

  Future<void> _exportToPdf() async {
    if (_isExporting) return;
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
    final excelActivityTypes = _activityTypes.where((t) => t != 'No Activity').toList();
    pdf.addPage(
      pw.MultiPage(
        margin: const pw.EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        build: (pw.Context context) {
          List<pw.Widget> widgets = [];
          widgets.add(
            pw.Text('Activity Counts by Mentor', style: pw.TextStyle(fontSize: 28, fontWeight: pw.FontWeight.bold, color: PdfColors.black, font: notoBoldFont)),
          );
          widgets.add(
            pw.Container(
              padding: const pw.EdgeInsets.only(bottom: 8, top: 4),
              child: pw.Text('This report shows activity counts by Mentor grouped by Activity type', style: pw.TextStyle(fontSize: 13, color: PdfColors.grey600, font: notoFont)),
            ),
          );
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
                padding: const pw.EdgeInsets.only(bottom: 16),
                child: pw.Text('Date Range: ${formatDate(startDate)} - ${formatDate(endDate)}', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: PdfColors.black, font: notoBoldFont)),
              ),
            );
          }
          widgets.add(pw.SizedBox(height: 10));
          // Table
          final tableHeaders = [
            pw.Container(
              alignment: pw.Alignment.center,
              padding: const pw.EdgeInsets.symmetric(vertical: 12, horizontal: 8),
              width: 90,
              child: pw.Text('Mentor', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14, color: PdfColors.black, font: notoBoldFont)),
            ),
            ...excelActivityTypes.map((type) =>
              pw.Container(
                alignment: pw.Alignment.center,
                width: 38,
                height: 80,
                padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                child: pw.Transform.rotate(
                  angle: 1.5708, // +90 degrees in radians (right)
                  child: pw.Text(type, textAlign: pw.TextAlign.center, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12, color: PdfColors.black, font: notoBoldFont)),
                ),
              )
            ),
            pw.Container(
              alignment: pw.Alignment.center,
              padding: const pw.EdgeInsets.symmetric(vertical: 12, horizontal: 8),
              width: 50,
              child: pw.Text('Total', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14, color: PdfColors.black, font: notoBoldFont)),
            ),
          ];
          // Data rows
          List<List<pw.Widget>> tableRows = [];
          final columnTotals = List<int>.filled(excelActivityTypes.length, 0);
          int grandTotal = 0;
          for (final mentorRow in _mentorRows) {
            int rowTotal = 0;
            List<pw.Widget> row = [
              pw.Container(
                alignment: pw.Alignment.centerLeft,
                padding: const pw.EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                width: 90,
                child: pw.Text(mentorRow['mentorName'] ?? '', style: pw.TextStyle(fontSize: 13, color: PdfColors.black, font: notoFont)),
              ),
            ];
            for (int i = 0; i < excelActivityTypes.length; i++) {
              final type = excelActivityTypes[i];
              final count = (mentorRow['activityTypeCounts'][type] ?? 0) as int;
              row.add(
                pw.Container(
                  alignment: pw.Alignment.center,
                  width: 38,
                  padding: const pw.EdgeInsets.symmetric(vertical: 10, horizontal: 2),
                  child: pw.Text(count.toString(), style: pw.TextStyle(fontSize: 13, color: PdfColors.black, font: notoFont)),
                ),
              );
              rowTotal += count;
              columnTotals[i] += count;
            }
            row.add(
              pw.Container(
                alignment: pw.Alignment.center,
                width: 50,
                padding: const pw.EdgeInsets.symmetric(vertical: 10, horizontal: 2),
                child: pw.Text(rowTotal.toString(), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14, color: PdfColors.black, font: notoBoldFont)),
              ),
            );
            grandTotal += rowTotal;
            tableRows.add(row);
          }
          // Total row
          List<pw.Widget> totalRow = [
            pw.Container(
              alignment: pw.Alignment.center,
              width: 90,
              padding: const pw.EdgeInsets.symmetric(vertical: 10, horizontal: 8),
              decoration: pw.BoxDecoration(color: totalBgColor),
              child: pw.Text('Total', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14, color: PdfColors.black, font: notoBoldFont)),
            ),
          ];
          for (int i = 0; i < columnTotals.length; i++) {
            totalRow.add(
              pw.Container(
                alignment: pw.Alignment.center,
                width: 38,
                padding: const pw.EdgeInsets.symmetric(vertical: 10, horizontal: 2),
                decoration: pw.BoxDecoration(color: totalBgColor),
                child: pw.Text(columnTotals[i].toString(), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14, color: PdfColors.black, font: notoBoldFont)),
              ),
            );
          }
          totalRow.add(
            pw.Container(
              alignment: pw.Alignment.center,
              width: 50,
              padding: const pw.EdgeInsets.symmetric(vertical: 10, horizontal: 2),
              decoration: pw.BoxDecoration(color: totalBgColor),
              child: pw.Text(grandTotal.toString(), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 15, color: PdfColors.black, font: notoBoldFont)),
            ),
          );
          tableRows.add(totalRow);
          // Table widget
          widgets.add(
            pw.Table(
              border: pw.TableBorder.all(color: borderColor, width: 0.7),
              defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
              children: [
                pw.TableRow(
                  decoration: pw.BoxDecoration(color: tableHeaderColor),
                  children: tableHeaders,
                ),
                ...tableRows.map((row) => pw.TableRow(
                  decoration: pw.BoxDecoration(color: PdfColors.white),
                  children: row,
                )),
              ],
            ),
          );
          return widgets;
        },
      ),
    );
    final bytes = await pdf.save();
    // Web download removed - only mobile/desktop support
    final directory = await getApplicationDocumentsDirectory();
    final path = '${directory.path}/Activity Counts By Mentor.pdf';
    final file = File(path);
    await file.writeAsBytes(bytes, flush: true);
    setState(() => _isExporting = false);
    OpenFile.open(path);
  }

  Future<void> _exportToCsvCrosstab() async {
    final excelActivityTypes = _activityTypes.where((t) => t != 'No Activity').toList();
    List<List<String>> rows = [];
    // Header
    rows.add(['mentor_name', ...excelActivityTypes, 'Total']);
    // Data rows
    for (final mentorRow in _mentorRows) {
      final mentorName = mentorRow['mentorName'] ?? '';
      final activityCounts = mentorRow['activityTypeCounts'] as Map<String, dynamic>;
      final total = mentorRow['total']?.toString() ?? '0';
      List<String> row = [mentorName];
      for (final type in excelActivityTypes) {
        row.add((activityCounts[type] ?? 0).toString());
      }
      row.add(total);
      rows.add(row);
    }
    // Total row
    List<String> totalRow = ['Total'];
    int grandTotal = 0;
    for (final type in excelActivityTypes) {
      int sum = 0;
      for (final mentorRow in _mentorRows) {
        final activityCounts = mentorRow['activityTypeCounts'] as Map<String, dynamic>;
        sum += (activityCounts[type] ?? 0) as int;
      }
      totalRow.add(sum.toString());
      grandTotal += sum;
    }
    totalRow.add(grandTotal.toString());
    rows.add(totalRow);
    // Write CSV
    String csvData = const ListToCsvConverter().convert(rows);
    final bytes = utf8.encode(csvData);
    // Web download removed - only mobile/desktop support
    final directory = await getApplicationDocumentsDirectory();
    final path = '${directory.path}/MentorActivityCounts.csv';
    final file = File(path);
    await file.writeAsBytes(bytes, flush: true);
    OpenFile.open(path);
  }

  Future<void> _exportToTextCrosstab() async {
    final excelActivityTypes = _activityTypes.where((t) => t != 'No Activity').toList();
    final header = ['mentor_name', ...excelActivityTypes, 'Total'];
    List<String> lines = [];
    lines.add(header.join(' | '));
    for (final mentorRow in _mentorRows) {
      final mentorName = mentorRow['mentorName'] ?? '';
      final activityCounts = mentorRow['activityTypeCounts'] as Map<String, dynamic>;
      final total = mentorRow['total']?.toString() ?? '0';
      List<String> row = [mentorName];
      for (final type in excelActivityTypes) {
        row.add((activityCounts[type] ?? 0).toString());
      }
      row.add(total);
      lines.add(row.join(' | '));
    }
    // Total row
    List<String> totalRow = ['Total'];
    int grandTotal = 0;
    for (final type in excelActivityTypes) {
      int sum = 0;
      for (final mentorRow in _mentorRows) {
        final activityCounts = mentorRow['activityTypeCounts'] as Map<String, dynamic>;
        sum += (activityCounts[type] ?? 0) as int;
      }
      totalRow.add(sum.toString());
      grandTotal += sum;
    }
    totalRow.add(grandTotal.toString());
    lines.add(totalRow.join(' | '));
    final bytes = utf8.encode(lines.join('\n'));
    // Web download removed - only mobile/desktop support
    final directory = await getApplicationDocumentsDirectory();
    final path = '${directory.path}/MentorActivityCounts.txt';
    final file = File(path);
    await file.writeAsBytes(bytes, flush: true);
    OpenFile.open(path);
  }

  Future<void> _exportToHtmlCrosstab() async {
    final excelActivityTypes = _activityTypes.where((t) => t != 'No Activity').toList();
    final header = ['mentor_name', ...excelActivityTypes, 'Total'];
    final tableHeaderColor = '#83CCEB';
    final totalBgColor = '#F7C037';
    final borderColor = '#000000';
    final textColor = '#000000';
    final bold = 'font-weight:bold;';
    final center = 'text-align:center;';
    final left = 'text-align:left;';
    final border = 'border:1px solid $borderColor;';
    final thStyle = 'background:$tableHeaderColor;$bold$center$border;color:$textColor;font-size:15px;';
    final tdStyle = '$center$border;font-size:15px;';
    final totalThStyle = 'background:$totalBgColor;$bold$center$border;color:$textColor;font-size:15px;';
    final totalTdStyle = 'background:$totalBgColor;$bold$center$border;color:$textColor;font-size:15px;';
    final thBorder = 'border-top:1px solid $borderColor !important;border-bottom:1px solid $borderColor !important;border-left:1px solid $borderColor !important;border-right:1px solid $borderColor !important;';
    final htmlBuffer = StringBuffer();
    htmlBuffer.writeln('<!DOCTYPE html>');
    htmlBuffer.writeln('<html lang="en"><head><meta charset="UTF-8"><title>Mentor Activity Counts</title>');
    htmlBuffer.writeln('<style>body{font-family:Arial,sans-serif;background:#fff;} table{border-collapse:collapse;margin:32px 0;} table,th,td{border:1px solid $borderColor !important;} th,td{padding:8px;} th{height:54px;} th.activity-type{min-width:70px;max-width:90px;} th.activity-type.wide{min-width:110px;max-width:130px;} .wrap{white-space:normal;word-break:break-word;} .total-row td{background:$totalBgColor;font-weight:bold;} </style></head><body>');
    htmlBuffer.writeln('<h1 style="color:#222;font-size:28px;margin-bottom:0;">Activity Counts by Mentor</h1>');
    htmlBuffer.writeln('<div style="color:#555;font-size:15px;margin-bottom:8px;">This report shows activity counts by Mentor grouped by Activity type</div>');
    // Date Range (if available)
    final startDate = widget.filters['startDate'] as DateTime?;
    final endDate = widget.filters['endDate'] as DateTime?;
    if (startDate != null && endDate != null) {
      final rangeText = 'Date Range: ${DateFormat.yMMMd().format(startDate)} - ${DateFormat.yMMMd().format(endDate)}';
      htmlBuffer.writeln('<div style="color:#333;font-size:14px;font-weight:bold;margin-bottom:12px;">$rangeText</div>');
    }
    // Table start
    htmlBuffer.writeln('<table>');
    // Single header row (no merged or rotated headers)
    htmlBuffer.write('<tr>');
    htmlBuffer.write('<th style="$thStyle">Mentor</th>');
    for (final type in excelActivityTypes) {
      String wrapped = type;
      String extraClass = '';
      if (type == 'One on one activity') {
        wrapped = 'One on one<br>activity';
        extraClass = ' wide';
      } else if (type == 'Religious day program') {
        wrapped = 'Religious day<br>program';
        extraClass = ' wide';
      } else if (type == 'Daily reading program') {
        wrapped = 'Daily reading<br>program';
        extraClass = ' wide';
      } else if (type == 'Parent meeting') {
        wrapped = 'Parent<br>meeting';
      } else if (type == 'Home visit') {
        wrapped = 'Home visit';
      } else if (type == 'Out of state trip') {
        wrapped = 'Out of state<br>trip';
      } else if (type == 'Out of town trip') {
        wrapped = 'Out of town<br>trip';
      } else if (type == 'Tent camp') {
        wrapped = 'Tent camp';
      } else if (type == 'Pre-mentor reading camp') {
        wrapped = 'Pre-mentor<br>reading camp';
        extraClass = ' wide';
      } else if (type == 'Mentor reading camp') {
        wrapped = 'Mentor<br>reading camp';
        extraClass = ' wide';
      } else if (type == 'Reading camp') {
        wrapped = 'Reading camp';
      } else if (type == 'Weekly mentoring') {
        wrapped = 'Weekly mentoring';
      }
      htmlBuffer.write('<th class="activity-type wrap$extraClass" style="$thStyle">$wrapped</th>');
    }
    htmlBuffer.write('<th style="$thStyle">Total</th>');
    htmlBuffer.writeln('</tr>');
    // Data rows
    for (final mentorRow in _mentorRows) {
      final mentorName = mentorRow['mentorName'] ?? '';
      final activityCounts = mentorRow['activityTypeCounts'] as Map<String, dynamic>;
      final total = mentorRow['total']?.toString() ?? '0';
      htmlBuffer.write('<tr>');
      htmlBuffer.write('<td style="$tdStyle$left">$mentorName</td>');
      for (final type in excelActivityTypes) {
        htmlBuffer.write('<td style="$tdStyle">${activityCounts[type] ?? 0}</td>');
      }
      htmlBuffer.write('<td style="$tdStyle$bold">$total</td>');
      htmlBuffer.writeln('</tr>');
    }
    // Total row
    htmlBuffer.write('<tr class="total-row">');
    htmlBuffer.write('<td style="$totalTdStyle$left">Total</td>');
    int grandTotal = 0;
    for (final type in excelActivityTypes) {
      int sum = 0;
      for (final mentorRow in _mentorRows) {
        final activityCounts = mentorRow['activityTypeCounts'] as Map<String, dynamic>;
        sum += (activityCounts[type] ?? 0) as int;
      }
      htmlBuffer.write('<td style="$totalTdStyle">$sum</td>');
      grandTotal += sum;
    }
    htmlBuffer.write('<td style="$totalTdStyle$bold">$grandTotal</td>');
    htmlBuffer.writeln('</tr>');
    htmlBuffer.writeln('</table>');
    htmlBuffer.writeln('</body></html>');
    final bytes = utf8.encode(htmlBuffer.toString());
    // Web download removed - only mobile/desktop support
    final directory = await getApplicationDocumentsDirectory();
    final path = '${directory.path}/MentorActivityCounts.html';
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