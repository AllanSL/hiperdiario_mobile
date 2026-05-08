import 'package:flutter/material.dart';

/// Utilitário para exibição de SnackBars padronizados no HiperDiário.
class AppSnackBar {
  /// Exibe um SnackBar de sucesso ou erro.
  static void show(
    BuildContext context,
    String message, {
    bool isError = false,
  }) {
    if (!context.mounted) return;
    
    final colorScheme = Theme.of(context).colorScheme;
    
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: isError
            ? colorScheme.errorContainer
            : colorScheme.primaryContainer,
        duration: const Duration(seconds: 4),
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: isError
                  ? colorScheme.onErrorContainer
                  : colorScheme.onPrimaryContainer,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: isError
                      ? colorScheme.onErrorContainer
                      : colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Atalho para SnackBar de erro.
  static void showError(BuildContext context, String message) {
    show(context, message, isError: true);
  }

  /// Atalho para SnackBar de sucesso.
  static void showSuccess(BuildContext context, String message) {
    show(context, message, isError: false);
  }
}
