const int kTeamSize = 6;
const int kMoveSlots = 4;

/// Un Pokémon del equipo con sus datos personalizables.
class TeamMember {
  final int pokemonId;

  /// Nombre en la PokeAPI (ej. "pikachu").
  final String name;
  int level;
  String? ability;

  /// Siempre [kMoveSlots] posiciones (null = vacío). Guarda el nombre de la PokeAPI.
  List<String?> moves;

  /// Clave del objeto (ver held_items.dart).
  String? itemKey;

  TeamMember({
    required this.pokemonId,
    required this.name,
    this.level = 50,
    this.ability,
    List<String?>? moves,
    this.itemKey,
  }) : moves = moves ?? List<String?>.filled(kMoveSlots, null);

  Map<String, dynamic> toJson() => {
        'id': pokemonId,
        'name': name,
        'level': level,
        'ability': ability,
        'moves': moves,
        'item': itemKey,
      };

  factory TeamMember.fromJson(Map<String, dynamic> json) {
    final raw = (json['moves'] as List? ?? const []).map((e) => e as String?);
    final moves = List<String?>.filled(kMoveSlots, null);
    var i = 0;
    for (final m in raw) {
      if (i >= kMoveSlots) break;
      moves[i++] = m;
    }
    return TeamMember(
      pokemonId: json['id'] as int,
      name: json['name'] as String,
      level: (json['level'] ?? 50) as int,
      ability: json['ability'] as String?,
      moves: moves,
      itemKey: json['item'] as String?,
    );
  }
}
