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
                        ],
                      ),
                      const SizedBox(height: 8),
                      Chip(
                        visualDensity: VisualDensity.compact,
                        label: Text('Turno: ${appointment.shift.label}'),
                      ),
                    ],
                  ),
                ),
                if (isToday)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.orange,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'HOJE',
                      style: textTheme.labelSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
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

            if (appointment.attended != null) ...[
              const Divider(height: 24),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: appointment.attended!
                      ? Colors.green.shade50
                      : Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: appointment.attended!
                        ? Colors.green.shade300
                        : Colors.red.shade300,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      appointment.attended! ? Icons.check_circle : Icons.cancel,
                      color: appointment.attended! ? Colors.green : Colors.red,
                      size: smallIconSize,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        appointment.attended! ? 'Compareceu' : 'Não compareceu',
                        style: textTheme.bodyMedium?.copyWith(
                          color: appointment.attended!
                              ? Colors.green.shade900
                              : Colors.red.shade900,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
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
