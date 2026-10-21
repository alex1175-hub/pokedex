import '../models/pokemon.dart';

/// Juegos preferidos (de más nuevo a más viejo) para saber qué movimientos
/// puede aprender cada Pokémon.
const List<String> _preferredGroups = [
  'scarlet-violet',
  'sword-shield',
  'ultra-sun-ultra-moon',
  'sun-moon',
  'omega-ruby-alpha-sapphire',
  'x-y',
  'black-2-white-2',
  'black-white',
  'heartgold-soulsilver',
  'diamond-pearl',
];

/// Movimientos (nombre de la PokeAPI) que [p] puede llevar a [level].
List<String> learnableMoves(Pokemon p, int level) {
  final byVersion = p.movesByVersion;
  if (byVersion.isEmpty) return <String>[];

  String? group;
  for (final g in _preferredGroups) {
    if (byVersion.containsKey(g)) {
      group = g;
      break;
    }
  }
  group ??= byVersion.entries
      .reduce((a, b) => b.value.length > a.value.length ? b : a)
      .key;

  final names = <String>{};
  for (final e in byVersion[group]!) {
    if (e.method == 'level-up') {
      if (e.level <= level) names.add(e.name);
    } else {
      names.add(e.name);
    }
  }
  return names.toList()..sort();
}
