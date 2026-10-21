import 'package:flutter/material.dart';

import '../battle/move_pool.dart';
import '../battle/battle_builder.dart';
import '../data/held_items.dart';
import '../models/details.dart';
import '../models/pokemon.dart';
import '../models/team.dart';
import '../services/pokemon_service.dart';
import '../services/sound_service.dart';
import '../services/team_service.dart';
import '../theme/app_theme.dart';
import '../theme/type_style.dart';
import '../widgets/pokeball.dart';
import '../widgets/pokedex_ui.dart';

const Color _fieldColor = Color(0xFFE4E4E4);

/// Editor de equipo: 6 slots por usuario con Pokémon, nivel, habilidad,
/// 4 movimientos y objeto equipado.
class TeamScreen extends StatefulWidget {
  final String username;
  final PokemonService service;
  final Future<List<PokemonListItem>> futureList;

  /// Título del encabezado.
  final String title;

  /// Nivel máximo permitido (100 = sin límite).
  final int maxLevel;

  /// Equipo inicial (solo en modo "elegir equipo", sin guardado propio).
  final List<TeamMember?>? initialSlots;

  /// Si no es null, el editor no guarda en el dispositivo: el botón principal
  /// confirma el equipo y lo entrega por este callback.
  final void Function(List<TeamMember?> slots)? onConfirm;

  const TeamScreen({
    super.key,
    required this.username,
    required this.service,
    required this.futureList,
    this.title = 'EDITOR DE EQUIPO',
    this.maxLevel = 100,
    this.initialSlots,
    this.onConfirm,
  });

  @override
  State<TeamScreen> createState() => _TeamScreenState();
}

class _TeamScreenState extends State<TeamScreen> {
  List<TeamMember?> _slots = List<TeamMember?>.filled(kTeamSize, null);
  List<PokemonListItem> _all = [];
  bool _loading = true;
  bool _dirty = false;
  int _selected = 0;

  PokemonDetails? _details;
  bool _detailsLoading = false;
  String? _detailsError;

  @override
  void initState() {
    super.initState();
    widget.futureList.then((list) {
      if (mounted) setState(() => _all = list);
    }).catchError((_) {});
    _loadTeam();
  }

  Future<void> _loadTeam() async {
    final List<TeamMember?> slots;
    if (widget.onConfirm != null) {
      final initial = widget.initialSlots;
      slots = List<TeamMember?>.generate(
        kTeamSize,
        (i) => initial != null && i < initial.length ? initial[i] : null,
      );
      for (final m in slots) {
        if (m != null && m.level > widget.maxLevel) m.level = widget.maxLevel;
      }
    } else {
      slots = await TeamService.load(widget.username);
    }
    if (!mounted) return;
    setState(() {
      _slots = slots;
      _loading = false;
      // Empieza en el primer slot con Pokémon.
      final first = slots.indexWhere((m) => m != null);
      _selected = first < 0 ? 0 : first;
    });
    _loadDetails();
  }

  // ---------- Datos del Pokémon del slot ----------
  Future<void> _loadDetails() async {
    final index = _selected;
    final member = _slots[index];
    if (member == null) {
      setState(() {
        _details = null;
        _detailsLoading = false;
        _detailsError = null;
      });
      return;
    }
    setState(() {
      _details = null;
      _detailsLoading = true;
      _detailsError = null;
    });
    try {
      final d = await widget.service.fetchPokemonDetails(member.pokemonId);
      if (!mounted ||
          _selected != index ||
          _slots[index]?.pokemonId != member.pokemonId) {
        return;
      }
      setState(() {
        _details = d;
        _detailsLoading = false;
        final names = d.abilities.map((a) => a.name).toList();
        if (member.ability == null || !names.contains(member.ability)) {
          final visible = d.abilities.where((a) => !a.isHidden).toList();
          member.ability = visible.isNotEmpty
              ? visible.first.name
              : (names.isNotEmpty ? names.first : null);
        }
        _pruneMoves(member);
      });
    } catch (e) {
      if (!mounted || _selected != index) return;
      setState(() {
        _detailsLoading = false;
        _detailsError = '$e';
      });
    }
  }

  /// Movimientos que puede llevar [m] a su nivel actual.
  List<String> _availableMoves(TeamMember m) {
    final d = _details;
    if (d == null) return const [];
    return learnableMoves(d.pokemon, m.level);
  }

  void _pruneMoves(TeamMember m) {
    final available = _availableMoves(m).toSet();
    for (var i = 0; i < m.moves.length; i++) {
      final mv = m.moves[i];
      if (mv != null && !available.contains(mv)) m.moves[i] = null;
    }
  }

  // ---------- Acciones ----------
  void _selectSlot(int i) {
    if (i == _selected) return;
    SoundService.instance.playSelect();
    setState(() => _selected = i);
    _loadDetails();
  }

  void _pick(PokemonListItem item) {
    final current = _slots[_selected];
    if (current != null && current.pokemonId == item.id) return;
    SoundService.instance.playSelect();
    setState(() {
      _slots[_selected] = TeamMember(
        pokemonId: item.id,
        name: item.name,
        level: widget.maxLevel < 50 ? widget.maxLevel : 50,
      );
      _dirty = true;
    });
    _loadDetails();
  }

  void _setLevel(TeamMember m, int level) {
    setState(() {
      m.level = level.clamp(1, widget.maxLevel).toInt();
      _pruneMoves(m);
      _dirty = true;
    });
  }

  void _clearSlot() {
    SoundService.instance.playSelect();
    setState(() {
      _slots[_selected] = null;
      _details = null;
      _detailsError = null;
      _detailsLoading = false;
      _dirty = true;
    });
  }

  Future<void> _saveTeam() async {
    SoundService.instance.playSelect();
    if (widget.onConfirm != null) {
      widget.onConfirm!(_slots);
      return;
    }
    await TeamService.save(widget.username, _slots);
    if (!mounted) return;
    setState(() => _dirty = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Equipo guardado.')),
    );
  }

  // ---------- Interfaz ----------
  @override
  Widget build(BuildContext context) {
    final filled = _slots.where((m) => m != null).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Flexible(
                child: Text(
                  widget.title,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
                ),
              ),
              const Spacer(),
              Text(
                '${widget.username} · $filled/$kTeamSize',
                style: const TextStyle(
                  color: AppColors.muted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: _loading
              ? Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Center(child: PokeballLoader(size: 64)),
                )
              : LayoutBuilder(
                  builder: (context, c) {
                    if (c.maxWidth >= 760) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SizedBox(width: 270, child: _slotList(false)),
                          const SizedBox(width: 12),
                          Expanded(child: _editorPanel()),
                        ],
                      );
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(height: 76, child: _slotList(true)),
                        const SizedBox(height: 12),
                        Expanded(child: _editorPanel()),
                      ],
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _slotList(bool horizontal) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(14),
      ),
      child: ListView.separated(
        scrollDirection: horizontal ? Axis.horizontal : Axis.vertical,
        padding: const EdgeInsets.all(8),
        itemCount: kTeamSize,
        separatorBuilder: (_, __) => const SizedBox(width: 8, height: 8),
        itemBuilder: (context, i) {
          final tile = _SlotTile(
            member: _slots[i],
            selected: i == _selected,
            onTap: () => _selectSlot(i),
          );
          return horizontal
              ? SizedBox(width: 170, child: tile)
              : SizedBox(height: 72, child: tile);
        },
      ),
    );
  }

  Widget _editorPanel() {
    final m = _slots[_selected];
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              m == null ? 'Añadir Pokémon (slot ${_selected + 1})' : 'Editar Pokémon',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            ),
            const SizedBox(height: 10),
            _topRow(m),
            if (m != null) ..._memberSections(m),
            const SizedBox(height: 16),
            _actions(m),
          ],
        ),
      ),
    );
  }

  Widget _topRow(TeamMember? m) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Column(
            children: [
              Text(
                m == null ? '#---' : '#${m.pokemonId.toString().padLeft(3, '0')}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              m == null
                  ? const PokeballIcon(size: 72)
                  : _artwork(m.pokemonId),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            children: [
              _labeled('Busca:', _searchField(m)),
              if (m != null) ...[
                _labeled('Nivel:', _levelRow(m)),
                _labeled('Habilidad:', _abilityField(m)),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _artwork(int id) {
    final url = _details != null && _details!.pokemon.id == id
        ? _details!.pokemon.artworkUrl
        : '';
    if (url.isEmpty) return SpriteImage(id: id, size: 96);
    return Image.network(
      url,
      width: 96,
      height: 96,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => SpriteImage(id: id, size: 96),
    );
  }

  Widget _labeled(String label, Widget child) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          SizedBox(
            width: 78,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }

  Widget _searchField(TeamMember? m) {
    return Autocomplete<PokemonListItem>(
      key: ValueKey('search-$_selected-${m?.pokemonId}'),
      initialValue:
          TextEditingValue(text: m == null ? '' : humanize(m.name)),
      displayStringForOption: (o) => humanize(o.name),
      optionsBuilder: (value) {
        final q = value.text.trim().toLowerCase().replaceAll('#', '');
        if (q.isEmpty) return const Iterable<PokemonListItem>.empty();
        return _all
            .where((p) =>
                humanize(p.name).toLowerCase().contains(q) ||
                p.id.toString().padLeft(3, '0').contains(q))
            .take(8);
      },
      onSelected: _pick,
      fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
        return TextField(
          controller: controller,
          focusNode: focusNode,
          style: const TextStyle(fontSize: 14),
          decoration: InputDecoration(
            hintText: _all.isEmpty ? 'Cargando lista...' : 'Nombre o número',
            isDense: true,
            filled: true,
            fillColor: _fieldColor,
            suffixIcon: const Icon(Icons.search),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: BorderSide.none,
            ),
          ),
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(12),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 280, maxWidth: 300),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (context, i) {
                  final o = options.elementAt(i);
                  return ListTile(
                    dense: true,
                    leading: SpriteImage(id: o.id, size: 36),
                    title: Text(humanize(o.name)),
                    trailing: Text(
                      '#${o.id.toString().padLeft(3, '0')}',
                      style: const TextStyle(color: AppColors.muted),
                    ),
                    onTap: () => onSelected(o),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _levelRow(TeamMember m) {
    return Row(
      children: [
        Container(
          width: 46,
          padding: const EdgeInsets.symmetric(vertical: 6),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: _fieldColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '${m.level}',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
        Expanded(
          child: Slider(
            min: 1,
            max: widget.maxLevel.toDouble(),
            divisions: widget.maxLevel > 1 ? widget.maxLevel - 1 : null,
            value: m.level.toDouble(),
            activeColor: AppColors.red,
            label: '${m.level}',
            onChanged: (v) => _setLevel(m, v.round()),
          ),
        ),
      ],
    );
  }

  Widget _abilityField(TeamMember m) {
    final d = _details;
    if (d == null) return _placeholderBox();
    final names = d.abilities.map((a) => a.name).toList();
    return _dropdownBox<String>(
      value: names.contains(m.ability) ? m.ability : null,
      hint: 'Elegir habilidad',
      items: [
        for (final a in d.abilities)
          DropdownMenuItem(
            value: a.name,
            child: Text(
              a.isHidden ? '${a.name} (oculta)' : a.name,
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
      onChanged: (v) => setState(() {
        m.ability = v;
        _dirty = true;
      }),
    );
  }

  Widget _placeholderBox() {
    return Container(
      height: 40,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: _fieldColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        _detailsLoading ? 'Cargando...' : '—',
        style: const TextStyle(color: AppColors.muted),
      ),
    );
  }

  List<Widget> _memberSections(TeamMember m) {
    if (_detailsError != null) {
      return [
        const SizedBox(height: 8),
        Text(_detailsError!, style: const TextStyle(color: AppColors.red)),
        TextButton(onPressed: _loadDetails, child: const Text('Reintentar')),
      ];
    }
    final ability = _details == null
        ? null
        : _details!.abilities
            .where((a) => a.name == m.ability)
            .map((a) => a.description)
            .firstOrNull;
    final available = _details == null ? <String>[] : _availableMoves(m);

    return [
      if (ability != null && ability.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(
            ability,
            style: const TextStyle(fontSize: 12, color: AppColors.muted),
          ),
        ),
      const SizedBox(height: 8),
      const Text(
        'MOVIMIENTOS (4 Slots)',
        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
      ),
      const SizedBox(height: 8),
      if (_detailsLoading)
        const Padding(
          padding: EdgeInsets.all(8),
          child: Center(child: PokeballLoader(size: 40)),
        )
      else
        LayoutBuilder(
          builder: (context, c) {
            final cols = c.maxWidth >= 420 ? 2 : 1;
            const gap = 10.0;
            final w = (c.maxWidth - gap * (cols - 1)) / cols;
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                for (var i = 0; i < kMoveSlots; i++)
                  SizedBox(width: w, child: _moveField(m, i, available)),
              ],
            );
          },
        ),
      const SizedBox(height: 6),
      const Text(
        'Selecciona de la lista de movimientos disponibles para el nivel '
        '(nombres en inglés, PokeAPI).',
        style: TextStyle(fontSize: 11, color: AppColors.muted),
      ),
      const SizedBox(height: 16),
      const Text(
        'OBJETO EQUIPADO',
        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
      ),
      const SizedBox(height: 8),
      SizedBox(
        width: 320,
        child: Builder(builder: (context) {
          final available = itemsFor(m.pokemonId);
          // Objetos agrupados por categoría, con cabeceras no seleccionables.
          final menu = <DropdownMenuItem<String>>[];
          for (final cat in kCategoryOrder) {
            final group =
                available.where((it) => categoryOf(it) == cat).toList();
            if (group.isEmpty) continue;
            menu.add(DropdownMenuItem<String>(
              value: '#header-$cat',
              enabled: false,
              child: Text(
                cat.toUpperCase(),
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: AppColors.red,
                ),
              ),
            ));
            for (final it in group) {
              menu.add(DropdownMenuItem<String>(
                value: it.key,
                child: Text(it.name, overflow: TextOverflow.ellipsis),
              ));
            }
          }
          return _dropdownBox<String>(
            value: available.any((it) => it.key == m.itemKey)
                ? m.itemKey
                : null,
            hint: 'Sin objeto',
            items: menu,
            onChanged: (v) => setState(() {
              m.itemKey = v;
              _dirty = true;
            }),
            onClear: () => setState(() {
              m.itemKey = null;
              _dirty = true;
            }),
          );
        }),
      ),
      Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(
          heldItemByKey(m.itemKey)?.description ?? 'Sin objeto equipado.',
          style: const TextStyle(fontSize: 11, color: AppColors.muted),
        ),
      ),
      const SizedBox(height: 16),
      const Text(
        'TERACRISTAL',
        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
      ),
      const SizedBox(height: 8),
      SizedBox(
        width: 320,
        child: _dropdownBox<String>(
          value: m.teraType,
          hint: _details == null
              ? 'Tipo original'
              : 'Tipo original (${styleOf(_details!.pokemon.types.first).label})',
          items: [
            for (final e in kTypeStyles.entries)
              DropdownMenuItem(
                value: e.key,
                child: Text(e.value.label, overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: (v) => setState(() {
            m.teraType = v;
            _dirty = true;
          }),
          onClear: () => setState(() {
            m.teraType = null;
            _dirty = true;
          }),
        ),
      ),
      Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(
          'En combate puede teracristalizarse una vez (cambia su tipo al '
          'Teratipo). Cualquier Pokémon puede usar Dinamax'
          '${kGmaxSpecies.containsKey(m.pokemonId) ? ' y este además tiene forma Gigamax' : ''}.',
          style: const TextStyle(fontSize: 11, color: AppColors.muted),
        ),
      ),
    ];
  }

  Widget _moveField(TeamMember m, int index, List<String> available) {
    final others = {
      for (var j = 0; j < m.moves.length; j++)
        if (j != index && m.moves[j] != null) m.moves[j]!,
    };
    final options = available.where((e) => !others.contains(e)).toList();
    final current = m.moves[index];
    return _dropdownBox<String>(
      value: current != null && options.contains(current) ? current : null,
      hint: 'Movimiento ${index + 1}',
      items: [
        for (final name in options)
          DropdownMenuItem(
            value: name,
            child: Text(humanize(name), overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: (v) => setState(() {
        m.moves[index] = v;
        _dirty = true;
      }),
      onClear: () => setState(() {
        m.moves[index] = null;
        _dirty = true;
      }),
    );
  }

  Widget _dropdownBox<T>({
    required T? value,
    required String hint,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
    VoidCallback? onClear,
  }) {
    return Container(
      padding: const EdgeInsets.only(left: 12, right: 6),
      decoration: BoxDecoration(
        color: _fieldColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<T>(
                isExpanded: true,
                value: value,
                hint: Text(
                  hint,
                  style: const TextStyle(color: AppColors.muted, fontSize: 14),
                ),
                items: items,
                onChanged: onChanged,
                menuMaxHeight: 320,
                borderRadius: BorderRadius.circular(12),
                style: const TextStyle(color: AppColors.black, fontSize: 14),
              ),
            ),
          ),
          if (onClear != null && value != null)
            InkWell(
              customBorder: const CircleBorder(),
              onTap: onClear,
              child: const Padding(
                padding: EdgeInsets.all(6),
                child: Icon(Icons.close, color: AppColors.red, size: 20),
              ),
            ),
        ],
      ),
    );
  }

  Widget _actions(TeamMember? m) {
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.red,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          ),
          onPressed: _saveTeam,
          child: Text(
            widget.onConfirm != null ? 'CONFIRMAR EQUIPO' : 'GUARDAR EQUIPO',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.black,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          ),
          onPressed: m == null ? null : _clearSlot,
          child: const Text(
            'BORRAR SLOT',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
        if (_dirty)
          const Text(
            'Cambios sin guardar',
            style: TextStyle(fontSize: 12, color: AppColors.muted),
          ),
      ],
    );
  }
}

class _SlotTile extends StatelessWidget {
  final TeamMember? member;
  final bool selected;
  final VoidCallback onTap;
  const _SlotTile({
    required this.member,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final m = member;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: selected ? Colors.white : const Color(0xFFF7F7F7),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? AppColors.red : Colors.transparent,
              width: 2,
            ),
          ),
          child: Row(
            children: [
              if (m == null)
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: _fieldColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                )
              else
                SpriteImage(id: m.pokemonId, size: 48),
              const SizedBox(width: 8),
              Expanded(
                child: m == null
                    ? const Text(
                        'Vacío',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppColors.muted,
                        ),
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            humanize(m.name),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          Text(
                            'Nv. ${m.level}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.muted,
                            ),
                          ),
                        ],
                      ),
              ),
              if (m != null)
                Text(
                  '#${m.pokemonId.toString().padLeft(3, '0')}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.muted,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
