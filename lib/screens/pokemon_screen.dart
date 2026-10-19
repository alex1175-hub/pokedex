import 'package:flutter/material.dart';

import '../models/details.dart';
import '../models/pokemon.dart';
import '../services/auth_service.dart';
import '../services/pokemon_service.dart';
import '../services/sound_service.dart';
import '../theme/app_theme.dart';
import '../theme/type_style.dart';
import '../widgets/center_card.dart';
import '../widgets/detail_tabs.dart';
import '../widgets/pokeball.dart';
import '../widgets/pokedex_ui.dart';
import 'combat_screen.dart';
import 'team_screen.dart';

/// Secciones de la barra lateral (Pokédex, Regiones, Tipos y Equipo).
enum _Section { pokedex, regions, types, team, combat }

class _Gen {
  final String roman;
  final String region;
  final int from;
  final int to;
  const _Gen(this.roman, this.region, this.from, this.to);
}

/// Generaciones I a VIII con su región y rango de números.
const List<_Gen> _generations = [
  _Gen('I', 'Kanto', 1, 151),
  _Gen('II', 'Johto', 152, 251),
  _Gen('III', 'Hoenn', 252, 386),
  _Gen('IV', 'Sinnoh', 387, 493),
  _Gen('V', 'Teselia', 494, 649),
  _Gen('VI', 'Kalos', 650, 721),
  _Gen('VII', 'Alola', 722, 809),
  _Gen('VIII', 'Galar', 810, 905),
];

final Map<int, String> _generationHeaders = {
  for (final g in _generations)
    g.from: 'GENERACIÓN ${g.roman} · ${g.region.toUpperCase()}',
};

/// Alto fijo de cada fila de la lista (permite saltar a un Pokémon).
const double _rowExtent = 60;

class _ListRow {
  final PokemonListItem? item;
  final String? header;
  const _ListRow.item(this.item) : header = null;
  const _ListRow.header(this.header) : item = null;
}

/// Paso 4: obtener y mostrar los datos con Flutter.
class PokemonScreen extends StatefulWidget {
  const PokemonScreen({super.key});

  @override
  State<PokemonScreen> createState() => _PokemonScreenState();
}

class _PokemonScreenState extends State<PokemonScreen> {
  final PokemonService _service = PokemonService();
  final ScrollController _scroll = ScrollController();
  final TextEditingController _searchCtrl = TextEditingController();

  late Future<List<PokemonListItem>> _futureList;
  List<PokemonListItem> _all = [];

  int? _selectedId;
  Future<PokemonDetails>? _futureDetails;

  _Section _section = _Section.pokedex;
  String _query = '';
  int? _generation; // 1..8
  String? _typeFilter;
  Set<int>? _typeIds;
  bool _typeLoading = false;

  @override
  void initState() {
    super.initState();
    _loadList();
  }

  @override
  void dispose() {
    _scroll.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _loadList() {
    _futureList = _service.fetchPokemonList().then((list) {
      _all = list;
      return list;
    });
  }

  // ---------- Acciones ----------
  void _select(int id) {
    SoundService.instance.playSelect();
    setState(() {
      _selectedId = id;
      _futureDetails = _service.fetchPokemonDetails(id);
    });
  }

  /// Salto desde los iconos de evolución.
  void _goTo(int id) {
    if (id > PokemonService.totalPokemon) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ese Pokémon es de una generación posterior a la 8.ª.'),
        ),
      );
      return;
    }
    final visible = _buildRows(_all).any((r) => r.item?.id == id);
    if (!visible) {
      _searchCtrl.clear();
      setState(() {
        _query = '';
        _generation = null;
        _typeFilter = null;
        _typeIds = null;
        _typeLoading = false;
      });
    }
    _select(id);
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollTo(id));
  }

  void _scrollTo(int id) {
    if (!_scroll.hasClients) return;
    final rows = _buildRows(_all);
    final index = rows.indexWhere((r) => r.item?.id == id);
    if (index < 0) return;
    final position = _scroll.position;
    final target = (index * _rowExtent -
            position.viewportDimension / 2 +
            _rowExtent / 2)
        .clamp(0.0, position.maxScrollExtent)
        .toDouble();
    _scroll.animateTo(
      target,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOut,
    );
  }

  void _setSection(_Section s) {
    SoundService.instance.playSelect();
    setState(() {
      _section = s;
      _generation = null;
      _typeFilter = null;
      _typeIds = null;
      _typeLoading = false;
    });
  }

  void _setGeneration(int g) {
    SoundService.instance.playSelect();
    setState(() => _generation = _generation == g ? null : g);
  }

  Future<void> _setTypeFilter(String type) async {
    SoundService.instance.playSelect();
    if (_typeFilter == type) {
      setState(() {
        _typeFilter = null;
        _typeIds = null;
        _typeLoading = false;
      });
      return;
    }
    setState(() {
      _typeFilter = type;
      _typeIds = null;
      _typeLoading = true;
    });
    try {
      final info = await _service.fetchTypeInfo(type);
      if (!mounted || _typeFilter != type) return;
      setState(() {
        _typeIds = info.pokemonIds;
        _typeLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _typeFilter = null;
        _typeIds = null;
        _typeLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e')),
      );
    }
  }

  // ---------- Datos de la lista ----------
  List<_ListRow> _buildRows(List<PokemonListItem> all) {
    final q = _query.trim().toLowerCase().replaceAll('#', '');
    final filtering =
        q.isNotEmpty || _generation != null || _typeFilter != null;
    final rows = <_ListRow>[];
    for (final item in all) {
      if (_generation != null) {
        final g = _generations[_generation! - 1];
        if (item.id < g.from || item.id > g.to) continue;
      }
      if (_typeIds != null && !_typeIds!.contains(item.id)) continue;
      if (q.isNotEmpty) {
        final name = humanize(item.name).toLowerCase();
        final number = item.id.toString().padLeft(3, '0');
        if (!name.contains(q) && !number.contains(q)) continue;
      }
      if (!filtering) {
        final header = _generationHeaders[item.id];
        if (header != null) rows.add(_ListRow.header(header));
      }
      rows.add(_ListRow.item(item));
    }
    return rows;
  }

  // ---------- Interfaz ----------
  @override
  Widget build(BuildContext context) {
    final visibleCount = _all.isEmpty
        ? 0
        : _buildRows(_all).where((r) => r.item != null).length;

    return Scaffold(
      backgroundColor: AppColors.black,
      appBar: AppBar(
        backgroundColor: AppColors.red,
        foregroundColor: Colors.white,
        centerTitle: true,
        leading: const Padding(
          padding: EdgeInsets.all(10),
          child: PokeballIcon(),
        ),
        title: const Text(
          'POKÉDEX DIGITAL',
          style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 3),
        ),
        actions: [
          if (MediaQuery.sizeOf(context).width >= 600)
            Center(
              child: Text(
                AuthService.instance.currentUser ?? '',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          IconButton(
            tooltip: _section == _Section.team ? 'Ver Pokédex' : 'Mi equipo',
            icon: Icon(
              _section == _Section.team ? Icons.grid_view : Icons.groups,
            ),
            onPressed: () => _setSection(
              _section == _Section.team ? _Section.pokedex : _Section.team,
            ),
          ),
          IconButton(
            tooltip: _section == _Section.combat ? 'Ver Pokédex' : 'Combate',
            icon: Icon(
              _section == _Section.combat ? Icons.grid_view : Icons.flash_on,
            ),
            onPressed: () => _setSection(
              _section == _Section.combat ? _Section.pokedex : _Section.combat,
            ),
          ),
          IconButton(
            tooltip: 'Cerrar sesión',
            icon: const Icon(Icons.logout),
            onPressed: () => AuthService.instance.logout(),
          ),
          const SizedBox(width: 4),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(4),
          child: SizedBox(
            height: 4,
            width: double.infinity,
            child: ColoredBox(color: AppColors.black),
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final w = constraints.maxWidth;
                final showRail = w >= 760;
                final listWidth = w >= 1000 ? 270.0 : (w >= 700 ? 230.0 : 170.0);
                return Stack(
                  children: [
                    const Positioned.fill(child: _SplitBackground()),
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (showRail) ...[
                            _Rail(section: _section, onChanged: _setSection),
                            const SizedBox(width: 12),
                          ],
                          if (_section == _Section.team)
                            Expanded(
                              child: TeamScreen(
                                key: ValueKey(AuthService.instance.currentUser),
                                username:
                                    AuthService.instance.currentUser ?? '',
                                service: _service,
                                futureList: _futureList,
                              ),
                            )
                          else if (_section == _Section.combat)
                            Expanded(
                              child: CombatScreen(
                                key: ValueKey(AuthService.instance.currentUser),
                                username:
                                    AuthService.instance.currentUser ?? '',
                                service: _service,
                                futureList: _futureList,
                              ),
                            )
                          else ...[
                            SizedBox(
                                width: listWidth, child: _buildListPanel()),
                            const SizedBox(width: 12),
                            Expanded(child: _buildDetail()),
                          ],
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          _buildFooter(visibleCount),
        ],
      ),
    );
  }

  Widget _buildFooter(int visibleCount) {
    const style = TextStyle(color: Colors.white70, fontSize: 12);
    final leftText = _section == _Section.team
        ? 'Equipo de ${AuthService.instance.currentUser ?? ''}'
        : (_section == _Section.combat
            ? 'Combate · ${AuthService.instance.currentUser ?? ''}'
            : 'Mostrando $visibleCount de ${PokemonService.totalPokemon} Pokémon');
    return Container(
      height: 34,
      color: AppColors.black,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Flexible(
            child: Text(
              leftText,
              style: style,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const Spacer(),
          const Flexible(
            child: Text(
              'Datos: PokeAPI · Generaciones I–VIII',
              style: style,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _panel(Widget child) {
    return Container(
      width: double.infinity,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: child,
    );
  }

  Widget _errorView(String message, VoidCallback onRetry) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 44, color: AppColors.red),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.red,
                foregroundColor: Colors.white,
              ),
              onPressed: onRetry,
              child: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }

  // ---------- Panel de la lista ----------
  Widget _buildListPanel() {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Material(
        color: Colors.transparent,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
              child: TextField(
                controller: _searchCtrl,
                onChanged: (v) => setState(() => _query = v),
                style: const TextStyle(fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Buscar nombre o número',
                  hintStyle: const TextStyle(fontSize: 13),
                  isDense: true,
                  filled: true,
                  fillColor: const Color(0xFFE4E4E4),
                  suffixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            _buildFilters(),
            Expanded(child: _buildList()),
          ],
        ),
      ),
    );
  }

  Widget _buildFilters() {
    List<Widget> pills;
    if (_section == _Section.regions) {
      pills = [
        for (var i = 0; i < _generations.length; i++)
          _FilterPill(
            label: '${_generations[i].region} ${_generations[i].roman}',
            color: AppColors.red,
            selected: _generation == i + 1,
            onTap: () => _setGeneration(i + 1),
          ),
      ];
    } else if (_section == _Section.types) {
      pills = [
        for (final t in kTypeStyles.keys)
          _FilterPill(
            label: styleOf(t).label,
            color: styleOf(t).color,
            selected: _typeFilter == t,
            onTap: () => _setTypeFilter(t),
          ),
      ];
    } else {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 120),
        child: SingleChildScrollView(
          child: Wrap(spacing: 6, runSpacing: 6, children: pills),
        ),
      ),
    );
  }

  Widget _buildList() {
    return FutureBuilder<List<PokemonListItem>>(
      future: _futureList,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting ||
            _typeLoading) {
          return const Center(child: PokeballLoader());
        }
        if (snapshot.hasError) {
          return _errorView('${snapshot.error}', () {
            SoundService.instance.playSelect();
            setState(_loadList);
          });
        }
        final rows = _buildRows(snapshot.data!);
        if (rows.isEmpty) {
          return const Center(child: Text('Sin resultados'));
        }
        return ListView.builder(
          controller: _scroll,
          itemExtent: _rowExtent,
          itemCount: rows.length,
          itemBuilder: (context, index) {
            final row = rows[index];
            if (row.header != null) return _GenerationHeader(row.header!);
            return _tile(row.item!);
          },
        );
      },
    );
  }

  Widget _tile(PokemonListItem item) {
    final selected = item.id == _selectedId;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => _select(item.id),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          decoration: BoxDecoration(
            color: selected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? AppColors.red : Colors.transparent,
              width: 2,
            ),
          ),
          child: Row(
            children: [
              SpriteImage(id: item.id, size: 44),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '#${item.id.toString().padLeft(3, '0')}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.muted,
                      ),
                    ),
                    Text(
                      humanize(item.name).toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------- Panel de detalle ----------
  Widget _buildDetail() {
    if (_futureDetails == null) {
      return _panel(
        const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            PokeballIcon(size: 96),
            SizedBox(height: 16),
            Text(
              'Selecciona un Pokémon de la lista',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      );
    }

    // Al cambiar de Pokémon el contenido anterior se desvanece y el nuevo
    // entra deslizándose.
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 350),
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.05, 0),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        );
      },
      child: FutureBuilder<PokemonDetails>(
        key: ValueKey(_selectedId),
        future: _futureDetails,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _panel(const PokeballLoader(size: 72));
          }
          if (snapshot.hasError) {
            return _panel(
              _errorView('${snapshot.error}', () => _select(_selectedId!)),
            );
          }
          return _DetailView(
            key: ValueKey('detail-${snapshot.data!.pokemon.id}'),
            details: snapshot.data!,
            onSelectPokemon: _goTo,
          );
        },
      ),
    );
  }
}

/// Fondo de la ventana: mitad roja, línea clara y mitad negra (como una Pokéball).
class _SplitBackground extends StatelessWidget {
  const _SplitBackground();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Expanded(flex: 60, child: ColoredBox(color: AppColors.red)),
        Container(height: 6, color: AppColors.white),
        const Expanded(flex: 40, child: ColoredBox(color: AppColors.black)),
      ],
    );
  }
}

/// Barra lateral: Pokédex, Regiones, Tipos y Equipo.
class _Rail extends StatelessWidget {
  final _Section section;
  final ValueChanged<_Section> onChanged;
  const _Rail({required this.section, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 84,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
      decoration: BoxDecoration(
        color: AppColors.black,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF3A3A3E)),
      ),
      child: Column(
        children: [
          _RailItem(
            label: 'POKÉDEX',
            selected: section == _Section.pokedex,
            iconBuilder: (selected) => const PokeballIcon(size: 30),
            onTap: () => onChanged(_Section.pokedex),
          ),
          const SizedBox(height: 6),
          _RailItem(
            label: 'REGIONES',
            selected: section == _Section.regions,
            iconBuilder: (selected) => Icon(
              Icons.map_outlined,
              size: 30,
              color: selected ? AppColors.red : Colors.white,
            ),
            onTap: () => onChanged(_Section.regions),
          ),
          const SizedBox(height: 6),
          _RailItem(
            label: 'TIPOS',
            selected: section == _Section.types,
            iconBuilder: (selected) => Icon(
              Icons.local_fire_department_outlined,
              size: 30,
              color: selected ? AppColors.red : Colors.white,
            ),
            onTap: () => onChanged(_Section.types),
          ),
          const SizedBox(height: 6),
          _RailItem(
            label: 'EQUIPO',
            selected: section == _Section.team,
            iconBuilder: (selected) => Icon(
              Icons.groups_outlined,
              size: 30,
              color: selected ? AppColors.red : Colors.white,
            ),
            onTap: () => onChanged(_Section.team),
          ),
          const SizedBox(height: 6),
          _RailItem(
            label: 'COMBATE',
            selected: section == _Section.combat,
            iconBuilder: (selected) => Icon(
              Icons.flash_on_outlined,
              size: 30,
              color: selected ? AppColors.red : Colors.white,
            ),
            onTap: () => onChanged(_Section.combat),
          ),
        ],
      ),
    );
  }
}

class _RailItem extends StatelessWidget {
  final String label;
  final bool selected;
  final Widget Function(bool selected) iconBuilder;
  final VoidCallback onTap;

  const _RailItem({
    required this.label,
    required this.selected,
    required this.iconBuilder,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            iconBuilder(selected),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w800,
                color: selected ? AppColors.black : Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterPill extends StatelessWidget {
  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _FilterPill({
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? color : Colors.white,
      shape: StadiumBorder(side: BorderSide(color: color, width: 1.5)),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: selected ? onColorFor(color) : AppColors.black,
            ),
          ),
        ),
      ),
    );
  }
}

class _GenerationHeader extends StatelessWidget {
  final String label;
  const _GenerationHeader(this.label);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        height: 30,
        width: double.infinity,
        margin: const EdgeInsets.symmetric(horizontal: 8),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        alignment: Alignment.centerLeft,
        decoration: BoxDecoration(
          color: AppColors.black,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
        ),
      ),
    );
  }
}

/// Ficha: tarjeta central + pestañas. En pantallas anchas van lado a lado;
/// en pantallas estrechas, una debajo de la otra.
class _DetailView extends StatefulWidget {
  final PokemonDetails details;
  final void Function(int id) onSelectPokemon;
  const _DetailView({
    super.key,
    required this.details,
    required this.onSelectPokemon,
  });

  @override
  State<_DetailView> createState() => _DetailViewState();
}

class _DetailViewState extends State<_DetailView> {
  @override
  void initState() {
    super.initState();
    // Sonido de escaneo, un instante después del pitido de selección.
    Future.delayed(const Duration(milliseconds: 160), () {
      if (mounted) SoundService.instance.playScan();
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final center = PokemonCenterCard(details: widget.details);
        if (c.maxWidth >= 820) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: 340,
                child: SingleChildScrollView(child: center),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DetailTabsPanel(
                  details: widget.details,
                  onSelectPokemon: widget.onSelectPokemon,
                  scrollable: true,
                ),
              ),
            ],
          );
        }
        return SingleChildScrollView(
          child: Column(
            children: [
              center,
              const SizedBox(height: 12),
              DetailTabsPanel(
                details: widget.details,
                onSelectPokemon: widget.onSelectPokemon,
                scrollable: false,
              ),
            ],
          ),
        );
      },
    );
  }
}
