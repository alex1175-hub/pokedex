import 'package:flutter/foundation.dart';

/// Opciones de visualización compartidas por toda la Pokédex.
class ViewOptions {
  ViewOptions._();

  /// true = la Pokédex muestra las versiones shiny (variocolor) de los
  /// Pokémon: lista, ficha y cadena evolutiva.
  static final ValueNotifier<bool> shiny = ValueNotifier<bool>(false);

  static void toggleShiny() => shiny.value = !shiny.value;
}
