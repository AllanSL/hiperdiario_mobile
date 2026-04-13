import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../core/models/appointment.dart';
import '../state/app_state.dart';
import 'add_appointment_page.dart';

class AppointmentsPage extends StatelessWidget {
  const AppointmentsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final allAppointments = context.watch<AppState>().appointments;
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final iconSize = theme.iconTheme.size ?? 24;

    // Filtrar apenas consultas futuras
    final now = DateTime.now();
    final upcomingAppointments =
        allAppointments.where((appt) => appt.dateTime.isAfter(now)).toList()
          ..sort((a, b) => a.dateTime.compareTo(b.dateTime));

    if (upcomingAppointments.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
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
      padding: const EdgeInsets.all(16),
      itemCount: upcomingAppointments.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
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
    final timeFormat = DateFormat('HH:mm');
    final now = DateTime.now();
    final isPast = appointment.dateTime.isBefore(now);
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
                  child: Wrap(
                    spacing: 16,
                    runSpacing: 8,
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
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.access_time,
                            color: isToday
                                ? Colors.orange
                                : colorScheme.primary,
                            size: smallIconSize,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            timeFormat.format(appointment.dateTime),
                            style: textTheme.titleMedium?.copyWith(
                              color: isToday
                                  ? Colors.orange
                                  : colorScheme.onSurface,
                            ),
                          ),
                        ],
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

            // Especialidade
            Row(
              children: [
                Icon(
                  Icons.medical_services,
                  size: smallIconSize,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    appointment.specialty,
                    style: textTheme.titleMedium,
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
                    appointment.location,
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

            // Botões de comparecimento (se a consulta já passou e ainda não foi marcada)
            if (isPast && appointment.attended == null) ...[
              const Divider(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        context.read<AppState>().markAppointmentAttendance(
                          appointment.id,
                          false,
                        );
                        ScaffoldMessenger.of(rootContext).showSnackBar(
                          SnackBar(
                            behavior: SnackBarBehavior.floating,
                            margin: const EdgeInsets.all(16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            backgroundColor: Theme.of(
                              rootContext,
                            ).colorScheme.error,
                            duration: const Duration(seconds: 2),
                            content: Row(
                              children: [
                                Icon(
                                  Icons.cancel_outlined,
                                  color: Theme.of(
                                    rootContext,
                                  ).colorScheme.onError,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Marcado como: Não compareceu',
                                    style: TextStyle(
                                      color: Theme.of(
                                        rootContext,
                                      ).colorScheme.onError,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                      icon: Icon(Icons.close, size: smallIconSize),
                      label: const Text('Faltou'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () {
                        context.read<AppState>().markAppointmentAttendance(
                          appointment.id,
                          true,
                        );
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
                                    'Marcado como: Compareceu ✓',
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
                      },
                      icon: Icon(Icons.check, size: smallIconSize),
                      label: const Text('Compareceu'),
                      style: FilledButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Theme.of(
                          context,
                        ).colorScheme.onPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ],

            // Status de comparecimento
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
