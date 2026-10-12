import 'package:flutter/material.dart';

const usageTopics = <({String title, String body})>[
  (
    title: 'Start here',
    body:
        'Blue is a local research workspace for Android, Windows and web. Start demo creates synthetic images; it does not connect to a probe. Real Clarius acquisition is not enabled in this release. GE is deferred. Use reviewed de-identified or synthetic files only.',
  ),
  (
    title: 'Scan, freeze and capture',
    body:
        'Open Workspace → Start demo. Freeze pauses the synthetic stream; Resume restarts it. Capture adds the current frame to Studies. Disconnect clears the viewport. Switching away from the app disconnects the source. A stale stream disables capture: reconnect before continuing. The demo has no calibrated measurements.',
  ),
  (
    title: 'Import and review a study',
    body:
        'Choose Import scan and select PNG, JPEG or a supported .dcm file. Open Studies to search, view, zoom and export. Multiframe DICOM has a preview player at a fixed 8 frames per second, not the original acquisition timing. Original-file export preserves the supplied file; PNG export is a rendered image, not a diagnostic DICOM export.',
  ),
  (
    title: 'Supported file formats',
    body:
        'Maximum input: 16 MiB. PNG/JPEG: a single image up to 4 million pixels. DICOM: Explicit VR Little Endian, uncompressed, unsigned 8/16-bit monochrome; up to 100 frames and 16 million total pixels. Compressed DICOM, sequences, color DICOM and unsupported encodings are rejected. A vendor name alone does not guarantee that its export is supported.',
  ),
  (
    title: 'Save, lock and back up',
    body:
        'Studies stay in memory until you explicitly save. Open Storage → Create vault and choose a passphrase of at least 12 characters. Save again after captures, imports or removals. Lock clears the open library. Unlock restores the saved copy. Export an encrypted backup before clearing app/browser storage. There is no passphrase recovery. Lock manually before handing over the device; backgrounding does not lock the vault.',
  ),
  (
    title: 'Restore and storage limits',
    body:
        'Restore backup accepts a Blue encrypted backup and its passphrase. Review the replacement confirmation. Workspace limit: 100 studies or 16 MiB of study data. Browser quotas may be smaller. If saving fails, export studies or a backup before closing. Android uses the system document picker for exports; Windows lets you choose a destination; the web browser handles downloads.',
  ),
  (
    title: 'Clarius: choose Solum or Cast',
    body:
        'Solum is the route to a standalone Blue scanner: it provides connectivity and imaging control without the Clarius App. It requires Clarius commercial-partner access, an OEM license per probe, a certificate and matching firmware. Cast receives images while the Clarius App remains connected to the probe. Its desktop C API and Android Java interface are different integrations. These are integration requirements, not working Blue connection instructions.',
  ),
  (
    title: 'Clarius: direct connection sequence',
    body:
        'For a future native Solum adapter: initialize the SDK; use platform Bluetooth to discover/power the probe and obtain its Wi-Fi endpoint; join the probe network; connect; wait for the connection callback; provide the probe certificate; check certificate and firmware status; enumerate probe applications; load one; start imaging. A successful request is not proof of connection. Blue must wait for callbacks and valid frames. Never put OEM API keys in the website or public source.',
  ),
  (
    title: 'Clarius: imaging and controls',
    body:
        'The Solum interface exposes mode selection, depth/gain and other parameters, parameter ranges, TGC, color ROI, Doppler gate, output dimensions and format, overlays, start/freeze and status. Availability depends on the probe, application, firmware and license. Controls must use reported ranges and acknowledge SDK results. These controls are not yet implemented in Blue; the demo cannot validate them.',
  ),
  (
    title: 'Clarius: raw data and motion',
    body:
        'Clarius documents processed images, pre-scan/raw frames, spectral frames and IMU callbacks. Buffered RF/IQ downloads require the supported frozen workflow and may need additional licensing. Some real-time RF paths are available under specific settings. Raw research data must retain timing, geometry and units; it must not be treated as a PNG. Blue currently imports neither RF/IQ files nor IMU streams.',
  ),
  (
    title: 'Clarius: maintenance and advanced research',
    body:
        'Solum exposes certificate and firmware handling, power-down, probe settings, Wi-Fi optimization/reset, acoustic indices, IMU calibration and battery checks. Some procedures require a frozen probe. Low-level parameter/pulse APIs can operate outside vendor-tested limits and need a separately validated research workflow. None of these device-changing operations is performed by Blue today.',
  ),
  (
    title: 'What full Clarius support still needs',
    body:
        'The native Android and Windows adapters, Bluetooth discovery, SDK runtime packaging, callback-safe image transport, all supported control/data paths and physical probe tests remain to be implemented. Solum does not provide Clarius Cloud, DICOM, measurements or reporting. Those require separate integrations. A header function existing does not mean Blue or every probe supports it. AI and paid Clarius App features cannot be assumed to be exposed by the SDK.',
  ),
  (
    title: 'Cloudflare, privacy and offline use',
    body:
        'Cloudflare serves the web application. It does not receive studies, vault passphrases or OEM credentials from Blue. Cloud sync and study upload endpoints are disabled. Native apps can run the demo and local review without internet. The website needs to load first; offline browser installation is not guaranteed. Local storage belongs to the browser profile and site origin.',
  ),
  (
    title: 'Troubleshooting',
    body:
        'No image: start the demo, or reconnect after backgrounding. Import rejected: check the format and limits above. Vault will not unlock: check the passphrase and backup; there is no reset that preserves encrypted data. Missing studies after reopening: unlock the saved vault; unsaved captures cannot be recovered. Clarius does not connect: this release has no hardware adapter, so changing Wi-Fi permissions will not enable it.',
  ),
];

class UsageGuide extends StatefulWidget {
  const UsageGuide({super.key});
  @override
  State<UsageGuide> createState() => _UsageGuideState();
}

class _UsageGuideState extends State<UsageGuide> {
  String query = '';
  @override
  Widget build(BuildContext context) {
    final topics = usageTopics.where(
      (t) => '${t.title} ${t.body}'.toLowerCase().contains(query.toLowerCase()),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          onChanged: (v) => setState(() => query = v.trim()),
          decoration: const InputDecoration(
            labelText: 'Search the guide',
            hintText: 'Clarius, vault, DICOM…',
            prefixIcon: Icon(Icons.search),
          ),
        ),
        const SizedBox(height: 20),
        if (topics.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'No matching topics. Try “Clarius”, “import” or “save”.',
            ),
          ),
        for (final topic in topics)
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            elevation: 0,
            color: Colors.white,
            child: ExpansionTile(
              key: ValueKey(topic.title),
              title: Text(topic.title),
              childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              expandedCrossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SelectableText(
                  topic.body,
                  style: const TextStyle(height: 1.65),
                ),
              ],
            ),
          ),
        const SizedBox(height: 16),
        const SelectableText(
          'Source references: github.com/clariusdev/solum · github.com/clariusdev/cast\nSDK reference snapshot: Solum 12.2.4. Hardware support is unverified.',
          style: TextStyle(color: Color(0xff53657d), height: 1.6),
        ),
      ],
    );
  }
}

class ClariusDevices extends StatelessWidget {
  const ClariusDevices({super.key, required this.onGuide});
  final VoidCallback onGuide;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xff102541),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'CLARIUS / PRIMARY INTEGRATION',
              style: TextStyle(
                color: Color(0xff9fc7ff),
                letterSpacing: 1.4,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'One workspace. A clear connection path.',
              style: TextStyle(
                color: Colors.white,
                fontSize: 25,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Direct hardware connection is not available in this build. Solum is the planned standalone integration; Cast is the companion streaming route.',
              style: TextStyle(color: Color(0xffd5e2f3), height: 1.6),
            ),
            const SizedBox(height: 18),
            FilledButton.tonalIcon(
              onPressed: onGuide,
              icon: const Icon(Icons.menu_book_outlined),
              label: const Text('Read setup & usage'),
            ),
          ],
        ),
      ),
      const SizedBox(height: 20),
      for (final item in const [
        (
          'Solum · Direct probe control',
          'NOT IMPLEMENTED',
          'Android and Windows SDK routes. Requires OEM access, a licensed probe, certificate, matching firmware and native Bluetooth/Wi-Fi integration.',
        ),
        (
          'Cast · Companion streaming',
          'NOT IMPLEMENTED',
          'Keep the Clarius App connected to the probe. Devices share a wireless network. SDK/App versions must match; research features may require separate licenses.',
        ),
        (
          'Synthetic demo',
          'AVAILABLE',
          'Local generated images. Start, freeze, resume, capture and review without a probe. No calibrated measurements.',
        ),
        (
          'GE Vscan Air',
          'DEFERRED',
          'GE integration is outside the current Clarius-first scope. Supported files can be imported manually.',
        ),
      ])
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Card(
            elevation: 0,
            color: Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.$1, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text(
                    item.$2,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                      color: Color(0xff53657d),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(item.$3, style: const TextStyle(height: 1.6)),
                ],
              ),
            ),
          ),
        ),
    ],
  );
}
