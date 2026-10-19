import 'pokemon.dart';

/// Nombres en español de los objetos de evolución más comunes.
/// Si un objeto no está aquí se muestra su nombre de la API formateado.
const Map<String, String> _itemNames = {
  'thunder-stone': 'Piedra Trueno',
  'fire-stone': 'Piedra Fuego',
  'water-stone': 'Piedra Agua',
  'leaf-stone': 'Piedra Hoja',
  'moon-stone': 'Piedra Lunar',
  'sun-stone': 'Piedra Solar',
  'shiny-stone': 'Piedra Día',
  'dusk-stone': 'Piedra Noche',
  'dawn-stone': 'Piedra Alba',
  'ice-stone': 'Piedra Hielo',
  'oval-stone': 'Piedra Oval',
  'kings-rock': 'Roca del Rey',
  'metal-coat': 'Revestimiento Metálico',
  'dragon-scale': 'Escama Dragón',
  'upgrade': 'Mejora',
  'dubious-disc': 'Disco Extraño',
  'deep-sea-tooth': 'Diente Marino',
  'deep-sea-scale': 'Escama Marina',
  'protector': 'Protector',
  'electirizer': 'Electrizador',
  'magmarizer': 'Magmatizador',
  'reaper-cloth': 'Tela Terrible',
  'razor-claw': 'Garra Afilada',
  'razor-fang': 'Colmillo Agudo',
  'prism-scale': 'Escama Bella',
  'sachet': 'Saquito Fragante',
  'whipped-dream': 'Dulce de Nata',
};

String _itemName(String slug) => _itemNames[slug] ?? humanize(slug);

String? _nameOf(dynamic v) => v == null ? null : (v as Map)['name'] as String;

/// Un paso de la cadena evolutiva: [from] evoluciona a [to] bajo [requirement].
class EvolutionStep {
  final String from;
  final String to;
  final int fromId;
  final int toId;
  final String requirement;

  EvolutionStep({
    required this.from,
    required this.to,
    required this.fromId,
    required this.toId,
    required this.requirement,
  });
}

/// Convierte el JSON de /evolution-chain/{id}/ en una lista plana de pasos.
List<EvolutionStep> parseEvolutionChain(Map<String, dynamic> json) {
  final steps = <EvolutionStep>[];

  void walk(Map<String, dynamic> node) {
    final fromSpecies = node['species'] as Map<String, dynamic>;
    for (final next in node['evolves_to'] as List) {
      final n = next as Map<String, dynamic>;
      final toSpecies = n['species'] as Map<String, dynamic>;
      steps.add(EvolutionStep(
        from: fromSpecies['name'] as String,
        to: toSpecies['name'] as String,
        fromId: idFromUrl(fromSpecies['url'] as String),
        toId: idFromUrl(toSpecies['url'] as String),
        requirement: _describeDetails(n['evolution_details'] as List),
      ));
      walk(n);
    }
  }

  walk(json['chain'] as Map<String, dynamic>);
  return steps;
}

/// Una evolución puede tener varias alternativas (ej. de día o de noche).
String _describeDetails(List details) {
  if (details.isEmpty) return 'Requisito especial';
  return details
      .map((d) => _describeOne(d as Map<String, dynamic>))
      .toSet()
      .join('  o  ');
}

String _describeOne(Map<String, dynamic> d) {
  final trigger = _nameOf(d['trigger']) ?? '';
  final itemSlug = _nameOf(d['item']);

  String base;
  switch (trigger) {
    case 'level-up':
      base = d['min_level'] != null
          ? 'Nivel ${d['min_level']}'
          : 'Subir de nivel';
      break;
    case 'trade':
      base = 'Intercambio';
      break;
    case 'use-item':
      base = itemSlug != null ? 'Usar ${_itemName(itemSlug)}' : 'Usar un objeto';
      break;
    case 'shed':
      base = 'Forma especial: espacio libre en el equipo y una Poké Ball';
      break;
    case 'spin':
      base = 'Forma especial: girar sosteniendo un objeto de sabor';
      break;
    case 'three-critical-hits':
      base = 'Forma especial: realizar 3 golpes críticos en un combate';
      break;
    case 'take-damage':
      base = 'Forma especial: recibir daño y explorar un lugar concreto';
      break;
    case 'agil-move':
      base = 'Forma especial: usar el estilo Ágil de un movimiento varias veces';
      break;
    case 'strong-style-move':
      base = 'Forma especial: usar el estilo Fuerte de un movimiento varias veces';
      break;
    case 'recoil-damage':
      base = 'Forma especial: acumular daño de retroceso';
      break;
    case 'tower-of-two-fists':
      base = 'Forma especial: entrenar en la Torre de los Dos Puños';
      break;
    default:
      base = 'Requisito especial';
  }

  final extras = <String>[];

  final held = _nameOf(d['held_item']);
  if (held != null) extras.add('sosteniendo ${_itemName(held)}');

  final move = _nameOf(d['known_move']);
  if (move != null) extras.add('conociendo ${humanize(move)}');

  final moveType = _nameOf(d['known_move_type']);
  if (moveType != null) {
    extras.add('conociendo un movimiento tipo ${humanize(moveType)}');
  }

  final location = _nameOf(d['location']);
  if (location != null) extras.add('en ${humanize(location)}');

  final time = (d['time_of_day'] ?? '') as String;
  if (time == 'day') extras.add('de día');
  if (time == 'night') extras.add('de noche');
  if (time == 'dusk') extras.add('al atardecer');

  if (d['min_happiness'] != null) {
    extras.add('con amistad ≥ ${d['min_happiness']}');
  }
  if (d['min_affection'] != null) {
    extras.add('con afecto ≥ ${d['min_affection']}');
  }
  if (d['min_beauty'] != null) {
    extras.add('con belleza ≥ ${d['min_beauty']}');
  }

  if (d['gender'] == 1) extras.add('solo hembras');
  if (d['gender'] == 2) extras.add('solo machos');

  if (d['needs_overworld_rain'] == true) extras.add('con lluvia');
  if (d['turn_upside_down'] == true) extras.add('con la consola boca abajo');

  final partySpecies = _nameOf(d['party_species']);
  if (partySpecies != null) {
    extras.add('con ${humanize(partySpecies)} en el equipo');
  }
  final partyType = _nameOf(d['party_type']);
  if (partyType != null) {
    extras.add('con un Pokémon tipo ${humanize(partyType)} en el equipo');
  }

  final tradeSpecies = _nameOf(d['trade_species']);
  if (tradeSpecies != null) extras.add('por ${humanize(tradeSpecies)}');

  final rel = d['relative_physical_stats'];
  if (rel == 1) extras.add('con Ataque > Defensa');
  if (rel == -1) extras.add('con Ataque < Defensa');
  if (rel == 0) extras.add('con Ataque = Defensa');

  return extras.isEmpty ? base : '$base (${extras.join(', ')})';
}
