import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Partida encontrada en la red local.
class DiscoveredGame {
  final String name;
  final String address;
  final int port;
  const DiscoveredGame({
    required this.name,
    required this.address,
    required this.port,
  });
}

/// Conexión TCP entre dos dispositivos de la misma red (Wi-Fi o LAN).
/// El anfitrión crea la partida y anuncia su presencia por UDP; el invitado
/// la busca o se conecta escribiendo la IP. Los mensajes son JSON, uno por
/// línea.
class NetSession {
  static const int gamePort = 4040;
  static const int beaconPort = 4041;

  final bool isHost;
  Socket? _socket;
  ServerSocket? _server;
  RawDatagramSocket? _beacon;
  Timer? _beaconTimer;
  bool _closed = false;

  final List<Map<String, dynamic>> _backlog = [];
  void Function(Map<String, dynamic>)? _handler;

  NetSession._(this.isHost);

  /// Receptor de mensajes. Los que llegan sin receptor se guardan y se
  /// entregan al asignar uno. Mensaje especial `{"t":"closed"}`: conexión
  /// perdida.
  set onMessage(void Function(Map<String, dynamic>)? handler) {
    _handler = handler;
    if (handler != null && _backlog.isNotEmpty) {
      final pending = List<Map<String, dynamic>>.of(_backlog);
      _backlog.clear();
      for (final m in pending) {
        handler(m);
      }
    }
  }

  void _dispatch(Map<String, dynamic> m) {
    final h = _handler;
    if (h != null) {
      h(m);
    } else {
      _backlog.add(m);
    }
  }

  // ---------- Anfitrión ----------
  static Future<NetSession> host(String name) async {
    final s = NetSession._(true);
    s._server = await ServerSocket.bind(InternetAddress.anyIPv4, gamePort);
    s._server!.listen((client) {
      if (s._socket != null) {
        client.destroy(); // Solo se admite un rival.
        return;
      }
      s._attach(client);
      s._stopBeacon();
    }, onError: (_) {});
    await s._startBeacon(name);
    return s;
  }

  Future<void> _startBeacon(String name) async {
    try {
      final sock = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      sock.broadcastEnabled = true;
      _beacon = sock;
      final data = utf8.encode('POKEDEX_BATTLE|$name|$gamePort');
      void ping() {
        try {
          sock.send(data, InternetAddress('255.255.255.255'), beaconPort);
        } catch (_) {}
      }

      ping();
      _beaconTimer = Timer.periodic(const Duration(seconds: 1), (_) => ping());
    } catch (_) {
      // Sin anuncio: el invitado puede conectarse escribiendo la IP.
    }
  }

  void _stopBeacon() {
    _beaconTimer?.cancel();
    _beaconTimer = null;
    _beacon?.close();
    _beacon = null;
  }

  // ---------- Invitado ----------
  static Future<NetSession> join(String host, {int port = gamePort}) async {
    final s = NetSession._(false);
    final sock = await Socket.connect(
      host,
      port,
      timeout: const Duration(seconds: 5),
    );
    s._attach(sock);
    return s;
  }

  /// Busca partidas anunciadas en la red durante [timeout].
  static Future<List<DiscoveredGame>> discover({
    Duration timeout = const Duration(seconds: 3),
  }) async {
    final found = <String, DiscoveredGame>{};
    RawDatagramSocket? sock;
    try {
      sock = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        beaconPort,
        reuseAddress: true,
      );
      final s = sock;
      s.listen((event) {
        if (event != RawSocketEvent.read) return;
        final d = s.receive();
        if (d == null) return;
        final parts = utf8.decode(d.data, allowMalformed: true).split('|');
        if (parts.length >= 3 && parts[0] == 'POKEDEX_BATTLE') {
          found[d.address.address] = DiscoveredGame(
            name: parts[1],
            address: d.address.address,
            port: int.tryParse(parts[2]) ?? gamePort,
          );
        }
      });
      await Future<void>.delayed(timeout);
    } catch (_) {
      // Sin red o sin permisos: la lista queda vacía.
    } finally {
      sock?.close();
    }
    return found.values.toList();
  }

  /// Direcciones IPv4 de este dispositivo (para decírselas al invitado).
  static Future<List<String>> localAddresses() async {
    try {
      final ifaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
      );
      return [
        for (final i in ifaces)
          for (final a in i.addresses) a.address,
      ];
    } catch (_) {
      return [];
    }
  }

  // ---------- Común ----------
  void _attach(Socket sock) {
    _socket = sock;
    try {
      sock.setOption(SocketOption.tcpNoDelay, true);
    } catch (_) {}
    sock
        .cast<List<int>>()
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(
      (line) {
        try {
          final m = jsonDecode(line);
          if (m is Map<String, dynamic>) _dispatch(m);
        } catch (_) {}
      },
      onDone: _onDone,
      onError: (_) => _onDone(),
      cancelOnError: true,
    );
  }

  void _onDone() {
    if (_closed) return;
    _closed = true;
    _dispatch({'t': 'closed'});
  }

  void send(Map<String, dynamic> message) {
    if (_closed) return;
    try {
      _socket?.write('${jsonEncode(message)}\n');
    } catch (_) {}
  }

  Future<void> close() async {
    if (_closed && _socket == null && _server == null) return;
    final wasClosed = _closed;
    _closed = true;
    _handler = null;
    _stopBeacon();
    try {
      if (!wasClosed) {
        _socket?.write('${jsonEncode({'t': 'bye'})}\n');
        await _socket?.flush();
      }
    } catch (_) {}
    try {
      _socket?.destroy();
    } catch (_) {}
    try {
      await _server?.close();
    } catch (_) {}
    _socket = null;
    _server = null;
  }
}
