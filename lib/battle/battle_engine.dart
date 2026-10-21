import 'dart:math';

import '../data/held_items.dart';
import '../models/battle_move.dart';
import '../theme/type_style.dart';

enum Difficulty { easy, normal, hard }

/// Tipo de efecto visual/sonoro que la interfaz debe reproducir.
enum FxKind {
  move,
  hit,
  status,
  faint,
  miss,
  heal,
  send,
  mega,
  stat,

  /// Movimiento Z: aura dorada antes del ataque.
  zmove,

  /// Dinamax / Gigamax (`up` = crece, si no vuelve a su tamaño).
  dynamax,

  /// Teracristalización (el tipo va en `type`).
  tera,

  /// Cambio de clima o de terreno (la clave va en `ailment`).
  weather,
}

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

  /// Para `stat`: true = sube, false = baja.
  final bool up;

  const BattleFx(
    this.kind,
    this.onPlayer, {
    this.type,
    this.damaging = true,
    this.eff = 1,
    this.crit = false,
    this.ailment,
    this.up = true,
  });

  Map<String, dynamic> toJson() => {
        'k': kind.index,
        'p': onPlayer,
        'ty': type,
        'd': damaging,
        'e': eff,
        'c': crit,
        'a': ailment,
        'u': up,
      };

  /// [flip] invierte el lado (el invitado ve el combate al revés).
  static BattleFx? fromJson(dynamic j, {bool flip = false}) {
    if (j is! Map) return null;
    final p = j['p'] == true;
    return BattleFx(
      FxKind.values[j['k'] as int],
      flip ? !p : p,
      type: j['ty'] as String?,
      damaging: j['d'] != false,
      eff: (j['e'] as num?)?.toDouble() ?? 1,
      crit: j['c'] == true,
      ailment: j['a'] as String?,
      up: j['u'] != false,
    );
  }
}

/// Acción de un jugador en un turno: usar un movimiento (con o sin una
/// transformación: megaevolución, Dinamax/Gigamax o teracristalización, o
/// como Movimiento Z) o cambiar de Pokémon.
class BattleAction {
  final int? moveIndex;
  final int? switchTo;
  final bool mega;
  final bool z;
  final bool dynamax;
  final bool tera;
  const BattleAction.move(
    int index, {
    this.mega = false,
    this.z = false,
    this.dynamax = false,
    this.tera = false,
  })  : moveIndex = index,
        switchTo = null;
  const BattleAction.change(int index)
      : moveIndex = null,
        switchTo = index,
        mega = false,
        z = false,
        dynamax = false,
        tera = false;
}

/// Datos de la megaevolución de un Pokémon (ya con estadísticas calculadas).
class MegaData {
  final int spriteId;
  final String name;
  final List<String> types;
  final int atk;
  final int def;
  final int spa;
  final int spd;
  final int spe;
  final Map<String, double> effectiveness;

  const MegaData({
    required this.spriteId,
    required this.name,
    required this.types,
    required this.atk,
    required this.def,
    required this.spa,
    required this.spd,
    required this.spe,
    required this.effectiveness,
  });
}

/// Poder del Cristal Z que lleva un Pokémon.
class ZData {
  final ZCrystal crystal;

  /// Nombres (en español) del movimiento Z genérico físico y especial, o
  /// del movimiento Z exclusivo en [signatureName].
  final String physName;
  final String specName;
  final String? signatureName;

  const ZData({
    required this.crystal,
    required this.physName,
    required this.specName,
    this.signatureName,
  });

  /// ¿Puede el cristal convertir este movimiento?
  bool accepts(MoveData mv) {
    if (!mv.isDamaging || mv.isMax || mv.isZ) return false;
    final base = crystal.baseMove;
    if (base != null) return mv.slug == base;
    return mv.type == crystal.type;
  }

  /// Potencia del movimiento Z genérico según la del movimiento original.
  static int powerFor(MoveData mv) {
    if (mv.isFixed) return 100;
    final p = mv.power ?? 0;
    if (p <= 55) return 100;
    if (p <= 65) return 120;
    if (p <= 75) return 140;
    if (p <= 85) return 160;
    if (p <= 95) return 175;
    if (p <= 100) return 180;
    if (p <= 110) return 185;
    if (p <= 125) return 190;
    if (p <= 130) return 195;
    return 200;
  }

  /// Versión Z de [mv] (se asume que [accepts] es verdadero).
  MoveData version(MoveData mv) {
    if (crystal.baseMove != null) {
      return MoveData(
        slug: crystal.zSlug ?? 'z-move',
        name: signatureName ?? crystal.zFallbackName,
        type: crystal.zType,
        damageClass: crystal.zClass,
        power: crystal.zPower > 0 ? crystal.zPower : null,
        accuracy: null,
        isZ: true,
      );
    }
    return MoveData(
      slug: 'z-${mv.slug}',
      name: mv.damageClass == 'physical' ? physName : specName,
      type: mv.type,
      damageClass: mv.damageClass,
      power: powerFor(mv),
      accuracy: null,
      priority: mv.priority,
      isZ: true,
    );
  }
}

/// Movimiento Gigamax exclusivo de una especie.
class GmaxData {
  /// Forma Gigamax (para el sprite).
  final int spriteId;
  final String moveName;
  final String moveType;

  const GmaxData({
    required this.spriteId,
    required this.moveName,
    required this.moveType,
  });
}

/// Datos de Dinamax: nombres de los Movimientos Máximos y, si la especie lo
/// tiene, su Gigamax.
class DynaData {
  /// Nombre del Movimiento Máximo de cada tipo.
  final Map<String, String> maxNames;
  final String guardName;
  final GmaxData? gmax;

  const DynaData({
    required this.maxNames,
    required this.guardName,
    this.gmax,
  });
}

/// Teracristal de un Pokémon: su tipo y cómo cambian sus debilidades.
class TeraData {
  final String type;
  final Map<String, double> effectiveness;
  const TeraData({required this.type, required this.effectiveness});
}

/// Potencia de un Movimiento Máximo según la del movimiento original.
int maxPowerFor(MoveData mv) {
  final low = mv.type == 'fighting' || mv.type == 'poison';
  if (mv.isFixed || (mv.power ?? 0) <= 0) return low ? 85 : 130;
  final p = mv.power!;
  if (low) {
    if (p <= 40) return 70;
    if (p <= 50) return 75;
    if (p <= 60) return 80;
    if (p <= 70) return 85;
    if (p <= 110) return 90;
    if (p <= 125) return 95;
    return 100;
  }
  if (p <= 40) return 90;
  if (p <= 50) return 100;
  if (p <= 55) return 110;
  if (p <= 65) return 120;
  if (p <= 75) return 130;
  if (p <= 100) return 140;
  return 150;
}

double _stageMult(int s) => s >= 0 ? (2 + s) / 2 : 2 / (2 - s);

/// Un Pokémon en combate (estadísticas ya calculadas).
class BattleMon {
  /// Número base de Pokédex.
  final int baseId;

  /// Número usado para el sprite (cambia al megaevolucionar).
  int id;
  String name;
  List<String> types;
  final int level;
  int maxHp;
  int atk;
  int def;
  int spa;
  int spd;
  int spe;
  final List<MoveData> moves;
  final String? item;

  /// Multiplicador de daño recibido por tipo atacante.
  Map<String, double> effectiveness;

  final MegaData? mega;
  bool megaEvolved = false;

  /// Cristal Z, Dinamax/Gigamax y Teracristal (null si no se pueden usar).
  final ZData? z;
  final DynaData? dyna;
  final TeraData? tera;

  /// Dinamax: turnos que quedan (0 = no está Dinamaxizado) y si ya se usó.
  int dynamaxTurns = 0;
  bool dynamaxUsed = false;
  bool gigantamaxed = false;

  /// true mientras los PS están duplicados por el Dinamax.
  bool big = false;

  /// El Movimiento Z de este Pokémon ya se gastó.
  bool zUsed = false;

  /// Teracristalización: tipos que tenía antes (para conservar el STAB).
  bool terastallized = false;
  List<String> originalTypes = const [];

  int hp;

  /// Movimiento bloqueado por un objeto "Elegido".
  int? lockedMove;
  bool itemUsed = false;

  /// paralysis, burn, poison, sleep, freeze o null.
  String? status;
  int sleepTurns = 0;

  /// Turnos de confusión que quedan (0 = sin confusión).
  int confusion = 0;

  // --- Efectos únicos (se pierden al cambiar de Pokémon) ---
  Map<String, int> stages = {for (final s in kStageStats) s: 0};
  bool infatuated = false;
  bool cursed = false;
  bool seeded = false;
  bool nightmare = false;
  int trapTurns = 0;
  int yawn = 0;
  int perish = 0;
  bool flinched = false;
  bool protecting = false;
  int protectStreak = 0;
  bool movedThisTurn = false;

  BattleMon({
    required this.baseId,
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
    this.mega,
    this.z,
    this.dyna,
    this.tera,
  }) : hp = maxHp;

  bool get fainted => hp <= 0;
  double get hpFraction => maxHp == 0 ? 0 : hp / maxHp;

  bool get dynamaxed => big;
  String? get teraType => tera?.type;

  /// ¿Ya usó una transformación (mega, Dinamax o Tera)? Solo se puede una
  /// por Pokémon y combate.
  bool get transformed => megaEvolved || dynamaxUsed || terastallized;

  bool get hasChoiceItem =>
      item == 'choice-band' || item == 'choice-specs' || item == 'choice-scarf';

  double effectivenessOf(String type) => effectiveness[type] ?? 1.0;

  double stat(String key) {
    final base = switch (key) {
      'attack' => atk,
      'defense' => def,
      'special-attack' => spa,
      'special-defense' => spd,
      _ => spe,
    };
    return base * _stageMult(stages[key] ?? 0);
  }

  int get effectiveSpeed {
    var s = stat('speed');
    if (item == 'choice-scarf') s *= 1.5;
    if (item == 'quick-powder' && baseId == 132) s *= 2;
    if (status == 'paralysis') s /= 2;
    return s.floor();
  }

  void megaEvolve() {
    final m = mega;
    if (m == null || megaEvolved) return;
    megaEvolved = true;
    id = m.spriteId;
    name = m.name;
    types = m.types;
    atk = m.atk;
    def = m.def;
    spa = m.spa;
    spd = m.spd;
    spe = m.spe;
    effectiveness = m.effectiveness;
  }

  /// Dinamax: PS x2 durante 3 turnos; con Gigamax cambia también el aspecto.
  void dynamax() {
    if (big) return;
    big = true;
    maxHp *= 2;
    hp *= 2;
    dynamaxTurns = 3;
    dynamaxUsed = true;
    lockedMove = null;
    final g = dyna?.gmax;
    if (g != null) {
      gigantamaxed = true;
      id = g.spriteId;
    }
  }

  /// Fin del Dinamax: los PS vuelven a la normalidad (en proporción).
  void revertDynamax() {
    if (!big) return;
    big = false;
    maxHp = maxHp ~/ 2;
    hp = hp > 0 ? max(1, (hp + 1) ~/ 2) : 0;
    dynamaxTurns = 0;
    if (gigantamaxed) {
      gigantamaxed = false;
      id = baseId;
    }
  }

  /// Teracristalización: pasa a ser de un único tipo (el Teratipo).
  void terastallize() {
    final t = tera;
    if (t == null || terastallized) return;
    terastallized = true;
    originalTypes = List<String>.of(types);
    types = [t.type];
    effectiveness = t.effectiveness;
  }

  /// Movimiento Máximo (o Gigamax) que sustituye a [mv] mientras dura el
  /// Dinamax. Los de estado se convierten en Dinoguardia.
  MoveData maxVersion(MoveData mv) {
    final d = dyna;
    if (!mv.isDamaging) {
      return MoveData(
        slug: 'max-guard',
        name: d?.guardName ?? 'Dinoguardia',
        type: 'normal',
        damageClass: 'status',
        power: null,
        accuracy: null,
        target: 'user',
        isMax: true,
      );
    }
    final g = d?.gmax;
    if (gigantamaxed && g != null && g.moveType == mv.type) {
      return MoveData(
        slug: 'gmax-${mv.type}',
        name: g.moveName,
        type: mv.type,
        damageClass: mv.damageClass,
        power: 150,
        accuracy: null,
        isMax: true,
      );
    }
    return MoveData(
      slug: 'max-${mv.type}',
      name: d?.maxNames[mv.type] ?? 'Dinoataque ${styleOf(mv.type).label}',
      type: mv.type,
      damageClass: mv.damageClass,
      power: maxPowerFor(mv),
      accuracy: null,
      isMax: true,
    );
  }

  /// Movimientos que se pueden usar ahora (Máximos si está Dinamaxizado).
  List<MoveData> get currentMoves =>
      big ? [for (final m in moves) maxVersion(m)] : moves;

  /// Versión Z del movimiento [index] (null si el cristal no lo admite).
  MoveData? zVersion(int index) {
    final zd = z;
    if (zd == null || big || index < 0 || index >= moves.length) return null;
    final mv = moves[index];
    return zd.accepts(mv) ? zd.version(mv) : null;
  }

  /// Borra los efectos que desaparecen al salir del combate.
  void resetVolatile() {
    revertDynamax();
    lockedMove = null;
    confusion = 0;
    stages = {for (final s in kStageStats) s: 0};
    infatuated = false;
    cursed = false;
    seeded = false;
    nightmare = false;
    trapTurns = 0;
    yawn = 0;
    perish = 0;
    flinched = false;
    protecting = false;
    protectStreak = 0;
  }

  Map<String, dynamic> toSnap() => {
        'hp': hp,
        'st': status,
        'sl': sleepTurns,
        'cf': confusion,
        'iu': itemUsed,
        'lk': lockedMove,
        'mg': megaEvolved,
        'tt': terastallized,
        'dx': dynamaxTurns,
        'du': dynamaxUsed,
        'zu': zUsed,
        'sg': stages,
        'if': infatuated,
        'cu': cursed,
        'sd': seeded,
        'nm': nightmare,
        'tr': trapTurns,
        'yw': yawn,
        'pe': perish,
      };

  void applySnap(Map<String, dynamic> s) {
    if (s['mg'] == true) megaEvolve();
    if (s['tt'] == true) terastallize();
    final dx = (s['dx'] as int?) ?? 0;
    if (dx > 0 && !big) {
      dynamax();
    } else if (dx == 0 && big) {
      revertDynamax();
    }
    dynamaxTurns = dx;
    dynamaxUsed = s['du'] == true;
    zUsed = s['zu'] == true;
    hp = (s['hp'] as int?) ?? hp;
    status = s['st'] as String?;
    sleepTurns = (s['sl'] as int?) ?? 0;
    confusion = (s['cf'] as int?) ?? 0;
    itemUsed = s['iu'] == true;
    lockedMove = s['lk'] as int?;
    final sg = s['sg'];
    if (sg is Map) {
      stages = {
        for (final k in kStageStats) k: (sg[k] as num?)?.toInt() ?? 0,
      };
    }
    infatuated = s['if'] == true;
    cursed = s['cu'] == true;
    seeded = s['sd'] == true;
    nightmare = s['nm'] == true;
    trapTurns = (s['tr'] as int?) ?? 0;
    yawn = (s['yw'] as int?) ?? 0;
    perish = (s['pe'] as int?) ?? 0;
  }
}

/// Motor de combate 1 contra 1 por turnos. Los métodos que devuelven
/// `Iterable<String>` son generadores: cada línea del registro se produce
/// justo después de aplicar el cambio, así la interfaz puede mostrar el
/// combate poco a poco. Antes de cada línea el motor puede dejar un
/// [BattleFx] (se recoge con [takeFx]) para animaciones y sonidos.
///
/// Las líneas son "crudas": los nombres llevan marcas para que cada jugador
/// los vea desde su punto de vista (ver [render]).
class BattleEngine {
  final List<BattleMon> player;
  final List<BattleMon> rival;
  final Difficulty difficulty;
  final Random rng;

  /// true = el rival es una persona (red local): no hay IA.
  final bool humanRival;

  int _pActive = 0;
  int _rActive = 0;
  BattleFx? _fx;

  /// Clima (sun, rain, hail, sand) y terreno (grassy, electric, psychic,
  /// misty) activos y turnos que les quedan.
  String? weather;
  int weatherTurns = 0;
  String? terrain;
  int terrainTurns = 0;

  /// Movimiento Z pedido por cada bando en el turno actual.
  bool _pZ = false;
  bool _rZ = false;

  /// 'player' o 'rival' cuando el combate terminó.
  String? winner;

  BattleEngine({
    required this.player,
    required this.rival,
    required this.difficulty,
    this.humanRival = false,
    Random? rng,
  }) : rng = rng ?? Random();

  BattleMon get activePlayer => player[_pActive];
  BattleMon get activeRival => rival[_rActive];
  int get playerActiveIndex => _pActive;

  bool get needsPlayerSwitch =>
      winner == null && activePlayer.fainted && player.any((m) => !m.fainted);

  bool get needsRivalSwitch =>
      humanRival &&
      winner == null &&
      activeRival.fainted &&
      rival.any((m) => !m.fainted);

  /// ¿Puede el jugador cambiar de Pokémon voluntariamente?
  bool get playerTrapped =>
      !activePlayer.fainted && activePlayer.trapTurns > 0;

  /// Devuelve (y borra) el efecto visual pendiente de la última línea.
  BattleFx? takeFx() {
    final f = _fx;
    _fx = null;
    return f;
  }

  // ---------- Marcas de texto por perspectiva ----------
  static final RegExp _tok = RegExp('\u0001([PR]):([^\u0002]*)\u0002');

  /// Convierte una línea cruda en texto para quien mira desde el lado
  /// [viewerIsP] (true = lado "player" del motor).
  static String render(String raw, {required bool viewerIsP}) {
    if (raw.startsWith('\u0004')) {
      final mine = (raw[1] == 'P') == viewerIsP;
      final name = raw.substring(3);
      return mine ? '¡Adelante, $name!' : 'El rival envía a $name.';
    }
    if (raw.startsWith('\u0005')) {
      final mineWon = (raw[1] == 'P') == viewerIsP;
      return mineWon
          ? '¡Todos los Pokémon rivales se debilitaron!'
          : '¡Todos tus Pokémon se debilitaron!';
    }
    return raw.replaceAllMapped(_tok, (m) {
      final mine = (m[1] == 'P') == viewerIsP;
      return mine ? m[2]! : '${m[2]} rival';
    });
  }

  bool _isPlayerMon(BattleMon m) => player.contains(m);
  String _label(BattleMon m) =>
      '\u0001${_isPlayerMon(m) ? 'P' : 'R'}:${m.name}\u0002';

  // ---------- Sincronización por red ----------
  Map<String, dynamic> toSnapshot() => {
        'p': [for (final m in player) m.toSnap()],
        'r': [for (final m in rival) m.toSnap()],
        'pa': _pActive,
        'ra': _rActive,
        'w': winner,
        'wx': weather,
        'wn': weatherTurns,
        'tf': terrain,
        'tn': terrainTurns,
      };

  /// Copia el estado del anfitrión. Con [swap] el invitado ve su equipo
  /// como "player" (las listas se intercambian).
  void applySnapshot(Map<String, dynamic> s, {required bool swap}) {
    final p = (s[swap ? 'r' : 'p'] as List).cast<Map<String, dynamic>>();
    final r = (s[swap ? 'p' : 'r'] as List).cast<Map<String, dynamic>>();
    for (var i = 0; i < player.length && i < p.length; i++) {
      player[i].applySnap(p[i]);
    }
    for (var i = 0; i < rival.length && i < r.length; i++) {
      rival[i].applySnap(r[i]);
    }
    _pActive = (s[swap ? 'ra' : 'pa'] as int?) ?? _pActive;
    _rActive = (s[swap ? 'pa' : 'ra'] as int?) ?? _rActive;
    weather = s['wx'] as String?;
    weatherTurns = (s['wn'] as int?) ?? 0;
    terrain = s['tf'] as String?;
    terrainTurns = (s['tn'] as int?) ?? 0;
    final w = s['w'] as String?;
    winner = w == null
        ? null
        : (swap ? (w == 'player' ? 'rival' : 'player') : w);
  }

  // ---------- Megaevolución ----------
  bool canMega(bool isPlayerSide) {
    final list = isPlayerSide ? player : rival;
    final m = isPlayerSide ? activePlayer : activeRival;
    return winner == null &&
        !m.fainted &&
        m.mega != null &&
        !m.transformed &&
        !list.any((x) => x.megaEvolved);
  }

  bool canDynamax(bool isPlayerSide) {
    final list = isPlayerSide ? player : rival;
    final m = isPlayerSide ? activePlayer : activeRival;
    return winner == null &&
        !m.fainted &&
        !m.transformed &&
        !list.any((x) => x.dynamaxUsed);
  }

  bool canTera(bool isPlayerSide) {
    final list = isPlayerSide ? player : rival;
    final m = isPlayerSide ? activePlayer : activeRival;
    return winner == null &&
        !m.fainted &&
        m.tera != null &&
        !m.transformed &&
        !list.any((x) => x.terastallized);
  }

  /// Versión Z del movimiento [index] del Pokémon activo, o null si no se
  /// puede usar (sin cristal, ya gastado por el equipo, Dinamax...).
  MoveData? zMoveFor(bool isPlayerSide, int index) {
    final list = isPlayerSide ? player : rival;
    final m = isPlayerSide ? activePlayer : activeRival;
    if (winner != null || m.fainted || list.any((x) => x.zUsed)) return null;
    return m.zVersion(index);
  }

  Iterable<String> _dynamax(bool isPlayerSide) sync* {
    final m = isPlayerSide ? activePlayer : activeRival;
    m.dynamax();
    _fx = BattleFx(FxKind.dynamax, isPlayerSide,
        up: true, ailment: m.gigantamaxed ? 'gmax' : null);
    yield m.gigantamaxed
        ? '¡${_label(m)} se transformó con el Gigamax!'
        : '¡${_label(m)} se envolvió en energía Dinamax y creció enormemente!';
  }

  Iterable<String> _tera(bool isPlayerSide) sync* {
    final m = isPlayerSide ? activePlayer : activeRival;
    m.terastallize();
    _fx = BattleFx(FxKind.tera, isPlayerSide, type: m.teraType);
    yield '¡${_label(m)} se teracristalizó! Ahora es de tipo '
        '${styleOf(m.teraType ?? 'normal').label}.';
  }

  double get _aiGimmickChance => difficulty == Difficulty.hard
      ? 0.25
      : (difficulty == Difficulty.normal ? 0.15 : 0.08);

  /// La IA decide si usa su Movimiento Z y con qué movimiento.
  int? _aiZIndex() {
    final a = activeRival;
    final d = activePlayer;
    int? best;
    var bestScore = -1.0;
    for (var i = 0; i < a.moves.length; i++) {
      final zm = zMoveFor(false, i);
      if (zm == null) continue;
      final sc = _score(a, d, zm);
      if (sc > bestScore) {
        bestScore = sc;
        best = i;
      }
    }
    if (best == null) return null;
    final chance = difficulty == Difficulty.hard
        ? 0.8
        : (difficulty == Difficulty.normal ? 0.4 : 0.2);
    return rng.nextDouble() < chance ? best : null;
  }

  Iterable<String> _mega(bool isPlayerSide) sync* {
    final m = isPlayerSide ? activePlayer : activeRival;
    final old = m.name;
    m.megaEvolve();
    _fx = BattleFx(FxKind.mega, isPlayerSide);
    yield '¡${isPlayerSide ? '\u0001P:$old\u0002' : '\u0001R:$old\u0002'} '
        'megaevolucionó en ${m.name}!';
  }

  // ---------- Turno ----------
  Iterable<String> runTurn(BattleAction p, [BattleAction? r]) sync* {
    if (winner != null) return;

    for (final m in [activePlayer, activeRival]) {
      m.flinched = false;
      m.protecting = false;
      m.movedThisTurn = false;
    }

    // Transformaciones (antes de actuar): una por Pokémon.
    if (p.mega && canMega(true)) {
      yield* _mega(true);
    } else if (p.dynamax && canDynamax(true)) {
      yield* _dynamax(true);
    } else if (p.tera && canTera(true)) {
      yield* _tera(true);
    }
    var rMega = false;
    var rDyn = false;
    var rTera = false;
    if (humanRival) {
      if (r != null && r.switchTo == null) {
        rMega = r.mega;
        rDyn = r.dynamax;
        rTera = r.tera;
      }
    } else {
      rMega = canMega(false) && (difficulty != Difficulty.easy || rng.nextBool());
      if (!rMega && canDynamax(false) && rng.nextDouble() < _aiGimmickChance) {
        rDyn = true;
      } else if (!rMega &&
          canTera(false) &&
          rng.nextDouble() < _aiGimmickChance) {
        rTera = true;
      }
    }
    if (rMega && canMega(false)) {
      yield* _mega(false);
    } else if (rDyn && canDynamax(false)) {
      yield* _dynamax(false);
    } else if (rTera && canTera(false)) {
      yield* _tera(false);
    }

    // Cambios de Pokémon.
    final pSwitch = _validSwitch(true, p.switchTo);
    final rSwitch = humanRival && _validSwitch(false, r?.switchTo);
    if (pSwitch) yield* _doSwitch(true, p.switchTo!);
    if (rSwitch) yield* _doSwitch(false, r!.switchTo!);

    // Movimientos.
    final pIdx = _resolveIdx(activePlayer, p.moveIndex ?? 0);
    var rIdx = humanRival
        ? _resolveIdx(activeRival, r?.moveIndex ?? 0)
        : _aiMove(activeRival, activePlayer);
    var rWantsZ = humanRival && (r?.z ?? false);
    if (!humanRival) {
      final zi = _aiZIndex();
      if (zi != null) {
        rIdx = zi;
        rWantsZ = true;
      }
    }
    _pZ = !pSwitch && p.z && zMoveFor(true, pIdx) != null;
    _rZ = !rSwitch && rWantsZ && zMoveFor(false, rIdx) != null;

    final pQuick = !pSwitch &&
        activePlayer.item == 'quick-claw' &&
        rng.nextInt(5) == 0;
    final rQuick = !rSwitch &&
        activeRival.item == 'quick-claw' &&
        rng.nextInt(5) == 0;
    if (pQuick) {
      yield '¡La Garra Rápida de ${_label(activePlayer)} le permite moverse primero!';
    }
    if (rQuick) {
      yield '¡La Garra Rápida de ${_label(activeRival)} le permite moverse primero!';
    }

    final movers = <bool>[if (!pSwitch) true, if (!rSwitch) false];
    movers.sort((a, b) {
      final ma = a ? activePlayer.currentMoves[pIdx] : activeRival.currentMoves[rIdx];
      final mb = b ? activePlayer.currentMoves[pIdx] : activeRival.currentMoves[rIdx];
      if (ma.priority != mb.priority) return mb.priority.compareTo(ma.priority);
      final qa = a ? pQuick : rQuick;
      final qb = b ? pQuick : rQuick;
      if (qa != qb) return qa ? -1 : 1;
      final sa = (a ? activePlayer : activeRival).effectiveSpeed;
      final sb = (b ? activePlayer : activeRival).effectiveSpeed;
      if (sa != sb) return sb.compareTo(sa);
      return rng.nextBool() ? -1 : 1;
    });
    for (final isPlayer in movers) {
      if (winner != null) break;
      final user = isPlayer ? activePlayer : activeRival;
      if (user.fainted) continue;
      yield* _attack(isPlayer, isPlayer ? pIdx : rIdx);
    }

    // Efectos de final de turno.
    if (winner == null) {
      for (final mon in [activePlayer, activeRival]) {
        if (mon.fainted) continue;
        yield* _endOfTurn(mon);
      }
      yield* _fieldEnd();
      _updateWinner();
    }

    yield* _afterTurn();
  }

  /// El jugador elige a su siguiente Pokémon tras un debilitamiento.
  Iterable<String> playerSwitchIn(int index) sync* {
    if (!needsPlayerSwitch || index < 0 || index >= player.length) return;
    if (player[index].fainted) return;
    yield* _doSwitch(true, index);
  }

  /// Igual que [playerSwitchIn] pero para el rival humano.
  Iterable<String> rivalSwitchIn(int index) sync* {
    if (!needsRivalSwitch || index < 0 || index >= rival.length) return;
    if (rival[index].fainted) return;
    yield* _doSwitch(false, index);
  }

  // ---------- Internos ----------
  bool _validSwitch(bool isPlayer, int? index) {
    if (index == null) return false;
    final list = isPlayer ? player : rival;
    final active = isPlayer ? activePlayer : activeRival;
    final current = isPlayer ? _pActive : _rActive;
    if (index < 0 || index >= list.length || index == current) return false;
    if (list[index].fainted) return false;
    return active.fainted || active.trapTurns == 0;
  }

  int _resolveIdx(BattleMon m, int idx) {
    if (!m.dynamaxed &&
        m.lockedMove != null &&
        m.lockedMove! < m.moves.length) {
      return m.lockedMove!;
    }
    return idx.clamp(0, m.moves.length - 1).toInt();
  }

  Iterable<String> _doSwitch(bool isPlayer, int index) sync* {
    final leaving = isPlayer ? activePlayer : activeRival;
    leaving.resetVolatile();
    if (isPlayer) {
      _pActive = index;
    } else {
      _rActive = index;
    }
    final now = isPlayer ? activePlayer : activeRival;
    _fx = BattleFx(FxKind.send, isPlayer);
    yield '\u0004${isPlayer ? 'P' : 'R'}:${now.name}';
  }

  Iterable<String> _afterTurn() sync* {
    _updateWinner();
    if (winner != null) {
      yield winner == 'player' ? '\u0005P' : '\u0005R';
      return;
    }
    if (!humanRival && activeRival.fainted) {
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
    final ratio = physical
        ? a.stat('attack') / d.stat('defense')
        : a.stat('special-attack') / d.stat('special-defense');
    final stab = _stab(a, mv);
    final acc = (mv.accuracy ?? 100) / 100;
    return (mv.power ?? 60) * acc * stab * d.effectivenessOf(mv.type) * ratio;
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
      case 'leech-seed':
        return t.types.contains('grass');
      default:
        return false;
    }
  }

  /// ¿Tiene sentido que la IA use este movimiento sin daño?
  bool _utilityUseful(BattleMon a, BattleMon d, MoveData mv) {
    if (mv.isDamaging || !mv.hasUtilityEffect) return false;
    if (kSpecialMoves.contains(mv.slug)) return false;
    final ail = mv.ailment;
    if (ail != null) {
      switch (ail) {
        case 'confusion':
          return d.confusion == 0;
        case 'infatuation':
          return !d.infatuated;
        case 'trap':
          return d.trapTurns == 0;
        case 'leech-seed':
          return !d.seeded && !_immune(d, ail);
        case 'nightmare':
          return d.status == 'sleep' && !d.nightmare;
        case 'yawn':
          return d.status == null && d.yawn == 0;
        case 'perish-song':
          return false;
        default:
          return d.status == null && !_immune(d, ail);
      }
    }
    if (mv.healing > 0) return a.hp * 2 < a.maxHp;
    if (mv.statChanges.isNotEmpty) {
      if (mv.statsOnSelf) {
        return mv.statChanges.entries
            .every((e) => e.value > 0 && (a.stages[e.key] ?? 0) < 2);
      }
      return mv.statChanges.entries
          .every((e) => e.value < 0 && (d.stages[e.key] ?? 0) > -2);
    }
    return false;
  }

  int _aiMove(BattleMon a, BattleMon d) {
    if (!a.dynamaxed &&
        a.lockedMove != null &&
        a.lockedMove! < a.moves.length) {
      return a.lockedMove!;
    }
    final cur = a.currentMoves;

    if (difficulty != Difficulty.easy) {
      final useful = [
        for (var i = 0; i < cur.length; i++)
          if (_utilityUseful(a, d, cur[i])) i,
      ];
      final chance = difficulty == Difficulty.hard ? 0.4 : 0.25;
      if (useful.isNotEmpty && rng.nextDouble() < chance) {
        return useful[rng.nextInt(useful.length)];
      }
    }

    final scores = [for (final mv in cur) _score(a, d, mv)];
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

  // ---------- Efectos ----------
  /// Aplica un daño de estado/residual y gestiona el debilitamiento.
  Iterable<String> _hurt(
    BattleMon m,
    int dmg,
    String ailment,
    String text,
  ) sync* {
    m.hp = max(0, m.hp - dmg);
    _fx = BattleFx(FxKind.status, _isPlayerMon(m), ailment: ailment);
    yield text;
    if (m.fainted) {
      _fx = BattleFx(FxKind.faint, _isPlayerMon(m));
      yield '${_label(m)} se debilitó.';
    }
  }

  Iterable<String> _endOfTurn(BattleMon mon) sync* {
    final label = _label(mon);
    final onPlayer = _isPlayerMon(mon);
    final other = onPlayer ? activeRival : activePlayer;

    if (mon.dynamaxed) {
      mon.dynamaxTurns--;
      if (mon.dynamaxTurns <= 0) {
        mon.revertDynamax();
        _fx = BattleFx(FxKind.dynamax, onPlayer, up: false);
        yield '¡$label volvió a su tamaño normal!';
      }
    }

    if (mon.status == 'burn') {
      yield* _hurt(mon, max(1, mon.maxHp ~/ 16), 'burn',
          '$label sufre por la quemadura.');
      if (mon.fainted) return;
    } else if (mon.status == 'poison') {
      yield* _hurt(mon, max(1, mon.maxHp ~/ 8), 'poison',
          '$label sufre por el veneno.');
      if (mon.fainted) return;
    }

    if (mon.seeded) {
      final dmg = max(1, mon.maxHp ~/ 8);
      if (!other.fainted) other.hp = min(other.maxHp, other.hp + dmg);
      yield* _hurt(mon, dmg, 'leech-seed',
          'Las drenadoras absorben PS de $label.');
      if (mon.fainted) return;
    }

    if (mon.trapTurns > 0) {
      mon.trapTurns--;
      yield* _hurt(mon, max(1, mon.maxHp ~/ 8), 'trap',
          '$label sufre por estar atrapado.');
      if (mon.fainted) return;
      if (mon.trapTurns == 0) yield '¡$label se liberó!';
    }

    if (mon.cursed) {
      yield* _hurt(
          mon, max(1, mon.maxHp ~/ 4), 'curse', '$label sufre por la maldición.');
      if (mon.fainted) return;
    }

    if (mon.nightmare) {
      if (mon.status == 'sleep') {
        yield* _hurt(mon, max(1, mon.maxHp ~/ 4), 'nightmare',
            '$label sufre una pesadilla.');
        if (mon.fainted) return;
      } else {
        mon.nightmare = false;
      }
    }

    if (mon.yawn > 0) {
      mon.yawn--;
      if (mon.yawn == 0 && mon.status == null) {
        yield* _inflict(mon, 'sleep', announceFail: false);
      }
    }

    if (mon.perish > 0) {
      mon.perish--;
      if (mon.perish == 0) {
        yield* _hurt(mon, mon.hp, 'perish-song', '¡La cuenta atrás de $label llegó a 0!');
        return;
      }
      _fx = BattleFx(FxKind.status, onPlayer, ailment: 'perish-song');
      yield 'Cuenta atrás de $label: ${mon.perish}.';
    }

    if (mon.item == 'leftovers' && mon.hp < mon.maxHp) {
      mon.hp = min(mon.maxHp, mon.hp + max(1, mon.maxHp ~/ 16));
      _fx = BattleFx(FxKind.heal, onPlayer);
      yield '$label recuperó PS con los Restos.';
    }
    if (mon.item == 'black-sludge') {
      if (mon.types.contains('poison')) {
        if (mon.hp < mon.maxHp) {
          mon.hp = min(mon.maxHp, mon.hp + max(1, mon.maxHp ~/ 16));
          _fx = BattleFx(FxKind.heal, onPlayer);
          yield '$label recuperó PS con el Lodo Negro.';
        }
      } else {
        yield* _hurt(mon, max(1, mon.maxHp ~/ 8), 'poison',
            '$label sufre por el Lodo Negro.');
        if (mon.fainted) return;
      }
    }
    if (mon.item == 'flame-orb' && mon.status == null) {
      yield* _inflict(mon, 'burn', announceFail: false);
    } else if (mon.item == 'toxic-orb' && mon.status == null) {
      yield* _inflict(mon, 'poison', announceFail: false);
    }
  }

  // ---------- Clima y terreno ----------
  static const Map<String, String> _weatherStart = {
    'sun': '¡El sol se intensificó!',
    'rain': '¡Empezó a llover!',
    'hail': '¡Empezó a granizar!',
    'sand': '¡Se desató una tormenta de arena!',
  };
  static const Map<String, String> _terrainStart = {
    'grassy': '¡Un campo de hierba cubrió el terreno!',
    'electric': '¡Una corriente eléctrica recorre el terreno!',
    'psychic': '¡El terreno se volvió extraño!',
    'misty': '¡La niebla cubrió el terreno!',
  };

  Iterable<String> _setWeather(String w) sync* {
    if (weather == w) return;
    weather = w;
    weatherTurns = 5;
    _fx = BattleFx(FxKind.weather, true, ailment: w);
    yield _weatherStart[w] ?? '¡Cambió el clima!';
  }

  Iterable<String> _setTerrain(String t) sync* {
    if (terrain == t) return;
    terrain = t;
    terrainTurns = 5;
    _fx = BattleFx(FxKind.weather, true, ailment: t);
    yield _terrainStart[t] ?? '¡Cambió el terreno!';
  }

  bool _grounded(BattleMon m) =>
      !m.types.contains('flying') && !(m.item == 'air-balloon' && !m.itemUsed);

  /// Efectos de final de turno del clima y del terreno.
  Iterable<String> _fieldEnd() sync* {
    final w = weather;
    if (w != null) {
      if (w == 'hail' || w == 'sand') {
        for (final mon in [activePlayer, activeRival]) {
          if (mon.fainted) continue;
          final immune = w == 'hail'
              ? mon.types.contains('ice')
              : (mon.types.contains('rock') ||
                  mon.types.contains('ground') ||
                  mon.types.contains('steel'));
          if (immune) continue;
          yield* _hurt(
            mon,
            max(1, mon.maxHp ~/ 16),
            w == 'hail' ? 'freeze' : 'trap',
            w == 'hail'
                ? '${_label(mon)} sufre por el granizo.'
                : '${_label(mon)} sufre por la tormenta de arena.',
          );
        }
      }
      weatherTurns--;
      if (weatherTurns <= 0) {
        weather = null;
        yield 'El clima volvió a la normalidad.';
      }
    }
    final t = terrain;
    if (t != null) {
      if (t == 'grassy') {
        for (final mon in [activePlayer, activeRival]) {
          if (mon.fainted || mon.hp >= mon.maxHp || !_grounded(mon)) continue;
          mon.hp = min(mon.maxHp, mon.hp + max(1, mon.maxHp ~/ 16));
          _fx = BattleFx(FxKind.heal, _isPlayerMon(mon));
          yield '${_label(mon)} recuperó PS gracias al campo de hierba.';
        }
      }
      terrainTurns--;
      if (terrainTurns <= 0) {
        terrain = null;
        yield 'El terreno volvió a la normalidad.';
      }
    }
  }

  /// Bonificación por tipo propio (STAB), con la Teracristalización.
  double _stab(BattleMon a, MoveData mv) {
    if (a.terastallized) {
      final orig = a.originalTypes.contains(mv.type);
      if (mv.type == a.teraType) return orig ? 2.0 : 1.5;
      return orig ? 1.5 : 1.0;
    }
    return a.types.contains(mv.type) ? 1.5 : 1.0;
  }

  double _fieldMult(BattleMon a, BattleMon d, MoveData mv) {
    var m = 1.0;
    if (weather == 'sun') {
      if (mv.type == 'fire') m *= 1.5;
      if (mv.type == 'water') m *= 0.5;
    } else if (weather == 'rain') {
      if (mv.type == 'water') m *= 1.5;
      if (mv.type == 'fire') m *= 0.5;
    }
    if (_grounded(a)) {
      if (terrain == 'grassy' && mv.type == 'grass') m *= 1.3;
      if (terrain == 'electric' && mv.type == 'electric') m *= 1.3;
      if (terrain == 'psychic' && mv.type == 'psychic') m *= 1.3;
    }
    if (terrain == 'misty' && mv.type == 'dragon' && _grounded(d)) m *= 0.5;
    return m;
  }

  bool _rollCrit(BattleMon a) {
    var stage = 0;
    if (a.item == 'scope-lens' || a.item == 'razor-claw') stage += 1;
    if ((a.item == 'lucky-punch' && a.baseId == 113) ||
        (a.item == 'leek' && (a.baseId == 83 || a.baseId == 865))) {
      stage += 2;
    }
    final chance = stage <= 0 ? 16 : (stage == 1 ? 8 : (stage == 2 ? 2 : 1));
    return rng.nextInt(chance) == 0;
  }

  /// ¿Acierta el movimiento? (Los Máximos y Z nunca fallan.)
  bool _hits(BattleMon a, BattleMon d, MoveData mv) {
    final base = mv.accuracy;
    if (base == null || mv.isMax || mv.isZ) return true;
    var acc = base.toDouble();
    if (a.item == 'wide-lens') acc *= 1.1;
    if (d.item == 'bright-powder') acc *= 0.9;
    return rng.nextInt(100) < acc.floor();
  }

  static const Map<String, Map<String, int>> _maxSelf = {
    'fighting': {'attack': 1},
    'steel': {'defense': 1},
    'poison': {'special-attack': 1},
    'ground': {'special-defense': 1},
    'flying': {'speed': 1},
  };
  static const Map<String, Map<String, int>> _maxFoe = {
    'dragon': {'attack': -1},
    'ghost': {'defense': -1},
    'bug': {'special-attack': -1},
    'dark': {'special-defense': -1},
    'normal': {'speed': -1},
  };
  static const Map<String, String> _maxWeather = {
    'fire': 'sun',
    'water': 'rain',
    'ice': 'hail',
    'rock': 'sand',
  };
  static const Map<String, String> _maxTerrain = {
    'grass': 'grassy',
    'electric': 'electric',
    'psychic': 'psychic',
    'fairy': 'misty',
  };

  /// Efecto secundario de un Movimiento Máximo según su tipo.
  Iterable<String> _maxEffect(BattleMon a, BattleMon d, MoveData mv) sync* {
    final self = _maxSelf[mv.type];
    if (self != null && !a.fainted) yield* _applyStages(a, self);
    final foe = _maxFoe[mv.type];
    if (foe != null && !d.fainted) yield* _applyStages(d, foe);
    final w = _maxWeather[mv.type];
    if (w != null) yield* _setWeather(w);
    final t = _maxTerrain[mv.type];
    if (t != null) yield* _setTerrain(t);
  }

  /// Aplica un problema de estado o efecto único a [t].
  Iterable<String> _inflict(
    BattleMon t,
    String ailment, {
    required bool announceFail,
  }) sync* {
    if (t.fainted) return;
    final label = _label(t);
    final onPlayer = _isPlayerMon(t);

    void fx() => _fx = BattleFx(FxKind.status, onPlayer, ailment: ailment);

    switch (ailment) {
      case 'confusion':
        if (t.confusion > 0) {
          if (announceFail) yield 'Pero $label ya está confuso.';
          return;
        }
        t.confusion = 2 + rng.nextInt(4);
        fx();
        yield '¡$label está confuso!';
        yield* _lumBerry(t);
        return;
      case 'infatuation':
        if (t.infatuated) {
          if (announceFail) yield 'Pero $label ya está enamorado.';
          return;
        }
        t.infatuated = true;
        fx();
        yield '¡$label se enamoró!';
        return;
      case 'leech-seed':
        if (t.seeded || _immune(t, ailment)) {
          if (announceFail) yield 'No afecta a $label...';
          return;
        }
        t.seeded = true;
        fx();
        yield '¡$label fue infectado con drenadoras!';
        return;
      case 'trap':
        if (t.trapTurns > 0) {
          if (announceFail) yield 'Pero $label ya está atrapado.';
          return;
        }
        t.trapTurns = 4 + rng.nextInt(2);
        fx();
        yield '¡$label quedó atrapado! No podrá huir.';
        return;
      case 'nightmare':
        if (t.status != 'sleep' || t.nightmare) {
          if (announceFail) yield 'Pero falló.';
          return;
        }
        t.nightmare = true;
        fx();
        yield '¡$label empezó a tener pesadillas!';
        return;
      case 'yawn':
        if (t.status != null || t.yawn > 0) {
          if (announceFail) yield 'Pero falló.';
          return;
        }
        t.yawn = 2;
        fx();
        yield '¡$label tiene mucho sueño!';
        return;
      case 'perish-song':
        for (final m in [activePlayer, activeRival]) {
          if (!m.fainted && m.perish == 0) m.perish = 4;
        }
        fx();
        yield '¡Todos los Pokémon oirán su fin en 3 turnos!';
        return;
    }

    // Estados "clásicos".
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
    fx();
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
    yield* _lumBerry(t);
  }

  /// Baya Ziuela (cura todo) y bayas que curan un estado concreto.
  Iterable<String> _lumBerry(BattleMon t) sync* {
    final item = t.item;
    if (item == null || t.itemUsed || t.fainted) return;
    final isLum = item == 'lum-berry';
    final cures = kStatusBerries[item];
    if (!isLum && cures == null) return;
    if (t.status == null && t.confusion == 0) return;
    if (!isLum) {
      final matches = cures == 'confusion' ? t.confusion > 0 : t.status == cures;
      if (!matches) return;
    }
    t.itemUsed = true;
    if (isLum || cures == 'confusion') t.confusion = 0;
    if (isLum || cures != 'confusion') {
      t.status = null;
      t.sleepTurns = 0;
    }
    _fx = BattleFx(FxKind.heal, _isPlayerMon(t));
    yield '${_label(t)} comió su ${heldItemByKey(item)?.name ?? 'baya'} y se curó.';
  }

  /// Sube o baja estadísticas de [t].
  Iterable<String> _applyStages(BattleMon t, Map<String, int> changes) sync* {
    if (t.fainted) return;
    final label = _label(t);
    final onPlayer = _isPlayerMon(t);
    for (final e in changes.entries) {
      final old = t.stages[e.key] ?? 0;
      final now = (old + e.value).clamp(-6, 6).toInt();
      final name = kStatNames[e.key] ?? e.key;
      final up = e.value > 0;
      if (now == old) {
        yield 'El $name de $label no puede ${up ? 'subir' : 'bajar'} más.';
        continue;
      }
      t.stages[e.key] = now;
      final mag = e.value.abs();
      final how = mag >= 3 ? ' muchísimo' : (mag == 2 ? ' mucho' : '');
      _fx = BattleFx(FxKind.stat, onPlayer, up: up);
      yield 'El $name de $label ${up ? 'subió' : 'bajó'}$how.';
    }
  }

  Iterable<String> _attack(bool isPlayer, int idx) sync* {
    final a = isPlayer ? activePlayer : activeRival;
    final d = isPlayer ? activeRival : activePlayer;
    final who = _label(a);
    a.movedThisTurn = true;

    // --- Estados que pueden impedir actuar.
    if (a.flinched) {
      yield '$who retrocedió y no pudo moverse.';
      return;
    }
    if (a.status == 'sleep') {
      a.sleepTurns--;
      if (a.sleepTurns > 0) {
        _fx = BattleFx(FxKind.status, isPlayer, ailment: 'sleep');
        yield '$who está profundamente dormido.';
        return;
      }
      a.status = null;
      a.nightmare = false;
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
    if (a.infatuated) {
      _fx = BattleFx(FxKind.status, isPlayer, ailment: 'infatuation');
      yield '$who está enamorado.';
      if (rng.nextInt(2) == 0) {
        yield '¡$who está tan enamorado que no puede atacar!';
        return;
      }
    }
    if (a.confusion > 0) {
      a.confusion--;
      if (a.confusion == 0) {
        yield '¡$who ya no está confuso!';
      } else {
        _fx = BattleFx(FxKind.status, isPlayer, ailment: 'confusion');
        yield '$who está confuso.';
        if (rng.nextInt(3) == 0) {
          final base = ((2 * a.level ~/ 5) + 2) * 40 *
                  a.stat('attack') /
                  a.stat('defense') /
                  50 +
              2;
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
    var mv = a.currentMoves[idx];
    if (a.hasChoiceItem && !a.dynamaxed) a.lockedMove = idx;

    // Movimiento Z: se gasta al ejecutarse.
    if (isPlayer ? _pZ : _rZ) {
      final zm = zMoveFor(isPlayer, idx);
      if (zm != null) {
        a.zUsed = true;
        _fx = BattleFx(FxKind.zmove, isPlayer, type: zm.type);
        yield '¡$who canaliza el poder de su Cristal Z!';
        mv = zm;
      }
    }
    if (mv.slug != 'protect' && mv.slug != 'detect' && mv.slug != 'max-guard') {
      a.protectStreak = 0;
    }

    _fx = BattleFx(FxKind.move, isPlayer,
        type: mv.type, damaging: mv.isDamaging);
    yield '$who usó ${mv.name}.';

    if (!mv.isDamaging) {
      yield* _useUtility(a, d, mv, isPlayer);
      return;
    }

    final breaksGuard = mv.isZ || mv.isMax;
    if (d.protecting && !breaksGuard) {
      _fx = BattleFx(FxKind.status, !isPlayer, ailment: 'protect');
      yield '¡${_label(d)} se protegió del ataque!';
      return;
    }
    if (mv.category == 'ohko') {
      if (d.level > a.level) {
        yield 'Pero falló: ${_label(d)} es de nivel superior.';
        return;
      }
    }
    if (!_hits(a, d, mv)) {
      _fx = BattleFx(FxKind.miss, !isPlayer);
      yield '¡El ataque de $who falló!';
      return;
    }
    if (mv.type == 'ground' && d.item == 'air-balloon' && !d.itemUsed) {
      yield 'No afecta a ${_label(d)}, que flota con su Globo Helio...';
      return;
    }
    final eff = d.effectivenessOf(mv.type);
    if (eff == 0) {
      yield 'No afecta a ${_label(d)}...';
      return;
    }

    final crit = !mv.isFixed && _rollCrit(a);
    var dmg = mv.isFixed ? _fixedDamage(a, d, mv) : _damage(a, d, mv, eff, crit);
    if (d.protecting && breaksGuard) {
      dmg = max(1, dmg ~/ 4);
      yield '¡El ataque atraviesa parcialmente la protección!';
    }
    String? resistNote;
    final resist = kResistBerries[d.item];
    if (!mv.isFixed &&
        resist != null &&
        !d.itemUsed &&
        resist == mv.type &&
        (eff > 1 || resist == 'normal')) {
      dmg = max(1, dmg ~/ 2);
      d.itemUsed = true;
      resistNote =
          '${_label(d)} comió su ${heldItemByKey(d.item)?.name ?? 'baya'} y redujo el daño.';
    }
    String? surviveNote;
    if (dmg >= d.hp && d.hp > 1) {
      if (d.item == 'focus-sash' && !d.itemUsed && d.hp == d.maxHp) {
        dmg = d.hp - 1;
        d.itemUsed = true;
        surviveNote = '¡${_label(d)} se aferró a su Banda Focus!';
      } else if (d.item == 'focus-band' && rng.nextInt(10) == 0) {
        dmg = d.hp - 1;
        surviveNote = '¡${_label(d)} aguantó el golpe con su Cinta Focus!';
      }
    }
    d.hp = max(0, d.hp - dmg);
    _fx = BattleFx(FxKind.hit, !isPlayer,
        type: mv.type, eff: mv.isFixed ? 1.0 : eff, crit: crit);
    yield '${_label(d)} recibió $dmg de daño.';
    if (resistNote != null) yield resistNote;
    if (surviveNote != null) yield surviveNote;
    if (mv.category == 'ohko') yield '¡KO de un golpe!';
    if (crit) yield '¡Golpe crítico!';
    if (!mv.isFixed) {
      if (eff > 1) {
        yield '¡Es muy eficaz!';
      } else if (eff < 1) {
        yield 'No es muy eficaz...';
      }
    }

    if (d.status == 'freeze' && mv.type == 'fire' && !d.fainted) {
      d.status = null;
      yield '¡${_label(d)} se descongeló por el calor!';
    }

    // Absorción / retroceso.
    if (mv.drain > 0 && !a.fainted) {
      final heal = max(1, dmg * mv.drain ~/ 100);
      a.hp = min(a.maxHp, a.hp + heal);
      _fx = BattleFx(FxKind.heal, isPlayer);
      yield '$who absorbió energía de ${_label(d)}.';
    } else if (mv.drain < 0 && !a.fainted) {
      final rec = max(1, dmg * (-mv.drain) ~/ 100);
      a.hp = max(0, a.hp - rec);
      _fx = BattleFx(FxKind.hit, isPlayer);
      yield '$who sufre daño de retroceso.';
    }

    // Efectos de objetos.
    if (a.item == 'shell-bell' && !a.fainted && a.hp < a.maxHp && dmg > 0) {
      a.hp = min(a.maxHp, a.hp + max(1, dmg ~/ 8));
      _fx = BattleFx(FxKind.heal, isPlayer);
      yield '$who recuperó PS con la Campana Concha.';
    }
    if (d.item == 'air-balloon' && !d.itemUsed && !d.fainted) {
      d.itemUsed = true;
      yield '¡El Globo Helio de ${_label(d)} explotó!';
    }
    if (d.item == 'weakness-policy' &&
        !d.itemUsed &&
        !d.fainted &&
        eff > 1 &&
        !mv.isFixed) {
      d.itemUsed = true;
      yield '¡El Seguro Debilidad de ${_label(d)} se activó!';
      yield* _applyStages(d, {'attack': 2, 'special-attack': 2});
    }
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

    // Cambios de estadísticas secundarios (ej. Psíquico baja Def. Esp.).
    if (mv.statChanges.isNotEmpty &&
        (mv.category == 'damage+lower' || mv.category == 'damage+raise')) {
      final chance = mv.statChance > 0 ? mv.statChance : 100;
      if (rng.nextInt(100) < chance) {
        if (mv.statsOnSelf) {
          yield* _applyStages(a, mv.statChanges);
        } else if (!d.fainted) {
          yield* _applyStages(d, mv.statChanges);
        }
      }
    }

    // Efectos de los Movimientos Máximos.
    if (mv.isMax) yield* _maxEffect(a, d, mv);

    // Retroceso del rival (solo si aún no ha actuado).
    final flinchChance =
        max(mv.flinchChance, a.item == 'kings-rock' ? 10 : 0);
    if (flinchChance > 0 &&
        !d.fainted &&
        !d.dynamaxed &&
        !d.movedThisTurn &&
        rng.nextInt(100) < flinchChance) {
      d.flinched = true;
    }

    // Autodestrucción.
    if (mv.slug == 'explosion' || mv.slug == 'self-destruct') {
      a.hp = 0;
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

  /// Movimientos sin daño: estado, estadísticas, curación y efectos únicos.
  Iterable<String> _useUtility(
    BattleMon a,
    BattleMon d,
    MoveData mv,
    bool isPlayer,
  ) sync* {
    final who = _label(a);

    // Protección.
    if (mv.slug == 'protect' || mv.slug == 'detect' || mv.slug == 'max-guard') {
      final ok = a.protectStreak == 0 ||
          rng.nextInt(pow(3, a.protectStreak).toInt()) == 0;
      if (!ok) {
        a.protectStreak = 0;
        yield 'Pero falló.';
        return;
      }
      a.protectStreak++;
      a.protecting = true;
      _fx = BattleFx(FxKind.status, isPlayer, ailment: 'protect');
      yield '¡$who se está protegiendo!';
      return;
    }

    // Descanso.
    if (mv.slug == 'rest') {
      if (a.hp >= a.maxHp || a.status == 'sleep') {
        yield 'Pero falló.';
        return;
      }
      a.hp = a.maxHp;
      a.status = 'sleep';
      a.sleepTurns = 3;
      _fx = BattleFx(FxKind.heal, isPlayer);
      yield '¡$who durmió y recuperó toda su salud!';
      return;
    }

    // Maldición.
    if (mv.slug == 'curse') {
      if (a.types.contains('ghost')) {
        if (d.cursed) {
          yield 'Pero falló.';
          return;
        }
        a.hp = max(0, a.hp - max(1, a.maxHp ~/ 2));
        d.cursed = true;
        _fx = BattleFx(FxKind.status, !isPlayer, ailment: 'curse');
        yield '$who sacrificó la mitad de sus PS y maldijo a ${_label(d)}.';
        if (a.fainted) {
          _fx = BattleFx(FxKind.faint, isPlayer);
          yield '$who se debilitó.';
          _updateWinner();
        }
      } else {
        yield* _applyStages(a, {'attack': 1, 'defense': 1, 'speed': -1});
      }
      return;
    }

    final targetsOpp =
        mv.ailment != null || (mv.statChanges.isNotEmpty && !mv.statsOnSelf);
    if (targetsOpp) {
      if (d.protecting) {
        _fx = BattleFx(FxKind.status, !isPlayer, ailment: 'protect');
        yield '¡${_label(d)} se protegió!';
        return;
      }
      if (!_hits(a, d, mv)) {
        _fx = BattleFx(FxKind.miss, !isPlayer);
        yield '¡El ataque de $who falló!';
        return;
      }
    }

    var did = false;
    if (mv.healing > 0) {
      did = true;
      if (a.hp >= a.maxHp) {
        yield 'La salud de $who ya está al máximo.';
      } else {
        a.hp = min(a.maxHp, a.hp + max(1, a.maxHp * mv.healing ~/ 100));
        _fx = BattleFx(FxKind.heal, isPlayer);
        yield '$who recuperó PS.';
      }
    }
    if (mv.statChanges.isNotEmpty) {
      did = true;
      yield* _applyStages(mv.statsOnSelf ? a : d, mv.statChanges);
    }
    if (mv.ailment != null) {
      did = true;
      yield* _inflict(d, mv.ailment!, announceFail: true);
    }
    if (!did) yield 'Pero no tuvo efecto en esta simulación.';
  }

  int _fixedDamage(BattleMon a, BattleMon d, MoveData mv) {
    switch (mv.slug) {
      case 'seismic-toss':
      case 'night-shade':
        return a.level;
      case 'sonic-boom':
        return 20;
      case 'dragon-rage':
        return 40;
      case 'super-fang':
        return max(1, d.hp ~/ 2);
      case 'guardian-of-alola':
        return max(1, d.hp * 3 ~/ 4);
      default: // KO de un golpe
        return d.hp;
    }
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
    var atk = a.stat(physical ? 'attack' : 'special-attack');
    var def = d.stat(physical ? 'defense' : 'special-defense');
    if (crit) {
      // El golpe crítico ignora las bajadas de ataque y las subidas de defensa.
      if ((a.stages[physical ? 'attack' : 'special-attack'] ?? 0) < 0) {
        atk = (physical ? a.atk : a.spa).toDouble();
      }
      if ((d.stages[physical ? 'defense' : 'special-defense'] ?? 0) > 0) {
        def = (physical ? d.def : d.spd).toDouble();
      }
    }
    if (a.baseId == 25 && a.item == 'light-ball') atk *= 2;
    if (physical && a.item == 'choice-band') atk *= 1.5;
    if (!physical && a.item == 'choice-specs') atk *= 1.5;
    if (!physical && d.item == 'assault-vest') def *= 1.5;
    if (physical && a.status == 'burn') atk *= 0.5;
    if (physical && a.item == 'thick-club' && (a.baseId == 104 || a.baseId == 105)) {
      atk *= 2;
    }
    if (!physical && a.item == 'soul-dew' && (a.baseId == 380 || a.baseId == 381)) {
      atk *= 1.5;
    }
    if (!physical && a.item == 'deep-sea-tooth' && a.baseId == 366) atk *= 2;
    if (!physical && d.item == 'soul-dew' && (d.baseId == 380 || d.baseId == 381)) {
      def *= 1.5;
    }
    if (!physical && d.item == 'deep-sea-scale' && d.baseId == 366) def *= 2;
    if (physical && d.item == 'metal-powder' && d.baseId == 132) def *= 2;

    final levelFactor = (2 * a.level ~/ 5) + 2;
    var power = mv.power!.toDouble();
    // Teracristal: los movimientos flojos de su Teratipo suben a 60.
    if (a.terastallized &&
        mv.type == a.teraType &&
        power < 60 &&
        mv.priority == 0 &&
        !mv.isMax &&
        !mv.isZ) {
      power = 60;
    }
    var dmg = (levelFactor * power * atk / def) / 50 + 2;

    dmg *= _stab(a, mv);
    dmg *= _fieldMult(a, d, mv);
    dmg *= eff;
    if (crit) dmg *= 1.5;
    dmg *= 0.85 + rng.nextDouble() * 0.15;
    if (a.item == 'life-orb') dmg *= 1.3;
    if (a.item == 'expert-belt' && eff > 1) dmg *= 1.2;
    if (kTypeBoostItems[a.item] == mv.type) dmg *= 1.2;
    if (physical && a.item == 'muscle-band') dmg *= 1.1;
    if (!physical && a.item == 'wise-glasses') dmg *= 1.1;
    if ((a.item == 'adamant-orb' &&
            a.baseId == 483 &&
            (mv.type == 'dragon' || mv.type == 'steel')) ||
        (a.item == 'lustrous-orb' &&
            a.baseId == 484 &&
            (mv.type == 'dragon' || mv.type == 'water')) ||
        (a.item == 'griseous-orb' &&
            a.baseId == 487 &&
            (mv.type == 'dragon' || mv.type == 'ghost'))) {
      dmg *= 1.2;
    }

    return max(1, dmg.floor());
  }
}
