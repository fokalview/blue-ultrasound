import 'dart:convert';
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'study.dart';

const maxImportBytes = 16 * 1024 * 1024;
const maxPixels = 4 * 1024 * 1024;

Study importStudy(Uint8List bytes, String name) {
  if (bytes.isEmpty || bytes.length > maxImportBytes) {
    throw const FormatException('Choose a non-empty file smaller than 16 MiB.');
  }
  final dicom =
      bytes.length > 132 &&
      ascii.decode(bytes.sublist(128, 132), allowInvalid: true) == 'DICM';
  final List<Uint8List> frames;
  final String extension;
  String note = 'Imported image · No calibrated measurements';
  if (dicom) {
    frames = decodeDicom(bytes);
    extension = 'dcm';
    note = 'DICOM display preview · Windowed to image range · Not diagnostic';
  } else {
    final png =
        bytes.length >= 8 &&
        bytes[0] == 137 &&
        bytes[1] == 80 &&
        bytes[2] == 78 &&
        bytes[3] == 71;
    final jpeg =
        bytes.length >= 3 &&
        bytes[0] == 255 &&
        bytes[1] == 216 &&
        bytes[2] == 255;
    if (!png && !jpeg) {
      throw const FormatException(
        'Supported: PNG, JPEG, and uncompressed Explicit VR Little Endian grayscale DICOM.',
      );
    }
    final img.Decoder decoder = png ? img.PngDecoder() : img.JpegDecoder();
    final info = decoder.startDecode(bytes);
    if (info == null ||
        info.width < 1 ||
        info.height < 1 ||
        info.width * info.height > maxPixels ||
        info.numFrames > 1) {
      throw const FormatException(
        'Image must be a single frame of at most 4 megapixels.',
      );
    }
    final decoded = decoder.decodeFrame(0);
    if (decoded == null) {
      throw const FormatException('The image could not be decoded.');
    }
    frames = [Uint8List.fromList(img.encodePng(img.bakeOrientation(decoded)))];
    extension = png ? 'png' : 'jpg';
  }
  final now = DateTime.now();
  return Study(
    id: 'import-${now.microsecondsSinceEpoch}',
    title: name,
    createdAt: now,
    source: 'imported',
    frames: frames,
    original: bytes,
    originalExtension: extension,
    note: note,
  );
}

// Deliberately narrow Part 10 reader: no compressed, sequence, signed, or color data.
// Unknown/unsupported encodings fail before allocating a pixel buffer.
List<Uint8List> decodeDicom(Uint8List bytes) {
  final data = ByteData.sublistView(bytes);
  var offset = 132;
  final tags = <int, Uint8List>{};
  const longVrs = {
    'OB',
    'OD',
    'OF',
    'OL',
    'OV',
    'OW',
    'SQ',
    'UC',
    'UR',
    'UT',
    'UN',
  };
  const validVrs = {
    'AE',
    'AS',
    'AT',
    'CS',
    'DA',
    'DS',
    'DT',
    'FD',
    'FL',
    'IS',
    'LO',
    'LT',
    'PN',
    'SH',
    'SL',
    'SS',
    'ST',
    'SV',
    'TM',
    'UI',
    'UL',
    'US',
    'UV',
    ...longVrs,
  };
  var syntaxSeen = false;
  while (offset + 8 <= bytes.length) {
    final group = data.getUint16(offset, Endian.little);
    final element = data.getUint16(offset + 2, Endian.little);
    if (group != 2 && !syntaxSeen) {
      throw const FormatException('DICOM transfer syntax is missing.');
    }
    final vr = ascii.decode(
      bytes.sublist(offset + 4, offset + 6),
      allowInvalid: true,
    );
    if (!validVrs.contains(vr)) {
      throw const FormatException(
        'Only Explicit VR Little Endian DICOM is supported.',
      );
    }
    final long = longVrs.contains(vr);
    final header = long ? 12 : 8;
    if (offset + header > bytes.length) {
      throw const FormatException('Truncated DICOM header.');
    }
    final length = long
        ? data.getUint32(offset + 8, Endian.little)
        : data.getUint16(offset + 6, Endian.little);
    if (length == 0xffffffff || vr == 'SQ') {
      throw const FormatException(
        'DICOM sequences and encapsulated pixels are not supported yet.',
      );
    }
    if (offset + header + length > bytes.length) {
      throw const FormatException('Truncated DICOM value.');
    }
    final value = Uint8List.sublistView(
      bytes,
      offset + header,
      offset + header + length,
    );
    final key = (group << 16) | element;
    if (key == 0x00020010) {
      final syntax = ascii.decode(value).replaceAll('\u0000', '').trim();
      if (syntax != '1.2.840.10008.1.2.1') {
        throw const FormatException(
          'Compressed or implicit-VR DICOM is not supported yet.',
        );
      }
      syntaxSeen = true;
    }
    if (group == 0x0028 || key == 0x7fe00010) tags[key] = value;
    offset += header + length;
    if (key == 0x7fe00010) break;
  }
  int us(int key, [int fallback = 0]) {
    final value = tags[key];
    return value != null && value.length == 2
        ? ByteData.sublistView(value).getUint16(0, Endian.little)
        : fallback;
  }

  String text(int key) => ascii
      .decode(tags[key] ?? Uint8List(0), allowInvalid: true)
      .replaceAll('\u0000', '')
      .trim();
  final rows = us(0x00280010), cols = us(0x00280011), bits = us(0x00280100);
  final stored = us(0x00280101), high = us(0x00280102, -1);
  final countText = text(0x00280008);
  final count = countText.isEmpty ? 1 : int.tryParse(countText) ?? 0;
  final photo = text(0x00280004);
  if (!syntaxSeen ||
      rows < 1 ||
      cols < 1 ||
      rows * cols > maxPixels ||
      count < 1 ||
      count > 100 ||
      rows * cols * count > maxPixels * 4) {
    throw const FormatException(
      'Unsupported DICOM dimensions or frame count (maximum 100 frames / 16 megapixels total).',
    );
  }
  if (us(0x00280002) != 1 ||
      (photo != 'MONOCHROME1' && photo != 'MONOCHROME2') ||
      (bits != 8 && bits != 16) ||
      stored < 1 ||
      stored > bits ||
      high != stored - 1 ||
      us(0x00280103, -1) != 0) {
    throw const FormatException(
      'Only unsigned 8/16-bit monochrome DICOM with standard bit alignment is supported.',
    );
  }
  final pixels = tags[0x7fe00010];
  final expected = rows * cols * count * (bits ~/ 8);
  if (pixels == null ||
      pixels.length < expected ||
      pixels.length > expected + (expected.isOdd ? 1 : 0)) {
    throw const FormatException(
      'DICOM pixel data length does not match its dimensions.',
    );
  }
  final raw = ByteData.sublistView(pixels);
  final mask = (1 << stored) - 1;
  final values = List<int>.generate(
    rows * cols * count,
    (i) =>
        (bits == 8 ? raw.getUint8(i) : raw.getUint16(i * 2, Endian.little)) &
        mask,
  );
  var min = mask, max = 0;
  for (final v in values) {
    if (v < min) min = v;
    if (v > max) max = v;
  }
  return List.generate(count, (frame) {
    final gray = Uint8List(rows * cols);
    for (var i = 0; i < gray.length; i++) {
      final v = values[frame * gray.length + i];
      final normalized = max == min
          ? 0
          : ((v - min) * 255 / (max - min)).round();
      gray[i] = photo == 'MONOCHROME1' ? 255 - normalized : normalized;
    }
    return grayscalePng(gray, cols, rows);
  });
}
