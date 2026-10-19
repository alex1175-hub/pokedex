import 'package:dio/dio.dart';

import '../models/battle_move.dart';
import '../models/details.dart';
import '../models/pokemon.dart';

/// Paso 2: peticiones de red usando Dio (Future + async/await).
class PokemonService {
  /// Último Pokémon de la 8.ª generación: Enamorus (#905, Leyendas Arceus).
  static const int totalPokemon = 905;

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
  Future<PokemonDetails> fetchPokemonDetails(int id) async {
    final cached = _detailsCache[id];
    if (cached != null) return cached;

    try {
      // 1) Datos del Pokémon y de su especie, en paralelo.
      final responses = await Future.wait([
        _dio.get('/pokemon/$id/'),
        _dio.get('/pokemon-species/$id/'),
      ]);
      final pokemon =
          Pokemon.fromJson(responses[0].data as Map<String, dynamic>);
      final species = responses[1].data as Map<String, dynamic>;

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
}
