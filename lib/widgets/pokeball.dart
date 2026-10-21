import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Pokéball dibujada con código (sin imágenes).
class PokeballIcon extends StatelessWidget {
  final double size;
  const PokeballIcon({super.key, this.size = 48});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _PokeballPainter(),
    );
  }
}

class _PokeballPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final r = size.width / 2;
    final center = Offset(r, r);
    final stroke = size.width * 0.07;
    final rect = Rect.fromCircle(center: center, radius: r - stroke / 2);

    // Mitad superior roja y mitad inferior blanca.
    canvas.drawArc(rect, math.pi, math.pi, true, Paint()..color = AppColors.red);
    canvas.drawArc(rect, 0, math.pi, true, Paint()..color = Colors.white);

    final line = Paint()
      ..color = AppColors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;

    // Contorno y banda central.
    canvas.drawCircle(center, r - stroke / 2, line);
    canvas.drawLine(
      Offset(stroke / 2, r),
      Offset(size.width - stroke / 2, r),
      line,
    );

    // Botón central.
    canvas.drawCircle(center, r * 0.28, Paint()..color = Colors.white);
    canvas.drawCircle(center, r * 0.28, line);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Indicador de carga: una Pokéball que gira.
class PokeballLoader extends StatefulWidget {
  final double size;
  const PokeballLoader({super.key, this.size = 56});

  @override
  State<PokeballLoader> createState() => _PokeballLoaderState();
}

class _PokeballLoaderState extends State<PokeballLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: _controller,
      child: PokeballIcon(size: widget.size),
    );
  }
}
