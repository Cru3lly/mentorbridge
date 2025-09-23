import 'package:flutter/material.dart';
import '../../services/location_service.dart';

/// Location dropdown cascade widget (Country → Province → City)
class LocationDropdownCascade extends StatefulWidget {
  final Function(Map<String, dynamic>?) onLocationSelected;
  final Map<String, dynamic>? initialLocation;
  final bool enabled;

  const LocationDropdownCascade({
    super.key,
    required this.onLocationSelected,
    this.initialLocation,
    this.enabled = true,
  });

  @override
  State<LocationDropdownCascade> createState() =>
      _LocationDropdownCascadeState();
}

class _LocationDropdownCascadeState extends State<LocationDropdownCascade> {
  // Data lists
  List<Map<String, dynamic>> _countries = [];
  List<Map<String, dynamic>> _provinces = [];
  List<Map<String, dynamic>> _cities = [];

  // Selected values
  Map<String, dynamic>? _selectedCountry;
  Map<String, dynamic>? _selectedProvince;
  Map<String, dynamic>? _selectedCity;

  // Loading states
  bool _isLoadingCountries = true;
  bool _isLoadingProvinces = false;
  bool _isLoadingCities = false;

  @override
  void initState() {
    super.initState();
    _loadCountries();
  }

  Future<void> _loadCountries() async {
    setState(() {
      _isLoadingCountries = true;
    });

    try {
      final countries = await LocationService.getCountries();
      if (mounted) {
        setState(() {
          _countries = countries;
          _isLoadingCountries = false;
        });

        // Set initial country if provided
        if (widget.initialLocation != null) {
          final countryName = widget.initialLocation!['country'];
          if (countryName != null) {
            _selectedCountry = _countries.firstWhere(
              (country) => country['name'] == countryName,
              orElse: () => {},
            );
            if (_selectedCountry!.isNotEmpty) {
              _loadProvinces(_selectedCountry!['code']);
            }
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingCountries = false;
        });
      }
    }
  }

  Future<void> _loadProvinces(String countryCode) async {
    setState(() {
      _isLoadingProvinces = true;
      _provinces = [];
      _cities = [];
      _selectedProvince = null;
      _selectedCity = null;
    });

    try {
      final provinces = await LocationService.getProvinces(countryCode);
      if (mounted) {
        setState(() {
          _provinces = provinces;
          _isLoadingProvinces = false;
        });

        // Set initial province if provided
        if (widget.initialLocation != null) {
          final provinceName = widget.initialLocation!['province'];
          if (provinceName != null) {
            _selectedProvince = _provinces.firstWhere(
              (province) => province['name'] == provinceName,
              orElse: () => {},
            );
            if (_selectedProvince!.isNotEmpty) {
              _loadCities(_selectedProvince!['code']);
            }
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingProvinces = false;
        });
      }
    }
  }

  Future<void> _loadCities(String provinceCode) async {
    setState(() {
      _isLoadingCities = true;
      _cities = [];
      _selectedCity = null;
    });

    try {
      final cities = await LocationService.getCities(
        provinceCode, // Use the passed province code
      );
      if (mounted) {
        setState(() {
          _cities = cities;
          _isLoadingCities = false;
        });

        // Set initial city if provided
        if (widget.initialLocation != null) {
          final cityName = widget.initialLocation!['city'];
          if (cityName != null) {
            _selectedCity = _cities.firstWhere(
              (city) => city['name'] == cityName,
              orElse: () => {},
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingCities = false;
        });
      }
    }
  }

  void _onCountryChanged(Map<String, dynamic>? country) {
    setState(() {
      _selectedCountry = country;
      _selectedProvince = null;
      _selectedCity = null;
      _provinces = [];
      _cities = [];
    });

    if (country != null) {
      _loadProvinces(country['code']);
    }

    _updateLocationData();
  }

  void _onProvinceChanged(Map<String, dynamic>? province) {
    setState(() {
      _selectedProvince = province;
      _selectedCity = null;
      _cities = [];
    });

    if (province != null) {
      _loadCities(province['code']);
    }

    _updateLocationData();
  }

  void _onCityChanged(Map<String, dynamic>? city) {
    setState(() {
      _selectedCity = city;
    });

    _updateLocationData();
  }

  void _updateLocationData() {
    if (_selectedCountry == null) {
      widget.onLocationSelected(null);
      return;
    }

    final locationData = {
      'country': _selectedCountry!['name'],
      'countryCode': _selectedCountry!['code'],
    };

    if (_selectedProvince != null) {
      locationData['province'] = _selectedProvince!['name'];
      locationData['provincePlaceId'] = _selectedProvince!['placeId'];
    }

    if (_selectedCity != null) {
      locationData['city'] = _selectedCity!['name'];
      locationData['cityPlaceId'] = _selectedCity!['placeId'];
      locationData['formattedAddress'] = _selectedCity!['formattedAddress'];
    }

    widget.onLocationSelected(locationData);
  }

  Widget _buildDropdown<T>({
    required String label,
    required IconData icon,
    required T? value,
    required List<T> items,
    required String Function(T) getDisplayText,
    required void Function(T?) onChanged,
    bool isLoading = false,
    String? hint,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF3A3D4A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF4A4D5A), width: 1),
      ),
      child: DropdownButtonFormField<T>(
        value: value,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.grey[400]),
          prefixIcon: isLoading
              ? const Padding(
                  padding: EdgeInsets.all(12.0),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white70),
                    ),
                  ),
                )
              : Icon(icon, color: Colors.grey[400], size: 20),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
        hint: Text(
          hint ?? 'Select $label',
          style: TextStyle(color: Colors.grey[400]),
        ),
        dropdownColor: const Color(0xFF3A3D4A),
        style: const TextStyle(color: Colors.white),
        items: items.map((item) {
          return DropdownMenuItem<T>(
            value: item,
            child: Text(
              getDisplayText(item),
              style: const TextStyle(color: Colors.white),
            ),
          );
        }).toList(),
        onChanged: widget.enabled && !isLoading ? onChanged : null,
        menuMaxHeight: 300,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Country Dropdown
        _buildDropdown<Map<String, dynamic>>(
          label: 'Country',
          icon: Icons.public,
          value: _selectedCountry,
          items: _countries,
          getDisplayText: (country) => country['name'] as String,
          onChanged: _onCountryChanged,
          isLoading: _isLoadingCountries,
        ),

        // Province Dropdown - Only show if country is selected
        if (_selectedCountry != null) ...[
          const SizedBox(height: 16),
          _buildDropdown<Map<String, dynamic>>(
            label: 'Province/State',
            icon: Icons.map,
            value: _selectedProvince,
            items: _provinces,
            getDisplayText: (province) => province['name'] as String,
            onChanged: _onProvinceChanged,
            isLoading: _isLoadingProvinces,
            hint: 'Select province',
          ),
        ],

        // City Dropdown - Only show if province is selected
        if (_selectedProvince != null) ...[
          const SizedBox(height: 16),
          _buildDropdown<Map<String, dynamic>>(
            label: 'City',
            icon: Icons.location_city,
            value: _selectedCity,
            items: _cities,
            getDisplayText: (city) => city['name'] as String,
            onChanged: _onCityChanged,
            isLoading: _isLoadingCities,
            hint: 'Select city',
          ),
        ],
      ],
    );
  }
}
