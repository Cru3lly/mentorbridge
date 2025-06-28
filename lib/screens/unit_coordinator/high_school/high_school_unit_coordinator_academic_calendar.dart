import 'package:flutter/material.dart';
import 'package:glassmorphism/glassmorphism.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import 'package:url_launcher/url_launcher.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
// Web fallback için ekle thbhybg
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:typed_data';
import 'package:firebase_auth/firebase_auth.dart';

class HighSchoolUnitCoordinatorAcademicCalendar extends StatefulWidget {
  const HighSchoolUnitCoordinatorAcademicCalendar({super.key});

  @override
  State<HighSchoolUnitCoordinatorAcademicCalendar> createState() => _HighSchoolUnitCoordinatorAcademicCalendarState();
}

class _HighSchoolUnitCoordinatorAcademicCalendarState extends State<HighSchoolUnitCoordinatorAcademicCalendar> {
  final List<String> months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];
  final List<String> monthShort = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];
  String selectedYear = '2025';
  String? expandedMonth;
  int? expandedWeek;
  String get unitCoordinatorId => FirebaseAuth.instance.currentUser?.uid ?? '';
  static const String youtubeApiKey = 'AIzaSyC7FcRIPbpSWmv_SwzGN_XMoRA7rVDf8pY';
  bool editMode = false;
  bool hasChanges = false;
  Map<String, TextEditingController> titleControllers = {};
  Map<String, TextEditingController> descControllers = {};
  Map<String, List<Map<String, dynamic>>> linkControllers = {};
  Map<String, List<Map<String, dynamic>>> attachmentControllers = {};
  Map<String, bool> dirtyWeeks = {};
  Map<String, List<dynamic>> pendingUploads = {};
  Map<String, List<String>> pendingUploadNames = {};
  Map<String, List<String>> pendingDeleteUrls = {};

  // Holds all week data for the selected year, loaded once.
  // Key: "month-weekNumber", Value: week data map
  Map<String, Map<String, dynamic>> _calendarDataForYear = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAllWeeksForYear();
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
      
      // Create a list of futures to fetch all months in parallel
      final List<Future<QuerySnapshot<Map<String, dynamic>>>> monthFutures = months.map((month) {
        return baseRef.collection(selectedYear).doc(month).collection('weeks').get();
      }).toList();
      
      // Wait for all futures to complete
      final List<QuerySnapshot<Map<String, dynamic>>> results = await Future.wait(monthFutures);
      
      // Process the results
      for (var i = 0; i < results.length; i++) {
        final month = months[i];
        final weeksSnapshot = results[i];
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

  List<Map<String, dynamic>> getWeeksForMonth(String month) {
    int year = int.parse(selectedYear);
    int monthIndex = months.indexOf(month);
    DateTime firstDayOfYear = DateTime(year, 1, 1);
    // İlk Pazartesi'yi bul
    DateTime firstMonday = firstDayOfYear.weekday == DateTime.monday
        ? firstDayOfYear
        : firstDayOfYear.add(Duration(days: (8 - firstDayOfYear.weekday) % 7));
    DateTime lastDayOfYear = DateTime(year, 12, 31);
    List<Map<String, dynamic>> allWeeks = [];
    DateTime weekStart = firstMonday;
    int weekNum = 1;
    while (weekStart.isBefore(lastDayOfYear) || weekStart.isAtSameMomentAs(lastDayOfYear)) {
      DateTime weekEnd = weekStart.add(const Duration(days: 6));
      allWeeks.add({
        'weekNumber': weekNum,
        'start': weekStart,
        'end': weekEnd,
      });
      weekStart = weekEnd.add(const Duration(days: 1));
      weekNum++;
    }
    // Şimdi bu ayda en az bir günü olan haftaları filtrele
    DateTime firstDayOfMonth = DateTime(year, monthIndex + 1, 1);
    DateTime lastDayOfMonth = DateTime(year, monthIndex + 2, 0);
    List<Map<String, dynamic>> monthWeeks = [];
    for (var week in allWeeks) {
      if (!(week['end'].isBefore(firstDayOfMonth) || week['start'].isAfter(lastDayOfMonth))) {
        // Tarih formatı: May 05 to May 11
        String startMonth = months[week['start'].month - 1];
        String endMonth = months[week['end'].month - 1];
        String range =
            '$startMonth '
            '${week['start'].day.toString().padLeft(2, '0')}'
            ' to '
            '$endMonth '
            '${week['end'].day.toString().padLeft(2, '0')}';
        monthWeeks.add({
          'weekNumber': week['weekNumber'],
          'dateRange': range,
          'title': '',
          'description': '',
          'links': [],
          'attachments': [],
        });
      }
    }
    return monthWeeks;
  }

  // This function is no longer needed as we load all data at once.
  // Future<Map<String, dynamic>?> fetchWeekData(String month, int weekNumber) async ...

  // Saves a single week's data to Firestore.
  Future<void> saveWeekData(String month, int weekNumber, Map<String, dynamic> data) async {
    if (unitCoordinatorId.isEmpty) {
      print('ERROR: unitCoordinatorId is empty! Cannot save to Firestore.');
      return;
    }
    final ref = FirebaseFirestore.instance
        .collection('academicCalendars')
        .doc(unitCoordinatorId)
        .collection(selectedYear)
        .doc(month)
        .collection('weeks')
        .doc('week_$weekNumber');
    print('Saving week data to Firestore: ${ref.path}');
    await ref.set(data, SetOptions(merge: true));
  }

  Future<String> fetchPageTitle(String url) async {
    try {
      if (url.contains('youtube.com') || url.contains('youtu.be')) {
        // YouTube video ID bul
        String? videoId;
        if (url.contains('v=')) {
          videoId = Uri.parse(url).queryParameters['v'];
        } else if (url.contains('youtu.be/')) {
          videoId = url.split('youtu.be/').last.split('?').first;
        }
        if (videoId != null) {
          // YouTube Data API ile başlık çek
          final apiUrl = 'https://www.googleapis.com/youtube/v3/videos?part=snippet&id=$videoId&key=$youtubeApiKey';
          final response = await http.get(Uri.parse(apiUrl));
          if (response.statusCode == 200) {
            final data = json.decode(response.body);
            if (data['items'] != null && data['items'].isNotEmpty) {
              return data['items'][0]['snippet']['title'];
            }
          }
        }
      } else {
        // Diğer web siteleri için
        final response = await http.get(
          Uri.parse(url),
          headers: {
            'User-Agent': 'Mozilla/5.0 (compatible; Googlebot/2.1; +http://www.google.com/bot.html)'
          },
        );
        final reg = RegExp(r'<title>(.*?)</title>', caseSensitive: false, dotAll: true);
        final match = reg.firstMatch(response.body);
        if (match != null) {
          return match.group(1) ?? url;
        }
      }
    } catch (_) {}
    return url;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('High School Academic Calendar'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
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
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Column(
                        children: [
                          const SizedBox(height: 20),
                          _buildYearSelector(),
                          const SizedBox(height: 20),
                          Expanded(
                            child: GlassmorphicContainer(
                              width: double.infinity,
                              height: double.infinity,
                              borderRadius: 28,
                              blur: 18,
                              alignment: Alignment.topCenter,
                              border: 2,
                              linearGradient: LinearGradient(
                                colors: [
                                  Colors.white.withOpacity(0.25),
                                  Colors.white.withOpacity(0.05),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderGradient: LinearGradient(
                                colors: [
                                  Colors.white.withOpacity(0.60),
                                  Colors.white.withOpacity(0.10),
                                ],
                              ),
                              child: ListView(
                                padding: const EdgeInsets.all(20),
                                children: [
                                  ...months.map((month) => _buildMonthTile(month)).toList(),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 80), // FAB'lar için boşluk
                        ],
                      ),
                    ),
                  ),
          ),
          // Global floating buttons
          if (!_isLoading) _buildFloatingButtons(),
        ],
      ),
    );
  }

  Widget _buildYearSelector() {
    return GlassmorphicContainer(
      width: 160,
      height: 50,
      borderRadius: 15,
      blur: 10,
      border: 1.5,
      linearGradient: LinearGradient(
        colors: [Colors.white.withOpacity(0.3), Colors.white.withOpacity(0.2)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderGradient: LinearGradient(
        colors: [Colors.white.withOpacity(0.6), Colors.white.withOpacity(0.3)],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Year:', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white.withOpacity(0.8))),
            const SizedBox(width: 12),
            DropdownButton<String>(
              value: selectedYear,
              items: [
                DropdownMenuItem(
                  value: '2025',
                  child: Text('2025', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.black87)),
                )
              ],
              onChanged: (val) {}, // Only 2025 for now
              underline: Container(),
              icon: Icon(Icons.keyboard_arrow_down, color: Colors.white.withOpacity(0.8)),
              dropdownColor: Colors.white.withOpacity(0.9),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFloatingButtons() {
    if (editMode) {
      return Positioned(
        bottom: 24,
        left: 24,
        right: 24,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _TextGlassButton(
              label: 'Cancel',
              textColor: const Color.fromARGB(255, 242, 56, 56).withOpacity(0.9),
              fontSize: 14,
              fontWeight: FontWeight.bold,
              onTap: () async {
                if (hasChanges) {
                  await showDiscardDialogWithDetails();
                } else {
                  setState(() {
                    editMode = false;
                  });
                }
              },
            ),
            _TextGlassButton(
              label: 'Save',
              textColor: const Color.fromARGB(255, 118, 165, 246).withOpacity(0.9),
              fontSize: 14,
              fontWeight: FontWeight.bold,
              onTap: () async {
                await saveAllDirtyWeeks();
                setState(() {
                  hasChanges = false;
                  editMode = false;
                });
              },
            ),
          ],
        ),
      );
    } else {
      return Positioned(
        bottom: 24,
        right: 24,
        child: _IconGlassButton(
          icon: Icons.edit,
          onTap: () => setState(() {
            editMode = true;
          }),
        ),
      );
    }
  }

  Widget _buildMonthTile(String month) {
    final isExpanded = expandedMonth == month;
    final weeks = getWeeksForMonth(month);
    return Card(
      elevation: isExpanded ? 4 : 2,
      color: Colors.white.withOpacity(isExpanded ? 0.4 : 0.25), // mimic glass
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          collapsedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Text(month, style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 17, color: Colors.black87)),
          trailing: Icon(
            isExpanded ? Icons.arrow_drop_up : Icons.arrow_drop_down,
            size: 30,
            color: Colors.black54,
          ),
          initiallyExpanded: isExpanded,
          onExpansionChanged: (expanded) {
            setState(() {
              expandedMonth = expanded ? month : null;
              expandedWeek = null;
            });
          },
          children: weeks.map((week) => _buildWeekTile(month, week)).toList(),
        ),
      ),
    );
  }

  Widget _buildWeekTile(String month, Map<String, dynamic> week) {
    final isExpanded = expandedWeek == week['weekNumber'];
    final key = weekKey(month, week['weekNumber']);

    // Initialize controllers from the loaded data or with empty values.
    final initialData = _calendarDataForYear[key];
    titleControllers.putIfAbsent(key, () => TextEditingController(text: initialData?['title'] ?? ''));
    descControllers.putIfAbsent(key, () => TextEditingController(text: initialData?['description'] ?? ''));
    linkControllers.putIfAbsent(key, () => List<Map<String, dynamic>>.from(initialData?['links'] ?? []));
    attachmentControllers.putIfAbsent(key, () => List<Map<String, dynamic>>.from(initialData?['attachments'] ?? []));
    
    pendingUploads.putIfAbsent(key, () => []);
    pendingUploadNames.putIfAbsent(key, () => []);
    dirtyWeeks.putIfAbsent(key, () => false);
    pendingDeleteUrls.putIfAbsent(key, () => []);

    Future<void> pickAndAddFileToPending(String key) async {
      if (kIsWeb) {
        html.FileUploadInputElement uploadInput = html.FileUploadInputElement();
        uploadInput.click();
        uploadInput.onChange.listen((e) async {
          final file = uploadInput.files?.first;
          if (file != null) {
            // Only html.File is added on web
            pendingUploads[key]!.add(file);
            pendingUploadNames[key]!.add(file.name);
            setState(() { dirtyWeeks[key] = true; hasChanges = true; });
          }
        });
      } else {
        FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.any);
        if (result != null && result.files.single.path != null) {
          final file = File(result.files.single.path!);
          // Only dart:io File is added on mobile/desktop
          pendingUploads[key]!.add(file);
          pendingUploadNames[key]!.add(result.files.single.name);
          setState(() { dirtyWeeks[key] = true; hasChanges = true; });
        }
      }
    }

    return StatefulBuilder(
      builder: (context, setState) {
        final TextEditingController linkController = TextEditingController();
        final TextEditingController linkTitleController = TextEditingController();
        
        final currentTitle = titleControllers[key]!.text;
        final currentDesc = descControllers[key]!.text;
        final currentLinks = linkControllers[key]!;
        final currentAttachments = attachmentControllers[key]!;

        Widget content;
        if (!editMode) {
          // Read-only mode
          bool hasAnyContent = currentTitle.isNotEmpty || currentDesc.isNotEmpty || currentLinks.isNotEmpty || currentAttachments.isNotEmpty;
          content = Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: Text(week['dateRange'], style: TextStyle(color: Colors.grey[700], fontStyle: FontStyle.italic, fontSize: 13)),
                ),
                const Divider(),
                const SizedBox(height: 8),
                if (hasAnyContent)
                  ...[
                    if (currentTitle.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(currentTitle, style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
                      ),
                    if (currentDesc.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(currentDesc, style: TextStyle(color: Colors.grey[800], fontSize: 14, height: 1.5)),
                      ),
                    if (currentLinks.isNotEmpty) ..._buildReadOnlyLinks(currentLinks),
                    if (currentAttachments.isNotEmpty) ..._buildReadOnlyAttachments(currentAttachments),
                  ]
                else
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Text('No content added yet.', style: TextStyle(color: Colors.grey)),
                    ),
                  ),
              ],
            ),
          );
        } else {
          // Edit mode: tüm week'ler editlenebilir
          content = Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: Text(week['dateRange'], style: TextStyle(color: Colors.grey[700], fontStyle: FontStyle.italic, fontSize: 13)),
                ),
                const Divider(),
                const SizedBox(height: 8),
                TextField(
                  controller: titleControllers[key],
                  decoration: _inputDecoration('Title'),
                  onChanged: (_) {
                    setState(() {
                      dirtyWeeks[key] = true;
                      hasChanges = true;
                    });
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descControllers[key],
                  decoration: _inputDecoration('Description'),
                  maxLines: 3,
                  onChanged: (_) {
                    setState(() {
                      dirtyWeeks[key] = true;
                      hasChanges = true;
                    });
                  },
                ),
                const SizedBox(height: 20),
                const Text("Links", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 8),
                ..._buildEditableLinks(key, currentLinks, linkController, linkTitleController, setState),
                const SizedBox(height: 20),
                const Text("Files", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 8),
                ..._buildEditableAttachments(key, currentAttachments, setState),
                
                // Pending uploads
                if (pendingUploadNames[key]!.isNotEmpty)
                  ..._buildPendingUploads(key, setState),

                // Add File butonu
                Align(
                  alignment: Alignment.centerLeft,
                  child: _buildAddFileButton(
                    onPressed: () async => await pickAndAddFileToPending(key),
                  ),
                ),
              ],
            ),
          );
        }
        return Card(
          elevation: 0,
          color: Colors.white.withOpacity(0.5),
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              collapsedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              title: Text(
                'Week ${week['weekNumber']}',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14),
              ),
              initiallyExpanded: isExpanded,
              onExpansionChanged: (expanded) {
                setState(() {
                  expandedWeek = expanded ? week['weekNumber'] : null;
                });
              },
              children: [content],
            ),
          ),
        );
      },
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

  List<Widget> _buildEditableLinks(String key, List<Map<String, dynamic>> currentLinks, TextEditingController linkController, TextEditingController linkTitleController, StateSetter setState) {
    return [
      // Add new link fields
      Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: TextField(
              controller: linkController,
              decoration: _inputDecoration('Add link URL'),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.add_link, color: Colors.green, size: 30),
            onPressed: () async {
              String url = linkController.text.trim();
              String title = linkTitleController.text.trim();
              if (url.isNotEmpty) {
                if (title.isEmpty) {
                  title = await fetchPageTitle(url);
                }
                currentLinks.add({'url': url, 'title': title});
                linkController.clear();
                linkTitleController.clear();
                setState(() {
                  dirtyWeeks[key] = true;
                  hasChanges = true;
                });
              }
            },
          ),
        ],
      ),
      const SizedBox(height: 8),
      TextField(
        controller: linkTitleController,
        decoration: _inputDecoration('Title (optional)'),
      ),
      const SizedBox(height: 12),
      // List of existing links
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
                setState(() {
                  dirtyWeeks[key] = true;
                  hasChanges = true;
                });
              },
            ),
          ),
        );
      }).toList(),
    ];
  }

  List<Widget> _buildEditableAttachments(String key, List<Map<String, dynamic>> currentAttachments, StateSetter setState) {
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
              setState(() {
                dirtyWeeks[key] = true;
                hasChanges = true;
              });
            },
          ),
        ),
      );
    }).toList();
  }

  List<Widget> _buildPendingUploads(String key, StateSetter setState) {
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
              setState(() {}); // Re-render this specific week tile
            },
          ),
        ),
      );
    }).toList();
  }

  Widget _buildAddFileButton({required VoidCallback onPressed}) {
    return IconButton(
      onPressed: onPressed,
      icon: Icon(Icons.note_add_outlined, color: Colors.blue[700]),
      iconSize: 32,
      tooltip: 'Add File',
      splashRadius: 24,
    );
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

  Future<void> saveAllDirtyWeeks() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    final dirtyKeys = dirtyWeeks.entries.where((e) => e.value).map((e) => e.key).toList();

    for (final key in dirtyKeys) {
      final parts = key.split('-');
      final month = parts[0];
      final weekNumber = int.parse(parts[1]);
      
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
        pendingDeleteUrls[key]!.clear();
      }

      // Upload pending files and add them to the attachments list
      if (pendingUploads.containsKey(key) && pendingUploads[key]!.isNotEmpty) {
        // Web
        if (kIsWeb) {
          for (var i = 0; i < pendingUploads[key]!.length; i++) {
            final file = pendingUploads[key]![i] as html.File;
            final reader = html.FileReader();
            reader.readAsArrayBuffer(file);
            await reader.onLoad.first;
            final data = reader.result as Uint8List;
            String ext = file.name.split('.').last.toLowerCase();
            String storagePath = 'calendar_files/$unitCoordinatorId/$selectedYear/${month}_${weekNumber}/${file.name}';
            final ref = FirebaseStorage.instance.ref().child(storagePath);
            final uploadTask = ref.putData(data, SettableMetadata(contentType: file.type));
            final snapshot = await uploadTask.whenComplete(() {});
            String url = await snapshot.ref.getDownloadURL();
            String type = ["jpg", "jpeg", "png", "gif", "bmp", "webp"].contains(ext) ? 'image' : (ext == 'pdf' ? 'pdf' : 'file');
            finalAttachments.add({'type': type, 'url': url, 'name': file.name});
          }
        }
        // Mobile
        else {
          for (var i = 0; i < pendingUploads[key]!.length; i++) {
            final file = pendingUploads[key]![i] as File;
            String fileName = pendingUploadNames[key]![i];
            String ext = fileName.split('.').last.toLowerCase();
            String storagePath = 'calendar_files/$unitCoordinatorId/$selectedYear/${month}_${weekNumber}/$fileName';
            final ref = FirebaseStorage.instance.ref().child(storagePath);
            await ref.putFile(file);
            String url = await ref.getDownloadURL();
            String type = ["jpg", "jpeg", "png", "gif", "bmp", "webp"].contains(ext) ? 'image' : (ext == 'pdf' ? 'pdf' : 'file');
            finalAttachments.add({'type': type, 'url': url, 'name': fileName});
          }
        }
      }

      // Prepare final data for Firestore
      final Map<String, dynamic> weekDataToSave = {
        'title': titleControllers[key]?.text ?? '',
        'description': descControllers[key]?.text ?? '',
        'links': linkControllers[key] ?? [],
        'attachments': finalAttachments,
      };

      // Save to Firestore
      await saveWeekData(month, weekNumber, weekDataToSave);

      // Update local cache
      _calendarDataForYear[key] = weekDataToSave;
      attachmentControllers[key] = finalAttachments;
    }

    // Clear dirty states and pending uploads
    dirtyWeeks.clear();
    pendingUploads.clear();
    pendingUploadNames.clear();
    pendingDeleteUrls.clear();

    if (mounted) {
      setState(() {
        _isLoading = false;
        hasChanges = false; // Reset changes state after saving
      });
    }
  }

  Future<void> showDiscardDialogWithDetails() async {
    final changed = dirtyWeeks.entries.where((e) => e.value).toList();
    if (changed.isEmpty) {
      setState(() { editMode = false; });
      return;
    }
    final details = changed.map((e) {
      final parts = e.key.split('-');
      final month = parts[0];
      final week = parts[1];
      return '$selectedYear > $month > Week $week';
    }).join('\n');

    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard Changes?'),
        content: SingleChildScrollView(
          child: ListBody(
            children: <Widget>[
              const Text('You have unsaved changes in:'),
              const SizedBox(height: 8),
              Text(details, style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              const Text('Are you sure you want to discard them?'),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('No')),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Yes')),
        ],
      ),
    ) ?? false;

    if (discard) {
      // Clear all local changes and reload from the original data
      dirtyWeeks.clear();
      pendingUploads.clear();
      pendingUploadNames.clear();
      pendingDeleteUrls.clear();
      
      // We don't need to re-fetch from Firestore.
      // We just need to reset the controllers to their original state from _calendarDataForYear.
      // This is automatically handled by the widget rebuild when we exit edit mode.

      setState(() {
        editMode = false;
        hasChanges = false;
      });
    }
  }
}

class _IconGlassButton extends StatelessWidget {
  final VoidCallback onTap;
  final IconData icon;

  const _IconGlassButton({
    required this.onTap,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return GlassmorphicContainer(
      width: 56,
      height: 56,
      borderRadius: 28,
      blur: 10,
      border: 1.5,
      linearGradient: LinearGradient(
        colors: [Theme.of(context).primaryColor.withOpacity(0.3), Theme.of(context).primaryColor.withOpacity(0.2)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderGradient: LinearGradient(
        colors: [Colors.white.withOpacity(0.5), Colors.white.withOpacity(0.2)],
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(28),
        child: Center(child: Icon(icon, color: Colors.white)),
      ),
    );
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
    this.fontSize = 16,
    this.fontWeight = FontWeight.bold,
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
            style: GoogleFonts.inter(
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