import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import '../core/providers/accessibility_provider.dart';
import '../core/providers/theme_provider.dart';
import '../core/theme/app_theme.dart';
import 'pages/Agenda/Home.dart';
import 'pages/Autenticacao/Login.dart';
import 'state/app_state.dart';

class HiperDiarioPacienteApp extends StatelessWidget {
  const HiperDiarioPacienteApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer2<AccessibilityProvider, ThemeProvider>(
      builder: (_, accessibility, themeProvider, __) => MaterialApp(
        title: 'HiperDiário',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.buildTheme(accessibility.factor),
        darkTheme: AppTheme.buildDarkTheme(accessibility.factor),
        themeMode: themeProvider.mode,
        // Configuração de localização para Português do Brasil
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('pt', 'BR')],
        // Aplica comportamento de scroll global: sem bounce/alongamento e sem glow
        scrollBehavior: const NoBounceSrollBehavior(),
        home: Consumer<AppState>(
          builder: (_, app, child) =>
              app.isLogged ? const HomePage() : const LoginPage(),
        ),
      ),
    );
  }
}
