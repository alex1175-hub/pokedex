import 'dart:math';

import '../data/held_items.dart';
import '../models/battle_move.dart';
import '../models/details.dart';
import '../models/pokemon.dart';
import '../models/team.dart';
import '../services/pokemon_service.dart';
import 'battle_engine.dart';
import 'move_pool.dart';

int _stat(Map<String, int> base, String key, int level, {bool hp = false}) {
  final b = base[key] ?? 50;
  final core = ((2 * b + 31) * level) ~/ 100;
  return hp ? core + level + 10 : core + 5;
}

/// Convierte los Pokémon del equipo en Pokémon de combate.
class BattleBuilder {
  static Future<MoveData?> _safeMove(PokemonService s, String slug) async {
    try {
      return await s.fetchMove(slug);
    } catch (_) {
      return null;
    }
  }

  /// [cap] = nivel máximo: los Pokémon con más nivel combaten con ese nivel.
  static Future<List<BattleMon>> buildTeam(
    PokemonService s,
    List<TeamMember> defs,
    int cap,
  ) {
    return Future.wait(defs.map((m) async {
      final d = await s.fetchPokemonDetails(m.pokemonId);
      final slugs = m.moves.whereType<String>().toList();
      final fetched = await Future.wait(slugs.map((n) => _safeMove(s, n)));
      var moves = fetched.whereType<MoveData>().toList();
      if (moves.isEmpty) moves = [MoveData.tackle];

      final level = min(m.level, cap).clamp(1, 100).toInt();
      final base = d.pokemon.stats;
      return BattleMon(
        id: d.pokemon.id,
        name: humanize(d.pokemon.name),
        types: d.pokemon.types,
        level: level,
        maxHp: _stat(base, 'hp', level, hp: true),
        atk: _stat(base, 'attack', level),
        def: _stat(base, 'defense', level),
        spa: _stat(base, 'special-attack', level),
        spd: _stat(base, 'special-defense', level),
        spe: _stat(base, 'speed', level),
        moves: moves,
        item: m.itemKey,
        effectiveness: d.effectiveness,
      );
    }));
  }
}

/// Genera equipos rivales con movimientos y objetos al azar.
class RivalGenerator {
  /// Hasta 4 movimientos al azar (casi siempre con alguno de estado) que [d] puede usar a [level].
  static Future<List<String?>> randomMoves(
    PokemonService s,
    PokemonDetails d,
    int level,
    Random rng,
  ) async {
    final pool = learnableMoves(d.pokemon, level)..shuffle(rng);
    final candidates = pool.take(16).toList();
    final fetched = await Future.wait(candidates.map((n) async {
      try {
        return await s.fetchMove(n);
      } catch (_) {
        return null;
      }
    }));
    final all = fetched.whereType<MoveData>().toList();
    final damaging = all.where((m) => m.isDamaging).toList()..shuffle(rng);
    final status = all.where((m) => m.isStatusEffect).toList()..shuffle(rng);
    final chosen = damaging.take(kMoveSlots).toList();
    // Casi siempre se incluye un movimiento de estado si hay alguno.
    if (status.isNotEmpty && rng.nextDouble() < 0.75) {
      if (chosen.length >= kMoveSlots) {
        chosen[kMoveSlots - 1] = status.first;
      } else {
        chosen.add(status.first);
      }
    }
    final result = List<String?>.filled(kMoveSlots, null);
    for (var i = 0; i < chosen.length; i++) {
      result[i] = chosen[i].slug;
    }
    return result;
  }

  static String? randomItem(Random rng) {
    if (rng.nextInt(5) == 0) return null;
    return kHeldItems[rng.nextInt(kHeldItems.length)].key;
  }

  static Future<List<TeamMember>> randomTeam(
    PokemonService s, {
    required int count,
    required int maxLevel,
    required Random rng,
  }) {
    final ids = <int>{};
    while (ids.length < count) {
      ids.add(1 + rng.nextInt(PokemonService.totalPokemon));
    }
    return Future.wait(ids.map((id) async {
      final d = await s.fetchPokemonDetails(id);
      final level = (maxLevel - rng.nextInt(6)).clamp(1, 100).toInt();
      return TeamMember(
        pokemonId: id,
        name: d.pokemon.name,
        level: level,
        moves: await randomMoves(s, d, level, rng),
        itemKey: randomItem(rng),
      );
    }));
  }

  /// Rellena con movimientos al azar a los Pokémon elegidos sin movimientos.
  static Future<void> completeMoves(
    PokemonService s,
    TeamMember m,
    int cap,
    Random rng,
  ) async {
    if (m.moves.any((e) => e != null)) return;
    final d = await s.fetchPokemonDetails(m.pokemonId);
    m.moves = await randomMoves(s, d, min(m.level, cap), rng);
  }
}
