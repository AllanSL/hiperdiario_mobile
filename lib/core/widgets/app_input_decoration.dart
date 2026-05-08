import 'package:flutter/material.dart';

class AppInputDecoration {
  static InputDecoration build(
    BuildContext context, {
    String? labelText,
    String? hintText,
    Widget? prefixIcon,
    Widget? suffixIcon,
    bool enabled = true,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(14);

    OutlineInputBorder border(Color color, {double width = 1}) {
      return OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: color, width: width),
      );
    }

    return InputDecoration(
      labelText: labelText,
      hintText: hintText,
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: enabled
          ? colorScheme.surface
          : colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      border: border(colorScheme.outlineVariant),
      enabledBorder: border(colorScheme.outlineVariant),
      disabledBorder: border(colorScheme.outlineVariant.withValues(alpha: 0.5)),
      focusedBorder: border(colorScheme.primary, width: 1.4),
      errorBorder: border(colorScheme.error),
      focusedErrorBorder: border(colorScheme.error, width: 1.4),
    );
  }
}
