import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:glassmorphism/glassmorphism.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'dart:ui';

class HighSchoolUnitCoordinatorStats extends StatefulWidget {
  const HighSchoolUnitCoordinatorStats({super.key});

  @override
  State<HighSchoolUnitCoordinatorStats> createState() =>
      _HighSchoolUnitCoordinatorStatsState();
}

class _HighSchoolUnitCoordinatorStatsState
    extends State<HighSchoolUnitCoordinatorStats> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  List<Map<String, dynamic>> _mentors = [];
  Map<String, bool> _selectedMentors = {};
  bool _isLoadingMentors = true;
  bool _isLoadingFilters = false;

  String? _selectedReportType;
  final List<String> _reportTypes = [
    'Active Students',
    'Activities',
    'Activity Counts',
    'Activity Counts By Mentor',
    'Activity Counts By Student',
    'Mentor List',
    'Student Counts',
    'Student Report Card',
  ];

  DateTime? _startDate;
  DateTime? _endDate;

  // State for filters
  List<String> _availableGrades = [];
  List<String> _availableGenders = [];
  List<String> _availableActivityTypes = [];
  List<String> _availableCities = [];
  List<String> _availableSchools = [];

  List<String> _selectedGrades = [];
  List<String> _selectedGenders = [];
  List<String> _selectedActivityTypes = [];

  List<String> _selectedCity = [];
  List<String> _selectedUnit = [];

  bool _isGeneratingReport = false;
  Map<String, dynamic>? _reportData;

  // Add state for quick date range selection
  String? _selectedQuickRange; // '3m', '6m', '12m'

  @override
  void initState() {
    super.initState();
    _fetchMentors();
    // Start date: 3 ay önce, End date: bugün
    final now = DateTime.now();
    _endDate = now;
    _startDate = DateTime(now.year, now.month - 1, now.day);
  }

  Future<void> _fetchMentors() async {
    setState(() {
      _isLoadingMentors = true;
    });

    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      // Handle user not logged in
      setState(() => _isLoadingMentors = false);
      return;
    }

    try {
      // 1. Fetch the coordinator's document
      final coordinatorDoc =
          await _firestore.collection('users').doc(currentUser.uid).get();
      if (!coordinatorDoc.exists) {
        setState(() => _isLoadingMentors = false);
        return;
      }
      final coordinatorData = coordinatorDoc.data();
      final city = coordinatorData?['city'];

      // 2. Get the list of mentor UIDs from the 'assignedTo' array
      final mentorUids =
          List<String>.from(coordinatorDoc.data()?['assignedTo'] ?? []);

      if (mentorUids.isEmpty) {
        setState(() {
          _mentors = [];
          _selectedMentors = {};
          _selectedCity = city != null ? [city] : [];
          _selectedUnit = [];
          _isLoadingMentors = false;
        });
        return;
      }

      // 3. Fetch the mentor documents using a 'whereIn' query
      final snapshot = await _firestore
          .collection('users')
          .where(FieldPath.documentId, whereIn: mentorUids)
          .get();

      final mentors = snapshot.docs.map((doc) {
        final data = doc.data();
        final firstName = data['firstName'] as String? ?? '';
        final lastName = data['lastName'] as String? ?? '';
        return <String, dynamic>{
          'uid': doc.id,
          'name': '$firstName $lastName'.trim(),
        };
      }).toList();

      setState(() {
        _mentors = mentors;
        _selectedMentors = {for (var mentor in _mentors) mentor['uid']: true};
        _selectedCity = city != null ? [city] : [];
        _selectedUnit = [];
        _isLoadingMentors = false;
      });
      // Populate filters initially based on all assigned mentors
      _populateFilters();
    } catch (e) {
      setState(() {
        _isLoadingMentors = false;
      });
      // Handle error
    }
  }

  Future<void> _populateFilters() async {
    setState(() { _isLoadingFilters = true; });
    final selectedMentorUids = _selectedMentors.entries
        .where((entry) => entry.value)
        .map((entry) => entry.key)
        .toList();

    if (selectedMentorUids.isEmpty) {
      setState(() {
        _availableGrades = [];
        _availableGenders = [];
        _availableActivityTypes = [];
        _availableCities = [];
        _availableSchools = [];
        _isLoadingFilters = false;
      });
      return;
    }

    // Fetch mentor docs for selected mentors to get their mentees
    final mentorDocs = await _firestore.collection('users').where(FieldPath.documentId, whereIn: selectedMentorUids).get();
    final allMenteeUids = <String>{};
    for (var mentorDoc in mentorDocs.docs) {
      final assignedMentees = List<String>.from(mentorDoc.data()['assignedTo'] ?? []);
      allMenteeUids.addAll(assignedMentees);
    }

    // Fetch mentees to get grades, genders, cities, schools
    final grades = <String>{};
    final genders = <String>{};
    final cities = <String>{};
    final schools = <String>{};
    if (allMenteeUids.isNotEmpty) {
      final menteeSnapshot = await _firestore
          .collection('users')
          .where(FieldPath.documentId, whereIn: allMenteeUids.toList())
          .get();

      for (var doc in menteeSnapshot.docs) {
        final data = doc.data();
        if (data['gradeLevel'] != null) grades.add(data['gradeLevel']);
        if (data['gender'] != null) genders.add(data['gender']);
        if (data['city'] != null) cities.add(data['city']);
        if (data['school'] != null) schools.add(data['school']);
      }
    }

    // Fetch reports to get activity types
    final activities = <String>{};
    for (String mentorId in selectedMentorUids) {
      final reportSnapshot = await _firestore
          .collection('weekendReports')
          .doc(mentorId)
          .collection('reports')
          .get();
      for (var doc in reportSnapshot.docs) {
        final data = doc.data();
        if (data['activity'] != null) {
          activities.add(data['activity']);
        }
      }
    }

    // --- Sıralama kuralları ---
    // City: alfabetik
    final sortedCities = cities.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    // School: Middle School varsa önce, sonra High School, sadece veride olanlar
    final schoolOrder = ['Middle School', 'High School'];
    final sortedSchools = [
      ...schoolOrder.where((s) => schools.contains(s)),
      ...schools.where((s) => !schoolOrder.contains(s)),
    ];

    // Gender: Male üstte, Female altta, sadece veride olanlar
    final genderOrder = ['Male', 'Female'];
    final sortedGenders = [
      ...genderOrder.where((g) => genders.contains(g)),
      ...genders.where((g) => !genderOrder.contains(g)),
    ];

    // Grades: sayısal küçükten büyüğe, sadece veride olanlar
    List<String> sortedGrades = grades.toList();
    sortedGrades.sort((a, b) {
      int parseGrade(String g) {
        if (g == 'College') return 99;
        final match = RegExp(r'^(\d+)th grade').firstMatch(g);
        if (match != null) return int.tryParse(match.group(1)!) ?? 0;
        return int.tryParse(g.replaceAll(RegExp(r'\D'), '')) ?? 0;
      }
      return parseGrade(a).compareTo(parseGrade(b));
    });

    // Activity Type: sabit sıralama, sadece veride olanlar
    final activityOrder = [
      'One on one activity',
      'Religious day program',
      'Daily reading program',
      'Parent meeting',
      'Home visit',
      'Out of state trip',
      'Out of town trip',
      'Tent camp',
      'Pre-mentor reading camp',
      'Mentor reading camp',
      'Reading camp',
      'Weekly mentoring',
      'No Activity',
    ];
    final sortedActivities = [
      ...activityOrder.where((a) => activities.contains(a)),
      ...activities.where((a) => !activityOrder.contains(a)),
    ];

    setState(() {
      _availableGrades = sortedGrades;
      _availableGenders = sortedGenders;
      _availableActivityTypes = sortedActivities;
      if (!_availableActivityTypes.contains('No Activity')) {
        _availableActivityTypes.add('No Activity');
      }
      _availableCities = sortedCities;
      _availableSchools = sortedSchools;

      // Set default selections to all
      _selectedGrades = List.from(_availableGrades);
      _selectedGenders = List.from(_availableGenders);
      _selectedActivityTypes = List.from(_availableActivityTypes);
      _selectedCity = List.from(_availableCities);
      _selectedUnit = List.from(_availableSchools);
      _isLoadingFilters = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Reports',
            style: TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => context.push('/settings'),
            tooltip: 'Settings',
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
          ),
          _isLoadingMentors
              ? const Center(
                  child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white)))
              : SafeArea(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildStepCard(
                          step: '1',
                          title: 'Select Report Details',
                          child: Column(
                            children: [
                              _buildMentorSelector(),
                              const SizedBox(height: 20),
                              _buildReportSelector(),
                            ],
                          ),
                        ),
                        if (_selectedReportType != null) ...[
                          const SizedBox(height: 24),
                          _buildStepCard(
                            step: '2',
                            title: 'Customize Filters',
                            child: _buildFilters(),
                          ),
                          const SizedBox(height: 24),
                          _buildActionButtons(),
                        ],
                      ],
                    ),
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildStepCard({
    required String step,
    required String title,
    required Widget child,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              width: 1,
              color: Colors.white.withOpacity(0.5),
            ),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withOpacity(0.1),
                Colors.white.withOpacity(0.05),
              ],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: Colors.white.withOpacity(0.2),
                      child: Text(step,
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                child,
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMentorSelector() {
    // Use a ValueNotifier to manage the state of the dropdown menu internally.
    // This allows the menu items and the chip button to update immediately without closing the dropdown.
    final ValueNotifier<Map<String, bool>> internalSelection = ValueNotifier(Map.from(_selectedMentors));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 4),
          child: Text('Select Mentors', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        ),
        DropdownButtonHideUnderline(
          child: DropdownButton2<String>(
            isExpanded: true,
            customButton: ValueListenableBuilder<Map<String, bool>>(
              valueListenable: internalSelection,
              builder: (context, currentSelection, _) {
                List<String> selectedMentorNames = _mentors
                    .where((m) => currentSelection[m['uid']] == true)
                    .map((m) => m['name'] as String)
                    .toList();
                
                String hintText;
                if (selectedMentorNames.isEmpty) {
                  hintText = '(None)';
                } else if (selectedMentorNames.length == _mentors.length) {
                  hintText = 'All';
                } else if (selectedMentorNames.length == 1) {
                  hintText = selectedMentorNames.first;
                } else {
                  hintText = selectedMentorNames.join(', ');
                }

                return GlassmorphicContainer(
                  width: double.infinity,
                  height: 58,
                  borderRadius: 12,
                  blur: 10,
                  alignment: Alignment.center,
                  border: 2,
                  linearGradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withOpacity(0.2),
                      Colors.white.withOpacity(0.1),
                    ],
                  ),
                  borderGradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withOpacity(0.5),
                      Colors.white.withOpacity(0.5),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            hintText,
                            style: const TextStyle(fontSize: 16, color: Colors.white),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                        const Icon(Icons.arrow_drop_down, color: Colors.white, size: 32),
                      ],
                    ),
                  ),
                );
              },
            ),
            onMenuStateChange: (isOpen) {
              if (isOpen) {
                // When opening, sync internal state with the parent's state.
                internalSelection.value = Map.from(_selectedMentors);
              } else {
                // When closing, update the parent state and repopulate filters.
                // This is more efficient as it's done only once.
                setState(() {
                  _selectedMentors = internalSelection.value;
                  _populateFilters();
                });
              }
            },
            items: [
              DropdownMenuItem<String>(
                value: '__select_all__',
                enabled: false,
                child: ValueListenableBuilder<Map<String, bool>>(
                  valueListenable: internalSelection,
                  builder: (context, currentSelection, _) {
                    final allSelected = currentSelection.isNotEmpty && currentSelection.values.every((v) => v);
                    return InkWell(
                      onTap: () {
                        final newSelection = Map<String, bool>.from(currentSelection);
                        for (var k in newSelection.keys) {
                          newSelection[k] = !allSelected;
                        }
                        internalSelection.value = newSelection;
                        setState(() {
                          _selectedMentors = newSelection;
                          _populateFilters();
                        });
                      },
                      child: Container(
                        child: Row(
                          children: [
                            Checkbox(
                              value: allSelected,
                              onChanged: (val) {
                                final newSelection = Map<String, bool>.from(currentSelection);
                                for (var k in newSelection.keys) {
                                  newSelection[k] = val ?? false;
                                }
                                internalSelection.value = newSelection;
                                setState(() {
                                  _selectedMentors = newSelection;
                                  _populateFilters();
                                });
                              },
                              activeColor: Colors.deepPurple,
                              checkColor: Colors.white,
                            ),
                            const Text('Select All', style: TextStyle(color: Colors.black)),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              ..._mentors.map((mentor) {
                return DropdownMenuItem<String>(
                  value: mentor['uid'],
                  enabled: false,
                  child: ValueListenableBuilder<Map<String, bool>>(
                    valueListenable: internalSelection,
                    builder: (context, currentSelection, _) {
                      final isSelected = currentSelection[mentor['uid']] ?? false;
                      return InkWell(
                        onTap: () {
                          final newSelection = Map<String, bool>.from(currentSelection);
                          newSelection[mentor['uid']] = !isSelected;
                          internalSelection.value = newSelection;
                          setState(() {
                            _selectedMentors = newSelection;
                            _populateFilters();
                          });
                        },
                        child: Container(
                          child: Row(
                            children: [
                              Checkbox(
                                value: isSelected,
                                onChanged: (val) {
                                  final newSelection = Map<String, bool>.from(currentSelection);
                                  newSelection[mentor['uid']] = val ?? false;
                                  internalSelection.value = newSelection;
                                  setState(() {
                                    _selectedMentors = newSelection;
                                    _populateFilters();
                                  });
                                },
                                activeColor: Colors.deepPurple,
                                checkColor: Colors.white,
                              ),
                              Text(mentor['name'] ?? '', style: const TextStyle(color: Colors.black)),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                );
              }),
            ],
            value: null,
            onChanged: (value) {},
            dropdownStyleData: DropdownStyleData(
              maxHeight: 240,
              width: 250,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: Colors.white,
              ),
              offset: const Offset(0, 0),
              elevation: 8,
            ),
            menuItemStyleData: const MenuItemStyleData(
              height: 40,
              padding: EdgeInsets.zero,
            ),
            iconStyleData: const IconStyleData(
              icon: SizedBox.shrink(), // Hide the default icon
              openMenuIcon: SizedBox.shrink(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReportSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 4),
          child: Text('Select Report Type', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        ),
        GlassmorphicContainer(
          width: double.infinity,
          height: 58,
          borderRadius: 12,
          blur: 10,
          alignment: Alignment.center,
          border: 2,
          linearGradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withOpacity(0.2),
              Colors.white.withOpacity(0.1),
            ],
          ),
          borderGradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withOpacity(0.5),
              Colors.white.withOpacity(0.5),
            ],
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton2<String>(
              isExpanded: true,
              hint: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 0.0),
                child: Text(
                  _selectedReportType ?? 'Select...',
                  style: const TextStyle(fontSize: 16, color: Colors.white),
                ),
              ),
              items: _reportTypes.map((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(
                    value,
                    style: const TextStyle(
                      color: Colors.white,
                    ),
                  ),
                );
              }).toList(),
              value: _selectedReportType,
              onChanged: (newValue) {
                setState(() {
                  _selectedReportType = newValue;
                  _selectedQuickRange = null;
                  // Reset report-specific filters when type changes
                  _reportData = null;
                });
              },
              buttonStyleData: ButtonStyleData(
                height: 58,
                decoration: BoxDecoration(
                  color: Colors.transparent,
                ),
              ),
              iconStyleData: const IconStyleData(
                icon: Icon(Icons.arrow_drop_down, color: Colors.white),
                iconSize: 32,
              ),
              dropdownStyleData: DropdownStyleData(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: Colors.blueGrey[800],
                ),
              ),
              menuItemStyleData: const MenuItemStyleData(
                height: 40,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFilters() {
    if (_selectedReportType == null) {
      return const SizedBox.shrink();
    }

    // Eğer mentor seçilmemişse filtreleri gösterme, uyarı göster
    final selectedMentorUids = _selectedMentors.entries.where((entry) => entry.value).map((entry) => entry.key).toList();
    if (selectedMentorUids.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24.0),
        child: Center(
          child: Text(
            'Please select at least one mentor first.',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ),
      );
    }

    if (_isLoadingFilters) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 32.0),
        child: Center(
          child: Column(
            children: [
              CircularProgressIndicator(color: Colors.white),
              SizedBox(height: 16),
              Text('Loading filters...', style: TextStyle(color: Colors.white)),
            ],
          ),
        ),
      );
    }

    final showActivityType = _selectedReportType == 'Activities' || _selectedReportType == 'Activity Counts' || _selectedReportType == 'Activity Counts By Mentor';
    final showStandardFilters = _selectedReportType == 'Active Students' ||
        _selectedReportType == 'Activities' ||
        _selectedReportType == 'Activity Counts' ||
        _selectedReportType == 'Activity Counts By Mentor';

    if (!showStandardFilters) {
      return const Center(
        child: Text(
          'This report type does not require additional filters.',
          style: TextStyle(color: Colors.white70),
        ),
      );
    }

    final List<Widget> filterChips = [];
    if (_availableCities.isNotEmpty) {
      filterChips.add(_buildFilterChip(
          label: 'Cities',
          icon: Icons.location_city_outlined,
          items: _availableCities,
          selectedItems: _selectedCity,
          onChanged: (values) => setState(() => _selectedCity = values)));
    }
    if (_availableSchools.isNotEmpty) {
      filterChips.add(_buildFilterChip(
          label: 'School',
          icon: Icons.school_outlined,
          items: _availableSchools,
          selectedItems: _selectedUnit,
          onChanged: (values) => setState(() => _selectedUnit = values)));
    }
    filterChips.add(_buildFilterChip(
        label: 'Gender',
        icon: Icons.wc_outlined,
        items: _availableGenders,
        selectedItems: _selectedGenders,
        onChanged: (values) => setState(() => _selectedGenders = values)));
    filterChips.add(_buildFilterChip(
        label: 'Grades',
        icon: Icons.class_outlined,
        items: _availableGrades,
        selectedItems: _selectedGrades,
        onChanged: (values) => setState(() => _selectedGrades = values)));
    if (showActivityType) {
      filterChips.add(_buildFilterChip(
          label: 'Activity Type',
          icon: Icons.local_activity_outlined,
          items: _availableActivityTypes,
          selectedItems: _selectedActivityTypes,
          onChanged: (values) => setState(() => _selectedActivityTypes = values)));
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_selectedReportType != 'Active Students') ...[
          Row(
            children: [
              Expanded(
                child: _buildDatePickerChip(
                  label: 'Start',
                  date: _startDate,
                  onDateSelected: (picked) {
                    if (picked != null) {
                      setState(() {
                        _startDate = picked;
                        _selectedQuickRange = null;
                      });
                    }
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildDatePickerChip(
                  label: 'End',
                  date: _endDate,
                  onDateSelected: (picked) {
                    if (picked != null) {
                      setState(() {
                        _endDate = picked;
                        _selectedQuickRange = null;
                      });
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              _buildQuickRangeButton('3m', '3m'),
              _buildQuickRangeButton('6m', '6m'),
              _buildQuickRangeButton('12m', '12m'),
            ],
          ),
        ],
        for (int i = 0; i < filterChips.length; i += 2)
          Padding(
            padding: const EdgeInsets.only(top: 12.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: filterChips[i]),
                const SizedBox(width: 10),
                if (i + 1 < filterChips.length)
                  Expanded(child: filterChips[i + 1])
                else
                  Expanded(child: Container()), // Keep alignment
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildDatePickerChip({
    required String label,
    required DateTime? date,
    required ValueChanged<DateTime?> onDateSelected,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 12.0, bottom: 4.0),
          child: Text(
            label,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
          ),
        ),
        InkWell(
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: date ?? DateTime.now(),
              firstDate: DateTime(2020),
              lastDate: DateTime.now(),
            );
            onDateSelected(picked);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.95),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.calendar_today_outlined,
                    size: 18, color: Color(0xFF555555)),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    date == null
                        ? "Select"
                        : DateFormat("MMM d, yyyy").format(date),
                    style: const TextStyle(
                      color: Color(0xFF333333),
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChip({
    required String label,
    required IconData icon,
    required List<String> items,
    required List<String> selectedItems,
    required ValueChanged<List<String>> onChanged,
  }) {
    final ValueNotifier<List<String>> internalSelection =
        ValueNotifier(List.from(selectedItems));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 12.0, bottom: 4.0),
          child: Text(
            label,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
          ),
        ),
        DropdownButtonHideUnderline(
          child: DropdownButton2<String>(
            isExpanded: true,
            customButton: ValueListenableBuilder<List<String>>(
              valueListenable: internalSelection,
              builder: (context, currentSelection, _) {
                String valueText;
                if (currentSelection.isEmpty) {
                  valueText = 'None';
                } else if (currentSelection.length == items.length) {
                  valueText = 'All';
                } else if (currentSelection.length == 1) {
                  valueText = currentSelection.first.replaceAll(' grade', '');
                } else {
                  valueText = currentSelection
                      .map((s) => s.replaceAll(' grade', ''))
                      .join(', ');
                }

                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.95),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Icon(icon, size: 20, color: const Color(0xFF555555)),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          valueText,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF333333),
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            onMenuStateChange: (isOpen) {
              if (isOpen) {
                internalSelection.value = List.from(selectedItems);
              } else {
                onChanged(internalSelection.value);
              }
            },
            items: [
              DropdownMenuItem<String>(
                value: '__select_all__',
                enabled: false,
                child: ValueListenableBuilder<List<String>>(
                  valueListenable: internalSelection,
                  builder: (context, currentSelection, _) {
                    final allSelected = currentSelection.length == items.length;
                    return InkWell(
                      onTap: () {
                        if (allSelected) {
                          internalSelection.value = [];
                        } else {
                          internalSelection.value = List.from(items);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Row(
                          children: [
                            Checkbox(
                              value: allSelected,
                               onChanged: (val) {
                                 if (val == true) {
                                   internalSelection.value = List.from(items);
                                 } else {
                                   internalSelection.value = [];
                                 }
                               },
                            ),
                            const Text('Select All', style: TextStyle(color: Colors.black)),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              ...items.map((item) {
                return DropdownMenuItem<String>(
                  value: item,
                  enabled: false,
                  child: ValueListenableBuilder<List<String>>(
                    valueListenable: internalSelection,
                    builder: (context, currentSelection, _) {
                      final isSelected = currentSelection.contains(item);
                      return InkWell(
                        onTap: () {
                          List<String> newSelection = List.from(currentSelection);
                          if (isSelected) {
                            newSelection.remove(item);
                          } else {
                            newSelection.add(item);
                          }
                          internalSelection.value = newSelection;
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: Row(
                            children: [
                              Checkbox(
                                value: isSelected,
                                onChanged: (val) {
                                  List<String> newSelection = List.from(currentSelection);
                                  if (val == true) {
                                    newSelection.add(item);
                                  } else {
                                    newSelection.remove(item);
                                  }
                                   internalSelection.value = newSelection;
                                },
                              ),
                              Text(item, style: const TextStyle(color: Colors.black)),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                );
              }),
            ],
            value: null,
            onChanged: (value) {},
            dropdownStyleData: DropdownStyleData(
              maxHeight: 240,
               width: 250,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: Colors.white,
              ),
              offset: const Offset(0, 0),
              elevation: 8,
            ),
            menuItemStyleData: const MenuItemStyleData(
              height: 40,
              padding: EdgeInsets.zero,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickRangeButton(String value, String label) {
    final isSelected = _selectedQuickRange == value;
    return GestureDetector(
      onTap: () {
        final now = DateTime.now();
        DateTime start;
        if (value == '3m') {
          start = DateTime(now.year, now.month - 3, now.day);
        } else if (value == '6m') {
          start = DateTime(now.year, now.month - 6, now.day);
        } else {
          start = DateTime(now.year - 1, now.month, now.day);
        }
        setState(() {
          _startDate = start;
          _endDate = now;
          _selectedQuickRange = value;
        });
      },
      child: Container(
        width: 44,
        padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: isSelected ? Colors.deepPurple : Colors.white.withOpacity(0.95),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? Colors.deepPurple : Colors.transparent,
            width: 2,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          value, // '3m', '6m', '12m'
          style: TextStyle(
            color: isSelected ? Colors.white : const Color(0xFF333333),
            fontWeight: FontWeight.w600,
            fontSize: 12,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Padding(
      padding: const EdgeInsets.only(top: 0.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TextButton(
            style: TextButton.styleFrom(
              backgroundColor: Colors.white.withOpacity(0.1),
              foregroundColor: Colors.white,
              padding:
                  const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              shape: const StadiumBorder(),
            ),
            onPressed: _resetFilters,
            child: const Text('Reset', style: TextStyle(fontSize: 14)),
          ),
          const SizedBox(width: 16),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.deepPurple,
              shape: const StadiumBorder(),
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
            ),
            onPressed: _isGeneratingReport ? null : _generateReport,
            child: _isGeneratingReport
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Submit', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          ),
        ],
      ),
    );
  }

  void _resetFilters() {
    setState(() {
      final now = DateTime.now();
      _endDate = now;
      _startDate = DateTime(now.year, now.month - 3, now.day);
      _selectedQuickRange = null;
      _selectedGrades = List.from(_availableGrades);
      _selectedGenders = List.from(_availableGenders);
      _selectedActivityTypes = List.from(_availableActivityTypes);
      _selectedCity = List.from(_availableCities);
      _selectedUnit = List.from(_availableSchools);
      _reportData = null;
    });
  }

  Future<void> _generateReport() async {
    if (_selectedReportType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a report type.')),
      );
      return;
    }

    setState(() {
      _isGeneratingReport = true;
      _reportData = null;
    });

    switch (_selectedReportType) {
      case 'Active Students':
        context.push('/highSchoolUnitCoordinatorStatsActiveStudents', extra: {
          'selectedMentors': _selectedMentors,
          'selectedCity': _selectedCity,
          'selectedUnit': _selectedUnit,
          'selectedGrades': _selectedGrades,
          'selectedGenders': _selectedGenders,
        });
        break;
      case 'Activities':
        context.push('/highSchoolUnitCoordinatorStatsActivities', extra: {
          'selectedMentors': _selectedMentors,
          'selectedCity': _selectedCity,
          'selectedUnit': _selectedUnit,
          'selectedGrades': _selectedGrades,
          'selectedGenders': _selectedGenders,
          'selectedActivityTypes': _selectedActivityTypes,
          'startDate': _startDate,
          'endDate': _endDate,
        });
        break;
      case 'Activity Counts':
        context.push('/highSchoolUnitCoordinatorStatsActivityCounts', extra: {
          'selectedMentors': _selectedMentors,
          'selectedCity': _selectedCity,
          'selectedUnit': _selectedUnit,
          'selectedGrades': _selectedGrades,
          'selectedGenders': _selectedGenders,
          'selectedActivityTypes': _selectedActivityTypes,
          'startDate': _startDate,
          'endDate': _endDate,
        });
        break;
      case 'Activity Counts By Mentor':
        context.push('/highSchoolUnitCoordinatorStatsActivityCountsByMentor', extra: {
          'selectedMentors': _selectedMentors,
          'selectedCity': _selectedCity,
          'selectedUnit': _selectedUnit,
          'selectedGrades': _selectedGrades,
          'selectedGenders': _selectedGenders,
          'selectedActivityTypes': _selectedActivityTypes,
          'startDate': _startDate,
          'endDate': _endDate,
        });
        break;
      // Add cases for other report types here
      default:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'The report type "$_selectedReportType" is not yet available.')),
        );
        break;
    }

    if (mounted) {
       setState(() {
        _isGeneratingReport = false;
      });
    }
  }

  Widget _buildReportContent() {
    // This widget is no longer needed as reports open on a new page.
    return const SizedBox.shrink();
  }
} 