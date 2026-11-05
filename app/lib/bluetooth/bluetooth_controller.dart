import 'dart:async';
import 'dart:math';

import 'package:bluetooth_low_energy/bluetooth_low_energy.dart' as ble;
import 'package:flutter/foundation.dart';

import '../economy.dart';
import '../decks.dart';
import 'ble_game.dart';
import 'framing.dart';

class BluetoothPeer {
  final String id;
  final String name;
  final int rssi;
  final ble.Peripheral peripheral;
  BluetoothPeer(this.peripheral, this.name, this.rssi)
    : id = peripheral.uuid.toString();
}

/// Foreground, offline BLE transport. The advertising phone owns the game.
class BluetoothController extends ChangeNotifier {
  BluetoothController({this.ticketProvider});
  final Future<GameTicket?> Function(int pairs, String theme)? ticketProvider;
  static bool get supported =>
      !kIsWeb &&
      [
        TargetPlatform.android,
        TargetPlatform.iOS,
      ].contains(defaultTargetPlatform);
  static final _serviceId = ble.UUID.fromString(
    '7ebbc000-71b8-469b-b323-57a928dac312',
  );
  static final _commandId = ble.UUID.fromString(
    '7ebbc001-71b8-469b-b323-57a928dac312',
  );
  static final _stateId = ble.UUID.fromString(
    '7ebbc002-71b8-469b-b323-57a928dac312',
  );
  Map<String, dynamic>? state;
  String? playerId, error;
  String status = 'Pronto';
  bool isHosting = false, scanning = false;
  bool get connected =>
      !_lostConnection && state != null && (isHosting || _remote != null);
  final List<BluetoothPeer> peers = [];
  ble.CentralManager? _central;
  ble.PeripheralManager? _peripheral;
  ble.Peripheral? _remote;
  ble.Central? _guest;
  ble.GATTCharacteristic? _command, _updates;
  BleGame? _game;
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  final BleFraming _incoming = BleFraming(), _outgoing = BleFraming();
  Future<void> _sendQueue = Future.value();
  Timer? _heartbeat, _scanTimeout, _mismatch;
  DateTime? _lastSeen;
  bool _disposed = false;
  bool _lostConnection = false;
  bool _preparingRound = false;
  int _generation = 0;

  void _changed() {
    if (!_disposed) notifyListeners();
  }

  void _fail(Object cause) {
    error = cause is TimeoutException
        ? 'Bluetooth non disponibile. Accendi il Bluetooth e tieni entrambe le app aperte.'
        : cause.toString().replaceFirst(
            RegExp(r'^(StateError|Bad state|Exception):\s*'),
            '',
          );
    status = 'Connessione Bluetooth non disponibile';
    _changed();
  }

  Future<void> _ready(ble.BluetoothLowEnergyManager manager) async {
    if (!supported) {
      throw StateError('Bluetooth disponibile sulle app Android e iOS.');
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      if (!await manager.authorize()) {
        throw StateError(
          'Consenti l’accesso ai dispositivi vicini nelle impostazioni.',
        );
      }
    }
    if (manager.state != ble.BluetoothLowEnergyState.poweredOn) {
      await manager.stateChanged
          .firstWhere(
            (event) => event.state == ble.BluetoothLowEnergyState.poweredOn,
          )
          .timeout(const Duration(seconds: 15));
    }
    _subscriptions.add(
      manager.stateChanged.listen((event) {
        if (event.state != ble.BluetoothLowEnergyState.poweredOn) {
          _lost('Bluetooth spento o permesso rimosso.');
        }
      }),
    );
  }

  Future<void> host(String name, int pairs, String theme) async {
    await leave();
    if (_disposed) return;
    if (!supported) {
      _fail(StateError('Bluetooth disponibile sulle app Android e iOS.'));
      return;
    }
    try {
      final generation = _generation;
      status = 'Preparazione Bluetooth…';
      _changed();
      final ticket = await _takeRewardTicket(pairs, theme);
      if (_disposed || generation != _generation) return;
      final manager = _peripheral = ble.PeripheralManager();
      await _ready(manager);
      if (_disposed || _peripheral != manager) return;
      isHosting = true;
      playerId = 'host';
      const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
      final random = Random.secure();
      final code = List.generate(
        4,
        (_) => alphabet[random.nextInt(alphabet.length)],
      ).join();
      _game = BleGame(
        name,
        pairs,
        theme,
        code,
        board: ticket?.board,
        ticketId: ticket?.id,
        guestClaimToken: ticket?.guestClaimToken,
      );
      _command = ble.GATTCharacteristic.mutable(
        uuid: _commandId,
        properties: [ble.GATTCharacteristicProperty.write],
        permissions: [ble.GATTCharacteristicPermission.write],
        descriptors: [],
      );
      // Indications request link-level acknowledgement on both platforms.
      _updates = ble.GATTCharacteristic.mutable(
        uuid: _stateId,
        properties: [ble.GATTCharacteristicProperty.indicate],
        permissions: [],
        descriptors: [],
      );
      _subscriptions.add(
        manager.characteristicWriteRequested.listen((event) async {
          try {
            if (event.characteristic.uuid != _commandId ||
                event.request.offset != 0 ||
                _guest == null ||
                _guest!.uuid != event.central.uuid) {
              await manager.respondWriteRequestWithError(
                event.request,
                error: ble.GATTError.insufficientAuthorization,
              );
              return;
            }
            Map<String, dynamic>? message;
            try {
              // Parse before acknowledging, so the next ATT write cannot
              // overtake this fragment while the platform response completes.
              message = _incoming.add(event.request.value);
            } on FormatException {
              await manager.respondWriteRequestWithError(
                event.request,
                error: ble.GATTError.invalidPDU,
              );
              return;
            }
            await manager.respondWriteRequest(event.request);
            if (message != null) _receiveCommand(message);
          } catch (cause) {
            _fail(cause);
          }
        }),
      );
      _subscriptions.add(
        manager.characteristicNotifyStateChanged.listen((event) {
          if (event.characteristic.uuid != _stateId) return;
          if (event.state && _guest == null) {
            _guest = event.central;
            _lastSeen = DateTime.now();
          } else if (!event.state && _guest?.uuid == event.central.uuid) {
            _lost('L’altro dispositivo si è scollegato.');
          }
        }),
      );
      // iOS reports unsubscribe; Android additionally reports disconnection.
      if (defaultTargetPlatform == TargetPlatform.android) {
        _subscriptions.add(
          manager.connectionStateChanged.listen((event) {
            if (event.central.uuid == _guest?.uuid &&
                event.state == ble.ConnectionState.disconnected) {
              _lost('L’altro dispositivo si è scollegato.');
            }
          }),
        );
      }
      await manager.removeAllServices();
      await manager.addService(
        ble.GATTService(
          uuid: _serviceId,
          isPrimary: true,
          includedServices: [],
          characteristics: [_command!, _updates!],
        ),
      );
      await manager.startAdvertising(
        ble.Advertisement(
          name: 'SommoMemory $code',
          serviceUUIDs: [_serviceId],
        ),
      );
      state = _game!.snapshot();
      status = 'Visibile come SommoMemory $code';
      _startHeartbeat();
      _changed();
    } catch (cause) {
      await _cleanupAfterFailure(cause);
    }
  }

  Future<void> scan() async {
    await leave();
    if (_disposed) return;
    if (!supported) {
      _fail(StateError('Bluetooth disponibile sulle app Android e iOS.'));
      return;
    }
    try {
      status = 'Ricerca di partite vicine…';
      _changed();
      final manager = _central = ble.CentralManager();
      await _ready(manager);
      if (_disposed || _central != manager) return;
      peers.clear();
      _subscriptions.add(
        manager.discovered.listen((event) {
          final peer = BluetoothPeer(
            event.peripheral,
            event.advertisement.name ?? 'SommoMemory vicino',
            event.rssi,
          );
          final index = peers.indexWhere((p) => p.id == peer.id);
          if (index < 0) {
            peers.add(peer);
          } else {
            peers[index] = peer;
          }
          peers.sort((a, b) => b.rssi.compareTo(a.rssi));
          _changed();
        }),
      );
      await manager.startDiscovery(serviceUUIDs: [_serviceId]);
      scanning = true;
      _scanTimeout = Timer(const Duration(seconds: 20), () {
        unawaited(_stopScan());
      });
      _changed();
    } catch (cause) {
      await _cleanupAfterFailure(cause);
    }
  }

  Future<void> _stopScan() async {
    _scanTimeout?.cancel();
    if (scanning) {
      scanning = false;
      try {
        await _central?.stopDiscovery();
      } catch (_) {}
      status = peers.isEmpty
          ? 'Nessuna partita trovata. Crea una partita sull’altro dispositivo.'
          : 'Scegli la partita vicina';
      _changed();
    }
  }

  Future<void> join(BluetoothPeer peer, String name) async {
    if (_central == null) {
      _fail(StateError('Avvia prima la ricerca.'));
      return;
    }
    try {
      await _stopScan();
      status = 'Connessione a ${peer.name}…';
      error = null;
      _changed();
      final manager = _central!;
      _remote = peer.peripheral;
      playerId = 'guest';
      _subscriptions.add(
        manager.connectionStateChanged.listen((event) {
          if (event.peripheral.uuid == _remote?.uuid &&
              event.state == ble.ConnectionState.disconnected) {
            _lost('L’altro dispositivo si è scollegato.');
          }
        }),
      );
      await manager
          .connect(peer.peripheral)
          .timeout(const Duration(seconds: 15));
      final services = await manager
          .discoverGATT(peer.peripheral)
          .timeout(const Duration(seconds: 15));
      final service = services.firstWhere((s) => s.uuid == _serviceId);
      _command = service.characteristics.firstWhere(
        (c) => c.uuid == _commandId,
      );
      _updates = service.characteristics.firstWhere((c) => c.uuid == _stateId);
      _subscriptions.add(
        manager.characteristicNotified.listen((event) {
          if (event.peripheral.uuid != _remote?.uuid ||
              event.characteristic.uuid != _stateId) {
            return;
          }
          try {
            final message = _incoming.add(event.value);
            if (message == null) return;
            if (message['type'] == 'error' && message['message'] is String) {
              _lost(
                (message['message'] as String).substring(
                  0,
                  min(160, (message['message'] as String).length),
                ),
              );
              return;
            }
            if (message['type'] == 'state') {
              // Snapshots heal an interrupted packet sequence on the next heartbeat.
              final revision = message['revision'];
              if (revision is! int ||
                  (state != null && revision < (state!['revision'] as int))) {
                return;
              }
              state = message;
              _lastSeen = DateTime.now();
              error = null;
              status = 'Connesso via Bluetooth';
              _changed();
            }
          } on FormatException {
            /* Retry via periodic full state snapshot. */
          }
        }),
      );
      await manager.setCharacteristicNotifyState(
        peer.peripheral,
        _updates!,
        state: true,
      );
      _lastSeen = DateTime.now();
      await _send({
        'type': 'hello',
        'version': 1,
        'name': BleGame.cleanName(name),
        'supportedDecks': deckNames.keys.toList(),
      });
      _startHeartbeat();
    } catch (cause) {
      await _cleanupAfterFailure(cause);
    }
  }

  void _receiveCommand(Map<String, dynamic> message) {
    _lastSeen = DateTime.now();
    final game = _game;
    if (game == null) return;
    switch (message['type']) {
      case 'hello':
        if (message['version'] != 1 || message['name'] is! String) return;
        final supported = message['supportedDecks'];
        final allowed = supported == null
            ? const ['garden', 'cosmos', 'ocean']
            : supported is List &&
                  supported.length <= 64 &&
                  supported.toSet().length == supported.length &&
                  supported.every(
                    (value) => value is String && deckNames.containsKey(value),
                  )
            ? supported
            : const [];
        if (!allowed.contains(game.theme)) {
          unawaited(
            _send({
              'type': 'error',
              'message':
                  'Aggiorna SommoMemory per giocare con questa collezione.',
            }),
          );
          status = 'L’altro dispositivo deve aggiornare SommoMemory.';
          _changed();
          return;
        }
        if (game.phase == 'waiting') {
          game.join(message['name'] as String);
          unawaited(_peripheral!.stopAdvertising().catchError((_) {}));
        }
        status = 'Connesso via Bluetooth';
        _publish();
      case 'flip':
        if (message['index'] is int &&
            game.flip('guest', message['index'] as int)) {
          _publish();
        }
      case 'rematch':
        unawaited(_requestRematch('guest'));
      case 'ping':
        _publish();
      case 'leave':
        _lost('L’altro giocatore ha lasciato la partita.');
    }
  }

  Future<void> flip(int index) async {
    if (!connected) return;
    if (isHosting) {
      if (_game?.flip('host', index) == true) _publish();
    } else {
      await _send({'type': 'flip', 'index': index});
    }
  }

  Future<void> rematch() async {
    if (!connected) return;
    if (isHosting) {
      await _requestRematch('host');
    } else {
      await _send({'type': 'rematch'});
    }
  }

  Future<GameTicket?> _takeRewardTicket(int pairs, String theme) async {
    try {
      return await ticketProvider?.call(pairs, theme);
    } catch (_) {
      // Internet is optional for Bluetooth; an unavailable reward ticket
      // must never prevent playing a normal offline match.
      return null;
    }
  }

  Future<void> _requestRematch(String player) async {
    final game = _game;
    if (game == null || _lostConnection) return;
    game.rematch(player, defer: true);
    _publish();
    if (!game.rematchReady || _preparingRound) return;
    _preparingRound = true;
    final generation = _generation;
    try {
      final ticket = await _takeRewardTicket(game.pairs, game.theme);
      if (_disposed ||
          generation != _generation ||
          _lostConnection ||
          _game != game) {
        return;
      }
      game.startRematch(
        board: ticket?.board,
        ticketId: ticket?.id,
        guestClaimToken: ticket?.guestClaimToken,
      );
      _publish();
    } finally {
      if (generation == _generation) _preparingRound = false;
    }
  }

  void _publish() {
    if (_game == null) return;
    state = _game!.snapshot();
    _changed();
    if (_guest != null && _game!.players.length == 2) unawaited(_send(state!));
    _mismatch?.cancel();
    final until = _game!.lockedUntil;
    if (until != null) {
      _mismatch = Timer(
        Duration(
          milliseconds: max(0, until - DateTime.now().millisecondsSinceEpoch),
        ),
        () {
          if (_game?.settle() == true) _publish();
        },
      );
    }
  }

  Future<void> _send(Map<String, dynamic> message) {
    final generation = _generation;
    final copy = Map<String, dynamic>.from(message);
    _sendQueue = _sendQueue
        .then((_) async {
          if (generation != _generation) return;
          if (isHosting) {
            final guest = _guest,
                manager = _peripheral,
                characteristic = _updates;
            if (guest == null || manager == null || characteristic == null) {
              return;
            }
            final mtu = await manager.getMaximumNotifyLength(guest);
            for (final frame in _outgoing.encode(copy, mtu: mtu)) {
              if (generation != _generation) return;
              await manager
                  .notifyCharacteristic(guest, characteristic, value: frame)
                  .timeout(const Duration(seconds: 5));
            }
          } else {
            final remote = _remote,
                manager = _central,
                characteristic = _command;
            if (remote == null || manager == null || characteristic == null) {
              return;
            }
            // 20 bytes is safe on every ATT implementation; commands are small.
            for (final frame in _outgoing.encode(copy)) {
              if (generation != _generation) return;
              await manager
                  .writeCharacteristic(
                    remote,
                    characteristic,
                    value: Uint8List.fromList(frame),
                    type: ble.GATTCharacteristicWriteType.withResponse,
                  )
                  .timeout(const Duration(seconds: 5));
            }
          }
        })
        .catchError((Object cause) {
          if (generation == _generation) {
            _lost('Connessione Bluetooth interrotta.');
          }
        });
    return _sendQueue;
  }

  void _startHeartbeat() {
    _heartbeat?.cancel();
    _heartbeat = Timer.periodic(const Duration(seconds: 2), (_) {
      if (_lastSeen != null &&
          DateTime.now().difference(_lastSeen!).inSeconds > 12) {
        _lost(
          'Connessione persa. Tieni le due app aperte e crea una nuova partita.',
        );
        return;
      }
      if (isHosting) {
        if (_guest != null) _publish();
      } else if (_remote != null) {
        unawaited(_send({'type': 'ping'}));
      }
    });
  }

  void _lost(String reason) {
    if (_disposed) return;
    _heartbeat?.cancel();
    _mismatch?.cancel();
    _lastSeen = null;
    _lostConnection = true;
    error = reason;
    status = 'Disconnesso';
    if (isHosting && _game != null) {
      _game!.disconnect('guest');
      state = _game!.snapshot();
    }
    _changed();
  }

  Future<void> _cleanupAfterFailure(Object cause) async {
    await leave();
    _fail(cause);
  }

  Future<void> leave() async {
    _generation++;
    _heartbeat?.cancel();
    _scanTimeout?.cancel();
    _mismatch?.cancel();
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    _subscriptions.clear();
    final central = _central, peripheral = _peripheral, remote = _remote;
    _central = null;
    _peripheral = null;
    _remote = null;
    _guest = null;
    if (central != null) {
      if (scanning) {
        try {
          await central.stopDiscovery();
        } catch (_) {}
      }
      if (remote != null) {
        try {
          await central.disconnect(remote);
        } catch (_) {}
      }
    }
    if (peripheral != null) {
      try {
        await peripheral.stopAdvertising();
      } catch (_) {}
      try {
        await peripheral.removeAllServices();
      } catch (_) {}
    }
    scanning = false;
    isHosting = false;
    _lostConnection = false;
    _preparingRound = false;
    state = null;
    playerId = null;
    _game = null;
    _command = null;
    _updates = null;
    _lastSeen = null;
    _incoming.reset();
    error = null;
    status = 'Pronto';
    peers.clear();
    _changed();
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(leave());
    super.dispose();
  }
}
