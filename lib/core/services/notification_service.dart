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

  Future<void> init() async {
    if (kIsWeb) return; // Web: ignorar inicialização
    
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);
    await _plugin.initialize(initSettings);

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
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(medicationsChannel);
    
    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(remindersChannel);
    
    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
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
  // Agenda 1 dia antes e 1 hora antes
    final oneDayBefore = appt.dateTime.subtract(const Duration(days: 1));
    final oneHourBefore = appt.dateTime.subtract(const Duration(hours: 1));

    if (oneDayBefore.isAfter(DateTime.now())) {
      await _zonedSchedule(
        id: _randomId(),
        title: 'Consulta amanhã',
        body:
            'Você tem consulta em ${appt.location} às ${_fmtTime(appt.dateTime)}.',
        when: oneDayBefore,
      );
    }
    if (oneHourBefore.isAfter(DateTime.now())) {
      await _zonedSchedule(
        id: _randomId(),
        title: 'Consulta em 1 hora',
        body:
            'Não esqueça: consulta em ${appt.location} às ${_fmtTime(appt.dateTime)}.',
        when: oneHourBefore,
      );
    }
  }

  Future<void> scheduleMedicationReminders(Medication med) async {
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
    
    // Agenda lembretes para cada horário configurado
    // Agendando para os próximos 30 dias
    for (final time in med.times) {
      final now = DateTime.now();
      
      // Agenda para os próximos 30 dias
      for (int day = 0; day < 30; day++) {
        var scheduledDate = DateTime(now.year, now.month, now.day, time.hour, time.minute).add(Duration(days: day));
        
        // Só agenda se for no futuro
        if (scheduledDate.isAfter(now)) {
          try {
            await _zonedSchedule(
              id: _randomId(),
              title: 'Hora do remédio',
              body: '${med.name} — ${med.dosage}',
              when: scheduledDate,
              androidChannelId: 'medications',
            );
          } catch (e) {
            // Silenciosamente continua se houver erro
          }
        }
      }
    }
  }

  Future<void> _zonedSchedule({
    required int id,
    required String title,
    required String body,
    required DateTime when,
    String androidChannelId = 'reminders',
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
    );
  }

  int _randomId() => Random().nextInt(1 << 31);

  String _fmtTime(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
}
