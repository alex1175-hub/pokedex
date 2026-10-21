import 'dart:math';

import '../data/held_items.dart';
import '../models/battle_move.dart';
import '../models/details.dart';
import '../models/pokemon.dart';
import '../models/team.dart';
import '../services/pokemon_service.dart';
import '../theme/type_style.dart';
import 'battle_engine.dart';
import 'move_pool.dart';

/// Especies con forma Gigamax: número -> (forma, movimiento Gigamax).
const Map<int, List<String>> kGmaxSpecies = {
  3: ['venusaur-gmax', 'g-max-vine-lash'],
  6: ['charizard-gmax', 'g-max-wildfire'],
  9: ['blastoise-gmax', 'g-max-cannonade'],
  12: ['butterfree-gmax', 'g-max-befuddle'],
  25: ['pikachu-gmax', 'g-max-volt-crash'],
  52: ['meowth-gmax', 'g-max-gold-rush'],
  68: ['machamp-gmax', 'g-max-chi-strike'],
  94: ['gengar-gmax', 'g-max-terror'],
  99: ['kingler-gmax', 'g-max-foam-burst'],
  131: ['lapras-gmax', 'g-max-resonance'],
  133: ['eevee-gmax', 'g-max-cuddle'],
  143: ['snorlax-gmax', 'g-max-replenish'],
  569: ['garbodor-gmax', 'g-max-malodor'],
  809: ['melmetal-gmax', 'g-max-meltdown'],
  812: ['rillaboom-gmax', 'g-max-drum-solo'],
  815: ['cinderace-gmax', 'g-max-fireball'],
  818: ['inteleon-gmax', 'g-max-hydrosnipe'],
  823: ['corviknight-gmax', 'g-max-wind-rage'],
  826: ['orbeetle-gmax', 'g-max-gravitas'],
  834: ['drednaw-gmax', 'g-max-stonesurge'],
  839: ['coalossal-gmax', 'g-max-volcalith'],
  841: ['flapple-gmax', 'g-max-tartness'],
  842: ['appletun-gmax', 'g-max-sweetness'],
  844: ['sandaconda-gmax', 'g-max-sandblast'],
  849: ['toxtricity-amped-gmax', 'g-max-stun-shock'],
  851: ['centiskorch-gmax', 'g-max-centiferno'],
  858: ['hatterene-gmax', 'g-max-smite'],
  861: ['grimmsnarl-gmax', 'g-max-snooze'],
  869: ['alcremie-gmax', 'g-max-finale'],
  879: ['copperajah-gmax', 'g-max-steelsurge'],
  884: ['duraludon-gmax', 'g-max-depletion'],
  892: ['urshifu-single-strike-gmax', 'g-max-one-blow'],
};

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

  /// Datos de megaevolución si el Pokémon lleva su megapiedra.
  static Future<MegaData?> _megaFor(
    PokemonService s,
    TeamMember m,
    int level,
  ) async {
    final stone = megaStoneFor(m.itemKey);
    if (stone == null || stone.speciesId != m.pokemonId) return null;
    try {
      final f = await s.fetchFormData(stone.formSlug);
      final st = f.pokemon.stats;
      return MegaData(
        spriteId: f.pokemon.id,
        name: stone.megaName,
        types: f.pokemon.types,
        atk: _stat(st, 'attack', level),
        def: _stat(st, 'defense', level),
        spa: _stat(st, 'special-attack', level),
        spd: _stat(st, 'special-defense', level),
        spe: _stat(st, 'speed', level),
        effectiveness: f.effectiveness,
      );
    } catch (_) {
      return null; // Sin red: el Pokémon combate sin megaevolución.
    }
  }

  /// Forma Gigamax y movimiento Gigamax de la especie (null si no tiene).
  static Future<GmaxData?> _gmaxFor(PokemonService s, int speciesId) async {
    final info = kGmaxSpecies[speciesId];
    if (info == null) return null;
    try {
      final results = await Future.wait<dynamic>([
        s.fetchFormData(info[0]),
        s.fetchMove(info[1]),
      ]);
      final form = results[0] as FormData;
      final move = results[1] as MoveData;
      return GmaxData(
        spriteId: form.pokemon.id,
        moveName: move.name,
        moveType: move.type,
      );
    } catch (_) {
      return null; // Sin red: solo Dinamax normal.
    }
  }

  /// Poder Z del cristal que lleva el Pokémon (si lo puede usar).
  static Future<ZData?> _zFor(PokemonService s, TeamMember m) async {
    final c = zCrystalFor(m.itemKey);
    if (c == null) return null;
    if (c.species.isNotEmpty && !c.species.contains(m.pokemonId)) return null;
    Future<String?> nameOf(String slug) async {
      try {
        return (await s.fetchMove(slug)).name;
      } catch (_) {
        return null;
      }
    }

    if (c.isGeneric) {
      const zSlugs = {
        'normal': 'breakneck-blitz',
        'fire': 'inferno-overdrive',
        'water': 'hydro-vortex',
        'electric': 'gigavolt-havoc',
        'grass': 'bloom-doom',
        'ice': 'subzero-slammer',
        'fighting': 'all-out-pummeling',
        'poison': 'acid-downpour',
        'ground': 'tectonic-rage',
        'flying': 'supersonic-skystrike',
        'psychic': 'shattered-psyche',
        'bug': 'savage-spin-out',
        'rock': 'continental-crush',
        'ghost': 'never-ending-nightmare',
        'dragon': 'devastating-drake',
        'dark': 'black-hole-eclipse',
        'steel': 'corkscrew-crash',
        'fairy': 'twinkle-tackle',
      };
      final base = zSlugs[c.type] ?? 'breakneck-blitz';
      final names = await Future.wait([
        nameOf('$base--physical'),
        nameOf('$base--special'),
      ]);
      final fallback = 'Movimiento Z ${styleOf(c.type!).label}';
      return ZData(
        crystal: c,
        physName: names[0] ?? fallback,
        specName: names[1] ?? fallback,
      );
    }
    final name = await nameOf(c.zSlug!);
    return ZData(
      crystal: c,
      physName: c.zFallbackName,
      specName: c.zFallbackName,
      signatureName: name ?? c.zFallbackName,
    );
  }

  /// [cap] = nivel máximo: los Pokémon con más nivel combaten con ese nivel.
  static Future<List<BattleMon>> buildTeam(
    PokemonService s,
    List<TeamMember> defs,
    int cap,
  ) {
    return Future.wait(defs.map((m) async {
      final d = await s.fetchPokemonDetails(m.pokemonId);
      final maxNames = await s.fetchMaxNames();
      final gmax = await _gmaxFor(s, m.pokemonId);
      final z = await _zFor(s, m);
      final teraType = (m.teraType != null && kTypeStyles.containsKey(m.teraType))
          ? m.teraType!
          : d.pokemon.types.first;
      TeraData? tera;
      try {
        final info = await s.fetchTypeInfo(teraType);
        tera = TeraData(type: teraType, effectiveness: info.damageFrom);
      } catch (_) {
        tera = null;
      }
      final slugs = m.moves.whereType<String>().toList();
      final fetched = await Future.wait(slugs.map((n) => _safeMove(s, n)));
      var moves = fetched.whereType<MoveData>().toList();
      if (moves.isEmpty) moves = [MoveData.tackle];

      final level = min(m.level, cap).clamp(1, 100).toInt();
      final base = d.pokemon.stats;
      return BattleMon(
        baseId: d.pokemon.id,
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
        mega: await _megaFor(s, m, level),
        z: z,
        dyna: DynaData(
          maxNames: maxNames,
          guardName: maxNames['guard'] ?? 'Dinoguardia',
          gmax: gmax,
        ),
        tera: tera,
      );
    }));
  }
}

/// Genera equipos rivales con movimientos y objetos al azar.
class RivalGenerator {
  /// Hasta 4 movimientos al azar (casi siempre con alguno de estado/efecto).
  static Future<List<String?>> randomMoves(
    PokemonService s,
    PokemonDetails d,
    int level,
    Random rng,
  ) async {
    final pool = learnableMoves(d.pokemon, level)..shuffle(rng);
    final candidates = pool.take(18).toList();
    final fetched = await Future.wait(candidates.map((n) async {
      try {
        return await s.fetchMove(n);
      } catch (_) {
        return null;
      }
    }));
    final all = fetched.whereType<MoveData>().toList();
    final damaging = all.where((m) => m.isDamaging).toList()..shuffle(rng);
    final utility = all.where((m) => m.hasUtilityEffect).toList()
      ..shuffle(rng);
    final chosen = damaging.take(kMoveSlots).toList();
    // Casi siempre se incluye un movimiento de estado/efecto si hay alguno.
    if (utility.isNotEmpty && rng.nextDouble() < 0.75) {
      if (chosen.length >= kMoveSlots) {
        chosen[kMoveSlots - 1] = utility.first;
      } else {
        chosen.add(utility.first);
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
    // Cada equipo puede llevar como máximo un Pokémon con megapiedra.
    final picks = <int, String?>{};
    var megaPlaced = false;
    while (picks.length < count) {
      if (!megaPlaced && rng.nextDouble() < 0.3) {
        final stone = kMegaStones[rng.nextInt(kMegaStones.length)];
        if (!picks.containsKey(stone.speciesId)) {
          picks[stone.speciesId] = stone.key;
          megaPlaced = true;
          continue;
        }
      }
      final id = 1 + rng.nextInt(PokemonService.totalPokemon);
      picks.putIfAbsent(id, () => randomItem(rng));
    }
    return Future.wait(picks.entries.map((e) async {
      final d = await s.fetchPokemonDetails(e.key);
      final level = (maxLevel - rng.nextInt(6)).clamp(1, 100).toInt();
      final moves = await randomMoves(s, d, level, rng);
      var item = e.value;
      // A veces el rival lleva un Cristal Z de un tipo que sí ataca.
      if (item == null || !kMegaStones.any((st) => st.key == item)) {
        if (rng.nextDouble() < 0.2) {
          final types = <String>{};
          for (final slug in moves.whereType<String>()) {
            try {
              final mv = await s.fetchMove(slug);
              if (mv.isDamaging) types.add(mv.type);
            } catch (_) {}
          }
          if (types.isNotEmpty) {
            final t = types.elementAt(rng.nextInt(types.length));
            item = kZCrystals.firstWhere((z) => z.type == t).key;
          }
        }
      }
      return TeamMember(
        pokemonId: e.key,
        name: d.pokemon.name,
        level: level,
        moves: moves,
        itemKey: item,
        teraType: rng.nextBool()
            ? d.pokemon.types.first
            : kTypeStyles.keys.elementAt(rng.nextInt(kTypeStyles.length)),
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
