// Generates a vCard file of realistic test contacts with metadata-valid numbers.
//
// Usage (from the project root):
//   dart run tool/generate_test_contacts.dart 500 contacts.vcf
//   xcrun simctl addmedia booted contacts.vcf   # import into iOS simulator
//
// Mix: ~54 countries weighted like a UAE-based address book, international,
// 00-prefixed and bracketed formats, UAE national numbers (classified only with
// region AE), ~18% with a second number, ~3% unclassifiable short numbers.
import 'dart:io';
import 'dart:math';

import 'package:phone_numbers_parser/metadata.dart';
import 'package:phone_numbers_parser/phone_numbers_parser.dart';

final rnd = Random(42);

// Country weights (roughly a UAE-based address book).
const weights = {
  'AE': 90,
  'IN': 60,
  'GB': 45,
  'US': 40,
  'PK': 30,
  'PH': 25,
  'EG': 22,
  'SA': 20,
  'LB': 14,
  'JO': 12,
  'CA': 12,
  'DE': 10,
  'FR': 10,
  'AU': 9,
  'KW': 8,
  'QA': 8,
  'OM': 8,
  'BH': 7,
  'IT': 7,
  'ES': 7,
  'NL': 6,
  'TR': 6,
  'RU': 6,
  'CN': 6,
  'NG': 6,
  'KE': 5,
  'ZA': 5,
  'BD': 5,
  'LK': 5,
  'NP': 5,
  'IE': 4,
  'SE': 4,
  'CH': 4,
  'BR': 4,
  'MX': 4,
  'JP': 4,
  'KR': 3,
  'SG': 3,
  'MY': 3,
  'ID': 3,
  'MA': 3,
  'TN': 3,
  'SY': 3,
  'IQ': 3,
  'IR': 3,
  'NZ': 2,
  'PT': 2,
  'PL': 2,
  'GR': 2,
  'UA': 2,
  'AR': 2,
  'KZ': 2,
  'GG': 1,
  'JE': 1,
};

const first = [
  'Aisha',
  'Omar',
  'Fatima',
  'Yusuf',
  'Layla',
  'Khalid',
  'Mariam',
  'Hassan',
  'Noor',
  'Ali',
  'Sara',
  'Ahmed',
  'Priya',
  'Rahul',
  'Ananya',
  'Vikram',
  'Deepa',
  'Arjun',
  'Kavya',
  'Sanjay',
  'Oliver',
  'Amelia',
  'Harry',
  'Isla',
  'George',
  'Emily',
  'Jack',
  'Sophie',
  'James',
  'Olivia',
  'Liam',
  'Emma',
  'Noah',
  'Ava',
  'Lucas',
  'Mia',
  'Chen',
  'Mei',
  'Hiroshi',
  'Yuki',
  'Ji-ho',
  'Lukas',
  'Lena',
  'Pierre',
  'Chloé',
  'Marco',
  'Giulia',
  'Carlos',
  'Lucía',
  'João',
  'Ana',
  'Ivan',
  'Olga',
  'Chidi',
  'Amara',
  'Wanjiru',
  'Kofi',
  'Thabo',
  'Nadia',
  'Rania',
  'Tariq',
  'Zainab',
  'Bilal',
  'Hira',
  'Imran',
  'Maria',
  'Jose',
  'Angelica',
  'Mark',
  'Rizal',
  'Siti',
  'Dewi',
  'Mehmet',
  'Elif',
  'Reza',
  'Shirin',
  'Sven',
  'Ingrid',
  'Jan',
  'Eva',
];
const last = [
  'Al Mansoori',
  'Al Hashimi',
  'Haddad',
  'Khoury',
  'Saeed',
  'Rahman',
  'Khan',
  'Sharma',
  'Patel',
  'Iyer',
  'Nair',
  'Reddy',
  'Gupta',
  'Smith',
  'Jones',
  'Taylor',
  'Brown',
  'Wilson',
  'Evans',
  'Johnson',
  'Williams',
  'Garcia',
  'Miller',
  'Davis',
  'Martin',
  'Tremblay',
  'Roy',
  'Wang',
  'Li',
  'Tanaka',
  'Sato',
  'Kim',
  'Park',
  'Müller',
  'Schmidt',
  'Dubois',
  'Bernard',
  'Rossi',
  'Bianchi',
  'Fernández',
  'López',
  'Silva',
  'Santos',
  'Ivanov',
  'Petrova',
  'Okafor',
  'Adeyemi',
  'Mwangi',
  'Mensah',
  'Nkosi',
  'Farouk',
  'Mahmoud',
  'Hussain',
  'Qureshi',
  'Malik',
  'Reyes',
  'Cruz',
  'Santos',
  'Bautista',
  'Tan',
  'Lim',
  'Wijaya',
  'Yılmaz',
  'Demir',
  'Hosseini',
  'Karimi',
  'Andersson',
  'Larsen',
  'de Vries',
  'Novak',
  'Kowalski',
  'Papadopoulos',
];

IsoCode iso(String s) => IsoCode.values.byName(s);

/// A valid NSN for [country], derived from its example mobile number.
String? validNsn(String country) {
  final example = metadataExamplesByIsoCode[iso(country)]!.mobile;
  if (example.isEmpty) return null;
  for (var attempt = 0; attempt < 60; attempt++) {
    final keep = (example.length * 0.45).ceil();
    final nsn =
        example.substring(0, keep) +
        List.generate(example.length - keep, (_) => rnd.nextInt(10)).join();
    if (PhoneNumber(isoCode: iso(country), nsn: nsn).isValid()) return nsn;
  }
  return null;
}

String grouped(String digits) {
  final parts = <String>[];
  var i = 0;
  while (i < digits.length) {
    final size = (digits.length - i) <= 4 ? digits.length - i : 3;
    parts.add(digits.substring(i, i + size));
    i += size;
  }
  return parts.join(' ');
}

String pickCountry() {
  final total = weights.values.reduce((a, b) => a + b);
  var r = rnd.nextInt(total);
  for (final e in weights.entries) {
    if ((r -= e.value) < 0) return e.key;
  }
  return 'AE';
}

String formatted(String country, {bool allowNational = true}) {
  final nsn = validNsn(country)!;
  final cc = PhoneNumber(isoCode: iso(country), nsn: nsn).countryCode;
  final roll = rnd.nextDouble();
  if (allowNational && country == 'AE' && roll < 0.35) {
    return '0${nsn.substring(0, 2)} ${grouped(nsn.substring(2))}'; // national
  }
  if (roll < 0.12) return '00$cc ${grouped(nsn)}';
  if (roll < 0.20) return '+$cc$nsn';
  if (roll < 0.26) return '+$cc (${nsn.substring(0, 2)}) ${nsn.substring(2)}';
  return '+$cc ${grouped(nsn)}';
}

void main(List<String> args) {
  final count = int.parse(args.isEmpty ? '500' : args[0]);
  final out = StringBuffer();
  final usedNames = <String>{};
  final stats = <String, int>{};
  for (var i = 0; i < count; i++) {
    String name;
    do {
      name =
          '${first[rnd.nextInt(first.length)]} '
          '${last[rnd.nextInt(last.length)]}';
    } while (!usedNames.add(name) &&
        usedNames.length < first.length * last.length);

    final phones = <(String, String)>[];
    final roll = rnd.nextDouble();
    if (roll < 0.03) {
      phones.add(('CELL', '${1000 + rnd.nextInt(9000)}')); // unclassifiable
    } else {
      final country = pickCountry();
      stats[country] = (stats[country] ?? 0) + 1;
      phones.add(('CELL', formatted(country)));
      if (roll > 0.82) {
        // Second number: home country or another one.
        final second = rnd.nextBool() ? country : pickCountry();
        phones.add((rnd.nextBool() ? 'WORK' : 'HOME', formatted(second)));
      }
    }
    final parts = name.split(' ');
    out
      ..writeln('BEGIN:VCARD')
      ..writeln('VERSION:3.0')
      ..writeln('N:${parts.sublist(1).join(' ')};${parts.first};;;')
      ..writeln('FN:$name');
    for (final (type, number) in phones) {
      out.writeln('TEL;TYPE=$type:$number');
    }
    out.writeln('END:VCARD');
  }
  File(args.length > 1 ? args[1] : 'contacts.vcf').writeAsStringSync('$out');
  stderr.writeln('Generated $count contacts. Primary countries: $stats');
}
