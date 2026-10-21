import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// Efectos de sonido de la Pokédex (assets), gritos de los Pokémon (URL)
/// y música/efectos del combate.
class SoundService {
  SoundService._();
  static final SoundService instance = SoundService._();

  final AudioPlayer _uiPlayer = AudioPlayer();
  final AudioPlayer _cryPlayer = AudioPlayer();

  // --- Combate ---
  final AudioPlayer _musicPlayer = AudioPlayer();
  final List<AudioPlayer> _sfxPlayers =
      List<AudioPlayer>.generate(4, (_) => AudioPlayer());
  int _sfxIndex = 0;
  Object? _musicOwner;
  String? _musicFile;

  /// Música del combate activada (se puede silenciar desde la pantalla).
  final ValueNotifier<bool> musicEnabled = ValueNotifier<bool>(true);

  /// Pitido al seleccionar algo.
  Future<void> playSelect() => _playAsset('sounds/select.wav');

  /// Sonido de escaneo cuando aparece un Pokémon.
  Future<void> playScan() => _playAsset('sounds/scan.wav');

  Future<void> _playAsset(String path) async {
    try {
      await _uiPlayer.stop();
      await _uiPlayer.play(AssetSource(path));
    } catch (e) {
      debugPrint('Sonido no disponible: $e');
    }
  }

  /// Música en bucle. [owner] identifica a quien la inició: solo él puede
  /// detenerla con [stopMusic].
  Future<void> playMusic(String file, Object owner) async {
    _musicOwner = owner;
    _musicFile = file;
    if (!musicEnabled.value) return;
    await _startMusic(file);
  }

  Future<void> _startMusic(String file) async {
    try {
      await _musicPlayer.stop();
      await _musicPlayer.setReleaseMode(ReleaseMode.loop);
      await _musicPlayer.setVolume(0.35);
      await _musicPlayer.play(AssetSource('sounds/$file'));
    } catch (e) {
      debugPrint('Música no disponible: $e');
    }
  }

  Future<void> stopMusic(Object owner) async {
    if (!identical(_musicOwner, owner)) return;
    _musicOwner = null;
    _musicFile = null;
    try {
      await _musicPlayer.stop();
    } catch (e) {
      debugPrint('No se pudo detener la música: $e');
    }
  }

  Future<void> toggleMusic() async {
    musicEnabled.value = !musicEnabled.value;
    if (!musicEnabled.value) {
      try {
        await _musicPlayer.stop();
      } catch (_) {}
    } else if (_musicFile != null) {
      await _startMusic(_musicFile!);
    }
  }

  /// Efecto corto del combate (varios pueden sonar a la vez).
  Future<void> playSfx(String file) async {
    final player = _sfxPlayers[_sfxIndex];
    _sfxIndex = (_sfxIndex + 1) % _sfxPlayers.length;
    try {
      await player.stop();
      await player.setVolume(0.8);
      await player.play(AssetSource('sounds/$file'));
    } catch (e) {
      debugPrint('Efecto no disponible: $e');
    }
  }

  /// Reproduce el grito del Pokémon. Devuelve false si no se pudo.
  Future<bool> playCry(String? url) async {
    if (url == null || url.isEmpty) return false;
    try {
      await _cryPlayer.stop();
      await _cryPlayer.play(UrlSource(url));
      return true;
    } catch (e) {
      debugPrint('No se pudo reproducir el grito: $e');
      return false;
    }
  }
}
