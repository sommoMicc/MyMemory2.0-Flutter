import 'dart:convert';
import 'dart:typed_data';

/// Bounded, ordered framing that also works with the minimum BLE ATT payload.
class BleFraming {
  static const int maxBytes = 8192;
  int _nextId = 0;
  int? _incomingId;
  int _nextPart = 0;
  int _parts = 0;
  DateTime? _started;
  final BytesBuilder _buffer = BytesBuilder();

  List<Uint8List> encode(Map<String, dynamic> message, {int mtu = 20}) {
    final bytes = utf8.encode(jsonEncode(message));
    if (bytes.length > maxBytes || mtu < 12) {
      throw const FormatException('Invalid BLE frame size');
    }
    final capacity = mtu.clamp(12, 512) - 7;
    final count = (bytes.length / capacity).ceil();
    final id = _nextId++ % 65536;
    return List.generate(count, (index) {
      final offset = index * capacity;
      return Uint8List.fromList([
        1,
        id >> 8,
        id & 255,
        index >> 8,
        index & 255,
        count >> 8,
        count & 255,
        ...bytes.sublist(offset, (offset + capacity).clamp(0, bytes.length)),
      ]);
    });
  }

  Map<String, dynamic>? add(Uint8List frame) {
    if (frame.length < 8 || frame[0] != 1) {
      reset();
      throw const FormatException('Invalid BLE frame');
    }
    final id = (frame[1] << 8) | frame[2];
    final index = (frame[3] << 8) | frame[4];
    final count = (frame[5] << 8) | frame[6];
    if (count == 0 || count > maxBytes || index >= count) {
      reset();
      throw const FormatException('Invalid BLE sequence');
    }
    if (index == 0) {
      reset();
      _incomingId = id;
      _parts = count;
      _started = DateTime.now();
    }
    if (_incomingId != id ||
        index != _nextPart ||
        count != _parts ||
        _started == null ||
        DateTime.now().difference(_started!).inSeconds > 10) {
      reset();
      throw const FormatException('Incomplete BLE message');
    }
    _buffer.add(frame.sublist(7));
    _nextPart++;
    if (_buffer.length > maxBytes) {
      reset();
      throw const FormatException('BLE message too large');
    }
    if (_nextPart != count) return null;
    final bytes = _buffer.takeBytes();
    reset();
    final decoded = jsonDecode(utf8.decode(bytes));
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Invalid BLE message');
    }
    return decoded;
  }

  void reset() {
    _buffer.clear();
    _incomingId = null;
    _nextPart = 0;
    _parts = 0;
    _started = null;
  }
}
