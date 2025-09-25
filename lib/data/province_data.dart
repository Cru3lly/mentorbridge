/// Province data for major countries
/// This file contains hardcoded province/state data for reliable dropdown functionality
library;

class Province {
  final String name;
  final String code;
  final String countryCode;

  const Province({
    required this.name,
    required this.code,
    required this.countryCode,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'code': code,
      'countryCode': countryCode,
    };
  }
}

class City {
  final String name;
  final String provinceCode;
  final String countryCode;

  const City({
    required this.name,
    required this.provinceCode,
    required this.countryCode,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'provinceCode': provinceCode,
      'countryCode': countryCode,
    };
  }
}

class ProvinceData {
  /// Get provinces for a specific country code
  static List<Province> getProvinces(String countryCode) {
    return _provinces[countryCode] ?? [];
  }

  /// Check if a country has provinces
  static bool hasProvinces(String countryCode) {
    return _provinces.containsKey(countryCode) &&
        _provinces[countryCode]!.isNotEmpty;
  }

  /// Get all supported country codes
  static List<String> getSupportedCountries() {
    return _provinces.keys.toList();
  }

  /// Get cities for a specific province code
  static List<City> getCities(String provinceCode) {
    return _provinceCities[provinceCode] ?? [];
  }

  /// Check if a province has cities
  static bool hasCities(String provinceCode) {
    return _provinceCities.containsKey(provinceCode) &&
        _provinceCities[provinceCode]!.isNotEmpty;
  }

  /// Hardcoded province data for major countries
  static const Map<String, List<Province>> _provinces = {
    // Turkey - 81 Provinces
    'TR': [
      Province(name: 'Adana', code: 'TR-01', countryCode: 'TR'),
      Province(name: 'Adıyaman', code: 'TR-02', countryCode: 'TR'),
      Province(name: 'Afyonkarahisar', code: 'TR-03', countryCode: 'TR'),
      Province(name: 'Ağrı', code: 'TR-04', countryCode: 'TR'),
      Province(name: 'Amasya', code: 'TR-05', countryCode: 'TR'),
      Province(name: 'Ankara', code: 'TR-06', countryCode: 'TR'),
      Province(name: 'Antalya', code: 'TR-07', countryCode: 'TR'),
      Province(name: 'Artvin', code: 'TR-08', countryCode: 'TR'),
      Province(name: 'Aydın', code: 'TR-09', countryCode: 'TR'),
      Province(name: 'Balıkesir', code: 'TR-10', countryCode: 'TR'),
      Province(name: 'Bilecik', code: 'TR-11', countryCode: 'TR'),
      Province(name: 'Bingöl', code: 'TR-12', countryCode: 'TR'),
      Province(name: 'Bitlis', code: 'TR-13', countryCode: 'TR'),
      Province(name: 'Bolu', code: 'TR-14', countryCode: 'TR'),
      Province(name: 'Burdur', code: 'TR-15', countryCode: 'TR'),
      Province(name: 'Bursa', code: 'TR-16', countryCode: 'TR'),
      Province(name: 'Çanakkale', code: 'TR-17', countryCode: 'TR'),
      Province(name: 'Çankırı', code: 'TR-18', countryCode: 'TR'),
      Province(name: 'Çorum', code: 'TR-19', countryCode: 'TR'),
      Province(name: 'Denizli', code: 'TR-20', countryCode: 'TR'),
      Province(name: 'Diyarbakır', code: 'TR-21', countryCode: 'TR'),
      Province(name: 'Edirne', code: 'TR-22', countryCode: 'TR'),
      Province(name: 'Elazığ', code: 'TR-23', countryCode: 'TR'),
      Province(name: 'Erzincan', code: 'TR-24', countryCode: 'TR'),
      Province(name: 'Erzurum', code: 'TR-25', countryCode: 'TR'),
      Province(name: 'Eskişehir', code: 'TR-26', countryCode: 'TR'),
      Province(name: 'Gaziantep', code: 'TR-27', countryCode: 'TR'),
      Province(name: 'Giresun', code: 'TR-28', countryCode: 'TR'),
      Province(name: 'Gümüşhane', code: 'TR-29', countryCode: 'TR'),
      Province(name: 'Hakkâri', code: 'TR-30', countryCode: 'TR'),
      Province(name: 'Hatay', code: 'TR-31', countryCode: 'TR'),
      Province(name: 'Isparta', code: 'TR-32', countryCode: 'TR'),
      Province(name: 'Mersin', code: 'TR-33', countryCode: 'TR'),
      Province(name: 'İstanbul', code: 'TR-34', countryCode: 'TR'),
      Province(name: 'İzmir', code: 'TR-35', countryCode: 'TR'),
      Province(name: 'Kars', code: 'TR-36', countryCode: 'TR'),
      Province(name: 'Kastamonu', code: 'TR-37', countryCode: 'TR'),
      Province(name: 'Kayseri', code: 'TR-38', countryCode: 'TR'),
      Province(name: 'Kırklareli', code: 'TR-39', countryCode: 'TR'),
      Province(name: 'Kırşehir', code: 'TR-40', countryCode: 'TR'),
      Province(name: 'Kocaeli', code: 'TR-41', countryCode: 'TR'),
      Province(name: 'Konya', code: 'TR-42', countryCode: 'TR'),
      Province(name: 'Kütahya', code: 'TR-43', countryCode: 'TR'),
      Province(name: 'Malatya', code: 'TR-44', countryCode: 'TR'),
      Province(name: 'Manisa', code: 'TR-45', countryCode: 'TR'),
      Province(name: 'Kahramanmaraş', code: 'TR-46', countryCode: 'TR'),
      Province(name: 'Mardin', code: 'TR-47', countryCode: 'TR'),
      Province(name: 'Muğla', code: 'TR-48', countryCode: 'TR'),
      Province(name: 'Muş', code: 'TR-49', countryCode: 'TR'),
      Province(name: 'Nevşehir', code: 'TR-50', countryCode: 'TR'),
      Province(name: 'Niğde', code: 'TR-51', countryCode: 'TR'),
      Province(name: 'Ordu', code: 'TR-52', countryCode: 'TR'),
      Province(name: 'Rize', code: 'TR-53', countryCode: 'TR'),
      Province(name: 'Sakarya', code: 'TR-54', countryCode: 'TR'),
      Province(name: 'Samsun', code: 'TR-55', countryCode: 'TR'),
      Province(name: 'Siirt', code: 'TR-56', countryCode: 'TR'),
      Province(name: 'Sinop', code: 'TR-57', countryCode: 'TR'),
      Province(name: 'Sivas', code: 'TR-58', countryCode: 'TR'),
      Province(name: 'Tekirdağ', code: 'TR-59', countryCode: 'TR'),
      Province(name: 'Tokat', code: 'TR-60', countryCode: 'TR'),
      Province(name: 'Trabzon', code: 'TR-61', countryCode: 'TR'),
      Province(name: 'Tunceli', code: 'TR-62', countryCode: 'TR'),
      Province(name: 'Şanlıurfa', code: 'TR-63', countryCode: 'TR'),
      Province(name: 'Uşak', code: 'TR-64', countryCode: 'TR'),
      Province(name: 'Van', code: 'TR-65', countryCode: 'TR'),
      Province(name: 'Yozgat', code: 'TR-66', countryCode: 'TR'),
      Province(name: 'Zonguldak', code: 'TR-67', countryCode: 'TR'),
      Province(name: 'Aksaray', code: 'TR-68', countryCode: 'TR'),
      Province(name: 'Bayburt', code: 'TR-69', countryCode: 'TR'),
      Province(name: 'Karaman', code: 'TR-70', countryCode: 'TR'),
      Province(name: 'Kırıkkale', code: 'TR-71', countryCode: 'TR'),
      Province(name: 'Batman', code: 'TR-72', countryCode: 'TR'),
      Province(name: 'Şırnak', code: 'TR-73', countryCode: 'TR'),
      Province(name: 'Bartın', code: 'TR-74', countryCode: 'TR'),
      Province(name: 'Ardahan', code: 'TR-75', countryCode: 'TR'),
      Province(name: 'Iğdır', code: 'TR-76', countryCode: 'TR'),
      Province(name: 'Yalova', code: 'TR-77', countryCode: 'TR'),
      Province(name: 'Karabük', code: 'TR-78', countryCode: 'TR'),
      Province(name: 'Kilis', code: 'TR-79', countryCode: 'TR'),
      Province(name: 'Osmaniye', code: 'TR-80', countryCode: 'TR'),
      Province(name: 'Düzce', code: 'TR-81', countryCode: 'TR'),
    ],

    // United States - 50 States
    'US': [
      Province(name: 'Alabama', code: 'US-AL', countryCode: 'US'),
      Province(name: 'Alaska', code: 'US-AK', countryCode: 'US'),
      Province(name: 'Arizona', code: 'US-AZ', countryCode: 'US'),
      Province(name: 'Arkansas', code: 'US-AR', countryCode: 'US'),
      Province(name: 'California', code: 'US-CA', countryCode: 'US'),
      Province(name: 'Colorado', code: 'US-CO', countryCode: 'US'),
      Province(name: 'Connecticut', code: 'US-CT', countryCode: 'US'),
      Province(name: 'Delaware', code: 'US-DE', countryCode: 'US'),
      Province(name: 'Florida', code: 'US-FL', countryCode: 'US'),
      Province(name: 'Georgia', code: 'US-GA', countryCode: 'US'),
      Province(name: 'Hawaii', code: 'US-HI', countryCode: 'US'),
      Province(name: 'Idaho', code: 'US-ID', countryCode: 'US'),
      Province(name: 'Illinois', code: 'US-IL', countryCode: 'US'),
      Province(name: 'Indiana', code: 'US-IN', countryCode: 'US'),
      Province(name: 'Iowa', code: 'US-IA', countryCode: 'US'),
      Province(name: 'Kansas', code: 'US-KS', countryCode: 'US'),
      Province(name: 'Kentucky', code: 'US-KY', countryCode: 'US'),
      Province(name: 'Louisiana', code: 'US-LA', countryCode: 'US'),
      Province(name: 'Maine', code: 'US-ME', countryCode: 'US'),
      Province(name: 'Maryland', code: 'US-MD', countryCode: 'US'),
      Province(name: 'Massachusetts', code: 'US-MA', countryCode: 'US'),
      Province(name: 'Michigan', code: 'US-MI', countryCode: 'US'),
      Province(name: 'Minnesota', code: 'US-MN', countryCode: 'US'),
      Province(name: 'Mississippi', code: 'US-MS', countryCode: 'US'),
      Province(name: 'Missouri', code: 'US-MO', countryCode: 'US'),
      Province(name: 'Montana', code: 'US-MT', countryCode: 'US'),
      Province(name: 'Nebraska', code: 'US-NE', countryCode: 'US'),
      Province(name: 'Nevada', code: 'US-NV', countryCode: 'US'),
      Province(name: 'New Hampshire', code: 'US-NH', countryCode: 'US'),
      Province(name: 'New Jersey', code: 'US-NJ', countryCode: 'US'),
      Province(name: 'New Mexico', code: 'US-NM', countryCode: 'US'),
      Province(name: 'New York', code: 'US-NY', countryCode: 'US'),
      Province(name: 'North Carolina', code: 'US-NC', countryCode: 'US'),
      Province(name: 'North Dakota', code: 'US-ND', countryCode: 'US'),
      Province(name: 'Ohio', code: 'US-OH', countryCode: 'US'),
      Province(name: 'Oklahoma', code: 'US-OK', countryCode: 'US'),
      Province(name: 'Oregon', code: 'US-OR', countryCode: 'US'),
      Province(name: 'Pennsylvania', code: 'US-PA', countryCode: 'US'),
      Province(name: 'Rhode Island', code: 'US-RI', countryCode: 'US'),
      Province(name: 'South Carolina', code: 'US-SC', countryCode: 'US'),
      Province(name: 'South Dakota', code: 'US-SD', countryCode: 'US'),
      Province(name: 'Tennessee', code: 'US-TN', countryCode: 'US'),
      Province(name: 'Texas', code: 'US-TX', countryCode: 'US'),
      Province(name: 'Utah', code: 'US-UT', countryCode: 'US'),
      Province(name: 'Vermont', code: 'US-VT', countryCode: 'US'),
      Province(name: 'Virginia', code: 'US-VA', countryCode: 'US'),
      Province(name: 'Washington', code: 'US-WA', countryCode: 'US'),
      Province(name: 'West Virginia', code: 'US-WV', countryCode: 'US'),
      Province(name: 'Wisconsin', code: 'US-WI', countryCode: 'US'),
      Province(name: 'Wyoming', code: 'US-WY', countryCode: 'US'),
    ],

    // Canada - 13 Provinces and Territories
    'CA': [
      Province(name: 'Alberta', code: 'CA-AB', countryCode: 'CA'),
      Province(name: 'British Columbia', code: 'CA-BC', countryCode: 'CA'),
      Province(name: 'Manitoba', code: 'CA-MB', countryCode: 'CA'),
      Province(name: 'New Brunswick', code: 'CA-NB', countryCode: 'CA'),
      Province(
          name: 'Newfoundland and Labrador', code: 'CA-NL', countryCode: 'CA'),
      Province(name: 'Northwest Territories', code: 'CA-NT', countryCode: 'CA'),
      Province(name: 'Nova Scotia', code: 'CA-NS', countryCode: 'CA'),
      Province(name: 'Nunavut', code: 'CA-NU', countryCode: 'CA'),
      Province(name: 'Ontario', code: 'CA-ON', countryCode: 'CA'),
      Province(name: 'Prince Edward Island', code: 'CA-PE', countryCode: 'CA'),
      Province(name: 'Quebec', code: 'CA-QC', countryCode: 'CA'),
      Province(name: 'Saskatchewan', code: 'CA-SK', countryCode: 'CA'),
      Province(name: 'Yukon', code: 'CA-YT', countryCode: 'CA'),
    ],

    // Germany - 16 States
    'DE': [
      Province(name: 'Baden-Württemberg', code: 'DE-BW', countryCode: 'DE'),
      Province(name: 'Bavaria', code: 'DE-BY', countryCode: 'DE'),
      Province(name: 'Berlin', code: 'DE-BE', countryCode: 'DE'),
      Province(name: 'Brandenburg', code: 'DE-BB', countryCode: 'DE'),
      Province(name: 'Bremen', code: 'DE-HB', countryCode: 'DE'),
      Province(name: 'Hamburg', code: 'DE-HH', countryCode: 'DE'),
      Province(name: 'Hesse', code: 'DE-HE', countryCode: 'DE'),
      Province(name: 'Lower Saxony', code: 'DE-NI', countryCode: 'DE'),
      Province(
          name: 'Mecklenburg-Vorpommern', code: 'DE-MV', countryCode: 'DE'),
      Province(
          name: 'North Rhine-Westphalia', code: 'DE-NW', countryCode: 'DE'),
      Province(name: 'Rhineland-Palatinate', code: 'DE-RP', countryCode: 'DE'),
      Province(name: 'Saarland', code: 'DE-SL', countryCode: 'DE'),
      Province(name: 'Saxony', code: 'DE-SN', countryCode: 'DE'),
      Province(name: 'Saxony-Anhalt', code: 'DE-ST', countryCode: 'DE'),
      Province(name: 'Schleswig-Holstein', code: 'DE-SH', countryCode: 'DE'),
      Province(name: 'Thuringia', code: 'DE-TH', countryCode: 'DE'),
    ],

    // Australia - 8 States and Territories
    'AU': [
      Province(
          name: 'Australian Capital Territory',
          code: 'AU-ACT',
          countryCode: 'AU'),
      Province(name: 'New South Wales', code: 'AU-NSW', countryCode: 'AU'),
      Province(name: 'Northern Territory', code: 'AU-NT', countryCode: 'AU'),
      Province(name: 'Queensland', code: 'AU-QLD', countryCode: 'AU'),
      Province(name: 'South Australia', code: 'AU-SA', countryCode: 'AU'),
      Province(name: 'Tasmania', code: 'AU-TAS', countryCode: 'AU'),
      Province(name: 'Victoria', code: 'AU-VIC', countryCode: 'AU'),
      Province(name: 'Western Australia', code: 'AU-WA', countryCode: 'AU'),
    ],

    // United Kingdom - 4 Countries
    'GB': [
      Province(name: 'England', code: 'GB-ENG', countryCode: 'GB'),
      Province(name: 'Scotland', code: 'GB-SCT', countryCode: 'GB'),
      Province(name: 'Wales', code: 'GB-WLS', countryCode: 'GB'),
      Province(name: 'Northern Ireland', code: 'GB-NIR', countryCode: 'GB'),
    ],

    // France - 18 Regions
    'FR': [
      Province(name: 'Auvergne-Rhône-Alpes', code: 'FR-ARA', countryCode: 'FR'),
      Province(
          name: 'Bourgogne-Franche-Comté', code: 'FR-BFC', countryCode: 'FR'),
      Province(name: 'Brittany', code: 'FR-BRE', countryCode: 'FR'),
      Province(name: 'Centre-Val de Loire', code: 'FR-CVL', countryCode: 'FR'),
      Province(name: 'Corsica', code: 'FR-COR', countryCode: 'FR'),
      Province(name: 'Grand Est', code: 'FR-GES', countryCode: 'FR'),
      Province(name: 'Hauts-de-France', code: 'FR-HDF', countryCode: 'FR'),
      Province(name: 'Île-de-France', code: 'FR-IDF', countryCode: 'FR'),
      Province(name: 'Normandy', code: 'FR-NOR', countryCode: 'FR'),
      Province(name: 'Nouvelle-Aquitaine', code: 'FR-NAQ', countryCode: 'FR'),
      Province(name: 'Occitanie', code: 'FR-OCC', countryCode: 'FR'),
      Province(name: 'Pays de la Loire', code: 'FR-PDL', countryCode: 'FR'),
      Province(
          name: 'Provence-Alpes-Côte d\'Azur',
          code: 'FR-PAC',
          countryCode: 'FR'),
      Province(name: 'Guadeloupe', code: 'FR-GP', countryCode: 'FR'),
      Province(name: 'Martinique', code: 'FR-MQ', countryCode: 'FR'),
      Province(name: 'French Guiana', code: 'FR-GF', countryCode: 'FR'),
      Province(name: 'Réunion', code: 'FR-RE', countryCode: 'FR'),
      Province(name: 'Mayotte', code: 'FR-YT', countryCode: 'FR'),
    ],

    // India - 28 States and 8 Union Territories
    'IN': [
      Province(name: 'Andhra Pradesh', code: 'IN-AP', countryCode: 'IN'),
      Province(name: 'Arunachal Pradesh', code: 'IN-AR', countryCode: 'IN'),
      Province(name: 'Assam', code: 'IN-AS', countryCode: 'IN'),
      Province(name: 'Bihar', code: 'IN-BR', countryCode: 'IN'),
      Province(name: 'Chhattisgarh', code: 'IN-CT', countryCode: 'IN'),
      Province(name: 'Goa', code: 'IN-GA', countryCode: 'IN'),
      Province(name: 'Gujarat', code: 'IN-GJ', countryCode: 'IN'),
      Province(name: 'Haryana', code: 'IN-HR', countryCode: 'IN'),
      Province(name: 'Himachal Pradesh', code: 'IN-HP', countryCode: 'IN'),
      Province(name: 'Jharkhand', code: 'IN-JH', countryCode: 'IN'),
      Province(name: 'Karnataka', code: 'IN-KA', countryCode: 'IN'),
      Province(name: 'Kerala', code: 'IN-KL', countryCode: 'IN'),
      Province(name: 'Madhya Pradesh', code: 'IN-MP', countryCode: 'IN'),
      Province(name: 'Maharashtra', code: 'IN-MH', countryCode: 'IN'),
      Province(name: 'Manipur', code: 'IN-MN', countryCode: 'IN'),
      Province(name: 'Meghalaya', code: 'IN-ML', countryCode: 'IN'),
      Province(name: 'Mizoram', code: 'IN-MZ', countryCode: 'IN'),
      Province(name: 'Nagaland', code: 'IN-NL', countryCode: 'IN'),
      Province(name: 'Odisha', code: 'IN-OR', countryCode: 'IN'),
      Province(name: 'Punjab', code: 'IN-PB', countryCode: 'IN'),
      Province(name: 'Rajasthan', code: 'IN-RJ', countryCode: 'IN'),
      Province(name: 'Sikkim', code: 'IN-SK', countryCode: 'IN'),
      Province(name: 'Tamil Nadu', code: 'IN-TN', countryCode: 'IN'),
      Province(name: 'Telangana', code: 'IN-TG', countryCode: 'IN'),
      Province(name: 'Tripura', code: 'IN-TR', countryCode: 'IN'),
      Province(name: 'Uttar Pradesh', code: 'IN-UP', countryCode: 'IN'),
      Province(name: 'Uttarakhand', code: 'IN-UT', countryCode: 'IN'),
      Province(name: 'West Bengal', code: 'IN-WB', countryCode: 'IN'),
      // Union Territories
      Province(
          name: 'Andaman and Nicobar Islands',
          code: 'IN-AN',
          countryCode: 'IN'),
      Province(name: 'Chandigarh', code: 'IN-CH', countryCode: 'IN'),
      Province(
          name: 'Dadra and Nagar Haveli and Daman and Diu',
          code: 'IN-DH',
          countryCode: 'IN'),
      Province(name: 'Delhi', code: 'IN-DL', countryCode: 'IN'),
      Province(name: 'Jammu and Kashmir', code: 'IN-JK', countryCode: 'IN'),
      Province(name: 'Ladakh', code: 'IN-LA', countryCode: 'IN'),
      Province(name: 'Lakshadweep', code: 'IN-LD', countryCode: 'IN'),
      Province(name: 'Puducherry', code: 'IN-PY', countryCode: 'IN'),
    ],

    // Brazil - 26 States and 1 Federal District
    'BR': [
      Province(name: 'Acre', code: 'BR-AC', countryCode: 'BR'),
      Province(name: 'Alagoas', code: 'BR-AL', countryCode: 'BR'),
      Province(name: 'Amapá', code: 'BR-AP', countryCode: 'BR'),
      Province(name: 'Amazonas', code: 'BR-AM', countryCode: 'BR'),
      Province(name: 'Bahia', code: 'BR-BA', countryCode: 'BR'),
      Province(name: 'Ceará', code: 'BR-CE', countryCode: 'BR'),
      Province(name: 'Distrito Federal', code: 'BR-DF', countryCode: 'BR'),
      Province(name: 'Espírito Santo', code: 'BR-ES', countryCode: 'BR'),
      Province(name: 'Goiás', code: 'BR-GO', countryCode: 'BR'),
      Province(name: 'Maranhão', code: 'BR-MA', countryCode: 'BR'),
      Province(name: 'Mato Grosso', code: 'BR-MT', countryCode: 'BR'),
      Province(name: 'Mato Grosso do Sul', code: 'BR-MS', countryCode: 'BR'),
      Province(name: 'Minas Gerais', code: 'BR-MG', countryCode: 'BR'),
      Province(name: 'Pará', code: 'BR-PA', countryCode: 'BR'),
      Province(name: 'Paraíba', code: 'BR-PB', countryCode: 'BR'),
      Province(name: 'Paraná', code: 'BR-PR', countryCode: 'BR'),
      Province(name: 'Pernambuco', code: 'BR-PE', countryCode: 'BR'),
      Province(name: 'Piauí', code: 'BR-PI', countryCode: 'BR'),
      Province(name: 'Rio de Janeiro', code: 'BR-RJ', countryCode: 'BR'),
      Province(name: 'Rio Grande do Norte', code: 'BR-RN', countryCode: 'BR'),
      Province(name: 'Rio Grande do Sul', code: 'BR-RS', countryCode: 'BR'),
      Province(name: 'Rondônia', code: 'BR-RO', countryCode: 'BR'),
      Province(name: 'Roraima', code: 'BR-RR', countryCode: 'BR'),
      Province(name: 'Santa Catarina', code: 'BR-SC', countryCode: 'BR'),
      Province(name: 'São Paulo', code: 'BR-SP', countryCode: 'BR'),
      Province(name: 'Sergipe', code: 'BR-SE', countryCode: 'BR'),
      Province(name: 'Tocantins', code: 'BR-TO', countryCode: 'BR'),
    ],
  };

  /// Hardcoded city data for major provinces
  static const Map<String, List<City>> _provinceCities = {
    // Turkey Cities
    'TR-34': [
      // Istanbul
      City(name: 'Kadıköy', provinceCode: 'TR-34', countryCode: 'TR'),
      City(name: 'Beşiktaş', provinceCode: 'TR-34', countryCode: 'TR'),
      City(name: 'Şişli', provinceCode: 'TR-34', countryCode: 'TR'),
      City(name: 'Beyoğlu', provinceCode: 'TR-34', countryCode: 'TR'),
      City(name: 'Üsküdar', provinceCode: 'TR-34', countryCode: 'TR'),
      City(name: 'Fatih', provinceCode: 'TR-34', countryCode: 'TR'),
      City(name: 'Bakırköy', provinceCode: 'TR-34', countryCode: 'TR'),
      City(name: 'Pendik', provinceCode: 'TR-34', countryCode: 'TR'),
      City(name: 'Maltepe', provinceCode: 'TR-34', countryCode: 'TR'),
      City(name: 'Ataşehir', provinceCode: 'TR-34', countryCode: 'TR'),
    ],
    'TR-06': [
      // Ankara
      City(name: 'Çankaya', provinceCode: 'TR-06', countryCode: 'TR'),
      City(name: 'Keçiören', provinceCode: 'TR-06', countryCode: 'TR'),
      City(name: 'Yenimahalle', provinceCode: 'TR-06', countryCode: 'TR'),
      City(name: 'Mamak', provinceCode: 'TR-06', countryCode: 'TR'),
      City(name: 'Sincan', provinceCode: 'TR-06', countryCode: 'TR'),
      City(name: 'Etimesgut', provinceCode: 'TR-06', countryCode: 'TR'),
    ],
    'TR-35': [
      // Izmir
      City(name: 'Konak', provinceCode: 'TR-35', countryCode: 'TR'),
      City(name: 'Bornova', provinceCode: 'TR-35', countryCode: 'TR'),
      City(name: 'Karşıyaka', provinceCode: 'TR-35', countryCode: 'TR'),
      City(name: 'Alsancak', provinceCode: 'TR-35', countryCode: 'TR'),
      City(name: 'Buca', provinceCode: 'TR-35', countryCode: 'TR'),
      City(name: 'Çiğli', provinceCode: 'TR-35', countryCode: 'TR'),
    ],
    'TR-16': [
      // Bursa
      City(name: 'Osmangazi', provinceCode: 'TR-16', countryCode: 'TR'),
      City(name: 'Nilüfer', provinceCode: 'TR-16', countryCode: 'TR'),
      City(name: 'Yıldırım', provinceCode: 'TR-16', countryCode: 'TR'),
      City(name: 'Gemlik', provinceCode: 'TR-16', countryCode: 'TR'),
      City(name: 'İnegöl', provinceCode: 'TR-16', countryCode: 'TR'),
    ],
    'TR-07': [
      // Antalya
      City(name: 'Muratpaşa', provinceCode: 'TR-07', countryCode: 'TR'),
      City(name: 'Kepez', provinceCode: 'TR-07', countryCode: 'TR'),
      City(name: 'Konyaaltı', provinceCode: 'TR-07', countryCode: 'TR'),
      City(name: 'Alanya', provinceCode: 'TR-07', countryCode: 'TR'),
      City(name: 'Manavgat', provinceCode: 'TR-07', countryCode: 'TR'),
      City(name: 'Side', provinceCode: 'TR-07', countryCode: 'TR'),
    ],

    // United States Cities
    'US-CA': [
      // California
      City(name: 'Los Angeles', provinceCode: 'US-CA', countryCode: 'US'),
      City(name: 'San Francisco', provinceCode: 'US-CA', countryCode: 'US'),
      City(name: 'San Diego', provinceCode: 'US-CA', countryCode: 'US'),
      City(name: 'Sacramento', provinceCode: 'US-CA', countryCode: 'US'),
      City(name: 'San Jose', provinceCode: 'US-CA', countryCode: 'US'),
      City(name: 'Oakland', provinceCode: 'US-CA', countryCode: 'US'),
      City(name: 'Fresno', provinceCode: 'US-CA', countryCode: 'US'),
      City(name: 'Long Beach', provinceCode: 'US-CA', countryCode: 'US'),
    ],
    'US-TX': [
      // Texas
      City(name: 'Houston', provinceCode: 'US-TX', countryCode: 'US'),
      City(name: 'Dallas', provinceCode: 'US-TX', countryCode: 'US'),
      City(name: 'San Antonio', provinceCode: 'US-TX', countryCode: 'US'),
      City(name: 'Austin', provinceCode: 'US-TX', countryCode: 'US'),
      City(name: 'Fort Worth', provinceCode: 'US-TX', countryCode: 'US'),
      City(name: 'El Paso', provinceCode: 'US-TX', countryCode: 'US'),
    ],
    'US-NY': [
      // New York
      City(name: 'New York City', provinceCode: 'US-NY', countryCode: 'US'),
      City(name: 'Buffalo', provinceCode: 'US-NY', countryCode: 'US'),
      City(name: 'Rochester', provinceCode: 'US-NY', countryCode: 'US'),
      City(name: 'Syracuse', provinceCode: 'US-NY', countryCode: 'US'),
      City(name: 'Albany', provinceCode: 'US-NY', countryCode: 'US'),
      City(name: 'Yonkers', provinceCode: 'US-NY', countryCode: 'US'),
    ],
    'US-FL': [
      // Florida
      City(name: 'Miami', provinceCode: 'US-FL', countryCode: 'US'),
      City(name: 'Orlando', provinceCode: 'US-FL', countryCode: 'US'),
      City(name: 'Tampa', provinceCode: 'US-FL', countryCode: 'US'),
      City(name: 'Jacksonville', provinceCode: 'US-FL', countryCode: 'US'),
      City(name: 'Fort Lauderdale', provinceCode: 'US-FL', countryCode: 'US'),
      City(name: 'Tallahassee', provinceCode: 'US-FL', countryCode: 'US'),
    ],

    // Canada Cities
    'CA-ON': [
      // Ontario
      City(name: 'Toronto', provinceCode: 'CA-ON', countryCode: 'CA'),
      City(name: 'Ottawa', provinceCode: 'CA-ON', countryCode: 'CA'),
      City(name: 'Hamilton', provinceCode: 'CA-ON', countryCode: 'CA'),
      City(name: 'London', provinceCode: 'CA-ON', countryCode: 'CA'),
      City(name: 'Kitchener', provinceCode: 'CA-ON', countryCode: 'CA'),
      City(name: 'Windsor', provinceCode: 'CA-ON', countryCode: 'CA'),
      City(name: 'Mississauga', provinceCode: 'CA-ON', countryCode: 'CA'),
    ],
    'CA-QC': [
      // Quebec
      City(name: 'Montreal', provinceCode: 'CA-QC', countryCode: 'CA'),
      City(name: 'Quebec City', provinceCode: 'CA-QC', countryCode: 'CA'),
      City(name: 'Laval', provinceCode: 'CA-QC', countryCode: 'CA'),
      City(name: 'Gatineau', provinceCode: 'CA-QC', countryCode: 'CA'),
      City(name: 'Longueuil', provinceCode: 'CA-QC', countryCode: 'CA'),
      City(name: 'Sherbrooke', provinceCode: 'CA-QC', countryCode: 'CA'),
    ],
    'CA-BC': [
      // British Columbia
      City(name: 'Vancouver', provinceCode: 'CA-BC', countryCode: 'CA'),
      City(name: 'Victoria', provinceCode: 'CA-BC', countryCode: 'CA'),
      City(name: 'Surrey', provinceCode: 'CA-BC', countryCode: 'CA'),
      City(name: 'Burnaby', provinceCode: 'CA-BC', countryCode: 'CA'),
      City(name: 'Richmond', provinceCode: 'CA-BC', countryCode: 'CA'),
      City(name: 'Kelowna', provinceCode: 'CA-BC', countryCode: 'CA'),
    ],
    'CA-AB': [
      // Alberta
      City(name: 'Calgary', provinceCode: 'CA-AB', countryCode: 'CA'),
      City(name: 'Edmonton', provinceCode: 'CA-AB', countryCode: 'CA'),
      City(name: 'Red Deer', provinceCode: 'CA-AB', countryCode: 'CA'),
      City(name: 'Lethbridge', provinceCode: 'CA-AB', countryCode: 'CA'),
      City(name: 'Medicine Hat', provinceCode: 'CA-AB', countryCode: 'CA'),
    ],

    // Germany Cities
    'DE-BY': [
      // Bavaria
      City(name: 'Munich', provinceCode: 'DE-BY', countryCode: 'DE'),
      City(name: 'Nuremberg', provinceCode: 'DE-BY', countryCode: 'DE'),
      City(name: 'Augsburg', provinceCode: 'DE-BY', countryCode: 'DE'),
      City(name: 'Regensburg', provinceCode: 'DE-BY', countryCode: 'DE'),
      City(name: 'Würzburg', provinceCode: 'DE-BY', countryCode: 'DE'),
    ],
    'DE-NW': [
      // North Rhine-Westphalia
      City(name: 'Cologne', provinceCode: 'DE-NW', countryCode: 'DE'),
      City(name: 'Düsseldorf', provinceCode: 'DE-NW', countryCode: 'DE'),
      City(name: 'Dortmund', provinceCode: 'DE-NW', countryCode: 'DE'),
      City(name: 'Essen', provinceCode: 'DE-NW', countryCode: 'DE'),
      City(name: 'Duisburg', provinceCode: 'DE-NW', countryCode: 'DE'),
      City(name: 'Bochum', provinceCode: 'DE-NW', countryCode: 'DE'),
    ],
    'DE-BE': [
      // Berlin
      City(name: 'Berlin Mitte', provinceCode: 'DE-BE', countryCode: 'DE'),
      City(name: 'Charlottenburg', provinceCode: 'DE-BE', countryCode: 'DE'),
      City(name: 'Kreuzberg', provinceCode: 'DE-BE', countryCode: 'DE'),
      City(name: 'Prenzlauer Berg', provinceCode: 'DE-BE', countryCode: 'DE'),
      City(name: 'Friedrichshain', provinceCode: 'DE-BE', countryCode: 'DE'),
    ],

    // Australia Cities
    'AU-NSW': [
      // New South Wales
      City(name: 'Sydney', provinceCode: 'AU-NSW', countryCode: 'AU'),
      City(name: 'Newcastle', provinceCode: 'AU-NSW', countryCode: 'AU'),
      City(name: 'Wollongong', provinceCode: 'AU-NSW', countryCode: 'AU'),
      City(name: 'Central Coast', provinceCode: 'AU-NSW', countryCode: 'AU'),
      City(name: 'Maitland', provinceCode: 'AU-NSW', countryCode: 'AU'),
    ],
    'AU-VIC': [
      // Victoria
      City(name: 'Melbourne', provinceCode: 'AU-VIC', countryCode: 'AU'),
      City(name: 'Geelong', provinceCode: 'AU-VIC', countryCode: 'AU'),
      City(name: 'Ballarat', provinceCode: 'AU-VIC', countryCode: 'AU'),
      City(name: 'Bendigo', provinceCode: 'AU-VIC', countryCode: 'AU'),
      City(name: 'Latrobe City', provinceCode: 'AU-VIC', countryCode: 'AU'),
    ],
    'AU-QLD': [
      // Queensland
      City(name: 'Brisbane', provinceCode: 'AU-QLD', countryCode: 'AU'),
      City(name: 'Gold Coast', provinceCode: 'AU-QLD', countryCode: 'AU'),
      City(name: 'Townsville', provinceCode: 'AU-QLD', countryCode: 'AU'),
      City(name: 'Cairns', provinceCode: 'AU-QLD', countryCode: 'AU'),
      City(name: 'Toowoomba', provinceCode: 'AU-QLD', countryCode: 'AU'),
    ],
    'AU-WA': [
      // Western Australia
      City(name: 'Perth', provinceCode: 'AU-WA', countryCode: 'AU'),
      City(name: 'Fremantle', provinceCode: 'AU-WA', countryCode: 'AU'),
      City(name: 'Mandurah', provinceCode: 'AU-WA', countryCode: 'AU'),
      City(name: 'Bunbury', provinceCode: 'AU-WA', countryCode: 'AU'),
      City(name: 'Rockingham', provinceCode: 'AU-WA', countryCode: 'AU'),
    ],

    // United Kingdom Cities
    'GB-ENG': [
      // England
      City(name: 'London', provinceCode: 'GB-ENG', countryCode: 'GB'),
      City(name: 'Birmingham', provinceCode: 'GB-ENG', countryCode: 'GB'),
      City(name: 'Manchester', provinceCode: 'GB-ENG', countryCode: 'GB'),
      City(name: 'Liverpool', provinceCode: 'GB-ENG', countryCode: 'GB'),
      City(name: 'Leeds', provinceCode: 'GB-ENG', countryCode: 'GB'),
      City(name: 'Sheffield', provinceCode: 'GB-ENG', countryCode: 'GB'),
    ],
    'GB-SCT': [
      // Scotland
      City(name: 'Edinburgh', provinceCode: 'GB-SCT', countryCode: 'GB'),
      City(name: 'Glasgow', provinceCode: 'GB-SCT', countryCode: 'GB'),
      City(name: 'Aberdeen', provinceCode: 'GB-SCT', countryCode: 'GB'),
      City(name: 'Dundee', provinceCode: 'GB-SCT', countryCode: 'GB'),
      City(name: 'Stirling', provinceCode: 'GB-SCT', countryCode: 'GB'),
    ],

    // France Cities
    'FR-IDF': [
      // Île-de-France
      City(name: 'Paris', provinceCode: 'FR-IDF', countryCode: 'FR'),
      City(
          name: 'Boulogne-Billancourt',
          provinceCode: 'FR-IDF',
          countryCode: 'FR'),
      City(name: 'Saint-Denis', provinceCode: 'FR-IDF', countryCode: 'FR'),
      City(name: 'Argenteuil', provinceCode: 'FR-IDF', countryCode: 'FR'),
      City(name: 'Versailles', provinceCode: 'FR-IDF', countryCode: 'FR'),
    ],
    'FR-ARA': [
      // Auvergne-Rhône-Alpes
      City(name: 'Lyon', provinceCode: 'FR-ARA', countryCode: 'FR'),
      City(name: 'Grenoble', provinceCode: 'FR-ARA', countryCode: 'FR'),
      City(name: 'Saint-Étienne', provinceCode: 'FR-ARA', countryCode: 'FR'),
      City(name: 'Villeurbanne', provinceCode: 'FR-ARA', countryCode: 'FR'),
      City(name: 'Clermont-Ferrand', provinceCode: 'FR-ARA', countryCode: 'FR'),
    ],
    'FR-PAC': [
      // Provence-Alpes-Côte d'Azur
      City(name: 'Marseille', provinceCode: 'FR-PAC', countryCode: 'FR'),
      City(name: 'Nice', provinceCode: 'FR-PAC', countryCode: 'FR'),
      City(name: 'Toulon', provinceCode: 'FR-PAC', countryCode: 'FR'),
      City(name: 'Aix-en-Provence', provinceCode: 'FR-PAC', countryCode: 'FR'),
      City(name: 'Cannes', provinceCode: 'FR-PAC', countryCode: 'FR'),
    ],

    // India Cities
    'IN-MH': [
      // Maharashtra
      City(name: 'Mumbai', provinceCode: 'IN-MH', countryCode: 'IN'),
      City(name: 'Pune', provinceCode: 'IN-MH', countryCode: 'IN'),
      City(name: 'Nagpur', provinceCode: 'IN-MH', countryCode: 'IN'),
      City(name: 'Thane', provinceCode: 'IN-MH', countryCode: 'IN'),
      City(name: 'Nashik', provinceCode: 'IN-MH', countryCode: 'IN'),
    ],
    'IN-DL': [
      // Delhi
      City(name: 'New Delhi', provinceCode: 'IN-DL', countryCode: 'IN'),
      City(name: 'Central Delhi', provinceCode: 'IN-DL', countryCode: 'IN'),
      City(name: 'South Delhi', provinceCode: 'IN-DL', countryCode: 'IN'),
      City(name: 'North Delhi', provinceCode: 'IN-DL', countryCode: 'IN'),
      City(name: 'East Delhi', provinceCode: 'IN-DL', countryCode: 'IN'),
    ],
    'IN-KA': [
      // Karnataka
      City(name: 'Bangalore', provinceCode: 'IN-KA', countryCode: 'IN'),
      City(name: 'Mysore', provinceCode: 'IN-KA', countryCode: 'IN'),
      City(name: 'Hubli-Dharwad', provinceCode: 'IN-KA', countryCode: 'IN'),
      City(name: 'Mangalore', provinceCode: 'IN-KA', countryCode: 'IN'),
      City(name: 'Belgaum', provinceCode: 'IN-KA', countryCode: 'IN'),
    ],

    // Brazil Cities
    'BR-SP': [
      // São Paulo
      City(name: 'São Paulo', provinceCode: 'BR-SP', countryCode: 'BR'),
      City(name: 'Guarulhos', provinceCode: 'BR-SP', countryCode: 'BR'),
      City(name: 'Campinas', provinceCode: 'BR-SP', countryCode: 'BR'),
      City(
          name: 'São Bernardo do Campo',
          provinceCode: 'BR-SP',
          countryCode: 'BR'),
      City(name: 'Santos', provinceCode: 'BR-SP', countryCode: 'BR'),
    ],
    'BR-RJ': [
      // Rio de Janeiro
      City(name: 'Rio de Janeiro', provinceCode: 'BR-RJ', countryCode: 'BR'),
      City(name: 'São Gonçalo', provinceCode: 'BR-RJ', countryCode: 'BR'),
      City(name: 'Duque de Caxias', provinceCode: 'BR-RJ', countryCode: 'BR'),
      City(name: 'Nova Iguaçu', provinceCode: 'BR-RJ', countryCode: 'BR'),
      City(name: 'Niterói', provinceCode: 'BR-RJ', countryCode: 'BR'),
    ],
    'BR-MG': [
      // Minas Gerais
      City(name: 'Belo Horizonte', provinceCode: 'BR-MG', countryCode: 'BR'),
      City(name: 'Uberlândia', provinceCode: 'BR-MG', countryCode: 'BR'),
      City(name: 'Contagem', provinceCode: 'BR-MG', countryCode: 'BR'),
      City(name: 'Juiz de Fora', provinceCode: 'BR-MG', countryCode: 'BR'),
      City(name: 'Betim', provinceCode: 'BR-MG', countryCode: 'BR'),
    ],
  };
}
