import 'package:dio/dio.dart';

import '../models/evolution.dart';
import '../models/pokemon.dart';

/// Paso 2: peticiones de red usando Dio (Future + async/await).
class PokemonService {
  final Dio _dio = Dio(
    BaseOptions(
      baseUrl: 'https://pokeapi.co/api/v2',
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ),
  );

  // Evita repetir las 3 peticiones al volver a seleccionar un Pokémon.
  final Map<int, PokemonDetails> _cache = {};

  /// Lista de los primeros [limit] Pokémon (solo nombre e id).
  Future<List<PokemonListItem>> fetchPokemonList({int limit = 150}) async {
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

  /// Pokémon + regiones (pokemon-species) + evoluciones (evolution-chain).
  Future<PokemonDetails> fetchPokemonDetails(int id) async {
    final cached = _cache[id];
    if (cached != null) return cached;

    try {
      // 1) Datos del Pokémon y de su especie, en paralelo.
      final responses = await Future.wait([
        _dio.get('/pokemon/$id/'),
        _dio.get('/pokemon-species/$id/'),
      ]);
      final pokemon = Pokemon.fromJson(responses[0].data as Map<String, dynamic>);
      final species = responses[1].data as Map<String, dynamic>;

      // 2) La especie trae la URL de su cadena evolutiva.
      final chainUrl = species['evolution_chain']['url'] as String;
      final chainResponse = await _dio.get(chainUrl);

      final details = PokemonDetails.from(
        pokemon: pokemon,
        species: species,
        chain: chainResponse.data as Map<String, dynamic>,
      );
      _cache[id] = details;
      return details;
    } on DioException catch (e) {
      throw Exception('Error de red: ${e.message}');
    }
  }
}
