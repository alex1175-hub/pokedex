import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../battle/battle_engine.dart';
import '../models/battle_move.dart';
import '../models/pokemon.dart';
import '../services/sound_service.dart';
import '../theme/app_theme.dart';
import '../theme/type_style.dart';
import 'pokeball.dart';
import 'pokedex_ui.dart';

// ---------------------------------------------------------------------------
// Colores y etiquetas de los problemas de estado
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
    default:
      return '';
  }
}

/// Pantalla del combate: arena con animaciones, registro y acciones.
class BattleView extends StatefulWidget {
  final BattleEngine engine;
  final VoidCallback onExit;
  final VoidCallback onRematch;

  const BattleView({
    super.key,
    required this.engine,
    required this.onExit,
    required this.onRematch,
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

  BattleEngine get _e => widget.engine;

  @override
  void initState() {
    super.initState();
    _log.addAll([
      '¡Comienza el combate!',
      '¡Adelante, ${_e.activePlayer.name}!',
      'El rival envía a ${_e.activeRival.name}.',
    ]);
    SoundService.instance.playMusic('bt_music.wav', this);
  }

  @override
  void dispose() {
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
        return 'sleep';
      case 'freeze':
        return 'freeze';
      default:
        return 'confusion';
    }
  }

  Future<void> _play(Iterable<String> events) async {
    setState(() {
      _busy = true;
      _showSwitch = false;
    });
    for (final line in events) {
      if (!mounted) return;
      final fx = _e.takeFx();
      setState(() {
        _log.add(line);
        if (fx != null) _fx = fx;
      });
      _scrollLog();
      if (fx != null) {
        _fxCtrl.duration = Duration(milliseconds: _fxMillis(fx.kind));
        _fxCtrl.forward(from: 0);
        _fxSound(fx);
      }
      await Future.delayed(Duration(milliseconds: fx != null ? 780 : 520));
    }
    if (!mounted) return;
    if (_e.winner != null && !_resultSounded) {
      _resultSounded = true;
      SoundService.instance.stopMusic(this);
      SoundService.instance
          .playSfx(_e.winner == 'player' ? 'bt_win.wav' : 'bt_lose.wav');
    }
    setState(() => _busy = false);
  }

  void _useMove(int i) {
    SoundService.instance.playSelect();
    _play(_e.runTurn(BattleAction.move(i)));
  }

  void _switchTo(int i) {
    SoundService.instance.playSelect();
    if (_e.needsPlayerSwitch) {
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
        final arena = _arena();
        final log = _logPanel();
        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _topBar(),
              if (wide)
                SizedBox(
                  height: 280,
                  child: Row(
                    children: [
                      Expanded(child: arena),
                      const SizedBox(width: 12),
                      SizedBox(width: 300, child: log),
                    ],
                  ),
                )
              else ...[
                SizedBox(height: 280, child: arena),
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
    return Align(
      alignment: Alignment.centerRight,
      child: ValueListenableBuilder<bool>(
        valueListenable: SoundService.instance.musicEnabled,
        builder: (context, on, _) => TextButton.icon(
          style: TextButton.styleFrom(foregroundColor: Colors.white),
          onPressed: () => SoundService.instance.toggleMusic(),
          icon: Icon(on ? Icons.music_note : Icons.music_off, size: 18),
          label: Text(on ? 'Música: sí' : 'Música: no'),
        ),
      ),
    );
  }

  // ---------- Arena ----------
  Widget _arena() {
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
                    child: _monRow(_e.activeRival, _e.rival, isPlayer: false)),
                const Divider(height: 8),
                Expanded(
                    child: _monRow(_e.activePlayer, _e.player, isPlayer: true)),
              ],
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _FxPainter(_fxCtrl, () => _fx),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _monRow(BattleMon mon, List<BattleMon> team,
      {required bool isPlayer}) {
    final sprite = _FxSprite(
      id: mon.id,
      back: isPlayer,
      fainted: mon.fainted,
      isPlayer: isPlayer,
      ctrl: _fxCtrl,
      fx: _fx,
    );
    final info = Expanded(child: _infoBox(mon, team, isPlayer));
    return Row(
      children: isPlayer
          ? [sprite, const SizedBox(width: 10), info]
          : [info, const SizedBox(width: 10), sprite],
    );
  }

  Widget _statusBadge(String? ailment) {
    return Container(
      margin: const EdgeInsets.only(right: 4),
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

  Widget _infoBox(BattleMon mon, List<BattleMon> team, bool isPlayer) {
    final frac = mon.hpFraction;
    final color = frac > 0.5
        ? const Color(0xFF43A047)
        : (frac > 0.2 ? const Color(0xFFFBC02D) : AppColors.red);
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${isPlayer ? '' : 'Rival · '}${mon.name}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              Text('Nv. ${mon.level}',
                  style: const TextStyle(fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(end: frac),
              duration: const Duration(milliseconds: 400),
              builder: (context, v, _) => LinearProgressIndicator(
                value: v,
                minHeight: 10,
                color: color,
                backgroundColor: const Color(0xFFCFCFCF),
              ),
            ),
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              Text(
                'PS ${mon.hp}/${mon.maxHp}',
                style: const TextStyle(fontSize: 11, color: AppColors.muted),
              ),
              const Spacer(),
              if (mon.status != null) _statusBadge(mon.status),
              if (mon.confusion > 0) _statusBadge('confusion'),
            ],
          ),
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
              if (mon.item != null)
                const Icon(Icons.inventory_2_outlined,
                    size: 14, color: AppColors.muted),
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
  Widget _actionPanel() {
    final Widget content;
    if (_e.winner != null && !_busy) {
      content = _resultPanel();
    } else if (_busy) {
      content = const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: PokeballLoader(size: 36)),
      );
    } else if (_e.needsPlayerSwitch) {
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('¡Elige al siguiente Pokémon!',
              style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          _switchTiles(),
        ],
      );
    } else {
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _moveGrid(),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: () => setState(() => _showSwitch = !_showSwitch),
              icon: const Icon(Icons.swap_horiz),
              label: const Text('CAMBIAR POKÉMON'),
            ),
          ),
          if (_showSwitch) ...[
            const SizedBox(height: 8),
            _switchTiles(),
          ],
        ],
      );
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
                child: _MoveButton(
                  move: mon.moves[i],
                  enabled: mon.lockedMove == null || mon.lockedMove == i,
                  onTap: () => _useMove(i),
                ),
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

  const _FxSprite({
    required this.id,
    required this.back,
    required this.fainted,
    required this.isPlayer,
    required this.ctrl,
    required this.fx,
  });

  @override
  Widget build(BuildContext context) {
    const size = 96.0;
    final url = back
        ? 'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/back/$id.png'
        : spriteUrlFor(id);
    final image = Image.network(
      url,
      width: size,
      height: size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.none,
      errorBuilder: (_, __, ___) => SpriteImage(id: id, size: size),
    );

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

  _FxPainter(this.anim, this.fxOf) : super(repaint: anim);

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
    final rival = Offset(size.width - 48, size.height * 0.26);
    final player = Offset(48, size.height * 0.74);
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
              ..color = _a(k.isEven ? const Color(0xFFFF7043) : const Color(0xFFFFCA28), 1 - tt * 0.6),
          );
        }
      case 'poison':
        for (var k = 0; k < 6; k++) {
          final tt = (t * 0.9 + k * 0.17) % 1.0;
          final p = Offset(at.dx + (k - 2.5) * 14.0 + math.sin(tt * 8) * 4, at.dy + 30 - 66 * tt);
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

  String get _info {
    final verb = kAilmentVerbs[move.ailment];
    if (move.isDamaging) {
      final base = 'Pot. ${move.power} · Prec. ${move.accuracy ?? '—'}';
      if (verb == null) return base;
      return '$base · ${move.ailmentChance}% $verb';
    }
    if (verb != null) return '$verb · Prec. ${move.accuracy ?? '—'}';
    return 'Sin efecto en esta simulación';
  }

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
                      Text(_info, style: TextStyle(color: fg, fontSize: 11)),
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
