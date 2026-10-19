import 'package:flutter/material.dart';

import '../models/details.dart';
import '../models/pokemon.dart';
import '../services/pokemon_service.dart';
import '../theme/app_theme.dart';
import 'pokedex_ui.dart';

/// Cadena evolutiva con sprites. Tocar un sprite abre la ficha de ese Pokémon.
class EvolutionList extends StatelessWidget {
  final PokemonDetails details;
  final void Function(int id) onSelect;
  final bool compact;

  const EvolutionList({
    super.key,
    required this.details,
    required this.onSelect,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final size = compact ? 52.0 : 72.0;

    if (details.evolutions.isEmpty) {
      return Column(
        children: [
          Center(
            child: _EvoSprite(
              id: details.speciesId,
              name: details.speciesName,
              size: size,
              current: true,
              compact: compact,
              onTap: onSelect,
            ),
          ),
          const SizedBox(height: 6),
          const Text('Este Pokémon no evoluciona.'),
        ],
      );
    }

    return Column(
      children: [
        for (final step in details.evolutions)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                _EvoSprite(
                  id: step.fromId,
                  name: step.from,
                  size: size,
                  current: step.fromId == details.speciesId,
                  compact: compact,
                  onTap: onSelect,
                ),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.arrow_forward,
                        size: 18,
                        color: AppColors.red,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        step.requirement,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: compact ? 11 : 13,
                          color: AppColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                _EvoSprite(
                  id: step.toId,
                  name: step.to,
                  size: size,
                  current: step.toId == details.speciesId,
                  compact: compact,
                  onTap: onSelect,
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _EvoSprite extends StatelessWidget {
  final int id;
  final String name;
  final double size;
  final bool current;
  final bool compact;
  final void Function(int id) onTap;

  const _EvoSprite({
    required this.id,
    required this.name,
    required this.size,
    required this.current,
    required this.compact,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = id <= PokemonService.totalPokemon;
    return Tooltip(
      message: enabled
          ? 'Ver ${humanize(name)}'
          : '${humanize(name)} (generación posterior a la 8.ª)',
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => onTap(id),
        child: Opacity(
          opacity: enabled ? 1 : 0.55,
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: current ? AppColors.red : Colors.transparent,
                width: 2,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SpriteImage(id: id, size: size),
                ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: size + 16),
                  child: Text(
                    humanize(name),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: compact ? 11 : 13,
                      fontWeight: current ? FontWeight.w800 : FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
