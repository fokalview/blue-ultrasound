import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:blue_ultrasound/core/scanner.dart';
import 'package:blue_ultrasound/core/study.dart';
import 'package:blue_ultrasound/core/importer.dart';
import 'package:blue_ultrasound/core/vault.dart';

Uint8List fixture({
  String syntax = '1.2.840.10008.1.2.1',
  String photo = 'MONOCHROME2',
  int rows = 2,
  int frames = 1,
}) {
  final out = BytesBuilder()
    ..add(Uint8List(128))
    ..add(ascii.encode('DICM'));
  void tag(int group, int element, String vr, List<int> value) {
    final long = vr == 'OB';
    final header = ByteData(long ? 12 : 8)
      ..setUint16(0, group, Endian.little)
      ..setUint16(2, element, Endian.little);
    header.setUint8(4, vr.codeUnitAt(0));
    header.setUint8(5, vr.codeUnitAt(1));
    if (long) {
      header.setUint32(8, value.length, Endian.little);
    } else {
      header.setUint16(6, value.length, Endian.little);
    }
    out
      ..add(header.buffer.asUint8List())
      ..add(value);
  }

  void us(int element, int value) => tag(
    0x0028,
    element,
    'US',
    (ByteData(2)..setUint16(0, value, Endian.little)).buffer.asUint8List(),
  );
  List<int> even(String value) =>
      ascii.encode(value.length.isEven ? value : '$value ');
  tag(2, 0x10, 'UI', even(syntax));
  us(0x10, rows);
  us(0x11, 2);
  us(2, 1);
  us(0x100, 8);
  us(0x101, 8);
  us(0x102, 7);
  us(0x103, 0);
  tag(0x28, 4, 'CS', even(photo));
  tag(0x28, 8, 'IS', even('$frames'));
  tag(0x7fe0, 0x10, 'OB', List.generate(4 * frames, (i) => (i * 63) % 256));
  return out.toBytes();
}

void main() {
  test('scanner state and disconnected capture restrictions', () async {
    final scanner = DemoScanner();
    expect(scanner.capture, throwsStateError);
    await scanner.connect();
    final first = scanner.capture();
    scanner.freeze();
    scanner.tick();
    expect(scanner.capture().sequence, first.sequence);
    scanner.resume();
    expect(scanner.capture().sequence, greaterThan(first.sequence));
    await scanner.disconnect();
    expect(scanner.capture, throwsStateError);
    expect(scanner.resume, throwsStateError);
    expect(first.source, 'simulated');
    await scanner.dispose();
  });
  test('frame dimensions, immutability and stale timestamps', () {
    expect(
      () => ScanFrame(
        sessionId: 'x',
        sequence: 0,
        acquiredAt: DateTime.now(),
        width: 2,
        height: 2,
        pixels: Uint8List(1),
      ),
      throwsArgumentError,
    );
    final frame = ScanFrame(
      sessionId: 'x',
      sequence: 0,
      acquiredAt: DateTime.utc(2020),
      width: 1,
      height: 1,
      pixels: Uint8List(1),
    );
    expect(
      frame.isStale(DateTime.utc(2020).add(const Duration(seconds: 3))),
      isTrue,
    );
    expect(() => frame.pixels[0] = 2, throwsUnsupportedError);
  });
  test('supported multiframe DICOM preserves original', () {
    final bytes = fixture(frames: 2);
    final study = importStudy(bytes, 'synthetic.dcm');
    expect(study.frames.length, 2);
    expect(study.original, bytes);
    expect(study.source, 'imported');
    expect(study.note, contains('Not diagnostic'));
  });
  test('rejects compressed, mismatched, truncated and color DICOM', () {
    expect(
      () => importStudy(fixture(syntax: '1.2.840.10008.1.2.4.50'), 'bad.dcm'),
      throwsFormatException,
    );
    expect(
      () => importStudy(fixture(rows: 65535), 'bad.dcm'),
      throwsFormatException,
    );
    expect(
      () => importStudy(fixture(photo: 'RGB'), 'bad.dcm'),
      throwsFormatException,
    );
    final bytes = fixture();
    expect(
      () => importStudy(bytes.sublist(0, bytes.length - 1), 'bad.dcm'),
      throwsFormatException,
    );
    expect(
      () => importStudy(Uint8List(maxImportBytes + 1), 'big.png'),
      throwsFormatException,
    );
  });
  test('PNG import and study serialization', () {
    final bytes = grayscalePng(Uint8List.fromList([0, 64, 128, 255]), 2, 2);
    final study = importStudy(bytes, 'demo.png');
    final restored = Study.fromJson(study.toJson());
    expect(restored.frames.single, study.frames.single);
    expect(restored.original, bytes);
  });
  test('vault persistence, wrong passphrase and tamper detection', () async {
    SharedPreferences.setMockInitialValues({});
    final vault = StudyVault();
    final studies = [importStudy(fixture(), 'synthetic.dcm')];
    const password = 'correct horse battery staple';
    await vault.save(studies, password);
    expect(await vault.exists(), isTrue);
    expect((await vault.load(password)).single.title, 'synthetic.dcm');
    final prefs = await SharedPreferences.getInstance();
    final payload = prefs.getString(StudyVault.storageKey)!;
    expect(payload, isNot(contains('synthetic.dcm')));
    await expectLater(vault.load('wrong password here'), throwsA(anything));
    final envelope = jsonDecode(payload) as Map<String, dynamic>;
    final bytes = base64Decode(envelope['data'] as String);
    bytes[0] ^= 1;
    envelope['data'] = base64Encode(bytes);
    await expectLater(
      vault.decrypt(jsonEncode(envelope), password),
      throwsA(anything),
    );
  });
}
