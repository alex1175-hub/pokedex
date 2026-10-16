import 'package:flutter/material.dart';

import '../models/evolution.dart';
import '../models/pokemon.dart';
import '../services/pokemon_service.dart';

String _capitalize(String s) =>
    s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

/// Paso 4: obtener y mostrar los datos con Flutter.
/// Izquierda: lista de los primeros 150 Pokémon. Derecha: detalle del elegido.
class PokemonScreen extends StatefulWidget {
  const PokemonScreen({super.key});

  @override
  State<PokemonScreen> createState() => _PokemonScreenState();
}

class _PokemonScreenState extends State<PokemonScreen> {
  final PokemonService _service = PokemonService();
  late Future<List<PokemonListItem>> _futureList;

  int? _selectedId;
  Future<PokemonDetails>? _futureDetails;

  @override
  void initState() {
    super.initState();
    _futureList = _service.fetchPokemonList(limit: 150);
  }

  void _select(int id) {
    setState(() {
      _selectedId = id;
      _futureDetails = _service.fetchPokemonDetails(id);
    });
  }

  void _reloadList() {
    setState(() {
      _futureList = _service.fetchPokemonList(limit: 150);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pokédex'),
        centerTitle: true,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final listWidth = constraints.maxWidth < 600 ? 160.0 : 280.0;
          return Row(
            children: [
              SizedBox(width: listWidth, child: _buildList()),
              const VerticalDivider(width: 1),
              Expanded(child: _buildDetail()),
            ],
          );
        },
      ),
    );
  }

  // ---------- Panel izquierdo: lista ----------
  Widget _buildList() {
    return FutureBuilder<List<PokemonListItem>>(
      future: _futureList,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, size: 40, color: Colors.red),
                  const SizedBox(height: 8),
                  Text('${snapshot.error}', textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: _reloadList,
                    child: const Text('Reintentar'),
                  ),
                ],
              ),
            ),
          );
        }
        final items = snapshot.data!;
        return ListView.builder(
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            return ListTile(
              dense: true,
              selected: item.id == _selectedId,
              selectedTileColor:
                  Theme.of(context).colorScheme.primaryContainer,
              leading: Text(
                '#${item.id.toString().padLeft(3, '0')}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              title: Text(_capitalize(item.name)),
              onTap: () => _select(item.id),
            );
          },
        );
      },
    );
  }

  // ---------- Panel derecho: detalle ----------
  Widget _buildDetail() {
    if (_futureDetails == null) {
      return const Center(
        child: Text('Selecciona un Pokémon de la lista'),
      );
    }
    return FutureBuilder<PokemonDetails>(
      future: _futureDetails,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 8),
                  Text('${snapshot.error}', textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () => _select(_selectedId!),
                    child: const Text('Reintentar'),
                  ),
                ],
              ),
            ),
          );
        }
        return _PokemonDetail(details: snapshot.data!);
      },
    );
  }
}

class _PokemonDetail extends StatelessWidget {
  final PokemonDetails details;
  const _PokemonDetail({required this.details});

  Pokemon get pokemon => details.pokemon;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Card(
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Column(
                      children: [
                        if (pokemon.imageUrl.isNotEmpty)
                          Image.network(
                            pokemon.imageUrl,
                            width: 192,
                            height: 192,
                            fit: BoxFit.contain,
                            filterQuality: FilterQuality.none,
                          ),
                        Text(
                          '#${pokemon.id.toString().padLeft(3, '0')} '
                          '${_capitalize(pokemon.name)}',
                          style: textTheme.headlineMedium,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          children: pokemon.types
                              .map((t) => Chip(label: Text(_capitalize(t))))
                              .toList(),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 32),
                  _row('Altura', '${pokemon.height / 10} m'),
                  _row('Peso', '${pokemon.weight / 10} kg'),
                  _row('Exp. base', '${pokemon.baseExperience}'),
                  _row(
                    'Habilidades',
                    pokemon.abilities.map(_capitalize).join(', '),
                  ),
                  const Divider(height: 32),
                  Text('Estadísticas', style: textTheme.titleMedium),
                  const SizedBox(height: 8),
                  ...pokemon.stats.entries.map(
                    (e) => _statBar(e.key, e.value),
                  ),
                  const Divider(height: 32),
                  _regionsSection(context),
                  const Divider(height: 32),
                  _evolutionSection(context),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ---------- Regiones ----------
  Widget _regionsSection(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final grey = textTheme.bodySmall?.copyWith(color: Colors.grey[600]);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Regiones', style: textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(
          'Originario de: ${details.generation}',
          style: textTheme.bodyMedium,
        ),
        const SizedBox(height: 8),
        if (details.regions.isEmpty)
          const Text('Sin datos de regiones.')
        else
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: details.regions
                .map((r) => Chip(
                      avatar: const Icon(Icons.public, size: 16),
                      label: Text(r),
                    ))
                .toList(),
          ),
        const SizedBox(height: 4),
        Text('Según las Pokédex regionales de los juegos.', style: grey),
      ],
    );
  }

  // ---------- Evolución ----------
  Widget _evolutionSection(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Evolución', style: textTheme.titleMedium),
        const SizedBox(height: 8),
        if (details.evolutions.isEmpty)
          const Text('Este Pokémon no evoluciona.')
        else
          ...details.evolutions.map((step) => _evolutionTile(step)),
      ],
    );
  }

  Widget _evolutionTile(EvolutionStep step) {
    // Resalta los pasos en los que participa el Pokémon seleccionado.
    final involved = step.from == pokemon.name || step.to == pokemon.name;
    final weight = involved ? FontWeight.bold : FontWeight.normal;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${_capitalize(step.from)}  →  ${_capitalize(step.to)}',
            style: TextStyle(fontWeight: weight),
          ),
          const SizedBox(height: 2),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(_iconFor(step.requirement), size: 16),
              const SizedBox(width: 6),
              Expanded(child: Text(step.requirement)),
            ],
          ),
        ],
      ),
    );
  }

  IconData _iconFor(String requirement) {
    if (requirement.startsWith('Intercambio')) return Icons.swap_horiz;
    if (requirement.startsWith('Usar')) return Icons.diamond_outlined;
    if (requirement.startsWith('Nivel') ||
        requirement.startsWith('Subir de nivel')) {
      return Icons.trending_up;
    }
    return Icons.auto_awesome;
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(width: 12),
          Flexible(child: Text(value, textAlign: TextAlign.end)),
        ],
      ),
    );
  }

  Widget _statBar(String name, int value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(_capitalize(name), style: const TextStyle(fontSize: 12)),
          ),
          SizedBox(
            width: 32,
            child: Text('$value', textAlign: TextAlign.end),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: LinearProgressIndicator(
              value: (value / 255).clamp(0.0, 1.0),
              minHeight: 8,
            ),
          ),
        ],
      ),
    );
  }
}
