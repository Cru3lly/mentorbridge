import '../data/province_data.dart';

/// Location service for dropdown cascade location system
/// Uses completely hardcoded data for countries, provinces, and cities
class LocationService {
  /// Get list of countries from hardcoded data (fast and reliable)
  static Future<List<Map<String, dynamic>>> getCountries() async {
    try {
      print('🌍 Getting countries from hardcoded data');

      // Hardcoded major countries list
      final countries = [
        {'name': 'Australia', 'code': 'AU'},
        {'name': 'Austria', 'code': 'AT'},
        {'name': 'Belgium', 'code': 'BE'},
        {'name': 'Brazil', 'code': 'BR'},
        {'name': 'Canada', 'code': 'CA'},
        {'name': 'China', 'code': 'CN'},
        {'name': 'Denmark', 'code': 'DK'},
        {'name': 'Egypt', 'code': 'EG'},
        {'name': 'Finland', 'code': 'FI'},
        {'name': 'France', 'code': 'FR'},
        {'name': 'Germany', 'code': 'DE'},
        {'name': 'Greece', 'code': 'GR'},
        {'name': 'India', 'code': 'IN'},
        {'name': 'Indonesia', 'code': 'ID'},
        {'name': 'Italy', 'code': 'IT'},
        {'name': 'Japan', 'code': 'JP'},
        {'name': 'Malaysia', 'code': 'MY'},
        {'name': 'Mexico', 'code': 'MX'},
        {'name': 'Netherlands', 'code': 'NL'},
        {'name': 'New Zealand', 'code': 'NZ'},
        {'name': 'Norway', 'code': 'NO'},
        {'name': 'Poland', 'code': 'PL'},
        {'name': 'Portugal', 'code': 'PT'},
        {'name': 'Russia', 'code': 'RU'},
        {'name': 'Saudi Arabia', 'code': 'SA'},
        {'name': 'South Africa', 'code': 'ZA'},
        {'name': 'South Korea', 'code': 'KR'},
        {'name': 'Spain', 'code': 'ES'},
        {'name': 'Sweden', 'code': 'SE'},
        {'name': 'Switzerland', 'code': 'CH'},
        {'name': 'Thailand', 'code': 'TH'},
        {'name': 'Turkey', 'code': 'TR'},
        {'name': 'Ukraine', 'code': 'UA'},
        {'name': 'United Arab Emirates', 'code': 'AE'},
        {'name': 'United Kingdom', 'code': 'GB'},
        {'name': 'United States', 'code': 'US'},
        {'name': 'Vietnam', 'code': 'VN'},
      ];

      print('✅ Loaded ${countries.length} countries from hardcoded data');
      return countries;
    } catch (e) {
      print('❌ Error getting countries: $e');
      return [];
    }
  }

  /// Get provinces/states for a country using hardcoded data (fast and reliable)
  static Future<List<Map<String, dynamic>>> getProvinces(
      String countryCode) async {
    try {
      print('🗺️ Getting provinces for $countryCode from hardcoded data');

      // Get provinces from hardcoded data
      final provinces = ProvinceData.getProvinces(countryCode);

      // Convert to Map format for compatibility
      final List<Map<String, dynamic>> provinceList = provinces
          .map((province) => {
                'name': province.name,
                'code': province.code,
                'countryCode': province.countryCode,
              })
          .toList();

      print('✅ Loaded ${provinceList.length} provinces for $countryCode');
      return provinceList;
    } catch (e) {
      print('❌ Error getting provinces: $e');
      return [];
    }
  }

  /// Get cities for a province using hardcoded data (fast and reliable)
  static Future<List<Map<String, dynamic>>> getCities(
      String provinceCode) async {
    try {
      print('🏙️ Getting cities for $provinceCode from hardcoded data');

      // Get cities from hardcoded data
      final cities = ProvinceData.getCities(provinceCode);

      // Convert to Map format for compatibility
      final List<Map<String, dynamic>> cityList = cities
          .map((city) => {
                'name': city.name,
                'provinceCode': city.provinceCode,
                'countryCode': city.countryCode,
              })
          .toList();

      print('✅ Loaded ${cityList.length} cities for $provinceCode');
      return cityList;
    } catch (e) {
      print('❌ Error getting cities: $e');
      return [];
    }
  }
}