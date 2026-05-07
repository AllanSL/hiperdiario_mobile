import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/models/appointment.dart';
import '../../core/services/cnes_service.dart';
import '../../state/app_state.dart';
import 'NovaConsulta.dart';

class AppointmentsPage extends StatelessWidget {
  const AppointmentsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final allAppointments = context.watch<AppState>().appointments;
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    // Filtrar apenas consultas futuras
    final now = DateTime.now();
    final upcomingAppointments =
        allAppointments.where((appt) {
          final date = appt.dateTime;
          return date.isAfter(now) ||
              (date.year == now.year &&
                  date.month == now.month &&
                  date.day == now.day);
        }).toList()..sort((a, b) {
          final dateCmp = a.dateTime.compareTo(b.dateTime);
          if (dateCmp != 0) return dateCmp;
          return _shiftOrder(a.shift).compareTo(_shiftOrder(b.shift));
        });

    if (upcomingAppointments.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.event_available,
                size: 80,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
              ),
              const SizedBox(height: 16),
              Text(
                'Nenhuma consulta agendada',
                style: textTheme.titleLarge?.copyWith(
                  color: theme.colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Toque no botão + para agendar\numa consulta',
                style: textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: upcomingAppointments.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (_, index) {
        final appt = upcomingAppointments[index];
        return _AppointmentCard(appointment: appt, rootContext: context);
      },
    );
  }
}

class _AppointmentCard extends StatelessWidget {
  final Appointment appointment;
  final BuildContext rootContext;

  const _AppointmentCard({
    required this.appointment,
    required this.rootContext,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final colorScheme = theme.colorScheme;
    final iconSize = theme.iconTheme.size ?? 24;
    final smallIconSize = iconSize * 0.75; // ~18 em escala normal

    final dateFormat = DateFormat('dd/MM/yyyy');
    final now = DateTime.now();
    final isToday =
        appointment.dateTime.year == now.year &&
        appointment.dateTime.month == now.month &&
        appointment.dateTime.day == now.day;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isToday
              ? Colors.orange
              : Theme.of(context).colorScheme.outline,
          width: isToday ? 2 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cabeçalho: Data e Hora — layout responsivo com Wrap
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.calendar_today,
                            color: isToday
                                ? Colors.orange
                                : colorScheme.primary,
                            size: smallIconSize,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            dateFormat.format(appointment.dateTime),
                            style: textTheme.titleMedium?.copyWith(
                              color: isToday
                                  ? Colors.orange
                                  : colorScheme.onSurface,
                            ),
                          ),
                          if (isToday) ...[
                            const SizedBox(width: 8),
                            _Badge(
                              label: 'HOJE',
                              color: Colors.orange,
                              filled: true,
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _Badge(
                            label: 'TURNO: ${appointment.shift.label}',
                            color: colorScheme.onSurfaceVariant,
                            filled: true,
                            stadium: true,
                          ),
                          const SizedBox(width: 8),
                          _StatusBadge(appointment: appointment),
                        ],
                      ),
                    ],
                  ),
                ),
                PopupMenuButton(
                  iconColor: colorScheme.primary,
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(
                            Icons.edit,
                            size: smallIconSize,
                            color: colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Editar',
                            style: textTheme.bodyMedium?.copyWith(
                              color: colorScheme.primary,
                            ),
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
                            size: smallIconSize,
                            color: colorScheme.error,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Excluir',
                            style: textTheme.bodyMedium?.copyWith(
                              color: colorScheme.error,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  onSelected: (value) async {
                    if (value == 'edit') {
                      final result = await Navigator.push<String>(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              AddAppointmentPage(appointment: appointment),
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
                              rootContext,
                            ).colorScheme.primaryContainer,
                            duration: const Duration(seconds: 2),
                            content: Row(
                              children: [
                                Icon(
                                  Icons.check_circle_outline,
                                  color: Theme.of(
                                    rootContext,
                                  ).colorScheme.onPrimaryContainer,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Consulta atualizada com sucesso',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: Theme.of(
                                        rootContext,
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
                      _confirmDelete(context, rootContext);
                    }
                  },
                ),
              ],
            ),
            const Divider(height: 24),

            // Especialidade e Profissional
            Row(
              children: [
                Icon(
                  Icons.medical_services,
                  size: smallIconSize,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (appointment.professionalName != null)
                        Text(
                          appointment.professionalName!.toUpperCase(),
                          style: textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurface,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      Text(
                        appointment.specialty.toUpperCase(),
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Local
            Row(
              children: [
                Icon(
                  Icons.location_on,
                  size: smallIconSize,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    formatCnesDisplayName(
                      appointment.location ==
                              context.read<AppState>().patient?.ubs
                          ? (context.read<AppState>().patient?.ubsName ??
                                appointment.location)
                          : appointment.location,
                    ),
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),

            // Observações
            if (appointment.notes != null && appointment.notes!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.note,
                    size: smallIconSize,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      appointment.notes!,
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, BuildContext rootContext) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir Consulta'),
        content: const Text('Tem certeza que deseja excluir esta consulta?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              context.read<AppState>().removeAppointment(appointment.id);
              Navigator.pop(context);
              ScaffoldMessenger.of(rootContext).showSnackBar(
                SnackBar(
                  behavior: SnackBarBehavior.floating,
                  margin: const EdgeInsets.all(16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  backgroundColor: Theme.of(rootContext).colorScheme.error,
                  duration: const Duration(seconds: 2),
                  content: Row(
                    children: [
                      Icon(
                        Icons.delete_outline,
                        color: Theme.of(rootContext).colorScheme.onError,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Consulta excluída',
                          style: TextStyle(
                            color: Theme.of(rootContext).colorScheme.onError,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
  }
}

int _shiftOrder(AppointmentShift shift) {
  return switch (shift) {
    AppointmentShift.morning => 0,
    AppointmentShift.afternoon => 1,
  };
}

class _StatusBadge extends StatelessWidget {
  final Appointment appointment;

  const _StatusBadge({required this.appointment});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    final status = appointment.status?.toLowerCase() ?? '';
    final shift = appointment.shift;
    final now = DateTime.now();

    String label = 'Agendada';
    Color color = Colors.grey;

    // Lógica de "Faltou" por tempo expirado (mesma da Web)
    bool isMissed = false;
    final aptDate = appointment.dateTime;
    final today = DateTime(now.year, now.month, now.day);
    final checkDate = DateTime(aptDate.year, aptDate.month, aptDate.day);

    if (status == 'scheduled' || status == '') {
      if (checkDate.isBefore(today)) {
        isMissed = true;
      } else if (checkDate.isAtSameMomentAs(today)) {
        if (shift == AppointmentShift.morning && now.hour >= 13) {
          isMissed = true;
        } else if (shift == AppointmentShift.afternoon && now.hour >= 17) {
          isMissed = true;
        }
      }
    }

    if (isMissed || status == 'missed' || status == 'faltou') {
      label = 'Faltou';
      color = Colors.red;
    } else if (status == 'attended' || status == 'compareceu') {
      label = 'Atendido';
      color = Colors.green;
    } else if (status == 'checked_in' || status.contains('fila')) {
      label = 'Na Fila';
      color = Colors.blue;
    } else if (status == 'in_progress') {
      label = 'Em Atendimento';
      color = Colors.amber;
    } else if (status == 'cancel') {
      label = 'Cancelada';
      color = Colors.orange;
    }

    final f = (theme.iconTheme.size ?? 24.0) / 24.0;

    return _Badge(
      label: label,
      color: color,
      stadium: true,
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  final bool filled;
  final bool stadium;

  const _Badge({
    required this.label,
    required this.color,
    this.filled = false,
    this.stadium = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final f = (theme.iconTheme.size ?? 24.0) / 24.0;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8 * f, vertical: 4 * f),
      decoration: BoxDecoration(
        color: filled
            ? (stadium ? theme.colorScheme.surfaceContainerHighest : color)
            : color.withValues(alpha: 0.1),
        borderRadius: stadium
            ? BorderRadius.circular(100)
            : BorderRadius.circular(8 * f),
        border: Border.all(
          color: stadium
              ? Colors.transparent
              : (filled ? color : color.withValues(alpha: 0.8)),
          width: 1 * f,
        ),
      ),
      child: Text(
        label.toUpperCase(),
        style: textTheme.labelMedium?.copyWith(
          color: stadium
              ? theme.colorScheme.onSurfaceVariant
              : (filled ? Colors.white : color),
          fontWeight: FontWeight.bold,
          fontSize: (textTheme.labelMedium?.fontSize ?? 14) * 0.7,
        ),
      ),
    );
  }
}
