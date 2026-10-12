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

GitHub run [38218185594](https://github.com/fokalview/blue-ultrasound/actions/runs/38218185594) successfully built the Windows release after passing analysis and tests on Windows. Downloaded artifact `blue-Windows-research` SHA-256 matched `72f73ab01b86089d09354c7ebfb8939a76459d3485fd95a9e419345e34e2cab6`. This confirms compilation/package integrity, not interactive native-device testing.

The same run finished successfully for all three jobs: Worker, Flutter on Linux (including Android debug APK and web build), and Flutter on Windows. Android/web artifact SHA-256 matched `9fb9cd9f4101d3349530a92935e53e4657e9d7d317d9d035ae52f9d5112156e0`. Local handoff packages are `artifacts/Blue-Android-debug.apk` and `artifacts/Blue-Windows.zip`; they are excluded from source control. The APK was extracted directly from the verified artifact.

Deployed browser verification also covered a 390×844 phone viewport. Desktop and phone screenshots are saved under `artifacts/`. Temporary SDK debug-symbol files were reversibly NTFS-compressed to recover disk space; their contents were retained.
