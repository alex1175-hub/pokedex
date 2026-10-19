import 'dart:math';

import '../models/battle_move.dart';

enum Difficulty { easy, normal, hard }

/// Tipo de efecto visual/sonoro que la interfaz debe reproducir.
enum FxKind { move, hit, status, faint, miss, heal, send }

/// Evento visual del motor: quién lo sufre/realiza y de qué tipo es.
class BattleFx {
  final FxKind kind;

  /// true = afecta al lado del jugador (en `move` es quien ataca).
  final bool onPlayer;
  final String? type;
  final bool damaging;
  final double eff;
  final bool crit;
  final String? ailment;

  const BattleFx(
    this.kind,
    this.onPlayer, {
    this.type,
    this.damaging = true,
    this.eff = 1,
    this.crit = false,
    this.ailment,
  });
}

/// Acción del jugador en un turno: usar un movimiento o cambiar de Pokémon.
class BattleAction {
  final int? moveIndex;
  final int? switchTo;
  const BattleAction.move(int index)
      : moveIndex = index,
        switchTo = null;
  const BattleAction.change(int index)
      : moveIndex = null,
        switchTo = index;
}

/// Un Pokémon en combate (estadísticas ya calculadas).
class BattleMon {
  final int id;
  final String name;
  final List<String> types;
  final int level;
  final int maxHp;
  final int atk;
  final int def;
  final int spa;
  final int spd;
  final int spe;
  final List<MoveData> moves;
  final String? item;

  /// Multiplicador de daño recibido por tipo atacante.
  final Map<String, double> effectiveness;

  int hp;

  /// Movimiento bloqueado por un objeto "Elegido".
  int? lockedMove;
  bool itemUsed = false;

  /// paralysis, burn, poison, sleep, freeze o null.
  String? status;
  int sleepTurns = 0;

  /// Turnos de confusión que quedan (0 = sin confusión).
  int confusion = 0;

  BattleMon({
    required this.id,
    required this.name,
    required this.types,
    required this.level,
    required this.maxHp,
    required this.atk,
    required this.def,
    required this.spa,
    required this.spd,
    required this.spe,
    required this.moves,
    required this.item,
    required this.effectiveness,
  }) : hp = maxHp;

  bool get fainted => hp <= 0;
  double get hpFraction => maxHp == 0 ? 0 : hp / maxHp;

  bool get hasChoiceItem =>
      item == 'choice-band' || item == 'choice-specs' || item == 'choice-scarf';

  double effectivenessOf(String type) => effectiveness[type] ?? 1.0;

  int get effectiveSpeed {
    var s = item == 'choice-scarf' ? spe * 3 ~/ 2 : spe;
    if (status == 'paralysis') s ~/= 2;
    return s;
  }
}

/// Motor de combate 1 contra 1 por turnos. Los métodos que devuelven
/// `Iterable<String>` son generadores: cada línea del registro se produce
/// justo después de aplicar el cambio, así la interfaz puede mostrar el
/// combate poco a poco. Antes de cada línea el motor puede dejar un
/// [BattleFx] (se recoge con [takeFx]) para animaciones y sonidos.
class BattleEngine {
  final List<BattleMon> player;
  final List<BattleMon> rival;
  final Difficulty difficulty;
  final Random rng;

  int _pActive = 0;
  int _rActive = 0;
  BattleFx? _fx;

  /// 'player' o 'rival' cuando el combate terminó.
  String? winner;

  BattleEngine({
    required this.player,
    required this.rival,
    required this.difficulty,
    Random? rng,
  }) : rng = rng ?? Random();

  BattleMon get activePlayer => player[_pActive];
  BattleMon get activeRival => rival[_rActive];
  int get playerActiveIndex => _pActive;

  bool get needsPlayerSwitch =>
      winner == null && activePlayer.fainted && player.any((m) => !m.fainted);

  /// Devuelve (y borra) el efecto visual pendiente de la última línea.
  BattleFx? takeFx() {
    final f = _fx;
    _fx = null;
    return f;
  }

  bool _isPlayerMon(BattleMon m) => player.contains(m);
  String _label(BattleMon m) => _isPlayerMon(m) ? m.name : '${m.name} rival';

  // ---------- Turno ----------
  Iterable<String> runTurn(BattleAction action) sync* {
    if (winner != null) return;

    if (action.switchTo != null) {
      yield* _doSwitch(true, action.switchTo!);
      yield* _attack(false);
    } else {
      final order = _playerFirst() ? [true, false] : [false, true];
      for (final isPlayer in order) {
        if (winner != null) break;
        final user = isPlayer ? activePlayer : activeRival;
        if (user.fainted) continue;
        yield* _attack(isPlayer, isPlayer ? (action.moveIndex ?? 0) : null);
      }
    }

    // Efectos de final de turno.
    if (winner == null) {
      for (final mon in [activePlayer, activeRival]) {
        if (mon.fainted) continue;
        final onPlayer = _isPlayerMon(mon);
        if (mon.status == 'burn' || mon.status == 'poison') {
          final burn = mon.status == 'burn';
          final dmg = max(1, mon.maxHp ~/ (burn ? 16 : 8));
          mon.hp = max(0, mon.hp - dmg);
          _fx = BattleFx(FxKind.status, onPlayer, ailment: mon.status);
          yield burn
              ? '${_label(mon)} sufre por la quemadura.'
              : '${_label(mon)} sufre por el veneno.';
          if (mon.fainted) {
            _fx = BattleFx(FxKind.faint, onPlayer);
            yield '${_label(mon)} se debilitó.';
            continue;
          }
        }
        if (mon.item == 'leftovers' && mon.hp < mon.maxHp) {
          mon.hp = min(mon.maxHp, mon.hp + max(1, mon.maxHp ~/ 16));
          _fx = BattleFx(FxKind.heal, onPlayer);
          yield '${_label(mon)} recuperó PS con los Restos.';
        }
      }
      _updateWinner();
    }

    yield* _afterTurn();
  }

  /// El jugador elige a su siguiente Pokémon tras un debilitamiento.
  Iterable<String> playerSwitchIn(int index) sync* {
    if (!needsPlayerSwitch) return;
    yield* _doSwitch(true, index);
  }

  // ---------- Internos ----------
  bool _playerFirst() {
    final a = activePlayer.effectiveSpeed;
    final b = activeRival.effectiveSpeed;
    if (a == b) return rng.nextBool();
    return a > b;
  }

  Iterable<String> _doSwitch(bool isPlayer, int index) sync* {
    if (isPlayer) {
      activePlayer.lockedMove = null;
      activePlayer.confusion = 0;
      _pActive = index;
      _fx = const BattleFx(FxKind.send, true);
      yield '¡Adelante, ${activePlayer.name}!';
    } else {
      activeRival.lockedMove = null;
      activeRival.confusion = 0;
      _rActive = index;
      _fx = const BattleFx(FxKind.send, false);
      yield 'El rival envía a ${activeRival.name}.';
    }
  }

  Iterable<String> _afterTurn() sync* {
    _updateWinner();
    if (winner != null) {
      yield winner == 'player'
          ? '¡Todos los Pokémon rivales se debilitaron!'
          : '¡Todos tus Pokémon se debilitaron!';
      return;
    }
    if (activeRival.fainted) {
      yield* _doSwitch(false, _pickRivalReplacement());
    }
  }

  void _updateWinner() {
    if (player.every((m) => m.fainted)) {
      winner = 'rival';
    } else if (rival.every((m) => m.fainted)) {
      winner = 'player';
    }
  }

  int _pickRivalReplacement() {
    final alive = [
      for (var i = 0; i < rival.length; i++)
        if (!rival[i].fainted) i,
    ];
    if (difficulty != Difficulty.hard || activePlayer.fainted) {
      return alive[rng.nextInt(alive.length)];
    }
    var best = alive.first;
    var bestScore = -1.0;
    for (final i in alive) {
      var s = 0.0;
      for (final mv in rival[i].moves) {
        s = max(s, _score(rival[i], activePlayer, mv));
      }
      if (s > bestScore) {
        bestScore = s;
        best = i;
      }
    }
    return best;
  }

  double _score(BattleMon a, BattleMon d, MoveData mv) {
    if (!mv.isDamaging) return 0;
    final physical = mv.damageClass == 'physical';
    final ratio = physical ? a.atk / d.def : a.spa / d.spd;
    final stab = a.types.contains(mv.type) ? 1.5 : 1.0;
    final acc = (mv.accuracy ?? 100) / 100;
    return mv.power! * acc * stab * d.effectivenessOf(mv.type) * ratio;
  }

  bool _immune(BattleMon t, String ailment) {
    switch (ailment) {
      case 'paralysis':
        return t.types.contains('electric');
      case 'burn':
        return t.types.contains('fire');
      case 'poison':
        return t.types.contains('poison') || t.types.contains('steel');
      case 'freeze':
        return t.types.contains('ice');
      default:
        return false;
    }
  }

  /// ¿Tiene sentido que la IA use este movimiento de estado contra [d]?
  bool _statusUseful(BattleMon d, MoveData mv) {
    final a = mv.ailment;
    if (mv.isDamaging || a == null) return false;
    if (a == 'confusion') return d.confusion == 0;
    return d.status == null && !_immune(d, a);
  }

  int _aiMove(BattleMon a, BattleMon d) {
    if (a.lockedMove != null) return a.lockedMove!;

    if (difficulty != Difficulty.easy) {
      final useful = [
        for (var i = 0; i < a.moves.length; i++)
          if (_statusUseful(d, a.moves[i])) i,
      ];
      final chance = difficulty == Difficulty.hard ? 0.4 : 0.25;
      if (useful.isNotEmpty && rng.nextDouble() < chance) {
        return useful[rng.nextInt(useful.length)];
      }
    }

    final scores = [for (final mv in a.moves) _score(a, d, mv)];
    final damaging = [
      for (var i = 0; i < scores.length; i++)
        if (scores[i] > 0) i,
    ];
    if (damaging.isEmpty || difficulty == Difficulty.easy) {
      return rng.nextInt(a.moves.length);
    }
    if (difficulty == Difficulty.normal && rng.nextDouble() < 0.3) {
      return damaging[rng.nextInt(damaging.length)];
    }
    var best = damaging.first;
    for (final i in damaging) {
      if (scores[i] > scores[best]) best = i;
    }
    return best;
  }

  /// Aplica un problema de estado a [t].
  Iterable<String> _inflict(
    BattleMon t,
    String ailment, {
    required bool announceFail,
  }) sync* {
    if (t.fainted) return;
    final label = _label(t);
    final onPlayer = _isPlayerMon(t);

    if (ailment == 'confusion') {
      if (t.confusion > 0) {
        if (announceFail) yield 'Pero $label ya está confuso.';
        return;
      }
      t.confusion = 2 + rng.nextInt(4);
      _fx = BattleFx(FxKind.status, onPlayer, ailment: 'confusion');
      yield '¡$label está confuso!';
      return;
    }
    if (t.status != null) {
      if (announceFail) {
        yield 'Pero no tuvo efecto: $label ya tiene un problema de estado.';
      }
      return;
    }
    if (_immune(t, ailment)) {
      if (announceFail) yield 'No afecta a $label...';
      return;
    }

    t.status = ailment;
    if (ailment == 'sleep') t.sleepTurns = 2 + rng.nextInt(3);
    _fx = BattleFx(FxKind.status, onPlayer, ailment: ailment);
    switch (ailment) {
      case 'paralysis':
        yield '¡$label se paralizó! Quizá no pueda moverse.';
      case 'burn':
        yield '¡$label se quemó!';
      case 'poison':
        yield '¡$label fue envenenado!';
      case 'freeze':
        yield '¡$label se congeló!';
      default:
        yield '¡$label se durmió!';
    }
  }

  Iterable<String> _attack(bool isPlayer, [int? moveIndex]) sync* {
    final a = isPlayer ? activePlayer : activeRival;
    final d = isPlayer ? activeRival : activePlayer;
    final who = _label(a);

    // --- Estados que pueden impedir actuar.
    if (a.status == 'sleep') {
      a.sleepTurns--;
      if (a.sleepTurns > 0) {
        _fx = BattleFx(FxKind.status, isPlayer, ailment: 'sleep');
        yield '$who está profundamente dormido.';
        return;
      }
      a.status = null;
      yield '¡$who se despertó!';
    }
    if (a.status == 'freeze') {
      if (rng.nextInt(5) == 0) {
        a.status = null;
        yield '¡$who se descongeló!';
      } else {
        _fx = BattleFx(FxKind.status, isPlayer, ailment: 'freeze');
        yield '$who está congelado y no puede moverse.';
        return;
      }
    }
    if (a.status == 'paralysis' && rng.nextInt(4) == 0) {
      _fx = BattleFx(FxKind.status, isPlayer, ailment: 'paralysis');
      yield '¡$who está paralizado! No puede moverse.';
      return;
    }
    if (a.confusion > 0) {
      a.confusion--;
      if (a.confusion == 0) {
        yield '¡$who ya no está confuso!';
      } else {
        _fx = BattleFx(FxKind.status, isPlayer, ailment: 'confusion');
        yield '$who está confuso.';
        if (rng.nextInt(3) == 0) {
          final base = ((2 * a.level ~/ 5) + 2) * 40 * a.atk / a.def / 50 + 2;
          a.hp = max(0, a.hp - max(1, base.floor()));
          _fx = BattleFx(FxKind.hit, isPlayer);
          yield '¡Está tan confuso que se hirió a sí mismo!';
          if (a.fainted) {
            _fx = BattleFx(FxKind.faint, isPlayer);
            yield '$who se debilitó.';
            _updateWinner();
          }
          return;
        }
      }
    }

    // --- Movimiento.
    var idx = moveIndex ?? _aiMove(a, d);
    if (a.lockedMove != null) idx = a.lockedMove!;
    final mv = a.moves[idx];
    if (a.hasChoiceItem) a.lockedMove = idx;

    _fx = BattleFx(FxKind.move, isPlayer,
        type: mv.type, damaging: mv.isDamaging);
    yield '$who usó ${mv.name}.';

    if (!mv.isDamaging) {
      if (mv.ailment == null) {
        yield 'Pero no tuvo efecto en esta simulación.';
        return;
      }
      if (mv.accuracy != null && rng.nextInt(100) >= mv.accuracy!) {
        _fx = BattleFx(FxKind.miss, !isPlayer);
        yield '¡El ataque de $who falló!';
        return;
      }
      yield* _inflict(d, mv.ailment!, announceFail: true);
      return;
    }

    if (mv.accuracy != null && rng.nextInt(100) >= mv.accuracy!) {
      _fx = BattleFx(FxKind.miss, !isPlayer);
      yield '¡El ataque de $who falló!';
      return;
    }
    final eff = d.effectivenessOf(mv.type);
    if (eff == 0) {
      yield 'No afecta a ${_label(d)}...';
      return;
    }

    final crit = rng.nextInt(16) == 0;
    final dmg = _damage(a, d, mv, eff, crit);
    d.hp = max(0, d.hp - dmg);
    _fx = BattleFx(FxKind.hit, !isPlayer,
        type: mv.type, eff: eff, crit: crit);
    yield '${_label(d)} recibió $dmg de daño.';
    if (crit) yield '¡Golpe crítico!';
    if (eff > 1) {
      yield '¡Es muy eficaz!';
    } else if (eff < 1) {
      yield 'No es muy eficaz...';
    }

    if (d.status == 'freeze' && mv.type == 'fire' && !d.fainted) {
      d.status = null;
      yield '¡${_label(d)} se descongeló por el calor!';
    }

    // Efectos de objetos.
    if (a.item == 'life-orb' && !a.fainted) {
      a.hp = max(0, a.hp - max(1, a.maxHp ~/ 10));
      _fx = BattleFx(FxKind.hit, isPlayer);
      yield '$who perdió PS por la Vidasfera.';
    }
    if (mv.damageClass == 'physical' &&
        d.item == 'rocky-helmet' &&
        !a.fainted) {
      a.hp = max(0, a.hp - max(1, a.maxHp ~/ 6));
      _fx = BattleFx(FxKind.hit, isPlayer);
      yield '$who se hirió con el Casco Dentado.';
    }
    yield* _berry(d);
    yield* _berry(a);

    // Efecto secundario de estado (ej. Rayo puede paralizar).
    if (!d.fainted &&
        mv.ailment != null &&
        rng.nextInt(100) < mv.ailmentChance) {
      yield* _inflict(d, mv.ailment!, announceFail: false);
    }

    if (d.fainted) {
      _fx = BattleFx(FxKind.faint, !isPlayer);
      yield '${_label(d)} se debilitó.';
    }
    if (a.fainted) {
      _fx = BattleFx(FxKind.faint, isPlayer);
      yield '$who se debilitó.';
    }
    _updateWinner();
  }

  Iterable<String> _berry(BattleMon m) sync* {
    if (m.fainted || m.itemUsed || m.hp * 2 > m.maxHp) return;
    if (m.item == 'sitrus-berry') {
      m.itemUsed = true;
      m.hp = min(m.maxHp, m.hp + max(1, m.maxHp ~/ 4));
      _fx = BattleFx(FxKind.heal, _isPlayerMon(m));
      yield '${_label(m)} comió su Baya Zidra y recuperó PS.';
    } else if (m.item == 'oran-berry') {
      m.itemUsed = true;
      m.hp = min(m.maxHp, m.hp + 10);
      _fx = BattleFx(FxKind.heal, _isPlayerMon(m));
      yield '${_label(m)} comió su Baya Aranja y recuperó PS.';
    }
  }

  int _damage(BattleMon a, BattleMon d, MoveData mv, double eff, bool crit) {
    final physical = mv.damageClass == 'physical';
    var atk = (physical ? a.atk : a.spa).toDouble();
    var def = (physical ? d.def : d.spd).toDouble();
    if (a.id == 25 && a.item == 'light-ball') atk *= 2;
    if (physical && a.item == 'choice-band') atk *= 1.5;
    if (!physical && a.item == 'choice-specs') atk *= 1.5;
    if (!physical && d.item == 'assault-vest') def *= 1.5;
    if (physical && a.status == 'burn') atk *= 0.5;

    final levelFactor = (2 * a.level ~/ 5) + 2;
    var dmg = (levelFactor * mv.power! * atk / def) / 50 + 2;

    if (a.types.contains(mv.type)) dmg *= 1.5;
    dmg *= eff;
    if (crit) dmg *= 1.5;
    dmg *= 0.85 + rng.nextDouble() * 0.15;
    if (a.item == 'life-orb') dmg *= 1.3;
    if (a.item == 'expert-belt' && eff > 1) dmg *= 1.2;

    return max(1, dmg.floor());
  }
}
