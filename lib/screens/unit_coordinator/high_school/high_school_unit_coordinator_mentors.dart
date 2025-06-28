import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:glassmorphism/glassmorphism.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/services.dart';

class HighSchoolUnitCoordinatorMentors extends StatefulWidget {
  const HighSchoolUnitCoordinatorMentors({super.key});

  @override
  State<HighSchoolUnitCoordinatorMentors> createState() => _HighSchoolUnitCoordinatorMentorsState();
}

class _HighSchoolUnitCoordinatorMentorsState extends State<HighSchoolUnitCoordinatorMentors> {
  Future<void> _removeSupervision(BuildContext context, String mentorId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final userRef = FirebaseFirestore.instance.collection('users').doc(uid);
    await userRef.update({
      'assignedTo': FieldValue.arrayRemove([mentorId])
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Mentor removed from your supervision.')),
    );
  }

  Future<Map<String, dynamic>?> _getSupervisorInfo(String? supervisorId) async {
    if (supervisorId == null || supervisorId.isEmpty) return null;
    final doc = await FirebaseFirestore.instance.collection('users').doc(supervisorId).get();
    return doc.data();
  }

  String _schoolLevelFromRole(String? supervisorRole) {
    if (supervisorRole == 'middleSchoolUnitCoordinator') return 'Middle School';
    if (supervisorRole == 'highSchoolUnitCoordinator') return 'High School';
    return '-';
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Mentors'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
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
          Positioned.fill(
            top: kToolbarHeight + MediaQuery.of(context).padding.top,
            child: uid == null
                ? const Center(child: Text('Not authenticated.'))
                : StreamBuilder<DocumentSnapshot>(
                    stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final data = snapshot.data?.data() as Map<String, dynamic>?;
                      final assignedTo = (data?['assignedTo'] as List<dynamic>? ?? []).cast<String>();
                      if (assignedTo.isEmpty) {
                        return const Center(child: Text('No mentors assigned yet.'));
                      }
                      return FutureBuilder<QuerySnapshot>(
                        future: FirebaseFirestore.instance
                            .collection('users')
                            .where(FieldPath.documentId, whereIn: assignedTo)
                            .where('role', isEqualTo: 'mentor')
                            .get(),
                        builder: (context, userSnap) {
                          if (userSnap.connectionState == ConnectionState.waiting) {
                            return const Center(child: CircularProgressIndicator());
                          }
                          final users = userSnap.data?.docs ?? [];
                          if (users.isEmpty) {
                            return const Center(child: Text('No mentors found.'));
                          }
                          return ListView.separated(
                            padding: const EdgeInsets.all(10),
                            itemCount: users.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 10),
                            itemBuilder: (context, i) {
                              final user = users[i].data() as Map<String, dynamic>;
                              final mentorId = users[i].id;
                              final fullName = ((user['firstName'] ?? '') + ' ' + (user['lastName'] ?? '')).trim();
                              return MentorTableCard(
                                mentorId: mentorId,
                                user: user,
                                fullName: fullName,
                                removeSupervision: _removeSupervision,
                                getSupervisorInfo: _getSupervisorInfo,
                                schoolLevelFromRole: _schoolLevelFromRole,
                                onMentorUpdated: () => setState(() {}),
                              );
                            },
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class MentorTableCard extends StatefulWidget {
  final String mentorId;
  final Map<String, dynamic> user;
  final String fullName;
  final Future<void> Function(BuildContext, String) removeSupervision;
  final Future<Map<String, dynamic>?> Function(String?) getSupervisorInfo;
  final String Function(String?) schoolLevelFromRole;
  final VoidCallback onMentorUpdated;

  const MentorTableCard({
    required this.mentorId,
    required this.user,
    required this.fullName,
    required this.removeSupervision,
    required this.getSupervisorInfo,
    required this.schoolLevelFromRole,
    required this.onMentorUpdated,
    super.key,
  });

  @override
  State<MentorTableCard> createState() => _MentorTableCardState();
}

class _MentorTableCardState extends State<MentorTableCard> with SingleTickerProviderStateMixin {
  bool _expanded = false;
  bool _isActive = false;
  String? _supervisorName;
  String? _supervisorRole;
  bool _loadingSupervisor = false;

  @override
  void initState() {
    super.initState();
    _isActive = widget.user['isActive'] ?? false;
    _fetchSupervisor();
  }

  Future<void> _fetchSupervisor() async {
    setState(() => _loadingSupervisor = true);
    final supervisor = await widget.getSupervisorInfo(widget.user['parentId']);
    setState(() {
      _supervisorName = supervisor == null ? '-' : ((supervisor['firstName'] ?? '') + ' ' + (supervisor['lastName'] ?? '')).trim();
      _supervisorRole = supervisor == null ? null : supervisor['role'] as String?;
      _loadingSupervisor = false;
    });
  }

  void _showEditMentorDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => _EditMentorDialog(
        user: widget.user,
        mentorId: widget.mentorId,
      ),
    );
    if (result == true) {
      widget.onMentorUpdated();
    }
  }

  void _showRemoveDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Supervision'),
        content: const Text('Are you sure you want to remove this mentor from your supervision?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              widget.removeSupervision(context, widget.mentorId);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  Widget _buildTableRow(String label, Widget valueWidget) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text('$label:', style: const TextStyle(fontWeight: FontWeight.w600, color: Color.fromARGB(255, 23, 23, 23))),
          ),
          Expanded(child: valueWidget),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 800),
      curve: Curves.fastOutSlowIn,
      child: GlassmorphicContainer(
        width: double.infinity,
        height: _expanded ? 430 : 50,
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
          child: Column(
            children: [
              InkWell(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                onTap: () => setState(() => _expanded = !_expanded),
                child: Container(
                  height: 50,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: _expanded ? Colors.white.withOpacity(0.1) : Colors.transparent,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                  ),
                  child: Row(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: _expanded ? Colors.blue : Colors.green,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: (_expanded ? Colors.blue : Colors.green).withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Icon(_expanded ? Icons.remove : Icons.add, color: Colors.white, size: 14),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          widget.fullName.isNotEmpty ? widget.fullName : widget.mentorId,
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: const Color.fromARGB(255, 23, 23, 23)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(widget.user['email'] ?? '-', style: theme.textTheme.bodyMedium?.copyWith(color: const Color.fromARGB(255, 46, 46, 46))),
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
                            _buildTableRow('Username', Text(widget.user['username'] ?? '-', style: theme.textTheme.bodyMedium?.copyWith(color: const Color.fromARGB(255, 23, 23, 23)))),
                            _buildTableRow('Country', Text(widget.user['country'] ?? '-', style: theme.textTheme.bodyMedium?.copyWith(color: const Color.fromARGB(255, 23, 23, 23)))),
                            _buildTableRow('Province', Text(widget.user['province'] ?? '-', style: theme.textTheme.bodyMedium?.copyWith(color: const Color.fromARGB(255, 23, 23, 23)))),
                            _buildTableRow('City', Text(widget.user['city'] ?? '-', style: theme.textTheme.bodyMedium?.copyWith(color: const Color.fromARGB(255, 23, 23, 23)))),
                            _buildTableRow('Role', Text((widget.user['role'] ?? '-').toString().replaceFirst(RegExp(r'^.'), (widget.user['role'] ?? '-').toString().substring(0, 1).toUpperCase()), style: theme.textTheme.bodyMedium?.copyWith(color: const Color.fromARGB(255, 23, 23, 23)))),
                            _buildTableRow('Supervisor', Text(_loadingSupervisor ? 'Loading...' : (_supervisorName ?? '-'), style: theme.textTheme.bodyMedium?.copyWith(color: const Color.fromARGB(255, 23, 23, 23)))),
                            _buildTableRow('School Level', Text(widget.schoolLevelFromRole(_supervisorRole), style: theme.textTheme.bodyMedium?.copyWith(color: const Color.fromARGB(255, 23, 23, 23)))),
                            _buildTableRow('Gender', Text(widget.user['gender'] ?? '-', style: theme.textTheme.bodyMedium?.copyWith(color: const Color.fromARGB(255, 23, 23, 23)))),
                            _buildTableRow(
                              'User ID',
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Expanded(
                                    child: Text(
                                      widget.mentorId,
                                      style: theme.textTheme.bodyMedium?.copyWith(color: const Color.fromARGB(255, 23, 23, 23), fontSize: 13),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  InkWell(
                                    borderRadius: BorderRadius.circular(16),
                                    onTap: () async {
                                      await Clipboard.setData(ClipboardData(text: widget.mentorId));
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('Copied!'), duration: Duration(milliseconds: 900)),
                                        );
                                      }
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.all(0.0),
                                      child: Icon(Icons.copy, size: 16),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(
                                  width: 120,
                                  child: Text('Actions:', style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600, color: const Color.fromARGB(255, 23, 23, 23))),
                                ),
                                Expanded(
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.start,
                                    children: [
                                      _CircleButton(
                                        icon: Icons.edit,
                                        label: 'Edit',
                                        color: Colors.grey[800]!,
                                        onPressed: _showEditMentorDialog,
                                      ),
                                      const SizedBox(width: 8),
                                      _CircleButton(
                                        icon: Icons.delete,
                                        label: 'Remove',
                                        color: Colors.red,
                                        onPressed: _showRemoveDialog,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
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

class _EditMentorDialog extends StatefulWidget {
  final Map<String, dynamic> user;
  final String mentorId;

  const _EditMentorDialog({required this.user, required this.mentorId});

  @override
  State<_EditMentorDialog> createState() => _EditMentorDialogState();
}

class _EditMentorDialogState extends State<_EditMentorDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _countryController;
  late TextEditingController _provinceController;
  late TextEditingController _cityController;
  late TextEditingController _genderController;

  final countryOptions = ['Canada', 'USA', 'UK'];
  final provinceOptions = ['Ontario', 'Quebec', 'British Columbia'];
  final cityOptions = ['Ottawa', 'Toronto', 'Montreal'];
  final genderOptions = ['Male', 'Female'];

  @override
  void initState() {
    super.initState();
    _countryController = TextEditingController(text: widget.user['country'] ?? '');
    _provinceController = TextEditingController(text: widget.user['province'] ?? '');
    _cityController = TextEditingController(text: widget.user['city'] ?? '');
    _genderController = TextEditingController(text: widget.user['gender'] ?? '');
  }

  @override
  void dispose() {
    _countryController.dispose();
    _provinceController.dispose();
    _cityController.dispose();
    _genderController.dispose();
    super.dispose();
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;

    final doc = FirebaseFirestore.instance.collection('users').doc(widget.mentorId);
    final updates = <String, dynamic>{
      'country': _countryController.text.trim(),
      'province': _provinceController.text.trim(),
      'city': _cityController.text.trim(),
      'gender': _genderController.text.trim(),
      'gradeLevel': FieldValue.delete(),
    };

    try {
      await doc.update(updates);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Mentor updated successfully.')),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update mentor: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: GlassmorphicContainer(
        width: 380,
        height: 500,
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
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Edit Mentor', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
                const SizedBox(height: 16),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildDropdown('Country', _countryController, countryOptions),
                        const SizedBox(height: 10),
                        _buildDropdown('Province', _provinceController, provinceOptions),
                        const SizedBox(height: 10),
                        _buildDropdown('City', _cityController, cityOptions),
                        const SizedBox(height: 10),
                        _buildDropdown('Gender', _genderController, genderOptions),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    ElevatedButton(
                      onPressed: () async {
                        final hasChanges = _countryController.text != (widget.user['country'] ?? '') ||
                            _provinceController.text != (widget.user['province'] ?? '') ||
                            _cityController.text != (widget.user['city'] ?? '') ||
                            _genderController.text != (widget.user['gender'] ?? '');

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
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
                      onPressed: _saveChanges,
                      child: const Text('Save'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDropdown(String label, TextEditingController controller, List<String> items) {
    return DropdownButtonFormField2<String>(
      value: controller.text.isNotEmpty && items.contains(controller.text) ? controller.text : null,
      decoration: InputDecoration(labelText: label, labelStyle: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
      isExpanded: true,
      items: items.map((i) => DropdownMenuItem(
        value: i,
        child: Container(
          decoration: BoxDecoration(
            color: controller.text == i ? Colors.blue[100] : Colors.grey[200],
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Text(i, style: const TextStyle(color: Colors.black)),
        ),
      )).toList(),
      onChanged: (v) => setState(() => controller.text = v ?? ''),
      validator: (v) => v == null || v.isEmpty ? 'Required' : null,
      dropdownStyleData: DropdownStyleData(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Colors.white,
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        elevation: 4,
        offset: const Offset(0, 4),
      ),
      selectedItemBuilder: (context) => items.map((i) => Text(i, style: const TextStyle(color: Colors.black))).toList(),
    );
  }
} 