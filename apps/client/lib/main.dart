import 'dart:async';
import 'dart:convert';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'core/importer.dart';
import 'core/scanner.dart';
import 'core/study.dart';
import 'core/vault.dart';
import 'guide.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const BlueApp());
}

class BlueApp extends StatelessWidget {
  const BlueApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Blue Ultrasound',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff185ecb)),
      scaffoldBackgroundColor: const Color(0xfff3f6fb),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48)),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
      ),
    ),
    home: const Workspace(),
  );
}

class Workspace extends StatefulWidget {
  const Workspace({super.key});
  @override
  State<Workspace> createState() => _WorkspaceState();
}

class _WorkspaceState extends State<Workspace> with WidgetsBindingObserver {
  final scanner = DemoScanner();
  final vault = StudyVault();
  final frame = ValueNotifier<Uint8List?>(null);
  final studies = <Study>[];
  StreamSubscription<ScanFrame>? frameSub;
  StreamSubscription<ScanState>? stateSub;
  Timer? watchdog;
  DateTime? lastFrame;
  var page = 0;
  var busy = false;
  var stale = false;
  var hasVault = false;
  var dirty = false;
  String? unlockedPassphrase;
  String search = '';
  String status = 'Local only · Nothing uploaded';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    frameSub = scanner.frames.listen((value) {
      lastFrame = value.acquiredAt;
      if (stale && mounted) setState(() => stale = false);
      frame.value = grayscalePng(value.pixels, value.width, value.height);
    });
    stateSub = scanner.states.listen((state) {
      if (!mounted) return;
      if (state == ScanState.disconnected) {
        frame.value = null;
        lastFrame = null;
      }
      setState(() => stale = false);
    });
    watchdog = Timer.periodic(const Duration(seconds: 1), (_) {
      final timestamp = lastFrame;
      final expired =
          scanner.state == ScanState.streaming &&
          (timestamp == null ||
              DateTime.now().difference(timestamp) >
                  const Duration(seconds: 2));
      if (mounted && expired != stale) setState(() => stale = expired);
    });
    vault.exists().then((value) {
      if (mounted) setState(() => hasVault = value);
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      scanner.disconnect();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    watchdog?.cancel();
    frameSub?.cancel();
    stateSub?.cancel();
    scanner.dispose();
    frame.dispose();
    super.dispose();
  }

  void message(String text) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    }
  }

  Future<void> action(Future<void> Function() operation) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await operation();
    } on FormatException catch (error) {
      message(error.message);
    } catch (_) {
      message(
        'The operation could not finish. Check the file, passphrase, or available storage and try again.',
      );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void addStudy(Study study) {
    if (studies.any((s) => s.id == study.id)) {
      message('This frame is already captured.');
      return;
    }
    final bytes =
        studies.fold(0, (total, s) => total + s.byteSize) + study.byteSize;
    if (bytes > 16 * 1024 * 1024 || studies.length >= 100) {
      message(
        'Workspace limit reached (16 MiB or 100 studies). Export and remove studies first.',
      );
      return;
    }
    setState(() {
      studies.insert(0, study);
      dirty = true;
      status = 'Unsaved changes · Save vault to keep them';
    });
    message(
      'Added to this workspace. Save your vault to keep it after closing.',
    );
  }

  Future<void> importFile() => action(() async {
    final selected = await openFile(
      acceptedTypeGroups: [
        const XTypeGroup(
          label: 'Research scans',
          extensions: ['png', 'jpg', 'jpeg', 'dcm'],
        ),
      ],
    );
    if (selected == null) return;
    if (await selected.length() > maxImportBytes) {
      throw const FormatException('File exceeds the 16 MiB import limit.');
    }
    final bytes = await selected.readAsBytes();
    final study = await compute(_importInWorker, (bytes, selected.name));
    if (mounted) addStudy(study);
  });
  Future<String?> passphrase({required bool creating}) async {
    final first = TextEditingController(), second = TextEditingController();
    String? error;
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, update) => AlertDialog(
          title: Text(
            creating ? 'Create an encrypted vault' : 'Unlock your local vault',
          ),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Use at least 12 characters. Keep your passphrase safe: there is no password recovery. Encryption protects saved copies; open studies remain in memory.',
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: first,
                  obscureText: true,
                  autofocus: true,
                  autocorrect: false,
                  enableSuggestions: false,
                  decoration: const InputDecoration(labelText: 'Passphrase'),
                ),
                if (creating) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: second,
                    obscureText: true,
                    autocorrect: false,
                    enableSuggestions: false,
                    decoration: const InputDecoration(
                      labelText: 'Repeat passphrase',
                    ),
                  ),
                ],
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      error!,
                      style: TextStyle(color: Theme.of(ctx).colorScheme.error),
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (first.text.length < 12 ||
                    (creating && first.text != second.text)) {
                  update(
                    () =>
                        error = 'Use 12+ characters and matching passphrases.',
                  );
                  return;
                }
                Navigator.pop(ctx, first.text);
              },
              child: Text(creating ? 'Create vault' : 'Unlock'),
            ),
          ],
        ),
      ),
    );
    // Controllers are disposed after the dialog exit animation no longer uses them.
    await Future<void>.delayed(const Duration(milliseconds: 250));
    first.dispose();
    second.dispose();
    return result;
  }

  Future<void> saveVault() => action(() async {
    if (hasVault && unlockedPassphrase == null) {
      message(
        'Unlock the existing vault before saving, so saved studies are preserved.',
      );
      return;
    }
    final password = unlockedPassphrase ?? await passphrase(creating: true);
    if (password == null || !mounted) return;
    await vault.save(List.of(studies), password);
    if (mounted) {
      setState(() {
        unlockedPassphrase = password;
        hasVault = true;
        dirty = false;
        status = 'Encrypted vault saved on this device';
      });
    }
  });
  Future<void> unlockVault() => action(() async {
    final password = await passphrase(creating: false);
    if (password == null) return;
    final stored = await vault.load(password);
    if (!mounted) return;
    final ids = studies.map((s) => s.id).toSet();
    final merged = [...studies, ...stored.where((s) => !ids.contains(s.id))];
    if (merged.length > 100 ||
        merged.fold<int>(0, (n, s) => n + s.byteSize) > 16 * 1024 * 1024) {
      throw const FormatException(
        'Combined workspace exceeds the limit. Export or remove unsaved studies before unlocking.',
      );
    }
    setState(() {
      studies
        ..clear()
        ..addAll(merged);
      unlockedPassphrase = password;
      status = dirty
          ? 'Vault unlocked · Unsaved changes remain'
          : 'Local vault unlocked';
    });
  });
  Future<void> lockVault() async {
    if (dirty) {
      message('Save the vault before locking to preserve your changes.');
      return;
    }
    await scanner.disconnect();
    if (mounted) {
      setState(() {
        studies.clear();
        unlockedPassphrase = null;
        status = 'Vault locked';
      });
    }
  }

  Future<void> exportFile(Uint8List bytes, String name, String mime) async {
    if (kIsWeb) {
      await XFile.fromData(bytes, mimeType: mime, name: name).saveTo(name);
    } else if (defaultTargetPlatform == TargetPlatform.android) {
      await const MethodChannel('blue/export').invokeMethod<bool>('save', {
        'bytes': bytes,
        'name': name,
        'mime': mime,
      });
    } else {
      final location = await getSaveLocation(suggestedName: name);
      if (location != null) {
        await XFile.fromData(
          bytes,
          mimeType: mime,
          name: name,
        ).saveTo(location.path);
      }
    }
  }

  Future<void> exportBackup() => action(() async {
    final password = unlockedPassphrase;
    if (password == null) {
      message('Save or unlock your vault first.');
      return;
    }
    await exportFile(
      await vault.backup(studies, password),
      'blue-vault.bluevault',
      'application/octet-stream',
    );
  });
  Future<void> restoreBackup() => action(() async {
    if (studies.isNotEmpty ||
        dirty ||
        (hasVault && unlockedPassphrase == null)) {
      message(
        'Restore into an empty workspace with any existing vault unlocked. Export your current studies first.',
      );
      return;
    }
    final selected = await openFile(
      acceptedTypeGroups: [
        const XTypeGroup(
          label: 'Encrypted Blue vault',
          extensions: ['bluevault'],
        ),
      ],
    );
    if (selected == null) return;
    if (await selected.length() > StudyVault.maxBytes * 2) {
      throw const FormatException('Backup is too large.');
    }
    final password = await passphrase(creating: false);
    if (password == null) return;
    final restored = await vault.decrypt(
      utf8.decode(await selected.readAsBytes()),
      password,
    );
    if (restored.length > 100 ||
        restored.fold<int>(0, (n, s) => n + s.byteSize) > 16 * 1024 * 1024) {
      throw const FormatException('Backup exceeds workspace limits.');
    }
    if (mounted) {
      setState(() {
        studies.addAll(restored);
        dirty = true;
        status = 'Backup restored to memory · Save vault to keep it';
      });
    }
  });

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 840;
    final titles = [
      'Scan workspace',
      'Study library',
      'Devices & connections',
      'Your local vault',
      'Setup & usage',
    ];
    final bodies = <Widget>[
      _ScanPage(
        scanner: scanner,
        frame: frame,
        stale: stale,
        busy: busy,
        onConnect: () => action(scanner.connect),
        onDisconnect: () => action(scanner.disconnect),
        onFreeze: () {
          if (scanner.state == ScanState.frozen) {
            scanner.resume();
          } else {
            scanner.freeze();
          }
        },
        onCapture: () => addStudy(Study.capture(scanner.capture())),
        onImport: importFile,
        onLibrary: () => setState(() => page = 1),
        onDevices: () => setState(() => page = 2),
        count: studies.length,
      ),
      _Library(
        studies: studies,
        search: search,
        onSearch: (value) => setState(() => search = value),
        onImport: busy ? null : importFile,
        onOpen: (study) => showDialog<void>(
          context: context,
          builder: (_) => StudyViewer(study: study, export: exportFile),
        ),
        onDelete: (study) async {
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Remove study?'),
              content: const Text(
                'This removes it from the open workspace. Save the vault afterward to update the saved copy. Existing exported backups are unchanged.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Remove'),
                ),
              ],
            ),
          );
          if (confirmed == true && mounted) {
            setState(() {
              studies.remove(study);
              dirty = true;
              status = 'Study removed · Save vault to update saved copy';
            });
          }
        },
      ),
      ClariusDevices(onGuide: () => setState(() => page = 4)),
      _StoragePage(
        hasVault: hasVault,
        unlocked: unlockedPassphrase != null,
        dirty: dirty,
        busy: busy,
        onSave: saveVault,
        onUnlock: unlockVault,
        onLock: lockVault,
        onBackup: exportBackup,
        onRestore: restoreBackup,
      ),
      const UsageGuide(),
    ];
    return Scaffold(
      body: SafeArea(
        child: Row(
          children: [
            if (wide)
              Container(
                width: 216,
                color: const Color(0xff102541),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Padding(
                      padding: EdgeInsets.fromLTRB(24, 34, 24, 30),
                      child: Text(
                        '◒ blue',
                        style: TextStyle(
                          fontSize: 36,
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    for (var i = 0; i < _labels.length; i++)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        child: TextButton.icon(
                          style: TextButton.styleFrom(
                            alignment: Alignment.centerLeft,
                            minimumSize: const Size(48, 52),
                            foregroundColor: Colors.white,
                            backgroundColor: page == i
                                ? const Color(0xff29476e)
                                : Colors.transparent,
                          ),
                          onPressed: () => setState(() => page = i),
                          icon: Icon(_icons[i]),
                          label: Text(_labels[i]),
                        ),
                      ),
                    const Spacer(),
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'OPEN-SOURCE ULTRASOUND\nResearch preview 0.1\nAndroid · Windows · Web',
                        style: TextStyle(
                          color: Color(0xffbdcfe5),
                          height: 1.8,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: Column(
                children: [
                  if (busy) const LinearProgressIndicator(minHeight: 3),
                  Expanded(
                    child: ListView(
                      padding: EdgeInsets.all(wide ? 32 : 16),
                      children: [
                        Text(
                          'BLUE / RESEARCH WORKSPACE',
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(
                                letterSpacing: 1.5,
                                color: const Color(0xff53657d),
                              ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          titles[page],
                          style: Theme.of(context).textTheme.headlineMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          status,
                          style: TextStyle(
                            color: dirty
                                ? const Color(0xff985d05)
                                : const Color(0xff53657d),
                          ),
                        ),
                        const SizedBox(height: 20),
                        bodies[page],
                        const SizedBox(height: 20),
                        const Text(
                          'Research preview · Synthetic or de-identified files only. Hardware acquisition is not enabled.',
                          style: TextStyle(
                            color: Color(0xff53657d),
                            fontSize: 12,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: wide
          ? null
          : NavigationBar(
              selectedIndex: page,
              onDestinationSelected: (value) => setState(() => page = value),
              destinations: [
                for (var i = 0; i < _labels.length; i++)
                  NavigationDestination(
                    icon: Icon(_icons[i]),
                    label: _labels[i],
                  ),
              ],
            ),
    );
  }
}

const _labels = ['Workspace', 'Studies', 'Devices', 'Storage', 'Guide'];
const _icons = [
  Icons.monitor_heart_outlined,
  Icons.folder_outlined,
  Icons.sensors,
  Icons.lock_outline,
  Icons.menu_book_outlined,
];
Study _importInWorker((Uint8List, String) args) =>
    importStudy(args.$1, args.$2);

class _Card extends StatelessWidget {
  const _Card({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    elevation: 0,
    color: Colors.white,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: const BorderSide(color: Color(0xffdce4ef)),
    ),
    child: Padding(padding: const EdgeInsets.all(20), child: child),
  );
}

class _ScanPage extends StatelessWidget {
  const _ScanPage({
    required this.scanner,
    required this.frame,
    required this.stale,
    required this.busy,
    required this.onConnect,
    required this.onDisconnect,
    required this.onFreeze,
    required this.onCapture,
    required this.onImport,
    required this.onLibrary,
    required this.onDevices,
    required this.count,
  });
  final DemoScanner scanner;
  final ValueListenable<Uint8List?> frame;
  final bool stale, busy;
  final VoidCallback onConnect,
      onDisconnect,
      onFreeze,
      onCapture,
      onImport,
      onLibrary,
      onDevices;
  final int count;
  @override
  Widget build(BuildContext context) {
    final connected = scanner.state != ScanState.disconnected;
    final frozen = scanner.state == ScanState.frozen;
    final label = stale
        ? 'STALE · reconnect the source'
        : frozen
        ? 'SIMULATED · FROZEN'
        : connected
        ? 'SIMULATED · 8 FPS'
        : 'NO SOURCE CONNECTED';
    final scan = _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Demo scanning',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              const Chip(label: Text('SYNTHETIC')),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            height: MediaQuery.sizeOf(context).width >= 1100 ? 440 : 340,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: const Color(0xff07111e),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  child: ValueListenableBuilder<Uint8List?>(
                    valueListenable: frame,
                    builder: (_, bytes, _) => bytes == null
                        ? const Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.sensors,
                                  size: 54,
                                  color: Color(0xff8cabc9),
                                ),
                                SizedBox(height: 14),
                                Text(
                                  'Ready when you are\nStart a synthetic scan to explore Blue',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.white),
                                ),
                              ],
                            ),
                          )
                        : Image.memory(
                            bytes,
                            gaplessPlayback: true,
                            fit: BoxFit.contain,
                            filterQuality: FilterQuality.none,
                            semanticLabel:
                                'Synthetic ultrasound-like pattern, not anatomy',
                          ),
                  ),
                ),
                Positioned(
                  top: 12,
                  left: 14,
                  right: 14,
                  child: Container(
                    color: const Color(0xcc07111e),
                    padding: const EdgeInsets.all(6),
                    child: Text(
                      label,
                      style: TextStyle(
                        color: stale ? Colors.orangeAccent : Colors.white,
                        fontSize: 12,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ),
                const Positioned(
                  bottom: 12,
                  left: 14,
                  child: Text(
                    'DEMO / NO CALIBRATED MEASUREMENTS',
                    style: TextStyle(color: Color(0xffbdcfe5), fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              if (!connected)
                FilledButton.icon(
                  onPressed: busy ? null : onConnect,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Start demo'),
                ),
              if (connected)
                FilledButton.icon(
                  onPressed: busy || stale ? null : onFreeze,
                  icon: Icon(frozen ? Icons.play_arrow : Icons.pause),
                  label: Text(frozen ? 'Resume' : 'Freeze'),
                ),
              OutlinedButton.icon(
                onPressed: connected && !busy && !stale ? onCapture : null,
                icon: const Icon(Icons.camera_alt_outlined),
                label: const Text('Capture'),
              ),
              if (connected)
                OutlinedButton(
                  onPressed: busy ? null : onDisconnect,
                  child: const Text('Disconnect'),
                ),
              OutlinedButton.icon(
                onPressed: busy ? null : onImport,
                icon: const Icon(Icons.file_open_outlined),
                label: const Text('Import scan'),
              ),
              TextButton(onPressed: onLibrary, child: Text('Studies ($count)')),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Capture a frame, review it in Studies, then save your vault. Clarius setup requirements are in Devices → Read setup & usage.',
            style: TextStyle(color: Color(0xff53657d), height: 1.5),
          ),
        ],
      ),
    );
    final source = _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'YOUR SOURCE',
            style: TextStyle(
              fontSize: 11,
              letterSpacing: 1.4,
              color: Color(0xff53657d),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Clarius',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          const Text(
            'Hardware adapter pending',
            style: TextStyle(color: Color(0xff53657d)),
          ),
          const SizedBox(height: 20),
          const Text(
            'Solum for direct control. Cast for companion streaming. See the requirements and supported SDK capabilities.',
            style: TextStyle(height: 1.6),
          ),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: onDevices,
            icon: const Icon(Icons.sensors),
            label: const Text('Setup & capabilities'),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Divider(),
          ),
          const Text(
            'AVAILABLE NOW',
            style: TextStyle(
              fontSize: 11,
              letterSpacing: 1.4,
              color: Color(0xff53657d),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Synthetic scanning\nLocal file import\nEncrypted study vault',
            style: TextStyle(height: 2),
          ),
        ],
      ),
    );
    return LayoutBuilder(
      builder: (context, constraints) => constraints.maxWidth >= 1000
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: scan),
                const SizedBox(width: 20),
                SizedBox(width: 284, child: source),
              ],
            )
          : Column(children: [scan, const SizedBox(height: 16), source]),
    );
  }
}

class _Library extends StatelessWidget {
  const _Library({
    required this.studies,
    required this.search,
    required this.onSearch,
    required this.onImport,
    required this.onOpen,
    required this.onDelete,
  });
  final List<Study> studies;
  final String search;
  final ValueChanged<String> onSearch;
  final VoidCallback? onImport;
  final ValueChanged<Study> onOpen, onDelete;
  @override
  Widget build(BuildContext context) {
    final filtered = studies
        .where((s) => s.title.toLowerCase().contains(search.toLowerCase()))
        .toList();
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            onChanged: onSearch,
            decoration: const InputDecoration(
              labelText: 'Search open studies',
              prefixIcon: Icon(Icons.search),
            ),
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: onImport,
              icon: const Icon(Icons.upload_file),
              label: const Text('Import PNG, JPEG or DICOM'),
            ),
          ),
          const SizedBox(height: 12),
          if (filtered.isEmpty)
            const Padding(
              padding: EdgeInsets.all(28),
              child: Text(
                'No matching studies. Capture a demo frame, import a scan, or unlock your vault in Storage.',
                textAlign: TextAlign.center,
              ),
            ),
          for (final study in filtered)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                onTap: () => onOpen(study),
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.memory(
                    study.frames.first,
                    width: 54,
                    height: 54,
                    fit: BoxFit.cover,
                  ),
                ),
                title: Text(
                  study.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  '${study.source.toUpperCase()} · ${study.frames.length} frame(s) · ${study.createdAt.toLocal().toString().substring(0, 16)}',
                ),
                trailing: IconButton(
                  tooltip: 'Remove study',
                  onPressed: () => onDelete(study),
                  icon: const Icon(Icons.delete_outline),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class StudyViewer extends StatefulWidget {
  const StudyViewer({super.key, required this.study, required this.export});
  final Study study;
  final Future<void> Function(Uint8List, String, String) export;
  @override
  State<StudyViewer> createState() => _StudyViewerState();
}

class _StudyViewerState extends State<StudyViewer> {
  int index = 0;
  Timer? playback;
  bool exporting = false;
  @override
  void dispose() {
    playback?.cancel();
    super.dispose();
  }

  void toggle() {
    if (playback != null) {
      playback?.cancel();
      setState(() => playback = null);
    } else {
      setState(
        () => playback = Timer.periodic(const Duration(milliseconds: 125), (_) {
          if (mounted) {
            setState(() => index = (index + 1) % widget.study.frames.length);
          }
        }),
      );
    }
  }

  Future<void> export(bool original) async {
    setState(() => exporting = true);
    try {
      final study = widget.study;
      await widget.export(
        original ? study.original! : study.frames[index],
        original
            ? 'blue-original.${study.originalExtension}'
            : 'blue-preview-${index + 1}.png',
        original ? 'application/octet-stream' : 'image/png',
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Export failed. Check storage access and try again.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) => Dialog(
    child: SizedBox(
      width: 800,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.study.title,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  tooltip: 'Close viewer',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              height: 320,
              color: const Color(0xff07111e),
              child: InteractiveViewer(
                minScale: 1,
                maxScale: 5,
                child: Image.memory(
                  widget.study.frames[index],
                  gaplessPlayback: true,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text('${widget.study.source.toUpperCase()} · ${widget.study.note}'),
            if (widget.study.frames.length > 1) ...[
              Slider(
                value: index.toDouble(),
                min: 0,
                max: (widget.study.frames.length - 1).toDouble(),
                divisions: widget.study.frames.length - 1,
                label: 'Frame ${index + 1}',
                onChanged: (value) => setState(() => index = value.round()),
              ),
              Text(
                'Frame ${index + 1}/${widget.study.frames.length} · Preview playback at 8 fps (not acquisition timing)',
              ),
            ],
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (widget.study.frames.length > 1)
                  OutlinedButton(
                    onPressed: toggle,
                    child: Text(playback == null ? 'Play preview' : 'Pause'),
                  ),
                OutlinedButton(
                  onPressed: exporting ? null : () => export(false),
                  child: const Text('Export PNG'),
                ),
                if (widget.study.original != null)
                  OutlinedButton(
                    onPressed: exporting ? null : () => export(true),
                    child: const Text('Export original'),
                  ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

class _StoragePage extends StatelessWidget {
  const _StoragePage({
    required this.hasVault,
    required this.unlocked,
    required this.dirty,
    required this.busy,
    required this.onSave,
    required this.onUnlock,
    required this.onLock,
    required this.onBackup,
    required this.onRestore,
  });
  final bool hasVault, unlocked, dirty, busy;
  final VoidCallback onSave, onUnlock, onLock, onBackup, onRestore;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _Card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your encrypted local vault',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            Text(
              hasVault
                  ? unlocked
                        ? 'Unlocked on this device'
                        : 'Saved vault found · Locked'
                  : 'No saved vault yet',
            ),
            const SizedBox(height: 12),
            const Text(
              'Save studies with your own passphrase. Closing the app discards unsaved changes. Keep an encrypted backup: browser/device storage can be cleared. An unlocked workspace is not suitable for unattended use.',
              style: TextStyle(height: 1.6),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: busy || (hasVault && !unlocked) ? null : onSave,
                  icon: const Icon(Icons.save_outlined),
                  label: Text(hasVault ? 'Save vault' : 'Create vault'),
                ),
                if (hasVault && !unlocked)
                  OutlinedButton(
                    onPressed: busy ? null : onUnlock,
                    child: const Text('Unlock vault'),
                  ),
                if (unlocked)
                  OutlinedButton(
                    onPressed: busy || dirty ? null : onLock,
                    child: const Text('Lock workspace'),
                  ),
                OutlinedButton(
                  onPressed: busy || !unlocked ? null : onBackup,
                  child: const Text('Export encrypted backup'),
                ),
                OutlinedButton(
                  onPressed: busy ? null : onRestore,
                  child: const Text('Restore backup'),
                ),
              ],
            ),
            if (dirty)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: Text(
                  'Unsaved changes · Save before locking or closing.',
                  style: TextStyle(color: Color(0xff985d05)),
                ),
              ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      const _Card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Cloud sync is not configured',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 12),
            Text(
              'Cloudflare can host this application. Study uploads remain disabled until identity, permissions, private storage, and the required data-handling setup are implemented. This release stores no studies on the server.',
              style: TextStyle(height: 1.6),
            ),
          ],
        ),
      ),
    ],
  );
}
