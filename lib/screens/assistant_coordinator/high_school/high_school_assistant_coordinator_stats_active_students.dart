import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:syncfusion_flutter_xlsio/xlsio.dart' as xlsio;
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:open_file/open_file.dart';
// For web download
// ignore: avoid_web_libraries_in_flutter
// HTML import removed for mobile compatibility
import 'package:csv/csv.dart';
import 'dart:convert';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:flutter/services.dart';

class HighSchoolAssistantCoordinatorStatsActiveStudentsPage extends StatefulWidget {
  final Map<String, dynamic> filters;
  const HighSchoolAssistantCoordinatorStatsActiveStudentsPage({super.key, required this.filters});

  @override
  State<HighSchoolAssistantCoordinatorStatsActiveStudentsPage> createState() => _HighSchoolAssistantCoordinatorStatsActiveStudentsPageState();
}

class _HighSchoolAssistantCoordinatorStatsActiveStudentsPageState extends State<HighSchoolAssistantCoordinatorStatsActiveStudentsPage> {
  final _firestore = FirebaseFirestore.instance;
  bool _isLoading = true;
  Map<String, List<Map<String, dynamic>>> _mentors = {};
  Map<String, String> _mentorNames = {};
  int _total = 0;
  String? _error;
  bool _isExporting = false;
  final ScrollController _scrollController = ScrollController();
  bool _showDownArrow = false;
  final GlobalKey _contentKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _fetchActiveStudentsReport();
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
    final atBottom = _scrollController.offset >= (_scrollController.position.maxScrollExtent - 8);
    final isScrollable = _scrollController.position.maxScrollExtent > 0;
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

  Future<void> _fetchActiveStudentsReport() async {
    try {
      final selectedMentorUids = (widget.filters['selectedMentors'] as Map<String, bool>?)?.entries.where((e) => e.value).map((e) => e.key).toList() ?? [];
      final selectedCity = widget.filters['selectedCity'] as List<String>? ?? [];
      final selectedUnit = widget.filters['selectedUnit'] as List<String>? ?? [];
      final selectedGrades = widget.filters['selectedGrades'] as List<String>? ?? [];
      final selectedGenders = widget.filters['selectedGenders'] as List<String>? ?? [];

      if (selectedMentorUids.isEmpty) {
        setState(() {
          _isLoading = false;
          _error = 'Please select at least one mentor.';
        });
        return;
      }

      // 1. Fetch mentor docs
      final mentorDocs = await _firestore.collection('users').where(FieldPath.documentId, whereIn: selectedMentorUids).get();
      // 2. Gather all mentee UIDs
      final allMenteeUids = <String>{};
      for (var mentorDoc in mentorDocs.docs) {
        final assignedMentees = (mentorDoc.data()['assignedTo'] as List<dynamic>?)?.map((e) => e?.toString() ?? '').where((e) => e.isNotEmpty).toList() ?? [];
        allMenteeUids.addAll(assignedMentees);
      }
      if (allMenteeUids.isEmpty) {
        setState(() {
          _isLoading = false;
          _mentors = {};
          _mentorNames = {};
          _total = 0;
        });
        return;
      }
      // 3. Fetch mentee docs
      final menteeSnapshot = await _firestore.collection('users').where(FieldPath.documentId, whereIn: allMenteeUids.toList()).get();
      // 4. Filter mentees
      final filteredMentees = menteeSnapshot.docs.where((doc) {
        final data = doc.data();
        final isActive = data['isActive'] == true;
        final cityMatch = selectedCity.isNotEmpty && selectedCity.contains(data['city']);
        final schoolMatch = selectedUnit.isNotEmpty && selectedUnit.contains(data['school']);
        final gradeMatch = selectedGrades.isNotEmpty && selectedGrades.contains(data['gradeLevel']);
        final genderMatch = selectedGenders.isNotEmpty && selectedGenders.contains(data['gender']);
        return isActive && cityMatch && schoolMatch && gradeMatch && genderMatch;
      }).toList();
      // 5. Group mentees by mentor
      final Map<String, List<Map<String, dynamic>>> reportData = {};
      for (var mentorDoc in mentorDocs.docs) {
        final mentorId = mentorDoc.id;
        final assignedMentees = (mentorDoc.data()['assignedTo'] as List<dynamic>?)?.map((e) => e?.toString() ?? '').where((e) => e.isNotEmpty).toList() ?? [];
        final mentees = filteredMentees.where((doc) => assignedMentees.contains(doc.id)).map((doc) {
          final d = doc.data();
          return {
            'firstName': d['firstName'] ?? '',
            'lastName': d['lastName'] ?? '',
            'gender': d['gender'] ?? '',
            'school': d['school'] ?? '',
            'grade': d['gradeLevel'] ?? '',
            'city': d['city'] ?? '',
            'province': d['province'] ?? '',
          };
        }).toList();
        if (mentees.isNotEmpty) {
          reportData[mentorId] = mentees;
        }
      }
      setState(() {
        _isLoading = false;
        _mentors = reportData;
        _mentorNames = {for (var doc in mentorDocs.docs) doc.id: ((doc.data()['firstName'] ?? '') + ' ' + (doc.data()['lastName'] ?? ''))};
        _total = filteredMentees.length;
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
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Active Students Report',
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
            NotificationListener<ScrollNotification>(
              onNotification: (_) => false,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return Stack(
                    children: [
                      SafeArea(
                        child: SingleChildScrollView(
                          controller: _scrollController,
                          padding: const EdgeInsets.all(16.0),
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
                                      'This report shows the list of all active students grouped by Mentor.',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.white70,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 24),
                              ..._buildMentorSections(),
                              Align(
                                alignment: Alignment.centerRight,
                                child: Padding(
                                  padding: const EdgeInsets.only(top: 8.0, right: 8.0),
                                  child: Text(
                                    'Total Students: $_total',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                      fontSize: 17,
                                      shadows: [
                                        Shadow(
                                          blurRadius: 2.0,
                                          color: Colors.black.withOpacity(0.5),
                                          offset: const Offset(1.0, 1.0),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 24),
                              if (_mentors.isNotEmpty)
                                Center(
                                  child: _isExporting
                                      ? const CircularProgressIndicator()
                                      : DownloadDropdownButton(
                                          onSelected: (value) async {
                                            if (value == 'excel') {
                                              await _exportToExcel();
                                            } else if (value == 'pdf') await _exportToPdf();
                                            else if (value == 'csv') await _exportToCsv();
                                            else if (value == 'text') await _exportToText();
                                            else if (value == 'html') await _exportToHtml();
                                          },
                                        ),
                                ),
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
                                if (position.hasContentDimensions) {
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
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  List<Widget> _buildMentorSections() {
    final sortedMentorIds = _mentors.keys.toList();
    sortedMentorIds.sort((a, b) => (_mentorNames[a] ?? '').compareTo(_mentorNames[b] ?? ''));
    return [
      for (final mentorId in sortedMentorIds)
        if (_mentors[mentorId]!.isNotEmpty)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 12.0, top: 10),
                child: Text(
                  'Mentor: ${_mentorNames[mentorId] ?? ''}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontSize: 19,
                    shadows: [
                      Shadow(
                        blurRadius: 2.0,
                        color: Colors.black.withOpacity(0.5),
                        offset: const Offset(1.0, 1.0),
                      ),
                    ],
                  ),
                ),
              ),
              ..._mentors[mentorId]!.map((mentee) => _buildMenteeCard(mentee)),
              const SizedBox(height: 16),
            ],
          ),
    ];
  }

  Widget _buildMenteeCard(Map<String, dynamic> mentee) {
    return Card(
      elevation: 4.0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15.0),
      ),
      color: Colors.white.withOpacity(0.95),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${mentee['firstName'] ?? ''} ${mentee['lastName'] ?? ''}',
                    style: const TextStyle(
                        color: Color(0xFF0D47A1),
                        fontWeight: FontWeight.bold,
                        fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${mentee['city'] ?? ''}, ${mentee['province'] ?? ''}',
                    style: TextStyle(color: Colors.grey[700], fontSize: 13),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    mentee['grade'] ?? '',
                    style: TextStyle(
                        color: Colors.grey[850],
                        fontSize: 15,
                        fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    mentee['school'] ?? '',
                    style: TextStyle(color: Colors.grey[700], fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportToExcel() async {
    setState(() => _isExporting = true);
    final workbook = xlsio.Workbook();
    final sheet = workbook.worksheets[0];
    sheet.showGridlines = false;
    // Add report title row
    sheet.getRangeByIndex(1, 1, 1, 7).merge();
    sheet.getRangeByIndex(1, 1).setText('Active Students');
    sheet.getRangeByIndex(1, 1).cellStyle.bold = true;
    sheet.getRangeByIndex(1, 1).cellStyle.fontSize = 24;
    sheet.getRangeByIndex(1, 1).cellStyle.hAlign = xlsio.HAlignType.left;
    sheet.getRangeByIndex(1, 1).cellStyle.vAlign = xlsio.VAlignType.center;
    sheet.setRowHeightInPixels(1, 36);
    // Add note and date row
    sheet.getRangeByIndex(2, 1, 2, 7).merge();
    sheet.getRangeByIndex(2, 1).setText('This report shows the list of all active students grouped by Mentor');
    sheet.getRangeByIndex(2, 1).cellStyle.fontSize = 12;
    sheet.getRangeByIndex(2, 1).cellStyle.fontColor = '#888888';
    sheet.getRangeByIndex(2, 1).cellStyle.hAlign = xlsio.HAlignType.left;
    sheet.getRangeByIndex(2, 1).cellStyle.vAlign = xlsio.VAlignType.center;
    // Date at the right of the same row (G2)
    final now = DateTime.now();
    final dateStr = 'Date: ${_monthYearString(now)}';
    sheet.getRangeByIndex(2, 7).setText(dateStr);
    sheet.getRangeByIndex(2, 7).cellStyle.fontSize = 12;
    sheet.getRangeByIndex(2, 7).cellStyle.fontColor = '#888888';
    sheet.getRangeByIndex(2, 7).cellStyle.hAlign = xlsio.HAlignType.right;
    sheet.getRangeByIndex(2, 7).cellStyle.vAlign = xlsio.VAlignType.center;
    sheet.setRowHeightInPixels(2, 22);
    // Start data from row 4
    int row = 4;
    // Satır ve sütun boyutlarını ayarla
    for (int i = 1; i <= 200; i++) { // 200 satıra kadar uygula (gerekirse artırılabilir)
      sheet.setRowHeightInPixels(i, 36);
    }
    for (int i = 1; i <= 7; i++) {
      sheet.getRangeByIndex(1, i, 200, i).columnWidth = 14;
    }
    // Mentor style
    final mentorStyle = workbook.styles.add('mentorStyle');
    mentorStyle.bold = true;
    mentorStyle.fontSize = 16;
    mentorStyle.borders.all.lineStyle = xlsio.LineStyle.thin;
    mentorStyle.borders.all.color = '#000000';
    mentorStyle.backColor = '#0D0D0D'; // dark
    mentorStyle.fontColor = '#FFFFFF';
    mentorStyle.vAlign = xlsio.VAlignType.center;
    // Header style
    final headerStyle = workbook.styles.add('headerStyle');
    headerStyle.bold = true;
    headerStyle.fontSize = 14;
    headerStyle.borders.all.lineStyle = xlsio.LineStyle.thin;
    headerStyle.borders.all.color = '#000000';
    headerStyle.hAlign = xlsio.HAlignType.center;
    headerStyle.vAlign = xlsio.VAlignType.center;
    headerStyle.backColor = '#000000'; // black
    headerStyle.fontColor = '#FFFFFF';
    // Cell style (even rows)
    final cellStyle = workbook.styles.add('cellStyle');
    cellStyle.fontSize = 12;
    cellStyle.borders.all.lineStyle = xlsio.LineStyle.thin;
    cellStyle.borders.all.color = '#000000';
    cellStyle.hAlign = xlsio.HAlignType.center;
    cellStyle.vAlign = xlsio.VAlignType.center;
    cellStyle.backColor = '#D0D0D0'; // gray
    // Cell style (odd rows)
    final cellStyleWhite = workbook.styles.add('cellStyleWhite');
    cellStyleWhite.fontSize = 12;
    cellStyleWhite.borders.all.lineStyle = xlsio.LineStyle.thin;
    cellStyleWhite.borders.all.color = '#000000';
    cellStyleWhite.hAlign = xlsio.HAlignType.center;
    cellStyleWhite.vAlign = xlsio.VAlignType.center;
    cellStyleWhite.backColor = '#FFFFFF';
    // Total style
    final totalStyle = workbook.styles.add('totalStyle');
    totalStyle.bold = true;
    totalStyle.fontSize = 13;
    totalStyle.borders.all.lineStyle = xlsio.LineStyle.thin;
    totalStyle.borders.all.color = '#000000';
    totalStyle.hAlign = xlsio.HAlignType.center;
    totalStyle.vAlign = xlsio.VAlignType.center;
    totalStyle.backColor = '#FFFF00'; // yellow
    totalStyle.fontColor = '#000000';
    // Write for each mentor
    int overallStudentCount = 0;
    for (final mentorId in _mentors.keys) {
      final mentorName = _mentorNames[mentorId] ?? '';
      final mentees = _mentors[mentorId]!;
      // Merge mentor row
      sheet.getRangeByIndex(row, 1, row, 7).merge();
      sheet.getRangeByIndex(row, 1).setText('Mentor: $mentorName');
      for (int col = 1; col <= 7; col++) {
        sheet.getRangeByIndex(row, col).cellStyle = mentorStyle;
      }
      sheet.setRowHeightInPixels(row, 36);
      row++;
      // Header
      final headers = ['First Name', 'Last Name', 'Gender', 'School', 'Grade', 'City', 'Province'];
      for (int col = 0; col < headers.length; col++) {
        sheet.getRangeByIndex(row, col + 1).setText(headers[col]);
        sheet.getRangeByIndex(row, col + 1).cellStyle = headerStyle;
      }
      sheet.setRowHeightInPixels(row, 36);
      row++;
      // Mentees
      for (int i = 0; i < mentees.length; i++) {
        final mentee = mentees[i];
        sheet.getRangeByIndex(row, 1).setText(mentee['firstName'] ?? '');
        sheet.getRangeByIndex(row, 2).setText(mentee['lastName'] ?? '');
        sheet.getRangeByIndex(row, 3).setText(mentee['gender'] ?? '');
        sheet.getRangeByIndex(row, 4).setText(mentee['school'] ?? '');
        sheet.getRangeByIndex(row, 5).setText(mentee['grade'] ?? '');
        sheet.getRangeByIndex(row, 6).setText(mentee['city'] ?? '');
        sheet.getRangeByIndex(row, 7).setText(mentee['province'] ?? '');
        for (int col = 1; col <= 7; col++) {
          sheet.getRangeByIndex(row, col).cellStyle = (i % 2 == 0) ? cellStyle : cellStyleWhite;
        }
        sheet.setRowHeightInPixels(row, 36);
        row++;
      }
      row++;
      overallStudentCount += mentees.length;
    }
    // Overall total mentees row
    row++;
    sheet.getRangeByIndex(row, 1).setText('Total Mentees:');
    sheet.getRangeByIndex(row, 2).setNumber(overallStudentCount.toDouble());
    sheet.getRangeByIndex(row, 1).cellStyle = totalStyle;
    sheet.getRangeByIndex(row, 2).cellStyle = totalStyle;
    for (int col = 3; col <= 7; col++) {
      sheet.getRangeByIndex(row, col).setText('');
    }
    sheet.setRowHeightInPixels(row, 36);
    // Auto fit columns (not needed since we set width, but keep for safety)
    for (int i = 1; i <= 7; i++) {
      sheet.autoFitColumn(i);
    }
    final List<int> bytes = workbook.saveAsStream();
    workbook.dispose();
    // Web download removed - only mobile/desktop support
    final directory = await getApplicationDocumentsDirectory();
    final path = '${directory.path}/Active Students.xlsx';
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
    // Başlık
    pdf.addPage(
      pw.MultiPage(
        build: (pw.Context context) {
          List<pw.Widget> widgets = [];
          widgets.add(
            pw.Text('Active Students', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: PdfColors.deepPurple800, font: notoBoldFont)),
          );
          widgets.add(
            pw.SizedBox(height: 6),
          );
          widgets.add(
            pw.Text('This report shows the list of all active students grouped by Mentor', style: pw.TextStyle(fontSize: 12, color: PdfColors.grey600, font: notoFont)),
          );
          widgets.add(pw.SizedBox(height: 18));
          int totalMentees = 0;
          for (final mentorId in _mentors.keys) {
            final mentorName = _mentorNames[mentorId] ?? '';
            widgets.add(
              pw.Container(
                color: PdfColors.black,
                padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                child: pw.Text('Mentor: $mentorName', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.white, font: notoBoldFont)),
              ),
            );
            widgets.add(pw.SizedBox(height: 2));
            // Header
            final headers = ['First Name', 'Last Name', 'Gender', 'School', 'Grade', 'City', 'Province'];
            final mentees = _mentors[mentorId]!;
            final data = mentees.map((mentee) => [
              mentee['firstName'] ?? '',
              mentee['lastName'] ?? '',
              mentee['gender'] ?? '',
              mentee['school'] ?? '',
              mentee['grade'] ?? '',
              mentee['city'] ?? '',
              mentee['province'] ?? '',
            ]).toList();
            widgets.add(
              pw.Table.fromTextArray(
                headers: headers,
                data: data,
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 13, font: notoBoldFont),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.black),
                cellStyle: pw.TextStyle(fontSize: 12, color: PdfColors.black, font: notoFont),
                cellAlignment: pw.Alignment.center,
                cellAlignments: {
                  for (var i = 0; i < 7; i++) i: pw.Alignment.center,
                },
                cellDecoration: (index, data, rowNum) => pw.BoxDecoration(
                  color: rowNum % 2 == 0 ? PdfColors.grey300 : PdfColors.white,
                  border: pw.TableBorder.all(color: PdfColors.black, width: 0.5),
                ),
                headerAlignments: {
                  for (var i = 0; i < 7; i++) i: pw.Alignment.center,
                },
                cellHeight: 36,
                columnWidths: {
                  for (var i = 0; i < 7; i++) i: const pw.FixedColumnWidth(14),
                },
              ),
            );
            widgets.add(pw.SizedBox(height: 12));
            totalMentees += mentees.length;
          }
          // Toplam mentee
          widgets.add(
            pw.Row(
              children: [
                pw.Container(
                  color: PdfColors.yellow,
                  padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                  child: pw.Text('Total Mentees:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 13, color: PdfColors.black, font: notoBoldFont)),
                ),
                pw.Container(
                  color: PdfColors.yellow,
                  padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                  child: pw.Text('$totalMentees', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 13, color: PdfColors.black, font: notoBoldFont)),
                ),
                pw.Expanded(child: pw.Container()),
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
    final path = '${directory.path}/Active_Students.pdf';
    final file = File(path);
    await file.writeAsBytes(bytes, flush: true);
    setState(() => _isExporting = false);
    OpenFile.open(path);
  }

  Future<void> _exportToCsv() async {
    setState(() => _isExporting = true);
    List<List<String>> rows = [];
    rows.add(['Mentor', 'First Name', 'Last Name', 'Gender', 'School', 'Grade', 'City', 'Province']);
    for (final mentorId in _mentors.keys) {
      final mentorName = _mentorNames[mentorId] ?? '';
      for (final mentee in _mentors[mentorId]!) {
        rows.add([
          mentorName,
          mentee['firstName'] ?? '',
          mentee['lastName'] ?? '',
          mentee['gender'] ?? '',
          mentee['school'] ?? '',
          mentee['grade'] ?? '',
          mentee['city'] ?? '',
          mentee['province'] ?? '',
        ]);
      }
    }
    String csvData = const ListToCsvConverter().convert(rows);
    final bytes = utf8.encode(csvData);
    // Web download removed - only mobile/desktop support
    final directory = await getApplicationDocumentsDirectory();
    final path = '${directory.path}/Active Students.csv';
    final file = File(path);
    await file.writeAsBytes(bytes, flush: true);
    setState(() => _isExporting = false);
    OpenFile.open(path);
  }

  Future<void> _exportToText() async {
    setState(() => _isExporting = true);
    StringBuffer buffer = StringBuffer();
    buffer.writeln('Active Students');
    buffer.writeln('This report shows the list of all active students grouped by Mentor');
    for (final mentorId in _mentors.keys) {
      final mentorName = _mentorNames[mentorId] ?? '';
      buffer.writeln('\nMentor: $mentorName');
      buffer.writeln('First Name | Last Name | Gender | School | Grade | City | Province');
      for (final mentee in _mentors[mentorId]!) {
        buffer.writeln([
          mentee['firstName'] ?? '',
          mentee['lastName'] ?? '',
          mentee['gender'] ?? '',
          mentee['school'] ?? '',
          mentee['grade'] ?? '',
          mentee['city'] ?? '',
          mentee['province'] ?? '',
        ].join(' | '));
      }
    }
    int total = _mentors.values.fold(0, (sum, mentees) => sum + mentees.length);
    buffer.writeln('\nTotal Mentees: $total');
    final bytes = utf8.encode(buffer.toString());
    // Web download removed - only mobile/desktop support
    final directory = await getApplicationDocumentsDirectory();
    final path = '${directory.path}/Active Students.txt';
    final file = File(path);
    await file.writeAsBytes(bytes, flush: true);
    setState(() => _isExporting = false);
    OpenFile.open(path);
  }

  Future<void> _exportToHtml() async {
    setState(() => _isExporting = true);
    final buffer = StringBuffer();
    buffer.writeln('<!DOCTYPE html>');
    buffer.writeln('<html lang="en"><head><meta charset="UTF-8"><title>Active Students</title>');
    buffer.writeln('<style>');
    buffer.writeln('body { font-family: Arial, sans-serif; background: #f7f7fa; }');
    buffer.writeln('h1 { color: #0D0D0D; }');
    buffer.writeln('table { border-collapse: collapse; width: 100%; margin-bottom: 32px; }');
    buffer.writeln('th, td { border: 1px solid #000; padding: 8px; text-align: center; min-width: 90px; font-size: 13px; }');
    buffer.writeln('th { background: #000000; color: #fff; font-weight: bold; }');
    buffer.writeln('tr.mentor-row td { background: #0D0D0D; color: #fff; font-weight: bold; font-size: 16px; }');
    buffer.writeln('tr.data-row.even td { background: #D0D0D0; }');
    buffer.writeln('tr.data-row.odd td { background: #FFFFFF; }');
    buffer.writeln('tr.total-row td { background: #FFFF00; color: #000; font-weight: bold; font-size: 13px; }');
    buffer.writeln('</style></head><body>');
    buffer.writeln('<h1>Active Students</h1>');
    buffer.writeln('<p style="color:#888888;font-size:15px;">This report shows the list of all active students grouped by Mentor</p>');
    int totalMentees = 0;
    for (final mentorId in _mentors.keys) {
      final mentorName = _mentorNames[mentorId] ?? '';
      final mentees = _mentors[mentorId]!;
      buffer.writeln('<table>');
      // Mentor row (merged)
      buffer.writeln('<tr class="mentor-row"><td colspan="7">Mentor: $mentorName</td></tr>');
      // Header
      buffer.writeln('<tr>');
      final headers = ['First Name', 'Last Name', 'Gender', 'School', 'Grade', 'City', 'Province'];
      for (final h in headers) {
        buffer.write('<th>$h</th>');
      }
      buffer.writeln('</tr>');
      // Data rows
      for (int i = 0; i < mentees.length; i++) {
        final mentee = mentees[i];
        final rowClass = i % 2 == 0 ? 'even' : 'odd';
        buffer.writeln('<tr class="data-row $rowClass">');
        buffer.write('<td>${mentee['firstName'] ?? ''}</td>');
        buffer.write('<td>${mentee['lastName'] ?? ''}</td>');
        buffer.write('<td>${mentee['gender'] ?? ''}</td>');
        buffer.write('<td>${mentee['school'] ?? ''}</td>');
        buffer.write('<td>${mentee['grade'] ?? ''}</td>');
        buffer.write('<td>${mentee['city'] ?? ''}</td>');
        buffer.write('<td>${mentee['province'] ?? ''}</td>');
        buffer.writeln('</tr>');
      }
      buffer.writeln('</table>');
      totalMentees += mentees.length;
    }
    // Total row (merged style)
    buffer.writeln('<table style="width:100%;"><tr class="total-row">');
    buffer.writeln('<td style="text-align:left;" colspan="7">Total Mentees: $totalMentees</td>');
    buffer.writeln('</tr></table>');
    buffer.writeln('</body></html>');
    final bytes = utf8.encode(buffer.toString());
    // Web download removed - only mobile/desktop support
    final directory = await getApplicationDocumentsDirectory();
    final path = '${directory.path}/Active_Students.html';
    final file = File(path);
    await file.writeAsBytes(bytes, flush: true);
    setState(() => _isExporting = false);
    OpenFile.open(path);
  }

  String _monthYearString(DateTime date) {
    final months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return '${months[date.month - 1]} ${date.year}';
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