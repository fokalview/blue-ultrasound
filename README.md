# Blue Ultrasound

**Live research preview:** https://blue-ultrasound.fokalview.workers.dev

**Native builds:** Android debug APK and Windows release ZIP successfully built in [GitHub Actions run 38218185594](https://github.com/fokalview/blue-ultrasound/actions/runs/38218185594). The Linux artifact contains the Android APK plus the web build; the Windows artifact contains the desktop application. Extract the complete Windows directory and run `blue_ultrasound.exe`, keeping its DLLs and `data` folder together. These are unsigned/debug research packages, not store releases or hardware-validated medical software.

Open-source, local-first ultrasound research workspace for **Android, Windows and web**, with a Cloudflare-hostable web build. Original code: Apache-2.0.

**This is a working research preview, not a universal probe driver or a diagnostic application.** Real GE, Clarius and Butterfly connections are unavailable until supported SDKs and hardware are verified. The application labels synthetic data and never presents simulated connections as real.

## Working features

- Animated synthetic scanner with freeze/resume, capture and disconnect.
- Local PNG/JPEG and a limited uncompressed grayscale DICOM import, original-file preservation, zoom and multiframe preview.
- Searchable study library, PNG/original export, and passphrase-encrypted local vault with encrypted backup/restore.
- Responsive navigation for phones and desktops.
- Cloudflare Worker and static hosting configuration, health/capabilities API, and disabled study-upload endpoints.
- GitHub CI definitions for shared tests, Android debug APK, Windows build and web build.

No scan data is uploaded. Cloud study synchronization, authentication, real probe SDKs and the GE DICOM gateway are **not implemented**. See [exact format limits and implementation status](docs/IMPLEMENTATION_STATUS.md).

## Run locally

Use Flutter **3.47.7** and Node.js **24**. A project-local Flutter SDK was installed at `.tools/flutter` in this workspace and is excluded from Git. On Windows you can substitute its `bin/flutter.bat` and `bin/dart.bat` for the commands below.

```sh
cd apps/client
flutter pub get
flutter run -d chrome
```

Android: install/configure the Android SDK, attach an Android device or emulator, then `flutter run -d <device-id>`.
Windows: install Visual Studio's Desktop development with C++ workload and enable symlink support, then `flutter run -d windows`.

This machine currently has neither the Android SDK nor Visual Studio C++ tooling. Native projects are present; native builds have not passed here. With dependencies already resolved, `--no-pub` lets shared analysis, tests and web builds run without Windows plugin symlink setup.

## Verify

```sh
cd apps/client
flutter analyze --no-pub
flutter test --no-pub
flutter build web --no-pub --no-web-resources-cdn
cd ../..
npm ci
npm run check
npm run deploy:check
```

`npm run dev` serves the built web app and Worker at `http://127.0.0.1:8787`.

## Cloudflare deployment

Build the web app first using the command above. Wrangler serves `apps/client/build/web` through the `blue-ultrasound` Worker. It requires no database or object-storage bindings in this release.

```sh
npx wrangler login
npm run deploy
```

Use an account authorized for Worker/static asset deployments. Never put OAuth tokens in source files. There is no automatic deployment on push; the CI workflow only builds/tests. No cloud study resources are created by this configuration. The app bundles its Flutter rendering resources instead of fetching them from an external CDN.

## First use

1. Select **Start demo**, **Freeze**, then **Capture**.
2. Open **Studies**, select the capture, zoom or export it.
3. Use **Storage → Create vault** to retain studies after closing. A passphrase must be at least 12 characters. There is no passphrase recovery.
4. Save after changing the library, then lock. On reopening, unlock the local vault. Export a backup because browser storage can be cleared or run out of space.
5. Import only synthetic or reviewed de-identified files. See the supported DICOM subset before trying a vendor export.

## Project map

- `apps/client/lib/core`: scanner contract/demo, importer, study model, encrypted vault.
- `apps/client/lib/main.dart`: responsive workspace and viewer.
- `apps/client/android`, `windows`, `web`: platform projects.
- `services/api`: Cloudflare Worker and tests.
- `.github/workflows/ci.yml`: proposed build verification on GitHub.
- [Original design and roadmap](plans/blue-ultrasound.md).
- [Contribution guide](CONTRIBUTING.md).

Source: https://github.com/fokalview/blue-ultrasound. GitHub Actions builds and artifacts are available from the repository's Actions tab when the workflows succeed.
