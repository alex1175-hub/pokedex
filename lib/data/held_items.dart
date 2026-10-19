/// Objeto que un Pokémon puede llevar equipado.
class HeldItem {
  final String key;
  final String name;
  final String description;
  const HeldItem(this.key, this.name, this.description);
}

/// Lista local de objetos (nombre y descripción en español).
const List<HeldItem> kHeldItems = [
  HeldItem('light-ball', 'Bolaluminosa', 'Potencia el Atk. y Atk.Esp. de Pikachu.'),
  HeldItem('leftovers', 'Restos', 'Restaura un poco de PS en cada turno.'),
  HeldItem('choice-band', 'Cinta Elegida',
      'Sube el Ataque, pero solo permite usar un movimiento.'),
  HeldItem('choice-specs', 'Gafas Elegidas',
      'Sube el Atk. Esp., pero solo permite usar un movimiento.'),
  HeldItem('choice-scarf', 'Pañuelo Elegido',
      'Sube la Velocidad, pero solo permite usar un movimiento.'),
  HeldItem('life-orb', 'Vidasfera',
      'Potencia los movimientos, pero resta PS al atacar.'),
  HeldItem('sitrus-berry', 'Baya Zidra', 'Restaura PS cuando quedan pocos.'),
  HeldItem('oran-berry', 'Baya Aranja', 'Restaura 10 PS cuando quedan pocos.'),
  HeldItem('expert-belt', 'Cinta Experto',
      'Potencia los movimientos supereficaces.'),
  HeldItem('assault-vest', 'Chaleco Asalto',
      'Sube la Def. Esp., pero impide usar movimientos de estado.'),
  HeldItem('eviolite', 'Mineral Evolutivo',
      'Sube Defensa y Def. Esp. si el Pokémon aún puede evolucionar.'),
  HeldItem('rocky-helmet', 'Casco Dentado',
      'Daña a quien golpee al portador con un ataque de contacto.'),
];

HeldItem? heldItemByKey(String? key) {
  if (key == null) return null;
  for (final i in kHeldItems) {
    if (i.key == key) return i;
  }
  return null;
}
