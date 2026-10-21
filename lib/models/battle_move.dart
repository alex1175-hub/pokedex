import 'pokemon.dart';

/// Efectos de estado (y efectos únicos) que el combate sabe aplicar
/// (nombres de la PokeAPI).
const Set<String> kSupportedAilments = {
  'paralysis',
  'sleep',
  'freeze',
  'burn',
  'poison',
  'confusion',
  'infatuation', // Atracción
  'trap', // Atrapar (Constricción, Giro Fuego...)
  'leech-seed', // Drenadoras
  'nightmare', // Pesadilla
  'yawn', // Bostezo
  'perish-song', // Canto Mortal
};

/// Verbo en español para mostrar en el botón del movimiento.
const Map<String, String> kAilmentVerbs = {
  'paralysis': 'Paralizar',
  'sleep': 'Dormir',
  'freeze': 'Congelar',
  'burn': 'Quemar',
  'poison': 'Envenenar',
  'confusion': 'Confundir',
  'infatuation': 'Enamorar',
  'trap': 'Atrapar',
  'leech-seed': 'Drenar',
  'nightmare': 'Pesadilla',
  'yawn': 'Dar sueño',
  'perish-song': 'Cuenta atrás',
};

/// Movimientos con efecto propio que se resuelven por su nombre.
const Set<String> kSpecialMoves = {
  'curse',
  'protect',
  'detect',
  'rest',
  'explosion',
  'self-destruct',
  'max-guard',
};

/// Movimientos de daño fijo (no usan la fórmula normal).
const Set<String> kFixedDamageMoves = {
  'seismic-toss',
  'night-shade',
  'sonic-boom',
  'dragon-rage',
  'super-fang',
  'guardian-of-alola', // Movimiento Z de los Tapu
};

/// Movimientos que bajan sus propias estadísticas tras atacar.
const Set<String> kSelfLowering = {
  'overheat',
  'close-combat',
  'superpower',
  'draco-meteor',
  'leaf-storm',
  'psycho-boost',
  'v-create',
  'hammer-arm',
  'ice-hammer',
  'clanging-scales',
  'fleur-cannon',
  'dragon-ascent',
};

/// Estadísticas que el combate modifica con subidas/bajadas.
const List<String> kStageStats = [
  'attack',
  'defense',
  'special-attack',
  'special-defense',
  'speed',
];

const Map<String, String> kStatNames = {
  'attack': 'Ataque',
  'defense': 'Defensa',
  'special-attack': 'Ataque Esp.',
  'special-defense': 'Defensa Esp.',
  'speed': 'Velocidad',
};

/// Datos de un movimiento necesarios para el combate (PokeAPI /move).
class MoveData {
  final String slug;
  final String name;
  final String type;

  /// physical, special o status.
  final String damageClass;
  final int? power;
  final int? accuracy;
  final int priority;

  /// Objetivo (user, selected-pokemon, all-opponents...).
  final String target;

  /// Categoría de la PokeAPI (ailment, damage+lower, heal, ohko...).
  final String category;

  /// Problema de estado o efecto único que puede causar (null si ninguno).
  final String? ailment;

  /// Probabilidad (1-100) de causar [ailment].
  final int ailmentChance;

  /// Cambios de estadísticas (+/- niveles).
  final Map<String, int> statChanges;
  final int statChance;

  /// >0: absorbe ese % del daño; <0: retroceso de ese % del daño.
  final int drain;

  /// % de PS máximos que cura a quien lo usa.
  final int healing;
  final int flinchChance;

  /// Movimiento Máximo (Dynamax/Gigamax) o Movimiento Z: versiones
  /// potenciadas que genera el combate a partir de un movimiento normal.
  final bool isMax;
  final bool isZ;

  const MoveData({
    required this.slug,
    required this.name,
    required this.type,
    required this.damageClass,
    required this.power,
    required this.accuracy,
    this.priority = 0,
    this.target = 'selected-pokemon',
    this.category = 'damage',
    this.ailment,
    this.ailmentChance = 0,
    this.statChanges = const {},
    this.statChance = 0,
    this.drain = 0,
    this.healing = 0,
    this.flinchChance = 0,
    this.isMax = false,
    this.isZ = false,
  });

  /// Daño fijo o KO de un golpe.
  bool get isFixed => kFixedDamageMoves.contains(slug) || category == 'ohko';

  /// Movimiento que hace daño directo.
  bool get isDamaging =>
      (damageClass != 'status' && (power ?? 0) > 0) || isFixed;

  /// Movimiento sin daño que sí tiene algún efecto en el combate.
  bool get hasUtilityEffect =>
      !isDamaging &&
      (ailment != null ||
          statChanges.isNotEmpty ||
          healing > 0 ||
          kSpecialMoves.contains(slug));

  /// Compatibilidad: movimiento de estado que causa un problema de estado.
  bool get isStatusEffect => !isDamaging && ailment != null;

  /// ¿Los cambios de estadísticas son para quien lo usa?
  bool get statsOnSelf {
    if (target == 'user' || target == 'users-field') return true;
    if (category == 'damage+raise') return true;
    return category == 'damage+lower' &&
        statChance >= 100 &&
        kSelfLowering.contains(slug);
  }

  /// Movimiento de reserva para Pokémon sin movimientos.
  static const MoveData tackle = MoveData(
    slug: 'tackle',
    name: 'Placaje',
    type: 'normal',
    damageClass: 'physical',
    power: 40,
    accuracy: 100,
  );

  factory MoveData.fromJson(Map<String, dynamic> json) {
    String? es;
    for (final n in json['names'] as List) {
      if (n['language']['name'] == 'es') es = n['name'] as String;
    }
    final slug = json['name'] as String;

    final metaRaw = json['meta'];
    final meta = metaRaw is Map<String, dynamic> ? metaRaw : <String, dynamic>{};
    final category = (meta['category'] as Map?)?['name'] as String? ?? 'damage';

    // Problema de estado / efecto único.
    String? ailment;
    var ailmentChance = 0;
    final ailName = (meta['ailment'] as Map?)?['name'] as String?;
    if (ailName != null &&
        kSupportedAilments.contains(ailName) &&
        (category == 'ailment' || category == 'damage+ailment')) {
      final chance = (meta['ailment_chance'] as int?) ?? 0;
      ailmentChance = chance > 0 ? chance : (category == 'ailment' ? 100 : 0);
      if (ailmentChance > 0) ailment = ailName;
    }

    // Cambios de estadísticas.
    final stats = <String, int>{};
    for (final s in (json['stat_changes'] as List? ?? const [])) {
      final key = s['stat']['name'] as String;
      if (kStageStats.contains(key)) stats[key] = s['change'] as int;
    }

    return MoveData(
      slug: slug,
      name: es ?? humanize(slug),
      type: json['type']['name'] as String,
      damageClass: json['damage_class']['name'] as String,
      power: json['power'] as int?,
      accuracy: json['accuracy'] as int?,
      priority: (json['priority'] as int?) ?? 0,
      target: (json['target'] as Map?)?['name'] as String? ??
          'selected-pokemon',
      category: category,
      ailment: ailment,
      ailmentChance: ailmentChance,
      statChanges: stats,
      statChance: (meta['stat_chance'] as int?) ?? 0,
      drain: (meta['drain'] as int?) ?? 0,
      healing: (meta['healing'] as int?) ?? 0,
      flinchChance: (meta['flinch_chance'] as int?) ?? 0,
    );
  }
}
