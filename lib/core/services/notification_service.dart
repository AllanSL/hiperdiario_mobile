import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/timezone.dart' as tz;

import '../models/appointment.dart';
import '../models/medication.dart';

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  final StreamController<String> _responseController =
      StreamController.broadcast();
  Stream<String> get onNotificationResponse => _responseController.stream;

  String? _launchNotificationPayload;

  // Mapeia medId -> lista de notification ids agendadas para esse medicamento
  final Map<String, List<int>> _medNotificationIds = {};

  Future<void> init() async {
    if (kIsWeb) return; // Web: ignorar inicialização

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);
    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (response) {
        try {
          final payload = response.payload;
          if (payload != null && payload.isNotEmpty) {
            _responseController.add(payload);
          }
        } catch (_) {}
      },
    );

    final details = await _plugin.getNotificationAppLaunchDetails();
    if (details?.didNotificationLaunchApp == true) {
      final payload = details?.notificationResponse?.payload;
      if (payload != null && payload.isNotEmpty) {
        _launchNotificationPayload = payload;
      }
    }

    // Criar canais de notificação no Android 8+
    if (defaultTargetPlatform == TargetPlatform.android) {
      await _createNotificationChannels();
      await Permission.notification.request();
      await Permission.scheduleExactAlarm.request();
    }
  }

  /// Cria os canais de notificação necessários
  Future<void> _createNotificationChannels() async {
    const medicationsChannel = AndroidNotificationChannel(
      'medications',
      'Lembretes de Medicamentos',
      description: 'Notificações para lembrar de tomar seus medicamentos',
      importance: Importance.high,
      enableVibration: true,
      playSound: true,
    );

    const remindersChannel = AndroidNotificationChannel(
      'reminders',
      'Lembretes de Consultas',
      description: 'Notificações sobre consultas agendadas',
      importance: Importance.high,
      enableVibration: true,
      playSound: true,
    );

    const testChannel = AndroidNotificationChannel(
      'test',
      'Testes',
      description: 'Canal para testar notificações',
      importance: Importance.high,
      enableVibration: true,
      playSound: true,
    );

    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(medicationsChannel);

    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(remindersChannel);

    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(testChannel);
  }

  /// Verifica se temos permissão para agendar alarmes exatos
  Future<bool> hasExactAlarmPermission() async {
    if (kIsWeb) return false;
    if (defaultTargetPlatform != TargetPlatform.android) return true;
    return await Permission.scheduleExactAlarm.isGranted;
  }

  /// Solicita permissão para alarmes exatos (abre configurações do sistema)
  Future<void> requestExactAlarmPermission() async {
    if (kIsWeb) return;
    if (defaultTargetPlatform != TargetPlatform.android) return;

    final status = await Permission.scheduleExactAlarm.request();

    // Se não foi concedida, abrir as configurações do sistema
    if (!status.isGranted) {
      await openAppSettings();
    }
  }

  Future<void> cancelAll() async {
    if (kIsWeb) return;
    await _plugin.cancelAll();
  }

  /// Retorna a payload da notificação que abriu o app e consome o valor.
  String? popLaunchNotificationPayload() {
    final payload = _launchNotificationPayload;
    _launchNotificationPayload = null;
    return payload;
  }

  /// Lista todas as notificações pendentes (para debug)
  Future<void> listPendingNotifications() async {
    if (kIsWeb) return;
    final pending = await _plugin.pendingNotificationRequests();
    print('🔔 [NotificationService] Notificações pendentes: ${pending.length}');
    for (final notif in pending) {
      print('  - ID: ${notif.id}, Title: ${notif.title}, Body: ${notif.body}');
    }
  }

  /// Envia uma notificação de teste imediata (para verificar se notificações funcionam)
  Future<void> showTestNotification() async {
    if (kIsWeb) return;

    await _plugin.show(
      999999,
      'Teste de Notificação',
      'Se você viu esta notificação, o sistema está funcionando! ✅',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'test',
          'test',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
    );
  }

  /// Testa notificação agendada (15 segundos no futuro)
  Future<void> showScheduledTestNotification() async {
    if (kIsWeb) return;

    // Verificar permissão primeiro
    final hasPermission = await hasExactAlarmPermission();

    if (!hasPermission) {
      await requestExactAlarmPermission();

      // Verificar novamente
      final hasPermissionNow = await hasExactAlarmPermission();
      if (!hasPermissionNow) {
        return;
      }
    }

    final scheduledTime = DateTime.now().add(const Duration(seconds: 15));
    final tzTime = tz.TZDateTime.from(scheduledTime, tz.local);

    await _plugin.zonedSchedule(
      888888,
      'Teste ZonedSchedule',
      'Notificação agendada com zonedSchedule + exact mode ⏰',
      tzTime,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'test',
          'test',
          importance: Importance.max,
          priority: Priority.max,
          enableVibration: true,
          playSound: true,
          channelShowBadge: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exact,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  Future<void> scheduleAppointmentReminders(Appointment appt) async {
    // Web não suporta flutter_local_notifications
    if (kIsWeb) return;
    // Agenda 1 dia antes e 1 hora antes, usando um horário-base do turno.
    final appointmentDateTime = _appointmentDateTimeForShift(appt);
    final oneDayBefore = appointmentDateTime.subtract(const Duration(days: 1));
    final oneHourBefore = appointmentDateTime.subtract(
      const Duration(hours: 1),
    );

    if (oneDayBefore.isAfter(DateTime.now())) {
      await _zonedSchedule(
        id: _randomId(),
        title: 'Consulta amanhã',
        body:
            'Você tem consulta em ${appt.location} às ${_fmtTime(appointmentDateTime)}.',
        when: oneDayBefore,
      );
    }
    if (oneHourBefore.isAfter(DateTime.now())) {
      await _zonedSchedule(
        id: _randomId(),
        title: 'Consulta em 1 hora',
        body:
            'Não esqueça: consulta em ${appt.location} às ${_fmtTime(appointmentDateTime)}.',
        when: oneHourBefore,
      );
    }
  }

  DateTime _appointmentDateTimeForShift(Appointment appt) {
    final hour = switch (appt.shift) {
      AppointmentShift.morning => 8,
      AppointmentShift.afternoon => 13,
    };
    return DateTime(
      appt.dateTime.year,
      appt.dateTime.month,
      appt.dateTime.day,
      hour,
      0,
    );
  }

  Future<void> scheduleMedicationReminders(Medication med) async {
    await scheduleAllMedicationReminders([med]);
  }

  Future<void> scheduleAllMedicationReminders(List<Medication> meds) async {
    if (kIsWeb) return;
    if (meds.isEmpty) return;

    final availableMeds = meds.where((m) => m.stockUnits > 0).toList();
    if (availableMeds.isEmpty) return;

    final hasPermission = await hasExactAlarmPermission();
    if (!hasPermission) {
      await requestExactAlarmPermission();
      if (!await hasExactAlarmPermission()) {
        return;
      }
    }

    final grouped = _groupMedicationsByTime(availableMeds);
    final now = DateTime.now();
    _medNotificationIds.clear();

    for (final group in grouped.values) {
      final timeLabel = _fmtTime(
        DateTime(
          now.year,
          now.month,
          now.day,
          group.time.hour,
          group.time.minute,
        ),
      );
      final medsAtTime = group.meds;
      for (int day = 0; day < 30; day++) {
        final scheduledDate = DateTime(
          now.year,
          now.month,
          now.day,
          group.time.hour,
          group.time.minute,
        ).add(Duration(days: day));
        if (!scheduledDate.isAfter(now)) continue;

        try {
          final id = _randomId();
          final body = medsAtTime.length == 1
              ? medsAtTime.first.name
              : medsAtTime.map((m) => m.name).join(', ');
          await _zonedSchedule(
            id: id,
            title: 'Hora do remédio',
            body: body,
            when: scheduledDate,
            androidChannelId: 'medications',
            payload: jsonEncode({
              'type': 'med_reminder',
              'medIds': medsAtTime.map((m) => m.id).toList(),
              'scheduledTime': timeLabel,
            }),
          );
          for (final med in medsAtTime) {
            _medNotificationIds.putIfAbsent(med.id, () => []).add(id);
          }
        } catch (e) {
          // Silenciosamente continua se houver erro
        }
      }
    }
  }

  Map<String, _MedicationGroup> _groupMedicationsByTime(List<Medication> meds) {
    final groups = <String, _MedicationGroup>{};
    for (final med in meds) {
      for (final time in med.times) {
        final key =
            '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
        groups.putIfAbsent(key, () => _MedicationGroup(time, [])).meds.add(med);
      }
    }
    return groups;
  }

  Future<void> _zonedSchedule({
    required int id,
    required String title,
    required String body,
    required DateTime when,
    String androidChannelId = 'reminders',
    String? payload,
  }) async {
    final tzTime = tz.TZDateTime.from(when, tz.local);

    await _plugin.zonedSchedule(
      id,
      title,
      body,
      tzTime,
      NotificationDetails(
        android: AndroidNotificationDetails(
          androidChannelId,
          androidChannelId,
          importance: Importance.max,
          priority: Priority.max,
          channelShowBadge: true,
          enableLights: true,
          enableVibration: true,
          playSound: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exact,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: payload,
    );
  }

  Future<void> cancelMedicationNotifications(String medId) async {
    await cancelAll();
  }

  int _randomId() => Random().nextInt(1 << 31);

  String _fmtTime(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
}

class _MedicationGroup {
  final TimeOfDayLite time;
  final List<Medication> meds;

  _MedicationGroup(this.time, this.meds);
}
