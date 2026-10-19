import 'pokemon.dart';

/// Problemas de estado que el combate sabe aplicar (nombre de la PokeAPI).
const Set<String> kSupportedAilments = {
  'paralysis',
  'sleep',
  'freeze',
  'burn',
  'poison',
  'confusion',
};

/// Verbo en español para mostrar en el botón del movimiento.
const Map<String, String> kAilmentVerbs = {
  'paralysis': 'Paralizar',
  'sleep': 'Dormir',
  'freeze': 'Congelar',
  'burn': 'Quemar',
  'poison': 'Envenenar',
  'confusion': 'Confundir',
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

  /// Problema de estado que puede causar (null si ninguno).
  final String? ailment;

  /// Probabilidad (1-100) de causar [ailment].
  final int ailmentChance;

  const MoveData({
    required this.slug,
    required this.name,
    required this.type,
    required this.damageClass,
    required this.power,
    required this.accuracy,
    this.ailment,
    this.ailmentChance = 0,
  });

  /// Movimiento que hace daño directo.
  bool get isDamaging => damageClass != 'status' && (power ?? 0) > 0;

  /// Movimiento de estado que causa un problema de estado (ej. Onda Trueno).
  bool get isStatusEffect => !isDamaging && ailment != null;

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

    // Problema de estado (solo movimientos de estado o con efecto secundario).
    String? ailment;
    var ailmentChance = 0;
    final meta = json['meta'];
    if (meta is Map<String, dynamic>) {
      final name = (meta['ailment'] as Map?)?['name'] as String?;
      final category = (meta['category'] as Map?)?['name'] as String?;
      if (name != null &&
          kSupportedAilments.contains(name) &&
          (category == 'ailment' || category == 'damage+ailment')) {
        final chance = (meta['ailment_chance'] as int?) ?? 0;
        ailmentChance = chance > 0 ? chance : (category == 'ailment' ? 100 : 0);
        if (ailmentChance > 0) ailment = name;
      }
    }

    return MoveData(
      slug: slug,
      name: es ?? humanize(slug),
      type: json['type']['name'] as String,
      damageClass: json['damage_class']['name'] as String,
      power: json['power'] as int?,
      accuracy: json['accuracy'] as int?,
      ailment: ailment,
      ailmentChance: ailmentChance,
    );
  }
}
