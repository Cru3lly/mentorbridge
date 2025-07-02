import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';

class HomeGoalSetup extends StatefulWidget {
  const HomeGoalSetup({super.key});

  @override
  State<HomeGoalSetup> createState() => _HomeGoalSetupState();
}

class _HomeGoalSetupState extends State<HomeGoalSetup> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _quranController = TextEditingController();
  final TextEditingController _prayerController = TextEditingController();
  final TextEditingController _dhikrController = TextEditingController();
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadGoals();
  }

  Future<void> _loadGoals() async {
    setState(() => _loading = true);
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final goalData = userDoc.data()?['goalData'] as Map<String, dynamic>?;
    if (goalData != null) {
      _quranController.text = goalData['quran']?.toString() ?? '';
      _prayerController.text = goalData['prayer']?.toString() ?? '';
      _dhikrController.text = goalData['dhikr']?.toString() ?? '';
    }
    setState(() => _loading = false);
  }

  Future<void> _saveGoals() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final goalData = {
      'quran': int.tryParse(_quranController.text) ?? 0,
      'prayer': int.tryParse(_prayerController.text) ?? 0,
      'dhikr': int.tryParse(_dhikrController.text) ?? 0,
    };
    await FirebaseFirestore.instance.collection('users').doc(uid).update({
      'goalData': goalData,
    });
    setState(() => _loading = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Goals updated!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Set Your Weekly Goals'),
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Please set your weekly goals:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _quranController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Quran (pages/verses)',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _prayerController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Prayer (count)',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _dhikrController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Dhikr (count)',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 32),
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: _loading ? null : _saveGoals,
                  child: _loading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Save & Continue', style: TextStyle(fontSize: 18)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
} 