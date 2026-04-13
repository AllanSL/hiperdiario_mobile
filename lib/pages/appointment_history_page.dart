import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../core/models/appointment.dart';
import '../state/app_state.dart';

class AppointmentHistoryPage extends StatelessWidget {
  const AppointmentHistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final allAppointments = context.watch<AppState>().appointments;

    // Filtrar apenas consultas passadas
    final now = DateTime.now();
    final pastAppointments =
        allAppointments.where((appt) => appt.dateTime.isBefore(now)).toList()
          ..sort(
            (a, b) => b.dateTime.compareTo(a.dateTime),
          ); // Mais recentes primeiro

    return Scaffold(
      appBar: AppBar(title: const Text('Histórico de Consultas')),
      body: pastAppointments.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.history,
                      size: 80,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.4),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Sem histórico de consultas',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Consultas passadas aparecerão aqui',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: pastAppointments.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, index) {
                final appt = pastAppointments[index];
                return _HistoryCard(appointment: appt);
              },
            ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  final Appointment appointment;

  const _HistoryCard({required this.appointment});

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd/MM/yyyy');
    final timeFormat = DateFormat('HH:mm');

    Color statusColor;
    IconData statusIcon;
    String statusText;

    if (appointment.attended == true) {
      statusColor = Colors.green;
      statusIcon = Icons.check_circle;
      statusText = 'Compareceu';
    } else if (appointment.attended == false) {
      statusColor = Colors.red;
      statusIcon = Icons.cancel;
      statusText = 'Não compareceu';
    } else {
      statusColor = Colors.grey;
      statusIcon = Icons.help_outline;
      statusText = 'Não registrado';
    }

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cabeçalho: Data e Hora
            Row(
              children: [
                Icon(
                  Icons.calendar_today,
                  color: Colors.grey.shade600,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  dateFormat.format(appointment.dateTime),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 16),
                Icon(Icons.access_time, color: Colors.grey.shade600, size: 18),
                const SizedBox(width: 8),
                Text(
                  timeFormat.format(appointment.dateTime),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const Divider(height: 20),

            // Especialidade
            Row(
              children: [
                const Icon(
                  Icons.medical_services,
                  size: 18,
                  color: Colors.grey,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    appointment.specialty,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),

            // Local
            Row(
              children: [
                const Icon(Icons.location_on, size: 18, color: Colors.grey),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    appointment.location,
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
                  ),
                ),
              ],
            ),

            // Observações
            if (appointment.notes != null && appointment.notes!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.note, size: 18, color: Colors.grey),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      appointment.notes!,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            ],

            const Divider(height: 20),

            // Status de comparecimento
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: statusColor.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(statusIcon, color: statusColor, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    statusText,
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (appointment.attended == null) ...[
                    const Spacer(),
                    TextButton(
                      onPressed: () => _showAttendanceDialog(context),
                      child: const Text('Registrar'),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAttendanceDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Registrar Comparecimento'),
        content: const Text('Você compareceu a esta consulta?'),
        actions: [
          TextButton(
            onPressed: () {
              context.read<AppState>().markAppointmentAttendance(
                appointment.id,
                false,
              );
              Navigator.pop(context);
            },
            child: const Text('Não'),
          ),
          FilledButton(
            onPressed: () {
              context.read<AppState>().markAppointmentAttendance(
                appointment.id,
                true,
              );
              Navigator.pop(context);
            },
            child: const Text('Sim'),
          ),
        ],
      ),
    );
  }
}
