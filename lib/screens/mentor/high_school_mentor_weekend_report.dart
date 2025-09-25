import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'dart:ui' as ui;
import 'package:glassmorphism/glassmorphism.dart';
import 'package:dropdown_button2/dropdown_button2.dart';

class HighSchoolMentorWeekendReport extends StatefulWidget {
  const HighSchoolMentorWeekendReport({super.key});

  @override
  State<HighSchoolMentorWeekendReport> createState() => _HighSchoolMentorWeekendReportState();
}

class _HighSchoolMentorWeekendReportState extends State<HighSchoolMentorWeekendReport> {
  final _formKey = GlobalKey<FormState>();
  final _noActivityFormKey = GlobalKey<FormState>();
  final TextEditingController _observationController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _daysController = TextEditingController(text: '1');
  bool _loading = false;

  // Program yapılmadı opsiyonu için
  bool _noProgramThisWeek = false;
  DateTime? _noProgramDay;
  final TextEditingController _noProgramReasonController = TextEditingController();

  // Dropdown için eklenenler
  String? _selectedActivity;
  final List<String> _activityOptions = [
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
  ];

  // Start Date ve How Many Days için eklenenler
  DateTime? _selectedDate;
  // _daysController zaten yukarıda tanımlı

  // Mentees için eklenenler
  List<Map<String, dynamic>> _mentees = [];
  Map<String, bool> _joined = {};
  Map<String, DateTime?> _joinDates = {};
  Map<String, String> _days = {};
  bool _menteesLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchMentees();
  }

  Future<void> _fetchMentees() async {
    setState(() => _menteesLoading = true);
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final menteesSnap = await FirebaseFirestore.instance
        .collection('users')
        .where('mentorId', isEqualTo: uid)
        .where('isActive', isEqualTo: true)
        .get();
    final mentees = menteesSnap.docs.map((doc) {
      final d = doc.data();
      return {
        'uid': doc.id,
        'name': ((d['firstName'] ?? '') + ' ' + (d['lastName'] ?? '')).trim(),
      };
    }).toList();
    setState(() {
      _mentees = mentees;
      _joined = {for (var m in mentees) m['uid']: true};
      _joinDates = {for (var m in mentees) m['uid']: null};
      _days = {for (var m in mentees) m['uid']: ''};
      _menteesLoading = false;
    });
  }

  bool _isDirty() {
    if (_noProgramThisWeek) {
      if (_noProgramDay != null) return true;
      if (_noProgramReasonController.text.trim().isNotEmpty) return true;
    } else {
      if (_selectedActivity != null) return true;
      if (_selectedDate != null) return true;
      if (_daysController.text.trim() != '1') return true;
      if (_notesController.text.trim().isNotEmpty) return true;
      
      for (var mentee in _mentees) {
        final uid = mentee['uid'];
        if (_joined[uid] == false) return true; // Default is all joined (true)
        if (_joinDates[uid] != null) return true; // Default is null
        if ((_days[uid] ?? '').isNotEmpty && _days[uid] != '1') return true; // Default is '', or '1' after date pick
      }
    }
    return false;
  }

  Future<bool> _onWillPop() async {
    if (!_isDirty()) {
      return true; // No changes, allow pop
    }

    final shouldPop = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard Changes?'),
        content: const Text('Are you sure you want to discard your changes?'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false), // Stay on page
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true), // Leave page
            child: const Text('Yes'),
          ),
        ],
      ),
    );

    return shouldPop ?? false;
  }

  Future<void> _saveReport() async {
    if (_noProgramThisWeek) {
      if (!(_noActivityFormKey.currentState?.validate() ?? false)) return;
      setState(() => _loading = true);
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final baseWeekKey = DateFormat('yyyy-MM-dd').format(_noProgramDay!);
      // Query for existing docs with this baseWeekKey
      final reportsRef = FirebaseFirestore.instance
          .collection('weekendReports')
          .doc(uid)
          .collection('reports');
      final existing = await reportsRef
          .where(FieldPath.documentId, isGreaterThanOrEqualTo: baseWeekKey)
          .where(FieldPath.documentId, isLessThan: '$baseWeekKey\uf8ff')
          .get();
      String weekKey = baseWeekKey;
      if (existing.docs.any((doc) => doc.id == baseWeekKey)) {
        // Find the next available index
        int i = 2;
        while (existing.docs.any((doc) => doc.id == '$baseWeekKey-$i')) {
          i++;
        }
        weekKey = '$baseWeekKey-$i';
      }
      final reportData = {
        'noActivityThisWeek': true,
        'noActivityDay': DateFormat('yyyy-MM-dd').format(_noProgramDay!),
        'noActivityReason': _noProgramReasonController.text.trim(),
        'timestamp': FieldValue.serverTimestamp(),
      };
      await reportsRef.doc(weekKey).set(reportData);
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Report successfully saved!')));
      _formKey.currentState?.reset();
      _selectedActivity = null;
      _selectedDate = null;
      _daysController.text = '1';
      _noActivityFormKey.currentState?.reset();
      _noProgramDay = null;
      _noProgramReasonController.clear();
      _notesController.clear();
      await _fetchMentees();
      return;
    }
    if (!(_formKey.currentState?.validate() ?? false)) return;
    // Check if at least one mentee is selected
    final hasSelectedMentee = _mentees.any((mentee) => _joined[mentee['uid']] == true);
    if (!hasSelectedMentee) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one mentee'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    setState(() => _loading = true);
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final baseWeekKey = DateFormat('yyyy-MM-dd').format(_selectedDate!);
    final reportsRef = FirebaseFirestore.instance
        .collection('weekendReports')
        .doc(uid)
        .collection('reports');
    final existing = await reportsRef
        .where(FieldPath.documentId, isGreaterThanOrEqualTo: baseWeekKey)
        .where(FieldPath.documentId, isLessThan: '$baseWeekKey\uf8ff')
        .get();
    String weekKey = baseWeekKey;
    if (existing.docs.any((doc) => doc.id == baseWeekKey)) {
      int i = 2;
      while (existing.docs.any((doc) => doc.id == '$baseWeekKey-$i')) {
        i++;
      }
      weekKey = '$baseWeekKey-$i';
    }
    final menteesData = <String, dynamic>{};
    for (final m in _mentees) {
      final mUid = m['uid'];
      menteesData[mUid] = {
        'joined': _joined[mUid] ?? false,
        'joinDate': _joinDates[mUid] != null ? DateFormat('yyyy-MM-dd').format(_joinDates[mUid]!) : null,
        'days': int.tryParse(_days[mUid] ?? '') ?? 0,
      };
    }
    final reportData = {
      'noActivityThisWeek': false,
      'activity': _selectedActivity,
      'startDate': DateFormat('yyyy-MM-dd').format(_selectedDate!),
      'days': int.tryParse(_daysController.text.trim()) ?? 1,
      'timestamp': FieldValue.serverTimestamp(),
      'notes': _notesController.text.trim(),
      'mentees': menteesData,
    };
    await reportsRef.doc(weekKey).set(reportData);
    setState(() => _loading = false);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Report successfully saved!')));
    _formKey.currentState?.reset();
    _selectedActivity = null;
    _selectedDate = null;
    _daysController.text = '1';
    _observationController.clear();
    _notesController.clear();
    await _fetchMentees();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        extendBodyBehindAppBar: true,
        resizeToAvoidBottomInset: false,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () async {
              final canPop = await _onWillPop();
              if (canPop) {
                context.pop();
              }
            },
          ),
        title: const Text('High School Weekend Activity Report'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Settings',
            onPressed: () {
              context.push('/settings');
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          // Pastel gradient background
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF8EC5FC), Color(0xFFE0C3FC)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          // Main glassmorphic content
          SafeArea(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 100), // Bottom padding for FAB
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Başlık
                    const SizedBox(height: 8),
                    // Checkbox'ı ayrı bir kutuda ve ortalanmış göster
                    Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white.withOpacity(0.32), width: 1.2),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Checkbox(
                              value: _noProgramThisWeek,
                              onChanged: (v) {
                                setState(() {
                                  _noProgramThisWeek = v ?? false;
                                });
                              },
                            ),
                            const SizedBox(width: 8),
                            const Text('No activity was held this week', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    // Formun geri kalanı
                    ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: BackdropFilter(
                        filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                        child: Container(
                          padding: const EdgeInsets.all(24.0),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.white.withOpacity(0.55),
                                Colors.white.withOpacity(0.28),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.32),
                              width: 1.5,
                            ),
                          ),
                          child: (_noProgramThisWeek)
                              ? Form(
                                  key: _noActivityFormKey,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      const SizedBox(height: 16),
                                      Row(
                                        children: [
                                          const Text('Which day was there no activity?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                          const SizedBox(width: 4),
                                          const Text('*', style: TextStyle(color: Colors.red, fontSize: 16)),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      GestureDetector(
                                        onTap: () async {
                                          final picked = await showDatePicker(
                                            context: context,
                                            initialDate: _noProgramDay ?? DateTime.now(),
                                            firstDate: DateTime(2020),
                                            lastDate: DateTime(2100),
                                          );
                                          if (picked != null) setState(() => _noProgramDay = picked);
                                        },
                                        child: AbsorbPointer(
                                          child: TextFormField(
                                            style: const TextStyle(color: Colors.black),
                                            decoration: InputDecoration(
                                              filled: true,
                                              fillColor: Colors.white.withOpacity(0.4),
                                              border: OutlineInputBorder(
                                                borderRadius: BorderRadius.circular(15),
                                                borderSide: BorderSide.none,
                                              ),
                                              hintText: 'Select date',
                                              hintStyle: TextStyle(color: Colors.black.withOpacity(0.7)),
                                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                            ),
                                            controller: TextEditingController(
                                              text: _noProgramDay != null ? DateFormat.yMMMd().format(_noProgramDay!) : '',
                                            ),
                                            validator: (v) => (_noProgramDay == null) ? 'Please select a date' : null,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 24),
                                      Row(
                                        children: [
                                          const Text('Reason for no activity?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                          const SizedBox(width: 4),
                                          const Text('*', style: TextStyle(color: Colors.red, fontSize: 16)),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      TextFormField(
                                        controller: _noProgramReasonController,
                                        maxLines: 4,
                                        style: const TextStyle(color: Colors.black),
                                        decoration: InputDecoration(
                                          filled: true,
                                          fillColor: Colors.white.withOpacity(0.4),
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(15),
                                            borderSide: BorderSide.none,
                                          ),
                                          hintText: 'Enter reason...',
                                          hintStyle: TextStyle(color: Colors.black.withOpacity(0.7)),
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                        ),
                                        validator: (v) {
                                          if (v == null || v.trim().isEmpty) return 'Please enter a reason';
                                          return null;
                                        },
                                      ),
                                    ],
                                  ),
                                )
                              : Form(
                                  key: _formKey,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                Row(
                                  children: const [
                                    Text('Create New Activity', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                    SizedBox(width: 4),
                                    Text('*', style: TextStyle(color: Colors.red, fontSize: 16)),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                FormField<String>(
                                  initialValue: _selectedActivity,
                                  validator: (value) {
                                    if (value == null) {
                                      return 'Please select an activity';
                                    }
                                    return null;
                                  },
                                  builder: (formFieldState) {
                                    return Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
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
                                              customButton: GlassmorphicContainer(
                                                width: double.infinity,
                                                height: 58,
                                                borderRadius: 12,
                                                blur: 4,
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
                                                    Colors.white.withOpacity(0.4),
                                                    Colors.white.withOpacity(0.4),
                                                  ],
                                                ),
                                                child: Padding(
                                                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                                                  child: Row(
                                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                    children: [
                                                      Expanded(
                                                        child: Text(
                                                          _selectedActivity ?? 'Select...',
                                                          style: TextStyle(fontSize: 16, color: Color.fromRGBO(0, 0, 0, 0.7)),
                                                          overflow: TextOverflow.ellipsis,
                                                          maxLines: 1,
                                                        ),
                                                      ),
                                                      const Icon(Icons.arrow_drop_down, color: Colors.white, size: 32),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                              items: _activityOptions.map((String value) {
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
                                              value: _selectedActivity,
                                              onChanged: (newValue) {
                                                setState(() {
                                                  _selectedActivity = newValue;
                                                });
                                                formFieldState.didChange(newValue);
                                              },
                                              buttonStyleData: const ButtonStyleData(
                                                height: 58,
                                                decoration: BoxDecoration(
                                                  color: Colors.transparent,
                                                ),
                                              ),
                                              iconStyleData: const IconStyleData(
                                                icon: SizedBox.shrink(), // Hide the default icon
                                                openMenuIcon: SizedBox.shrink(),
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
                                        if (formFieldState.hasError)
                                          Padding(
                                            padding: const EdgeInsets.only(left: 12.0, top: 4.0),
                                            child: Text(
                                              formFieldState.errorText!,
                                              style: TextStyle(
                                                color: Colors.redAccent.shade100,
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                      ],
                                    );
                                  },
                                ),
                                const SizedBox(height: 24),
                                Row(
                                  children: const [
                                    Text('Start Date', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                    SizedBox(width: 4),
                                    Text('*', style: TextStyle(color: Colors.red, fontSize: 16)),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                GestureDetector(
                                  onTap: () async {
                                    final picked = await showDatePicker(
                                      context: context,
                                      initialDate: _selectedDate ?? DateTime.now(),
                                      firstDate: DateTime(2020),
                                      lastDate: DateTime(2100),
                                    );
                                    if (picked != null) {
                                      setState(() {
                                        _selectedDate = picked;
                                        // Automatically update all checked mentees
                                        for (final mentee in _mentees) {
                                          final uid = mentee['uid'];
                                          if (_joined[uid] == true) {
                                            _joinDates[uid] = picked;
                                            _days[uid] = '1';
                                          }
                                        }
                                      });
                                    }
                                  },
                                  child: AbsorbPointer(
                                    child: TextFormField(
                                      style: const TextStyle(color: Colors.black),
                                      decoration: InputDecoration(
                                        filled: true,
                                        fillColor: Colors.white.withOpacity(0.4),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(15),
                                          borderSide: BorderSide.none,
                                        ),
                                        hintText: 'Select date',
                                        hintStyle: TextStyle(color: Colors.black.withOpacity(0.7)),
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                      ),
                                      controller: TextEditingController(
                                        text: _selectedDate != null ? DateFormat.yMMMd().format(_selectedDate!) : '',
                                      ),
                                      validator: (v) => (_selectedDate == null) ? 'Please select a date' : null,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 24),
                                Row(
                                  children: const [
                                    Text('How Many Days', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                    SizedBox(width: 4),
                                    Text('*', style: TextStyle(color: Colors.red, fontSize: 16)),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                TextFormField(
                                  controller: _daysController,
                                  keyboardType: TextInputType.number,
                                  style: const TextStyle(color: Colors.black),
                                  decoration: InputDecoration(
                                    filled: true,
                                    fillColor: Colors.white.withOpacity(0.4),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(15),
                                      borderSide: BorderSide.none,
                                    ),
                                    hintStyle: TextStyle(color: Colors.black.withOpacity(0.7)),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                  ),
                                  validator: (v) {
                                    if (v == null || v.isEmpty) return 'Required';
                                    final n = int.tryParse(v);
                                    if (n == null || n < 1) return 'Enter a valid number';
                                    return null;
                                  },
                                  onChanged: (v) {
                                    final n = int.tryParse(v);
                                    if (n != null && n > 0) {
                                      setState(() {
                                        for (final mentee in _mentees) {
                                          final uid = mentee['uid'];
                                          if (_joined[uid] == true) {
                                            _days[uid] = v;
                                          }
                                        }
                                      });
                                    }
                                  },
                                ),
                                const SizedBox(height: 32),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Row(
                                          children: [
                                            Text('Mentee', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                            SizedBox(width: 4),
                                            Text('*', style: TextStyle(color: Colors.red, fontSize: 16)),
                                          ],
                                        ),
                                      ),
                                      SizedBox(
                                        width: 80,
                                        child: const Text('Join Date', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14), textAlign: TextAlign.center),
                                      ),
                                      SizedBox(width: 8),
                                      SizedBox(
                                        width: 50,
                                        child: const Padding(
                                          padding: EdgeInsets.only(left: 12.0),
                                          child: Text('Days', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                        ),
                                      ),
                                      SizedBox(width: 4),
                                    ],
                                  ),
                                ),
                                const Divider(color: Colors.black26),
                                if (_menteesLoading)
                                  const Center(child: CircularProgressIndicator(color: Colors.blue))
                                else if (_mentees.isNotEmpty)
                                  Column(
                                    children: _mentees.map((mentee) {
                                      final uid = mentee['uid'];
                                      final bool isJoined = _joined[uid] ?? false;
                                      return Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                                        child: GlassmorphicContainer(
                                          width: double.infinity,
                                          height: 60,
                                          borderRadius: 16,
                                          blur: 8,
                                          border: 1,
                                          linearGradient: LinearGradient(
                                            colors: [
                                              Colors.white.withOpacity(0.4),
                                              Colors.white.withOpacity(0.3),
                                            ],
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                          ),
                                          borderGradient: LinearGradient(
                                            colors: [
                                              Colors.white.withOpacity(0.5),
                                              Colors.white.withOpacity(0.5),
                                            ],
                                          ),
                                          child: Align(
                                            alignment: const Alignment(0.0, 0.2),
                                            child: Row(
                                              crossAxisAlignment: CrossAxisAlignment.center,
                                              children: [
                                                Expanded(
                                                  child: Row(
                                                    children: [
                                                      Checkbox(
                                                        value: isJoined,
                                                        onChanged: (v) => setState(() {
                                                          final isNowJoined = v ?? false;
                                                          _joined[uid] = isNowJoined;

                                                          if (!isNowJoined) {
                                                            // Un-ticked, clear data
                                                            _joinDates[uid] = null;
                                                            _days[uid] = '';
                                                          }
                                                          // When re-ticked, do nothing automatically.
                                                          // User has to manually set the date again.
                                                        }),
                                                        activeColor: Colors.green,
                                                        checkColor: Colors.white,
                                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                                        visualDensity: VisualDensity.compact,
                                                      ),
                                                      Expanded(
                                                        child: Text(
                                                          mentee['name'],
                                                          style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                                                          overflow: TextOverflow.ellipsis,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                SizedBox(width: 8),
                                                SizedBox(
                                                  width: 80,
                                                  child: GestureDetector(
                                                    onTap: () async {
                                                      if (!isJoined) {
                                                        setState(() {
                                                          _joined[uid] = true;
                                                        });
                                                      }
                                                      final picked = await showDatePicker(
                                                        context: context,
                                                        initialDate: _joinDates[uid] ?? DateTime.now(),
                                                        firstDate: DateTime(2020),
                                                        lastDate: DateTime(2100),
                                                      );
                                                      if (picked != null) setState(() => _joinDates[uid] = picked);
                                                    },
                                                    child: Container(
                                                      height: 36,
                                                      decoration: BoxDecoration(
                                                        color: Colors.white.withOpacity(0.4),
                                                        borderRadius: BorderRadius.circular(12),
                                                      ),
                                                      alignment: Alignment.center,
                                                      child: Text(
                                                        _joinDates[uid] != null
                                                            ? DateFormat('MMM d').format(_joinDates[uid]!)
                                                            : 'Date',
                                                        style: TextStyle(
                                                          color: Colors.black.withOpacity(_joinDates[uid] != null ? 1.0 : 0.7),
                                                          fontSize: 14,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                SizedBox(width: 8),
                                                SizedBox(
                                                  width: 50,
                                                  height: 36,
                                                  child: TextFormField(
                                                    enabled: isJoined,
                                                    textAlignVertical: TextAlignVertical.center,
                                                    decoration: InputDecoration(
                                                      filled: true,
                                                      fillColor: Colors.white.withOpacity(0.4),
                                                      border: OutlineInputBorder(
                                                        borderRadius: BorderRadius.circular(12),
                                                        borderSide: BorderSide.none,
                                                      ),
                                                      contentPadding: const EdgeInsets.symmetric(horizontal: 8.0),
                                                    ),
                                                    keyboardType: TextInputType.number,
                                                    style: const TextStyle(color: Colors.black),
                                                    textAlign: TextAlign.center,
                                                    onChanged: (v) {
                                                      setState(() {
                                                        _days[uid] = v;
                                                      });
                                                    },
                                                    controller: TextEditingController(text: _days[uid]),
                                                  ),
                                                ),
                                                SizedBox(width: 4),
                                              ],
                                            ),
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                const SizedBox(height: 24),
                                Row(
                                  children: [
                                    const Text('Notes', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                    const SizedBox(width: 4),
                                    const Text('*', style: TextStyle(color: Colors.red, fontSize: 16)),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                TextFormField(
                                  controller: _notesController,
                                  maxLines: 6,
                                  style: const TextStyle(color: Colors.black),
                                  decoration: InputDecoration(
                                    filled: true,
                                    fillColor: Colors.white.withOpacity(0.4),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(15),
                                      borderSide: BorderSide.none,
                                    ),
                                    hintText: 'Enter ...',
                                    hintStyle: TextStyle(color: Colors.black.withOpacity(0.7)),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                  ),
                                  validator: (v) {
                                    if (v == null || v.trim().isEmpty) return 'Please enter your notes';
                                    return null;
                                  },
                                ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(right: 18.0, bottom: 18.0),
        child: GlassmorphicContainer(
          width: 120,
          height: 45,
          borderRadius: 22.5,
          blur: 12,
          alignment: Alignment.center,
          border: 1.5,
          linearGradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withOpacity(0.3),
              Colors.white.withOpacity(0.15),
            ],
          ),
          borderGradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withOpacity(0.6),
              Colors.white.withOpacity(0.3),
            ],
          ),
          child: ElevatedButton(
            onPressed: _loading ? null : _saveReport,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22.5),
              ),
              elevation: 0,
              padding: EdgeInsets.zero,
              textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            child: _loading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(color: Colors.blue, strokeWidth: 2),
                  )
                : const Text('Save', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color.fromARGB(255, 74, 180, 255))),
          ),
        ),
      ),
      ),
    );
  }
} 