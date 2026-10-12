import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

enum ScanState { disconnected, streaming, frozen }

class ScanFrame {
  ScanFrame({
    required this.sessionId,
    required this.sequence,
    required this.acquiredAt,
    required this.width,
    required this.height,
    required Uint8List pixels,
    this.source = 'simulated',
  }) : pixels = Uint8List.fromList(pixels).asUnmodifiableView() {
    if (width < 1 ||
        height < 1 ||
        width * height > 4194304 ||
        pixels.length != width * height ||
        sequence < 0) {
      throw ArgumentError('Invalid grayscale frame');
    }
  }
  final String sessionId;
  final int sequence;
  final DateTime acquiredAt;
  final int width, height;
  final Uint8List pixels;
  final String source;
  bool isStale(DateTime now) =>
      now.difference(acquiredAt) > const Duration(seconds: 2);
}

abstract class ScannerAdapter {
  String get id;
  ScanState get state;
  Set<String> get capabilities;
  Stream<ScanFrame> get frames;
  Stream<ScanState> get states;
  Future<void> connect();
  Future<void> disconnect();
  void freeze();
  void resume();
  ScanFrame capture();
  Future<void> dispose();
}

class DemoScanner implements ScannerAdapter {
  final _frames = StreamController<ScanFrame>.broadcast();
  final _states = StreamController<ScanState>.broadcast();
  Timer? _timer;
  ScanFrame? _latest;
  int _sequence = 0;
  String _session = '';
  ScanState _state = ScanState.disconnected;
  bool _disposed = false;
  @override
  String get id => 'demo';
  @override
  ScanState get state => _state;
  @override
  Set<String> get capabilities => const {'freeze', 'resume', 'capture'};
  @override
  Stream<ScanFrame> get frames => _frames.stream;
  @override
  Stream<ScanState> get states => _states.stream;
  void _set(ScanState state) {
    _state = state;
    _states.add(state);
  }

  @override
  Future<void> connect() async {
    if (_disposed) throw StateError('Adapter disposed');
    if (_state != ScanState.disconnected) return;
    _session = DateTime.now().microsecondsSinceEpoch.toString();
    _sequence = 0;
    _set(ScanState.streaming);
    tick();
    _timer = Timer.periodic(const Duration(milliseconds: 125), (_) => tick());
  }

  void tick() {
    if (_state != ScanState.streaming) return;
    const size = 192;
    final bytes = Uint8List(size * size);
    final phase = _sequence / 8;
    for (var y = 0; y < size; y++) {
      for (var x = 0; x < size; x++) {
        final dx = x - size / 2;
        final dy = y + 8.0;
        if (dx.abs() > dy * .58) continue;
        final radius = sqrt(dx * dx + dy * dy);
        final waves = sin(radius * .22 - phase) * .5 + .5;
        final grain = ((x * 31 + y * 73 + _sequence * 7) % 43) / 43;
        bytes[y * size + x] = (24 + 130 * waves * (1 - y / 260) + grain * 50)
            .round()
            .clamp(0, 255);
      }
    }
    _latest = ScanFrame(
      sessionId: _session,
      sequence: _sequence++,
      acquiredAt: DateTime.now(),
      width: size,
      height: size,
      pixels: bytes,
    );
    _frames.add(_latest!);
  }

  @override
  void freeze() {
    if (_state != ScanState.streaming) {
      throw StateError('Scanner is not streaming');
    }
    _set(ScanState.frozen);
  }

  @override
  void resume() {
    if (_state != ScanState.frozen) throw StateError('Scanner is not frozen');
    _set(ScanState.streaming);
    tick();
  }

  @override
  ScanFrame capture() {
    final frame = _latest;
    if (_state == ScanState.disconnected ||
        frame == null ||
        (_state == ScanState.streaming && frame.isStale(DateTime.now()))) {
      throw StateError('No current frame to capture');
    }
    return frame;
  }

  @override
  Future<void> disconnect() async {
    _timer?.cancel();
    _timer = null;
    _latest = null;
    if (!_disposed) _set(ScanState.disconnected);
  }

  @override
  Future<void> dispose() async {
    await disconnect();
    _disposed = true;
    await _frames.close();
    await _states.close();
  }
}
