import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/models/medication.dart';
import '../state/app_state.dart';
import 'add_medication_page.dart';

class MedicationsPage extends StatelessWidget {
  const MedicationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final meds = app.medications;
    if (meds.isEmpty) {
      final colorScheme = Theme.of(context).colorScheme;
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.medication_outlined,
                size: 80,
                color: colorScheme.onSurface.withValues(alpha: 0.4),
              ),
              const SizedBox(height: 16),
              Text(
                'Nenhum medicamento cadastrado',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Toque no botão + para adicionar\nseu primeiro medicamento',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }
    final rootContext = context; // contexto estável do Scaffold/aba
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: meds.length,
      separatorBuilder: (_, i) => const SizedBox(height: 8),
      itemBuilder: (_, i) => _MedicationTile(
        meds[i],
        app.lowStockDaysThreshold,
        rootContext: rootContext,
      ),
    );
  }
}

class _MedicationTile extends StatelessWidget {
  final Medication m;
  final int lowStockDaysThreshold;
  final BuildContext rootContext;
  const _MedicationTile(
    this.m,
    this.lowStockDaysThreshold, {
    required this.rootContext,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final timesStr = m.times
        .map(
          (t) =>
              '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}',
        )
        .join(', ');
    final timesPerDay = m.times.isEmpty ? 0 : m.times.length;
    final thresholdUnits = timesPerDay > 0
        ? timesPerDay * lowStockDaysThreshold
        : 5;
    final isLow = m.stockUnits <= thresholdUnits;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isLow ? Colors.red.shade200 : colorScheme.outline,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Primeira linha: Nome + Menu de ações
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    m.name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                PopupMenuButton<String>(
                  tooltip: 'Mais ações',
                  iconColor: colorScheme.primary,
                  onSelected: (value) async {
                    if (value == 'edit') {
                      final result = await Navigator.of(context).push<String>(
                        MaterialPageRoute(
                          builder: (_) => AddMedicationPage(initial: m),
                        ),
                      );
                      if (result == 'updated' && context.mounted) {
                        ScaffoldMessenger.of(rootContext).showSnackBar(
                          SnackBar(
                            behavior: SnackBarBehavior.floating,
                            margin: const EdgeInsets.all(16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            backgroundColor: Theme.of(
                              context,
                            ).colorScheme.primaryContainer,
                            duration: const Duration(seconds: 2),
                            content: Row(
                              children: [
                                Icon(
                                  Icons.check_circle_outline,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onPrimaryContainer,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Medicamento atualizado',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onPrimaryContainer,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }
                    } else if (value == 'delete') {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Excluir medicamento'),
                          content: Text('Deseja excluir "${m.name}"?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(ctx).pop(false),
                              child: const Text('Cancelar'),
                            ),
                            FilledButton(
                              style: FilledButton.styleFrom(
                                backgroundColor: Theme.of(
                                  ctx,
                                ).colorScheme.error,
                              ),
                              onPressed: () => Navigator.of(ctx).pop(true),
                              child: const Text('Excluir'),
                            ),
                          ],
                        ),
                      );
                      if (confirmed == true && context.mounted) {
                        // Mostra o toast imediatamente
                        final theme = Theme.of(rootContext);
                        final messenger = ScaffoldMessenger.of(rootContext);
                        messenger.showSnackBar(
                          SnackBar(
                            behavior: SnackBarBehavior.floating,
                            margin: const EdgeInsets.all(16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            backgroundColor: theme.colorScheme.error,
                            duration: const Duration(seconds: 2),
                            content: Row(
                              children: [
                                Icon(
                                  Icons.delete_outline,
                                  color: theme.colorScheme.onError,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Medicamento excluído',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: theme.colorScheme.onError,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                        // Remove o medicamento
                        await context.read<AppState>().removeMedication(m.id);
                      }
                    }
                  },
                  itemBuilder: (ctx) => [
                    PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(
                            Icons.edit,
                            size: 20,
                            color: colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Editar',
                            style: TextStyle(color: colorScheme.primary),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(
                            Icons.delete,
                            size: 20,
                            color: colorScheme.error,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Excluir',
                            style: TextStyle(color: colorScheme.error),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            // Segunda linha: Chips de estoque
            if (isLow || m.stockUnits >= 0)
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  if (isLow)
                    Chip(
                      label: const Text('Estoque baixo'),
                      backgroundColor: colorScheme.errorContainer,
                      labelStyle: TextStyle(
                        color: colorScheme.onErrorContainer,
                        fontWeight: FontWeight.w600,
                        fontSize: 18,
                      ),
                      side: BorderSide(
                        color: colorScheme.error.withValues(alpha: 0.4),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 0,
                      ),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  Chip(
                    label: Text('Estoque: ${m.stockUnits}'),
                    backgroundColor: colorScheme.primaryContainer,
                    labelStyle: TextStyle(
                      color: colorScheme.onPrimaryContainer,
                      fontSize: 18,
                    ),
                    side: BorderSide(
                      color: colorScheme.primary.withValues(alpha: 0.4),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 0,
                    ),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ],
              ),
            const SizedBox(height: 8),
            Text(m.dosage),
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.access_time, size: 18, color: colorScheme.primary),
                const SizedBox(width: 6),
                Text(timesStr),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
