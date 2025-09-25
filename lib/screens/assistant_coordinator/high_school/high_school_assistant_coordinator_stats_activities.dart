import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'dart:io';
// ignore: avoid_web_libraries_in_flutter
// HTML import removed for mobile compatibility
import 'package:syncfusion_flutter_xlsio/xlsio.dart' as xlsio;
import 'package:csv/csv.dart';
import 'dart:convert';
import 'package:flutter/services.dart';

class HighSchoolAssistantCoordinatorStatsActivitiesPage extends StatefulWidget {
  final Map<String, dynamic> filters;
  const HighSchoolAssistantCoordinatorStatsActivitiesPage({super.key, required this.filters});

  @override
  State<HighSchoolAssistantCoordinatorStatsActivitiesPage> createState() => _HighSchoolAssistantCoordinatorStatsActivitiesPageState();
}

class _HighSchoolAssistantCoordinatorStatsActivitiesPageState extends State<HighSchoolAssistantCoordinatorStatsActivitiesPage> {
  final _firestore = FirebaseFirestore.instance;
  bool _isLoading = true;
  List<Map<String, dynamic>> _reports = [];
  Map<String, String> _mentorNames = {};
  String? _error;
  final ScrollController _scrollController = ScrollController();
  bool _showDownArrow = false;
  final GlobalKey _contentKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _fetchActivitiesReport();
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

  Future<void> _fetchActivitiesReport() async {
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
          _error = 'Please select at least one mentor.';
        });
        return;
      }

      // 1. Fetch all reports for selected mentors
      final List<Map<String, dynamic>> allReports = [];
      for (final mentorId in selectedMentorUids) {
        final reportsSnapshot = await _firestore
            .collection('weekendReports')
            .doc(mentorId)
            .collection('reports')
            .get();
        for (final doc in reportsSnapshot.docs) {
          final data = doc.data();
          data['mentorId'] = mentorId;
          data['reportId'] = doc.id;
          allReports.add(data);
        }
      }

      // 2. Filter by date range
      final filteredReports = allReports.where((report) {
        String? dateStr = report['startdate'];
        if (dateStr == null || dateStr.isEmpty) {
          final reportId = report['reportId'] ?? '';
          if (reportId.length >= 10) {
            dateStr = reportId.substring(0, 10);
          } else {
            dateStr = '';
          }
        }
        final reportDate = DateTime.tryParse(dateStr ?? '');
        if (reportDate == null) return false;
        if (startDate != null && reportDate.isBefore(startDate)) return false;
        if (endDate != null && reportDate.isAfter(endDate)) return false;
        return true;
      }).toList();

      // 3. Filter by activity type (including 'No Activity')
      final includeNoActivity = selectedActivityTypes.contains('No Activity');
      final filteredByActivity = filteredReports.where((report) {
        final isNoActivity = report['noActivityThisWeek'] == true;
        if (isNoActivity && includeNoActivity) return true;
        if (!isNoActivity && selectedActivityTypes.isNotEmpty) {
          return selectedActivityTypes.contains(report['activity']);
        }
        return !isNoActivity && selectedActivityTypes.isEmpty;
      }).toList();

      // 4. For each report, filter mentees by city, school, grade, gender
      final List<Map<String, dynamic>> resultReports = [];
      for (final report in filteredByActivity) {
        final mentorId = report['mentorId'];
        final menteesMap = Map<String, dynamic>.from(report['mentees'] ?? {});
        final List<Map<String, dynamic>> menteeDetails = [];
        if (menteesMap.isNotEmpty) {
          final menteeIds = menteesMap.keys.toList();
          final menteeSnapshot = await _firestore
              .collection('users')
              .where(FieldPath.documentId, whereIn: menteeIds)
              .get();
          for (final doc in menteeSnapshot.docs) {
            final data = doc.data();
            final cityMatch = selectedCity.isNotEmpty && selectedCity.contains(data['city']);
            final schoolMatch = selectedUnit.isNotEmpty && selectedUnit.contains(data['school']);
            final gradeMatch = selectedGrades.isNotEmpty && selectedGrades.contains(data['gradeLevel']);
            final genderMatch = selectedGenders.isNotEmpty && selectedGenders.contains(data['gender']);
            if (cityMatch && schoolMatch && gradeMatch && genderMatch) {
              menteeDetails.add({
                'firstName': data['firstName'] ?? '',
                'lastName': data['lastName'] ?? '',
                'grade': data['gradeLevel'] ?? '',
                'joined': menteesMap[doc.id]['joined'] ?? false,
                'joinDate': menteesMap[doc.id]['joinDate'] ?? '',
                'days': menteesMap[doc.id]['days'] ?? 1,
              });
            }
          }
        }
        resultReports.add({
          ...report,
          'menteesDetails': menteeDetails,
        });
      }

      // 5. Fetch mentor names
      final mentorSnapshot = await _firestore
          .collection('users')
          .where(FieldPath.documentId, whereIn: selectedMentorUids)
          .get();
      final mentorNamesRaw = {for (var doc in mentorSnapshot.docs) doc.id: (doc.data()['firstName'] ?? '') + ' ' + (doc.data()['lastName'] ?? '')};
      final Map<String, String> mentorNames = mentorNamesRaw.map((k, v) => MapEntry(k, v.toString()));

      setState(() {
        _isLoading = false;
        _reports = resultReports;
        _mentorNames = mentorNames;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = 'An error occurred while fetching data.';
      });
    }
  }

  Future<void> _exportToPdf() async {
    setState(() => _isLoading = true);
    final pdf = pw.Document();
    // Load NotoSans fonts from assets/fonts/
    final fontData = await rootBundle.load('assets/fonts/NotoSans-Regular.ttf');
    final boldFontData = await rootBundle.load('assets/fonts/NotoSans-Bold.ttf');
    final notoFont = pw.Font.ttf(fontData);
    final notoBoldFont = pw.Font.ttf(boldFontData);
    pdf.addPage(
      pw.MultiPage(
        build: (pw.Context context) {
          List<pw.Widget> widgets = [];
          widgets.add(
            pw.Text('Activities', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: PdfColors.deepPurple800, font: notoBoldFont)),
          );
          widgets.add(pw.SizedBox(height: 6));
          widgets.add(
            pw.Text('This report lists all activities with their participants', style: pw.TextStyle(fontSize: 12, color: PdfColors.grey600, font: notoFont)),
          );
          widgets.add(pw.SizedBox(height: 18));
          for (final report in _reports) {
            final isNoActivity = report['noActivityThisWeek'] == true;
            final activity = report['activity'] ?? (isNoActivity ? 'No Activity' : '');
            final mentorName = _mentorNames[report['mentorId']] ?? '';
            final dateRaw = report['startdate'] ?? report['reportId'] ?? '';
            String formattedDate = '';
            try {
              if (dateRaw.isNotEmpty) {
                final dt = DateTime.parse(dateRaw.substring(0, 10));
                formattedDate = DateFormat('MMMM d, yyyy').format(dt);
              }
            } catch (e) {
              formattedDate = dateRaw;
            }
            // Activity Title
            widgets.add(
              pw.Text(activity, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.red800, font: notoBoldFont)),
            );
            // Meta line (use '•' between mentor and date)
            String metaText = 'by $mentorName';
            if (formattedDate.isNotEmpty) metaText += ' • $formattedDate';
            widgets.add(
              pw.Text(metaText, style: pw.TextStyle(fontSize: 12, color: PdfColors.grey800, font: notoFont)),
            );
            // Notes or Reason
            final notes = report['notes'] ?? '';
            final reason = report['noActivityReason'] ?? report['reason'] ?? '';
            if (isNoActivity) {
              widgets.add(
                pw.Text('Reason: $reason', style: pw.TextStyle(fontSize: 12, color: PdfColors.grey600, fontStyle: pw.FontStyle.italic, font: notoFont)),
              );
            } else if (notes.isNotEmpty) {
              widgets.add(
                pw.Text('Notes: $notes', style: pw.TextStyle(fontSize: 12, color: PdfColors.grey600, fontStyle: pw.FontStyle.italic, font: notoFont)),
              );
            }
            // Mentees table
            final mentees = List<Map<String, dynamic>>.from(report['menteesDetails'] ?? []);
            if (mentees.isNotEmpty) {
              widgets.add(pw.SizedBox(height: 8));
              final menteeHeaders = ['Student', 'Grade', 'Joined', 'Joined Date', 'Days'];
              final data = mentees.map((mentee) => [
                '${mentee['firstName'] ?? ''} ${mentee['lastName'] ?? ''}',
                mentee['grade'] ?? '',
                (mentee['joined'] ?? false) ? 'Yes' : 'No',
                (() {
                  final joinedDateRaw = mentee['joinDate'] ?? '';
                  if (joinedDateRaw.isNotEmpty) {
                    try {
                      final dt = DateTime.parse(joinedDateRaw);
                      return '${_monthName(dt.month)} ${dt.day}, ${dt.year}';
                    } catch (_) {
                      return joinedDateRaw;
                    }
                  }
                  return '';
                })(),
                (mentee['days'] ?? 1).toString(),
              ]).toList();
              widgets.add(
                pw.Table.fromTextArray(
                  headers: menteeHeaders,
                  data: data,
                  headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 13, font: notoBoldFont),
                  headerDecoration: const pw.BoxDecoration(color: PdfColors.indigo900),
                  cellStyle: pw.TextStyle(fontSize: 12, color: PdfColors.black, font: notoFont),
                  cellAlignment: pw.Alignment.center,
                  cellAlignments: {for (var i = 0; i < menteeHeaders.length; i++) i: pw.Alignment.center},
                  cellDecoration: (index, data, rowNum) => pw.BoxDecoration(
                    color: rowNum % 2 == 0 ? PdfColors.grey300 : PdfColors.white,
                    border: pw.TableBorder.all(color: PdfColors.black, width: 0.5),
                  ),
                  headerAlignments: {for (var i = 0; i < menteeHeaders.length; i++) i: pw.Alignment.center},
                  cellHeight: 27,
                  columnWidths: {for (var i = 0; i < menteeHeaders.length; i++) i: const pw.FixedColumnWidth(90)},
                ),
              );
            }
            widgets.add(pw.SizedBox(height: 18));
          }
          return widgets;
        },
      ),
    );
    final bytes = await pdf.save();
    // Web download removed - only mobile/desktop support
    final directory = await getApplicationDocumentsDirectory();
    final path = '${directory.path}/Activities.pdf';
    final file = File(path);
    await file.writeAsBytes(bytes, flush: true);
    setState(() => _isLoading = false);
    OpenFile.open(path);
  }

  Future<void> _exportToExcel() async {
    setState(() => _isLoading = true);
    final workbook = xlsio.Workbook();
    final sheet = workbook.worksheets[0];
    sheet.showGridlines = false;
    // Styles
    final xlsio.Style titleStyle = workbook.styles.add('titleStyle');
    titleStyle.fontSize = 22;
    titleStyle.bold = true;
    titleStyle.hAlign = xlsio.HAlignType.left;
    titleStyle.vAlign = xlsio.VAlignType.center;
    final xlsio.Style subtitleStyle = workbook.styles.add('subtitleStyle');
    subtitleStyle.fontSize = 12;
    subtitleStyle.fontColor = '#555555';
    subtitleStyle.hAlign = xlsio.HAlignType.left;
    final xlsio.Style activityTitleStyle = workbook.styles.add('activityTitleStyle');
    activityTitleStyle.fontSize = 14;
    activityTitleStyle.bold = true;
    activityTitleStyle.fontColor = '#C00000'; // Dark Red
    activityTitleStyle.hAlign = xlsio.HAlignType.left;
    final xlsio.Style metaStyle = workbook.styles.add('metaStyle');
    metaStyle.fontSize = 11;
    metaStyle.fontColor = '#333333';
    metaStyle.hAlign = xlsio.HAlignType.left;
    final xlsio.Style notesStyle = workbook.styles.add('notesStyle');
    notesStyle.fontSize = 11;
    notesStyle.italic = true;
    notesStyle.fontColor = '#333333';
    notesStyle.hAlign = xlsio.HAlignType.left;
    final xlsio.Style reasonHeaderStyle = workbook.styles.add('reasonHeaderStyle');
    reasonHeaderStyle.bold = true;
    reasonHeaderStyle.fontSize = 11;
    reasonHeaderStyle.fontColor = '#666666';
    reasonHeaderStyle.hAlign = xlsio.HAlignType.left;
    final xlsio.Style reasonContentStyle = workbook.styles.add('reasonContentStyle');
    reasonContentStyle.italic = true;
    reasonContentStyle.fontSize = 11;
    reasonContentStyle.fontColor = '#666666';
    reasonContentStyle.hAlign = xlsio.HAlignType.left;
    final xlsio.Style headerStyle = workbook.styles.add('headerStyle');
    headerStyle.bold = true;
    headerStyle.fontSize = 11;
    headerStyle.hAlign = xlsio.HAlignType.center;
    headerStyle.vAlign = xlsio.VAlignType.center;
    headerStyle.borders.all.lineStyle = xlsio.LineStyle.thin;
    headerStyle.borders.all.color = '#000000';
    headerStyle.backColor = '#1A3353';
    headerStyle.fontColor = '#FFFFFF';
    final xlsio.Style cellStyle = workbook.styles.add('cellStyle');
    cellStyle.fontSize = 11;
    cellStyle.hAlign = xlsio.HAlignType.center;
    cellStyle.vAlign = xlsio.VAlignType.center;
    cellStyle.borders.all.lineStyle = xlsio.LineStyle.thin;
    cellStyle.borders.all.color = '#000000';
    // Set column widths
    sheet.getRangeByName('A1').columnWidth = 25;
    sheet.getRangeByName('B1').columnWidth = 15;
    sheet.getRangeByName('C1').columnWidth = 12;
    sheet.getRangeByName('D1').columnWidth = 18;
    sheet.getRangeByName('E1').columnWidth = 10;
    int row = 1;
    // Main Title
    sheet.getRangeByIndex(row, 1, row, 5).merge();
    sheet.getRangeByIndex(row, 1).setText('Activities');
    sheet.getRangeByIndex(row, 1).cellStyle = titleStyle;
    sheet.setRowHeightInPixels(row, 30);
    row++;
    // Subtitle
    sheet.getRangeByIndex(row, 1, row, 5).merge();
    sheet.getRangeByIndex(row, 1).setText('This report lists all activities with their participants');
    sheet.getRangeByIndex(row, 1).cellStyle = subtitleStyle;
    row++;
    row++; // Empty row
    // For each activity
    for (final report in _reports) {
      // Activity Title
      sheet.getRangeByIndex(row, 1, row, 5).merge();
      final isNoActivity = report['noActivityThisWeek'] == true;
      final activity = report['activity'] ?? (isNoActivity ? 'No Activity' : '');
      sheet.getRangeByIndex(row, 1).setText(activity);
      sheet.getRangeByIndex(row, 1).cellStyle = activityTitleStyle;
      row++;
      // Meta line
      final mentorName = _mentorNames[report['mentorId']] ?? '';
      final dateRaw = report['startdate'] ?? report['reportId'] ?? '';
      String formattedDate = '';
      try {
        if (dateRaw.isNotEmpty) {
          final dt = DateTime.parse(dateRaw.substring(0, 10));
          formattedDate = DateFormat('MMMM d, yyyy').format(dt);
        }
      } catch (e) {
        formattedDate = dateRaw;
      }
      String metaText = 'by $mentorName • $formattedDate';
      
      sheet.getRangeByIndex(row, 1, row, 5).merge();
      sheet.getRangeByIndex(row, 1).setText(metaText);
      sheet.getRangeByIndex(row, 1).cellStyle = metaStyle;
      row++;
      // Notes or Reason
      final notes = report['notes'] ?? '';
      final reason = report['noActivityReason'] ?? report['reason'] ?? '';
      if (isNoActivity) {
        // For "No Activity", show Reason: [content] in one line, italic, gray.
        sheet.getRangeByIndex(row, 1, row, 5).merge();
        sheet.getRangeByIndex(row, 1).setText('Reason: $reason');
        sheet.getRangeByIndex(row, 1).cellStyle = reasonContentStyle;
        row++;
      } else {
        // For normal activities, only show the "Notes:" line if notes exist.
        if (notes.isNotEmpty) {
          final notesText = 'Notes: $notes';
          sheet.getRangeByIndex(row, 1, row, 5).merge();
          sheet.getRangeByIndex(row, 1).setText(notesText);
          sheet.getRangeByIndex(row, 1).cellStyle = notesStyle;
          row++;
        }
      }
      // Mentees table
      final mentees = List<Map<String, dynamic>>.from(report['menteesDetails'] ?? []);
      if (mentees.isNotEmpty) {
        // Table header
        final menteeHeaders = ['Student', 'Grade', 'Joined', 'Joined Date', 'Days'];
        for (int col = 0; col < menteeHeaders.length; col++) {
          sheet.getRangeByIndex(row, col + 1).setText(menteeHeaders[col]);
          sheet.getRangeByIndex(row, col + 1).cellStyle = headerStyle;
        }
        row++;
        // Table rows
        for (final mentee in mentees) {
          final joinedDateRaw = mentee['joinDate'] ?? '';
          String joinedDate = '';
          if (joinedDateRaw.isNotEmpty) {
            try {
              final dt = DateTime.parse(joinedDateRaw);
              joinedDate = '${_monthName(dt.month)} ${dt.day}, ${dt.year}';
            } catch (_) {
              joinedDate = joinedDateRaw;
            }
          }
          sheet.getRangeByIndex(row, 1).setText('${mentee['firstName'] ?? ''} ${mentee['lastName'] ?? ''}');
          sheet.getRangeByIndex(row, 2).setText(mentee['grade'] ?? '');
          sheet.getRangeByIndex(row, 3).setText((mentee['joined'] ?? false) ? 'Yes' : 'No');
          sheet.getRangeByIndex(row, 4).setText(joinedDate);
          sheet.getRangeByIndex(row, 5).setNumber((mentee['days'] ?? 1).toDouble());
          for (int c = 1; c <= 5; c++) {
            sheet.getRangeByIndex(row, c).cellStyle = cellStyle;
          }
          row++;
        }
      }
      row++;
      row++; // 2 empty rows
    }
    final List<int> bytes = workbook.saveAsStream();
    workbook.dispose();
    // Web download removed - only mobile/desktop support
    final directory = await getApplicationDocumentsDirectory();
    final path = '${directory.path}/Activities.xlsx';
    final file = File(path);
    await file.writeAsBytes(bytes, flush: true);
    setState(() => _isLoading = false);
    OpenFile.open(path);
  }

  Future<void> _exportToCsv() async {
    setState(() => _isLoading = true);
    List<List<String>> rows = [];
    // Header
    rows.add(['Activity', 'Mentor', 'Date', 'Notes/Reason', 'Student', 'Grade', 'Joined', 'Joined Date', 'Days']);
    for (final report in _reports) {
      final activity = report['activity'] ?? (report['noActivityThisWeek'] == true ? 'No Activity' : '');
      final mentorName = _mentorNames[report['mentorId']] ?? '';
      final dateRaw = report['startdate'] ?? report['reportId'] ?? '';
      String date = dateRaw;
      // Format date as yyyy-MM-dd for CSV
      if (dateRaw.isNotEmpty) {
        try {
          final dt = DateTime.parse(dateRaw);
          date = '${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
        } catch (_) {
          date = dateRaw;
        }
      }
      final notes = report['notes'] ?? '';
      final reason = report['noActivityReason'] ?? report['reason'] ?? '';
      final mentees = List<Map<String, dynamic>>.from(report['menteesDetails'] ?? []);
      final notesOrReason = report['noActivityThisWeek'] == true ? reason : notes;
      if (mentees.isNotEmpty) {
        for (final mentee in mentees) {
          // Format joined date as yyyy-MM-dd for CSV
          String joinedDate = mentee['joinDate'] ?? '';
          if (joinedDate.isNotEmpty) {
            try {
              final dt = DateTime.parse(joinedDate);
              joinedDate = '${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
            } catch (_) {}
          }
          rows.add([
            activity,
            mentorName,
            date,
            notesOrReason,
            '${mentee['firstName'] ?? ''} ${mentee['lastName'] ?? ''}',
            mentee['grade'] ?? '',
            (mentee['joined'] ?? false) ? 'Yes' : 'No',
            joinedDate,
            (mentee['days'] ?? 1).toString(),
          ]);
        }
      } else {
        // No Activity or no mentees
        rows.add([
          activity,
          mentorName,
          date,
          notesOrReason,
          '', '', '', '', ''
        ]);
      }
    }
    String csvData = const ListToCsvConverter().convert(rows);
    final bytes = utf8.encode(csvData);
    // Web download removed - only mobile/desktop support
    final directory = await getApplicationDocumentsDirectory();
    final path = '${directory.path}/Activities.csv';
    final file = File(path);
    await file.writeAsBytes(bytes, flush: true);
    setState(() => _isLoading = false);
    OpenFile.open(path);
  }

  Future<void> _exportToText() async {
    setState(() => _isLoading = true);
    StringBuffer buffer = StringBuffer();
    for (final report in _reports) {
      final activity = report['activity'] ?? (report['noActivityThisWeek'] == true ? 'No Activity' : '');
      final mentorName = _mentorNames[report['mentorId']] ?? '';
      final date = report['startdate'] ?? report['reportId'] ?? '';
      final mentees = List<Map<String, dynamic>>.from(report['menteesDetails'] ?? []);
      final notes = report['notes'] ?? '';
      final reason = report['noActivityReason'] ?? report['reason'] ?? '';
      buffer.writeln('Activity: $activity');
      buffer.writeln('Mentor: $mentorName');
      if (date.isNotEmpty) buffer.writeln('Date: $date');
      if (report['noActivityThisWeek'] == true) {
        buffer.writeln('Reason: $reason');
      } else if (notes.isNotEmpty) {
        buffer.writeln('Notes: $notes');
      }
      if (mentees.isNotEmpty) {
        buffer.writeln('Student | Grade | Joined | Joined Date | Days');
        for (final mentee in mentees) {
          buffer.writeln([
            '${mentee['firstName'] ?? ''} ${mentee['lastName'] ?? ''}',
            mentee['grade'] ?? '',
            (mentee['joined'] ?? false) ? 'Yes' : 'No',
            mentee['joinDate'] ?? '',
            (mentee['days'] ?? 1).toString(),
          ].join(' | '));
        }
      }
      buffer.writeln('');
    }
    final bytes = utf8.encode(buffer.toString());
    // Web download removed - only mobile/desktop support
    final directory = await getApplicationDocumentsDirectory();
    final path = '${directory.path}/Activities.txt';
    final file = File(path);
    await file.writeAsBytes(bytes, flush: true);
    setState(() => _isLoading = false);
    OpenFile.open(path);
  }

  Future<void> _exportToHtml() async {
    setState(() => _isLoading = true);
    final buffer = StringBuffer();
    buffer.writeln('<!DOCTYPE html>');
    buffer.writeln('<html lang="en"><head><meta charset="UTF-8"><title>Activities</title>');
    buffer.writeln('<style>');
    buffer.writeln('body { font-family: Arial, sans-serif; background: #f7f7fa; }');
    buffer.writeln('h2 { color: #B71C1C; margin-bottom: 0; }');
    buffer.writeln('h3 { color: #333; margin-top: 4px; margin-bottom: 0; }');
    buffer.writeln('p.meta { color: #222; font-size: 13px; margin: 2px 0 8px 0; }');
    buffer.writeln('p.note { color: #444; font-size: 13px; margin: 2px 0 8px 0; }');
    buffer.writeln('p.reason { color: #B71C1C; font-size: 13px; margin: 2px 0 8px 0; }');
    buffer.writeln('table { border-collapse: collapse; width: 100%; margin-bottom: 24px; }');
    buffer.writeln('th, td { border: 1px solid #000; padding: 6px; text-align: center; font-size: 13px; }');
    buffer.writeln('th { background: #1A3353; color: #fff; font-weight: bold; }');
    buffer.writeln('tr.alt td { background: #F2F2F2; }');
    buffer.writeln('</style></head><body>');
    for (final report in _reports) {
      final activity = report['activity'] ?? (report['noActivityThisWeek'] == true ? 'No Activity' : '');
      final mentorName = _mentorNames[report['mentorId']] ?? '';
      final dateRaw = report['startdate'] ?? report['reportId'] ?? '';
      String formattedDate = '';
      try {
        if (dateRaw.isNotEmpty) {
          final dt = DateTime.parse(dateRaw.substring(0, 10));
          formattedDate = DateFormat('MMMM d, yyyy').format(dt);
        }
      } catch (e) {
        formattedDate = dateRaw;
      }
      final mentees = List<Map<String, dynamic>>.from(report['menteesDetails'] ?? []);
      final notes = report['notes'] ?? '';
      final reason = report['noActivityReason'] ?? report['reason'] ?? '';
      buffer.writeln('<h2>$activity</h2>');
      // Mentor and date in one line with •
      if (mentorName.isNotEmpty || formattedDate.isNotEmpty) {
        buffer.writeln('<p class="meta">Mentor: $mentorName • $formattedDate</p>');
      }
      if (report['noActivityThisWeek'] == true) {
        buffer.writeln('<p class="reason">Reason: $reason</p>');
      } else if (notes.isNotEmpty) {
        buffer.writeln('<p class="note">Notes: $notes</p>');
      }
      if (mentees.isNotEmpty) {
        buffer.writeln('<table>');
        buffer.writeln('<tr>');
        final headers = ['Student', 'Grade', 'Joined', 'Joined Date', 'Days'];
        for (final h in headers) {
          buffer.write('<th>$h</th>');
        }
        buffer.writeln('</tr>');
        for (int i = 0; i < mentees.length; i++) {
          final mentee = mentees[i];
          final alt = i % 2 == 1 ? ' class="alt"' : '';
          // Format joined date
          String joinedDate = mentee['joinDate'] ?? '';
          if (joinedDate.isNotEmpty) {
            try {
              final dt = DateTime.parse(joinedDate);
              final months = [
                'January', 'February', 'March', 'April', 'May', 'June',
                'July', 'August', 'September', 'October', 'November', 'December'
              ];
              joinedDate = '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
            } catch (_) {}
          }
          buffer.writeln('<tr$alt>');
          buffer.write('<td>${mentee['firstName'] ?? ''} ${mentee['lastName'] ?? ''}</td>');
          buffer.write('<td>${mentee['grade'] ?? ''}</td>');
          buffer.write('<td>${(mentee['joined'] ?? false) ? 'Yes' : 'No'}</td>');
          buffer.write('<td>$joinedDate</td>');
          buffer.write('<td>${mentee['days'] ?? 1}</td>');
          buffer.writeln('</tr>');
        }
        buffer.writeln('</table>');
      }
      buffer.writeln('<hr style="margin:24px 0;">');
    }
    buffer.writeln('</body></html>');
    final bytes = utf8.encode(buffer.toString());
    // Web download removed - only mobile/desktop support
    final directory = await getApplicationDocumentsDirectory();
    final path = '${directory.path}/Activities.html';
    final file = File(path);
    await file.writeAsBytes(bytes, flush: true);
    setState(() => _isLoading = false);
    OpenFile.open(path);
  }

  String _monthName(int month) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return months[month - 1];
  }

  @override
  Widget build(BuildContext context) {
    // Sort reports by date, newest first
    final sortedReports = List<Map<String, dynamic>>.from(_reports);
    sortedReports.sort((a, b) {
      String getDateStr(Map<String, dynamic> r) {
        final raw = (r['startdate'] ?? r['reportId'] ?? '').toString();
        return raw.length >= 10 ? raw.substring(0, 10) : raw;
      }
      final dateA = DateTime.tryParse(getDateStr(a));
      final dateB = DateTime.tryParse(getDateStr(b));
      if (dateA == null && dateB == null) return 0;
      if (dateA == null) return 1;
      if (dateB == null) return -1;
      return dateB.compareTo(dateA); // newest first
    });
    final startDate = widget.filters['startDate'] as DateTime?;
    final endDate = widget.filters['endDate'] as DateTime?;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent, // To see the gradient
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Activities Report', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
            const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Colors.white))),
          if (!_isLoading && _error != null)
            Center(child: Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 16))),
          if (!_isLoading && _error == null)
            SafeArea(
              child: Stack(
                children: [
                  Positioned.fill(
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
                                  'This report lists all activities with their participants.',
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
                          if (sortedReports.isEmpty)
                            Center(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  padding: EdgeInsets.all(16),
                                  color: Colors.white.withOpacity(0.1),
                                  child: Text(
                                    'No activities found.',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                            ),
                          ...sortedReports.map((report) {
                            final isNoActivity = report['noActivityThisWeek'] == true;
                            final mentorName = _mentorNames[report['mentorId']] ?? '';
                            final dateStr = report['startdate'] ?? report['reportId'] ?? '';
                            String formattedDate = '';
                            try {
                              if (dateStr.isNotEmpty) {
                                formattedDate = DateFormat('MMMM d, yyyy').format(DateTime.parse(dateStr.substring(0, 10)));
                              }
                            } catch (e) {
                              formattedDate = dateStr; // fallback to original string
                            }
                            final activity = report['activity'] ?? 'No Activity';
                            final notes = report['notes'] ?? '';
                            final reason = report['noActivityReason'] ?? report['reason'] ?? '';
                            final mentees = report['menteesDetails'] as List<dynamic>? ?? [];
                            return Container(
                              margin: const EdgeInsets.only(bottom: 16),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Colors.white.withOpacity(0.4),
                                    Colors.white.withOpacity(0.2),
                                  ],
                                ),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.5),
                                  width: 1,
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      isNoActivity ? 'No Activity' : activity,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: isNoActivity ? Colors.red.shade700 : const Color(0xFF333333),
                                        fontSize: 18,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'by $mentorName • $formattedDate',
                                      style: TextStyle(
                                        color: Colors.grey[800],
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    if (isNoActivity) ...[
                                      const SizedBox(height: 12),
                                      Text(
                                        'Reason:',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black.withOpacity(0.6),
                                          fontSize: 14,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        reason,
                                        style: TextStyle(color: Colors.black.withOpacity(0.8), fontSize: 14, fontStyle: FontStyle.italic),
                                      )
                                    ] else ...[
                                      if (mentees.isNotEmpty)
                                        LayoutBuilder(
                                          builder: (context, constraints) {
                                            return Container(
                                              margin: const EdgeInsets.only(top: 12),
                                              decoration: BoxDecoration(
                                                borderRadius: BorderRadius.circular(12),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: Colors.black.withOpacity(0.1),
                                                    blurRadius: 10,
                                                    offset: const Offset(0, 5),
                                                  ),
                                                ],
                                              ),
                                              child: ClipRRect(
                                                borderRadius: BorderRadius.circular(12),
                                                child: SingleChildScrollView(
                                                  scrollDirection: Axis.horizontal,
                                                  child: ConstrainedBox(
                                                    constraints: BoxConstraints(minWidth: constraints.maxWidth),
                                                    child: DataTable(
                                                      dataRowHeight: 60,
                                                      columnSpacing: 8,
                                                      headingRowColor: WidgetStateProperty.all(Colors.blueGrey[900]),
                                                      columns: const [
                                                        DataColumn(label: Text('Student', style: TextStyle(color: Colors.white, fontSize: 13))),
                                                        DataColumn(label: Text('Grade', style: TextStyle(color: Colors.white, fontSize: 13))),
                                                        DataColumn(label: Text('Joined', style: TextStyle(color: Colors.white, fontSize: 13))),
                                                        DataColumn(label: Text('Joined Date', style: TextStyle(color: Colors.white, fontSize: 13))),
                                                        DataColumn(label: Text('Days', style: TextStyle(color: Colors.white, fontSize: 12))),
                                                      ],
                                                      rows: List<DataRow>.generate(
                                                        mentees.length,
                                                        (index) => DataRow(
                                                          color: WidgetStateProperty.resolveWith<Color?>(
                                                            (Set<WidgetState> states) {
                                                              return index % 2 == 0
                                                                  ? Colors.white
                                                                  : const Color.fromARGB(255, 231, 242, 255);
                                                            },
                                                          ),
                                                          cells: [
                                                            DataCell(Text(
                                                              (mentees[index]['firstName'] ?? '') + ' ' + (mentees[index]['lastName'] ?? ''),
                                                              style: const TextStyle(color: Colors.black, fontSize: 12),
                                                            )),
                                                            DataCell(Text(
                                                              (mentees[index]['grade'] ?? '').toString().replaceAll(' grade', ''),
                                                              style: const TextStyle(color: Colors.black, fontSize: 13),
                                                            )),
                                                            DataCell(Text(
                                                              (mentees[index]['joined'] ?? false) ? 'Yes' : 'No',
                                                              style: const TextStyle(color: Colors.black, fontSize: 12),
                                                            )),
                                                            DataCell(Text(
                                                              () {
                                                                final joinDateStr = mentees[index]['joinDate'] ?? '';
                                                                if (joinDateStr.isEmpty) return '';
                                                                try {
                                                                  return DateFormat('MMMM d, yyyy').format(DateTime.parse(joinDateStr));
                                                                } catch (e) {
                                                                  return joinDateStr;
                                                                }
                                                              }(),
                                                              style: const TextStyle(color: Colors.black, fontSize: 12),
                                                            )),
                                                            DataCell(
                                                              Padding(
                                                                padding: const EdgeInsets.only(left: 12),
                                                                child: Text(
                                                                  mentees[index]['days']?.toString() ?? '',
                                                                  style: const TextStyle(color: Colors.black, fontSize: 12),
                                                                ),
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                      headingTextStyle: const TextStyle(fontWeight: FontWeight.bold),
                                                      dividerThickness: 0,
                                                      horizontalMargin: 4,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      if (notes.isNotEmpty) ...[
                                        const SizedBox(height: 12),
                                        Text(
                                          'Notes:',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.black.withOpacity(0.6),
                                            fontSize: 14,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          notes,
                                          style: TextStyle(color: Colors.black.withOpacity(0.8), fontSize: 14, fontStyle: FontStyle.italic),
                                        ),
                                      ]
                                    ]
                                  ],
                                ),
                              ),
                            );
                          }),
                          const SizedBox(height: 32),
                          if (_reports.isNotEmpty)
                            Center(
                              child: DownloadDropdownButton(
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
              ),
            ),
        ],
      ),
    );
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