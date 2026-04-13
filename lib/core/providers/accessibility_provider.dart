import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Níveis de escala de acessibilidade
enum AccessibilityScale {
  normal('Normal', 1.0),
  grande('Grande', 1.3),
  extraGrande('Extra Grande', 1.6);

  final String label;
  final double factor;
  const AccessibilityScale(this.label, this.factor);
}

/// Provider responsável pelas preferências de acessibilidade.
///
/// Persiste a escala escolhida via [SharedPreferences] e notifica
/// a árvore de widgets sempre que o usuário altera o modo.
class AccessibilityProvider extends ChangeNotifier {
  static const _key = 'accessibility_scale';

  AccessibilityScale _scale = AccessibilityScale.normal;
  AccessibilityScale get scale => _scale;

  /// Fator multiplicador atual (1.0 / 1.3 / 1.6)
  double get factor => _scale.factor;

  /// Indica se o modo de acessibilidade está ativo (qualquer escala acima de normal)
  bool get isAccessibilityMode => _scale != AccessibilityScale.normal;

  AccessibilityProvider() {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final index = prefs.getInt(_key) ?? 0;
    if (index >= 0 && index < AccessibilityScale.values.length) {
      _scale = AccessibilityScale.values[index];
      notifyListeners();
    }
  }

  Future<void> setScale(AccessibilityScale newScale) async {
    if (newScale == _scale) return;
    _scale = newScale;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_key, newScale.index);
  }

  // ─── Helpers de escala ─────────────────────────────────────────

  /// Retorna o valor escalado de um tamanho base (fonte, padding, ícone etc.)
  double scaled(double base) => base * _scale.factor;

  /// Retorna EdgeInsets escalados proporcionalmente
  EdgeInsets scaledPadding(EdgeInsets base) => EdgeInsets.only(
        left: base.left * _scale.factor,
        top: base.top * _scale.factor,
        right: base.right * _scale.factor,
        bottom: base.bottom * _scale.factor,
      );
}
