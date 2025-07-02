import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

const Color kCardBorder = Color(0xFFE0E0E0);
const Color kCardBg = Color(0xFFFFFFFF);
const Color kTextDark = Color(0xFF444444);
const Color kCardInnerBg = Color(0xFFF5F7FB);
const Color kButtonBg = Color(0xFFF5E6FA);

final activityData = [
  {'key': 'quran', 'label': 'Quran', 'icon': '📖', 'hint': 'pages/verses'},
  {'key': 'prayer', 'label': 'Prayer', 'icon': '🕌', 'hint': 'count/notes'},
  {'key': 'memorization', 'label': 'Memorization', 'icon': '🧠', 'hint': 'verses/pages'},
  {'key': 'dhikr', 'label': 'Dhikr', 'icon': '🧿', 'hint': 'count'},
  {'key': 'fasting', 'label': 'Fasting', 'icon': '🌙', 'hint': 'days/notes'},
  {'key': 'tahajjud', 'label': 'Tahajjud', 'icon': '🌃', 'hint': 'count/notes'},
  {'key': 'nafila', 'label': 'Nafila', 'icon': '✨', 'hint': 'count/notes'},
  {'key': 'reading', 'label': 'Reading', 'icon': '📚', 'hint': 'pages/notes'},
];

class HomeDailyEntry extends StatefulWidget {
  const HomeDailyEntry({super.key});

  @override
  State<HomeDailyEntry> createState() => _HomeDailyEntryState();
}

class _HomeDailyEntryState extends State<HomeDailyEntry> {
  final Map<String, TextEditingController> _controllers = {
    for (var item in activityData) item['key'] as String: TextEditingController(text: '0'),
  };
  final Map<String, bool> _boolFields = {
    'prayer': false,
    'fasting': false,
    'tahajjud': false,
    'nafila': false,
  };

  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _goalData;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadGoalsAndTodayEntry();
    });
  }

  Future<void> _loadGoalsAndTodayEntry() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final now = DateTime.now();
    final dateId =
        '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    try {
      // Hedefleri çek
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      _goalData = userDoc.data()?['goalData'] as Map<String, dynamic>?;
      // Günlük girişleri çek
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('entries')
          .doc(dateId)
          .get();
      if (doc.exists) {
        final data = doc.data()!;
        for (var key in _controllers.keys) {
          _controllers[key]!.text = data[key]?.toString() ?? '';
        }
        for (var key in _boolFields.keys) {
          _boolFields[key] = data[key] == true;
        }
      }
    } catch (e) {
      _error = 'Failed to load entry.';
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _saveEntry() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final now = DateTime.now();
    final dateId =
        '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    try {
      final entryData = <String, dynamic>{'timestamp': FieldValue.serverTimestamp()};
      for (var key in _controllers.keys) {
        entryData[key] = _controllers[key]!.text.trim();
      }
      for (var key in _boolFields.keys) {
        entryData[key] = _boolFields[key];
      }
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('entries')
          .doc(dateId)
          .set(entryData, SetOptions(merge: true));
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Entry saved!')));
    } catch (_) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Failed to save entry. Please try again.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(70),
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
          ),
          child: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: kTextDark),
              onPressed: () => context.pop(),
            ),
            title: Text(
              'My Daily Journey 🚀',
              style: GoogleFonts.quicksand(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: kTextDark,
                letterSpacing: 1.1,
              ),
            ),
            centerTitle: true,
            iconTheme: const IconThemeData(color: kTextDark),
            actions: [
              IconButton(
                icon: const Icon(Icons.settings, color: kTextDark),
                onPressed: () => context.push('/settings'),
              ),
            ],
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(18.0),
              child: Column(
                children: [
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Text(
                        _error!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  Expanded(
                    child: GridView.builder(
                      itemCount: activityData.length,
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 18,
                        mainAxisSpacing: 18,
                        childAspectRatio: 1,
                      ),
                      itemBuilder: (context, i) {
                        final data = activityData[i];
                        final key = data['key'] as String;
                        final hasGoal = _goalData != null && _goalData!.containsKey(key);
                        final goalValue = hasGoal ? _goalData![key] : null;
                        return Container(
                          decoration: BoxDecoration(
                            color: kCardBg,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: kCardBorder, width: 1.2),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.03),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                data['icon']!,
                                style: const TextStyle(fontSize: 36),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                data['label']!,
                                style: GoogleFonts.quicksand(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 17,
                                  color: kTextDark,
                                ),
                              ),
                              if (hasGoal && (key == 'quran' || key == 'prayer' || key == 'dhikr'))
                                Padding(
                                  padding: const EdgeInsets.only(top: 6.0, bottom: 2.0),
                                  child: Text(
                                    'Today: ${_controllers[key]!.text} / $goalValue',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: Colors.deepOrange,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              const SizedBox(height: 10),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.remove_circle_outline, color: kTextDark),
                                    onPressed: () {
                                      setState(() {
                                        int current = int.tryParse(_controllers[key]!.text) ?? 0;
                                        if (current > 0) _controllers[key]!.text = (current - 1).toString();
                                      });
                                    },
                                  ),
                                  Text(
                                    _controllers[key]!.text,
                                    style: GoogleFonts.quicksand(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                      color: kTextDark,
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.add_circle_outline, color: kTextDark),
                                    onPressed: () {
                                      setState(() {
                                        int current = int.tryParse(_controllers[key]!.text) ?? 0;
                                        _controllers[key]!.text = (current + 1).toString();
                                      });
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: ElevatedButton(
                      onPressed: _saveEntry,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kButtonBg,
                        foregroundColor: kTextDark,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 0),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                        elevation: 2,
                        textStyle: GoogleFonts.quicksand(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                        ),
                        shadowColor: kButtonBg.withOpacity(0.3),
                      ),
                      child: const Text("🎯 Let's Go"),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
