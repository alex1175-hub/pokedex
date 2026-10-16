/// Elemento de la lista (respuesta de /pokemon?limit=150).
class PokemonListItem {
  final int id;
  final String name;

  PokemonListItem({required this.id, required this.name});

  factory PokemonListItem.fromJson(Map<String, dynamic> json) {
    // La url tiene la forma https://pokeapi.co/api/v2/pokemon/25/
    final url = json['url'] as String;
    final segments = url.split('/').where((s) => s.isNotEmpty).toList();
    return PokemonListItem(
      id: int.parse(segments.last),
      name: json['name'] as String,
    );
  }
}

/// Paso 3: clase personalizada para convertir la respuesta JSON.
class Pokemon {
  final int id;
  final String name;
  final int height;
  final int weight;
  final int baseExperience;
  final String imageUrl;
  final List<String> types;
  final List<String> abilities;
  final Map<String, int> stats;

  Pokemon({
    required this.id,
    required this.name,
    required this.height,
    required this.weight,
    required this.baseExperience,
    required this.imageUrl,
    required this.types,
    required this.abilities,
    required this.stats,
  });

  factory Pokemon.fromJson(Map<String, dynamic> json) {
    return Pokemon(
      id: json['id'] as int,
      name: json['name'] as String,
      height: json['height'] as int,
      weight: json['weight'] as int,
      baseExperience: (json['base_experience'] ?? 0) as int,
      imageUrl: (json['sprites']?['front_default'] ?? '') as String,
      types: (json['types'] as List)
          .map((t) => t['type']['name'] as String)
          .toList(),
      abilities: (json['abilities'] as List)
          .map((a) => a['ability']['name'] as String)
          .toList(),
      stats: {
        for (final s in json['stats'] as List)
          s['stat']['name'] as String: s['base_stat'] as int,
      },
    );
  }
}
