import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Login local: las cuentas y la sesión se guardan en el dispositivo
/// (contraseña con sal + SHA-256; no hay servidor).
class AuthService extends ChangeNotifier {
  AuthService._();
  static final AuthService instance = AuthService._();

  static const _usersKey = 'auth_users';
  static const _sessionKey = 'auth_session';
  static const _tutorialKey = 'tutorial_pending_';

  late final SharedPreferences _prefs;

  /// clave = usuario en minúsculas -> {name, salt, hash}
  Map<String, Map<String, String>> _users = {};
  String? _currentUser;

  /// Nombre (tal como se registró) del usuario con sesión, o null.
  String? get currentUser => _currentUser;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    final raw = _prefs.getString(_usersKey);
    if (raw != null) {
      try {
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        _users = decoded.map(
          (k, v) => MapEntry(k, Map<String, String>.from(v as Map)),
        );
      } catch (_) {
        _users = {};
      }
    }
    final session = _prefs.getString(_sessionKey);
    if (session != null && _users.containsKey(session)) {
      _currentUser = _users[session]!['name'];
    }
  }

  String _hash(String salt, String password) =>
      sha256.convert(utf8.encode('$salt:$password')).toString();

  String _newSalt() {
    final rnd = Random.secure();
    return base64UrlEncode(List<int>.generate(16, (_) => rnd.nextInt(256)));
  }

  /// Crea la cuenta e inicia sesión. Devuelve un mensaje de error o null.
  Future<String?> register(String username, String password) async {
    final name = username.trim();
    final key = name.toLowerCase();
    if (_users.containsKey(key)) return 'Ese usuario ya existe.';
    final salt = _newSalt();
    _users[key] = {'name': name, 'salt': salt, 'hash': _hash(salt, password)};
    await _prefs.setString(_usersKey, jsonEncode(_users));
    // Perfil nuevo: se mostrará el tutorial hasta que lo termine u omita.
    await _prefs.setBool('$_tutorialKey$key', true);
    await _startSession(key);
    return null;
  }

  /// Inicia sesión. Devuelve un mensaje de error o null.
  Future<String?> login(String username, String password) async {
    final key = username.trim().toLowerCase();
    final user = _users[key];
    if (user == null || user['hash'] != _hash(user['salt']!, password)) {
      return 'Usuario o contraseña incorrectos.';
    }
    await _startSession(key);
    return null;
  }

  Future<void> _startSession(String key) async {
    await _prefs.setString(_sessionKey, key);
    _currentUser = _users[key]!['name'];
    notifyListeners();
  }

  /// ¿Debe verse el tutorial de bienvenida (perfil recién creado)?
  bool get needsTutorial {
    final name = _currentUser;
    if (name == null) return false;
    return _prefs.getBool('$_tutorialKey${name.toLowerCase()}') ?? false;
  }

  Future<void> markTutorialDone() async {
    final name = _currentUser;
    if (name == null) return;
    await _prefs.remove('$_tutorialKey${name.toLowerCase()}');
  }

  Future<void> logout() async {
    await _prefs.remove(_sessionKey);
    _currentUser = null;
    notifyListeners();
  }
}
