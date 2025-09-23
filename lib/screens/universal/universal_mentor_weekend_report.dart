import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/services.dart';

class UniversalMentorWeekendReport extends StatefulWidget {
  const UniversalMentorWeekendReport({super.key});

  @override
  State<UniversalMentorWeekendReport> createState() =>
      _UniversalMentorWeekendReportState();
}

class _UniversalMentorWeekendReportState
    extends State<UniversalMentorWeekendReport> {
  final _formKey = GlobalKey<FormState>();
  final _noActivityFormKey = GlobalKey<FormState>();
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _daysController =
      TextEditingController(text: '1');
  bool _loading = false;

  // No program option
  bool _noProgramThisWeek = false;
  DateTime? _noProgramDay;
  final TextEditingController _noProgramReasonController =
      TextEditingController();

  // Activity dropdown
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

  // Date and duration
  DateTime? _selectedDate;

  // Mentees data
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

  @override
  void dispose() {
    _notesController.dispose();
    _daysController.dispose();
    _noProgramReasonController.dispose();
    super.dispose();
  }

  Future<void> _fetchMentees() async {
    setState(() => _menteesLoading = true);

    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final menteesSnap = await FirebaseFirestore.instance
          .collection('users')
          .where('mentorId', isEqualTo: uid)
          .where('isActive', isEqualTo: true)
          .get();

      final mentees = menteesSnap.docs.map((doc) {
        final data = doc.data();
        final firstName = data['firstName'] ?? '';
        final lastName = data['lastName'] ?? '';
        return {
          'uid': doc.id,
          'name': '$firstName $lastName'.trim(),
        };
      }).toList();

      setState(() {
        _mentees = mentees;
        _joined = {for (var m in mentees) m['uid'] as String: true};
        _joinDates = {for (var m in mentees) m['uid'] as String: null};
        _days = {for (var m in mentees) m['uid'] as String: ''};
        _menteesLoading = false;
      });
    } catch (e) {
      setState(() => _menteesLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading mentees: $e')),
        );
      }
    }
  }

  bool _isDirty() {
    if (_noProgramThisWeek) {
      return _noProgramDay != null ||
          _noProgramReasonController.text.trim().isNotEmpty;
    } else {
      if (_selectedActivity != null) return true;
      if (_selectedDate != null) return true;
      if (_daysController.text.trim() != '1') return true;
      if (_notesController.text.trim().isNotEmpty) return true;

      for (var mentee in _mentees) {
        final uid = mentee['uid'];
        if (_joined[uid] == false) return true;
        if (_joinDates[uid] != null) return true;
        if ((_days[uid] ?? '').isNotEmpty && _days[uid] != '1') return true;
      }
    }
    return false;
  }

  Future<bool> _onWillPop() async {
    if (!_isDirty()) return true;

    final shouldPop = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('Discard Changes?'),
        content: const Text('Are you sure you want to discard your changes?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Discard', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    return shouldPop ?? false;
  }

  Future<void> _saveReport() async {
    if (_noProgramThisWeek) {
      if (!(_noActivityFormKey.currentState?.validate() ?? false)) return;
    } else {
      if (!(_formKey.currentState?.validate() ?? false)) return;

      // Check if at least one mentee is selected
      final hasSelectedMentee =
          _mentees.any((mentee) => _joined[mentee['uid']] == true);
      if (!hasSelectedMentee) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select at least one mentee'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    setState(() => _loading = true);

    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final baseWeekKey = DateFormat('yyyy-MM-dd')
          .format(_noProgramThisWeek ? _noProgramDay! : _selectedDate!);

      // Check for existing reports with same base key
      final reportsRef = FirebaseFirestore.instance
          .collection('weekendReports')
          .doc(uid)
          .collection('reports');

      final existing = await reportsRef
          .where(FieldPath.documentId, isGreaterThanOrEqualTo: baseWeekKey)
          .where(FieldPath.documentId, isLessThan: '$baseWeekKey\uf8ff')
          .get();

      // Generate unique week key
      String weekKey = baseWeekKey;
      if (existing.docs.any((doc) => doc.id == baseWeekKey)) {
        int i = 2;
        while (existing.docs.any((doc) => doc.id == '$baseWeekKey-$i')) {
          i++;
        }
        weekKey = '$baseWeekKey-$i';
      }

      Map<String, dynamic> reportData;

      if (_noProgramThisWeek) {
        reportData = {
          'noActivityThisWeek': true,
          'noActivityDay': DateFormat('yyyy-MM-dd').format(_noProgramDay!),
          'noActivityReason': _noProgramReasonController.text.trim(),
          'timestamp': FieldValue.serverTimestamp(),
        };
      } else {
        final menteesData = <String, dynamic>{};
        for (final m in _mentees) {
          final mUid = m['uid'];
          menteesData[mUid] = {
            'joined': _joined[mUid] ?? false,
            'joinDate': _joinDates[mUid] != null
                ? DateFormat('yyyy-MM-dd').format(_joinDates[mUid]!)
                : null,
            'days': int.tryParse(_days[mUid] ?? '') ?? 0,
          };
        }

        reportData = {
          'noActivityThisWeek': false,
          'activity': _selectedActivity,
          'startDate': DateFormat('yyyy-MM-dd').format(_selectedDate!),
          'days': int.tryParse(_daysController.text.trim()) ?? 1,
          'timestamp': FieldValue.serverTimestamp(),
          'notes': _notesController.text.trim(),
          'mentees': menteesData,
        };
      }

      await reportsRef.doc(weekKey).set(reportData);

      setState(() => _loading = false);

      if (mounted) {
        HapticFeedback.lightImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Report successfully saved!'),
            backgroundColor: Colors.green,
          ),
        );

        // Reset form
        _resetForm();
      }
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving report: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _resetForm() {
    _formKey.currentState?.reset();
    _noActivityFormKey.currentState?.reset();
    _selectedActivity = null;
    _selectedDate = null;
    _daysController.text = '1';
    _noProgramDay = null;
    _noProgramReasonController.clear();
    _notesController.clear();
    _noProgramThisWeek = false;
    _fetchMentees();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        final canPop = await _onWillPop();
        if (canPop && context.mounted) {
          context.pop();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black87),
            onPressed: () async {
              final canPop = await _onWillPop();
              if (canPop && context.mounted) {
                context.pop();
              }
            },
          ),
          title: const Text(
            'Weekend Activity Report',
            style: TextStyle(
              color: Colors.black87,
              fontWeight: FontWeight.w600,
            ),
          ),
          centerTitle: true,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // No Activity Checkbox
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Checkbox(
                      value: _noProgramThisWeek,
                      onChanged: (value) {
                        setState(() {
                          _noProgramThisWeek = value ?? false;
                        });
                      },
                      activeColor: Colors.blue,
                    ),
                    const Expanded(
                      child: Text(
                        'No activity was held this week',
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Main Form Container
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: _noProgramThisWeek
                    ? _buildNoActivityForm()
                    : _buildActivityForm(),
              ),
              const SizedBox(height: 100), // Space for FAB
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _loading ? null : _saveReport,
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
          icon: _loading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : const Icon(Icons.save),
          label: Text(_loading ? 'Saving...' : 'Save Report'),
        ),
      ),
    );
  }

  Widget _buildNoActivityForm() {
    return Form(
      key: _noActivityFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'No Activity Details',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),

          // Date Selection
          const Text(
            'Which day was there no activity? *',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          InkWell(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _noProgramDay ?? DateTime.now(),
                firstDate: DateTime(2020),
                lastDate: DateTime(2100),
              );
              if (picked != null) {
                setState(() => _noProgramDay = picked);
              }
            },
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today, color: Colors.grey),
                  const SizedBox(width: 12),
                  Text(
                    _noProgramDay != null
                        ? DateFormat.yMMMd().format(_noProgramDay!)
                        : 'Select date',
                    style: TextStyle(
                      color:
                          _noProgramDay != null ? Colors.black87 : Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_noProgramDay == null)
            const Padding(
              padding: EdgeInsets.only(top: 4, left: 12),
              child: Text(
                'Please select a date',
                style: TextStyle(color: Colors.red, fontSize: 12),
              ),
            ),
          const SizedBox(height: 20),

          // Reason
          const Text(
            'Reason for no activity *',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _noProgramReasonController,
            maxLines: 4,
            decoration: InputDecoration(
              hintText: 'Enter reason...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Colors.blue),
              ),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter a reason';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildActivityForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Activity Details',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),

          // Activity Selection
          const Text(
            'Select Activity *',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _selectedActivity,
            decoration: InputDecoration(
              hintText: 'Choose an activity...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Colors.blue),
              ),
            ),
            items: _activityOptions.map((activity) {
              return DropdownMenuItem(
                value: activity,
                child: Text(activity),
              );
            }).toList(),
            onChanged: (value) {
              setState(() => _selectedActivity = value);
            },
            validator: (value) {
              if (value == null) return 'Please select an activity';
              return null;
            },
          ),
          const SizedBox(height: 20),

          // Start Date
          const Text(
            'Start Date *',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          InkWell(
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
                  // Auto-update mentee dates
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
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today, color: Colors.grey),
                  const SizedBox(width: 12),
                  Text(
                    _selectedDate != null
                        ? DateFormat.yMMMd().format(_selectedDate!)
                        : 'Select start date',
                    style: TextStyle(
                      color:
                          _selectedDate != null ? Colors.black87 : Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_selectedDate == null)
            const Padding(
              padding: EdgeInsets.only(top: 4, left: 12),
              child: Text(
                'Please select a date',
                style: TextStyle(color: Colors.red, fontSize: 12),
              ),
            ),
          const SizedBox(height: 20),

          // Duration
          const Text(
            'How Many Days *',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _daysController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              hintText: 'Number of days',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Colors.blue),
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) return 'Required';
              final n = int.tryParse(value);
              if (n == null || n < 1) return 'Enter a valid number';
              return null;
            },
            onChanged: (value) {
              final n = int.tryParse(value);
              if (n != null && n > 0) {
                setState(() {
                  for (final mentee in _mentees) {
                    final uid = mentee['uid'];
                    if (_joined[uid] == true) {
                      _days[uid] = value;
                    }
                  }
                });
              }
            },
          ),
          const SizedBox(height: 24),

          // Mentees Section
          const Text(
            'Mentees *',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),

          if (_menteesLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_mentees.isEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: const Text(
                'No mentees found',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            )
          else
            ..._mentees.map((mentee) => _buildMenteeCard(mentee)),

          const SizedBox(height: 24),

          // Notes
          const Text(
            'Notes *',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _notesController,
            maxLines: 4,
            decoration: InputDecoration(
              hintText: 'Enter your notes...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Colors.blue),
              ),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter your notes';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMenteeCard(Map<String, dynamic> mentee) {
    final uid = mentee['uid'];
    final name = mentee['name'];
    final isJoined = _joined[uid] ?? false;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Checkbox(
                value: isJoined,
                onChanged: (value) {
                  setState(() {
                    final isNowJoined = value ?? false;
                    _joined[uid] = isNowJoined;

                    if (!isNowJoined) {
                      _joinDates[uid] = null;
                      _days[uid] = '';
                    }
                  });
                },
                activeColor: Colors.blue,
              ),
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
          if (isJoined) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Join Date',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 4),
                      InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _joinDates[uid] ?? DateTime.now(),
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2100),
                          );
                          if (picked != null) {
                            setState(() => _joinDates[uid] = picked);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            _joinDates[uid] != null
                                ? DateFormat('MMM d').format(_joinDates[uid]!)
                                : 'Select date',
                            style: TextStyle(
                              color: _joinDates[uid] != null
                                  ? Colors.black87
                                  : Colors.grey,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                SizedBox(
                  width: 80,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Days',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 4),
                      TextFormField(
                        enabled: isJoined,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        decoration: InputDecoration(
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 8),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(6),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(6),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                        ),
                        onChanged: (value) {
                          setState(() => _days[uid] = value);
                        },
                        controller: TextEditingController(text: _days[uid]),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
