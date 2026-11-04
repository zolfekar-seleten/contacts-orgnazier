import 'package:country_contacts/features/contacts/domain/phone_classification.dart';
import 'package:country_contacts/features/contacts/domain/phone_classifier.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('normalizePhoneInput', () {
    test('strips spaces, brackets, hyphens and dots', () {
      expect(normalizePhoneInput('+44 (20) 7946-0958'), '+442079460958');
      expect(normalizePhoneInput('050.123.4567'), '0501234567');
    });

    test('keeps only a leading plus', () {
      expect(normalizePhoneInput('00+971 50'), '0097150');
      expect(normalizePhoneInput(' +1 650'), '+1650');
    });

    test('converts Arabic-Indic and Persian digits', () {
      expect(normalizePhoneInput('+٩٧١ ٥٠ ١٢٣ ٤٥٦٧'), '+971501234567');
      expect(normalizePhoneInput('۰۹۱۲'), '0912');
    });

    test('drops extensions and DTMF pauses', () {
      expect(normalizePhoneInput('+1 650-253-0000 ext. 123'), '+16502530000');
      expect(normalizePhoneInput('+1 650 253 0000,,123'), '+16502530000');
      expect(normalizePhoneInput('+1 650 253 0000 x12'), '+16502530000');
    });
  });

  group('international numbers', () {
    final classifier = PhoneClassifier();

    final cases = {
      '+44 7400 123456': ('GB', '+447400123456'),
      '+44 7911 123456': ('GG', '+447911123456'),
      '+1 650-253-0000': ('US', '+16502530000'),
      '+1 416 555 0123': ('CA', '+14165550123'),
      '+971 50 123 4567': ('AE', '+971501234567'),
      '+91 98765 43210': ('IN', '+919876543210'),
      '+44 (0)20 7946 0958': ('GB', '+442079460958'),
      '+7 701 123 4567': ('KZ', '+77011234567'),
      '+7 912 345 6789': ('RU', '+79123456789'),
    };
    cases.forEach((input, expected) {
      test('$input -> ${expected.$1}', () {
        final result = classifier.classify(input);
        expect(result.isoCode, expected.$1);
        expect(result.e164, expected.$2);
        expect(result.source, ClassificationSource.international);
      });
    });

    test('00 prefix is international even without a default region', () {
      final result = classifier.classify('00971501234567');
      expect(result.isoCode, 'AE');
      expect(result.e164, '+971501234567');
    });
  });

  group('national-format numbers', () {
    test('are Unknown (ambiguous) without a default region', () {
      final result = PhoneClassifier().classify('050 123 4567');
      expect(result.isClassified, isFalse);
      expect(result.reason, UnknownReason.ambiguousNationalFormat);
    });

    test('use the default region when one is set', () {
      final result = PhoneClassifier(
        defaultRegion: 'AE',
      ).classify('050 123 4567');
      expect(result.isoCode, 'AE');
      expect(result.e164, '+971501234567');
      expect(result.source, ClassificationSource.defaultRegion);
    });

    test('same digits resolve differently per region', () {
      expect(
        PhoneClassifier(defaultRegion: 'GB').classify('07400 123456').isoCode,
        'GB',
      );
      expect(
        PhoneClassifier(
          defaultRegion: 'AE',
        ).classify('07400 123456').isClassified,
        isFalse,
      );
    });

    test('resolves regions sharing the caller numbering plan', () {
      expect(
        PhoneClassifier(defaultRegion: 'US').classify('(416) 555-0123').isoCode,
        'CA',
      );
      expect(
        PhoneClassifier(defaultRegion: 'GB').classify('07911 123456').isoCode,
        'GG',
      );
    });

    test('region exit code is treated as international', () {
      final result = PhoneClassifier(
        defaultRegion: 'US',
      ).classify('011 44 7400 123456');
      expect(result.isoCode, 'GB');
      expect(result.source, ClassificationSource.international);
    });

    test('falls back to platform E.164 normalization', () {
      final result = PhoneClassifier().classify(
        '050 123 4567',
        platformNormalized: '+971501234567',
      );
      expect(result.isoCode, 'AE');
      expect(result.source, ClassificationSource.platformNormalized);
    });

    test('default region wins over platform normalization', () {
      final result = PhoneClassifier(
        defaultRegion: 'GB',
      ).classify('07400 123456', platformNormalized: '+971501234567');
      expect(result.isoCode, 'GB');
    });
  });

  group('invalid numbers', () {
    final classifier = PhoneClassifier(defaultRegion: 'GB');

    test('empty and very short input are unparseable', () {
      expect(classifier.classify('').reason, UnknownReason.unparseable);
      expect(classifier.classify('12').reason, UnknownReason.unparseable);
      expect(classifier.classify('abc').reason, UnknownReason.unparseable);
    });

    test('numbers invalid per metadata are Unknown', () {
      expect(classifier.classify('+44 123').reason, UnknownReason.invalid);
      expect(classifier.classify('+999 1234567').isClassified, isFalse);
      expect(classifier.classify('12345').isClassified, isFalse);
    });

    test('overlong input does not throw', () {
      expect(
        classifier.classify('+1234567890123456789012345').isClassified,
        isFalse,
      );
    });
  });

  group('caching', () {
    test('classifies each distinct number once', () {
      final classifier = PhoneClassifier();
      classifier.classify('+44 7911 123456');
      classifier.classify('+44 7911 123456');
      expect(classifier.cacheSize, 1);
      classifier.classify('+44 7911 123456', platformNormalized: '+1');
      expect(classifier.cacheSize, 2);
    });
  });
}
