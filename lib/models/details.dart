import 'evolution.dart';
import 'pokemon.dart';

const Map<String, String> _eggGroupNames = {
  'monster': 'Monstruo',
  'water1': 'Agua 1',
  'water2': 'Agua 2',
  'water3': 'Agua 3',
  'bug': 'Bicho',
  'flying': 'Volador',
  'ground': 'Campo',
  'fairy': 'Hada',
  'plant': 'Planta',
  'humanshape': 'Humanoide',
  'mineral': 'Mineral',
  'indeterminate': 'Amorfo',
  'ditto': 'Ditto',
  'dragon': 'Dragón',
  'no-eggs': 'Desconocido',
};

/// Último texto del idioma [lang] (el último suele ser el más reciente).
String? _byLang(List entries, String field, String lang) {
  String? result;
  for (final e in entries) {
    if (e['language']['name'] == lang) result = e[field] as String?;
  }
  return result;
}

String _clean(String s) => s.replaceAll(RegExp(r'\s+'), ' ').trim();

/// Habilidad con su nombre y descripción (en español si existe).
class AbilityInfo {
  final String name;
  final String description;
  final bool isHidden;

  AbilityInfo({
    required this.name,
    required this.description,
    required this.isHidden,
  });

  factory AbilityInfo.fromJson(Map<String, dynamic> json, bool isHidden) {
    final names = json['names'] as List;
    final flavor = json['flavor_text_entries'] as List;
    final effects = json['effect_entries'] as List;

    final description = _byLang(flavor, 'flavor_text', 'es') ??
        _byLang(effects, 'short_effect', 'en') ??
        _byLang(flavor, 'flavor_text', 'en') ??
        '';

    return AbilityInfo(
      name: _byLang(names, 'name', 'es') ?? humanize(json['name'] as String),
      description: _clean(description),
      isHidden: isHidden,
    );
  }
}

/// Un tipo: contra qué tipos es débil/resistente y qué Pokémon lo tienen.
class TypeInfo {
  final String name;

  /// Multiplicador de daño recibido por tipo atacante (2, 0.5 o 0).
  final Map<String, double> damageFrom;

  /// Números de los Pokémon con este tipo.
  final Set<int> pokemonIds;

  TypeInfo({
    required this.name,
    required this.damageFrom,
    required this.pokemonIds,
  });

  factory TypeInfo.fromJson(Map<String, dynamic> json) {
    final relations = json['damage_relations'] as Map<String, dynamic>;
    final damage = <String, double>{};
    void apply(String key, double multiplier) {
      for (final t in relations[key] as List) {
        damage[t['name'] as String] = multiplier;
      }
    }

    apply('double_damage_from', 2);
    apply('half_damage_from', 0.5);
    apply('no_damage_from', 0);

    final ids = <int>{
      for (final p in json['pokemon'] as List)
        idFromUrl(p['pokemon']['url'] as String),
    };

    return TypeInfo(
      name: json['name'] as String,
      damageFrom: damage,
      pokemonIds: ids,
    );
  }
}

/// Región a la que pertenece una Pokédex regional (null si no aplica).
String? _regionFromPokedex(String pokedex) {
  const table = {
    'kanto': 'Kanto',
    'johto': 'Johto',
    'hoenn': 'Hoenn',
    'sinnoh': 'Sinnoh',
    'unova': 'Teselia',
    'kalos': 'Kalos',
    'alola': 'Alola',
    'melemele': 'Alola',
    'akala': 'Alola',
    'ulaula': 'Alola',
    'poni': 'Alola',
    'galar': 'Galar',
    'isle-of-armor': 'Galar',
    'crown-tundra': 'Galar',
    'hisui': 'Hisui',
    'paldea': 'Paldea',
    'kitakami': 'Paldea',
    'blueberry': 'Paldea',
  };
  for (final e in table.entries) {
    if (pokedex.contains(e.key)) return e.value;
  }
  return null;
}

/// Todo lo que muestra la ficha de un Pokémon.
class PokemonDetails {
  final Pokemon pokemon;
  final int speciesId;
  final String speciesName;
  final String generation;
  final String genus;
  final String description;
  final List<String> eggGroups;

  /// Probabilidad de hembra en octavos (0-8); -1 = sin género.
  final int genderRate;
  final List<String> regions;
  final List<EvolutionStep> evolutions;
  final List<AbilityInfo> abilities;

  /// Multiplicador de daño recibido por tipo atacante (ya combinado).
  final Map<String, double> effectiveness;

  PokemonDetails({
    required this.pokemon,
    required this.speciesId,
    required this.speciesName,
    required this.generation,
    required this.genus,
    required this.description,
    required this.eggGroups,
    required this.genderRate,
    required this.regions,
    required this.evolutions,
    required this.abilities,
    required this.effectiveness,
  });

  factory PokemonDetails.from({
    required Pokemon pokemon,
    required Map<String, dynamic> species,
    required Map<String, dynamic> chain,
    required List<AbilityInfo> abilities,
    required List<TypeInfo> types,
  }) {
    final regions = <String>[];
    for (final p in species['pokedex_numbers'] as List) {
      final region = _regionFromPokedex(p['pokedex']['name'] as String);
      if (region != null && !regions.contains(region)) regions.add(region);
    }

    final effectiveness = <String, double>{};
    for (final t in types) {
      t.damageFrom.forEach((attacker, multiplier) {
        effectiveness[attacker] = (effectiveness[attacker] ?? 1.0) * multiplier;
      });
    }

    final genera = species['genera'] as List;
    final flavor = species['flavor_text_entries'] as List;
    final genSlug = (species['generation']['name'] as String)
        .replaceFirst('generation-', '')
        .toUpperCase();

    return PokemonDetails(
      pokemon: pokemon,
      speciesId: species['id'] as int,
      speciesName: species['name'] as String,
      generation: 'Generación $genSlug',
      genus: _byLang(genera, 'genus', 'es') ??
          _byLang(genera, 'genus', 'en') ??
          '',
      description: _clean(_byLang(flavor, 'flavor_text', 'es') ??
          _byLang(flavor, 'flavor_text', 'en') ??
          ''),
      eggGroups: (species['egg_groups'] as List).map((g) {
        final slug = g['name'] as String;
        return _eggGroupNames[slug] ?? humanize(slug);
      }).toList(),
      genderRate: species['gender_rate'] as int,
      regions: regions,
      evolutions: parseEvolutionChain(chain),
      abilities: abilities,
      effectiveness: effectiveness,
    );
  }
}
