import 'package:flutter/material.dart';
import '../../utils/username_generator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';

class UsernameScreen extends StatefulWidget {
  const UsernameScreen({super.key});

  @override
  State<UsernameScreen> createState() => _UsernameScreenState();
}

class _UsernameScreenState extends State<UsernameScreen> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final FocusNode _firstNameFocusNode = FocusNode();
  final FocusNode _lastNameFocusNode = FocusNode();
  bool _isChecking = false;
  bool _isGenerating = false;

  String? _selectedCountry;
  String? _selectedProvince;
  String? _selectedCity;
  String? _selectedGender;

  final List<String> _countries = ['Canada', 'USA'];
  final Map<String, List<String>> _provinceCityMap = {
    'Ontario': ['Toronto', 'Ottawa', 'Mississauga', 'Hamilton', 'London'],
    'British Columbia': ['Vancouver', 'Victoria', 'Surrey', 'Kelowna'],
    'Alberta': ['Calgary', 'Edmonton', 'Red Deer'],
    'Quebec': ['Montreal', 'Quebec City', 'Laval'],
  };
  final List<String> _genders = ['Male', 'Female', 'Prefer not to answer'];

  // Static cache for form state
  static Map<String, dynamic>? _cachedForm;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      if (args != null) {
        _usernameController.text = args['username'] ?? _cachedForm?['username'] ?? '';
        _firstNameController.text = args['firstName'] ?? _cachedForm?['firstName'] ?? '';
        _lastNameController.text = args['lastName'] ?? _cachedForm?['lastName'] ?? '';
        setState(() {
          _selectedCountry = args['country'] ?? _cachedForm?['country'];
          _selectedProvince = args['province'] ?? _cachedForm?['province'];
          _selectedCity = args['city'] ?? _cachedForm?['city'];
          _selectedGender = args['gender'] ?? _cachedForm?['gender'];
        });
      } else if (_cachedForm != null) {
        _usernameController.text = _cachedForm?['username'] ?? '';
        _firstNameController.text = _cachedForm?['firstName'] ?? '';
        _lastNameController.text = _cachedForm?['lastName'] ?? '';
        setState(() {
          _selectedCountry = _cachedForm?['country'];
          _selectedProvince = _cachedForm?['province'];
          _selectedCity = _cachedForm?['city'];
          _selectedGender = _cachedForm?['gender'];
        });
      }
    });
  }

  void _cacheForm() {
    _cachedForm = {
      'username': _usernameController.text,
      'firstName': _firstNameController.text,
      'lastName': _lastNameController.text,
      'country': _selectedCountry,
      'province': _selectedProvince,
      'city': _selectedCity,
      'gender': _selectedGender,
    };
  }

  void _generateUsername() async {
    setState(() => _isGenerating = true);

    for (int i = 0; i < 5; i++) {
      final suggestion = await generateUsername();
      final doc = await FirebaseFirestore.instance
          .collection('usernames')
          .doc(suggestion)
          .get();
      if (!doc.exists) {
        setState(() {
          _usernameController.text = suggestion;
          _isGenerating = false;
        });
        return;
      }
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Could not generate a unique username. Try again.')),
    );

    setState(() => _isGenerating = false);
  }

  Future<void> _proceedToRegister() async {
    final username = _usernameController.text.trim();
    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();
    final args = GoRouterState.of(context).extra as Map<String, dynamic>?;

    if (username.isEmpty ||
        firstName.isEmpty ||
        lastName.isEmpty ||
        _selectedCountry == null ||
        _selectedProvince == null ||
        _selectedCity == null ||
        _selectedGender == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in all required fields.', style: TextStyle(color: Colors.white)),
        ),
      );
      return;
    }

    setState(() => _isChecking = true);

    try {
      final doc = await FirebaseFirestore.instance
          .collection('usernames')
          .doc(username)
          .get();

      if (doc.exists) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Username is already taken.')),
        );
        setState(() => _isChecking = false);
        return;
      }

      // Klasik kayıt akışı (email/password ile):
      context.push('/register', extra: {
        'username': username,
        'firstName': firstName,
        'lastName': lastName, // Required now, no null check needed
        'country': _selectedCountry,
        'province': _selectedProvince,
        'city': _selectedCity,
        'gender': _selectedGender,
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Something went wrong. Please try again.')),
      );
    }

    setState(() => _isChecking = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F2FA),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.deepPurple),
          onPressed: () => context.pop(),
          tooltip: 'Back',
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.only(left: 20.0, right: 20.0, top: 0.0, bottom: 0.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Text(
                'MentorBridge',
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                  color: Colors.deepPurple.shade700,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 2),
              const Text(
                'Create your account',
                style: TextStyle(
                  fontSize: 20,
                  color: Colors.black54,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 10),
              Card(
                elevation: 6,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: _usernameController,
                        textInputAction: TextInputAction.next,
                        onSubmitted: (_) {
                          FocusScope.of(context)
                              .requestFocus(_firstNameFocusNode);
                        },
                        decoration: InputDecoration(
                          labelText: 'Username *',
                          prefixIcon: const Icon(Icons.person_outline),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          filled: true,
                          fillColor: Colors.grey[100],
                          suffixIcon: _isGenerating
                              ? const Padding(
                                  padding: EdgeInsets.all(10),
                                  child: SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  ),
                                )
                              : IconButton(
                                  icon: const Icon(Icons.refresh),
                                  onPressed: _generateUsername,
                                ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _firstNameController,
                        focusNode: _firstNameFocusNode,
                        textInputAction: TextInputAction.next,
                        onSubmitted: (_) {
                          FocusScope.of(context)
                              .requestFocus(_lastNameFocusNode);
                        },
                        decoration: InputDecoration(
                          labelText: 'First Name *',
                          prefixIcon: const Icon(Icons.badge_outlined),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          filled: true,
                          fillColor: Colors.grey[100],
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _lastNameController,
                        focusNode: _lastNameFocusNode,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) {
                          FocusScope.of(context).unfocus();
                        },
                        decoration: InputDecoration(
                          labelText: 'Last Name *',
                          prefixIcon: const Icon(Icons.badge_outlined),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          filled: true,
                          fillColor: Colors.grey[100],
                        ),
                      ),
                      const SizedBox(height: 18),
                      DropdownButtonFormField<String>(
                        value: _selectedGender,
                        decoration: InputDecoration(
                          labelText: 'Gender *',
                          prefixIcon: const Icon(Icons.wc),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          filled: true,
                          fillColor: Colors.grey[100],
                        ),
                        items: _genders
                            .map((gender) => DropdownMenuItem(value: gender, child: Text(gender)))
                            .toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedGender = value;
                          });
                        },
                      ),
                      const SizedBox(height: 18),
                      DropdownButtonFormField<String>(
                        value: _selectedCountry,
                        decoration: InputDecoration(
                          labelText: 'Country *',
                          prefixIcon: const Icon(Icons.public),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          filled: true,
                          fillColor: Colors.grey[100],
                        ),
                        items: _countries
                            .map((country) => DropdownMenuItem(value: country, child: Text(country)))
                            .toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedCountry = value;
                            _selectedProvince = null;
                            _selectedCity = null;
                          });
                        },
                      ),
                      const SizedBox(height: 18),
                      DropdownButtonFormField<String>(
                        value: _selectedProvince,
                        decoration: InputDecoration(
                          labelText: 'Province *',
                          prefixIcon: const Icon(Icons.map_outlined),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          filled: true,
                          fillColor: Colors.grey[100],
                        ),
                        items: _selectedCountry == null
                            ? []
                            : _provinceCityMap.keys
                                .map((province) => DropdownMenuItem(value: province, child: Text(province)))
                                .toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedProvince = value;
                            _selectedCity = null;
                          });
                        },
                      ),
                      const SizedBox(height: 18),
                      DropdownButtonFormField<String>(
                        value: _selectedCity,
                        decoration: InputDecoration(
                          labelText: 'City *',
                          prefixIcon: const Icon(Icons.location_city_outlined),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          filled: true,
                          fillColor: Colors.grey[100],
                        ),
                        items: _selectedProvince == null
                            ? []
                            : (_provinceCityMap[_selectedProvince] ?? [])
                                .map((city) => DropdownMenuItem(value: city, child: Text(city)))
                                .toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedCity = value;
                          });
                        },
                      ),
                      const SizedBox(height: 28),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: _isChecking ? null : _proceedToRegister,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.deepPurple,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          child: _isChecking
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    color: Color.fromARGB(255, 255, 255, 255),
                                    strokeWidth: 0,
                                  ),
                                )
                              : const Text('Continue', style: TextStyle(color: Colors.white)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _firstNameFocusNode.dispose();
    _lastNameFocusNode.dispose();
    super.dispose();
  }
}
