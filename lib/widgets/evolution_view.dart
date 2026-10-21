import 'package:flutter/material.dart';

import '../models/details.dart';
import '../models/pokemon.dart';
import '../services/pokemon_service.dart';
import '../theme/app_theme.dart';
import 'pokedex_ui.dart';

/// Color de las megaevoluciones (flecha, etiqueta y borde).
const Color _megaColor = Color(0xFFE08A00);

/// Cadena evolutiva con sprites y, debajo, las megaevoluciones de la especie.
/// Tocar un sprite abre la ficha de ese Pokémon (o de esa megaevolución).
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
    final hasMegas = details.megaForms.isNotEmpty;

    final children = <Widget>[];

    if (details.evolutions.isEmpty) {
      if (!hasMegas) {
        return Column(
          children: [
            Center(
              child: _EvoSprite(
                id: details.speciesId,
                name: details.speciesName,
                size: size,
                current: !details.isForm,
                compact: compact,
                onTap: onSelect,
              ),
            ),
            const SizedBox(height: 6),
            const Text('Este Pokémon no evoluciona.'),
          ],
        );
      }
      children.add(const Padding(
        padding: EdgeInsets.only(bottom: 4),
        child: Text(
          'No tiene más evoluciones, pero puede megaevolucionar.',
          style: TextStyle(fontSize: 12, color: AppColors.muted),
        ),
      ));
    }

    for (final step in details.evolutions) {
      children.add(_row(
        fromId: step.fromId,
        fromName: step.from,
        fromCurrent: !details.isForm && step.fromId == details.speciesId,
        toId: step.toId,
        toName: step.to,
        toCurrent: !details.isForm && step.toId == details.speciesId,
        requirement: step.requirement,
        size: size,
      ));
    }

    if (hasMegas) {
      children.add(Padding(
        padding: const EdgeInsets.only(top: 10, bottom: 2),
        child: Row(
          children: const [
            Icon(Icons.auto_awesome, size: 16, color: _megaColor),
            SizedBox(width: 6),
            Text(
              'MEGAEVOLUCIONES',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: _megaColor,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ));
      for (final mega in details.megaForms) {
        children.add(_row(
          fromId: details.speciesId,
          fromName: details.speciesName,
          fromCurrent: false,
          toId: mega.id,
          toName: mega.slug,
          toCurrent: details.isForm && details.pokemon.id == mega.id,
          requirement: mega.requirement,
          size: size,
          mega: true,
        ));
      }
    }

    return Column(children: children);
  }

  Widget _row({
    required int fromId,
    required String fromName,
    required bool fromCurrent,
    required int toId,
    required String toName,
    required bool toCurrent,
    required String requirement,
    required double size,
    bool mega = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          _EvoSprite(
            id: fromId,
            name: fromName,
            size: size,
            current: fromCurrent,
            compact: compact,
            onTap: onSelect,
          ),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  mega ? Icons.auto_awesome : Icons.arrow_forward,
                  size: 18,
                  color: mega ? _megaColor : AppColors.red,
                ),
                const SizedBox(height: 2),
                Text(
                  requirement,
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
            id: toId,
            name: toName,
            size: size,
            current: toCurrent,
            compact: compact,
            onTap: onSelect,
            mega: mega,
          ),
        ],
      ),
    );
  }
}

class _EvoSprite extends StatelessWidget {
  final int id;
  final String name;
  final double size;
  final bool current;
  final bool compact;
  final bool mega;
  final void Function(int id) onTap;

  const _EvoSprite({
    required this.id,
    required this.name,
    required this.size,
    required this.current,
    required this.compact,
    required this.onTap,
    this.mega = false,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = id <= PokemonService.totalPokemon || id >= kFormIdStart;
    final highlight = mega ? _megaColor : AppColors.red;
    return Tooltip(
      message: enabled
          ? 'Ver ${displayName(name)}'
          : '${displayName(name)} (no disponible en esta Pokédex)',
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
                color: current ? highlight : Colors.transparent,
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
                    displayName(name),
                    maxLines: 2,
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
