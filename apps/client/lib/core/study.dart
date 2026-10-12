import 'dart:convert';
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'scanner.dart';

class Study {
  const Study({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.source,
    required this.frames,
    this.original,
    this.originalExtension,
    this.note = 'No calibrated measurements',
  });
  final String id, title, source, note;
  final DateTime createdAt;
  final List<Uint8List> frames;
  final Uint8List? original;
  final String? originalExtension;
  int get byteSize =>
      frames.fold(0, (total, f) => total + f.length) + (original?.length ?? 0);
  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'createdAt': createdAt.toIso8601String(),
    'source': source,
    'note': note,
    'frames': frames.map(base64Encode).toList(),
    'original': original == null ? null : base64Encode(original!),
    'extension': originalExtension,
  };
  factory Study.fromJson(Map<String, dynamic> json) {
    final encodedFrames = json['frames'];
    if (encodedFrames is! List ||
        encodedFrames.isEmpty ||
        encodedFrames.length > 100 ||
        !const {'simulated', 'imported'}.contains(json['source']) ||
        json['id'] is! String ||
        json['title'] is! String ||
        (json['title'] as String).length > 512 ||
        (json['extension'] != null &&
            !const {'dcm', 'png', 'jpg'}.contains(json['extension']))) {
      throw const FormatException('Invalid study in vault.');
    }
    final frames = encodedFrames.map((f) => base64Decode(f as String)).toList();
    var pixelCount = 0;
    for (final frame in frames) {
      final info = img.PngDecoder().startDecode(frame);
      if (info == null ||
          info.width < 1 ||
          info.height < 1 ||
          info.numFrames != 1 ||
          info.width * info.height > 4 * 1024 * 1024) {
        throw const FormatException('Invalid preview in vault.');
      }
      pixelCount += info.width * info.height;
    }
    if (pixelCount > 16 * 1024 * 1024) {
      throw const FormatException('Vault study has too many pixels.');
    }
    return Study(
      id: json['id'] as String,
      title: json['title'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      source: json['source'] as String,
      note: json['note'] as String,
      frames: frames,
      original: json['original'] == null
          ? null
          : base64Decode(json['original'] as String),
      originalExtension: json['extension'] as String?,
    );
  }
  factory Study.capture(ScanFrame frame) => Study(
    id: 'demo-${frame.sessionId}-${frame.sequence}',
    title: 'Demo capture ${frame.sequence + 1}',
    createdAt: frame.acquiredAt,
    source: 'simulated',
    frames: [grayscalePng(frame.pixels, frame.width, frame.height)],
  );
}

Uint8List grayscalePng(Uint8List pixels, int width, int height) {
  final image = img.Image(width: width, height: height, numChannels: 1);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      image.setPixelR(x, y, pixels[y * width + x]);
    }
  }
  return Uint8List.fromList(img.encodePng(image));
}
