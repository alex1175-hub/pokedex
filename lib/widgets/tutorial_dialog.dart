import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class _Step {
  final IconData icon;
  final String title;
  final String body;
  const _Step(this.icon, this.title, this.body);
}

const List<_Step> _steps = [
  _Step(Icons.catching_pokemon, '¡Bienvenido a la Pokédex!',
      'Aquí puedes consultar los Pokémon de las generaciones I a IX, armar '
          'equipos y combatir. Este tutorial dura un minuto; puedes volver a '
          'verlo con el botón ? de la barra superior.'),
  _Step(Icons.search, 'Explora la Pokédex',
      'Elige un Pokémon de la lista o búscalo por nombre o número. En REGIONES '
          'filtras por generación y en TIPOS por tipo. La ficha tiene '
          'pestañas: datos, habilidades, evolución y movimientos. Toca al '
          'Pokémon para oír su grito.'),
  _Step(Icons.auto_awesome, 'Megas y shiny',
      'En la tabla de evolución aparecen también las megaevoluciones: tócalas '
          'para abrir su ficha. El botón SHINY (estrella de la barra superior '
          'o sobre el arte) cambia todo a las versiones variocolor.'),
  _Step(Icons.groups, 'Crea tu equipo',
      'En EQUIPO guardas hasta 6 Pokémon. Para cada uno elige nivel, '
          'habilidad, 4 movimientos, un objeto equipado (bayas, megapiedras, '
          'Cristales Z...) y su Teracristal. No olvides GUARDAR EQUIPO.'),
  _Step(Icons.flash_on, 'Combate',
      'En COMBATE eliges dificultad y rival (o juegas por red local). Cada '
          'turno usa un movimiento o cambia de Pokémon. Antes de atacar puedes '
          'activar UNA mecánica por Pokémon: Megaevolución (con megapiedra), '
          'Movimiento Z (con Cristal Z, una vez por equipo), Dinamax/Gigamax '
          '(3 turnos) o Teracristalización.'),
  _Step(Icons.rocket_launch, '¡Listo!',
      'Consejo: empieza armando un equipo en EQUIPO y pruébalo en COMBATE '
          'contra la dificultad fácil. ¡Mucha suerte, entrenador!'),
];

/// Tutorial de bienvenida (también se puede abrir desde la barra superior).
Future<void> showTutorial(BuildContext context) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const _TutorialDialog(),
  );
}

class _TutorialDialog extends StatefulWidget {
  const _TutorialDialog();

  @override
  State<_TutorialDialog> createState() => _TutorialDialogState();
}

class _TutorialDialogState extends State<_TutorialDialog> {
  final PageController _ctrl = PageController();
  int _page = 0;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _next() {
    if (_page == _steps.length - 1) {
      Navigator.of(context).pop();
    } else {
      _ctrl.nextPage(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final last = _page == _steps.length - 1;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460, maxHeight: 420),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Expanded(
                child: PageView.builder(
                  controller: _ctrl,
                  itemCount: _steps.length,
                  onPageChanged: (i) => setState(() => _page = i),
                  itemBuilder: (context, i) {
                    final st = _steps[i];
                    return SingleChildScrollView(
                      child: Column(
                        children: [
                          CircleAvatar(
                            radius: 34,
                            backgroundColor: AppColors.red,
                            child: Icon(st.icon, size: 36, color: Colors.white),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            st.title,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                fontSize: 20, fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            st.body,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 14, height: 1.4),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < _steps.length; i++)
                    Container(
                      width: 8,
                      height: 8,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i == _page ? AppColors.red : AppColors.grey,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(last ? '' : 'Omitir'),
                  ),
                  const Spacer(),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.red,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: _next,
                    child: Text(last ? '¡EMPEZAR!' : 'SIGUIENTE'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
