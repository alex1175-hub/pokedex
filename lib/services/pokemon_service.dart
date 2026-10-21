import 'package:dio/dio.dart';

import '../models/battle_move.dart';
import '../models/details.dart';
import '../models/pokemon.dart';

/// Datos de una forma alternativa (ej. megaevolución).
class FormData {
  final Pokemon pokemon;

  /// Multiplicador de daño recibido por tipo atacante (ya combinado).
  final Map<String, double> effectiveness;
  FormData(this.pokemon, this.effectiveness);
}

/// Paso 2: peticiones de red usando Dio (Future + async/await).
class PokemonService {
  /// Último Pokémon de la 9.ª generación: Pecharunt (#1025).
  static const int totalPokemon = 1025;

  final Dio _dio = Dio(
    BaseOptions(
      baseUrl: 'https://pokeapi.co/api/v2',
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ),
  );

  // Evita repetir peticiones al volver a seleccionar un Pokémon o un tipo.
  final Map<int, PokemonDetails> _detailsCache = {};
  final Map<String, TypeInfo> _typeCache = {};
  final Map<String, MoveData> _moveCache = {};
  final Map<String, FormData> _formCache = {};
  Map<String, String>? _maxNames;

  /// Lista de los primeros [limit] Pokémon (solo nombre e id).
  Future<List<PokemonListItem>> fetchPokemonList({
    int limit = totalPokemon,
  }) async {
    try {
      final response = await _dio.get(
        '/pokemon',
        queryParameters: {'limit': limit, 'offset': 0},
      );
      final results = response.data['results'] as List;
      return results
          .map((e) => PokemonListItem.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw Exception('Error de red: ${e.message}');
    }
  }

  /// Datos básicos de un Pokémon.
  Future<Pokemon> fetchPokemon(int id) async {
    try {
      final response = await _dio.get('/pokemon/$id/');
      // Paso 3: convertir la respuesta en un objeto Pokemon
      return Pokemon.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception('Error de red: ${e.message}');
    }
  }

  /// Un tipo: debilidades/resistencias y los Pokémon que lo tienen.
  Future<TypeInfo> fetchTypeInfo(String type) async {
    final cached = _typeCache[type];
    if (cached != null) return cached;
    try {
      final response = await _dio.get('/type/$type/');
      final info = TypeInfo.fromJson(response.data as Map<String, dynamic>);
      _typeCache[type] = info;
      return info;
    } on DioException catch (e) {
      throw Exception('Error de red: ${e.message}');
    }
  }

  Future<AbilityInfo> _fetchAbility(AbilityRef ref) async {
    final response = await _dio.get('/ability/${ref.name}/');
    return AbilityInfo.fromJson(
      response.data as Map<String, dynamic>,
      ref.isHidden,
    );
  }

  /// Ficha completa: Pokémon + especie + evolución + habilidades + tipos.
  /// [id] puede ser una especie (1..[totalPokemon]) o una forma alternativa
  /// (a partir de [kFormIdStart], p. ej. una megaevolución).
  Future<PokemonDetails> fetchPokemonDetails(int id) async {
    final cached = _detailsCache[id];
    if (cached != null) return cached;

    try {
      // 1) Datos del Pokémon y de su especie.
      final Pokemon pokemon;
      final Map<String, dynamic> species;
      if (id < kFormIdStart) {
        final responses = await Future.wait([
          _dio.get('/pokemon/$id/'),
          _dio.get('/pokemon-species/$id/'),
        ]);
        pokemon = Pokemon.fromJson(responses[0].data as Map<String, dynamic>);
        species = responses[1].data as Map<String, dynamic>;
      } else {
        // Una forma: su especie se averigua a partir de su propio JSON y los
        // movimientos/grito (que suelen faltar) se toman de la forma base.
        final formJson =
            (await _dio.get('/pokemon/$id/')).data as Map<String, dynamic>;
        final speciesId =
            idFromUrl(formJson['species']['url'] as String);
        final responses = await Future.wait([
          _dio.get('/pokemon-species/$speciesId/'),
          _dio.get('/pokemon/$speciesId/'),
        ]);
        species = responses[0].data as Map<String, dynamic>;
        final base =
            Pokemon.fromJson(responses[1].data as Map<String, dynamic>);
        final form = Pokemon.fromJson(formJson);
        pokemon = form.withBase(
          cryUrl: form.cryUrl ?? base.cryUrl,
          movesByVersion: form.movesByVersion.isEmpty
              ? base.movesByVersion
              : form.movesByVersion,
        );
      }

      // 2) Cadena evolutiva, habilidades y tipos, todo en paralelo.
      final chainUrl = species['evolution_chain']['url'] as String;
      final results = await Future.wait<dynamic>([
        _dio.get(chainUrl),
        Future.wait(pokemon.abilities.map(_fetchAbility)),
        Future.wait(pokemon.types.map(fetchTypeInfo)),
      ]);

      final details = PokemonDetails.from(
        pokemon: pokemon,
        species: species,
        chain: (results[0] as Response).data as Map<String, dynamic>,
        abilities: (results[1] as List).cast<AbilityInfo>(),
        types: (results[2] as List).cast<TypeInfo>(),
      );
      _detailsCache[id] = details;
      return details;
    } on DioException catch (e) {
      throw Exception('Error de red: ${e.message}');
    }
  }

  /// Datos de un movimiento para el combate (nombre en español, poder...).
  Future<MoveData> fetchMove(String slug) async {
    final cached = _moveCache[slug];
    if (cached != null) return cached;
    try {
      final response = await _dio.get('/move/$slug/');
      final move = MoveData.fromJson(response.data as Map<String, dynamic>);
      _moveCache[slug] = move;
      return move;
    } on DioException catch (e) {
      throw Exception('Error de red: ${e.message}');
    }
  }

  /// Estadísticas, tipos y debilidades de una forma por nombre
  /// (ej. "charizard-mega-x").
  Future<FormData> fetchFormData(String slug) async {
    final cached = _formCache[slug];
    if (cached != null) return cached;
    try {
      final response = await _dio.get('/pokemon/$slug/');
      final pokemon =
          Pokemon.fromJson(response.data as Map<String, dynamic>);
      final types = await Future.wait(pokemon.types.map(fetchTypeInfo));
      final effectiveness = <String, double>{};
      for (final t in types) {
        t.damageFrom.forEach((attacker, multiplier) {
          effectiveness[attacker] =
              (effectiveness[attacker] ?? 1.0) * multiplier;
        });
      }
      final data = FormData(pokemon, effectiveness);
      _formCache[slug] = data;
      return data;
    } on DioException catch (e) {
      throw Exception('Error de red: ${e.message}');
    }
  }

  /// Nombres (en español) de los Movimientos Máximos de cada tipo y de
  /// Dinoguardia. Si la red falla se usan nombres genéricos.
  Future<Map<String, String>> fetchMaxNames() async {
    final cached = _maxNames;
    if (cached != null) return cached;
    const slugs = {
      'normal': 'max-strike',
      'fire': 'max-flare',
      'water': 'max-geyser',
      'electric': 'max-lightning',
      'grass': 'max-overgrowth',
      'ice': 'max-hailstorm',
      'fighting': 'max-knuckle',
      'poison': 'max-ooze',
      'ground': 'max-quake',
      'flying': 'max-airstream',
      'psychic': 'max-mindstorm',
      'bug': 'max-flutterby',
      'rock': 'max-rockfall',
      'ghost': 'max-phantasm',
      'dragon': 'max-wyrmwind',
      'dark': 'max-darkness',
      'steel': 'max-steelspike',
      'fairy': 'max-starfall',
      'guard': 'max-guard',
    };
    final names = <String, String>{};
    await Future.wait(slugs.entries.map((e) async {
      try {
        names[e.key] = (await fetchMove(e.value)).name;
      } catch (_) {}
    }));
    // Solo se guarda si llegaron todos (así se reintenta si falló la red).
    if (names.length == slugs.length) _maxNames = names;
    return names;
  }
}
