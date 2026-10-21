# pokedex_app

Práctica Flutter: consumo de la PokeAPI (`https://pokeapi.co/api/v2/`) con Dio.
Pokédex digital de las 8 primeras generaciones (905 Pokémon, de Bulbasaur a Enamorus).

## Estructura

```
assets/sounds/                      # select.wav y scan.wav (efectos de la Pokédex)
lib/
├── main.dart                       # Punto de entrada + control de sesión (login)
├── data/held_items.dart            # Objetos equipables y megapiedras (español)
├── models/team.dart                # TeamMember (Pokémon del equipo)
├── services/auth_service.dart      # Login/registro local (sal + SHA-256)
├── services/team_service.dart      # Guarda el equipo de cada usuario
├── screens/login_screen.dart       # Iniciar sesión / crear cuenta
├── screens/team_screen.dart        # Editor de equipo (6 slots)
├── screens/combat_screen.dart      # Menú de combate, configuración y combate simulado
├── battle/battle_engine.dart       # Lógica del combate por turnos (daño, tipos, objetos, IA)
├── battle/net_session.dart         # Conexión TCP/UDP para combatir en red local
├── battle/battle_builder.dart      # Estadísticas de combate y generador de rival aleatorio
├── battle/move_pool.dart           # Movimientos que puede aprender cada Pokémon
├── models/battle_move.dart         # Datos de un movimiento (poder, precisión, tipo)
├── widgets/battle_view.dart        # Pantalla del combate (arena, animaciones, efectos, acciones)
├── services/sound_service.dart     # Sonidos, música y efectos del combate
├── tools/generar_audio.py          # Genera la música/efectos bt_*.wav (numpy)
├── theme/app_theme.dart            # Paleta Pokéball (rojo, blanco, negro)
├── theme/type_style.dart           # Colores/iconos/nombres de tipos y estadísticas
├── models/pokemon.dart             # Pokemon, movimientos, habilidades, lista
├── models/evolution.dart           # Cadena evolutiva y sus requisitos
├── models/details.dart             # Ficha completa (especie, tipos, habilidades...)
├── services/pokemon_service.dart   # Paso 2: peticiones con Dio
├── services/sound_service.dart     # Efectos de sonido y gritos
├── widgets/pokeball.dart           # Pokéball dibujada + loader giratorio
├── widgets/pokedex_ui.dart         # Tarjetas, etiquetas de tipo, sprites
├── widgets/center_card.dart        # Tarjeta central: arte animado + estadísticas
├── widgets/evolution_view.dart     # Evoluciones clicables
├── widgets/detail_tabs.dart        # Pestañas Datos/Habilidades/Evolución/Movimientos
└── screens/pokemon_screen.dart     # Ventana principal, lista, filtros, barra lateral
```

## Cómo ejecutarlo en VS Code

1. Dentro de la carpeta `pokedex_app`, genera las carpetas de plataforma:
   ```
   flutter create .
   ```
   (No sobrescribe `lib/`, `assets/` ni `pubspec.yaml`; si pregunta, conserva los tuyos.)
   Borra `test/widget_test.dart`, que hace referencia a la app de ejemplo.
2. Instala dependencias:
   ```
   flutter pub get
   ```
3. Ejecuta con `F5` en VS Code o `flutter run` (mejor en ventana ancha: escritorio o web).

## Funciones

- Lista con sprites, búsqueda por nombre o número y cabeceras por generación.
- Barra lateral: POKÉDEX (todos), REGIONES (filtra por generación) y TIPOS (filtra por tipo).
- Ficha: arte, tipos, estadísticas, descripción, género, grupo huevo, regiones,
  debilidades y resistencias.
- Pestañas: Datos, Habilidades, Evolución y Movimientos (por nivel, MT/MO, tutor, huevo,
  con selector de juego).
- Los iconos de evolución son accesos directos a la ficha de ese Pokémon.
- Animación de escaneo, sonidos de interfaz y grito del Pokémon al tocar su imagen
  (archivos `.ogg` de la PokeAPI; no se reproducen en iOS ni en Safari).

## Novedades

- Pokédex hasta la generación IX (#1025, Paldea) con sus movimientos de Escarlata/Púrpura.
- Megaevoluciones (incluidas las nuevas de Leyendas Z-A) en la tabla de evolución; al tocarlas se abre su ficha.
- Botón SHINY (barra superior y sobre el arte) para ver las versiones variocolor.
- Combate: ~90 objetos más (bayas, objetos de combate, exclusivos), Cristales Z (genéricos y exclusivos),
  Dinamax/Gigamax (con Movimientos Máximos, clima y terreno) y Teracristalización (Teratipo elegible en el editor de equipo).
- Arena de combate: Pokémon más grandes y barra de PS más pequeña.
