import 'package:flutter/material.dart';

import 'app_theme.dart';

/// Nombre en español, color e icono de un tipo.
class TypeStyle {
  final String label;
  final Color color;
  final IconData icon;
  const TypeStyle(this.label, this.color, this.icon);
}

/// Los 18 tipos (clave = nombre en la PokeAPI), en orden de la Pokédex.
const Map<String, TypeStyle> kTypeStyles = {
  'normal': TypeStyle('Normal', Color(0xFFA8A77A), Icons.circle_outlined),
  'fire': TypeStyle('Fuego', Color(0xFFEE8130), Icons.local_fire_department),
  'water': TypeStyle('Agua', Color(0xFF6390F0), Icons.water_drop),
  'electric': TypeStyle('Eléctrico', Color(0xFFF7D02C), Icons.bolt),
  'grass': TypeStyle('Planta', Color(0xFF7AC74C), Icons.eco),
  'ice': TypeStyle('Hielo', Color(0xFF96D9D6), Icons.ac_unit),
  'fighting': TypeStyle('Lucha', Color(0xFFC22E28), Icons.sports_mma),
  'poison': TypeStyle('Veneno', Color(0xFFA33EA1), Icons.science),
  'ground': TypeStyle('Tierra', Color(0xFFE2BF65), Icons.terrain),
  'flying': TypeStyle('Volador', Color(0xFFA98FF3), Icons.air),
  'psychic': TypeStyle('Psíquico', Color(0xFFF95587), Icons.psychology),
  'bug': TypeStyle('Bicho', Color(0xFFA6B91A), Icons.bug_report),
  'rock': TypeStyle('Roca', Color(0xFFB6A136), Icons.landscape),
  'ghost': TypeStyle('Fantasma', Color(0xFF735797), Icons.nights_stay),
  'dragon': TypeStyle('Dragón', Color(0xFF6F35FC), Icons.whatshot),
  'dark': TypeStyle('Siniestro', Color(0xFF705746), Icons.dark_mode),
  'steel': TypeStyle('Acero', Color(0xFFB7B7CE), Icons.shield),
  'fairy': TypeStyle('Hada', Color(0xFFD685AD), Icons.auto_awesome),
};

const TypeStyle _unknownType =
    TypeStyle('???', Color(0xFF9E9E9E), Icons.help_outline);

TypeStyle styleOf(String type) => kTypeStyles[type] ?? _unknownType;

/// Color de texto/icono legible sobre [background] (blanco u oscuro).
Color onColorFor(Color background) =>
    ThemeData.estimateBrightnessForColor(background) == Brightness.dark
        ? Colors.white
        : AppColors.black;

/// Colores de las barras de estadísticas (clave = nombre en la PokeAPI).
const Map<String, Color> kStatColors = {
  'hp': Color(0xFFE53935),
  'attack': Color(0xFFF57C00),
  'defense': Color(0xFFAB47BC),
  'special-attack': Color(0xFF42A5F5),
  'special-defense': Color(0xFF66BB6A),
  'speed': Color(0xFFFBC02D),
};

const Map<String, String> kStatLabels = {
  'hp': 'PS',
  'attack': 'ATAQUE',
  'defense': 'DEFENSA',
  'special-attack': 'ATK. ESP',
  'special-defense': 'DEF. ESP',
  'speed': 'VELOCIDAD',
};
