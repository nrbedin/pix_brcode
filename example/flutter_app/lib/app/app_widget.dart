import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';

/// `MaterialApp` com as rotas do Modular.
class AppWidget extends StatelessWidget {
  /// Cria o app.
  const AppWidget({super.key});

  static const _seed = Color(0xFF00897B);

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Pix Checkout Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: _seed, useMaterial3: true),
      darkTheme: ThemeData(
        colorSchemeSeed: _seed,
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      routeInformationParser: Modular.routeInformationParser,
      routerDelegate: Modular.routerDelegate,
    );
  }
}
