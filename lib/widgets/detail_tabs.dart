import 'package:flutter/material.dart';

import '../models/details.dart';
import '../models/pokemon.dart';
import '../services/sound_service.dart';
import '../theme/app_theme.dart';
import 'evolution_view.dart';
import 'pokedex_ui.dart';

enum DetailTab { data, abilities, evolution, moves }

const Map<DetailTab, String> _tabLabels = {
  DetailTab.data: 'DATOS',
  DetailTab.abilities: 'HABILIDADES',
  DetailTab.evolution: 'EVOLUCIÓN',
  DetailTab.moves: 'MOVIMIENTOS',
};

/// Panel derecho: barra de pestañas + contenido de la pestaña activa.
class DetailTabsPanel extends StatefulWidget {
  final PokemonDetails details;
  final void Function(int id) onSelectPokemon;

  /// true: el contenido hace scroll dentro del panel (diseño ancho).
  /// false: el contenido crece y el scroll lo da la pantalla (diseño estrecho).
  final bool scrollable;

  const DetailTabsPanel({
    super.key,
    required this.details,
    required this.onSelectPokemon,
    required this.scrollable,
  });

  @override
  State<DetailTabsPanel> createState() => _DetailTabsPanelState();
}

class _DetailTabsPanelState extends State<DetailTabsPanel> {
  DetailTab _tab = DetailTab.data;

  void _setTab(DetailTab t) {
    if (t == _tab) return;
    SoundService.instance.playSelect();
    setState(() => _tab = t);
  }

  Widget _content() {
    final details = widget.details;
    return switch (_tab) {
      DetailTab.data => _DataTab(
          details: details,
          onSelectPokemon: widget.onSelectPokemon,
        ),
      DetailTab.abilities => _AbilitiesTab(details: details),
      DetailTab.evolution => InfoCard(
          title: 'Cadena evolutiva',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              EvolutionList(
                details: details,
                onSelect: widget.onSelectPokemon,
              ),
              const SizedBox(height: 8),
              const Text(
                'Toca un Pokémon para abrir su ficha.',
                style: TextStyle(fontSize: 12, color: AppColors.muted),
              ),
            ],
          ),
        ),
      DetailTab.moves => _MovesTab(
          key: ValueKey('moves-${details.pokemon.id}'),
          details: details,
        ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final bar = _TabBar(selected: _tab, onChanged: _setTab);
    if (widget.scrollable) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          bar,
          const SizedBox(height: 12),
          Expanded(child: SingleChildScrollView(child: _content())),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [bar, const SizedBox(height: 12), _content()],
    );
  }
}

class _TabBar extends StatelessWidget {
  final DetailTab selected;
  final ValueChanged<DetailTab> onChanged;
  const _TabBar({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: AppColors.black,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF3A3A3E)),
      ),
      child: Row(
        children: [
          for (final t in DetailTab.values)
            Expanded(
              child: InkWell(
                onTap: () => onChanged(t),
                borderRadius: BorderRadius.circular(8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    color: t == selected ? Colors.white : Colors.transparent,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: 10,
                            horizontal: 4,
                          ),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              _tabLabels[t]!,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: t == selected
                                    ? AppColors.black
                                    : Colors.white,
                              ),
                            ),
                          ),
                        ),
                        Container(
                          height: 3,
                          color: t == selected
                              ? AppColors.red
                              : Colors.transparent,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Pestaña DATOS
// ---------------------------------------------------------------------------

Widget _pill(String text, {IconData? icon}) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: AppColors.black,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 4),
        ],
        Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
        ),
      ],
    ),
  );
}

Widget _dataRow(String label, Widget value) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 96,
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        Expanded(child: value),
      ],
    ),
  );
}

String _pct(double v) =>
    v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

class _DataTab extends StatelessWidget {
  final PokemonDetails details;
  final void Function(int id) onSelectPokemon;
  const _DataTab({required this.details, required this.onSelectPokemon});

  Widget _gender() {
    final rate = details.genderRate;
    if (rate < 0) return const Text('Sin género');
    final female = rate / 8 * 100;
    final male = 100 - female;
    return Wrap(
      spacing: 12,
      children: [
        if (male > 0)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.male, size: 18, color: Color(0xFF1E88E5)),
              Text(' ${_pct(male)}%'),
            ],
          ),
        if (female > 0)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.female, size: 18, color: Color(0xFFD81B60)),
              Text(' ${_pct(female)}%'),
            ],
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = details.pokemon;

    final left = <Widget>[
      InfoCard(
        title: 'DATOS',
        child: Column(
          children: [
            _dataRow('Altura', Text('${p.height / 10} m')),
            _dataRow('Peso', Text('${p.weight / 10} kg')),
            _dataRow('Género', _gender()),
            _dataRow(
              'Grupo Huevo',
              Text(details.eggGroups.isEmpty
                  ? '—'
                  : details.eggGroups.join(', ')),
            ),
            _dataRow('Exp. base', Text('${p.baseExperience}')),
            _dataRow(
              'Generación',
              Text(details.generation.replaceFirst('Generación ', '')),
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      InfoCard(
        title: 'DESCRIPCIÓN',
        child: Text(
          details.description.isEmpty
              ? 'Sin descripción disponible.'
              : details.description,
        ),
      ),
      const SizedBox(height: 12),
      InfoCard(
        title: 'REGIONES',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (details.regions.isEmpty)
              const Text('Sin datos de regiones.')
            else
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final r in details.regions) _pill(r, icon: Icons.public),
                ],
              ),
            const SizedBox(height: 6),
            const Text(
              'Según las Pokédex regionales de los juegos.',
              style: TextStyle(fontSize: 11, color: AppColors.muted),
            ),
          ],
        ),
      ),
    ];

    final right = <Widget>[
      InfoCard(
        title: 'EVOLUCIÓN',
        child: EvolutionList(
          details: details,
          onSelect: onSelectPokemon,
          compact: true,
        ),
      ),
      const SizedBox(height: 12),
      InfoCard(
        title: 'Debilidades y Resistencias',
        child: _Effectiveness(data: details.effectiveness),
      ),
    ];

    return LayoutBuilder(
      builder: (context, c) {
        if (c.maxWidth >= 500) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: Column(children: left)),
              const SizedBox(width: 12),
              Expanded(child: Column(children: right)),
            ],
          );
        }
        return Column(children: [...left, const SizedBox(height: 12), ...right]);
      },
    );
  }
}

class _Effectiveness extends StatelessWidget {
  final Map<String, double> data;
  const _Effectiveness({required this.data});

  Widget _group(String title, List<MapEntry<String, double>> entries) {
    if (entries.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.muted,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 8,
            children: [
              for (final e in entries)
                TypeCircle(type: e.key, multiplier: e.value),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final weak = data.entries.where((e) => e.value > 1).toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final resist = data.entries.where((e) => e.value < 1 && e.value > 0).toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    final immune = data.entries.where((e) => e.value == 0).toList();

    if (weak.isEmpty && resist.isEmpty && immune.isEmpty) {
      return const Text('Sin debilidades ni resistencias.');
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _group('Débil contra', weak),
        _group('Resiste', resist),
        _group('Inmune a', immune),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Pestaña HABILIDADES
// ---------------------------------------------------------------------------

class _AbilitiesTab extends StatelessWidget {
  final PokemonDetails details;
  const _AbilitiesTab({required this.details});

  @override
  Widget build(BuildContext context) {
    if (details.abilities.isEmpty) {
      return const InfoCard(
        title: 'HABILIDADES',
        child: Text('Sin datos de habilidades.'),
      );
    }
    return Column(
      children: [
        for (final a in details.abilities) ...[
          InfoCard(
            title: a.isHidden ? '${a.name}  (Habilidad oculta)' : a.name,
            child: Text(
              a.description.isEmpty ? 'Sin descripción.' : a.description,
            ),
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Pestaña MOVIMIENTOS
// ---------------------------------------------------------------------------

/// Juegos (grupos de versiones) hasta la 9.ª generación, en orden cronológico.
const List<String> _versionOrder = [
  'red-blue',
  'yellow',
  'gold-silver',
  'crystal',
  'ruby-sapphire',
  'emerald',
  'firered-leafgreen',
  'diamond-pearl',
  'platinum',
  'heartgold-soulsilver',
  'black-white',
  'black-2-white-2',
  'x-y',
  'omega-ruby-alpha-sapphire',
  'sun-moon',
  'ultra-sun-ultra-moon',
  'lets-go-pikachu-lets-go-eevee',
  'sword-shield',
  'the-isle-of-armor',
  'the-crown-tundra',
  'brilliant-diamond-and-shining-pearl',
  'legends-arceus',
  'scarlet-violet',
  'the-teal-mask',
  'the-indigo-disk',
  'legends-za',
  'mega-dimension',
];

const Map<String, String> _versionNames = {
  'red-blue': 'Rojo / Azul',
  'yellow': 'Amarillo',
  'gold-silver': 'Oro / Plata',
  'crystal': 'Cristal',
  'ruby-sapphire': 'Rubí / Zafiro',
  'emerald': 'Esmeralda',
  'firered-leafgreen': 'Rojo Fuego / Verde Hoja',
  'diamond-pearl': 'Diamante / Perla',
  'platinum': 'Platino',
  'heartgold-soulsilver': 'HeartGold / SoulSilver',
  'black-white': 'Negro / Blanco',
  'black-2-white-2': 'Negro 2 / Blanco 2',
  'x-y': 'X / Y',
  'omega-ruby-alpha-sapphire': 'Rubí Omega / Zafiro Alfa',
  'sun-moon': 'Sol / Luna',
  'ultra-sun-ultra-moon': 'Ultrasol / Ultraluna',
  'lets-go-pikachu-lets-go-eevee': "Let's Go, Pikachu! / Eevee!",
  'sword-shield': 'Espada / Escudo',
  'the-isle-of-armor': 'Espada / Escudo: Isla de la Armadura',
  'the-crown-tundra': 'Espada / Escudo: Nieves de la Corona',
  'brilliant-diamond-and-shining-pearl':
      'Diamante Brillante / Perla Reluciente',
  'legends-arceus': 'Leyendas Pokémon: Arceus',
  'scarlet-violet': 'Escarlata / Púrpura',
  'the-teal-mask': 'Escarlata / Púrpura: La Máscara Turquesa',
  'the-indigo-disk': 'Escarlata / Púrpura: El Disco Índigo',
  'legends-za': 'Leyendas Pokémon: Z-A',
  'mega-dimension': 'Leyendas Pokémon: Z-A: Mega Dimensión',
};

String _methodTitle(String m) => switch (m) {
      'level-up' => 'Por nivel',
      'machine' => 'MT / MO',
      'tutor' => 'Tutor',
      'egg' => 'Movimientos huevo',
      _ => humanize(m),
    };

String _methodBadge(String m) => switch (m) {
      'machine' => 'MT/MO',
      'tutor' => 'Tutor',
      'egg' => 'Huevo',
      _ => humanize(m),
    };

class _MovesTab extends StatefulWidget {
  final PokemonDetails details;
  const _MovesTab({super.key, required this.details});

  @override
  State<_MovesTab> createState() => _MovesTabState();
}

class _MovesTabState extends State<_MovesTab> {
  late final List<String> _groups;
  late String _group;

  @override
  void initState() {
    super.initState();
    final available = widget.details.pokemon.movesByVersion;
    var groups = _versionOrder.where(available.containsKey).toList();
    if (groups.isEmpty) groups = available.keys.toList();
    _groups = groups;
    _group = _groups.contains('scarlet-violet')
        ? 'scarlet-violet'
        : (_groups.contains('sword-shield')
            ? 'sword-shield'
            : (_groups.isNotEmpty ? _groups.last : ''));
  }

  String _groupLabel(String g) => _versionNames[g] ?? humanize(g);

  Widget _moveRow(MoveEntry e, int index) {
    final isLevel = e.method == 'level-up';
    return Container(
      color: index.isEven ? const Color(0xFFF7F7F7) : Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      child: Row(
        children: [
          SizedBox(
            width: 70,
            child: Text(
              isLevel
                  ? (e.level == 0 ? 'Evo.' : 'Nv. ${e.level}')
                  : _methodBadge(e.method),
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 12,
                color: isLevel ? AppColors.red : AppColors.muted,
              ),
            ),
          ),
          Expanded(child: Text(humanize(e.name))),
        ],
      ),
    );
  }

  Widget _section(String method, List<MoveEntry> list) {
    if (method == 'level-up') {
      list.sort((a, b) {
        final byLevel = a.level.compareTo(b.level);
        return byLevel != 0 ? byLevel : a.name.compareTo(b.name);
      });
    } else {
      list.sort((a, b) => a.name.compareTo(b.name));
    }
    return InfoCard(
      title: '${_methodTitle(method)} (${list.length})',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Column(
          children: [
            for (var i = 0; i < list.length; i++) _moveRow(list[i], i),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_groups.isEmpty) {
      return const InfoCard(
        title: 'MOVIMIENTOS',
        child: Text('Sin datos de movimientos.'),
      );
    }

    final entries =
        widget.details.pokemon.movesByVersion[_group] ?? const <MoveEntry>[];
    final byMethod = <String, List<MoveEntry>>{};
    for (final e in entries) {
      byMethod.putIfAbsent(e.method, () => []).add(e);
    }
    const order = ['level-up', 'machine', 'tutor', 'egg'];
    final methods = [
      ...order.where(byMethod.containsKey),
      ...byMethod.keys.where((k) => !order.contains(k)),
    ];

    return Column(
      children: [
        InfoCard(
          title: 'JUEGO',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DropdownButton<String>(
                isExpanded: true,
                value: _group,
                underline: const SizedBox.shrink(),
                items: [
                  for (final g in _groups)
                    DropdownMenuItem(value: g, child: Text(_groupLabel(g))),
                ],
                onChanged: (v) {
                  if (v == null) return;
                  SoundService.instance.playSelect();
                  setState(() => _group = v);
                },
              ),
              const SizedBox(height: 4),
              const Text(
                'Los nombres de los movimientos están en inglés (PokeAPI). '
                '"Evo." = se aprende al evolucionar.',
                style: TextStyle(fontSize: 11, color: AppColors.muted),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (methods.isEmpty)
          const InfoCard(
            title: 'MOVIMIENTOS',
            child: Text('Este Pokémon no aprende movimientos en este juego.'),
          )
        else
          for (final m in methods) ...[
            _section(m, byMethod[m]!),
            const SizedBox(height: 12),
          ],
      ],
    );
  }
}
