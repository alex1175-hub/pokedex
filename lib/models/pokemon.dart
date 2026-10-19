/// Convierte "mr-mime" en "Mr Mime".
String humanize(String slug) => slug
    .split('-')
    .map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1))
    .join(' ');

/// Extrae el id numérico del final de una URL de la PokeAPI
/// (ej. https://pokeapi.co/api/v2/pokemon-species/25/ -> 25).
int idFromUrl(String url) {
  final segments = url.split('/').where((s) => s.isNotEmpty).toList();
  return int.parse(segments.last);
}

/// Sprite pequeño (pixel art) de un Pokémon a partir de su número.
String spriteUrlFor(int id) =>
    'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/$id.png';

/// Elemento de la lista (respuesta de /pokemon?limit=...).
class PokemonListItem {
  final int id;
  final String name;

  PokemonListItem({required this.id, required this.name});

  factory PokemonListItem.fromJson(Map<String, dynamic> json) {
    return PokemonListItem(
      id: idFromUrl(json['url'] as String),
      name: json['name'] as String,
    );
  }
}

/// Habilidad de un Pokémon (referencia; su descripción se pide aparte).
class AbilityRef {
  final String name;
  final bool isHidden;
  AbilityRef({required this.name, required this.isHidden});
}

/// Un movimiento y cómo se aprende en un juego concreto.
class MoveEntry {
  final String name;

  /// level-up, machine (MT/MO), egg, tutor, ...
  final String method;

  /// Nivel al que se aprende (solo con level-up; 0 si no aplica).
  final int level;

  MoveEntry({required this.name, required this.method, required this.level});
}

/// Paso 3: clase personalizada para convertir la respuesta JSON.
class Pokemon {
  final int id;
  final String name;
  final int height;
  final int weight;
  final int baseExperience;
  final String imageUrl;
  final String artworkUrl;
  final String? cryUrl;
  final List<String> types;
  final List<AbilityRef> abilities;
  final Map<String, int> stats;

  /// Movimientos agrupados por juego (clave = version group de la PokeAPI).
  final Map<String, List<MoveEntry>> movesByVersion;

  Pokemon({
    required this.id,
    required this.name,
    required this.height,
    required this.weight,
    required this.baseExperience,
    required this.imageUrl,
    required this.artworkUrl,
    required this.cryUrl,
    required this.types,
    required this.abilities,
    required this.stats,
    required this.movesByVersion,
  });

  factory Pokemon.fromJson(Map<String, dynamic> json) {
    final cries = json['cries'] as Map<String, dynamic>?;
    final sprites = json['sprites'] as Map<String, dynamic>?;

    final byVersion = <String, List<MoveEntry>>{};
    for (final m in json['moves'] as List) {
      final name = m['move']['name'] as String;
      for (final v in m['version_group_details'] as List) {
        byVersion
            .putIfAbsent(v['version_group']['name'] as String, () => [])
            .add(MoveEntry(
              name: name,
              method: v['move_learn_method']['name'] as String,
              level: (v['level_learned_at'] ?? 0) as int,
            ));
      }
    }

    return Pokemon(
      id: json['id'] as int,
      name: json['name'] as String,
      height: json['height'] as int,
      weight: json['weight'] as int,
      baseExperience: (json['base_experience'] ?? 0) as int,
      imageUrl: (sprites?['front_default'] ?? '') as String,
      artworkUrl:
          (sprites?['other']?['official-artwork']?['front_default'] ?? '')
              as String,
      // Grito en formato .ogg (más reciente; si no existe, el clásico).
      cryUrl: (cries?['latest'] ?? cries?['legacy']) as String?,
      types: (json['types'] as List)
          .map((t) => t['type']['name'] as String)
          .toList(),
      abilities: (json['abilities'] as List)
          .map((a) => AbilityRef(
                name: a['ability']['name'] as String,
                isHidden: (a['is_hidden'] ?? false) as bool,
              ))
          .toList(),
      stats: {
        for (final s in json['stats'] as List)
          s['stat']['name'] as String: s['base_stat'] as int,
      },
      movesByVersion: byVersion,
    );
  }
}
