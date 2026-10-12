# Implementation status

12 October 2026 — research preview 0.1

## Implemented

- Flutter app projects for Android, Windows and web, sharing the same workspace UI.
- Synthetic grayscale scanner at a target 8 fps; connect, freeze/resume, capture, disconnect; stale-frame indicator and capture prevention.
- Local PNG/JPEG import and a narrow Part 10 DICOM decoder; original file preservation; study search, zoom, frame stepping and fixed-rate preview playback.
- Passphrase-encrypted local vault (AES-256-GCM, fresh random salt/nonce, PBKDF2-HMAC-SHA256 with 210,000 iterations), explicit save/unlock/lock, encrypted backup/restore.
- PNG and original-file export. Android has a document-picker export bridge; Windows uses a save dialog; web uses download.
- Cloudflare Worker serves the web build, health and device-capability routes. All study writes are disabled; no D1/R2 resources, identities, or study uploads are configured.
- GitHub workflow definitions for Android debug APK, Windows release build, web build, tests, and Worker checks. Workflows have not yet run on GitHub.

## Supported file subset

PNG and JPEG: single-frame images, at most 4 megapixels. DICOM: Part 10 with transfer syntax 1.2.840.10008.1.2.1 (Explicit VR Little Endian), unsigned 8/16-bit MONOCHROME1/2, one sample per pixel, standard bit alignment, no sequences or encapsulated/compressed data. Maximum 100 frames and 16 megapixels total. All inputs must be at most 16 MiB.

DICOM previews use global min/max intensity normalization and do not apply modality LUTs, VOI LUTs, overlays, physical geometry, or acquisition timing. Preview playback is fixed at 8 fps and labeled accordingly. These are research previews, not diagnostic rendering or measurements. Many real ultrasound DICOM exports are compressed or color and will be rejected. No GE device has been tested.

## Storage limits

Open workspace: at most 100 studies and 16 MiB of combined originals/previews. Serialized vault limit: 24 MiB before encryption. Browser storage quotas may be smaller; save failure is reported and leaves the current workspace in memory. Keep exported backups. Native storage currently uses encrypted payloads in preferences, intended only for this bounded research preview; it is not the transactional database/outbox in the full plan.

The passphrase is never transmitted or saved. It stays in memory while unlocked; managed runtimes cannot guarantee memory zeroization. Saved data uses authenticated encryption, but this is not a claim of clinical/privacy certification. Backgrounding disconnects acquisition; explicit Lock clears open studies after changes are saved. Reopening starts locked. Closing before saving loses unsaved work.

## Remaining dependencies

Native builds require Android SDK and Visual Studio C++ tooling, respectively. Windows plugins also need symlink capability (typically Developer Mode). This machine currently lacks these prerequisites, so native binaries and the Android export bridge are unverified.

Real acquisition requires supported SDK access, exact probe model/firmware, and physical testing. Cloud study sync requires an identity provider, tenant authorization, upload/deletion protocol, private storage configuration, and the applicable data-handling agreements. GE DICOM gateway reception, MP4 import and calibrated measurements are not implemented.

## Plan mapping

Steps 1–2: code and shared/web verification implemented; native build acceptance still open.
Step 3: bounded research import/vault subset implemented; full DICOM/video support and transactional storage remain open.
Steps 4–5: deployable application shell and fail-closed API only; authenticated cloud study services remain open.
Steps 6–7: blocked on hardware/SDK/model access; no adapter or gateway is claimed complete.
Step 8: license, contribution docs and CI definitions implemented; signed native research release remains open.

Design adjustment: use the shared Flutter app as the first hosted workspace, rather than maintaining a separate web UI. This reduces divergence while preserving a future dedicated portal. Local passphrase encryption replaces platform-key integration for the bounded prototype; full native storage remains a later milestone.
