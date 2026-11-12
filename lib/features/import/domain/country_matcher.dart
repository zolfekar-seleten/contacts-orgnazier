import '../../countries/domain/country.dart';

/// Recognises a country written as a name, ISO code, common abbreviation,
/// nationality ("Emirati") or Arabic name, e.g. for spreadsheet import.
class CountryMatcher {
  CountryMatcher._();

  static final instance = CountryMatcher._();

  late final Map<String, String> _names = {
    for (final c in Country.all) ...{
      _key(c.name): c.isoCode,
      c.isoCode.toLowerCase(): c.isoCode,
    },
    for (final MapEntry(:key, :value) in _aliases.entries) _key(key): value,
  };

  late final Map<String, String> _demonyms = {
    for (final MapEntry(:key, :value) in _nationalities.entries)
      _key(key): value,
  };

  /// ISO code for [text], or null.
  String? match(String text) {
    final k = _key(text);
    if (k.isEmpty) return null;
    return _names[k] ?? _demonyms[k];
  }

  /// Whether [text] reads as a nationality ("Indian") rather than a country.
  bool isNationalityWord(String text) => _demonyms.containsKey(_key(text));

  static String _key(String s) => s
      .toLowerCase()
      .replaceAll(RegExp(r'[̀-ͯ]'), '')
      .replaceAll(RegExp('[àáâãäå]'), 'a')
      .replaceAll(RegExp('[èéêë]'), 'e')
      .replaceAll(RegExp('[ìíîï]'), 'i')
      .replaceAll(RegExp('[òóôõö]'), 'o')
      .replaceAll(RegExp('[ùúûü]'), 'u')
      .replaceAll('ç', 'c')
      .replaceAll(RegExp(r'^the\s+'), '')
      .replaceAll(RegExp(r'[^\p{L}\p{N}]+', unicode: true), '');

  static const _aliases = {
    'UAE': 'AE', 'U.A.E': 'AE', 'Emirates': 'AE', 'ARE': 'AE',
    'United Arab Emirate': 'AE', 'Dubai': 'AE', 'Abu Dhabi': 'AE',
    'KSA': 'SA', 'Saudi': 'SA', 'SAU': 'SA', 'Kingdom of Saudi Arabia': 'SA',
    'USA': 'US', 'U.S.A': 'US', 'U.S': 'US', 'America': 'US',
    'United States of America': 'US',
    'UK': 'GB', 'U.K': 'GB', 'GBR': 'GB', 'Britain': 'GB',
    'Great Britain': 'GB', 'England': 'GB', 'Scotland': 'GB', 'Wales': 'GB',
    'IND': 'IN', 'PAK': 'PK', 'EGY': 'EG', 'JOR': 'JO', 'LBN': 'LB',
    'Russia': 'RU', 'Russian Federation': 'RU', 'South Korea': 'KR',
    'Korea': 'KR', 'North Korea': 'KP', 'Iran': 'IR', 'Syria': 'SY',
    'Palestine': 'PS', 'Vietnam': 'VN', 'Turkey': 'TR', 'Turkiye': 'TR',
    'Czech Republic': 'CZ', 'Holland': 'NL', 'The Netherlands': 'NL',
    'Ivory Coast': 'CI', 'Hong Kong': 'HK', 'Macau': 'MO', 'Laos': 'LA',
    'Moldova': 'MD', 'Tanzania': 'TZ', 'Venezuela': 'VE', 'Bolivia': 'BO',
    'Congo': 'CG', 'DR Congo': 'CD', 'DRC': 'CD',
    // Arabic.
    'الإمارات': 'AE', 'الامارات': 'AE', 'الإمارات العربية المتحدة': 'AE',
    'السعودية': 'SA', 'المملكة العربية السعودية': 'SA', 'مصر': 'EG',
    'الأردن': 'JO', 'الاردن': 'JO', 'لبنان': 'LB', 'سوريا': 'SY',
    'العراق': 'IQ', 'الكويت': 'KW', 'قطر': 'QA', 'عمان': 'OM', 'عُمان': 'OM',
    'البحرين': 'BH', 'اليمن': 'YE', 'فلسطين': 'PS', 'المغرب': 'MA',
    'الجزائر': 'DZ', 'تونس': 'TN', 'ليبيا': 'LY', 'السودان': 'SD',
    'الهند': 'IN', 'باكستان': 'PK', 'بريطانيا': 'GB',
    'المملكة المتحدة': 'GB', 'أمريكا': 'US', 'الولايات المتحدة': 'US',
    'تركيا': 'TR', 'إيران': 'IR', 'ايران': 'IR', 'روسيا': 'RU',
    'الصين': 'CN', 'فرنسا': 'FR', 'ألمانيا': 'DE', 'المانيا': 'DE',
    'الفلبين': 'PH',
  };

  static const _nationalities = {
    'Emirati': 'AE', 'Saudi Arabian': 'SA', 'Indian': 'IN',
    'Pakistani': 'PK', 'Egyptian': 'EG', 'Jordanian': 'JO',
    'Lebanese': 'LB', 'Syrian': 'SY', 'Iraqi': 'IQ', 'Kuwaiti': 'KW',
    'Qatari': 'QA', 'Omani': 'OM', 'Bahraini': 'BH', 'Yemeni': 'YE',
    'Palestinian': 'PS', 'Moroccan': 'MA', 'Algerian': 'DZ',
    'Tunisian': 'TN', 'Libyan': 'LY', 'Sudanese': 'SD', 'Somali': 'SO',
    'Iranian': 'IR', 'Turkish': 'TR', 'Afghan': 'AF', 'Bangladeshi': 'BD',
    'Sri Lankan': 'LK', 'Nepali': 'NP', 'Nepalese': 'NP', 'Filipino': 'PH',
    'Filipina': 'PH', 'Indonesian': 'ID', 'Malaysian': 'MY',
    'Singaporean': 'SG', 'Thai': 'TH', 'Vietnamese': 'VN', 'Chinese': 'CN',
    'Japanese': 'JP', 'Korean': 'KR', 'South Korean': 'KR',
    'Kazakh': 'KZ', 'Uzbek': 'UZ', 'Russian': 'RU', 'Ukrainian': 'UA',
    'British': 'GB', 'English': 'GB', 'Scottish': 'GB', 'Welsh': 'GB',
    'Irish': 'IE', 'American': 'US', 'Canadian': 'CA', 'Mexican': 'MX',
    'Brazilian': 'BR', 'Argentinian': 'AR', 'Argentine': 'AR',
    'Colombian': 'CO', 'Australian': 'AU', 'New Zealander': 'NZ',
    'French': 'FR', 'German': 'DE', 'Italian': 'IT', 'Spanish': 'ES',
    'Portuguese': 'PT', 'Dutch': 'NL', 'Belgian': 'BE', 'Swiss': 'CH',
    'Austrian': 'AT', 'Swedish': 'SE', 'Norwegian': 'NO', 'Danish': 'DK',
    'Finnish': 'FI', 'Polish': 'PL', 'Greek': 'GR', 'Romanian': 'RO',
    'Bulgarian': 'BG', 'Serbian': 'RS', 'Croatian': 'HR', 'Czech': 'CZ',
    'Hungarian': 'HU', 'Nigerian': 'NG', 'Kenyan': 'KE', 'Ethiopian': 'ET',
    'Ghanaian': 'GH', 'Ugandan': 'UG', 'South African': 'ZA',
    'Cameroonian': 'CM', 'Eritrean': 'ER', 'Tanzanian': 'TZ',
    // Arabic.
    'إماراتي': 'AE', 'اماراتي': 'AE', 'سعودي': 'SA', 'مصري': 'EG',
    'أردني': 'JO', 'اردني': 'JO', 'لبناني': 'LB', 'سوري': 'SY',
    'عراقي': 'IQ', 'كويتي': 'KW', 'قطري': 'QA', 'عماني': 'OM',
    'بحريني': 'BH', 'يمني': 'YE', 'فلسطيني': 'PS', 'مغربي': 'MA',
    'هندي': 'IN', 'باكستاني': 'PK', 'بريطاني': 'GB', 'أمريكي': 'US',
  };
}
