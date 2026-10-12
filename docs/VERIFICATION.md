# Verification — 12 October 2026

- Flutter 3.47.7 / Dart 3.13.5: `flutter analyze --no-pub` passed with no issues.
- `flutter test --no-pub`: 8 tests passed (scanner state, frame validation, DICOM acceptance/rejection, PNG/model round trip, vault integrity, desktop capture, narrow layout).
- `flutter build web --no-pub --no-web-resources-cdn`: passed.
- `npm run check`: TypeScript check and 5 Worker tests passed.
- `npm run deploy:check`: Cloudflare packaging passed.
- `npm run deploy`: succeeded at https://blue-ultrasound.fokalview.workers.dev, version `6e632e50-9b6e-4604-b867-8aadb60188f2`.
- Live HTTP checks: application 200, health reports local-research/storage-disabled, study POST rejected with 503, frame protection header DENY.
- Browser check: start synthetic scanner, freeze, capture, library entry and viewer all verified; no captured warning/error console entries.
- Windows build attempt: blocked by missing symlink support. Flutter doctor also reports Visual Studio missing.
- Android debug build attempt: blocked because Android SDK is missing.

Native hardware, Android document export, Windows installer behavior and real vendor DICOM samples have not been tested. GitHub CI status is tracked separately from these local results.
