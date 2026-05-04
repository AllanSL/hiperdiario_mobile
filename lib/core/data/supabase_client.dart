import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Simple wrapper to initialize Supabase from environment variables.
///
/// Usage: call `await SupabaseClientService.init();` in `main()` before `runApp()`.
class SupabaseClientService {
  static Future<void> init() async {
    // Load .env (if present). If not present, dotenv.load will silently fail
    // but we throw below if values are missing.
    await dotenv.load(fileName: '.env');

    final url = dotenv.env['SUPABASE_URL'];
    final anonKey = dotenv.env['SUPABASE_ANON_KEY'];

    if (url == null || anonKey == null) {
      throw Exception(
        'Supabase configuration not found. Create a .env file with SUPABASE_URL and SUPABASE_ANON_KEY (see .env.example)',
      );
    }

    await Supabase.initialize(
      url: url,
      anonKey: anonKey,
      // debug: true,
    );
  }

  static SupabaseClient get client => Supabase.instance.client;
}
