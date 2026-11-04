# Contacts Organizer

Browse your phone contacts grouped by the country of their phone numbers, then
call or WhatsApp them. Everything runs on-device; contacts are read-only and
never uploaded.

## Run

```bash
flutter pub get
flutter run                 # pick an iOS simulator / Android device
flutter test test           # unit + widget tests
flutter test integration_test -d <device-id>   # real url_launcher on a device
```

## How numbers are classified

`lib/features/contacts/domain/phone_classifier.dart`, using libphonenumber
metadata via `phone_numbers_parser`:

1. Formatting is stripped (spaces, brackets, hyphens, extensions); Arabic-Indic
   and Persian digits are converted.
2. `+…` numbers are classified by their country code. Shared codes (+1, +44, +7)
   are resolved by numbering-plan patterns, so `+1 416…` → Canada and
   `+44 7911…` → Guernsey.
3. National numbers (no `+`) are **only** interpreted with an explicit default
   region (device locale by default, changeable in Settings, or "Don't assume a
   region"). The default region's own exit code (`00`, `011`, …) is honoured,
   and all regions sharing its plan are tried.
4. Otherwise Android's E.164 `normalizedNumber` is used when present.
5. Anything that is not a valid number per metadata goes to **Unknown**.

Results are cached per (number, region); large address books are classified in
a background isolate (`precomputeClassifications`).

## Structure

```
lib/
  core/            theme, shared widgets
  features/
    contacts/      device access (data), classification + aggregation (domain),
                   Riverpod state, home / permission UI (presentation)
    countries/     Country model + names, country tile & screen
    contact_search/ precomputed search index, debounced query providers
    contact_details/ details screen
    communication/ tel: / wa.me link building, CommunicationService,
                   number picker, message composer
    duplicates/    contacts sharing a number or an identical name
    export/        CSV of selected contacts, shared via the OS share sheet
    settings/      theme + default region (shared_preferences)
```

## Duplicates

The home screen counts contacts that appear more than once and lists them in
groups:

- **Same phone number**: numbers match on E.164, so `+44 7400 123456`,
  `07400 123456` and `0044 7400 123456` are the same. Numbers with fewer than
  6 digits (service codes) are ignored.
- **Same name**: identical names, ignoring case and spacing. A name group with
  the same contacts as a phone group is not shown twice.

The app never merges or deletes anything: open a contact and tap **Edit** to
fix it in the system Contacts app.

## App icon

The icon artwork is drawn in code (`tool/icon/render_icon_test.dart`). To change it:

```bash
flutter test tool/icon/render_icon_test.dart   # writes assets/icon/*.png
dart run flutter_launcher_icons                # iOS + Android icon sets
```

## Releasing to TestFlight (iOS)

Configured: bundle ID `com.pbs.countryContact`, team `AY769555S5` (PlanB Solutions)
with automatic signing, iOS 15+ (built with Xcode 26 or later), `ITSAppUsesNonExemptEncryption = false`, an app
privacy manifest (`ios/Runner/PrivacyInfo.xcprivacy`) and `ios/ExportOptions.plist`.

1. In App Store Connect, create the app record with bundle ID `com.pbs.countryContact`.
2. Bump `version:` in `pubspec.yaml` (e.g. `1.0.0+2`); every upload needs a new build number.
3. Archive, either:
   - Xcode: open `ios/Runner.xcworkspace`, choose *Any iOS Device (arm64)*,
     *Product > Archive*, then *Distribute App > App Store Connect > Upload*.
   - CLI: `flutter build ipa --export-options-plist=ios/ExportOptions.plist`,
     then drag `build/ios/ipa/*.ipa` into Apple's Transporter app.
