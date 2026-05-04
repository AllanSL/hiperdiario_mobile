import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'pages/home_page.dart';
import 'package:hiperdiario/pages/login_page.dart';
import 'state/app_state.dart';

class HiperDiarioApp extends StatelessWidget {
  const HiperDiarioApp({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
      useMaterial3: true,
      visualDensity: VisualDensity.comfortable,
      textTheme: const TextTheme(
        bodyLarge: TextStyle(fontSize: 20),
        bodyMedium: TextStyle(fontSize: 18),
        labelLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
      ),
      buttonTheme: const ButtonThemeData(minWidth: 64, height: 48),
    );

    return MaterialApp(
      title: 'HiperDiário',
      debugShowCheckedModeBanner: false,
      theme: theme,
      // Configuração de localização para Português do Brasil
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('pt', 'BR')],
      // Aplica comportamento de scroll global: sem bounce/alongamento e sem glow.
      scrollBehavior: const _NoBounceScrollBehavior(),
      // Suporte melhor à acessibilidade: respeita escala do sistema
      // e aumenta áreas de toque por padrão via visualDensity.
      home: Consumer<AppState>(
        builder: (_, app, child) =>
            app.isLogged ? const HomePage() : const LoginPage(),
      ),
    );
  }
}

class _NoBounceScrollBehavior extends ScrollBehavior {
  const _NoBounceScrollBehavior();
  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    return const ClampingScrollPhysics();
  }

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }
}
