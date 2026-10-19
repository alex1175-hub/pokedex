import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/team.dart';

/// Guarda y carga el equipo de cada usuario (6 slots) en el dispositivo.
class TeamService {
  static String _key(String username) => 'team_${username.toLowerCase()}';

  static Future<List<TeamMember?>> load(String username) async {
    final prefs = await SharedPreferences.getInstance();
    final slots = List<TeamMember?>.filled(kTeamSize, null);
    final raw = prefs.getString(_key(username));
    if (raw == null) return slots;
    try {
      final list = jsonDecode(raw) as List;
      for (var i = 0; i < kTeamSize && i < list.length; i++) {
        final e = list[i];
        if (e != null) slots[i] = TeamMember.fromJson(e as Map<String, dynamic>);
      }
    } catch (_) {
      // Datos dañados: se empieza con el equipo vacío.
    }
    return slots;
  }

  static Future<void> save(String username, List<TeamMember?> slots) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key(username),
      jsonEncode(slots.map((m) => m?.toJson()).toList()),
    );
  }
}
