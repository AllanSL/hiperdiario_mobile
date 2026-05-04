// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hiperdiario/core/providers/accessibility_provider.dart';
import 'package:hiperdiario/core/providers/theme_provider.dart';
import 'package:hiperdiario/app_paciente.dart';
import 'package:hiperdiario/pages/login_page.dart';
import 'package:hiperdiario/state/app_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://example.supabase.co',
      anonKey: 'public-anon-key',
    );
  });

  testWidgets('Login screen renders', (WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AppState()),
          ChangeNotifierProvider(create: (_) => AccessibilityProvider()),
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ],
        child: const HiperDiarioPacienteApp(),
      ),
    );
    // Verifica se a tela inicial carrega (LoginPage)
    expect(find.byType(LoginPage), findsOneWidget);
  });
}
