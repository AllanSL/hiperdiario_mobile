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
    final pendings = app.pendingDispensations;

    if (meds.isEmpty && pendings.isEmpty) {
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
                'Toque no botão + para adicionar\nseu primeiro medicamento ou aguarde uma retirada na UBS.',
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

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        if (pendings.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0, left: 4),
            child: Text(
              'Retiradas Pendentes (SUS)',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
          ...pendings.map(
            (p) => Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: _PendingDispensationTile(p, rootContext: rootContext),
            ),
          ),
          const SizedBox(height: 16),
          if (meds.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0, left: 4),
              child: Text(
                'Meus Medicamentos',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
        ],
        ...meds.map(
          (m) => Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: _MedicationTile(
              m,
              app.lowStockDaysThreshold,
              rootContext: rootContext,
            ),
          ),
        ),
      ],
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
    final isDisabled = m.stockUnits <= 0;

    return Card(
      elevation: 0,
      color: isDisabled
          ? Theme.of(context).colorScheme.surfaceContainerHighest
          : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isDisabled
              ? Theme.of(context).colorScheme.onSurfaceVariant.withAlpha(80)
              : (isLow ? Colors.red.shade200 : colorScheme.outline),
        ),
      ),
      child: Opacity(
        opacity: isDisabled ? 0.5 : 1.0,
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
                    child: Row(
                      children: [
                        Flexible(
                          child: Text(
                            m.name,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ),
                        if (m.dispensationId != null) ...[
                          const SizedBox(width: 8),
                          Tooltip(
                            message: 'Medicamento retirado no SUS',
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: colorScheme.primaryContainer,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'SUS',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: colorScheme.onPrimaryContainer,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
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
                      } else if (value == 'delete' &&
                          m.dispensationId == null) {
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
                      if (m.dispensationId == null)
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
                        label: Text('Estoque baixo'),
                        backgroundColor: colorScheme.errorContainer,
                        labelStyle: Theme.of(context).textTheme.labelLarge
                            ?.copyWith(
                              color: colorScheme.onErrorContainer,
                              fontWeight: FontWeight.w600,
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
                      label: Text(
                        m.stockUnits > 0
                            ? 'Estoque: ${m.stockUnits}'
                            : 'Sem estoque',
                      ),
                      backgroundColor: colorScheme.primaryContainer,
                      labelStyle: Theme.of(context).textTheme.labelLarge
                          ?.copyWith(color: colorScheme.onPrimaryContainer),
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
      ),
    );
  }
}

class _PendingDispensationTile extends StatelessWidget {
  final PendingDispensation p;
  final BuildContext rootContext;

  const _PendingDispensationTile(this.p, {required this.rootContext});

  void _showAcknowledgeDialog(BuildContext context) {
    showModalBottomSheet<void>(
      context: rootContext,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: _AcknowledgeDispensationSheet(dispensation: p),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      color: colorScheme.primaryContainer.withValues(alpha: 0.5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: colorScheme.primary.withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.local_pharmacy,
                  color: colorScheme.primary,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${p.activePrinciple} ${p.strength}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Retirado na farmácia. Você recebeu ${p.dispensedQuantity} unidades. Configure os horários para continuar.',
              style: TextStyle(
                fontSize: 14,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                icon: const Icon(Icons.alarm_add, size: 18),
                label: const Text('Configurar lembretes'),
                onPressed: () => _showAcknowledgeDialog(context),
                style: FilledButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  foregroundColor: colorScheme.onPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AcknowledgeDispensationSheet extends StatefulWidget {
  final PendingDispensation dispensation;
  const _AcknowledgeDispensationSheet({required this.dispensation});

  @override
  State<_AcknowledgeDispensationSheet> createState() =>
      _AcknowledgeDispensationSheetState();
}

class _AcknowledgeDispensationSheetState
    extends State<_AcknowledgeDispensationSheet> {
  bool _isSaving = false;
  final List<TimeOfDayLite> _times = [];

  List<TimeOfDayLite> _generateFromBase(TimeOfDayLite base, int n) {
    final interval = 24 * 60 / n;
    final baseMinutes = base.hour * 60 + base.minute;
    final res = <TimeOfDayLite>[];
    for (var i = 0; i < n; i++) {
      final minutes = (baseMinutes + (interval * i)).round() % (24 * 60);
      final h = minutes ~/ 60;
      final m = minutes % 60;
      res.add(TimeOfDayLite(h, m));
    }
    return res;
  }

  @override
  void initState() {
    super.initState();
    final d = widget.dispensation;
    final n = d.frequencyPerDay <= 0 ? 1 : d.frequencyPerDay;

    if (d.scheduledTimes.isNotEmpty) {
      final parsed = <TimeOfDayLite>[];
      for (final timeStr in d.scheduledTimes) {
        final parts = timeStr.split(':');
        if (parts.length >= 2) {
          final h = int.tryParse(parts[0]) ?? 0;
          final m = int.tryParse(parts[1]) ?? 0;
          parsed.add(TimeOfDayLite(h, m));
        }
      }
      if (parsed.isNotEmpty) {
        if (parsed.length == n) {
          parsed.sort(
            (a, b) => a.hour != b.hour ? a.hour - b.hour : a.minute - b.minute,
          );
          _times.addAll(parsed);
        } else {
          // Use first provided as base and generate remaining automatically
          final base = parsed.first;
          _times.addAll(_generateFromBase(base, n));
        }
      }
    }
  }

  Future<void> _pickTime([int? editIndex]) async {
    final initial = editIndex != null && _times.length > editIndex
        ? TimeOfDay(
            hour: _times[editIndex].hour,
            minute: _times[editIndex].minute,
          )
        : const TimeOfDay(hour: 8, minute: 0);

    final t = await showTimePicker(
      context: context,
      initialTime: initial,
      initialEntryMode: TimePickerEntryMode.input,
    );
    if (t == null) return;

    final lite = TimeOfDayLite(t.hour, t.minute);
    final d = widget.dispensation;
    final n = d.frequencyPerDay <= 0 ? 1 : d.frequencyPerDay;

    if (_times.isEmpty) {
      // First time defined by user -> generate full schedule
      setState(() {
        _times.clear();
        _times.addAll(_generateFromBase(lite, n));
      });
      return;
    }

    // Editing an existing time (no deletion allowed). If editing index 0, regenerate others.
    if (editIndex == 0) {
      setState(() {
        _times.clear();
        _times.addAll(_generateFromBase(lite, n));
      });
      return;
    }

    if (editIndex != null && editIndex >= 0 && editIndex < _times.length) {
      setState(() {
        _times[editIndex] = lite;
        _times.sort(
          (a, b) => a.hour != b.hour ? a.hour - b.hour : a.minute - b.minute,
        );
      });
    }
  }

  String _fmt(TimeOfDayLite t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  void _save() async {
    final d = widget.dispensation;
    if (_times.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Defina o primeiro horário para ativar os alarmes'),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    final freqStr = d.frequencyLabel ?? '${d.frequencyPerDay}x ao dia';
    final finalDosage = '${d.strength} (${d.form}) $freqStr';

    try {
      await context.read<AppState>().acknowledgeDispensation(
        widget.dispensation,
        List.of(_times),
        finalDosage,
      );
      if (mounted) {
        Navigator.of(context).pop();
        final theme = Theme.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            backgroundColor: theme.colorScheme.primaryContainer,
            duration: const Duration(seconds: 2),
            content: Row(
              children: [
                Icon(
                  Icons.check_circle_outline,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Medicamento da UBS sincronizado e alarmes ativados!',
                    style: TextStyle(
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erro: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.dispensation;

    final freqStr = d.frequencyLabel ?? '${d.frequencyPerDay}x ao dia';

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Pendência (SUS)',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text('${d.activePrinciple} - ${d.dispensedQuantity} un. recebidas.'),
          const SizedBox(height: 12),
          // const SizedBox(height: 2),
          if (_times.isNotEmpty) ...[
            Text(
              'Frequência indicada: $freqStr',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            // const SizedBox(height: 2),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _times
                  .asMap()
                  .entries
                  .map(
                    (e) => ActionChip(
                      label: Text(_fmt(e.value)),
                      onPressed: () => _pickTime(e.key),
                    ),
                  )
                  .toList(),
            ),
          ],
          if (_times.isEmpty) ...[
            FilledButton.icon(
              icon: const Icon(Icons.access_time),
              label: const Text('Definir lembretes'),
              onPressed: () => _pickTime(),
            ),
            const SizedBox(height: 16),
          ] else ...[
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  setState(() {
                    _times.clear();
                  });
                },
                icon: const Icon(Icons.clear),
                label: const Text('Limpar horários'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _isSaving ? null : _save,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
              child: _isSaving
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Salvar'),
            ),
          ],
        ],
      ),
    );
  }
}
