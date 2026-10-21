import 'dart:math';

import 'package:flutter/material.dart';

import '../battle/battle_builder.dart';
import '../battle/battle_engine.dart';
import '../battle/net_session.dart';
import '../models/pokemon.dart';
import '../models/team.dart';
import '../services/pokemon_service.dart';
import '../services/sound_service.dart';
import '../services/team_service.dart';
import '../theme/app_theme.dart';
import '../widgets/battle_view.dart';
import '../widgets/pokeball.dart';
import '../widgets/pokedex_ui.dart';
import 'team_screen.dart';

enum _Stage { menu, config, loading, lobby, battle }

enum _Mode { simulated, network, bluetooth }

/// Sección de combate: menú, configuración y combate simulado.
class CombatScreen extends StatefulWidget {
  final String username;
  final PokemonService service;
  final Future<List<PokemonListItem>> futureList;

  const CombatScreen({
    super.key,
    required this.username,
    required this.service,
    required this.futureList,
  });

  @override
  State<CombatScreen> createState() => _CombatScreenState();
}

class _CombatScreenState extends State<CombatScreen> {
  final Random _rng = Random();

  _Stage _stage = _Stage.menu;
  _Mode _mode = _Mode.simulated;
  bool _teamLoading = true;
  List<TeamMember> _team = [];

  // Configuración del combate.
  int _cap = 50;
  Difficulty _difficulty = Difficulty.normal;
  bool _rivalRandom = true;
  int _rivalCount = 6;
  List<TeamMember?>? _rivalChosen;

  List<TeamMember> _rivalDefs = [];
  BattleEngine? _engine;
  String? _error;

  // Red local.
  NetSession? _net;
  bool _netHost = false;
  String? _opponentName;
  String _lobbyMsg = '';
  List<String> _ips = [];
  List<DiscoveredGame> _found = [];
  bool _searching = false;
  final TextEditingController _ipCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadTeam();
  }

  @override
  void dispose() {
    _ipCtrl.dispose();
    _net?.close();
    super.dispose();
  }

  Future<void> _loadTeam() async {
    final slots = await TeamService.load(widget.username);
    if (!mounted) return;
    setState(() {
      _team = slots.whereType<TeamMember>().toList();
      _rivalCount = _team.isEmpty ? 6 : _team.length;
      _teamLoading = false;
    });
  }

  void _openConfig(_Mode mode) {
    SoundService.instance.playSelect();
    setState(() {
      _mode = mode;
      _stage = _Stage.config;
      _error = null;
    });
  }

  void _toMenu() {
    SoundService.instance.playSelect();
    _net?.close();
    _net = null;
    setState(() {
      _stage = _Stage.menu;
      _engine = null;
      _opponentName = null;
      _error = null;
    });
  }

  Future<void> _pickRival() async {
    SoundService.instance.playSelect();
    final result = await Navigator.of(context).push<List<TeamMember?>>(
      MaterialPageRoute(
        builder: (ctx) => Scaffold(
          backgroundColor: AppColors.black,
          appBar: AppBar(
            backgroundColor: AppColors.red,
            foregroundColor: Colors.white,
            title: const Text('EQUIPO RIVAL'),
          ),
          body: Padding(
            padding: const EdgeInsets.all(12),
            child: TeamScreen(
              username: 'Rival',
              service: widget.service,
              futureList: widget.futureList,
              title: 'EQUIPO RIVAL',
              maxLevel: _cap,
              initialSlots: _rivalChosen,
              onConfirm: (slots) => Navigator.of(ctx).pop(slots),
            ),
          ),
        ),
      ),
    );
    if (result != null && mounted) setState(() => _rivalChosen = result);
  }

  Future<void> _startSimulation({bool rematch = false}) async {
    SoundService.instance.playSelect();
    setState(() {
      _stage = _Stage.loading;
      _error = null;
    });
    try {
      final List<TeamMember> rivalDefs;
      if (rematch && _rivalDefs.isNotEmpty) {
        rivalDefs = _rivalDefs;
      } else if (_rivalRandom) {
        rivalDefs = await RivalGenerator.randomTeam(
          widget.service,
          count: _rivalCount,
          maxLevel: _cap,
          rng: _rng,
        );
      } else {
        rivalDefs = (_rivalChosen ?? const <TeamMember?>[])
            .whereType<TeamMember>()
            .toList();
        if (rivalDefs.isEmpty) {
          throw Exception('Elige al menos un Pokémon para el equipo rival.');
        }
        for (final m in rivalDefs) {
          await RivalGenerator.completeMoves(widget.service, m, _cap, _rng);
        }
      }
      _rivalDefs = rivalDefs;

      final results = await Future.wait([
        BattleBuilder.buildTeam(widget.service, _team, _cap),
        BattleBuilder.buildTeam(widget.service, rivalDefs, _cap),
      ]);
      if (!mounted) return;
      setState(() {
        _engine = BattleEngine(
          player: results[0],
          rival: results[1],
          difficulty: _difficulty,
          rng: _rng,
        );
        _stage = _Stage.battle;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e'.replaceFirst('Exception: ', '');
        _stage = _Stage.config;
      });
    }
  }

  void _bluetoothInfo() {
    SoundService.instance.playSelect();
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Combate por Bluetooth'),
        content: Text(
          'Tu configuración (nivel máximo $_cap) está lista, pero la '
          'conexión Bluetooth con otro jugador todavía no está implementada '
          'en esta versión. Por ahora puedes practicar con el combate '
          'simulado.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('ENTENDIDO'),
          ),
        ],
      ),
    );
  }

  // ---------- Interfaz ----------
  @override
  Widget build(BuildContext context) {
    final title = switch (_stage) {
      _Stage.menu => 'MENÚ DE COMBATE',
      _Stage.config => 'CONFIGURAR COMBATE',
      _Stage.loading => 'PREPARANDO COMBATE',
      _Stage.lobby => 'PARTIDA EN RED LOCAL',
      _Stage.battle => _net != null ? 'COMBATE EN RED LOCAL' : 'COMBATE SIMULADO',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(
            title,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(child: _body()),
      ],
    );
  }

  Widget _body() {
    if (_teamLoading) {
      return _whitePanel(const Center(child: PokeballLoader(size: 64)));
    }
    switch (_stage) {
      case _Stage.menu:
        return _menu();
      case _Stage.config:
        return _config();
      case _Stage.loading:
        return _whitePanel(
          const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                PokeballLoader(size: 64),
                SizedBox(height: 12),
                Text('Preparando equipos...'),
              ],
            ),
          ),
        );
      case _Stage.lobby:
        return _lobby();
      case _Stage.battle:
        return BattleView(
          key: ValueKey(_engine),
          engine: _engine!,
          net: _net,
          isHost: _netHost,
          opponentName: _opponentName,
          onExit: _toMenu,
          onRematch: () => _startSimulation(rematch: true),
        );
    }
  }

  Widget _whitePanel(Widget child) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: child,
    );
  }

  // ---------- Menú ----------
  Widget _menu() {
    return LayoutBuilder(
      builder: (context, c) {
        final wide = c.maxWidth >= 760;
        final list = _teamList(horizontal: !wide);
        final panel = _menuPanel();
        if (wide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(width: 270, child: list),
              const SizedBox(width: 12),
              Expanded(child: panel),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(height: 76, child: list),
            const SizedBox(height: 12),
            Expanded(child: panel),
          ],
        );
      },
    );
  }

  Widget _teamList({required bool horizontal}) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(14),
      ),
      child: _team.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(12),
                child: Text('Sin equipo', textAlign: TextAlign.center),
              ),
            )
          : ListView.separated(
              scrollDirection: horizontal ? Axis.horizontal : Axis.vertical,
              padding: const EdgeInsets.all(8),
              itemCount: _team.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(width: 8, height: 8),
              itemBuilder: (context, i) {
                final tile = _TeamTile(member: _team[i], position: i + 1);
                return horizontal
                    ? SizedBox(width: 190, child: tile)
                    : SizedBox(height: 66, child: tile);
              },
            ),
    );
  }

  Widget _menuPanel() {
    final canFight = _team.isNotEmpty;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(14),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'RESUMEN DEL EQUIPO CONFIGURADO',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
            ),
            const SizedBox(height: 10),
            if (!canFight)
              const Padding(
                padding: EdgeInsets.only(bottom: 10),
                child: Text(
                  'Primero crea y guarda un equipo en la sección EQUIPO.',
                  style: TextStyle(color: AppColors.red),
                ),
              ),
            _modeCard(
              icon: Icons.psychology,
              title: 'COMBATE SIMULADO',
              text: 'Entrena contra un oponente de IA. Configura dificultad '
                  'y practica estrategias.',
              button: 'INICIAR SIMULACIÓN',
              onTap: canFight ? () => _openConfig(_Mode.simulated) : null,
            ),
            const SizedBox(height: 12),
            _modeCard(
              icon: Icons.wifi,
              title: 'RED LOCAL',
              text: 'Combate contra otra persona conectada a la misma red '
                  'Wi-Fi o LAN. Uno crea la partida y el otro se une.',
              button: 'JUGAR EN RED',
              onTap: canFight ? () => _openConfig(_Mode.network) : null,
            ),
            const SizedBox(height: 12),
            _modeCard(
              icon: Icons.bluetooth,
              title: 'POR BLUETOOTH',
              text: 'Conéctate y combate contra un amigo cercano. Asegúrate '
                  'de que el Bluetooth esté activado.',
              button: 'BUSCAR RIVAL',
              onTap: canFight ? () => _openConfig(_Mode.bluetooth) : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _modeCard({
    required IconData icon,
    required String title,
    required String text,
    required String button,
    required VoidCallback? onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 110,
              color: AppColors.panel,
              child: Icon(icon, size: 56, color: AppColors.black),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 6),
                    Text(text),
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerRight,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.black,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: onTap,
                        child: Text(
                          button,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------- Red local ----------
  String _clean(Object e) => '$e'.replaceFirst('Exception: ', '');

  List<Map<String, dynamic>> _teamJson() => [for (final t in _team) t.toJson()];

  void _netFail(String message, {bool toConfig = true}) {
    _net?.close();
    _net = null;
    if (!mounted) return;
    setState(() {
      _error = message;
      if (toConfig) _stage = _Stage.config;
    });
  }

  Future<void> _hostGame() async {
    SoundService.instance.playSelect();
    setState(() {
      _stage = _Stage.lobby;
      _netHost = true;
      _error = null;
      _ips = [];
      _lobbyMsg = 'Creando partida...';
    });
    try {
      final s = await NetSession.host(widget.username);
      if (!mounted) {
        s.close();
        return;
      }
      _net = s;
      s.onMessage = (m) {
        if (m['t'] == 'hello') {
          s.onMessage = null;
          _onGuestHello(s, m);
        } else if (m['t'] == 'closed') {
          _netFail('El rival se desconectó.');
        }
      };
      final ips = await NetSession.localAddresses();
      if (!mounted) return;
      setState(() {
        _ips = ips;
        _lobbyMsg = 'Esperando a un rival...';
      });
    } catch (e) {
      _netFail('No se pudo crear la partida: ${_clean(e)}');
    }
  }

  Future<void> _onGuestHello(NetSession s, Map<String, dynamic> m) async {
    if (!mounted) return;
    setState(() {
      _stage = _Stage.loading;
      _opponentName = (m['name'] as String?) ?? 'Rival';
    });
    try {
      final guestDefs = [
        for (final e in (m['team'] as List))
          TeamMember.fromJson(e as Map<String, dynamic>),
      ];
      if (guestDefs.isEmpty) throw Exception('El rival no tiene equipo.');
      final results = await Future.wait([
        BattleBuilder.buildTeam(widget.service, _team, _cap),
        BattleBuilder.buildTeam(widget.service, guestDefs, _cap),
      ]);
      s.send({
        't': 'start',
        'cap': _cap,
        'name': widget.username,
        'team': _teamJson(),
      });
      if (!mounted) return;
      setState(() {
        _engine = BattleEngine(
          player: results[0],
          rival: results[1],
          difficulty: Difficulty.normal,
          humanRival: true,
          rng: _rng,
        );
        _netHost = true;
        _stage = _Stage.battle;
      });
    } catch (e) {
      _netFail('No se pudo preparar el combate: ${_clean(e)}');
    }
  }

  void _openJoinLobby() {
    SoundService.instance.playSelect();
    setState(() {
      _stage = _Stage.lobby;
      _netHost = false;
      _error = null;
      _found = [];
      _lobbyMsg = '';
    });
    _searchGames();
  }

  Future<void> _searchGames() async {
    setState(() => _searching = true);
    final games = await NetSession.discover();
    if (!mounted) return;
    setState(() {
      _found = games;
      _searching = false;
    });
  }

  Future<void> _joinGame(String address, int port) async {
    SoundService.instance.playSelect();
    setState(() {
      _error = null;
      _lobbyMsg = 'Conectando...';
    });
    try {
      final s = await NetSession.join(address, port: port);
      if (!mounted) {
        s.close();
        return;
      }
      _net = s;
      s.onMessage = (m) {
        if (m['t'] == 'start') {
          s.onMessage = null;
          _onHostStart(s, m);
        } else if (m['t'] == 'closed' || m['t'] == 'bye') {
          _netFail('Se perdió la conexión con la partida.', toConfig: false);
          if (mounted) setState(() => _lobbyMsg = '');
        }
      };
      s.send({'t': 'hello', 'name': widget.username, 'team': _teamJson()});
      setState(() => _lobbyMsg = 'Conectado. Esperando al anfitrión...');
    } catch (e) {
      _netFail('No se pudo conectar: ${_clean(e)}', toConfig: false);
      if (mounted) setState(() => _lobbyMsg = '');
    }
  }

  Future<void> _onHostStart(NetSession s, Map<String, dynamic> m) async {
    if (!mounted) return;
    setState(() {
      _stage = _Stage.loading;
      _opponentName = (m['name'] as String?) ?? 'Anfitrión';
    });
    try {
      final cap = (m['cap'] as int?) ?? _cap;
      final hostDefs = [
        for (final e in (m['team'] as List))
          TeamMember.fromJson(e as Map<String, dynamic>),
      ];
      final results = await Future.wait([
        BattleBuilder.buildTeam(widget.service, _team, cap),
        BattleBuilder.buildTeam(widget.service, hostDefs, cap),
      ]);
      if (!mounted) return;
      setState(() {
        _cap = cap;
        // El invitado ve su equipo como "player" (el motor corre en el anfitrión).
        _engine = BattleEngine(
          player: results[0],
          rival: results[1],
          difficulty: Difficulty.normal,
          humanRival: true,
          rng: _rng,
        );
        _netHost = false;
        _stage = _Stage.battle;
      });
    } catch (e) {
      _netFail('No se pudo preparar el combate: ${_clean(e)}');
    }
  }

  Widget _lobby() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(14),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: _netHost ? _hostLobby() : _guestLobby(),
          ),
        ),
      ),
    );
  }

  Widget _hostLobby() {
    return InfoCard(
      title: 'ESPERANDO RIVAL',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const PokeballLoader(size: 32),
              const SizedBox(width: 12),
              Expanded(child: Text(_lobbyMsg)),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Dile a tu rival que elija "Unirse a partida". Si no te encuentra '
            'solo, que escriba una de estas direcciones:',
          ),
          const SizedBox(height: 6),
          if (_ips.isEmpty)
            const Text('(no se encontró ninguna IP)',
                style: TextStyle(color: AppColors.muted))
          else
            for (final ip in _ips)
              SelectableText(
                '$ip   (puerto ${NetSession.gamePort})',
                style: const TextStyle(
                    fontWeight: FontWeight.w800, fontSize: 16),
              ),
          const SizedBox(height: 14),
          OutlinedButton(onPressed: _toMenu, child: const Text('CANCELAR')),
        ],
      ),
    );
  }

  Widget _guestLobby() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InfoCard(
          title: 'PARTIDAS EN LA RED',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_searching)
                const Padding(
                  padding: EdgeInsets.all(8),
                  child: Row(
                    children: [
                      PokeballLoader(size: 28),
                      SizedBox(width: 12),
                      Text('Buscando partidas...'),
                    ],
                  ),
                )
              else if (_found.isEmpty)
                const Text(
                  'No se encontró ninguna partida. Pídele al anfitrión que '
                  'cree una o escribe su IP abajo.',
                  style: TextStyle(color: AppColors.muted),
                ),
              for (final g in _found)
                ListTile(
                  dense: true,
                  leading: const Icon(Icons.sports_esports),
                  title: Text(g.name),
                  subtitle: Text(g.address),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _joinGame(g.address, g.port),
                ),
              const SizedBox(height: 6),
              OutlinedButton.icon(
                onPressed: _searching ? null : _searchGames,
                icon: const Icon(Icons.refresh),
                label: const Text('BUSCAR DE NUEVO'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        InfoCard(
          title: 'CONECTAR POR IP',
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _ipCtrl,
                  keyboardType: TextInputType.url,
                  decoration: const InputDecoration(
                    hintText: 'Ej. 192.168.1.20',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (v) {
                    if (v.trim().isNotEmpty) {
                      _joinGame(v.trim(), NetSession.gamePort);
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.red,
                  foregroundColor: Colors.white,
                ),
                onPressed: () {
                  final ip = _ipCtrl.text.trim();
                  if (ip.isNotEmpty) _joinGame(ip, NetSession.gamePort);
                },
                child: const Text('CONECTAR'),
              ),
            ],
          ),
        ),
        if (_lobbyMsg.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(_lobbyMsg, textAlign: TextAlign.center),
        ],
        if (_error != null) ...[
          const SizedBox(height: 10),
          Text(
            _error!,
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: AppColors.red, fontWeight: FontWeight.w600),
          ),
        ],
        const SizedBox(height: 12),
        Center(
          child: OutlinedButton(onPressed: _toMenu, child: const Text('VOLVER')),
        ),
      ],
    );
  }

  // ---------- Configuración ----------
  Widget _config() {
    final simulated = _mode == _Mode.simulated;
    final network = _mode == _Mode.network;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(14),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  simulated
                      ? 'Combate simulado'
                      : (network ? 'Combate en red local' : 'Combate por Bluetooth'),
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 16),
                ),
                const SizedBox(height: 10),
                InfoCard(title: 'NIVEL MÁXIMO', child: _levelCapSection()),
                if (simulated) ...[
                  const SizedBox(height: 12),
                  InfoCard(title: 'DIFICULTAD', child: _difficultySection()),
                  const SizedBox(height: 12),
                  InfoCard(title: 'EQUIPO RIVAL', child: _rivalSection()),
                ],
                if (network) ...[
                  const SizedBox(height: 12),
                  const Text(
                    'Los dos dispositivos deben estar en la misma red. Si eres '
                    'el anfitrión, tu nivel máximo se aplica a ambos equipos. '
                    'Si Windows pregunta por el Firewall, permite el acceso en '
                    'redes privadas.',
                    style: TextStyle(fontSize: 12, color: AppColors.muted),
                  ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    style: const TextStyle(
                        color: AppColors.red, fontWeight: FontWeight.w600),
                  ),
                ],
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    OutlinedButton(
                      onPressed: _toMenu,
                      child: const Text('VOLVER'),
                    ),
                    if (network) ...[
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.red,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: _hostGame,
                        child: const Text(
                          'CREAR PARTIDA',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.black,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: _openJoinLobby,
                        child: const Text(
                          'UNIRSE A PARTIDA',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ] else
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.red,
                          foregroundColor: Colors.white,
                        ),
                        onPressed:
                            simulated ? _startSimulation : _bluetoothInfo,
                        child: Text(
                          simulated ? 'COMENZAR COMBATE' : 'BUSCAR RIVAL',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _levelCapSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 50,
              padding: const EdgeInsets.symmetric(vertical: 6),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFFE4E4E4),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text('$_cap',
                  style: const TextStyle(fontWeight: FontWeight.w800)),
            ),
            Expanded(
              child: Slider(
                min: 1,
                max: 100,
                divisions: 99,
                value: _cap.toDouble(),
                activeColor: AppColors.red,
                label: '$_cap',
                onChanged: (v) => setState(() {
                  _cap = v.round();
                  // Los Pokémon rivales elegidos se ajustan al nuevo máximo.
                  for (final m in _rivalChosen ?? const <TeamMember?>[]) {
                    if (m != null && m.level > _cap) m.level = _cap;
                  }
                }),
              ),
            ),
          ],
        ),
        const Text(
          'Los Pokémon con un nivel superior combaten con este nivel máximo.',
          style: TextStyle(fontSize: 12, color: AppColors.muted),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final m in _team)
              Chip(
                visualDensity: VisualDensity.compact,
                avatar: SpriteImage(id: m.pokemonId, size: 22),
                label: Text(
                  '${humanize(m.name)} Nv. ${m.level}'
                  '${m.level > _cap ? ' → $_cap' : ''}',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _difficultySection() {
    return SegmentedButton<Difficulty>(
      showSelectedIcon: false,
      style: SegmentedButton.styleFrom(
        selectedBackgroundColor: AppColors.black,
        selectedForegroundColor: Colors.white,
      ),
      segments: const [
        ButtonSegment(value: Difficulty.easy, label: Text('Fácil')),
        ButtonSegment(value: Difficulty.normal, label: Text('Normal')),
        ButtonSegment(value: Difficulty.hard, label: Text('Difícil')),
      ],
      selected: {_difficulty},
      onSelectionChanged: (s) => setState(() => _difficulty = s.first),
    );
  }

  Widget _rivalSection() {
    final chosen =
        (_rivalChosen ?? const <TeamMember?>[]).whereType<TeamMember>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SegmentedButton<bool>(
          showSelectedIcon: false,
          style: SegmentedButton.styleFrom(
            selectedBackgroundColor: AppColors.black,
            selectedForegroundColor: Colors.white,
          ),
          segments: const [
            ButtonSegment(value: true, label: Text('Aleatorio')),
            ButtonSegment(value: false, label: Text('Elegir equipo')),
          ],
          selected: {_rivalRandom},
          onSelectionChanged: (s) => setState(() => _rivalRandom = s.first),
        ),
        const SizedBox(height: 10),
        if (_rivalRandom) ...[
          Row(
            children: [
              Text('Pokémon rivales: $_rivalCount',
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              Expanded(
                child: Slider(
                  min: 1,
                  max: 6,
                  divisions: 5,
                  value: _rivalCount.toDouble(),
                  activeColor: AppColors.red,
                  label: '$_rivalCount',
                  onChanged: (v) => setState(() => _rivalCount = v.round()),
                ),
              ),
            ],
          ),
          const Text(
            'Pokémon, movimientos y objetos al azar (nivel cercano al máximo).',
            style: TextStyle(fontSize: 12, color: AppColors.muted),
          ),
        ] else ...[
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final m in chosen)
                Chip(
                  visualDensity: VisualDensity.compact,
                  avatar: SpriteImage(id: m.pokemonId, size: 22),
                  label: Text('${humanize(m.name)} Nv. ${m.level}',
                      style: const TextStyle(fontSize: 12)),
                ),
            ],
          ),
          if (chosen.isEmpty)
            const Text(
              'Aún no has elegido el equipo rival.',
              style: TextStyle(fontSize: 12, color: AppColors.muted),
            ),
          const SizedBox(height: 6),
          OutlinedButton.icon(
            onPressed: _pickRival,
            icon: const Icon(Icons.edit),
            label: const Text('ELEGIR EQUIPO RIVAL'),
          ),
          const SizedBox(height: 4),
          const Text(
            'Si dejas un Pokémon sin movimientos, se le asignan al azar.',
            style: TextStyle(fontSize: 12, color: AppColors.muted),
          ),
        ],
      ],
    );
  }
}

class _TeamTile extends StatelessWidget {
  final TeamMember member;
  final int position;
  const _TeamTile({required this.member, required this.position});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: position == 1 ? Colors.white : const Color(0xFFF7F7F7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: position == 1 ? AppColors.red : Colors.transparent,
          width: 2,
        ),
      ),
      child: Row(
        children: [
          SpriteImage(id: member.pokemonId, size: 46),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  humanize(member.name),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                Text(
                  'Nv. ${member.level}',
                  style:
                      const TextStyle(fontSize: 12, color: AppColors.muted),
                ),
              ],
            ),
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '#${member.pokemonId.toString().padLeft(3, '0')}',
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.muted),
              ),
              Text(
                '$position',
                style: const TextStyle(
                    fontWeight: FontWeight.w800, color: AppColors.muted),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
