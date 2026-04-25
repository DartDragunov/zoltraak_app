import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:encrypt/encrypt.dart' as enc;
import 'package:flutter/foundation.dart';
import 'package:flutter_libserialport/flutter_libserialport.dart';

// Mirrors package_command_t from communication.h
enum PackageMode {
  read('R'),
  write('W'),
  notify('N'),
  confirmation('C');

  final String code;
  const PackageMode(this.code);
}

// Mirrors user_package_t from communication.h
class UserPackage {
  final PackageMode mode;
  final Uint8List command;
  final Uint8List data;

  const UserPackage({
    required this.mode,
    required this.command,
    required this.data,
  });
}

// Mirrors communication_controller in communication.c
// Handles the same framing, AES-256-CTR encryption and checksum logic.
class SerialModel extends ChangeNotifier {
  // ── Singleton ─────────────────────────────────────────────────────────────

  static SerialModel? _instance;

  /// Initialises the singleton and opens the serial port immediately.
  /// Throws a [SerialPortError] if the port cannot be opened.
  /// Must be called exactly once before accessing [instance].
  factory SerialModel.initialize(String portName, int baudRate) {
    assert(_instance == null, 'SerialModel.initialize() called more than once');
    _instance = SerialModel._(portName, baudRate);
    return _instance!;
  }

  /// Returns the singleton. Throws [StateError] if [initialize] was not called.
  static SerialModel get instance {
    if (_instance == null) {
      throw StateError(
          'SerialModel not initialised. Call SerialModel.initialize(portName, baudRate) first.');
    }
    return _instance!;
  }

  // ── Private constructor – stores params only, port opens on connect() ──────

  SerialModel._(this._portName, this._baudRate);

  final String _portName;
  final int _baudRate;

  // ── AES-256-CTR key (same bytes as in communication.c) ────────────────────
  static final _key = enc.Key(Uint8List.fromList([
    0x9c,
    0xcb,
    0x2d,
    0x2c,
    0xd4,
    0x1b,
    0xdc,
    0x9f,
    0x97,
    0x96,
    0x75,
    0x13,
    0x6f,
    0x58,
    0xcd,
    0x60,
    0x09,
    0x86,
    0x62,
    0xc6,
    0x71,
    0xe4,
    0xbf,
    0x96,
    0xe1,
    0x52,
    0x6a,
    0x0a,
    0xcf,
    0x1c,
    0x2f,
    0x09,
  ]));

  // Packet framing constants
  // ignore: unused_field
  static const _header = [0x5A, 0xA5];
  static const _tail = [0xCC, 0x33, 0xC3, 0x3C];

  SerialPort? _port;
  SerialPortReader? _reader;
  StreamSubscription<Uint8List>? _subscription;

  final _buffer = <int>[];
  final _random = Random.secure();

  // Last package received from the device.
  UserPackage? _lastReceivedPackage;
  UserPackage? get lastReceivedPackage => _lastReceivedPackage;

  // Used to signal the send task that a confirmation ('C') was received.
  Completer<void>? _confirmCompleter;

  // ── Public state ──────────────────────────────────────────────────────────

  bool get isConnected => _port?.isOpen ?? false;

  static List<String> get availablePorts => SerialPort.availablePorts;

  // ── Connect ───────────────────────────────────────────────────────────────

  Future<void> _setupPermissions() async {
    await Process.run('su', ['-c', 'chmod 666 $_portName']);
    await Process.run('su', ['-c', 'chown root $_portName']);
  }

  Future<bool> connect() async {
    if (isConnected) return true;
    try {
      await _setupPermissions();

      _port = SerialPort(_portName);

      if (!_port!.openReadWrite()) {
        debugPrint('Serial open error: ${SerialPort.lastError}');
        _port!.dispose();
        _port = null;
        return false;
      }

      // Config must be applied AFTER the port is opened.
      final config = SerialPortConfig()
        ..baudRate = _baudRate
        ..bits = 8
        ..parity = SerialPortParity.none
        ..stopBits = 1;
      config.setFlowControl(SerialPortFlowControl.none);
      _port!.config = config;
      config.dispose();

      _reader = SerialPortReader(_port!);
      _subscription = _reader!.stream.listen(
        _onDataReceived,
        onError: (error) {
          debugPrint('Serial read error: $error');
          disconnect();
        },
        onDone: disconnect,
      );

      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Serial connect error: $e');
      return false;
    }
  }

  // ── Disconnect ────────────────────────────────────────────────────────────

  void disconnect() {
    _subscription?.cancel();
    _subscription = null;
    _reader?.close();
    _reader = null;
    _port?.close();
    _port?.dispose();
    _port = null;
    _buffer.clear();
    _confirmCompleter?.completeError(StateError('Disconnected'));
    _confirmCompleter = null;
    notifyListeners();
  }

  // ── Send (mirrors communication_send_task) ────────────────────────────────
  //
  // Packet layout (N = encrypted data length):
  //   [0..1]           HEADER  {0x5A, 0xA5}
  //   [2]              mode    'R'/'W'/'N'/'C'
  //   [3..3+N-1]       AES-CTR encrypted {cmd_len, cmd..., data_len, data...}
  //   [3+N..3+N+11]    nonce   (12 random bytes; bytes 12-15 of full IV are 0)
  //   [3+N+12]         checksum high byte
  //   [3+N+13]         checksum low byte
  //   [3+N+14..3+N+17] TAIL    {0xCC, 0x33, 0xC3, 0x3C}
  //
  // Checksum = uint16 sum of bytes[2..length-7] (mode + encrypted + nonce).

  Future<void> sendPackage(UserPackage package) async {
    final port = _port;
    if (port == null || !port.isOpen) throw StateError('Not connected');

    final packet = _buildPacket(package);

    for (int attempt = 0; attempt < 3; attempt++) {
      _confirmCompleter = Completer<void>();
      port.write(packet);
      try {
        await _confirmCompleter!.future
            .timeout(const Duration(milliseconds: 500));
        _confirmCompleter = null;
        return; // Confirmed
      } on TimeoutException {
        // Retry up to 3 times (mirrors send task retry logic)
      }
    }

    _confirmCompleter = null;
    throw TimeoutException('No confirmation received after 3 attempts');
  }

  Uint8List _buildPacket(UserPackage package) {
    final cmd = package.command;
    final data = package.data;

    // Build plaintext: [cmd_len(1)][cmd][data_len(1)][data]
    final plaintext = Uint8List(1 + cmd.length + 1 + data.length);
    int idx = 0;
    plaintext[idx++] = cmd.length;
    plaintext.setRange(idx, idx + cmd.length, cmd);
    idx += cmd.length;
    plaintext[idx++] = data.length;
    plaintext.setRange(idx, idx + data.length, data);

    // 16-byte IV: 12 random bytes + 4 zero bytes (counter starts at 0)
    final iv = Uint8List(16);
    for (int i = 0; i < 12; i++) iv[i] = _random.nextInt(256);
    // bytes 12-15 remain 0

    final encrypter =
        enc.Encrypter(enc.AES(_key, mode: enc.AESMode.ctr, padding: null));
    final encryptedBytes =
        encrypter.encryptBytes(plaintext, iv: enc.IV(iv)).bytes;

    // Assemble final packet
    final packetLength = 3 + encryptedBytes.length + 12 + 2 + 4;
    final packet = Uint8List(packetLength);

    packet[0] = 0x5A;
    packet[1] = 0xA5;
    packet[2] = package.mode.code.codeUnitAt(0);

    int pos = 3;
    packet.setRange(pos, pos + encryptedBytes.length, encryptedBytes);
    pos += encryptedBytes.length;
    packet.setRange(pos, pos + 12, iv.sublist(0, 12));
    pos += 12;

    // Checksum over bytes[2..packetLength-7] (mode + encrypted data + nonce)
    int checksum = 0;
    for (int i = 2; i < packetLength - 6; i++) checksum += packet[i];
    checksum &= 0xFFFF;
    packet[pos] = (checksum >> 8) & 0xFF;
    packet[pos + 1] = checksum & 0xFF;
    pos += 2;

    packet.setRange(pos, pos + 4, _tail);

    return packet;
  }

  // ── Receive (mirrors communication_task + communication_compute_task) ──────

  void _onDataReceived(Uint8List data) {
    debugPrint('Serial data received: $data');
    _buffer.addAll(data);
    _processBuffer();
  }

  void _processBuffer() {
    while (true) {
      // Locate HEADER
      int start = -1;
      for (int i = 0; i < _buffer.length - 1; i++) {
        if (_buffer[i] == 0x5A && _buffer[i + 1] == 0xA5) {
          start = i;
          break;
        }
      }
      if (start == -1) {
        _buffer.clear();
        return;
      }

      if (start > 0) _buffer.removeRange(0, start);

      // Locate TAIL
      int tailPos = -1;
      for (int i = 2; i < _buffer.length - 3; i++) {
        if (_buffer[i] == 0xCC &&
            _buffer[i + 1] == 0x33 &&
            _buffer[i + 2] == 0xC3 &&
            _buffer[i + 3] == 0x3C) {
          tailPos = i;
          break;
        }
      }
      if (tailPos == -1) return; // Wait for more data

      final messageLength = tailPos + 4;
      final packet = Uint8List.fromList(_buffer.sublist(0, messageLength));
      _buffer.removeRange(0, messageLength);

      _processPacket(packet);
    }
  }

  void _processPacket(Uint8List packet) {
    final length = packet.length;
    if (length < 10) return;

    // Validate checksum
    int calculated = 0;
    for (int i = 2; i < length - 6; i++) calculated += packet[i];
    calculated &= 0xFFFF;
    final received = (packet[length - 6] << 8) | packet[length - 5];

    if (calculated != received) {
      _sendValidation(0x01); // Error
      return;
    }

    final mode = String.fromCharCode(packet[2]);

    if (mode == 'C') {
      if (packet[3] == 0x00) {
        _confirmCompleter?.complete();
        _confirmCompleter = null;
      }
      return;
    }

    // Acknowledge receipt before decrypting
    _sendValidation(0x00);

    // N = total - header/mode(3) - nonce(12) - checksum(2) - tail(4)
    final dataLength = length - 3 - 12 - 6;
    if (dataLength <= 0) return;

    final encryptedData = Uint8List.fromList(packet.sublist(3, 3 + dataLength));
    final iv = Uint8List(16);
    iv.setRange(0, 12, packet.sublist(3 + dataLength, 3 + dataLength + 12));
    // bytes 12-15 remain 0 (counter reset for decryption)

    final encrypter =
        enc.Encrypter(enc.AES(_key, mode: enc.AESMode.ctr, padding: null));
    final decrypted =
        encrypter.decryptBytes(enc.Encrypted(encryptedData), iv: enc.IV(iv));

    if (decrypted.isEmpty) return;

    // Parse decrypted: [cmd_len(1)][cmd...][data_len(1)][data...]
    int idx = 0;
    if (idx >= decrypted.length) return;
    final cmdLength = decrypted[idx++];
    if (idx + cmdLength > decrypted.length) return;
    final cmdBytes =
        Uint8List.fromList(decrypted.sublist(idx, idx + cmdLength));
    idx += cmdLength;
    if (idx >= decrypted.length) return;
    final dataLen = decrypted[idx++];
    if (idx + dataLen > decrypted.length) return;
    final dataBytes = Uint8List.fromList(decrypted.sublist(idx, idx + dataLen));

    final packageMode = PackageMode.values.firstWhere(
      (m) => m.code == mode,
      orElse: () => PackageMode.notify,
    );

    _lastReceivedPackage = UserPackage(
      mode: packageMode,
      command: cmdBytes,
      data: dataBytes,
    );
    notifyListeners();
  }

  // ── Confirmation packet (mirrors send_validation_package) ─────────────────

  void _sendValidation(int errorCode) {
    final port = _port;
    if (port == null || !port.isOpen) return;

    // Packet: HEADER(2) + 'C'(1) + error_code(1) + checksum(2) + TAIL(4) = 10 bytes
    final packet = Uint8List(10);
    packet[0] = 0x5A;
    packet[1] = 0xA5;
    packet[2] = 0x43; // 'C'
    packet[3] = errorCode;
    final checksum = (packet[2] + packet[3]) & 0xFFFF;
    packet[4] = (checksum >> 8) & 0xFF;
    packet[5] = checksum & 0xFF;
    packet[6] = 0xCC;
    packet[7] = 0x33;
    packet[8] = 0xC3;
    packet[9] = 0x3C;

    port.write(packet);
  }

  @override
  void dispose() {
    disconnect();
    super.dispose();
  }
}
