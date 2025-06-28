import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:glassmorphism/glassmorphism.dart';
import 'package:dropdown_button2/dropdown_button2.dart';

const int charLimit = 11;

class HighSchoolUnitCoordinatorMentees extends StatefulWidget {
  const HighSchoolUnitCoordinatorMentees({super.key});

  @override
  State<HighSchoolUnitCoordinatorMentees> createState() => _HighSchoolUnitCoordinatorMenteesState();
}

class _HighSchoolUnitCoordinatorMenteesState extends State<HighSchoolUnitCoordinatorMentees> {
  List<DocumentSnapshot> _mentees = [];
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _mentors = [];
  bool _showCreate = false;
  String _sortField = 'mentorName';
  bool _sortAsc = true;

  @override
  void initState() {
    super.initState();
    _fetchMentees();
    _fetchMentors();
  }

  Future<void> _fetchMentees() async {
    setState(() { _loading = true; _error = null; });
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      setState(() { _loading = false; _error = 'Not authenticated.'; });
      return;
    }
    try {
      final menteeQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('parentId', isEqualTo: uid)
          .where('role', isEqualTo: 'mentee')
          .get();
      setState(() {
        _mentees = menteeQuery.docs;
        _loading = false;
      });
    } catch (e) {
      setState(() { _error = 'Error: $e'; _loading = false; });
    }
  }

  Future<void> _fetchMentors() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final mentorQuery = await FirebaseFirestore.instance
        .collection('users')
        .where('parentId', isEqualTo: uid)
        .where('role', isEqualTo: 'mentor')
        .get();
    setState(() {
      _mentors = mentorQuery.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'firstName': data['firstName'] ?? '',
          'lastName': data['lastName'] ?? '',
        };
      }).toList();
    });
  }

  List<DocumentSnapshot> get _sortedMentees {
    List<DocumentSnapshot> mentees = List.from(_mentees);
    mentees.sort((a, b) {
      final aData = a.data() as Map<String, dynamic>;
      final bData = b.data() as Map<String, dynamic>;
      String aValue = '';
      String bValue = '';
      switch (_sortField) {
        case 'fullName':
          aValue = ((aData['firstName'] ?? '') + ' ' + (aData['lastName'] ?? '')).trim().toLowerCase();
          bValue = ((bData['firstName'] ?? '') + ' ' + (bData['lastName'] ?? '')).trim().toLowerCase();
          break;
        case 'province':
          aValue = (aData['province'] ?? '').toLowerCase();
          bValue = (bData['province'] ?? '').toLowerCase();
          break;
        case 'city':
          aValue = (aData['city'] ?? '').toLowerCase();
          bValue = (bData['city'] ?? '').toLowerCase();
          break;
        case 'mentorName':
          aValue = (aData['mentorId'] ?? '').toLowerCase();
          bValue = (bData['mentorId'] ?? '').toLowerCase();
          break;
      }
      return _sortAsc ? aValue.compareTo(bValue) : bValue.compareTo(aValue);
    });
    return mentees;
  }

  void _showCreateMenteeDialog() {
    setState(() { _showCreate = true; });
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => MenteeCreateDialog(
        mentors: _mentors,
        onCreated: () async {
          if (!mounted) return;
          context.pop();
          setState(() { _showCreate = false; });
          await _fetchMentees();
        },
        onCancel: () {
          if (!mounted) return;
          context.pop();
          setState(() { _showCreate = false; });
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text('Mentees'),
        centerTitle: true,
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
          // Main content (app bar yüksekliği kadar padding ile başlasın)
          Positioned.fill(
            top: kToolbarHeight + MediaQuery.of(context).padding.top,
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(child: Text(_error!))
                    : _mentees.isEmpty
                        ? const Center(child: Text('No mentees found.'))
                        : Column(
                            children: [
                              // Glassmorphic header/filter row
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  children: [
                                    _HeaderBox(
                                      label: 'Full Name',
                                      selected: _sortField == 'fullName',
                                      asc: _sortAsc,
                                      width: 80,
                                      fontSize: 13,
                                      onTap: () {
                                        setState(() {
                                          if (_sortField == 'fullName') {
                                            _sortAsc = !_sortAsc;
                                          } else {
                                            _sortField = 'fullName';
                                            _sortAsc = true;
                                          }
                                        });
                                      },
                                      glass: true,
                                    ),
                                    _HeaderBox(
                                      label: 'Province',
                                      selected: _sortField == 'province',
                                      asc: _sortAsc,
                                      width: 80,
                                      fontSize: 13,
                                      onTap: () {
                                        setState(() {
                                          if (_sortField == 'province') {
                                            _sortAsc = !_sortAsc;
                                          } else {
                                            _sortField = 'province';
                                            _sortAsc = true;
                                          }
                                        });
                                      },
                                      glass: true,
                                    ),
                                    _HeaderBox(
                                      label: 'City',
                                      selected: _sortField == 'city',
                                      asc: _sortAsc,
                                      width: 80,
                                      fontSize: 13,
                                      onTap: () {
                                        setState(() {
                                          if (_sortField == 'city') {
                                            _sortAsc = !_sortAsc;
                                          } else {
                                            _sortField = 'city';
                                            _sortAsc = true;
                                          }
                                        });
                                      },
                                      glass: true,
                                    ),
                                    _HeaderBox(
                                      label: 'Mentor',
                                      selected: _sortField == 'mentorName',
                                      asc: _sortAsc,
                                      width: 80,
                                      fontSize: 13,
                                      onTap: () {
                                        setState(() {
                                          if (_sortField == 'mentorName') {
                                            _sortAsc = !_sortAsc;
                                          } else {
                                            _sortField = 'mentorName';
                                            _sortAsc = true;
                                          }
                                        });
                                      },
                                      glass: true,
                                    ),
                                  ],
                                ),
                              ),
                              // Mentee cards list
                              Expanded(
                                child: _loading
                                    ? const Center(child: CircularProgressIndicator())
                                    : _error != null
                                        ? Center(child: Text(_error!))
                                        : _mentees.isEmpty
                                            ? const Center(child: Text('No mentees found.'))
                                            : _buildGroupedMenteeList(),
                              ),
                            ],
                          ),
          ),
          // Floating action button (unchanged)
          Positioned(
            bottom: 24,
            right: 24,
            child: _CreateFAB(onPressed: _showCreateMenteeDialog),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupedMenteeList() {
    // MentorId'ye göre grupla
    final mentees = _sortedMentees;
    Map<String, List<DocumentSnapshot>> grouped = {};
    for (var doc in mentees) {
      final data = doc.data() as Map<String, dynamic>;
      final mentorId = data['mentorId'] ?? '';
      grouped.putIfAbsent(mentorId, () => []).add(doc);
    }
    // Mentor sırasını korumak için mentorId'leri sırala
    final mentorOrder = grouped.keys.toList();
    return ListView.builder(
      padding: const EdgeInsets.all(10),
      itemCount: mentorOrder.length,
      itemBuilder: (context, groupIdx) {
        final mentorId = mentorOrder[groupIdx];
        final menteeDocs = grouped[mentorId]!;
        // Mentor adını bul
        String mentorName = '-';
        final mentor = _mentors.firstWhere(
          (m) => m['id'] == mentorId,
          orElse: () => <String, dynamic>{},
        );
        if (mentor.isNotEmpty) {
          mentorName = ((mentor['firstName'] ?? '') + ' ' + (mentor['lastName'] ?? '')).trim();
          if (mentorName.isEmpty) mentorName = '-';
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ...List.generate(menteeDocs.length, (idx) {
              final doc = menteeDocs[idx];
              final data = doc.data() as Map<String, dynamic>;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: MenteeTableCard(
                  menteeId: doc.id,
                  user: data,
                  fullName: ((data['firstName'] ?? '') + ' ' + (data['lastName'] ?? '')).trim(),
                  mentors: _mentors,
                  onUpdated: _fetchMentees,
                  provincePadding: EdgeInsets.only(left: 0),
                  cityPadding: EdgeInsets.only(left: 0),
                  mentorNamePadding: EdgeInsets.only(left: 20),
                ),
              );
            }),
            // Mentor grubu bitti, divider ekle (son grupta ekleme)
            if (groupIdx != mentorOrder.length - 1)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 2,
                        offset: Offset(0, 1),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class MenteeTableCard extends StatefulWidget {
  final String menteeId;
  final Map<String, dynamic> user;
  final String fullName;
  final List<Map<String, dynamic>> mentors;
  final VoidCallback onUpdated;
  final EdgeInsets provincePadding;
  final EdgeInsets mentorNamePadding;
  final EdgeInsets cityPadding;

  const MenteeTableCard({
    required this.menteeId,
    required this.user,
    required this.fullName,
    required this.mentors,
    required this.onUpdated,
    this.provincePadding = EdgeInsets.zero,
    this.mentorNamePadding = EdgeInsets.zero,
    this.cityPadding = EdgeInsets.zero,
    super.key,
  });

  @override
  State<MenteeTableCard> createState() => _MenteeTableCardState();
}

class _MenteeTableCardState extends State<MenteeTableCard> with SingleTickerProviderStateMixin {
  bool _expanded = false;
  bool _editMode = false;
  late TextEditingController _firstNameController;
  late TextEditingController _lastNameController;
  String _gender = '';
  String _gradeLevel = '';
  String _province = '';
  String _city = '';
  String _mentorId = '';
  bool _isActive = true;

  @override
  void initState() {
    super.initState();
    final user = widget.user;
    _firstNameController = TextEditingController(text: user['firstName'] ?? '');
    _lastNameController = TextEditingController(text: user['lastName'] ?? '');
    _gender = user['gender'] ?? '';
    _gradeLevel = user['gradeLevel'] ?? '';
    _province = user['province'] ?? '';
    _city = user['city'] ?? '';
    _mentorId = user['mentorId'] ?? '';
    _isActive = user['isActive'] ?? true;
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    super.dispose();
  }

  Future<void> _saveEdits() async {
    final doc = FirebaseFirestore.instance.collection('users').doc(widget.menteeId);
    await doc.update({
      'firstName': _firstNameController.text.trim(),
      'lastName': _lastNameController.text.trim(),
      'gender': _gender,
      'gradeLevel': _gradeLevel == 'College' ? 'College' : '${_gradeLevel}th grade',
      'province': _province,
      'city': _city,
      'mentorId': _mentorId,
      'isActive': _isActive,
    });
    setState(() => _editMode = false);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Mentee updated.')));
    widget.onUpdated();
  }

  Future<void> _deleteMentee() async {
    await FirebaseFirestore.instance.collection('users').doc(widget.menteeId).delete();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Mentee deleted.')));
    // Remove from list in parent
    if (context.findAncestorStateOfType<_HighSchoolUnitCoordinatorMenteesState>() != null) {
      final parent = context.findAncestorStateOfType<_HighSchoolUnitCoordinatorMenteesState>()!;
      parent._fetchMentees();
    }
  }

  void _showDeleteDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Mentee'),
        content: const Text('Are you sure you want to delete this mentee? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => context.pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              context.pop();
              await _deleteMentee();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showEditDialog() {
    final parent = context.findAncestorStateOfType<_HighSchoolUnitCoordinatorMenteesState>();
    if (parent == null) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => MenteeEditDialog(
        menteeData: widget.user,
        menteeId: widget.menteeId,
        mentors: parent._mentors,
        onSaved: () async {
          if (!mounted) return;
          await parent._fetchMentees();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    final grades = ['8', '9', '10', '11', '12', 'College'];
    final genders = ['Male', 'Female'];
    final provinces = ['Ontario', 'Quebec', 'British Columbia'];
    final cities = ['Toronto', 'Ottawa', 'Montreal'];
    return GlassmorphicContainer(
      width: double.infinity,
      height: _expanded ? 380 : 60,
      borderRadius: 12,
      blur: 10,
      alignment: Alignment.topCenter,
      border: 1,
      linearGradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withOpacity(0.4),
          Colors.white.withOpacity(0.3),
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
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        child: Column(
          children: [
            InkWell(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              onTap: () => setState(() => _expanded = !_expanded),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: _expanded ? Colors.white.withOpacity(0.1) : Colors.transparent,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 2.0, right: 8),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: _expanded ? Colors.blue : Colors.green,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: (_expanded ? Colors.blue : Colors.green).withOpacity(0.18),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Icon(_expanded ? Icons.remove : Icons.add, color: Colors.white, size: 12),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Builder(
                        builder: (context) {
                          final text = widget.fullName.isNotEmpty ? widget.fullName : widget.menteeId;
                          final words = text.split(' ');
                          String firstLine = '';
                          String secondLine = '';
                          int currentLength = 0;
                          for (int i = 0; i < words.length; i++) {
                            final word = words[i];
                            // +1: boşluk için (ilk kelime hariç)
                            int addLength = (firstLine.isEmpty ? 0 : 1) + word.length;
                            if (currentLength + addLength <= charLimit) {
                              if (firstLine.isNotEmpty) firstLine += ' ';
                              firstLine += word;
                              currentLength += addLength;
                            } else {
                              // Kalan kelimeleri ikinci satıra ekle
                              secondLine = words.sublist(i).join(' ');
                              break;
                            }
                          }
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                firstLine,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black),
                                softWrap: true,
                                textAlign: TextAlign.left,
                              ),
                              if (secondLine.isNotEmpty)
                                Text(
                                  secondLine,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black),
                                  softWrap: true,
                                  textAlign: TextAlign.left,
                                ),
                            ],
                          );
                        },
                      ),
                    ),
                    Expanded(
                      flex: 1,
                      child: Transform.translate(
                        offset: const Offset(-24, 0),
                        child: Text(
                          user['province'] ?? '-',
                          style: const TextStyle(color: Color.fromARGB(255, 75, 75, 75), fontSize: 13),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          softWrap: true,
                          textAlign: TextAlign.left,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 1,
                      child: Transform.translate(
                        offset: const Offset(5, 0),
                        child: Container(
                          padding: widget.cityPadding,
                          child: Text(
                            user['city'] ?? '-',
                            style: const TextStyle(color: Color.fromARGB(255, 75, 75, 75), fontSize: 13),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            softWrap: true,
                            textAlign: TextAlign.left,
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Transform.translate(
                        offset: const Offset(8, 0),
                        child: Container(
                          padding: widget.mentorNamePadding,
                          child: Builder(
                            builder: (context) {
                              String mentorName = '-';
                              final mentor = widget.mentors.firstWhere(
                                (m) => m['id'] == widget.user['mentorId'],
                                orElse: () => <String, dynamic>{},
                              );
                              if (mentor.isNotEmpty) {
                                mentorName = ((mentor['firstName'] ?? '') + ' ' + (mentor['lastName'] ?? '')).trim();
                                if (mentorName.isEmpty) mentorName = '-';
                              }
                              final words = mentorName.split(' ');
                              String firstLine = '';
                              String secondLine = '';
                              int currentLength = 0;
                              for (int i = 0; i < words.length; i++) {
                                final word = words[i];
                                int addLength = (firstLine.isEmpty ? 0 : 1) + word.length;
                                if (currentLength + addLength <= charLimit) {
                                  if (firstLine.isNotEmpty) firstLine += ' ';
                                  firstLine += word;
                                  currentLength += addLength;
                                } else {
                                  secondLine = words.sublist(i).join(' ');
                                  break;
                                }
                              }
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    firstLine,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black),
                                    softWrap: true,
                                    textAlign: TextAlign.left,
                                  ),
                                  if (secondLine.isNotEmpty)
                                    Text(
                                      secondLine,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black),
                                      softWrap: true,
                                      textAlign: TextAlign.left,
                                    ),
                                ],
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              child: _expanded
                  ? Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildTableRow('First Name', _editMode
                            ? TextField(controller: _firstNameController)
                            : Text(widget.user['firstName'] ?? '-', style: const TextStyle(fontSize: 15))),
                          _buildTableRow('Last Name', _editMode
                            ? TextField(controller: _lastNameController)
                            : Text(widget.user['lastName'] ?? '-', style: const TextStyle(fontSize: 15))),
                          _buildTableRow('Gender', _editMode
                            ? DropdownButton2<String>(
                                value: _gender,
                                items: genders.map((g) => DropdownMenuItem(
                                  value: g,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: g == 'Male' ? Colors.blue[50] : Colors.pink[50],
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    child: Text(g, style: const TextStyle(color: Colors.black)),
                                  ),
                                )).toList(),
                                onChanged: (v) => setState(() => _gender = v ?? 'Male'),
                                dropdownStyleData: DropdownStyleData(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    color: Colors.white,
                                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 12, offset: Offset(0, 4))],
                                  ),
                                  elevation: 4,
                                  offset: const Offset(0, 4),
                                ),
                                selectedItemBuilder: (context) => genders.map((g) => Text(g, style: const TextStyle(color: Colors.black))).toList(),
                              )
                            : Text(widget.user['gender'] ?? '-', style: const TextStyle(fontSize: 15))),
                          _buildTableRow('School', Text(widget.user['school'] ?? '-', style: const TextStyle(fontSize: 15))),
                          _buildTableRow('Grade', _editMode
                            ? DropdownButton2<String>(
                                value: _gradeLevel,
                                items: grades.map((g) => DropdownMenuItem(
                                  value: g,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: g == 'College' ? Colors.deepPurple[50] : Colors.grey[200],
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    child: Text(g, style: const TextStyle(color: Colors.black)),
                                  ),
                                )).toList(),
                                onChanged: (v) => setState(() => _gradeLevel = v ?? '6'),
                                dropdownStyleData: DropdownStyleData(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    color: Colors.white,
                                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 12, offset: Offset(0, 4))],
                                  ),
                                  elevation: 4,
                                  offset: const Offset(0, 4),
                                ),
                                selectedItemBuilder: (context) => grades.map((g) => Text(g, style: const TextStyle(color: Colors.black))).toList(),
                              )
                            : Text(widget.user['gradeLevel'] ?? '-', style: const TextStyle(fontSize: 15))),
                          _buildTableRow('Province', _editMode
                            ? DropdownButton2<String>(
                                value: _province.isNotEmpty ? _province : null,
                                items: provinces.map((p) => DropdownMenuItem(
                                  value: p,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: p == 'Ontario' ? Colors.blue[50] : p == 'Quebec' ? Colors.pink[50] : Colors.green[50],
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    child: Text(p, style: const TextStyle(color: Colors.black)),
                                  ),
                                )).toList(),
                                onChanged: (v) => setState(() => _province = v ?? ''),
                                dropdownStyleData: DropdownStyleData(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    color: Colors.white,
                                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 12, offset: Offset(0, 4))],
                                  ),
                                  elevation: 4,
                                  offset: const Offset(0, 4),
                                ),
                                selectedItemBuilder: (context) => provinces.map((p) => Text(p, style: const TextStyle(color: Colors.black))).toList(),
                              )
                            : Text(widget.user['province'] ?? '-', style: const TextStyle(fontSize: 15))),
                          _buildTableRow('City', _editMode
                            ? DropdownButton2<String>(
                                value: _city.isNotEmpty ? _city : null,
                                items: cities.map((c) => DropdownMenuItem(
                                  value: c,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: c == 'Toronto' ? Colors.blue[50] : c == 'Ottawa' ? Colors.pink[50] : Colors.green[50],
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    child: Text(c, style: const TextStyle(color: Colors.black)),
                                  ),
                                )).toList(),
                                onChanged: (v) => setState(() => _city = v ?? ''),
                                dropdownStyleData: DropdownStyleData(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    color: Colors.white,
                                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 12, offset: Offset(0, 4))],
                                  ),
                                  elevation: 4,
                                  offset: const Offset(0, 4),
                                ),
                                selectedItemBuilder: (context) => cities.map((c) => Text(c, style: const TextStyle(color: Colors.black))).toList(),
                              )
                            : Text(widget.user['city'] ?? '-', style: const TextStyle(fontSize: 15))),
                          _buildTableRow('Mentor', _editMode
                            ? DropdownButton2<String>(
                                value: _mentorId.isNotEmpty ? _mentorId : null,
                                items: widget.mentors.map((m) => DropdownMenuItem<String>(
                                  value: m['id'] as String,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: m['id'] == _mentorId ? Colors.deepPurple[50] : Colors.grey[200],
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    child: Text('${m['firstName']} ${m['lastName']}', style: const TextStyle(color: Colors.black)),
                                  ),
                                )).toList(),
                                onChanged: (v) => setState(() => _mentorId = v ?? ''),
                                dropdownStyleData: DropdownStyleData(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    color: Colors.white,
                                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 12, offset: Offset(0, 4))],
                                  ),
                                  elevation: 4,
                                  offset: const Offset(0, 4),
                                ),
                                selectedItemBuilder: (context) => widget.mentors.map((m) => Text('${m['firstName']} ${m['lastName']}', style: const TextStyle(color: Colors.black))).toList(),
                              )
                            : Builder(
                                builder: (context) {
                                  String mentorName = '-';
                                  final mentor = widget.mentors.firstWhere(
                                    (m) => m['id'] == widget.user['mentorId'],
                                    orElse: () => <String, dynamic>{},
                                  );
                                  if (mentor.isNotEmpty) {
                                    mentorName = ((mentor['firstName'] ?? '') + ' ' + (mentor['lastName'] ?? '')).trim();
                                    if (mentorName.isEmpty) mentorName = '-';
                                  }
                                  return Text(mentorName, style: const TextStyle(fontSize: 15));
                                },
                              )),
                          _buildTableRow('Is Active', _editMode
                            ? Row(
                                children: [
                                  Transform.translate(
                                    offset: const Offset(-4, -2),
                                    child: Checkbox(
                                      value: _isActive,
                                      onChanged: (v) => setState(() => _isActive = v ?? true),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                      activeColor: Colors.green,
                                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      visualDensity: VisualDensity.compact,
                                    ),
                                  ),
                                ],
                              )
                            : Row(
                                children: [
                                  Transform.translate(
                                    offset: const Offset(-4, -2),
                                    child: Icon(_isActive ? Icons.check_circle : Icons.cancel, color: _isActive ? Colors.green : Colors.red),
                                  ),
                                ],
                              )),
                          const SizedBox(height: 8),
                          Transform.translate(
                            offset: const Offset(0, -4),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(
                                  width: 110,
                                  child: Text('Actions:', style: const TextStyle(fontWeight: FontWeight.w600)),
                                ),
                                Expanded(
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.start,
                                    children: [
                                      if (!_editMode)
                                        _CircleButton(
                                          icon: Icons.edit,
                                          label: 'Edit',
                                          color: Colors.grey[800]!,
                                          onPressed: _showEditDialog,
                                        ),
                                      if (_editMode) ...[
                                        _CircleButton(
                                          icon: Icons.save,
                                          label: 'Save',
                                          color: Colors.blue,
                                          onPressed: _saveEdits,
                                        ),
                                        const SizedBox(width: 8),
                                        _CircleButton(
                                          icon: Icons.cancel,
                                          label: 'Cancel',
                                          color: Colors.grey,
                                          onPressed: () {
                                            setState(() {
                                              _editMode = false;
                                              // Alanları eski haline döndür
                                              final user = widget.user;
                                              _firstNameController.text = user['firstName'] ?? '';
                                              _lastNameController.text = user['lastName'] ?? '';
                                              _gender = user['gender'] ?? 'Male';
                                              _gradeLevel = user['gradeLevel'] ?? '6';
                                              _province = user['province'] ?? '';
                                              _city = user['city'] ?? '';
                                              _mentorId = user['mentorId'] ?? '';
                                              _isActive = user['isActive'] ?? true;
                                            });
                                          },
                                        ),
                                      ],
                                      const SizedBox(width: 8),
                                      _CircleButton(
                                        icon: Icons.delete,
                                        label: 'Delete',
                                        color: Colors.red,
                                        onPressed: () async {
                                          final confirmed = await showDialog<bool>(
                                            context: context,
                                            builder: (context) => AlertDialog(
                                              title: const Text('Are you sure you want to delete this mentee?'),
                                              content: const Text('This action cannot be undone.'),
                                              actions: [
                                                TextButton(
                                                  onPressed: () => Navigator.of(context).pop(false),
                                                  child: const Text('Cancel'),
                                                ),
                                                TextButton(
                                                  onPressed: () => Navigator.of(context).pop(true),
                                                  child: const Text('Delete'),
                                                ),
                                              ],
                                            ),
                                          );
                                          if (confirmed == true) {
                                            // 1. Mentee profilini sil
                                            await FirebaseFirestore.instance.collection('users').doc(widget.menteeId).delete();
                                            // 2. Mentorun assignedTo array'inden menteeId'yi sil
                                            final mentorId = widget.user['mentorId'];
                                            if (mentorId != null && mentorId.toString().isNotEmpty) {
                                              await FirebaseFirestore.instance.collection('users').doc(mentorId).update({
                                                'assignedTo': FieldValue.arrayRemove([widget.menteeId])
                                              });
                                            }
                                            if (!mounted) return;
                                            widget.onUpdated();
                                          }
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTableRow(String label, Widget valueWidget) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 110, child: Text('$label:', style: const TextStyle(fontWeight: FontWeight.w600))),
          Expanded(child: valueWidget),
        ],
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onPressed;
  const _CircleButton({required this.icon, required this.label, required this.color, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2.0),
      child: ElevatedButton.icon(
        icon: Icon(icon, size: 16),
        label: Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          minimumSize: const Size(0, 36),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
        ),
        onPressed: onPressed,
      ),
    );
  }
}

class MenteeCreateDialog extends StatefulWidget {
  final List<Map<String, dynamic>> mentors;
  final VoidCallback onCreated;
  final VoidCallback onCancel;
  const MenteeCreateDialog({required this.mentors, required this.onCreated, required this.onCancel, super.key});

  @override
  State<MenteeCreateDialog> createState() => _MenteeCreateDialogState();
}

class _MenteeCreateDialogState extends State<MenteeCreateDialog> {
  final _formKey = GlobalKey<FormState>();
  String firstName = '';
  String lastName = '';
  String gender = '';
  String gradeLevel = '';
  String school = '';
  String province = '';
  String city = '';
  String mentorId = '';
  bool isActive = false;

  @override
  void initState() {
    super.initState();
    // mentorId'yi otomatik olarak doldurma, boş kalsın
    // school başta boş olacak
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final schoolOptions = ['High School']; // İleride başka seçenekler eklenebilir
    final grades = ['8', '9', '10', '11', '12', 'College'];
    final provinces = ['Ontario', 'Quebec', 'British Columbia'];
    final cities = ['Toronto', 'Ottawa', 'Montreal'];
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: GlassmorphicContainer(
        width: 380,
        height: double.infinity,
        borderRadius: 18,
        blur: 18,
        border: 1.5,
        linearGradient: LinearGradient(
          colors: [
            Colors.white.withOpacity(0.55),
            Colors.white.withOpacity(0.28),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderGradient: LinearGradient(
          colors: [
            Colors.white.withOpacity(0.70),
            Colors.white.withOpacity(0.32),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Create Mentee', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
                  const SizedBox(height: 16),
                  TextFormField(
                    decoration: const InputDecoration(labelText: 'First Name', labelStyle: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                    onChanged: (v) => setState(() => firstName = v),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    decoration: const InputDecoration(labelText: 'Last Name', labelStyle: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                    onChanged: (v) => setState(() => lastName = v),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField2<String>(
                    value: gender.isNotEmpty ? gender : null,
                    decoration: const InputDecoration(labelText: 'Gender', labelStyle: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                    isExpanded: true,
                    items: ['Male', 'Female'].map((g) => DropdownMenuItem(
                      value: g,
                      child: Container(
                        decoration: BoxDecoration(
                          color: g == 'Male' ? Colors.blue[50] : Colors.pink[50],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        child: Text(g, style: const TextStyle(color: Colors.black)),
                      ),
                    )).toList(),
                    onChanged: (v) => setState(() => gender = v ?? ''),
                    validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                    dropdownStyleData: DropdownStyleData(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: Colors.white,
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 12, offset: Offset(0, 4))],
                      ),
                      elevation: 4,
                      offset: const Offset(0, 4),
                    ),
                    selectedItemBuilder: (context) => ['Male', 'Female'].map((g) => Text(g, style: const TextStyle(color: Colors.black))).toList(),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField2<String>(
                    value: school.isNotEmpty ? school : null,
                    decoration: const InputDecoration(labelText: 'School', labelStyle: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                    isExpanded: true,
                    items: schoolOptions.map((s) => DropdownMenuItem(
                      value: s,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        child: Text(s, style: const TextStyle(color: Colors.black)),
                      ),
                    )).toList(),
                    onChanged: (v) => setState(() => school = v ?? ''),
                    validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                    dropdownStyleData: DropdownStyleData(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: Colors.white,
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 12, offset: Offset(0, 4))],
                      ),
                      elevation: 4,
                      offset: const Offset(0, 4),
                    ),
                    selectedItemBuilder: (context) => schoolOptions.map((s) => Text(s, style: const TextStyle(color: Colors.black))).toList(),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField2<String>(
                    value: gradeLevel.isNotEmpty ? gradeLevel : null,
                    decoration: const InputDecoration(labelText: 'Grade', labelStyle: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                    isExpanded: true,
                    items: grades.map((g) => DropdownMenuItem(
                      value: g,
                      child: Container(
                        decoration: BoxDecoration(
                          color: g == 'College' ? Colors.deepPurple[50] : Colors.grey[200],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        child: Text(g, style: const TextStyle(color: Colors.black)),
                      ),
                    )).toList(),
                    onChanged: (v) => setState(() => gradeLevel = v ?? ''),
                    validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                    dropdownStyleData: DropdownStyleData(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: Colors.white,
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 12, offset: Offset(0, 4))],
                      ),
                      elevation: 4,
                      offset: const Offset(0, 4),
                    ),
                    selectedItemBuilder: (context) => grades.map((g) => Text(g, style: const TextStyle(color: Colors.black))).toList(),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField2<String>(
                    value: province.isNotEmpty ? province : null,
                    decoration: const InputDecoration(labelText: 'Province', labelStyle: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                    isExpanded: true,
                    items: provinces.map((p) => DropdownMenuItem(
                      value: p,
                      child: Container(
                        decoration: BoxDecoration(
                          color: p == 'Ontario' ? Colors.blue[50] : p == 'Quebec' ? Colors.pink[50] : Colors.green[50],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        child: Text(p, style: const TextStyle(color: Colors.black)),
                      ),
                    )).toList(),
                    onChanged: (v) => setState(() => province = v ?? ''),
                    validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                    dropdownStyleData: DropdownStyleData(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: Colors.white,
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 12, offset: Offset(0, 4))],
                      ),
                      elevation: 4,
                      offset: const Offset(0, 4),
                    ),
                    selectedItemBuilder: (context) => provinces.map((p) => Text(p, style: const TextStyle(color: Colors.black))).toList(),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField2<String>(
                    value: city.isNotEmpty ? city : null,
                    decoration: const InputDecoration(labelText: 'City', labelStyle: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                    isExpanded: true,
                    items: cities.map((c) => DropdownMenuItem(
                      value: c,
                      child: Container(
                        decoration: BoxDecoration(
                          color: c == 'Toronto' ? Colors.blue[50] : c == 'Ottawa' ? Colors.pink[50] : Colors.green[50],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        child: Text(c, style: const TextStyle(color: Colors.black)),
                      ),
                    )).toList(),
                    onChanged: (v) => setState(() => city = v ?? ''),
                    validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                    dropdownStyleData: DropdownStyleData(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: Colors.white,
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 12, offset: Offset(0, 4))],
                      ),
                      elevation: 4,
                      offset: const Offset(0, 4),
                    ),
                    selectedItemBuilder: (context) => cities.map((c) => Text(c, style: const TextStyle(color: Colors.black))).toList(),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField2<String>(
                    value: mentorId.isNotEmpty ? mentorId : null,
                    decoration: const InputDecoration(labelText: 'Mentor', labelStyle: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                    isExpanded: true,
                    items: widget.mentors.map((m) => DropdownMenuItem<String>(
                      value: m['id'] as String,
                      child: Container(
                        decoration: BoxDecoration(
                          color: m['id'] == mentorId ? Colors.deepPurple[50] : Colors.grey[200],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        child: Text('${m['firstName']} ${m['lastName']}', style: const TextStyle(color: Colors.black)),
                      ),
                    )).toList(),
                    onChanged: (v) => setState(() => mentorId = v ?? ''),
                    validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                    dropdownStyleData: DropdownStyleData(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: Colors.white,
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 12, offset: Offset(0, 4))],
                      ),
                      elevation: 4,
                      offset: const Offset(0, 4),
                    ),
                    selectedItemBuilder: (context) => widget.mentors.map((m) => Text('${m['firstName']} ${m['lastName']}', style: const TextStyle(color: Colors.black))).toList(),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Checkbox(
                        value: isActive,
                        onChanged: (v) => setState(() => isActive = v ?? false),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        activeColor: Colors.green,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                      ),
                      const Text('Is Active', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      ElevatedButton(
                        onPressed: () async {
                          // Eğer herhangi bir alan doluysa, onay iste
                          if (firstName.isNotEmpty || lastName.isNotEmpty || gender.isNotEmpty || gradeLevel.isNotEmpty || school.isNotEmpty || province.isNotEmpty || city.isNotEmpty || mentorId.isNotEmpty) {
                            final discard = await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Are you sure you want to exit without saving changes?'),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.of(context).pop(false),
                                    child: const Text('Cancel'),
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.of(context).pop(true),
                                    child: const Text('Discard'),
                                  ),
                                ],
                              ),
                            );
                            if (discard != true) return;
                          }
                          widget.onCancel();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepPurple[50],
                          foregroundColor: Colors.black87,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 0),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                          elevation: 2,
                          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                          minimumSize: const Size(80, 38),
                          shadowColor: Colors.deepPurple.withOpacity(0.12),
                        ),
                        child: Text('Cancel'),
                      ),
                      ElevatedButton(
                        onPressed: () async {
                          if (!_formKey.currentState!.validate()) return;
                          final uid = FirebaseAuth.instance.currentUser?.uid;
                          if (uid == null) return;
                          final docRef = await FirebaseFirestore.instance.collection('users').add({
                            'firstName': firstName.trim(),
                            'lastName': lastName.trim(),
                            'gender': gender,
                            'school': school,
                            'gradeLevel': gradeLevel == 'College' ? 'College' : '${gradeLevel}th grade',
                            'province': province,
                            'city': city,
                            'mentorId': mentorId,
                            'isActive': isActive,
                            'parentId': uid,
                            'role': 'mentee',
                            'createdAt': FieldValue.serverTimestamp(),
                          });
                          // Mentorun assignedTo array'ine menteeId ekle
                          await FirebaseFirestore.instance.collection('users').doc(mentorId).update({
                            'assignedTo': FieldValue.arrayUnion([docRef.id])
                          });
                          if (!mounted) return;
                          widget.onCreated();
                        },
                        child: const Text('Save'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class MenteeEditDialog extends StatefulWidget {
  final Map<String, dynamic> menteeData;
  final String menteeId;
  final List<Map<String, dynamic>> mentors;
  final VoidCallback onSaved;
  const MenteeEditDialog({required this.menteeData, required this.menteeId, required this.mentors, required this.onSaved, super.key});

  @override
  State<MenteeEditDialog> createState() => _MenteeEditDialogState();
}

class _MenteeEditDialogState extends State<MenteeEditDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController firstNameController;
  late TextEditingController lastNameController;
  String gender = '';
  String gradeLevel = '';
  String province = '';
  String city = '';
  String mentorId = '';
  bool isActive = true;

  @override
  void initState() {
    super.initState();
    final data = widget.menteeData;
    firstNameController = TextEditingController(text: data['firstName'] ?? '');
    lastNameController = TextEditingController(text: data['lastName'] ?? '');
    gender = data['gender'] ?? '';
    gradeLevel = _getPureGrade(data['gradeLevel'] ?? '');
    province = data['province'] ?? '';
    city = data['city'] ?? '';
    mentorId = data['mentorId'] ?? (widget.mentors.isNotEmpty ? widget.mentors.first['id'] : '');
    isActive = data['isActive'] ?? true;
  }

  String _getPureGrade(String grade) {
    if (grade == 'College') return 'College';
    final match = RegExp(r'^(\d+)th grade').firstMatch(grade);
    if (match != null) return match.group(1)!;
    return grade;
  }

  String get pureGradeLevel {
    return gradeLevel;
  }

  @override
  Widget build(BuildContext context) {
    final grades = ['8', '9', '10', '11', '12', 'College'];
    final genders = ['Male', 'Female'];
    final provinces = ['Ontario', 'Quebec', 'British Columbia'];
    final cities = ['Toronto', 'Ottawa', 'Montreal'];
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: GlassmorphicContainer(
        width: 380,
        height: double.infinity,
        borderRadius: 18,
        blur: 18,
        border: 1.5,
        linearGradient: LinearGradient(
          colors: [
            Colors.white.withOpacity(0.55),
            Colors.white.withOpacity(0.28),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderGradient: LinearGradient(
          colors: [
            Colors.white.withOpacity(0.70),
            Colors.white.withOpacity(0.32),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, 10),
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Edit Mentee', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: firstNameController,
                    decoration: const InputDecoration(labelText: 'First Name', labelStyle: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: lastNameController,
                    decoration: const InputDecoration(labelText: 'Last Name', labelStyle: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField2<String>(
                    value: gender,
                    decoration: const InputDecoration(labelText: 'Gender', labelStyle: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                    isExpanded: true,
                    items: genders.map((g) => DropdownMenuItem(
                      value: g,
                      child: Container(
                        decoration: BoxDecoration(
                          color: g == 'Male' ? Colors.blue[50] : Colors.pink[50],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        child: Text(g, style: const TextStyle(color: Colors.black)),
                      ),
                    )).toList(),
                    onChanged: (v) => setState(() => gender = v ?? ''),
                    validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                    dropdownStyleData: DropdownStyleData(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: Colors.white,
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 12, offset: Offset(0, 4))],
                      ),
                      elevation: 4,
                      offset: const Offset(0, 4),
                    ),
                    selectedItemBuilder: (context) => genders.map((g) => Text(g, style: const TextStyle(color: Colors.black))).toList(),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField2<String>(
                    value: pureGradeLevel,
                    decoration: const InputDecoration(labelText: 'Grade', labelStyle: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                    isExpanded: true,
                    items: grades.map((g) => DropdownMenuItem(
                      value: g,
                      child: Container(
                        decoration: BoxDecoration(
                          color: g == 'College' ? Colors.deepPurple[50] : Colors.grey[200],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        child: Text(g, style: const TextStyle(color: Colors.black)),
                      ),
                    )).toList(),
                    onChanged: (v) => setState(() => gradeLevel = v ?? ''),
                    validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                    dropdownStyleData: DropdownStyleData(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: Colors.white,
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 12, offset: Offset(0, 4))],
                      ),
                      elevation: 4,
                      offset: const Offset(0, 4),
                    ),
                    selectedItemBuilder: (context) => grades.map((g) => Text(g, style: const TextStyle(color: Colors.black))).toList(),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField2<String>(
                    value: province.isNotEmpty ? province : null,
                    decoration: const InputDecoration(labelText: 'Province', labelStyle: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                    isExpanded: true,
                    items: provinces.map((p) => DropdownMenuItem(
                      value: p,
                      child: Container(
                        decoration: BoxDecoration(
                          color: p == 'Ontario' ? Colors.blue[50] : p == 'Quebec' ? Colors.pink[50] : Colors.green[50],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        child: Text(p, style: const TextStyle(color: Colors.black)),
                      ),
                    )).toList(),
                    onChanged: (v) => setState(() => province = v ?? ''),
                    validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                    dropdownStyleData: DropdownStyleData(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: Colors.white,
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 12, offset: Offset(0, 4))],
                      ),
                      elevation: 4,
                      offset: const Offset(0, 4),
                    ),
                    selectedItemBuilder: (context) => provinces.map((p) => Text(p, style: const TextStyle(color: Colors.black))).toList(),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField2<String>(
                    value: city.isNotEmpty ? city : null,
                    decoration: const InputDecoration(labelText: 'City', labelStyle: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                    isExpanded: true,
                    items: cities.map((c) => DropdownMenuItem(
                      value: c,
                      child: Container(
                        decoration: BoxDecoration(
                          color: c == 'Toronto' ? Colors.blue[50] : c == 'Ottawa' ? Colors.pink[50] : Colors.green[50],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        child: Text(c, style: const TextStyle(color: Colors.black)),
                      ),
                    )).toList(),
                    onChanged: (v) => setState(() => city = v ?? ''),
                    validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                    dropdownStyleData: DropdownStyleData(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: Colors.white,
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 12, offset: Offset(0, 4))],
                      ),
                      elevation: 4,
                      offset: const Offset(0, 4),
                    ),
                    selectedItemBuilder: (context) => cities.map((c) => Text(c, style: const TextStyle(color: Colors.black))).toList(),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField2<String>(
                    value: mentorId.isNotEmpty ? mentorId : null,
                    decoration: const InputDecoration(labelText: 'Mentor', labelStyle: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                    isExpanded: true,
                    items: widget.mentors.map((m) => DropdownMenuItem<String>(
                      value: m['id'] as String,
                      child: Container(
                        decoration: BoxDecoration(
                          color: m['id'] == mentorId ? Colors.deepPurple[50] : Colors.grey[200],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        child: Text('${m['firstName']} ${m['lastName']}', style: const TextStyle(color: Colors.black)),
                      ),
                    )).toList(),
                    onChanged: (v) => setState(() => mentorId = v ?? ''),
                    validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                    dropdownStyleData: DropdownStyleData(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: Colors.white,
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 12, offset: Offset(0, 4))],
                      ),
                      elevation: 4,
                      offset: const Offset(0, 4),
                    ),
                    selectedItemBuilder: (context) => widget.mentors.map((m) => Text('${m['firstName']} ${m['lastName']}', style: const TextStyle(color: Colors.black))).toList(),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Checkbox(
                        value: isActive,
                        onChanged: (v) => setState(() => isActive = v ?? true),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        activeColor: Colors.green,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                      ),
                      const Text('Is Active', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      ElevatedButton(
                        onPressed: () async {
                          final hasChanges = firstNameController.text != (widget.menteeData['firstName'] ?? '') ||
                              lastNameController.text != (widget.menteeData['lastName'] ?? '') ||
                              gender != (widget.menteeData['gender'] ?? '') ||
                              gradeLevel != _getPureGrade(widget.menteeData['gradeLevel'] ?? '') ||
                              province != (widget.menteeData['province'] ?? '') ||
                              city != (widget.menteeData['city'] ?? '') ||
                              mentorId != (widget.menteeData['mentorId'] ?? '') ||
                              isActive != (widget.menteeData['isActive'] ?? true);

                          if (hasChanges) {
                            final discard = await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Discard changes?'),
                                content: const Text('You have unsaved changes. Are you sure you want to discard them?'),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.of(context).pop(false),
                                    child: const Text('Cancel'),
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.of(context).pop(true),
                                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                                    child: const Text('Discard'),
                                  ),
                                ],
                              ),
                            );
                            if (discard != true) return;
                          }
                          Navigator.of(context).pop();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepPurple[50],
                          foregroundColor: Colors.black87,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 0),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                          elevation: 2,
                          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                          minimumSize: const Size(80, 38),
                          shadowColor: Colors.deepPurple.withOpacity(0.12),
                        ),
                        child: Text('Cancel'),
                      ),
                      ElevatedButton(
                        onPressed: () async {
                          if (!_formKey.currentState!.validate()) return;
                          final menteeDoc = FirebaseFirestore.instance.collection('users').doc(widget.menteeId);
                          final oldMentorId = widget.menteeData['mentorId'];
                          final newMentorId = mentorId;
                          await menteeDoc.update({
                            'firstName': firstNameController.text.trim(),
                            'lastName': lastNameController.text.trim(),
                            'gender': gender,
                            'gradeLevel': gradeLevel == 'College' ? 'College' : '${gradeLevel}th grade',
                            'province': province,
                            'city': city,
                            'mentorId': newMentorId,
                            'isActive': isActive,
                          });
                          if (oldMentorId != newMentorId) {
                            // Eski mentordan sil
                            if (oldMentorId != null && oldMentorId.isNotEmpty) {
                              await FirebaseFirestore.instance.collection('users').doc(oldMentorId).update({
                                'assignedTo': FieldValue.arrayRemove([widget.menteeId])
                              });
                            }
                            // Yeni mentora ekle
                            if (newMentorId.isNotEmpty) {
                              await FirebaseFirestore.instance.collection('users').doc(newMentorId).update({
                                'assignedTo': FieldValue.arrayUnion([widget.menteeId])
                              });
                            }
                          }
                          if (!mounted) return;
                          widget.onSaved();
                          context.pop();
                        },
                        child: const Text('Save'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HeaderBox extends StatelessWidget {
  final String label;
  final bool selected;
  final bool asc;
  final double width;
  final double fontSize;
  final VoidCallback onTap;
  final bool glass;
  const _HeaderBox({required this.label, required this.selected, required this.asc, required this.width, required this.fontSize, required this.onTap, this.glass = false});

  @override
  Widget build(BuildContext context) {
    if (glass) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2.0, vertical: 4.0),
        child: GlassmorphicContainer(
          width: width,
          height: 42,
          borderRadius: 12,
          blur: 12,
          border: 1.2,
          linearGradient: LinearGradient(
            colors: [
              Colors.white.withOpacity(0.18),
              Colors.white.withOpacity(0.04),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderGradient: LinearGradient(
            colors: [
              Colors.white.withOpacity(0.40),
              Colors.white.withOpacity(0.10),
            ],
          ),
          alignment: Alignment.center,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onTap,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: fontSize,
                    color: selected ? Theme.of(context).primaryColor : Colors.black87,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                if (selected)
                  Icon(asc ? Icons.arrow_drop_up : Icons.arrow_drop_down, size: 18, color: Theme.of(context).primaryColor),
              ],
            ),
          ),
        ),
      );
    } else {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2.0, vertical: 4.0),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Container(
            width: width,
            height: 42,
            decoration: BoxDecoration(
              color: selected ? Colors.blue[50] : Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: selected ? Theme.of(context).primaryColor : Colors.grey[300]!, width: 1.2),
            ),
            alignment: Alignment.center,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: fontSize,
                    color: selected ? Theme.of(context).primaryColor : Colors.black87,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                if (selected)
                  Icon(asc ? Icons.arrow_drop_up : Icons.arrow_drop_down, size: 18, color: Theme.of(context).primaryColor),
              ],
            ),
          ),
        ),
      );
    }
  }
}

class _CreateFAB extends StatelessWidget {
  final VoidCallback onPressed;
  const _CreateFAB({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return GlassmorphicContainer(
      width: 160,
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
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(22.5),
        child: Center(
          child: Text(
            'Add Mentee',
            style: TextStyle(
              color: const Color.fromARGB(255, 84, 192, 255),
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
        ),
      ),
    );
  }
} 