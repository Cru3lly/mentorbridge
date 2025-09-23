import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';

class ProfileSetup extends StatefulWidget {
  const ProfileSetup({super.key});

  @override
  State<ProfileSetup> createState() => _ProfileSetupState();
}

class _ProfileSetupState extends State<ProfileSetup> {
  String? _country;
  String? _selectedProvince;
  String? _selectedCity;
  String? _selectedGender;
  bool _isSaving = false;

  final Map<String, List<String>> _provinceCityMap = {
    'Ontario': ['Toronto', 'Ottawa', 'Mississauga', 'Hamilton', 'London'],
    'British Columbia': ['Vancouver', 'Victoria', 'Surrey', 'Kelowna'],
    'Alberta': ['Calgary', 'Edmonton', 'Red Deer'],
    'Quebec': ['Montreal', 'Quebec City', 'Laval'],
  };

  final List<String> _genders = ['Male', 'Female', 'Prefer not to answer'];

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    if (doc.exists) {
      final data = doc.data()!;
      _country = data['country'] ?? '';
      _selectedProvince = data['province'];
      _selectedCity = data['city'];
      _selectedGender = data['gender'];
    }

    setState(() {});
  }

  Future<void> _saveProfile() async {
    if (_selectedProvince == null || _selectedCity == null || _selectedGender == null || _country == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all fields.')),
      );
      return;
    }

    setState(() => _isSaving = true);
    final uid = FirebaseAuth.instance.currentUser!.uid;

    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'country': _country,
        'province': _selectedProvince,
        'city': _selectedCity,
        'gender': _selectedGender,
      });
      context.go('/authGate');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Something went wrong. Please try again.')),
      );
    }

    setState(() => _isSaving = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Set Up Profile')),
      body: _isSaving
          ? const Center(child: CircularProgressIndicator())
          : Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Complete your profile information',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            DropdownButtonFormField<String>(
              value: _country,
              items: ['Canada', 'USA']
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: (value) {
                setState(() {
                  _country = value;
                });
              },
              decoration: const InputDecoration(labelText: 'Country'),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedProvince,
              items: _provinceCityMap.keys.map((prov) {
                return DropdownMenuItem(value: prov, child: Text(prov));
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedProvince = value;
                  _selectedCity = null;
                });
              },
              decoration:
              const InputDecoration(labelText: 'Province'),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedCity,
              items:
              (_provinceCityMap[_selectedProvince] ?? []).map((city) {
                return DropdownMenuItem(value: city, child: Text(city));
              }).toList(),
              onChanged: (value) {
                setState(() => _selectedCity = value);
              },
              decoration: const InputDecoration(labelText: 'City'),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Gender *', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 16)),
              ),
            ),
            Row(
              children: _genders.map((gender) => Expanded(
                child: RadioListTile<String>(
                  title: Text(gender, style: const TextStyle(fontSize: 14)),
                  value: gender,
                  groupValue: _selectedGender,
                  onChanged: (value) {
                    setState(() {
                      _selectedGender = value;
                    });
                  },
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              )).toList(),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _saveProfile,
              child: const Text('Complete'),
            ),
          ],
        ),
      ),
    );
  }
}
