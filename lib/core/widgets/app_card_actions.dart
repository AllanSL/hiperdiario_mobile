import 'package:flutter/material.dart';

/// Define uma ação para o menu de ações do card.
class AppMenuAction {
  final String label;
  final IconData icon;
  final String value;
  final Color? color;
  final bool visible;

  AppMenuAction({
    required this.label,
    required this.icon,
    required this.value,
    this.color,
    this.visible = true,
  });
}

/// Widget padronizado para o menu de ações (três pontinhos) nos cards.
/// Garante que o efeito de clique preencha todo o espaço do item.
class AppCardActions extends StatelessWidget {
  final List<AppMenuAction> actions;
  final Function(String) onSelected;
  final Color? iconColor;

  const AppCardActions({
    super.key,
    required this.actions,
    required this.onSelected,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final visibleActions = actions.where((a) => a.visible).toList();

    if (visibleActions.isEmpty) return const SizedBox.shrink();

    return PopupMenuButton<String>(
      iconColor: iconColor ?? theme.colorScheme.primary,
      onSelected: onSelected,
      itemBuilder: (context) => visibleActions.map((action) {
        final itemColor = action.color ?? theme.colorScheme.primary;
        
        return PopupMenuItem<String>(
          value: action.value,
          padding: EdgeInsets.zero,
          height: 48,
          child: Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            alignment: Alignment.centerLeft,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(action.icon, size: 20, color: itemColor),
                const SizedBox(width: 12),
                Text(
                  action.label,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: itemColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
