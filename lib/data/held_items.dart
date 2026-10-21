/// Objeto que un Pokémon puede llevar equipado.
class HeldItem {
  final String key;
  final String name;
  final String _description;

  /// Grupo en el que aparece en el selector del editor de equipo.
  final String category;
  const HeldItem(this.key, this.name, this._description,
      [this.category = kCatBattle]);
  String get description => _description;
}

const String kCatBattle = 'Objetos de combate';
const String kCatBerry = 'Bayas';
const String kCatType = 'Potenciadores de tipo';
const String kCatSpecies = 'Objetos exclusivos';
const String kCatZ = 'Cristales Z';
const String kCatMega = 'Megapiedras';

/// Objeto que solo sirve a ciertas especies.
class SpeciesItem extends HeldItem {
  final List<int> species;
  const SpeciesItem(String key, String name, String description, this.species)
      : super(key, name, description, kCatSpecies);
}

/// Megapiedra: permite que su Pokémon megaevolucione en combate.
class MegaStone extends HeldItem {
  /// Número de Pokédex del Pokémon que la usa.
  final int speciesId;

  /// Forma en la PokeAPI (ej. "charizard-mega-x").
  final String formSlug;
  final String megaName;

  const MegaStone(
    String key,
    String name,
    this.speciesId,
    this.formSlug,
    this.megaName,
  ) : super(key, name, '', kCatMega);

  @override
  String get description =>
      'Permite a $megaName megaevolucionar durante el combate.';
}

/// Cristal Z: permite usar un movimiento Z una vez por combate.
/// Los genéricos convierten un movimiento de su [type]; los exclusivos
/// ([species] no vacío) convierten un movimiento concreto ([baseMove]) en
/// su movimiento Z propio ([zSlug]).
class ZCrystal extends HeldItem {
  final String? type;
  final List<int> species;
  final String? baseMove;
  final String? zSlug;
  final int zPower;
  final String zType;
  final String zClass;
  final String zFallbackName;

  const ZCrystal.generic(String key, String name, String this.type)
      : species = const [],
        baseMove = null,
        zSlug = null,
        zPower = 0,
        zType = '',
        zClass = '',
        zFallbackName = '',
        super(key, name, '', kCatZ);

  const ZCrystal.signature(
    String key,
    String name,
    this.species,
    String this.baseMove,
    String this.zSlug,
    this.zFallbackName,
    this.zType,
    this.zClass,
    this.zPower,
  )   : type = null,
        super(key, name, '', kCatZ);

  bool get isGeneric => type != null;

  @override
  String get description => isGeneric
      ? 'Convierte un movimiento de tipo ${_typeLabels[type] ?? type} en un '
          'movimiento Z devastador (una vez por combate).'
      : 'Convierte $baseMoveLabel en $zFallbackName (una vez por combate).';

  String get baseMoveLabel => (baseMove ?? '')
      .split('-')
      .map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1))
      .join(' ');
}

const Map<String, String> _typeLabels = {
  'normal': 'Normal',
  'fire': 'Fuego',
  'water': 'Agua',
  'electric': 'Eléctrico',
  'grass': 'Planta',
  'ice': 'Hielo',
  'fighting': 'Lucha',
  'poison': 'Veneno',
  'ground': 'Tierra',
  'flying': 'Volador',
  'psychic': 'Psíquico',
  'bug': 'Bicho',
  'rock': 'Roca',
  'ghost': 'Fantasma',
  'dragon': 'Dragón',
  'dark': 'Siniestro',
  'steel': 'Acero',
  'fairy': 'Hada',
};

/// Objetos que potencian los movimientos de un tipo (+20 %).
const Map<String, String> kTypeBoostItems = {
  'charcoal': 'fire',
  'mystic-water': 'water',
  'magnet': 'electric',
  'miracle-seed': 'grass',
  'sharp-beak': 'flying',
  'silver-powder': 'bug',
  'twisted-spoon': 'psychic',
  'dragon-fang': 'dragon',
  'hard-stone': 'rock',
  'soft-sand': 'ground',
  'black-belt': 'fighting',
  'black-glasses': 'dark',
  'never-melt-ice': 'ice',
  'poison-barb': 'poison',
  'spell-tag': 'ghost',
  'silk-scarf': 'normal',
  'metal-coat': 'steel',
  'fairy-feather': 'fairy',
};

/// Bayas que reducen a la mitad un golpe supereficaz de su tipo (una vez).
/// La de tipo Normal reduce cualquier golpe Normal.
const Map<String, String> kResistBerries = {
  'occa-berry': 'fire',
  'passho-berry': 'water',
  'wacan-berry': 'electric',
  'rindo-berry': 'grass',
  'yache-berry': 'ice',
  'chople-berry': 'fighting',
  'kebia-berry': 'poison',
  'shuca-berry': 'ground',
  'coba-berry': 'flying',
  'payapa-berry': 'psychic',
  'tanga-berry': 'bug',
  'charti-berry': 'rock',
  'kasib-berry': 'ghost',
  'haban-berry': 'dragon',
  'colbur-berry': 'dark',
  'babiri-berry': 'steel',
  'chilan-berry': 'normal',
  'roseli-berry': 'fairy',
};

/// Bayas que curan un problema de estado concreto (la Ziuela cura todos).
const Map<String, String> kStatusBerries = {
  'cheri-berry': 'paralysis',
  'chesto-berry': 'sleep',
  'pecha-berry': 'poison',
  'rawst-berry': 'burn',
  'aspear-berry': 'freeze',
  'persim-berry': 'confusion',
};

/// Lista local de objetos generales (nombre y descripción en español).
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
  HeldItem('lum-berry', 'Baya Ziuela',
      'Cura cualquier problema de estado una vez.'),
  HeldItem('expert-belt', 'Cinta Experto',
      'Potencia los movimientos supereficaces.'),
  HeldItem('assault-vest', 'Chaleco Asalto',
      'Sube la Def. Esp., pero impide usar movimientos de estado.'),
  HeldItem('eviolite', 'Mineral Evolutivo',
      'Sube Defensa y Def. Esp. si el Pokémon aún puede evolucionar.'),
  HeldItem('rocky-helmet', 'Casco Dentado',
      'Daña a quien golpee al portador con un ataque de contacto.'),
  HeldItem('flame-orb', 'Llamasfera', 'Quema a su portador al final del turno.'),
  HeldItem('toxic-orb', 'Toxisfera',
      'Envenena a su portador al final del turno.'),
  HeldItem('charcoal', 'Carbón', 'Potencia los movimientos de tipo Fuego.'),
  HeldItem('mystic-water', 'Agua Mística', 'Potencia los movimientos de tipo Agua.'),
  HeldItem('magnet', 'Imán', 'Potencia los movimientos de tipo Eléctrico.'),
  HeldItem('miracle-seed', 'Semilla Milagro',
      'Potencia los movimientos de tipo Planta.'),
  HeldItem('sharp-beak', 'Pico Afilado', 'Potencia los movimientos de tipo Volador.'),
  HeldItem('silver-powder', 'Polvo Plata', 'Potencia los movimientos de tipo Bicho.'),
  HeldItem('twisted-spoon', 'Cuchara Torcida',
      'Potencia los movimientos de tipo Psíquico.'),
  HeldItem('dragon-fang', 'Colmillo Dragón',
      'Potencia los movimientos de tipo Dragón.'),
  HeldItem('hard-stone', 'Piedra Dura', 'Potencia los movimientos de tipo Roca.'),
  HeldItem('soft-sand', 'Arena Fina', 'Potencia los movimientos de tipo Tierra.'),
  HeldItem('black-belt', 'Cinturón Negro',
      'Potencia los movimientos de tipo Lucha.'),
  HeldItem('black-glasses', 'Gafas de Sol',
      'Potencia los movimientos de tipo Siniestro.'),
  HeldItem('never-melt-ice', 'Antiderretir',
      'Potencia los movimientos de tipo Hielo.'),
  HeldItem('poison-barb', 'Flecha Venenosa',
      'Potencia los movimientos de tipo Veneno.'),
  HeldItem('spell-tag', 'Hechizo', 'Potencia los movimientos de tipo Fantasma.'),
  HeldItem('silk-scarf', 'Pañuelo Seda', 'Potencia los movimientos de tipo Normal.'),
  // --- Más objetos de combate ---
  HeldItem('focus-sash', 'Banda Focus',
      'Si recibe un golpe que lo debilitaría con los PS al máximo, aguanta con 1 PS (una vez).'),
  HeldItem('focus-band', 'Cinta Focus',
      'Con un 10 % de probabilidad aguanta un golpe mortal con 1 PS.'),
  HeldItem('scope-lens', 'Periscopio', 'Aumenta la probabilidad de golpe crítico.'),
  HeldItem('razor-claw', 'Garra Afilada',
      'Aumenta la probabilidad de golpe crítico.'),
  HeldItem('muscle-band', 'Cinta Fuerte',
      'Potencia un 10 % los movimientos físicos.'),
  HeldItem('wise-glasses', 'Gafas Especiales',
      'Potencia un 10 % los movimientos especiales.'),
  HeldItem('shell-bell', 'Campana Concha',
      'Recupera PS equivalentes a 1/8 del daño que inflige.'),
  HeldItem('black-sludge', 'Lodo Negro',
      'Cura PS a los tipo Veneno cada turno; daña a los demás.'),
  HeldItem('quick-claw', 'Garra Rápida',
      'Con un 20 % de probabilidad permite actuar primero.'),
  HeldItem('kings-rock', 'Roca del Rey',
      'Sus ataques pueden hacer retroceder al rival (10 %).'),
  HeldItem('weakness-policy', 'Seguro Debilidad',
      'Si recibe un golpe supereficaz, sube mucho Ataque y Atk. Esp. (una vez).'),
  HeldItem('air-balloon', 'Globo Helio',
      'Inmune a movimientos Tierra hasta que reciba un golpe.'),
  HeldItem('bright-powder', 'Polvo Brillo',
      'Reduce la precisión de los ataques que recibe.'),
  HeldItem('wide-lens', 'Lupa', 'Aumenta la precisión de sus movimientos.'),
  // --- Potenciadores de tipo extra ---
  HeldItem('metal-coat', 'Revestimiento Metálico',
      'Potencia los movimientos de tipo Acero.', kCatType),
  HeldItem('fairy-feather', 'Pluma Hada',
      'Potencia los movimientos de tipo Hada.', kCatType),
  // --- Bayas de estado ---
  HeldItem('cheri-berry', 'Baya Zreza', 'Cura la parálisis (una vez).', kCatBerry),
  HeldItem('chesto-berry', 'Baya Atania', 'Despierta al portador (una vez).', kCatBerry),
  HeldItem('pecha-berry', 'Baya Meloc', 'Cura el envenenamiento (una vez).', kCatBerry),
  HeldItem('rawst-berry', 'Baya Safre', 'Cura las quemaduras (una vez).', kCatBerry),
  HeldItem('aspear-berry', 'Baya Perasi', 'Descongela al portador (una vez).', kCatBerry),
  HeldItem('persim-berry', 'Baya Caquic', 'Cura la confusión (una vez).', kCatBerry),
  HeldItem('occa-berry', 'Baya Resistente: Fuego', 'Reduce a la mitad un golpe supereficaz de tipo Fuego (una vez).', kCatBerry),
  HeldItem('passho-berry', 'Baya Resistente: Agua', 'Reduce a la mitad un golpe supereficaz de tipo Agua (una vez).', kCatBerry),
  HeldItem('wacan-berry', 'Baya Resistente: Eléctrico', 'Reduce a la mitad un golpe supereficaz de tipo Eléctrico (una vez).', kCatBerry),
  HeldItem('rindo-berry', 'Baya Resistente: Planta', 'Reduce a la mitad un golpe supereficaz de tipo Planta (una vez).', kCatBerry),
  HeldItem('yache-berry', 'Baya Resistente: Hielo', 'Reduce a la mitad un golpe supereficaz de tipo Hielo (una vez).', kCatBerry),
  HeldItem('chople-berry', 'Baya Resistente: Lucha', 'Reduce a la mitad un golpe supereficaz de tipo Lucha (una vez).', kCatBerry),
  HeldItem('kebia-berry', 'Baya Resistente: Veneno', 'Reduce a la mitad un golpe supereficaz de tipo Veneno (una vez).', kCatBerry),
  HeldItem('shuca-berry', 'Baya Resistente: Tierra', 'Reduce a la mitad un golpe supereficaz de tipo Tierra (una vez).', kCatBerry),
  HeldItem('coba-berry', 'Baya Resistente: Volador', 'Reduce a la mitad un golpe supereficaz de tipo Volador (una vez).', kCatBerry),
  HeldItem('payapa-berry', 'Baya Resistente: Psíquico', 'Reduce a la mitad un golpe supereficaz de tipo Psíquico (una vez).', kCatBerry),
  HeldItem('tanga-berry', 'Baya Resistente: Bicho', 'Reduce a la mitad un golpe supereficaz de tipo Bicho (una vez).', kCatBerry),
  HeldItem('charti-berry', 'Baya Resistente: Roca', 'Reduce a la mitad un golpe supereficaz de tipo Roca (una vez).', kCatBerry),
  HeldItem('kasib-berry', 'Baya Resistente: Fantasma', 'Reduce a la mitad un golpe supereficaz de tipo Fantasma (una vez).', kCatBerry),
  HeldItem('haban-berry', 'Baya Resistente: Dragón', 'Reduce a la mitad un golpe supereficaz de tipo Dragón (una vez).', kCatBerry),
  HeldItem('colbur-berry', 'Baya Resistente: Siniestro', 'Reduce a la mitad un golpe supereficaz de tipo Siniestro (una vez).', kCatBerry),
  HeldItem('babiri-berry', 'Baya Resistente: Acero', 'Reduce a la mitad un golpe supereficaz de tipo Acero (una vez).', kCatBerry),
  HeldItem('chilan-berry', 'Baya Resistente: Normal', 'Reduce a la mitad un golpe de tipo Normal (una vez).', kCatBerry),
  HeldItem('roseli-berry', 'Baya Resistente: Hada', 'Reduce a la mitad un golpe supereficaz de tipo Hada (una vez).', kCatBerry),
];



/// Objetos que solo sirven a ciertas especies.
const List<SpeciesItem> kSpeciesItems = [
  SpeciesItem('thick-club', 'Hueso Grueso',
      'Duplica el Ataque de Cubone y Marowak.', [104, 105]),
  SpeciesItem('lucky-punch', 'Puño Suerte',
      'Aumenta mucho el ratio de críticos de Chansey.', [113]),
  SpeciesItem('leek', 'Puerro',
      "Aumenta mucho el ratio de críticos de Farfetch'd y Sirfetch'd.",
      [83, 865]),
  SpeciesItem('soul-dew', 'Rocío Bondad',
      'Sube el Atk. Esp. y la Def. Esp. de Latias y Latios.', [380, 381]),
  SpeciesItem('deep-sea-tooth', 'Diente Marino',
      'Duplica el Atk. Esp. de Clamperl.', [366]),
  SpeciesItem('deep-sea-scale', 'Escama Marina',
      'Duplica la Def. Esp. de Clamperl.', [366]),
  SpeciesItem('metal-powder', 'Polvo Metálico',
      'Duplica la Defensa de Ditto.', [132]),
  SpeciesItem('quick-powder', 'Polvo Veloz',
      'Duplica la Velocidad de Ditto.', [132]),
  SpeciesItem('adamant-orb', 'Diamansfera',
      'Potencia los movimientos Dragón y Acero de Dialga.', [483]),
  SpeciesItem('lustrous-orb', 'Lustresfera',
      'Potencia los movimientos Dragón y Agua de Palkia.', [484]),
  SpeciesItem('griseous-orb', 'Griseosfera',
      'Potencia los movimientos Dragón y Fantasma de Giratina.', [487]),
];

/// Cristales Z genéricos (uno por tipo).
const List<ZCrystal> kZCrystals = [
  ZCrystal.generic('normalium-z', 'Cristal Z Normal', 'normal'),
  ZCrystal.generic('firium-z', 'Cristal Z Fuego', 'fire'),
  ZCrystal.generic('waterium-z', 'Cristal Z Agua', 'water'),
  ZCrystal.generic('electrium-z', 'Cristal Z Eléctrico', 'electric'),
  ZCrystal.generic('grassium-z', 'Cristal Z Planta', 'grass'),
  ZCrystal.generic('icium-z', 'Cristal Z Hielo', 'ice'),
  ZCrystal.generic('fightinium-z', 'Cristal Z Lucha', 'fighting'),
  ZCrystal.generic('poisonium-z', 'Cristal Z Veneno', 'poison'),
  ZCrystal.generic('groundium-z', 'Cristal Z Tierra', 'ground'),
  ZCrystal.generic('flyinium-z', 'Cristal Z Volador', 'flying'),
  ZCrystal.generic('psychium-z', 'Cristal Z Psíquico', 'psychic'),
  ZCrystal.generic('buginium-z', 'Cristal Z Bicho', 'bug'),
  ZCrystal.generic('rockium-z', 'Cristal Z Roca', 'rock'),
  ZCrystal.generic('ghostium-z', 'Cristal Z Fantasma', 'ghost'),
  ZCrystal.generic('dragonium-z', 'Cristal Z Dragón', 'dragon'),
  ZCrystal.generic('darkinium-z', 'Cristal Z Siniestro', 'dark'),
  ZCrystal.generic('steelium-z', 'Cristal Z Acero', 'steel'),
  ZCrystal.generic('fairium-z', 'Cristal Z Hada', 'fairy'),
];

/// Cristales Z exclusivos de ciertos Pokémon.
const List<ZCrystal> kSignatureZCrystals = [
  ZCrystal.signature('pikanium-z', 'Cristal Z de Pikachu', [25], 'volt-tackle',
      'catastropika', 'Catastropika', 'electric', 'physical', 210),
  ZCrystal.signature('aloraichium-z', 'Cristal Z de Raichu de Alola', [26],
      'thunderbolt', 'stoked-sparksurfer', 'Surfeo Chispeante', 'electric',
      'special', 175),
  ZCrystal.signature('decidium-z', 'Cristal Z de Decidueye', [724],
      'spirit-shackle', 'sinister-arrow-raid', 'Flechazo Sombrío', 'ghost',
      'physical', 180),
  ZCrystal.signature('incinium-z', 'Cristal Z de Incineroar', [727],
      'darkest-lariat', 'malicious-moonsault', 'Salto Mortal Maligno', 'dark',
      'physical', 180),
  ZCrystal.signature('primarium-z', 'Cristal Z de Primarina', [730],
      'sparkling-aria', 'oceanic-operetta', 'Opereta Oceánica', 'water',
      'special', 195),
  ZCrystal.signature('snorlium-z', 'Cristal Z de Snorlax', [143], 'giga-impact',
      'pulverizing-pancake', 'Tortitas Aplastantes', 'normal', 'physical', 210),
  ZCrystal.signature('mewnium-z', 'Cristal Z de Mew', [151], 'psychic',
      'genesis-supernova', 'Supernova Génesis', 'psychic', 'special', 185),
  ZCrystal.signature('tapunium-z', 'Cristal Z de los Tapu', [785, 786, 787, 788],
      'natures-madness', 'guardian-of-alola', 'Guardián de Alola', 'fairy',
      'special', 0),
  ZCrystal.signature('marshadium-z', 'Cristal Z de Marshadow', [802],
      'spectral-thief', 'soul-stealing-7-star-strike', 'Golpe Robaalmas',
      'ghost', 'physical', 195),
  ZCrystal.signature('kommonium-z', 'Cristal Z de Kommo-o', [784],
      'clanging-scales', 'clangorous-soulblaze', 'Estruendo Almafuego',
      'dragon', 'special', 185),
  ZCrystal.signature('lycanium-z', 'Cristal Z de Lycanroc', [745], 'stone-edge',
      'splintered-stormshards', 'Tormenta de Cristales', 'rock', 'physical',
      190),
  ZCrystal.signature('mimikium-z', 'Cristal Z de Mimikyu', [778], 'play-rough',
      'lets-snuggle-forever', 'Abrazo Eterno', 'fairy', 'physical', 190),
  ZCrystal.signature('solganium-z', 'Cristal Z de Solgaleo', [791],
      'sunsteel-strike', 'searing-sunraze-smash', 'Golpe Solar Abrasador',
      'steel', 'physical', 200),
  ZCrystal.signature('lunalium-z', 'Cristal Z de Lunala', [792],
      'moongeist-beam', 'menacing-moonraze-maelstrom', 'Rayo Lunar Amenazante',
      'ghost', 'special', 200),
  ZCrystal.signature('ultranecrozium-z', 'Cristal Z de Necrozma', [800],
      'photon-geyser', 'light-that-burns-the-sky', 'Fotodestrucción Cegadora',
      'psychic', 'special', 200),
];

/// Todas las megapiedras (cada una solo sirve para su Pokémon).
const List<MegaStone> kMegaStones = [
  MegaStone('venusaurite', 'Venusaurita', 3, 'venusaur-mega', 'Mega Venusaur'),
  MegaStone('charizardite-x', 'Charizardita X', 6, 'charizard-mega-x', 'Mega Charizard X'),
  MegaStone('charizardite-y', 'Charizardita Y', 6, 'charizard-mega-y', 'Mega Charizard Y'),
  MegaStone('blastoisinite', 'Blastoisita', 9, 'blastoise-mega', 'Mega Blastoise'),
  MegaStone('beedrillite', 'Beedrillita', 15, 'beedrill-mega', 'Mega Beedrill'),
  MegaStone('pidgeotite', 'Pidgeotita', 18, 'pidgeot-mega', 'Mega Pidgeot'),
  MegaStone('alakazite', 'Alakazamita', 65, 'alakazam-mega', 'Mega Alakazam'),
  MegaStone('slowbronite', 'Slowbronita', 80, 'slowbro-mega', 'Mega Slowbro'),
  MegaStone('gengarite', 'Gengarita', 94, 'gengar-mega', 'Mega Gengar'),
  MegaStone('kangaskhanite', 'Kangaskhanita', 115, 'kangaskhan-mega', 'Mega Kangaskhan'),
  MegaStone('pinsirite', 'Pinsirita', 127, 'pinsir-mega', 'Mega Pinsir'),
  MegaStone('gyaradosite', 'Gyaradosita', 130, 'gyarados-mega', 'Mega Gyarados'),
  MegaStone('aerodactylite', 'Aerodactylita', 142, 'aerodactyl-mega', 'Mega Aerodactyl'),
  MegaStone('mewtwonite-x', 'Mewtwoita X', 150, 'mewtwo-mega-x', 'Mega Mewtwo X'),
  MegaStone('mewtwonite-y', 'Mewtwoita Y', 150, 'mewtwo-mega-y', 'Mega Mewtwo Y'),
  MegaStone('ampharosite', 'Ampharosita', 181, 'ampharos-mega', 'Mega Ampharos'),
  MegaStone('steelixite', 'Steelixita', 208, 'steelix-mega', 'Mega Steelix'),
  MegaStone('scizorite', 'Scizorita', 212, 'scizor-mega', 'Mega Scizor'),
  MegaStone('heracronite', 'Heracrosita', 214, 'heracross-mega', 'Mega Heracross'),
  MegaStone('houndoominite', 'Houndoomita', 229, 'houndoom-mega', 'Mega Houndoom'),
  MegaStone('tyranitarite', 'Tyranitarita', 248, 'tyranitar-mega', 'Mega Tyranitar'),
  MegaStone('sceptilite', 'Sceptilita', 254, 'sceptile-mega', 'Mega Sceptile'),
  MegaStone('blazikenite', 'Blazikenita', 257, 'blaziken-mega', 'Mega Blaziken'),
  MegaStone('swampertite', 'Swampertita', 260, 'swampert-mega', 'Mega Swampert'),
  MegaStone('gardevoirite', 'Gardevoirita', 282, 'gardevoir-mega', 'Mega Gardevoir'),
  MegaStone('sablenite', 'Sablenita', 302, 'sableye-mega', 'Mega Sableye'),
  MegaStone('mawilite', 'Mawilita', 303, 'mawile-mega', 'Mega Mawile'),
  MegaStone('aggronite', 'Aggronita', 306, 'aggron-mega', 'Mega Aggron'),
  MegaStone('medichamite', 'Medichamita', 308, 'medicham-mega', 'Mega Medicham'),
  MegaStone('manectite', 'Manectricita', 310, 'manectric-mega', 'Mega Manectric'),
  MegaStone('sharpedonite', 'Sharpedonita', 319, 'sharpedo-mega', 'Mega Sharpedo'),
  MegaStone('cameruptite', 'Cameruptita', 323, 'camerupt-mega', 'Mega Camerupt'),
  MegaStone('altarianite', 'Altarianita', 334, 'altaria-mega', 'Mega Altaria'),
  MegaStone('banettite', 'Banettita', 354, 'banette-mega', 'Mega Banette'),
  MegaStone('absolite', 'Absolita', 359, 'absol-mega', 'Mega Absol'),
  MegaStone('glalitite', 'Glalitita', 362, 'glalie-mega', 'Mega Glalie'),
  MegaStone('salamencite', 'Salamencita', 373, 'salamence-mega', 'Mega Salamence'),
  MegaStone('metagrossite', 'Metagrossita', 376, 'metagross-mega', 'Mega Metagross'),
  MegaStone('latiasite', 'Latiasita', 380, 'latias-mega', 'Mega Latias'),
  MegaStone('latiosite', 'Latiosita', 381, 'latios-mega', 'Mega Latios'),
  MegaStone('lopunnite', 'Lopunnita', 428, 'lopunny-mega', 'Mega Lopunny'),
  MegaStone('garchompite', 'Garchompita', 445, 'garchomp-mega', 'Mega Garchomp'),
  MegaStone('lucarionite', 'Lucarita', 448, 'lucario-mega', 'Mega Lucario'),
  MegaStone('abomasite', 'Abomasnowita', 460, 'abomasnow-mega', 'Mega Abomasnow'),
  MegaStone('galladite', 'Galladita', 475, 'gallade-mega', 'Mega Gallade'),
  MegaStone('audinite', 'Audinita', 531, 'audino-mega', 'Mega Audino'),
  MegaStone('diancite', 'Diancita', 719, 'diancie-mega', 'Mega Diancie'),
  MegaStone('clefablite', 'Clefablita', 36, 'clefable-mega', 'Mega Clefable'),
  MegaStone('victreebelite', 'Victreebelita', 71, 'victreebel-mega', 'Mega Victreebel'),
  MegaStone('starminite', 'Starmita', 121, 'starmie-mega', 'Mega Starmie'),
  MegaStone('dragoninite', 'Dragonitita', 149, 'dragonite-mega', 'Mega Dragonite'),
  MegaStone('meganiumite', 'Meganiumita', 154, 'meganium-mega', 'Mega Meganium'),
  MegaStone('feraligite', 'Feraligita', 160, 'feraligatr-mega', 'Mega Feraligatr'),
  MegaStone('skarmorite', 'Skarmorita', 227, 'skarmory-mega', 'Mega Skarmory'),
  MegaStone('froslassite', 'Froslassita', 478, 'froslass-mega', 'Mega Froslass'),
  MegaStone('heatranite', 'Heatranita', 485, 'heatran-mega', 'Mega Heatran'),
  MegaStone('darkranite', 'Darkranita', 491, 'darkrai-mega', 'Mega Darkrai'),
  MegaStone('emboarite', 'Emboarita', 500, 'emboar-mega', 'Mega Emboar'),
  MegaStone('excadrite', 'Excadrita', 530, 'excadrill-mega', 'Mega Excadrill'),
  MegaStone('scolipite', 'Scolipita', 545, 'scolipede-mega', 'Mega Scolipede'),
  MegaStone('scraftinite', 'Scraftinita', 560, 'scrafty-mega', 'Mega Scrafty'),
  MegaStone('eelektrossite', 'Eelektrossita', 604, 'eelektross-mega', 'Mega Eelektross'),
  MegaStone('chandelurite', 'Chandelurita', 609, 'chandelure-mega', 'Mega Chandelure'),
  MegaStone('golurkite', 'Golurkita', 623, 'golurk-mega', 'Mega Golurk'),
  MegaStone('chesnaughtite', 'Chesnaughtita', 652, 'chesnaught-mega', 'Mega Chesnaught'),
  MegaStone('delphoxite', 'Delphoxita', 655, 'delphox-mega', 'Mega Delphox'),
  MegaStone('greninjite', 'Greninjita', 658, 'greninja-mega', 'Mega Greninja'),
  MegaStone('pyroarite', 'Pyroarita', 668, 'pyroar-mega', 'Mega Pyroar'),
  MegaStone('floettite', 'Floettita', 670, 'floette-mega', 'Mega Floette'),
  MegaStone('meowsticite', 'Meowsticita', 678, 'meowstic-male-mega', 'Mega Meowstic'),
  MegaStone('malamarite', 'Malamarita', 687, 'malamar-mega', 'Mega Malamar'),
  MegaStone('barbaracite', 'Barbaracita', 689, 'barbaracle-mega', 'Mega Barbaracle'),
  MegaStone('dragalgite', 'Dragalgita', 691, 'dragalge-mega', 'Mega Dragalge'),
  MegaStone('hawluchanite', 'Hawluchanita', 701, 'hawlucha-mega', 'Mega Hawlucha'),
  MegaStone('zygardite', 'Zygardita', 718, 'zygarde-mega', 'Mega Zygarde'),
  MegaStone('crabominite', 'Crabominita', 740, 'crabominable-mega', 'Mega Crabominable'),
  MegaStone('golisopite', 'Golisopita', 768, 'golisopod-mega', 'Mega Golisopod'),
  MegaStone('drampanite', 'Drampanita', 780, 'drampa-mega', 'Mega Drampa'),
  MegaStone('magearnite', 'Magearnita', 801, 'magearna-mega', 'Mega Magearna'),
  MegaStone('zeraorite', 'Zeraorita', 807, 'zeraora-mega', 'Mega Zeraora'),
  MegaStone('falinksite', 'Falinksita', 870, 'falinks-mega', 'Mega Falinks'),
  MegaStone('scovillainite', 'Scovillainita', 952, 'scovillain-mega', 'Mega Scovillain'),
  MegaStone('glimmoranite', 'Glimmoranita', 970, 'glimmora-mega', 'Mega Glimmora'),
  MegaStone('tatsugirinite', 'Tatsugirinita', 978, 'tatsugiri-curly-mega', 'Mega Tatsugiri'),
  MegaStone('baxcalibrite', 'Baxcalibrita', 998, 'baxcalibur-mega', 'Mega Baxcalibur'),
  MegaStone('raichunite-x', 'Raichunita X', 26, 'raichu-mega-x', 'Mega Raichu X'),
  MegaStone('raichunite-y', 'Raichunita Y', 26, 'raichu-mega-y', 'Mega Raichu Y'),
  MegaStone('chimechite', 'Chimechita', 358, 'chimecho-mega', 'Mega Chimecho'),
  MegaStone('absolite-z', 'Absolita Z', 359, 'absol-mega-z', 'Mega Absol Z'),
  MegaStone('staraptite', 'Staraptita', 398, 'staraptor-mega', 'Mega Staraptor'),
  MegaStone('garchompite-z', 'Garchompita Z', 445, 'garchomp-mega-z', 'Mega Garchomp Z'),
  MegaStone('lucarionite-z', 'Lucarita Z', 448, 'lucario-mega-z', 'Mega Lucario Z'),
];

HeldItem? heldItemByKey(String? key) {
  if (key == null) return null;
  for (final i in kHeldItems) {
    if (i.key == key) return i;
  }
  for (final i in kSpeciesItems) {
    if (i.key == key) return i;
  }
  for (final z in kZCrystals) {
    if (z.key == key) return z;
  }
  for (final z in kSignatureZCrystals) {
    if (z.key == key) return z;
  }
  for (final s in kMegaStones) {
    if (s.key == key) return s;
  }
  return null;
}

MegaStone? megaStoneFor(String? key) {
  if (key == null) return null;
  for (final s in kMegaStones) {
    if (s.key == key) return s;
  }
  return null;
}

/// Cristal Z (genérico o exclusivo) con esa clave.
ZCrystal? zCrystalFor(String? key) {
  if (key == null) return null;
  for (final z in kZCrystals) {
    if (z.key == key) return z;
  }
  for (final z in kSignatureZCrystals) {
    if (z.key == key) return z;
  }
  return null;
}

/// Megapiedra que corresponde a una forma (o, si no hay una exacta, la de su
/// especie: p. ej. las otras formas de Tatsugiri).
MegaStone? megaStoneForForm(String formSlug, int speciesId) {
  for (final s in kMegaStones) {
    if (s.formSlug == formSlug) return s;
  }
  for (final s in kMegaStones) {
    if (s.speciesId == speciesId) return s;
  }
  return null;
}

/// Orden en el que se muestran los grupos del selector de objetos.
const List<String> kCategoryOrder = [
  kCatBattle,
  kCatType,
  kCatBerry,
  kCatSpecies,
  kCatZ,
  kCatMega,
];

/// Grupo real de un objeto (los potenciadores de tipo y las bayas antiguas
/// están en la lista general).
String categoryOf(HeldItem item) {
  if (kTypeBoostItems.containsKey(item.key)) return kCatType;
  if (item.key.endsWith('-berry')) return kCatBerry;
  return item.category;
}

/// Objetos que se pueden equipar a un Pokémon: los generales, los exclusivos
/// de su especie, los Cristales Z y sus megapiedras.
List<HeldItem> itemsFor(int pokemonId) => [
      ...kHeldItems,
      ...kSpeciesItems.where((i) => i.species.contains(pokemonId)),
      ...kZCrystals,
      ...kSignatureZCrystals.where((z) => z.species.contains(pokemonId)),
      ...kMegaStones.where((s) => s.speciesId == pokemonId),
    ];
