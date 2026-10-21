import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../battle/battle_engine.dart';
import '../battle/net_session.dart';
import '../models/battle_move.dart';
import '../models/pokemon.dart';
import '../services/sound_service.dart';
import '../services/view_options.dart';
import '../theme/app_theme.dart';
import '../theme/type_style.dart';
import 'pokeball.dart';
import 'pokedex_ui.dart';

// ---------------------------------------------------------------------------
// Colores y etiquetas de los problemas de estado y efectos únicos
// ---------------------------------------------------------------------------
Color ailmentColor(String? ailment) {
  switch (ailment) {
    case 'paralysis':
      return const Color(0xFFF9A825);
    case 'burn':
      return const Color(0xFFEF6C00);
    case 'poison':
      return const Color(0xFF8E24AA);
    case 'sleep':
      return const Color(0xFF607D8B);
    case 'freeze':
      return const Color(0xFF26C6DA);
    case 'confusion':
      return const Color(0xFFEC407A);
    case 'infatuation':
      return const Color(0xFFE91E63);
    case 'curse':
      return const Color(0xFF4A148C);
    case 'leech-seed':
      return const Color(0xFF558B2F);
    case 'trap':
      return const Color(0xFF8D6E63);
    case 'nightmare':
      return const Color(0xFF283593);
    case 'yawn':
      return const Color(0xFF78909C);
    case 'perish-song':
      return const Color(0xFF37474F);
    case 'protect':
      return const Color(0xFF42A5F5);
    default:
      return const Color(0xFF9E9E9E);
  }
}

String ailmentBadge(String? ailment) {
  switch (ailment) {
    case 'paralysis':
      return 'PAR';
    case 'burn':
      return 'QUE';
    case 'poison':
      return 'ENV';
    case 'sleep':
      return 'DOR';
    case 'freeze':
      return 'HIE';
    case 'confusion':
      return 'CNF';
    case 'infatuation':
      return 'ATR';
    case 'curse':
      return 'MAL';
    case 'leech-seed':
      return 'DRE';
    case 'trap':
      return 'ATP';
    case 'nightmare':
      return 'PES';
    case 'yawn':
      return 'SUE';
    case 'perish-song':
      return 'CUE';
    default:
      return '';
  }
}

const Map<String, String> _stageAbbr = {
  'attack': 'ATQ',
  'defense': 'DEF',
  'special-attack': 'A.E',
  'special-defense': 'D.E',
  'speed': 'VEL',
};

/// Texto corto que describe un movimiento en su botón.
String describeMove(MoveData m) {
  final verb = kAilmentVerbs[m.ailment];
  final parts = <String>[];
  if (m.isDamaging) {
    if (m.category == 'ohko') {
      parts.add('KO · Prec. ${m.accuracy ?? '—'}');
    } else if (m.isFixed) {
      parts.add('Daño fijo · Prec. ${m.accuracy ?? '—'}');
    } else {
      parts.add('Pot. ${m.power} · Prec. ${m.accuracy ?? '—'}');
    }
    if (verb != null) parts.add('${m.ailmentChance}% $verb');
    if (m.drain > 0) parts.add('Absorbe');
    if (m.drain < 0) parts.add('Retroceso');
    if (m.flinchChance > 0) parts.add('${m.flinchChance}% Retroc.');
    if (m.statChanges.isNotEmpty &&
        (m.category == 'damage+lower' || m.category == 'damage+raise')) {
      parts.add(_statsText(m, withChance: true));
    }
    return parts.join(' · ');
  }
  switch (m.slug) {
    case 'curse':
      return 'Maldición';
    case 'protect':
    case 'detect':
      return 'Protección';
    case 'rest':
      return 'Descanso: cura y duerme';
    case 'max-guard':
      return 'Protección total este turno';
  }
  if (verb != null) parts.add(verb);
  if (m.statChanges.isNotEmpty) parts.add(_statsText(m));
  if (m.healing > 0) parts.add('Cura ${m.healing}%');
  if (parts.isEmpty) return 'Sin efecto en esta simulación';
  return parts.join(' · ');
}

String _statsText(MoveData m, {bool withChance = false}) {
  final s = m.statChanges.entries
      .map((e) =>
          '${_stageAbbr[e.key] ?? e.key}${e.value > 0 ? '+' : ''}${e.value}')
      .join(' ');
  final chance = withChance && m.statChance > 0 && m.statChance < 100
      ? '${m.statChance}% '
      : '';
  return '$chance$s${m.statsOnSelf ? ' (propio)' : ''}';
}

/// Pantalla del combate: arena con animaciones, registro y acciones.
/// Sirve para el combate contra la IA y para la red local (con [net]).
class BattleView extends StatefulWidget {
  final BattleEngine engine;
  final VoidCallback onExit;
  final VoidCallback onRematch;

  /// Conexión con el otro jugador (null = combate contra la IA).
  final NetSession? net;

  /// En red: true si este dispositivo es el anfitrión (ejecuta el combate).
  final bool isHost;
  final String? opponentName;

  const BattleView({
    super.key,
    required this.engine,
    required this.onExit,
    required this.onRematch,
    this.net,
    this.isHost = false,
    this.opponentName,
  });

  @override
  State<BattleView> createState() => _BattleViewState();
}

class _BattleViewState extends State<BattleView>
    with SingleTickerProviderStateMixin {
  final List<String> _log = [];
  final ScrollController _logScroll = ScrollController();
  late final AnimationController _fxCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 600),
    value: 1,
  );

  BattleFx? _fx;
  bool _busy = false;
  bool _showSwitch = false;
  bool _resultSounded = false;
  /// Transformación o Movimiento Z elegido para el próximo turno:
  /// 'mega', 'z', 'dyn' o 'tera' (solo una a la vez).
  String? _gimmick;

  // --- Red local ---
  bool _waitingOpp = false;
  bool _disconnected = false;
  BattleAction? _hostAction;
  BattleAction? _guestAction;
  Future<void> _chain = Future<void>.value();

  BattleEngine get _e => widget.engine;
  bool get _isNet => widget.net != null;
  bool get _isHost => _isNet && widget.isHost;
  bool get _isGuest => _isNet && !widget.isHost;
  String get _oppName => widget.opponentName ?? 'El rival';

  @override
  void initState() {
    super.initState();
    if (_isNet) {
      _log.addAll([
        '¡Comienza el combate contra $_oppName!',
        '¡Adelante, ${_e.activePlayer.name}!',
        '$_oppName envía a ${_e.activeRival.name}.',
      ]);
      widget.net!.onMessage = _onNet;
    } else {
      _log.addAll([
        '¡Comienza el combate!',
        '¡Adelante, ${_e.activePlayer.name}!',
        'El rival envía a ${_e.activeRival.name}.',
      ]);
    }
    SoundService.instance.playMusic('bt_music.wav', this);
  }

  @override
  void dispose() {
    widget.net?.onMessage = null;
    SoundService.instance.stopMusic(this);
    _fxCtrl.dispose();
    _logScroll.dispose();
    super.dispose();
  }

  void _scrollLog() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_logScroll.hasClients) return;
      _logScroll.animateTo(
        _logScroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  int _fxMillis(FxKind k) {
    switch (k) {
      case FxKind.move:
        return 520;
      case FxKind.hit:
        return 520;
      case FxKind.status:
        return 800;
      case FxKind.faint:
        return 700;
      case FxKind.miss:
        return 500;
      case FxKind.heal:
        return 650;
      case FxKind.send:
        return 550;
      case FxKind.mega:
        return 1100;
      case FxKind.stat:
        return 650;
      case FxKind.zmove:
        return 1000;
      case FxKind.dynamax:
        return 1100;
      case FxKind.tera:
        return 1100;
      case FxKind.weather:
        return 900;
    }
  }

  String _ailmentSound(String? a) {
    switch (a) {
      case 'paralysis':
        return 'paralysis';
      case 'burn':
        return 'burn';
      case 'poison':
        return 'poison';
      case 'sleep':
      case 'yawn':
        return 'sleep';
      case 'freeze':
        return 'freeze';
      case 'infatuation':
        return 'attract';
      case 'curse':
      case 'nightmare':
      case 'perish-song':
        return 'curse';
      case 'leech-seed':
        return 'drain';
      case 'trap':
        return 'trap';
      case 'protect':
        return 'cast';
      default:
        return 'confusion';
    }
  }

  void _fxSound(BattleFx fx) {
    final s = SoundService.instance;
    switch (fx.kind) {
      case FxKind.move:
        s.playSfx(fx.damaging ? 'bt_move.wav' : 'bt_cast.wav');
      case FxKind.hit:
        if (fx.crit) {
          s.playSfx('bt_crit.wav');
        } else if (fx.eff > 1) {
          s.playSfx('bt_hit_super.wav');
        } else if (fx.eff < 1) {
          s.playSfx('bt_hit_weak.wav');
        } else {
          s.playSfx('bt_hit.wav');
        }
      case FxKind.status:
        s.playSfx('bt_${_ailmentSound(fx.ailment)}.wav');
      case FxKind.faint:
        s.playSfx('bt_faint.wav');
      case FxKind.miss:
        s.playSfx('bt_miss.wav');
      case FxKind.heal:
        s.playSfx('bt_heal.wav');
      case FxKind.send:
        s.playSfx('bt_send.wav');
      case FxKind.mega:
        s.playSfx('bt_mega.wav');
      case FxKind.stat:
        s.playSfx(fx.up ? 'bt_statup.wav' : 'bt_statdown.wav');
      case FxKind.zmove:
        s.playSfx('bt_crit.wav');
      case FxKind.dynamax:
        s.playSfx(fx.up ? 'bt_mega.wav' : 'bt_statdown.wav');
      case FxKind.tera:
        s.playSfx('bt_mega.wav');
      case FxKind.weather:
        s.playSfx('bt_cast.wav');
    }
  }

  void _showFxAnim(BattleFx fx) {
    _fxCtrl.duration = Duration(milliseconds: _fxMillis(fx.kind));
    _fxCtrl.forward(from: 0);
    _fxSound(fx);
  }

  int _delayFor(BattleFx? fx) {
    if (fx == null) return 520;
    switch (fx.kind) {
      case FxKind.mega:
      case FxKind.dynamax:
      case FxKind.tera:
        return 1250;
      case FxKind.zmove:
        return 1100;
      default:
        return 780;
    }
  }

  void _maybeResultSound() {
    if (_e.winner != null && !_resultSounded) {
      _resultSounded = true;
      SoundService.instance.stopMusic(this);
      SoundService.instance
          .playSfx(_e.winner == 'player' ? 'bt_win.wav' : 'bt_lose.wav');
    }
  }

  /// Reproduce los eventos del motor (combate local o anfitrión).
  Future<void> _play(Iterable<String> events, {bool broadcast = false}) async {
    setState(() {
      _busy = true;
      _showSwitch = false;
    });
    for (final raw in events) {
      if (!mounted) return;
      final fx = _e.takeFx();
      if (broadcast) {
        widget.net?.send({
          't': 'ev',
          'line': raw,
          'fx': fx?.toJson(),
          'snap': _e.toSnapshot(),
        });
      }
      setState(() {
        _log.add(BattleEngine.render(raw, viewerIsP: true));
        if (fx != null) _fx = fx;
      });
      _scrollLog();
      if (fx != null) _showFxAnim(fx);
      await Future<void>.delayed(Duration(milliseconds: _delayFor(fx)));
    }
    if (!mounted) return;
    _maybeResultSound();
    setState(() => _busy = false);
  }

  // ---------- Red local ----------
  void _enqueue(Future<void> Function() job) {
    _chain = _chain.then((_) => job());
  }

  void _onNet(Map<String, dynamic> m) {
    switch (m['t']) {
      case 'act':
        if (!_isHost) return;
        _guestAction = m['switch'] != null
            ? BattleAction.change(m['switch'] as int)
            : BattleAction.move((m['move'] as int?) ?? 0,
                mega: m['mega'] == true,
                z: m['z'] == true,
                dynamax: m['dyn'] == true,
                tera: m['tera'] == true);
        _tryRunTurn();
      case 'switch':
        if (!_isHost) return;
        final i = (m['i'] as int?) ?? 0;
        _enqueue(() async {
          await _play(_e.rivalSwitchIn(i), broadcast: true);
          _afterHostPlay();
        });
      case 'ev':
        if (_isGuest) _enqueue(() => _showRemote(m));
      case 'ready':
        if (_isGuest) {
          _enqueue(() async {
            if (!mounted) return;
            _maybeResultSound();
            setState(() {
              _busy = false;
              _waitingOpp = m['hold'] == true;
            });
          });
        }
      case 'closed':
      case 'bye':
        _enqueue(() async => _onDisconnect());
    }
  }

  void _onDisconnect() {
    if (!mounted || _disconnected) return;
    if (_e.winner != null) return;
    setState(() {
      _disconnected = true;
      _busy = false;
      _waitingOpp = false;
      _log.add('Se perdió la conexión con $_oppName.');
    });
    _scrollLog();
  }

  void _tryRunTurn() {
    final h = _hostAction;
    final g = _guestAction;
    if (h == null || g == null) return;
    _hostAction = null;
    _guestAction = null;
    _enqueue(() async {
      await _play(_e.runTurn(h, g), broadcast: true);
      _afterHostPlay();
    });
  }

  void _afterHostPlay() {
    if (!mounted) return;
    widget.net?.send({'t': 'ready', 'hold': _e.needsPlayerSwitch});
    setState(() {
      _waitingOpp = _e.winner == null && _e.needsRivalSwitch;
    });
  }

  /// El invitado muestra un evento enviado por el anfitrión.
  Future<void> _showRemote(Map<String, dynamic> m) async {
    if (!mounted) return;
    final snap = m['snap'];
    if (snap is Map<String, dynamic>) _e.applySnapshot(snap, swap: true);
    final fx = BattleFx.fromJson(m['fx'], flip: true);
    final raw = (m['line'] as String?) ?? '';
    setState(() {
      _busy = true;
      _showSwitch = false;
      _log.add(BattleEngine.render(raw, viewerIsP: false));
      if (fx != null) _fx = fx;
    });
    _scrollLog();
    if (fx != null) _showFxAnim(fx);
    await Future<void>.delayed(Duration(milliseconds: _delayFor(fx)));
  }

  // ---------- Acciones del jugador ----------
  void _useMove(int i) {
    SoundService.instance.playSelect();
    final g = _gimmick;
    final action = BattleAction.move(
      i,
      mega: g == 'mega' && _e.canMega(true),
      z: g == 'z' && _e.zMoveFor(true, i) != null,
      dynamax: g == 'dyn' && _e.canDynamax(true),
      tera: g == 'tera' && _e.canTera(true),
    );
    setState(() => _gimmick = null);
    if (_isGuest) {
      widget.net!.send({
        't': 'act',
        'move': i,
        'mega': action.mega,
        'z': action.z,
        'dyn': action.dynamax,
        'tera': action.tera,
      });
      setState(() => _waitingOpp = true);
    } else if (_isHost) {
      _hostAction = action;
      setState(() => _waitingOpp = true);
      _tryRunTurn();
    } else {
      _play(_e.runTurn(action));
    }
  }

  void _switchTo(int i) {
    SoundService.instance.playSelect();
    final forced = _e.needsPlayerSwitch;
    if (_isGuest) {
      widget.net!.send(forced ? {'t': 'switch', 'i': i} : {'t': 'act', 'switch': i});
      setState(() {
        _waitingOpp = true;
        _showSwitch = false;
      });
    } else if (_isHost) {
      if (forced) {
        _enqueue(() async {
          await _play(_e.playerSwitchIn(i), broadcast: true);
          _afterHostPlay();
        });
      } else {
        _hostAction = BattleAction.change(i);
        setState(() {
          _waitingOpp = true;
          _showSwitch = false;
        });
        _tryRunTurn();
      }
    } else if (forced) {
      _play(_e.playerSwitchIn(i));
    } else {
      _play(_e.runTurn(BattleAction.change(i)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final wide = c.maxWidth >= 760;
        // Los Pokémon ocupan buena parte de la arena: su tamaño depende del
        // ancho disponible (de 120 a 190 px).
        final arenaW = wide ? c.maxWidth - 312 : c.maxWidth;
        final sprite = (arenaW * 0.42).clamp(120.0, 190.0).toDouble();
        final arenaH = sprite * 2 + 100;
        final arena = _arena(sprite);
        final log = _logPanel();
        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _topBar(),
              if (wide)
                SizedBox(
                  height: arenaH,
                  child: Row(
                    children: [
                      Expanded(child: arena),
                      const SizedBox(width: 12),
                      SizedBox(width: 300, child: log),
                    ],
                  ),
                )
              else ...[
                SizedBox(height: arenaH, child: arena),
                const SizedBox(height: 8),
                SizedBox(height: 130, child: log),
              ],
              const SizedBox(height: 8),
              _actionPanel(),
            ],
          ),
        );
      },
    );
  }

  Widget _topBar() {
    return Row(
      children: [
        if (_isNet)
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Text(
              'Red local · $_oppName',
              style: const TextStyle(
                  color: Colors.white70, fontWeight: FontWeight.w600),
            ),
          ),
        const Spacer(),
        ValueListenableBuilder<bool>(
          valueListenable: SoundService.instance.musicEnabled,
          builder: (context, on, _) => TextButton.icon(
            style: TextButton.styleFrom(foregroundColor: Colors.white),
            onPressed: () => SoundService.instance.toggleMusic(),
            icon: Icon(on ? Icons.music_note : Icons.music_off, size: 18),
            label: Text(on ? 'Música: sí' : 'Música: no'),
          ),
        ),
      ],
    );
  }

  // ---------- Arena ----------
  Widget _arena(double spriteSize) {
    return AnimatedBuilder(
      animation: _fxCtrl,
      builder: (context, child) {
        // Sacudida de la arena en golpes fuertes.
        var shake = 0.0;
        final f = _fx;
        final t = _fxCtrl.value;
        if (f != null &&
            f.kind == FxKind.hit &&
            (f.crit || f.eff > 1) &&
            t < 1) {
          shake = math.sin(t * math.pi * 14) * 5 * (1 - t);
        }
        return Transform.translate(offset: Offset(shake, 0), child: child);
      },
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Stack(
          children: [
            Column(
              children: [
                Expanded(
                    child: _monRow(_e.activeRival, _e.rival,
                        isPlayer: false, size: spriteSize)),
                const Divider(height: 8),
                Expanded(
                    child: _monRow(_e.activePlayer, _e.player,
                        isPlayer: true, size: spriteSize)),
              ],
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Center(child: _fieldChips()),
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _FxPainter(_fxCtrl, () => _fx, spriteSize),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Clima y terreno activos (arriba de la arena).
  Widget _fieldChips() {
    const weatherNames = {
      'sun': '☀ Sol',
      'rain': '☂ Lluvia',
      'hail': '❄ Granizo',
      'sand': '≋ Tormenta de arena',
    };
    const terrainNames = {
      'grassy': 'Campo de hierba',
      'electric': 'Campo eléctrico',
      'psychic': 'Campo psíquico',
      'misty': 'Campo de niebla',
    };
    final chips = <Widget>[
      if (_e.weather != null)
        _fieldChip('${weatherNames[_e.weather] ?? _e.weather} (${_e.weatherTurns})',
            const Color(0xFF42A5F5)),
      if (_e.terrain != null)
        _fieldChip('${terrainNames[_e.terrain] ?? _e.terrain} (${_e.terrainTurns})',
            const Color(0xFF66BB6A)),
    ];
    if (chips.isEmpty) return const SizedBox.shrink();
    return Wrap(spacing: 6, children: chips);
  }

  Widget _fieldChip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
      decoration: BoxDecoration(
        color: color.withAlpha(40),
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(text,
          style: TextStyle(
              fontSize: 10, fontWeight: FontWeight.w800, color: color)),
    );
  }

  Widget _monRow(BattleMon mon, List<BattleMon> team,
      {required bool isPlayer, required double size}) {
    final sprite = _FxSprite(
      id: mon.id,
      back: isPlayer,
      fainted: mon.fainted,
      isPlayer: isPlayer,
      ctrl: _fxCtrl,
      fx: _fx,
      size: size,
      dynamaxed: mon.dynamaxed,
      gigantamax: mon.gigantamaxed,
      teraType: mon.terastallized ? mon.teraType : null,
    );
    final info = Expanded(child: _infoBox(mon, team, isPlayer));
    return Row(
      children: isPlayer
          ? [sprite, const SizedBox(width: 10), info]
          : [info, const SizedBox(width: 10), sprite],
    );
  }

  Widget _statusBadge(String ailment) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: ailmentColor(ailment),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        ailmentBadge(ailment),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _stageChip(String stat, int value) {
    final up = value > 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: up ? const Color(0xFFE8F5E9) : const Color(0xFFFFEBEE),
        border: Border.all(color: up ? const Color(0xFF43A047) : AppColors.red),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '${_stageAbbr[stat] ?? stat}${up ? '+' : ''}$value',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: up ? const Color(0xFF2E7D32) : AppColors.red,
        ),
      ),
    );
  }

  List<Widget> _badgesFor(BattleMon m) {
    final keys = <String>[
      if (m.status != null) m.status!,
      if (m.confusion > 0) 'confusion',
      if (m.infatuated) 'infatuation',
      if (m.cursed) 'curse',
      if (m.seeded) 'leech-seed',
      if (m.trapTurns > 0) 'trap',
      if (m.nightmare) 'nightmare',
      if (m.yawn > 0) 'yawn',
      if (m.perish > 0) 'perish-song',
    ];
    return [
      for (final k in keys) _statusBadge(k),
      for (final e in m.stages.entries)
        if (e.value != 0) _stageChip(e.key, e.value),
    ];
  }

  /// Insignias de transformación: Mega, Dinamax/Gigamax y Tera.
  List<Widget> _formBadges(BattleMon m) {
    Widget chip(String text, Color color) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            text,
            style: TextStyle(
              color: onColorFor(color),
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        );
    return [
      if (m.megaEvolved) chip('MEGA', const Color(0xFFFFB300)),
      if (m.dynamaxed)
        chip(
          '${m.gigantamaxed ? 'GIGAMAX' : 'DINAMAX'} ${m.dynamaxTurns}',
          m.gigantamaxed ? const Color(0xFFD81B60) : const Color(0xFFE53935),
        ),
      if (m.terastallized)
        chip('TERA ${styleOf(m.teraType ?? 'normal').label.toUpperCase()}',
            styleOf(m.teraType ?? 'normal').color),
    ];
  }

  Widget _infoBox(BattleMon mon, List<BattleMon> team, bool isPlayer) {
    final frac = mon.hpFraction;
    final color = frac > 0.5
        ? const Color(0xFF43A047)
        : (frac > 0.2 ? const Color(0xFFFBC02D) : AppColors.red);
    final badges = [..._formBadges(mon), ..._badgesFor(mon)];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${isPlayer ? '' : 'Rival · '}${mon.name}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 12),
                ),
              ),
              Text('Nv. ${mon.level}',
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 11)),
            ],
          ),
          const SizedBox(height: 2),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(end: frac),
              duration: const Duration(milliseconds: 400),
              builder: (context, v, _) => LinearProgressIndicator(
                value: v,
                minHeight: 4,
                color: color,
                backgroundColor: const Color(0xFFCFCFCF),
              ),
            ),
          ),
          Text(
            'PS ${mon.hp}/${mon.maxHp}',
            style: const TextStyle(fontSize: 9.5, color: AppColors.muted),
          ),
          if (badges.isNotEmpty) ...[
            const SizedBox(height: 3),
            Wrap(spacing: 4, runSpacing: 3, children: badges),
          ],
          const SizedBox(height: 4),
          Row(
            children: [
              for (final m in team)
                Padding(
                  padding: const EdgeInsets.only(right: 3),
                  child: Icon(
                    Icons.circle,
                    size: 10,
                    color: m.fainted ? const Color(0xFFBDBDBD) : AppColors.red,
                  ),
                ),
              const Spacer(),
              if (mon.zUsed)
                const Icon(Icons.flash_on, size: 13, color: Color(0xFFFFB300)),
              if (mon.item != null)
                const Icon(Icons.inventory_2_outlined,
                    size: 13, color: AppColors.muted),
            ],
          ),
        ],
      ),
    );
  }

  // ---------- Registro ----------
  Widget _logPanel() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.black,
        borderRadius: BorderRadius.circular(14),
      ),
      child: ListView.builder(
        controller: _logScroll,
        itemCount: _log.length,
        itemBuilder: (context, i) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Text(
            _log[i],
            style: TextStyle(
              color: i == _log.length - 1 ? Colors.white : Colors.white60,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }

  // ---------- Acciones ----------
  Widget _waitingPanel() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const PokeballLoader(size: 28),
          const SizedBox(width: 12),
          Text('Esperando a $_oppName...',
              style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _switchPanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('¡Elige al siguiente Pokémon!',
            style: TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        _switchTiles(),
      ],
    );
  }

  Widget _actionPanel() {
    final Widget content;
    if (_disconnected && _e.winner == null) {
      content = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Conexión perdida',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: AppColors.red)),
          const SizedBox(height: 10),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.black,
              foregroundColor: Colors.white,
            ),
            onPressed: widget.onExit,
            child: const Text('VOLVER AL MENÚ'),
          ),
        ],
      );
    } else if (_e.winner != null && !_busy) {
      content = _resultPanel();
    } else if (_busy) {
      content = const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: PokeballLoader(size: 36)),
      );
    } else if (_isGuest && _waitingOpp) {
      content = _waitingPanel();
    } else if (_e.needsPlayerSwitch) {
      content = _switchPanel();
    } else if (_waitingOpp) {
      content = _waitingPanel();
    } else {
      content = _movesPanel();
    }
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: content,
    );
  }

  Widget _movesPanel() {
    final trapped = _e.playerTrapped;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _moveGrid(),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            OutlinedButton.icon(
              onPressed: trapped
                  ? null
                  : () => setState(() => _showSwitch = !_showSwitch),
              icon: const Icon(Icons.swap_horiz),
              label: Text(trapped ? 'ATRAPADO' : 'CAMBIAR POKÉMON'),
            ),
            if (_e.canMega(true))
              _gimmickChip('mega', 'MEGAEVOLUCIONAR', Icons.auto_awesome,
                  const Color(0xFFFFB300)),
            if (_hasZ())
              _gimmickChip(
                  'z', 'MOVIMIENTO Z', Icons.flash_on, const Color(0xFFFFB300)),
            if (_e.canDynamax(true))
              _gimmickChip(
                'dyn',
                _e.activePlayer.dyna?.gmax != null ? 'GIGAMAX' : 'DINAMAX',
                Icons.open_in_full,
                const Color(0xFFE53935),
              ),
            if (_e.canTera(true))
              _gimmickChip(
                'tera',
                'TERACRISTALIZAR (${styleOf(_e.activePlayer.teraType ?? 'normal').label})',
                Icons.diamond_outlined,
                styleOf(_e.activePlayer.teraType ?? 'normal').color,
              ),
          ],
        ),
        if (_showSwitch && !trapped) ...[
          const SizedBox(height: 8),
          _switchTiles(),
        ],
      ],
    );
  }

  bool _hasZ() {
    for (var i = 0; i < _e.activePlayer.moves.length; i++) {
      if (_e.zMoveFor(true, i) != null) return true;
    }
    return false;
  }

  /// Casilla para activar una transformación o el Movimiento Z (solo una).
  Widget _gimmickChip(String key, String label, IconData icon, Color color) {
    return FilterChip(
      avatar: Icon(icon, size: 18, color: color),
      label: Text(label),
      selected: _gimmick == key,
      onSelected: (v) => setState(() => _gimmick = v ? key : null),
    );
  }

  Widget _resultPanel() {
    final won = _e.winner == 'player';
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          won ? '¡HAS GANADO!' : 'HAS PERDIDO',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: won ? const Color(0xFF2E7D32) : AppColors.red,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: [
            if (!_isNet)
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.red,
                  foregroundColor: Colors.white,
                ),
                onPressed: widget.onRematch,
                child: const Text('REVANCHA'),
              ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.black,
                foregroundColor: Colors.white,
              ),
              onPressed: widget.onExit,
              child: const Text('VOLVER AL MENÚ'),
            ),
          ],
        ),
      ],
    );
  }

  /// Botón del movimiento [i] mostrando su versión Máxima (Dinamax o si se
  /// va a Dinamaxizar) o Z (si está marcado el Movimiento Z).
  Widget _moveButtonFor(BattleMon mon, int i) {
    var move = mon.currentMoves[i];
    var enabled = mon.dynamaxed || mon.lockedMove == null || mon.lockedMove == i;
    if (_gimmick == 'z') {
      final zm = _e.zMoveFor(true, i);
      if (zm != null) {
        move = zm;
      } else {
        enabled = false;
      }
    } else if (_gimmick == 'dyn') {
      move = mon.maxVersion(mon.moves[i]);
    }
    return _MoveButton(
      move: move,
      enabled: enabled,
      onTap: () => _useMove(i),
    );
  }

  Widget _moveGrid() {
    final mon = _e.activePlayer;
    return LayoutBuilder(
      builder: (context, c) {
        final cols = c.maxWidth >= 420 ? 2 : 1;
        const gap = 8.0;
        final w = (c.maxWidth - gap * (cols - 1)) / cols;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (var i = 0; i < mon.moves.length; i++)
              SizedBox(
                width: w,
                child: _moveButtonFor(mon, i),
              ),
          ],
        );
      },
    );
  }

  Widget _switchTiles() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (var i = 0; i < _e.player.length; i++)
          if (i != _e.playerActiveIndex || _e.needsPlayerSwitch)
            _SwitchTile(
              mon: _e.player[i],
              onTap: _e.player[i].fainted ? null : () => _switchTo(i),
            ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Sprite animado
// ---------------------------------------------------------------------------
class _FxSprite extends StatelessWidget {
  final int id;
  final bool back;
  final bool fainted;
  final bool isPlayer;
  final AnimationController ctrl;
  final BattleFx? fx;
  final double size;
  final bool dynamaxed;
  final bool gigantamax;
  final String? teraType;

  const _FxSprite({
    required this.id,
    required this.back,
    required this.fainted,
    required this.isPlayer,
    required this.ctrl,
    required this.fx,
    required this.size,
    this.dynamaxed = false,
    this.gigantamax = false,
    this.teraType,
  });

  @override
  Widget build(BuildContext context) {
    final shiny = ViewOptions.shiny.value;
    const base = 'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/';
    final url = back
        ? '$base' 'back/${shiny ? 'shiny/' : ''}$id.png'
        : spriteUrlFor(id, shiny: shiny);
    Widget image = Image.network(
      url,
      width: size,
      height: size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.none,
      errorBuilder: (_, __, ___) =>
          SpriteImage(id: id, size: size, shiny: shiny),
    );
    // Resplandor: Teracristal (color del tipo) o Dinamax/Gigamax.
    final glow = teraType != null
        ? styleOf(teraType!).color
        : (dynamaxed
            ? (gigantamax ? const Color(0xFFD81B60) : const Color(0xFFE53935))
            : null);
    if (glow != null) {
      image = DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(color: glow.withAlpha(150), blurRadius: 28, spreadRadius: 4),
          ],
        ),
        child: image,
      );
    }
    if (dynamaxed) image = Transform.scale(scale: 1.2, child: image);

    return AnimatedBuilder(
      animation: ctrl,
      child: image,
      builder: (context, child) {
        final t = ctrl.value;
        final f = fx;
        var dx = 0.0;
        var dy = 0.0;
        var scale = 1.0;
        var opacity = fainted ? 0.3 : 1.0;
        Color? tint;

        if (f != null && t < 1 && f.onPlayer == isPlayer) {
          switch (f.kind) {
            case FxKind.move:
              final p = math.sin(math.pi * t);
              final dir = isPlayer ? const Offset(1, -0.5) : const Offset(-1, 0.5);
              dx = dir.dx * p * 30;
              dy = dir.dy * p * 30;
            case FxKind.hit:
              dx = math.sin(t * math.pi * 10) * 9 * (1 - t);
              if (t < 0.8 && (t * 10).floor().isEven) opacity *= 0.35;
            case FxKind.status:
              tint = ailmentColor(f.ailment)
                  .withAlpha((math.sin(math.pi * t) * 150).round());
            case FxKind.faint:
              dy = 40 * t;
              opacity = 1 - 0.7 * t;
            case FxKind.send:
              scale = Curves.elasticOut.transform(t).clamp(0.0, 1.3).toDouble();
              opacity = math.min(1.0, t * 4);
            case FxKind.heal:
              tint = const Color(0xFF66BB6A)
                  .withAlpha((math.sin(math.pi * t) * 110).round());
            case FxKind.miss:
              dx = math.sin(math.pi * t) * 16 * (isPlayer ? -1 : 1);
            case FxKind.mega:
              scale = 1 + 0.3 * math.sin(math.pi * t);
              tint = Colors.white.withAlpha((math.sin(math.pi * t) * 220).round());
            case FxKind.stat:
              dy = math.sin(math.pi * t) * (f.up ? -8 : 8);
            case FxKind.zmove:
              scale = 1 + 0.12 * math.sin(math.pi * t);
              tint = const Color(0xFFFFC107)
                  .withAlpha((math.sin(math.pi * t) * 140).round());
            case FxKind.dynamax:
              scale = f.up ? 0.7 + 0.3 * t : 1.3 - 0.3 * t;
            case FxKind.tera:
              tint = styleOf(f.type ?? 'normal')
                  .color
                  .withAlpha((math.sin(math.pi * t) * 170).round());
            case FxKind.weather:
              break;
          }
        }

        Widget w = child!;
        if (tint != null) {
          w = ColorFiltered(
            colorFilter: ColorFilter.mode(tint, BlendMode.srcATop),
            child: w,
          );
        }
        return Opacity(
          opacity: opacity.clamp(0.0, 1.0).toDouble(),
          child: Transform.translate(
            offset: Offset(dx, dy),
            child: Transform.scale(scale: scale, child: w),
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Efectos especiales dibujados sobre la arena
// ---------------------------------------------------------------------------
class _FxPainter extends CustomPainter {
  final Animation<double> anim;
  final BattleFx? Function() fxOf;
  final double spriteSize;

  _FxPainter(this.anim, this.fxOf, this.spriteSize) : super(repaint: anim);

  @override
  bool shouldRepaint(covariant _FxPainter oldDelegate) => true;

  Color _a(Color c, double alpha) =>
      c.withAlpha((alpha.clamp(0.0, 1.0) * 255).round());

  void _text(Canvas canvas, String s, Offset center, double size, Color color) {
    final tp = TextPainter(
      text: TextSpan(
        text: s,
        style: TextStyle(
            fontSize: size, color: color, fontWeight: FontWeight.w900),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final fx = fxOf();
    if (fx == null) return;
    final t = anim.value;
    if (t >= 1) return;

    // Posiciones aproximadas de los sprites dentro de la arena.
    final rival = Offset(size.width - 10 - spriteSize / 2, size.height * 0.26);
    final player = Offset(10 + spriteSize / 2, size.height * 0.74);
    final self = fx.onPlayer ? player : rival;
    final other = fx.onPlayer ? rival : player;

    switch (fx.kind) {
      case FxKind.move:
        _paintMove(canvas, fx, t, self, other);
      case FxKind.hit:
        _paintHit(canvas, fx, t, self);
      case FxKind.status:
        _paintStatus(canvas, fx.ailment, t, self);
      case FxKind.faint:
        for (var k = 0; k < 6; k++) {
          final p = Offset(self.dx + (k - 2.5) * 14, self.dy + 30 - 40 * t);
          canvas.drawCircle(
            p,
            6 + 10 * t,
            Paint()..color = _a(const Color(0xFF9E9E9E), (1 - t) * 0.6),
          );
        }
      case FxKind.heal:
        for (var k = 0; k < 4; k++) {
          final tt = (t + k * 0.2) % 1.0;
          final p = Offset(self.dx + (k - 1.5) * 22, self.dy + 30 - 70 * tt);
          final paint = Paint()
            ..color = _a(const Color(0xFF43A047), 1 - tt)
            ..strokeWidth = 4
            ..strokeCap = StrokeCap.round;
          canvas.drawLine(p - const Offset(7, 0), p + const Offset(7, 0), paint);
          canvas.drawLine(p - const Offset(0, 7), p + const Offset(0, 7), paint);
        }
      case FxKind.send:
        canvas.drawCircle(
          self,
          20 + 55 * t,
          Paint()..color = _a(Colors.white, (1 - t) * 0.7),
        );
        final ring = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = _a(AppColors.red, 1 - t);
        canvas.drawCircle(self, 10 + 70 * t, ring);
      case FxKind.miss:
        _text(canvas, '¡Falló!', self + Offset(0, -50 - 20 * t), 16,
            _a(AppColors.muted, 1 - t));
      case FxKind.mega:
        _paintMega(canvas, t, self);
      case FxKind.stat:
        _paintStat(canvas, fx.up, t, self);
      case FxKind.zmove:
        _paintZ(canvas, styleOf(fx.type ?? 'normal').color, t, self);
      case FxKind.dynamax:
        _paintDynamax(canvas, fx, t, self);
      case FxKind.tera:
        _paintTera(canvas, styleOf(fx.type ?? 'normal').color, t, self);
      case FxKind.weather:
        _paintWeather(canvas, size, fx.ailment, t);
    }
  }

  void _paintZ(Canvas canvas, Color color, double t, Offset at) {
    const gold = Color(0xFFFFC107);
    for (var k = 0; k < 3; k++) {
      final tt = (t - k * 0.15).clamp(0.0, 1.0).toDouble();
      canvas.drawCircle(
        at,
        110 - 90 * tt,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..color = _a(k.isEven ? gold : color, tt < 1 ? 0.3 + 0.7 * tt : 0),
      );
    }
    _text(canvas, 'Z', at + Offset(0, -80 - 20 * t), 26, _a(gold, 1 - t * 0.5));
  }

  void _paintDynamax(Canvas canvas, BattleFx fx, double t, Offset at) {
    final color =
        fx.ailment == 'gmax' ? const Color(0xFFD81B60) : const Color(0xFFE53935);
    final r = fx.up ? 20 + 110 * t : 130 - 110 * t;
    canvas.drawCircle(at, r, Paint()..color = _a(color, (1 - t) * 0.45));
    canvas.drawCircle(
      at,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..color = _a(Colors.white, 1 - t),
    );
    if (fx.up) {
      _text(canvas, fx.ailment == 'gmax' ? 'GIGAMAX' : 'DINAMAX',
          at + Offset(0, -90 - 20 * t), 16, _a(color, 1 - t * 0.6));
    }
  }

  void _paintTera(Canvas canvas, Color color, double t, Offset at) {
    for (var k = 0; k < 8; k++) {
      final ang = 2 * math.pi * k / 8 + t * 2;
      final r = 30 + 70 * t;
      final c = at + Offset(math.cos(ang), math.sin(ang)) * r;
      final path = Path()
        ..moveTo(c.dx, c.dy - 12)
        ..lineTo(c.dx + 8, c.dy)
        ..lineTo(c.dx, c.dy + 12)
        ..lineTo(c.dx - 8, c.dy)
        ..close();
      canvas.drawPath(path, Paint()..color = _a(color, 1 - t * 0.7));
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = _a(Colors.white, 1 - t),
      );
    }
    _text(canvas, 'TERA', at + Offset(0, -90 - 20 * t), 16, _a(color, 1 - t * 0.6));
  }

  void _paintWeather(Canvas canvas, Size size, String? key, double t) {
    final fade = math.sin(math.pi * t);
    Color tint;
    switch (key) {
      case 'sun':
        tint = const Color(0xFFFFC107);
      case 'rain':
        tint = const Color(0xFF42A5F5);
      case 'hail':
        tint = const Color(0xFFB3E5FC);
      case 'sand':
        tint = const Color(0xFFD7B66B);
      case 'grassy':
        tint = const Color(0xFF66BB6A);
      case 'electric':
        tint = const Color(0xFFFDD835);
      case 'psychic':
        tint = const Color(0xFFEC407A);
      default:
        tint = const Color(0xFFF8BBD0);
    }
    canvas.drawRect(Offset.zero & size, Paint()..color = _a(tint, 0.35 * fade));
    for (var k = 0; k < 18; k++) {
      final x = size.width * ((k * 0.137 + 0.05) % 1.0);
      final y = size.height * ((t * 1.2 + k * 0.19) % 1.0);
      canvas.drawCircle(Offset(x, y), 3, Paint()..color = _a(tint, 0.8 * fade));
    }
  }

  void _paintMega(Canvas canvas, double t, Offset at) {
    canvas.drawCircle(
      at,
      20 + 95 * t,
      Paint()..color = _a(Colors.white, (1 - t) * 0.6),
    );
    for (var k = 0; k < 12; k++) {
      final ang = 2 * math.pi * k / 12 + t * 4;
      final r = 25 + 55 * t;
      final p = at + Offset(math.cos(ang), math.sin(ang)) * r;
      final c = HSVColor.fromAHSV(
              (1 - t * 0.5).clamp(0.0, 1.0).toDouble(), (k * 30.0) % 360, 0.8, 1)
          .toColor();
      canvas.drawCircle(p, 6 * (1 - t * 0.5) + 2, Paint()..color = c);
    }
    _text(canvas, 'MEGA', at + Offset(0, -62 - 20 * t), 16,
        _a(const Color(0xFFFFB300), 1 - t));
  }

  void _paintStat(Canvas canvas, bool up, double t, Offset at) {
    final color = up ? const Color(0xFF43A047) : AppColors.red;
    for (var k = 0; k < 3; k++) {
      final tt = (t + k * 0.25) % 1.0;
      final x = at.dx + (k - 1) * 24.0;
      final y = up ? at.dy + 30 - 70 * tt : at.dy - 40 + 70 * tt;
      final path = Path();
      if (up) {
        path
          ..moveTo(x, y - 9)
          ..lineTo(x - 9, y + 6)
          ..lineTo(x + 9, y + 6);
      } else {
        path
          ..moveTo(x, y + 9)
          ..lineTo(x - 9, y - 6)
          ..lineTo(x + 9, y - 6);
      }
      path.close();
      canvas.drawPath(path, Paint()..color = _a(color, 1 - tt));
    }
  }

  void _paintMove(Canvas canvas, BattleFx fx, double t, Offset from, Offset to) {
    final color = styleOf(fx.type ?? 'normal').color;
    if (!fx.damaging) {
      // Movimiento de estado: ondas alrededor de quien lo lanza.
      for (var k = 0; k < 2; k++) {
        final tt = (t - k * 0.25).clamp(0.0, 1.0).toDouble();
        canvas.drawCircle(
          from,
          18 + 55 * tt,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 4
            ..color = _a(color, 1 - tt),
        );
      }
      return;
    }
    final p = Curves.easeIn.transform(t);
    final glow = Paint()
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    final type = fx.type;
    if (type == 'electric') {
      // Rayo en zigzag hasta el proyectil.
      final head = Offset.lerp(from, to, p)!;
      final path = Path()..moveTo(from.dx, from.dy);
      const segs = 7;
      for (var i = 1; i <= segs; i++) {
        final q = Offset.lerp(from, head, i / segs)!;
        final off = (i.isEven ? 1 : -1) * 9.0 * ((t * 20).floor() % 2 == 0 ? 1 : -1);
        path.lineTo(q.dx + off * 0.6, q.dy + off);
      }
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..strokeCap = StrokeCap.round
          ..color = _a(color, 1),
      );
      return;
    }
    for (var i = 0; i < 6; i++) {
      final q = (p - i * 0.045).clamp(0.0, 1.0).toDouble();
      final pos = Offset.lerp(from, to, q)!;
      final r = 13.0 - i * 1.6;
      final c = _a(color, 1 - i * 0.15);
      if (type == 'ice') {
        canvas.save();
        canvas.translate(pos.dx, pos.dy);
        canvas.rotate(t * 6 + i);
        canvas.drawRect(
          Rect.fromCenter(center: Offset.zero, width: r * 1.6, height: r * 1.6),
          Paint()..color = c,
        );
        canvas.restore();
      } else {
        if (i == 0) {
          canvas.drawCircle(pos, r + 6, glow..color = _a(color, 0.7));
        }
        canvas.drawCircle(pos, r, Paint()..color = c);
        if (i == 0) {
          canvas.drawCircle(pos, r * 0.4, Paint()..color = Colors.white);
        }
      }
    }
  }

  void _paintHit(Canvas canvas, BattleFx fx, double t, Offset at) {
    final strong = fx.crit || fx.eff > 1;
    final base = fx.eff > 1
        ? const Color(0xFFFF7043)
        : (fx.eff < 1 ? const Color(0xFF9E9E9E) : Colors.white);
    canvas.drawCircle(
      at,
      10 + 36 * t,
      Paint()..color = _a(base, (1 - t) * 0.5),
    );
    final typeColor = styleOf(fx.type ?? 'normal').color;
    canvas.drawCircle(
      at,
      16 + 34 * t,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = _a(typeColor, 1 - t),
    );
    final lines = Paint()
      ..strokeWidth = strong ? 5 : 3
      ..strokeCap = StrokeCap.round
      ..color = _a(fx.crit ? const Color(0xFFFFEB3B) : base, 1 - t);
    final reach = strong ? 30.0 : 20.0;
    for (var k = 0; k < 8; k++) {
      final ang = k * math.pi / 4 + 0.3;
      final r0 = 14 + 14 * t;
      final r1 = r0 + reach * (1 - t * 0.4);
      canvas.drawLine(
        at + Offset(math.cos(ang), math.sin(ang)) * r0,
        at + Offset(math.cos(ang), math.sin(ang)) * r1,
        lines,
      );
    }
    if (fx.crit) {
      _text(canvas, '¡CRÍTICO!', at + Offset(0, -56 - 12 * t), 14,
          _a(const Color(0xFFFFB300), 1 - t));
    }
  }

  void _paintDarkSwirl(Canvas canvas, Color color, double t, Offset at) {
    canvas.drawCircle(
      at,
      22,
      Paint()..color = _a(color, 0.45 * math.sin(math.pi * t)),
    );
    for (var k = 0; k < 8; k++) {
      final ang = 2 * math.pi * k / 8 + t * 3;
      final r = 58 * (1 - t) + 8;
      final p = at + Offset(math.cos(ang), math.sin(ang)) * r;
      canvas.drawCircle(p, 7, Paint()..color = _a(color, 0.9 - t * 0.4));
    }
  }

  void _paintStatus(Canvas canvas, String? ailment, double t, Offset at) {
    final color = ailmentColor(ailment);
    switch (ailment) {
      case 'paralysis':
        for (var k = 0; k < 3; k++) {
          if (((t * 14).floor() + k).isEven) continue;
          final x = at.dx + (k - 1) * 24.0;
          final path = Path()..moveTo(x, at.dy - 44);
          for (var i = 1; i <= 5; i++) {
            path.lineTo(x + (i.isEven ? 8 : -8), at.dy - 44 + i * 16);
          }
          canvas.drawPath(
            path,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 3.5
              ..strokeCap = StrokeCap.round
              ..color = _a(const Color(0xFFFFEB3B), 1 - t * 0.5),
          );
        }
      case 'burn':
        for (var k = 0; k < 7; k++) {
          final tt = (t + k * 0.14) % 1.0;
          final p = Offset(at.dx + (k - 3) * 11.0, at.dy + 30 - 70 * tt);
          canvas.drawCircle(
            p,
            8 * (1 - tt) + 2,
            Paint()
              ..color = _a(
                  k.isEven ? const Color(0xFFFF7043) : const Color(0xFFFFCA28),
                  1 - tt * 0.6),
          );
        }
      case 'poison':
        for (var k = 0; k < 6; k++) {
          final tt = (t * 0.9 + k * 0.17) % 1.0;
          final p = Offset(at.dx + (k - 2.5) * 14.0 + math.sin(tt * 8) * 4,
              at.dy + 30 - 66 * tt);
          canvas.drawCircle(p, 4 + 5 * (1 - tt), Paint()..color = _a(color, 0.55));
          canvas.drawCircle(
            p,
            4 + 5 * (1 - tt),
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.5
              ..color = _a(const Color(0xFFE1BEE7), 0.9),
          );
        }
      case 'sleep':
      case 'yawn':
        for (var k = 0; k < 3; k++) {
          final tt = (t + k * 0.28) % 1.0;
          _text(
            canvas,
            'Z',
            Offset(at.dx + 22 + k * 12.0, at.dy - 20 - 50 * tt),
            12 + k * 5.0,
            _a(const Color(0xFF455A64), 1 - tt * 0.8),
          );
        }
      case 'freeze':
        final glass = RRect.fromRectAndRadius(
          Rect.fromCenter(center: at, width: 92, height: 92),
          const Radius.circular(10),
        );
        canvas.drawRRect(
            glass, Paint()..color = _a(color, 0.35 * math.sin(math.pi * t)));
        canvas.drawRRect(
          glass,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3
            ..color = _a(Colors.white, 0.9 * math.sin(math.pi * t)),
        );
        for (var k = 0; k < 6; k++) {
          final ang = k * math.pi / 3 + t * 2;
          final p = at + Offset(math.cos(ang), math.sin(ang)) * 52;
          canvas.save();
          canvas.translate(p.dx, p.dy);
          canvas.rotate(math.pi / 4);
          canvas.drawRect(
            Rect.fromCenter(center: Offset.zero, width: 10, height: 10),
            Paint()..color = _a(Colors.white, 1 - t * 0.5),
          );
          canvas.restore();
        }
      case 'infatuation':
        for (var k = 0; k < 5; k++) {
          final tt = (t + k * 0.2) % 1.0;
          final p = Offset(at.dx + math.sin(tt * 6 + k) * 26, at.dy + 20 - 70 * tt);
          _text(canvas, '♥', p, 16 + k * 2.0, _a(color, 1 - tt * 0.7));
        }
      case 'curse':
      case 'nightmare':
        _paintDarkSwirl(canvas, color, t, at);
      case 'leech-seed':
        for (var k = 0; k < 7; k++) {
          final tt = (t + k * 0.14) % 1.0;
          final p = Offset(at.dx + (k - 3) * 10.0 + math.sin(tt * 7) * 4,
              at.dy + 34 - 80 * tt);
          canvas.drawCircle(p, 4, Paint()..color = _a(const Color(0xFF66BB6A), 1 - tt));
        }
      case 'trap':
        for (var k = 0; k < 2; k++) {
          canvas.drawCircle(
            at,
            62 - 38 * t - k * 10,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 5
              ..color = _a(color, 1 - t * 0.5),
          );
        }
      case 'perish-song':
        for (var k = 0; k < 4; k++) {
          final tt = (t + k * 0.25) % 1.0;
          final p = Offset(at.dx + (k - 1.5) * 20, at.dy + 20 - 70 * tt);
          _text(canvas, '♪', p, 18, _a(color, 1 - tt * 0.7));
        }
      case 'protect':
        canvas.drawCircle(
          at,
          54,
          Paint()..color = _a(color, 0.35 * math.sin(math.pi * t)),
        );
        canvas.drawCircle(
          at,
          54,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 4
            ..color = _a(Colors.white, 0.9 * math.sin(math.pi * t)),
        );
      default: // confusion
        for (var k = 0; k < 3; k++) {
          final ang = 2 * math.pi * (t * 1.5 + k / 3);
          final p = at + Offset(math.cos(ang) * 38, math.sin(ang) * 12 - 44);
          _text(canvas, '★', p, 18, _a(const Color(0xFFFFC107), 1 - t * 0.4));
        }
    }
  }
}

// ---------------------------------------------------------------------------
// Botones
// ---------------------------------------------------------------------------
class _MoveButton extends StatelessWidget {
  final MoveData move;
  final bool enabled;
  final VoidCallback onTap;
  const _MoveButton({
    required this.move,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final style = styleOf(move.type);
    final fg = onColorFor(style.color);
    return Opacity(
      opacity: enabled ? 1 : 0.4,
      child: Material(
        color: style.color,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: enabled ? onTap : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Icon(style.icon, color: fg, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        move.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style:
                            TextStyle(color: fg, fontWeight: FontWeight.w800),
                      ),
                      Text(
                        describeMove(move),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: fg, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                if (move.ailment != null)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: ailmentColor(move.ailment),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      ailmentBadge(move.ailment),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SwitchTile extends StatelessWidget {
  final BattleMon mon;
  final VoidCallback? onTap;
  const _SwitchTile({required this.mon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final state = mon.fainted
        ? 'Debilitado'
        : 'Nv. ${mon.level} · PS ${mon.hp}/${mon.maxHp}'
            '${mon.status != null ? ' · ${ailmentBadge(mon.status)}' : ''}';
    return Opacity(
      opacity: onTap == null ? 0.4 : 1,
      child: Material(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SpriteImage(id: mon.id, size: 40),
                const SizedBox(width: 6),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(mon.name,
                        style: const TextStyle(fontWeight: FontWeight.w800)),
                    Text(
                      state,
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.muted),
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
}
