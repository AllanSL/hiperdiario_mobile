import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Provider responsável pela preferência de tema (claro / escuro / sistema).
///
/// Persiste a escolha via [SharedPreferences] e notifica a árvore de widgets
/// sempre que o usuário altera o modo.
class ThemeProvider extends ChangeNotifier {
  static const _key = 'theme_mode';

  ThemeMode _mode = ThemeMode.system;

  /// Modo de tema atual.
  ThemeMode get mode => _mode;

  /// Indica se o tema escuro está ativo (explicitamente ou via sistema).
  bool isDark(BuildContext context) {
    if (_mode == ThemeMode.system) {
      return MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    }
    return _mode == ThemeMode.dark;
  }

  ThemeProvider() {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final index = prefs.getInt(_key) ?? ThemeMode.system.index;
    _mode = ThemeMode.values[index.clamp(0, ThemeMode.values.length - 1)];
    notifyListeners();
  }

  /// Alterna entre claro e escuro (ignora "sistema" após o primeiro toque).
  Future<void> toggle(BuildContext context) async {
    final dark = isDark(context);
    await setMode(dark ? ThemeMode.light : ThemeMode.dark);
  }

  Future<void> setMode(ThemeMode mode) async {
    if (mode == _mode) return;
    _mode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_key, mode.index);
  }
}
