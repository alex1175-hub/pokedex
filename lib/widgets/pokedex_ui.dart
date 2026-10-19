import 'package:flutter/material.dart';

import '../models/pokemon.dart';
import '../theme/app_theme.dart';
import '../theme/type_style.dart';
import 'pokeball.dart';

/// Tarjeta blanca con título subrayado (como "DATOS" o "DESCRIPCIÓN").
class InfoCard extends StatelessWidget {
  final String title;
  final Widget child;
  const InfoCard({super.key, required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 15,
              color: AppColors.black,
            ),
          ),
          const Divider(height: 16),
          child,
        ],
      ),
    );
  }
}

/// Etiqueta de tipo: píldora de color con icono y nombre.
class TypeBadge extends StatelessWidget {
  final String type;
  const TypeBadge(this.type, {super.key});

  @override
  Widget build(BuildContext context) {
    final s = styleOf(type);
    final fg = onColorFor(s.color);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: s.color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(s.icon, size: 14, color: fg),
          const SizedBox(width: 4),
          Text(
            s.label,
            style: TextStyle(
              color: fg,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

/// Círculo de tipo con su multiplicador de daño (2x, 0.5x, 0x...).
class TypeCircle extends StatelessWidget {
  final String type;
  final double multiplier;
  const TypeCircle({super.key, required this.type, required this.multiplier});

  String get _text =>
      '${multiplier == multiplier.roundToDouble() ? multiplier.toInt() : multiplier}x';

  @override
  Widget build(BuildContext context) {
    final s = styleOf(type);
    final Color valueColor = multiplier > 1
        ? AppColors.red
        : (multiplier == 0 ? AppColors.muted : const Color(0xFF2E7D32));
    return SizedBox(
      width: 58,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: s.color, shape: BoxShape.circle),
            child: Icon(s.icon, size: 22, color: onColorFor(s.color)),
          ),
          const SizedBox(height: 2),
          Text(
            s.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 10, color: AppColors.muted),
          ),
          Text(
            _text,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 12,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
}

/// Sprite pequeño (pixel art) de un Pokémon por su número.
class SpriteImage extends StatelessWidget {
  final int id;
  final double size;
  const SpriteImage({super.key, required this.id, required this.size});

  @override
  Widget build(BuildContext context) {
    return Image.network(
      spriteUrlFor(id),
      width: size,
      height: size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.none,
      errorBuilder: (_, __, ___) => SizedBox(
        width: size,
        height: size,
        child: Center(child: PokeballIcon(size: size * 0.6)),
      ),
    );
  }
}
