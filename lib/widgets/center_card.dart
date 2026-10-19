import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/details.dart';
import '../models/pokemon.dart';
import '../services/sound_service.dart';
import '../theme/app_theme.dart';
import '../theme/type_style.dart';
import 'pokeball.dart';
import 'pokedex_ui.dart';

/// Tarjeta central: nombre, número, tipos, arte con animación de escaneo
/// (al tocarlo suena el grito) y barras de estadísticas.
class PokemonCenterCard extends StatelessWidget {
  final PokemonDetails details;
  const PokemonCenterCard({super.key, required this.details});

  Pokemon get pokemon => details.pokemon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      humanize(pokemon.name).toUpperCase(),
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: AppColors.black,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      details.genus,
                      style: const TextStyle(color: AppColors.muted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '#${pokemon.id.toString().padLeft(3, '0')}',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: AppColors.muted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [for (final t in pokemon.types) TypeBadge(t)],
          ),
          const SizedBox(height: 10),
          _ScanArtwork(pokemon: pokemon),
          const SizedBox(height: 6),
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.volume_up, size: 14, color: AppColors.muted),
              SizedBox(width: 4),
              Text(
                'Toca al Pokémon para oír su grito',
                style: TextStyle(fontSize: 11, color: AppColors.muted),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (final e in pokemon.stats.entries)
            _StatBar(name: e.key, value: e.value),
        ],
      ),
    );
  }
}

class _StatBar extends StatelessWidget {
  final String name;
  final int value;
  const _StatBar({required this.name, required this.value});

  @override
  Widget build(BuildContext context) {
    final color = kStatColors[name] ?? AppColors.red;
    final target = (value / 160).clamp(0.0, 1.0).toDouble();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 82,
            child: Text(
              kStatLabels[name] ?? humanize(name).toUpperCase(),
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0, end: target),
                duration: const Duration(milliseconds: 700),
                curve: Curves.easeOut,
                builder: (context, v, _) => LinearProgressIndicator(
                  value: v,
                  minHeight: 9,
                  color: color,
                  backgroundColor: AppColors.grey,
                ),
              ),
            ),
          ),
          SizedBox(
            width: 32,
            child: Text(
              '$value',
              textAlign: TextAlign.end,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

/// Arte del Pokémon con animación de escaneo al aparecer:
/// una línea roja baja y el Pokémon se revela. Al tocarlo "salta" y suena
/// su grito.
class _ScanArtwork extends StatefulWidget {
  final Pokemon pokemon;
  const _ScanArtwork({required this.pokemon});

  @override
  State<_ScanArtwork> createState() => _ScanArtworkState();
}

class _ScanArtworkState extends State<_ScanArtwork>
    with TickerProviderStateMixin {
  late final AnimationController _scan;
  late final AnimationController _bounce;
  late final Animation<double> _fade;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _scan = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..forward();
    _bounce = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _fade = CurvedAnimation(
      parent: _scan,
      curve: const Interval(0.3, 1.0, curve: Curves.easeOut),
    );
    _scale = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(
        parent: _scan,
        curve: const Interval(0.3, 1.0, curve: Curves.easeOutBack),
      ),
    );
  }

  @override
  void dispose() {
    _scan.dispose();
    _bounce.dispose();
    super.dispose();
  }

  Future<void> _onTap() async {
    _bounce.forward(from: 0);
    final ok = await SoundService.instance.playCry(widget.pokemon.cryUrl);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo reproducir el grito en esta plataforma.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.pokemon;
    final pixelArt = p.artworkUrl.isEmpty;
    final url = pixelArt ? p.imageUrl : p.artworkUrl;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: _onTap,
        child: Container(
          height: 250,
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.white, AppColors.panel],
            ),
            border: Border.all(color: AppColors.border),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(11),
            child: AnimatedBuilder(
              animation: Listenable.merge([_scan, _bounce]),
              builder: (context, _) {
                final t = _scan.value;
                final lineT = const Interval(
                  0.0,
                  0.75,
                  curve: Curves.easeInOut,
                ).transform(t);
                final bounce = 1 + 0.12 * math.sin(_bounce.value * math.pi);

                return Stack(
                  children: [
                    Positioned.fill(
                      child: Center(
                        child: Opacity(
                          opacity: _fade.value,
                          child: Transform.scale(
                            scale: _scale.value * bounce,
                            child: url.isEmpty
                                ? const PokeballIcon(size: 90)
                                : Image.network(
                                    url,
                                    width: 220,
                                    height: 220,
                                    fit: BoxFit.contain,
                                    filterQuality: pixelArt
                                        ? FilterQuality.none
                                        : FilterQuality.medium,
                                    errorBuilder: (_, __, ___) =>
                                        const PokeballIcon(size: 90),
                                  ),
                          ),
                        ),
                      ),
                    ),
                    // Línea de escaneo roja.
                    if (t < 0.75)
                      Positioned.fill(
                        child: Align(
                          alignment: Alignment(0, -1 + 2 * lineT),
                          child: Container(
                            height: 4,
                            decoration: const BoxDecoration(
                              color: AppColors.red,
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.redGlow,
                                  blurRadius: 12,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
