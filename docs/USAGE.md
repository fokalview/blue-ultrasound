# Using Blue

[Open Blue](https://blue-ultrasound.fokalview.workers.dev) · [Source and builds](https://github.com/fokalview/blue-ultrasound) · [Editable Figma design](https://www.figma.com/design/JVAG6jYshsNxMfgio5eDVP)

The same workspace is built for Android, Windows and web. **This release supports synthetic scanning and local file review, not real probe acquisition.** Clarius is the primary integration target; GE is deferred. Open **Guide** inside Blue for searchable instructions.

## A complete first session

1. In **Workspace**, select **Start demo**. The image and status explicitly identify synthetic data.
2. Select **Freeze**, then **Capture**. Use **Resume** to continue, or **Disconnect** to stop. Captures remain in memory until saved.
3. Open **Studies**. Search by title, open a study, zoom, step through frames or play the fixed-rate preview. Export a rendered PNG or the original imported file using the viewer controls.
4. Open **Storage → Create vault**. Choose a passphrase with at least 12 characters and retain it securely; Blue has no recovery mechanism.
5. Save again after adding/removing studies. Export an encrypted backup, then lock the vault before leaving the device.
6. On reopening Blue, use **Storage → Unlock** to restore the saved library. Restore backup can recover a previously exported Blue vault with its passphrase; review the replacement confirmation.

Changing pages does not stop the demo. Backgrounding the application disconnects it; it does **not** automatically lock the vault. A stale source disables capture. Reconnect to resume. Closing without saving loses unsaved studies.

## Import a scan

Choose **Import scan** in Workspace or Studies. Select a synthetic or reviewed de-identified PNG, JPEG or DICOM file. The original is preserved for export. Blue does not remove identifying information from imported files.

| Format | Accepted subset |
|---|---|
| PNG/JPEG | Single image, up to 4 million pixels |
| DICOM | Part 10, Explicit VR Little Endian (1.2.840.10008.1.2.1), uncompressed unsigned 8/16-bit MONOCHROME1/2, one sample per pixel, standard bit alignment, no sequences |
| All input files | Up to 16 MiB each |
| DICOM multiframe | Up to 100 frames and 16 million total pixels |

Compressed or color ultrasound DICOM, MP4, RF/IQ files and unsupported encodings are rejected. A GE or Clarius export is accepted only if it matches this subset. DICOM previews normalize intensity and do not apply acquisition timing, geometry, modality/VOI LUTs or overlays. Cine playback is fixed at 8 fps. No calibrated measurement or diagnostic DICOM export is provided.

## Saving and exporting

The open workspace allows up to 100 studies or 16 MiB of combined study data. The serialized vault has a 24 MiB limit before encryption; browser quotas may be smaller. If storage is full, export a backup/studies before closing and remove unneeded items.

Vault encryption uses AES-256-GCM and a passphrase-derived key. The passphrase is not uploaded or stored persistently. It remains in app memory while unlocked. Encryption does not anonymize original files or imply clinical certification.

- **Android:** export opens the system document picker; choose a location and filename.
- **Windows:** choose an export destination in the save dialog.
- **Web:** the browser handles the download. Vault storage is tied to the browser profile and site origin. Clearing site data can delete the local vault.

Keep a separate encrypted backup. Removing a study affects the open library; save the vault to update its saved copy. Previously exported backups remain unchanged.

## Clarius usage and compatibility

Open **Devices → Read setup & usage**. The screen explains two future native connection routes:

- **Solum:** standalone control; requires commercial/OEM access, a licensed probe, certificate and matched firmware/runtime.
- **Cast:** image streaming and selected controls while the Clarius App controls the probe; requires matching SDK/App versions, a shared network and applicable feature licenses.

The guide covers connection lifecycle, imaging controls, raw data, IMU and maintenance. These are SDK capabilities and integration requirements, **not enabled Blue features**. See the [full Clarius coverage specification](CLARIUS.md), including the 73-function public C export inventory. No claim is made that all Clarius App AI, cloud, measurement or paid features are exposed by these SDKs.

## Install and run

Use the successful run for the latest source commit in [GitHub Actions](https://github.com/fokalview/blue-ultrasound/actions). The Linux artifact includes the Android debug APK and web build; Windows includes the release directory. These are research builds.

On Android, extract and install `app-debug.apk` on a compatible test device. On Windows, extract the **entire** Release directory and run `blue_ultrasound.exe`; keep DLLs and the `data` folder together. Native builds are unsigned/debug research packages and have not been interactively verified on physical devices. Consult [README](../README.md) for source builds.

Cloudflare serves the web app and read-only status/capability endpoints. No study upload, cloud sync or remote probe control is implemented. Native local review/demo can work offline; the web app must load first, and persistent offline browser operation is not guaranteed.

## Troubleshooting

| Symptom | Action |
|---|---|
| Empty viewport | Start demo; after backgrounding, reconnect |
| Capture unavailable | Start the source; reconnect if stale |
| Import rejected | Check the exact encoding, dimensions and limits above |
| Missing library after reopening | Unlock the saved vault; unsaved captures cannot be recovered |
| Wrong passphrase / damaged backup | Check the passphrase and use a known-good backup; no recovery bypass exists |
| Save fails | Keep app open; export data, check available storage, reduce library size |
| Clarius will not connect | Hardware adapter is not included; changing permissions cannot enable it |

For an issue report, include platform, app commit/build, steps, expected/actual behavior and a synthetic reproduction. Do not attach patient scans, passphrases, certificates or OEM API keys.
