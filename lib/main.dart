import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import 'core/providers/accessibility_provider.dart';
import 'core/providers/theme_provider.dart';
import 'core/services/notification_service.dart';
import 'app_paciente.dart';
import 'state/app_state.dart';
import 'core/data/supabase_client.dart';

/// Execução: flutter run
/// Build:    flutter build apk
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Inicializa timezones
  tz.initializeTimeZones();
  // Define o timezone local (importante para notificações)
  tz.setLocalLocation(tz.getLocation('America/Sao_Paulo'));
  
  await NotificationService.instance.init();
  // Inicializa Supabase (carrega .env e inicializa o cliente). Create a local
  // `.env` file based on `.env.example` with SUPABASE_URL and SUPABASE_ANON_KEY.
  await SupabaseClientService.init();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppState()),
        ChangeNotifierProvider(create: (_) => AccessibilityProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: const HiperDiarioPacienteApp(),
    ),
  );
}
