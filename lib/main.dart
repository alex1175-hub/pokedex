import 'package:flutter/material.dart';

import 'screens/login_screen.dart';
import 'screens/pokemon_screen.dart';
import 'services/auth_service.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AuthService.instance.init();
  runApp(const PokedexApp());
}

class PokedexApp extends StatelessWidget {
  const PokedexApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pokédex',
      debugShowCheckedModeBanner: false,
      theme: buildPokeballTheme(),
      home: const _AuthGate(),
    );
  }
}

/// Muestra el login o la Pokédex según haya sesión iniciada.
class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AuthService.instance,
      builder: (context, _) {
        final user = AuthService.instance.currentUser;
        if (user == null) return const LoginScreen();
        return PokemonScreen(key: ValueKey(user));
      },
    );
  }
}
