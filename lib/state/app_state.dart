import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/services/notification_service.dart';
import '../core/models/appointment.dart';
import '../core/models/emergency_contact.dart';
import '../core/models/medication.dart';
import '../core/models/patient.dart';
import '../core/services/ibge_service.dart';
import '../core/services/municipio_service.dart';
import '../core/services/cnes_service.dart';

class AppState extends ChangeNotifier {
  bool _isLogged = false;
  bool _isAuthenticating = false;
  Patient? _patient;
  List<Appointment> _appointments = [];
  List<Medication> _medications = [];
  List<PendingDispensation> _pendingDispensations = [];
  int _lowStockDaysThreshold =
      2; // dias de doses restantes para considerar estoque baixo

  bool get isLogged => _isLogged && !_isAuthenticating;
  Patient? get patient => _patient;
  List<Appointment> get appointments => List.unmodifiable(_appointments);
  List<Medication> get medications => List.unmodifiable(_medications);
  List<PendingDispensation> get pendingDispensations =>
      List.unmodifiable(_pendingDispensations);
  int get lowStockDaysThreshold => _lowStockDaysThreshold;

  final SupabaseClient _supabase = Supabase.instance.client;
  Timer? _syncTimer;

  AppState() {
    // Check initial session
    _isLogged = _supabase.auth.currentSession != null;
    if (_isLogged) {
      _loadDataAndSchedule();
      _startSyncTimer();
    }

    // Listen to auth changes
    _supabase.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.initialSession) return;

      final session = data.session;
      final isNowLogged = session != null;
      if (_isLogged != isNowLogged) {
        _isLogged = isNowLogged;
        if (!_isLogged) {
          _patient = null;
          _appointments = [];
          _medications = [];
          _pendingDispensations = [];
          _stopSyncTimer();
        } else {
          _loadDataAndSchedule();
          _startSyncTimer();
        }
        notifyListeners();
      }
    });
  }

  void _startSyncTimer() {
    _stopSyncTimer();
    _syncTimer = Timer.periodic(const Duration(minutes: 10), (_) {
      _loadDataAndSchedule();
    });
  }

  void _stopSyncTimer() {
    _syncTimer?.cancel();
    _syncTimer = null;
  }

  @override
  void dispose() {
    _stopSyncTimer();
    super.dispose();
  }

  Future<void> loginWithCpfPassword(String cpf, String password) async {
    final cleanCpf = cpf.replaceAll(RegExp(r'\D'), '');
    if (!_isValidCpf(cleanCpf)) {
      throw Exception('CPF inválido. Verifique e tente novamente.');
    }
    final email = _cpfToEmail(cleanCpf);
    _isAuthenticating = true;
    notifyListeners();

    try {
      await _supabase.auth.signInWithPassword(email: email, password: password);

      // Verifica se o usuário autenticado possui um perfil de paciente
      final user = _supabase.auth.currentUser;
      if (user != null) {
        final patientExists = await _supabase
            .from('patients')
            .select('id')
            .eq('remote_id', user.id)
            .maybeSingle();

        if (patientExists == null) {
          // Verifica se é um profissional (para dar erro específico)
          final profExists = await _supabase
              .from('professionals')
              .select('user_id')
              .eq('user_id', user.id)
              .maybeSingle();

          if (profExists != null) {
            await logout();
            throw Exception(
              'Acesso negado. Este aplicativo é exclusivo para pacientes.',
            );
          }
        }
      }
    } finally {
      _isAuthenticating = false;
      notifyListeners();
    }
  }

  Future<void> signUpWithCpfPassword({
    required String cpf,
    required String password,
    required String name,
    String? birthDate,
    String? gender,
    List<String> diseases = const <String>[],
    String? phone,
    String? email,
    String? emergencyContactName,
    String? emergencyContactPhone,
    String? emergencyContactRelationship,
    String? uf,
    String? municipioIbge,
    String? ubsCnes,
  }) async {
    final cleanCpf = cpf.replaceAll(RegExp(r'\D'), '');
    if (!_isValidCpf(cleanCpf)) {
      throw Exception('CPF inválido. Verifique e tente novamente.');
    }
    final authEmail = _cpfToEmail(cleanCpf);

    _isAuthenticating = true;
    notifyListeners();

    try {
      AuthResponse signUpResponse;
      try {
        signUpResponse = await _supabase.auth.signUp(
          email: authEmail,
          password: password,
          data: {'full_name': name, 'cpf': cleanCpf},
        );
      } on AuthException catch (e) {
        if (e.code == 'over_email_send_rate_limit') {
          throw Exception(
            'Limite de envio de e-mails atingido. Aguarde alguns minutos e tente novamente.',
          );
        }
        if (e.code == 'user_already_exists' || e.code == 'email_exists') {
          try {
            await _supabase.auth.signInWithPassword(
              email: authEmail,
              password: password,
            );
          } on AuthException catch (signInError) {
            if (signInError.code == 'invalid_credentials') {
              throw Exception(
                'CPF já cadastrado. Faça login ou recupere a senha.',
              );
            }
            rethrow;
          }
          final existingUserId = _supabase.auth.currentUser?.id;
          if (existingUserId == null) {
            throw Exception('Não foi possível obter o usuário após login');
          }
          await _upsertUserProfile(
            userId: existingUserId,
            payload: _buildUserPayload(
              userId: existingUserId,
              name: name,
              cleanCpf: cleanCpf,
              birthDate: birthDate,
              gender: gender,
              diseases: diseases,
              phone: phone,
              email: email,
              emergencyContactName: emergencyContactName,
              emergencyContactPhone: emergencyContactPhone,
              emergencyContactRelationship: emergencyContactRelationship,
              uf: uf,
              municipioIbge: municipioIbge,
              ubsCnes: ubsCnes,
            ),
            allowUpdateExisting: false,
          );
          await _loadDataAndSchedule();
          return;
        }
        rethrow;
      }

      final userId = signUpResponse.user?.id ?? _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('Não foi possível obter o usuário após cadastro');
      }

      await _upsertUserProfile(
        userId: userId,
        payload: _buildUserPayload(
          userId: userId,
          name: name,
          cleanCpf: cleanCpf,
          birthDate: birthDate,
          gender: gender,
          diseases: diseases,
          phone: phone,
          email: email,
          emergencyContactName: emergencyContactName,
          emergencyContactPhone: emergencyContactPhone,
          emergencyContactRelationship: emergencyContactRelationship,
          uf: uf,
          municipioIbge: municipioIbge,
          ubsCnes: ubsCnes,
        ),
        allowUpdateExisting: false,
      );
      await _loadDataAndSchedule();
    } finally {
      _isAuthenticating = false;
      notifyListeners();
    }
  }

  Future<String?> obterNomePacienteRecuperacao(
    String cpf,
    String dataNascimento,
  ) async {
    final cleanCpf = cpf.replaceAll(RegExp(r'\D'), '');

    String? parsedDate;
    final parts = dataNascimento.split('/');
    if (parts.length == 3) {
      parsedDate = '${parts[2]}-${parts[1]}-${parts[0]}';
    } else {
      parsedDate = dataNascimento;
    }

    try {
      final response = await _supabase.rpc(
        'obter_nome_paciente_recuperacao',
        params: {'p_cpf': cleanCpf, 'p_data_nascimento': parsedDate},
      );
      return response as String?;
    } catch (e) {
      throw Exception(
        'Dados não encontrados ou ocorreu um erro. Verifique e tente novamente.',
      );
    }
  }

  Future<void> recuperarSenha({
    required String cpf,
    required String novaSenha,
    String? email,
    String? nome,
    String? dataNascimento,
  }) async {
    final cleanCpf = cpf.replaceAll(RegExp(r'\D'), '');

    String? parsedDate;
    if (dataNascimento != null) {
      // Tenta converter de DD/MM/YYYY para YYYY-MM-DD (formato do banco)
      final parts = dataNascimento.split('/');
      if (parts.length == 3) {
        parsedDate = '${parts[2]}-${parts[1]}-${parts[0]}';
      } else {
        parsedDate = dataNascimento;
      }
    }

    try {
      await _supabase.rpc(
        'recuperar_senha_paciente',
        params: {
          'p_cpf': cleanCpf,
          'p_nova_senha': novaSenha,
          if (email != null && email.isNotEmpty) 'p_email': email,
          if (nome != null && nome.isNotEmpty) 'p_nome': nome,
          if (parsedDate != null && parsedDate.isNotEmpty)
            'p_data_nascimento': parsedDate,
        },
      );
      // Após sucesso, o usuário poderá fazer o login normalmente com a nova senha
    } on PostgrestException catch (e) {
      throw Exception(e.message);
    } catch (e) {
      throw Exception(
        'Ocorreu um erro ao recuperar a senha. Verifique os dados e tente novamente.',
      );
    }
  }

  Map<String, dynamic> _buildUserPayload({
    required String userId,
    required String name,
    required String cleanCpf,
    String? birthDate,
    String? gender,
    List<String> diseases = const <String>[],
    String? phone,
    String? email,
    String? emergencyContactName,
    String? emergencyContactPhone,
    String? emergencyContactRelationship,
    String? uf,
    String? municipioIbge,
    String? ubsCnes,
  }) {
    final parsedBirthDate = _parseDate(birthDate);
    final municipio = int.tryParse((municipioIbge ?? '').trim());
    final normalizedDiseases = diseases
        .map((d) => d.trim())
        .where((d) => d.isNotEmpty)
        .toList();

    final emergencyName = (emergencyContactName ?? '').trim();
    final emergencyPhone = (emergencyContactPhone ?? '').trim();
    final emergencyRelationship = (emergencyContactRelationship ?? '').trim();

    Map<String, dynamic>? emergencyContact;
    if (emergencyName.isNotEmpty && emergencyPhone.isNotEmpty) {
      emergencyContact = {
        'name': emergencyName,
        'phone': emergencyPhone,
        'relationship': emergencyRelationship.isEmpty
            ? 'Contato de emergência'
            : emergencyRelationship,
      };
    }

    final payload = <String, dynamic>{
      'remote_id': userId,
      'name': name.trim(),
      'cpf': cleanCpf,
      'birth_date': parsedBirthDate?.toIso8601String(),
      'gender': (gender ?? '').trim().isEmpty ? null : gender?.trim(),
      'diseases': normalizedDiseases.isEmpty ? null : normalizedDiseases,
      'phone': (phone ?? '').trim().isEmpty ? null : phone?.trim(),
      'email': (email ?? '').trim().isEmpty ? null : email?.trim(),
      'emergency_contact': emergencyContact,
      'uf': (uf ?? '').trim().isEmpty ? null : uf?.trim().toUpperCase(),
      'municipio_ibge': municipio,
      'ubs_cnes': (ubsCnes ?? '').trim().isEmpty ? null : ubsCnes?.trim(),
    };

    // remove nulls to avoid overriding defaults
    payload.removeWhere((key, value) => value == null);
    return payload;
  }

  Future<void> _upsertUserProfile({
    required String userId,
    required Map<String, dynamic> payload,
    bool allowUpdateExisting = true,
  }) async {
    final existingByRemote = await _supabase
        .from('patients')
        .select('id')
        .eq('remote_id', userId)
        .maybeSingle();

    if (existingByRemote != null) {
      if (!allowUpdateExisting) {
        throw Exception('CPF já cadastrado. Faça login ou recupere a senha.');
      }
      await _supabase
          .from('patients')
          .update(payload)
          .eq('id', existingByRemote['id']);
      return;
    }

    final cpf = payload['cpf'] as String?;
    if (cpf != null && cpf.isNotEmpty) {
      final existingByCpf = await _supabase
          .from('patients')
          .select('id, remote_id')
          .eq('cpf', cpf)
          .maybeSingle();
      if (existingByCpf != null) {
        throw Exception('CPF já cadastrado. Faça login ou recupere a senha.');
      }
    }

    await _supabase.from('patients').insert(payload);
  }

  DateTime? _parseDate(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final parts = value.split(RegExp(r'[\\/-]'));
    if (parts.length == 3) {
      final day = int.tryParse(parts[0]);
      final month = int.tryParse(parts[1]);
      final year = int.tryParse(parts[2]);
      if (day != null && month != null && year != null) {
        try {
          return DateTime.utc(year, month, day);
        } catch (_) {
          return null;
        }
      }
    }
    // fallback attempt ISO format
    try {
      return DateTime.parse(value);
    } catch (_) {
      return null;
    }
  }

  String _cpfToEmail(String cpf) {
    // Remove non-digits
    final cleanCpf = cpf.replaceAll(RegExp(r'\D'), '');
    return '$cleanCpf@hiperdiario.app';
  }

  bool _isValidCpf(String cpf) {
    if (cpf.length != 11 || RegExp(r'^(\d)\1{10}$').hasMatch(cpf)) {
      return false;
    }

    int calcDigit(String base) {
      int sum = 0;
      for (int i = 0; i < base.length; i++) {
        sum += int.parse(base[i]) * ((base.length + 1) - i);
      }
      final mod = sum % 11;
      return mod < 2 ? 0 : 11 - mod;
    }

    final digit1 = calcDigit(cpf.substring(0, 9));
    final digit2 = calcDigit(cpf.substring(0, 9) + digit1.toString());
    return cpf.endsWith('$digit1$digit2');
  }

  Future<bool> cpfExists(String cpf) async {
    final cleanCpf = cpf.replaceAll(RegExp(r'\D'), '');
    if (!_isValidCpf(cleanCpf)) {
      throw Exception('CPF inválido. Verifique e tente novamente.');
    }
    final existing = await _supabase
        .from('patients')
        .select('id')
        .eq('cpf', cleanCpf)
        .maybeSingle();
    return existing != null;
  }

  Future<void> logout() async {
    await NotificationService.instance.cancelAll();
    await _supabase.auth.signOut();
    // Listener will handle clearing state
  }

  Future<void> _loadDataAndSchedule() async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      _patient = null;
      _appointments = [];
      _medications = [];
      _pendingDispensations = [];
      notifyListeners();
      return;
    }

    Map<String, dynamic>? profile = await _supabase
        .from('patients')
        .select('*')
        .eq('remote_id', user.id)
        .maybeSingle();

    if (profile == null) {
      final cpfFromEmail = _extractCpfFromEmail(user.email);
      if (cpfFromEmail != null) {
        profile = await _supabase
            .from('patients')
            .select('*')
            .eq('cpf', cpfFromEmail)
            .maybeSingle();
      }
    }

    // Se ainda assim não houver perfil, verifica se é um profissional para forçar o logout no mobile
    if (profile == null) {
      final isProf = await _supabase
          .from('professionals')
          .select('user_id')
          .eq('user_id', user.id)
          .maybeSingle();
      if (isProf != null) {
        debugPrint(
          'Profissional detectado no mobile sem perfil de paciente. Forçando logout.',
        );
        await logout();
        return;
      }
    }

    String? nomeMunicipio;
    final municipioRaw = profile?['municipio_ibge'];
    final codigoMunicipio = municipioRaw is int
        ? municipioRaw
        : int.tryParse('${municipioRaw ?? ''}');
    final siglaUf = profile?['uf']?.toString();
    final codigoUf = _resolveCodigoUf(siglaUf);

    if (codigoMunicipio != null && siglaUf != null && codigoUf != null) {
      try {
        final municipio = await IbgeService.buscarMunicipioPorId(
          idMunicipio: codigoMunicipio,
          siglaUf: siglaUf,
          codigoUf: codigoUf,
        );
        nomeMunicipio = municipio?.nome;
      } catch (_) {}
    }

    String? ubsName = profile?['ubs_name']?.toString().trim();
    final ubsCnes = profile?['ubs_cnes']?.toString();
    if ((ubsName == null || ubsName.isEmpty) &&
        ubsCnes != null &&
        ubsCnes.trim().isNotEmpty) {
      try {
        ubsName = await _resolveUbsNameFromLocalCnes(ubsCnes.trim());
      } catch (_) {
        // Se a consulta local falhar, tentamos buscar via CNES externo.
      }

      if ((ubsName == null || ubsName.isEmpty) &&
          codigoUf != null &&
          codigoMunicipio != null) {
        try {
          final ubsList = await CnesService.buscarEstabelecimentos(
            codigoUf: codigoUf,
            codigoMunicipio: codigoMunicipio,
            tipoUnidade: 2,
          );
          final match = ubsList
              .where((u) => u.codigoCnes.toString() == ubsCnes)
              .firstOrNull;
          if (match != null) {
            ubsName = match.nomeFantasia;
          }
        } catch (_) {}
      }
    }

    _patient = _mapPatientFromDb(
      profile,
      user,
      nomeMunicipio: nomeMunicipio,
      ubsName: ubsName,
    );

    final profileId = profile?['id'];
    if (profileId != null) {
      final appointmentRows = await _supabase
          .from('appointments')
          .select('*')
          .eq('patient_id', profileId)
          .order('date_time', ascending: true);
      _appointments = (appointmentRows as List)
          .map((row) => _mapAppointmentFromDb(row as Map<String, dynamic>))
          .toList();
    } else {
      _appointments = [];
    }

    // --- INÍCIO DA SINCRONIZAÇÃO PONTO 2, 3 e 4 (SUS) ---
    if (profileId != null) {
      try {
        final allDispsRows = await _supabase
            .from('medicine_dispensations')
            .select('id, dispensed_quantity, scheduled_times')
            .eq('patient_id', profileId);

        final validDisps = <String, Map<String, dynamic>>{};
        for (final row in allDispsRows as List) {
          validDisps[row['id'].toString()] = row as Map<String, dynamic>;
        }

        final medsToCheck = await _supabase
            .from('medications')
            .select('id, dispensation_id, frequency, stock')
            .eq('owner_id', user.id)
            .eq('active', true)
            .not('dispensation_id', 'is', null);

        for (final medRow in medsToCheck as List) {
          final mId = medRow['id'].toString();
          final dId = medRow['dispensation_id']?.toString();

          if (dId != null && dId.isNotEmpty) {
            if (!validDisps.containsKey(dId)) {
              await _supabase
                  .from('medications')
                  .update({'active': false})
                  .eq('id', mId);
            } else {
              final updateMap = <String, dynamic>{};
              final dispData = validDisps[dId]!;

              final webTimesRaw = dispData['scheduled_times'];
              final newTimes = <String>[];
              if (webTimesRaw is List) {
                for (final t in webTimesRaw) {
                  newTimes.add(t.toString());
                }
              }

              bool timesChanged = false;
              final freqRaw = medRow['frequency'];
              final currentTimes = <String>[];
              if (freqRaw is List) {
                for (final item in freqRaw) {
                  if (item is String) currentTimes.add(item);
                }
              } else if (freqRaw is Map && freqRaw['times'] is List) {
                for (final item in (freqRaw['times'] as List)) {
                  if (item is String) currentTimes.add(item);
                }
              }

              if (newTimes.length != currentTimes.length) {
                timesChanged = true;
              } else {
                for (int i = 0; i < newTimes.length; i++) {
                  if (newTimes[i] != currentTimes[i]) {
                    timesChanged = true;
                    break;
                  }
                }
              }

              final webStockRaw = dispData['dispensed_quantity'];
              final int webStock =
                  int.tryParse(webStockRaw?.toString() ?? '0') ?? 0;
              final currentStockRaw = medRow['stock'];
              final int currentStock =
                  int.tryParse(currentStockRaw?.toString() ?? '0') ?? 0;

              if (timesChanged && newTimes.isNotEmpty) {
                updateMap['frequency'] = newTimes;
              }

              // Evita sobrescrever um estoque definido manualmente no servidor.
              // Atualiza o stock a partir da dispensa apenas quando o estoque
              // atual estiver ausente/zero (regra conservadora).
              if (webStock > 0 && currentStock <= 0) {
                updateMap['stock'] = webStock;
              }

              if (updateMap.isNotEmpty) {
                await _supabase
                    .from('medications')
                    .update(updateMap)
                    .eq('id', mId);
              }
            }
          }
        }
      } catch (e) {
        debugPrint('Erro ao sincronizar retornos da UBS: ');
      }
    }
    // --- FIM DA SINCRONIZAÇÃO PONTO 2, 3 e 4 (SUS) ---

    final medicationRows = await _supabase
        .from('medications')
        .select('*')
        .eq('owner_id', user.id)
        .eq('active', true)
        .order('created_at', ascending: false);
    _medications = (medicationRows as List)
        .map((row) => _mapMedicationFromDb(row as Map<String, dynamic>))
        .toList();

    if (profileId != null) {
      try {
        final pendingRows = await _supabase
            .from('medicine_dispensations')
            .select(
              'id, dispensed_quantity, dispensed_at, prescribing_doctor, frequency_per_day, frequency_label, scheduled_times, medicine_catalog ( active_principle, strength, form )',
            )
            .eq('patient_id', profileId)
            .eq('acknowledged_in_app', false);

        _pendingDispensations = (pendingRows as List).map((row) {
          final map = row as Map<String, dynamic>;
          final catalog =
              map['medicine_catalog'] as Map<String, dynamic>? ?? {};

          final timesRaw = map['scheduled_times'];
          final timesList = <String>[];
          if (timesRaw is List) {
            for (final t in timesRaw) {
              timesList.add(t.toString());
            }
          }

          // Se houver um array de horários, derivamos o rótulo a partir dele
          String? computedFreqLabel;
          if (timesList.isNotEmpty) {
            final parsed = <TimeOfDayLite>[];
            for (final s in timesList) {
              final parts = s.split(':');
              if (parts.length >= 2) {
                final h = int.tryParse(parts[0]) ?? 0;
                final m = int.tryParse(parts[1]) ?? 0;
                parsed.add(TimeOfDayLite(h, m));
              }
            }
            final derived = _deriveFrequencyLabelFromTimes(parsed);
            computedFreqLabel = derived ?? '${parsed.length}x ao dia';
          }

          return PendingDispensation(
            id: map['id'].toString(),
            activePrinciple:
                catalog['active_principle']?.toString() ?? 'Medicamento Local',
            strength: catalog['strength']?.toString() ?? '',
            form: catalog['form']?.toString() ?? '',
            dispensedQuantity:
                int.tryParse(map['dispensed_quantity']?.toString() ?? '0') ?? 0,
            dispensedAt:
                DateTime.tryParse(
                  map['dispensed_at']?.toString() ?? '',
                )?.toLocal() ??
                DateTime.now(),
            prescribingDoctor:
                map['prescribing_doctor']?.toString() ?? 'Não informado',
            frequencyPerDay:
                int.tryParse(map['frequency_per_day']?.toString() ?? '1') ?? 1,
            frequencyLabel:
                computedFreqLabel ?? map['frequency_label']?.toString(),
            scheduledTimes: timesList,
          );
        }).toList();
      } catch (e) {
        debugPrint('Erro ao buscar retiradas pendentes de medicamento: $e');
        _pendingDispensations = [];
      }
    } else {
      _pendingDispensations = [];
    }

    notifyListeners();

    // Cancela todas as notificações antigas e reagenda
    await NotificationService.instance.cancelAll();

    // Agenda notificações conforme RF04 e RF07
    for (final appt in _appointments) {
      await NotificationService.instance.scheduleAppointmentReminders(appt);
    }
    await NotificationService.instance.scheduleAllMedicationReminders(
      _medications,
    );
  }

  Future<void> syncUbsData() async {
    await _loadDataAndSchedule();
  }

  String? _extractCpfFromEmail(String? email) {
    if (email == null || email.isEmpty) return null;
    const suffix = '@hiperdiario.app';
    if (!email.endsWith(suffix)) return null;
    final cpf = email.substring(0, email.length - suffix.length);
    return RegExp(r'^\d{11}$').hasMatch(cpf) ? cpf : null;
  }

  DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value.toLocal();
    if (value is String && value.trim().isNotEmpty) {
      return DateTime.tryParse(value)?.toLocal();
    }
    return null;
  }

  int? _resolveCodigoUf(String? siglaUf) {
    if (siglaUf == null || siglaUf.trim().isEmpty) return null;
    final upper = siglaUf.trim().toUpperCase();
    try {
      return estadosBrasileiros
          .firstWhere((estado) => estado.sigla == upper)
          .codigoIbge;
    } catch (_) {
      return null;
    }
  }

  Patient _mapPatientFromDb(
    Map<String, dynamic>? row,
    User user, {
    String? nomeMunicipio,
    String? ubsName,
  }) {
    final email = user.email;
    final cpfFallback = _extractCpfFromEmail(email) ?? '';
    final metadata = user.userMetadata ?? const <String, dynamic>{};

    final birthDate =
        _parseDateTime(row?['birth_date']) ?? DateTime(1970, 1, 1);
    final municipio = row?['municipio_ibge'];
    final diseasesRaw = row?['diseases'];
    final diseases = diseasesRaw is List
        ? diseasesRaw
              .map((item) => item.toString().trim())
              .where((item) => item.isNotEmpty)
              .toList()
        : <String>[];

    EmergencyContact? emergencyContact;
    final emergencyRaw = row?['emergency_contact'];
    if (emergencyRaw is Map) {
      final emergencyName = (emergencyRaw['name'] ?? '').toString().trim();
      final emergencyPhone = (emergencyRaw['phone'] ?? '').toString().trim();
      final emergencyRelationship = (emergencyRaw['relationship'] ?? '')
          .toString()
          .trim();

      if (emergencyName.isNotEmpty && emergencyPhone.isNotEmpty) {
        emergencyContact = EmergencyContact(
          name: emergencyName,
          phone: emergencyPhone,
          relationship: emergencyRelationship.isEmpty
              ? 'Contato de emergência'
              : emergencyRelationship,
        );
      }
    }

    return Patient(
      name: (row?['name'] ?? metadata['full_name'] ?? 'Usuário').toString(),
      cpf: (row?['cpf'] ?? metadata['cpf'] ?? cpfFallback).toString(),
      birthDate: birthDate,
      diseases: diseases,
      contact: (row?['phone'] ?? '').toString(),
      ubs: row?['ubs_cnes']?.toString().isNotEmpty == true
          ? row!['ubs_cnes'].toString()
          : 'UBS não informada',
      ubsName: ubsName ?? row?['ubs_name']?.toString(),
      email: (row?['email'] ?? email)?.toString(),
      emergencyContact: emergencyContact,
      codigoUf: _resolveCodigoUf(row?['uf']?.toString()),
      siglaUf: row?['uf']?.toString(),
      codigoMunicipio: municipio is int
          ? municipio
          : int.tryParse('${municipio ?? ''}'),
      nomeMunicipio: nomeMunicipio,
    );
  }

  Future<String?> _resolveUbsNameFromLocalCnes(String ubsCnes) async {
    try {
      final result = await _supabase
          .from('cnes_establishments')
          .select('name')
          .eq('cnes_id', ubsCnes)
          .maybeSingle();

      if (result is Map<String, dynamic>) {
        final name = result['name']?.toString().trim();
        return (name?.isNotEmpty == true) ? name : null;
      }
    } catch (_) {
      // Ignora erro e permite fallback para a rota externa.
    }
    return null;
  }

  Appointment _mapAppointmentFromDb(Map<String, dynamic> row) {
    final dateTime = _parseDateTime(row['date_time']) ?? DateTime.now();
    final status = (row['status'] ?? '').toString().toLowerCase();
    final shiftRaw = row['shift']?.toString();

    bool? attended;
    if (status == 'attended' || status == 'compareceu') {
      attended = true;
    } else if (status == 'missed' || status == 'faltou') {
      attended = false;
    }

    return Appointment(
      id: (row['remote_id'] ?? row['id']).toString(),
      dateTime: dateTime,
      location: (row['location'] ?? 'Local não informado').toString(),
      specialty: (row['specialty'] ?? 'Consulta').toString(),
      professionalName: row['professional_name']?.toString(),
      professionalId: row['professional_id']?.toString(),
      shift: shiftRaw != null
          ? AppointmentShiftX.fromDb(shiftRaw)
          : (dateTime.hour >= 12
                ? AppointmentShift.afternoon
                : AppointmentShift.morning),
      notes: row['notes']?.toString(),
      attended: attended,
    );
  }

  List<TimeOfDayLite> _parseMedicationTimes(dynamic frequency) {
    final times = <TimeOfDayLite>[];

    void addFromString(String value) {
      final match = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(value.trim());
      if (match == null) return;
      final hour = int.tryParse(match.group(1)!);
      final minute = int.tryParse(match.group(2)!);
      if (hour == null || minute == null) return;
      if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return;
      times.add(TimeOfDayLite(hour, minute));
    }

    if (frequency is List) {
      for (final item in frequency) {
        if (item is String) {
          addFromString(item);
        } else if (item is Map) {
          final hour = int.tryParse('${item['hour'] ?? ''}');
          final minute = int.tryParse('${item['minute'] ?? ''}');
          if (hour != null &&
              minute != null &&
              hour >= 0 &&
              hour <= 23 &&
              minute >= 0 &&
              minute <= 59) {
            times.add(TimeOfDayLite(hour, minute));
          }
        }
      }
    } else if (frequency is Map && frequency['times'] is List) {
      for (final item in (frequency['times'] as List)) {
        if (item is String) {
          addFromString(item);
        }
      }
    }

    return times;
  }

  String? _deriveFrequencyLabelFromTimes(List<TimeOfDayLite> times) {
    if (times.isEmpty) return null;
    final n = times.length;
    if (n == 1) return '1x ao dia';

    final minutes = times.map((t) => t.hour * 60 + t.minute).toList();
    minutes.sort();
    final diffs = <int>[];
    for (var i = 0; i < minutes.length - 1; i++) {
      diffs.add(minutes[i + 1] - minutes[i]);
    }
    // wrap-around diff
    diffs.add((minutes[0] + 24 * 60) - minutes.last);

    final expected = 24 * 60 / n;
    const tolerance = 30; // minutos
    final approxEqual = diffs.every((d) => (d - expected).abs() <= tolerance);

    if (!approxEqual) return null;

    // Usamos um rótulo consistente do tipo 'Nx ao dia' para exibição
    // (por exemplo '2x ao dia', '3x ao dia', etc.), mantendo a forma
    // legível e consistente com medicamentos criados pelo usuário.
    return '${n}x ao dia';
  }

  String _normalizeDoseText(String s) {
    var t = s.replaceAll(RegExp(r'\s+'), ' ').trim();
    t = t.replaceAllMapped(
      RegExp(r'(\d+(?:[.,]\d+)?)([A-Za-zµ%]+)'),
      (m) => '${m[1]} ${m[2]}',
    );
    return t;
  }

  String _extractBaseDose(String strength, String rawDosage) {
    final s = strength.trim();
    if (s.isNotEmpty) {
      return _normalizeDoseText(s);
    }

    final freqRegex = RegExp(
      r'\b(?:\d+\s*x\s*(?:ao dia|/dia)?|\d+\/\d+\s*h)\b',
      caseSensitive: false,
    );
    final cleaned = rawDosage.replaceAll(freqRegex, '').trim();
    if (cleaned.isEmpty) return 'Sem posologia informada';

    // Composite like '250 mg/5 ml'
    final composite = RegExp(
      r'(\d+(?:[.,]\d+)?)\s*(mg|g|ml|mcg|µg)\s*\/\s*(\d+(?:[.,]\d+)?)\s*(ml|g)',
      caseSensitive: false,
    );
    final compMatch = composite.firstMatch(cleaned);
    if (compMatch != null) {
      return _normalizeDoseText(compMatch.group(0)!);
    }

    final doseRegex = RegExp(
      r'(\d+(?:[.,]\d+)?)\s*(mg|g|ml|mcg|µg|iu|unidades|comprimad[oa]s?|cápsulas?)',
      caseSensitive: false,
    );
    final match = doseRegex.firstMatch(cleaned);
    if (match != null) {
      return _normalizeDoseText(match.group(0)!);
    }

    final first = cleaned.split(RegExp(r'[;,]')).first.trim();
    return first.isNotEmpty ? first : 'Sem posologia informada';
  }

  Medication _mapMedicationFromDb(Map<String, dynamic> row) {
    final stock = int.tryParse('${row['stock'] ?? 0}') ?? 0;
    final rawDosage = (row['dosage_instructions'] ?? '').toString();
    final strength = (row['strength'] ?? '').toString();
    final times = _parseMedicationTimes(row['frequency']);
    final freqLabel =
        _deriveFrequencyLabelFromTimes(times) ??
        (times.isNotEmpty ? '${times.length}x ao dia' : null);

    final base = _extractBaseDose(strength, rawDosage);

    String dosage;
    if (base == 'Sem posologia informada') {
      dosage = freqLabel ?? base;
    } else {
      dosage = freqLabel != null ? '$base $freqLabel' : base;
    }

    return Medication(
      id: (row['remote_id'] ?? row['id']).toString(),
      name: (row['name'] ?? 'Medicamento').toString(),
      dosage: dosage,
      times: times,
      stockUnits: stock,
      dispensationId: row['dispensation_id']?.toString(),
    );
  }

  // === Gerenciamento de Consultas ===

  Future<void> addAppointment(Appointment appt) async {
    final user = _supabase.auth.currentUser;
    if (user != null && _patient != null) {
      try {
        // Usa o CPF do paciente que j est garantido e com fallback correto
        final profile = await _supabase
            .from('patients')
            .select('id')
            .eq('cpf', _patient!.cpf)
            .maybeSingle();

        if (profile != null) {
          final doc = {
            'remote_id': appt.id,
            'patient_id': profile['id'],
            'date_time': appt.dateTime.toUtc().toIso8601String(),
            'location': appt.location,
            'specialty': appt.specialty,
            'professional_name': appt.professionalName,
            'professional_id': appt.professionalId,
            'shift': appt.shift.dbValue,
            'notes': appt.notes,
            'status': appt.attended == true
                ? 'attended'
                : appt.attended == false
                ? 'missed'
                : 'scheduled',
          };
          await _supabase.from('appointments').insert(doc);
        } else {
          debugPrint(
            'Falha: usurio no encontrado na tabela para associar a consulta.',
          );
        }
      } catch (e) {
        debugPrint('Erro ao salvar agendamento no Supabase: $e');
      }
    }

    _appointments = [..._appointments, appt];
    notifyListeners();
    try {
      await NotificationService.instance.scheduleAppointmentReminders(appt);
    } catch (e) {
      // Ignora erro de notificaes - no deve impedir salvamento
    }
  }

  Future<void> updateAppointment(Appointment appt) async {
    final user = _supabase.auth.currentUser;
    if (user != null) {
      try {
        // Tenta atualizar usando primeiramente o remote_id se existir, caso no, por safety pode tentar id numrico se for DB id.
        final targetId = appt.id;
        final isNumeric =
            int.tryParse(targetId) != null && targetId.length < 13;
        // Heurstica p/ identificar id sequencial gerado pelo Supabase versus timestamp/UUID

        final doc = {
          'date_time': appt.dateTime.toUtc().toIso8601String(),
          'location': appt.location,
          'specialty': appt.specialty,
          'professional_name': appt.professionalName,
          'professional_id': appt.professionalId,
          'shift': appt.shift.dbValue,
          'notes': appt.notes,
          'status': appt.attended == true
              ? 'attended'
              : appt.attended == false
              ? 'missed'
              : 'scheduled',
        };

        if (isNumeric) {
          await _supabase.from('appointments').update(doc).eq('id', targetId);
        } else {
          await _supabase
              .from('appointments')
              .update(doc)
              .eq('remote_id', targetId);
        }
      } catch (e) {
        debugPrint('Erro ao atualizar agendamento no Supabase: $e');
      }
    }

    _appointments = _appointments
        .map((e) => e.id == appt.id ? appt : e)
        .toList();
    notifyListeners();
    // Cancela e reagenda todas as notificaes
    try {
      await NotificationService.instance.cancelAll();
      for (final a in _appointments) {
        await NotificationService.instance.scheduleAppointmentReminders(a);
      }
      for (final med in _medications) {
        await NotificationService.instance.scheduleMedicationReminders(med);
      }
    } catch (e) {
      // Ignora erro de notificaes
    }
  }

  Future<void> removeAppointment(String id) async {
    final user = _supabase.auth.currentUser;
    if (user != null) {
      try {
        final isNumeric = int.tryParse(id) != null && id.length < 13;
        if (isNumeric) {
          await _supabase.from('appointments').delete().eq('id', id);
        } else {
          await _supabase.from('appointments').delete().eq('remote_id', id);
        }
      } catch (e) {
        debugPrint('Erro ao remover agendamento no Supabase: $e');
      }
    }

    _appointments = _appointments.where((e) => e.id != id).toList();
    notifyListeners();
    // Cancela e reagenda notificações restantes
    try {
      await NotificationService.instance.cancelAll();
      for (final a in _appointments) {
        await NotificationService.instance.scheduleAppointmentReminders(a);
      }
      for (final med in _medications) {
        await NotificationService.instance.scheduleMedicationReminders(med);
      }
    } catch (e) {
      // Ignora erro de notificações
    }
  }

  Future<void> markAppointmentAttendance(String id, bool attended) async {
    final user = _supabase.auth.currentUser;
    if (user != null) {
      try {
        final isNumeric = int.tryParse(id) != null && id.length < 13;
        final doc = {'status': attended ? 'attended' : 'missed'};

        if (isNumeric) {
          await _supabase.from('appointments').update(doc).eq('id', id);
        } else {
          await _supabase.from('appointments').update(doc).eq('remote_id', id);
        }
      } catch (e) {
        debugPrint('Erro ao atualizar presence no Supabase: $e');
      }
    }

    _appointments = _appointments.map((appt) {
      if (appt.id == id) {
        return appt.copyWith(attended: attended);
      }
      return appt;
    }).toList();
    notifyListeners();
  }

  // === Gerenciamento de Contatos ===

  Future<void> updatePatientContacts({
    String? contact,
    String? ubs,
    String? ubsName,
    String? email,
    EmergencyContact? emergencyContact,
    bool clearEmergencyContact = false,
  }) async {
    if (_patient == null) return;

    // Preparar os dados para atualizacao no Supabase
    final payload = <String, dynamic>{};
    if (contact != null) payload['phone'] = contact;
    if (ubs != null) {
      payload['ubs_cnes'] = ubs;
      if (ubsName != null) payload['ubs_name'] = ubsName;
    } else if (ubsName != null) {
      payload['ubs_name'] = ubsName;
    }
    if (email != null) payload['email'] = email;

    if (clearEmergencyContact) {
      payload['emergency_contact'] = null;
    } else if (emergencyContact != null) {
      payload['emergency_contact'] = {
        'name': emergencyContact.name,
        'phone': emergencyContact.phone,
        'relationship': emergencyContact.relationship,
      };
    }

    if (payload.isNotEmpty) {
      try {
        await _supabase
            .from('patients')
            .update(payload)
            .eq('cpf', _patient!.cpf);
      } catch (e) {
        // Log ou re-throw dependendo da necessidade de UI, mas como é um app state
        debugPrint('Erro ao atualizar contatos no Supabase: $e');
        rethrow;
      }
    }

    _patient = _patient!.copyWith(
      contact: contact,
      ubs: ubs,
      ubsName: ubsName,
      email: email,
      emergencyContact: emergencyContact,
      clearEmergencyContact: clearEmergencyContact,
    );
    notifyListeners();
  }

  // === Localização do paciente ===

  Future<void> updatePatientLocation({
    required int codigoUf,
    required String siglaUf,
    required int codigoMunicipio,
    required String nomeMunicipio,
  }) async {
    if (_patient == null) return;

    try {
      // Se o município mudou, limpamos também a UBS de referência para
      // forçar o usuário a selecionar uma UBS no novo município.
      final bool municipioMudou = _patient!.codigoMunicipio != codigoMunicipio;
      final payload = <String, dynamic>{
        'uf': siglaUf,
        'municipio_ibge': codigoMunicipio,
      };
      if (municipioMudou) {
        payload['ubs_cnes'] = '';
        payload['ubs_name'] = '';
      }

      await _supabase.from('patients').update(payload).eq('cpf', _patient!.cpf);
    } catch (e) {
      debugPrint('Erro ao atualizar localização no Supabase: $e');
    }

    // Atualiza o estado local do paciente. Quando o município mudou,
    // também limparemos os campos `ubs` e `ubsName` em memória.
    final bool municipioMudou = _patient!.codigoMunicipio != codigoMunicipio;
    _patient = _patient!.copyWith(
      codigoUf: codigoUf,
      siglaUf: siglaUf,
      codigoMunicipio: codigoMunicipio,
      nomeMunicipio: nomeMunicipio,
      ubs: municipioMudou ? '' : _patient!.ubs,
      ubsName: municipioMudou ? '' : _patient!.ubsName,
    );
    notifyListeners();
  }

  Future<void> addMedication(Medication m) async {
    final user = _supabase.auth.currentUser;
    if (user != null) {
      try {
        final doc = {
          'remote_id': m.id,
          'owner_id': user.id,
          'name': m.name,
          'dosage_instructions': m.dosage,
          'frequency': m.times
              .map(
                (t) =>
                    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}',
              )
              .toList(),
          'stock': m.stockUnits,
          'active': true,
        };
        await _supabase.from('medications').insert(doc);
      } catch (e) {
        debugPrint('Erro ao salvar medicamento no Supabase: $e');
      }
    }

    _medications = [..._medications, m];
    notifyListeners();
    try {
      await NotificationService.instance.cancelAll();
      await NotificationService.instance.scheduleAllMedicationReminders(
        _medications,
      );
    } catch (e) {
      // Ignora erro de notificações - não deve impedir salvamento
    }
  }

  Future<void> acknowledgeDispensation(
    PendingDispensation disp,
    List<TimeOfDayLite> times,
    String finalDosage,
  ) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    try {
      final name = disp.activePrinciple;

      final doc = {
        'owner_id': user.id,
        'name': name,
        'dispensation_id': disp.id,
        'dosage_instructions': finalDosage,
        'frequency': times
            .map(
              (t) =>
                  '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}',
            )
            .toList(),
        'stock': disp.dispensedQuantity,
        'active': true,
      };

      final response = await _supabase
          .from('medications')
          .insert(doc)
          .select('*')
          .single();
      final newMed = _mapMedicationFromDb(response);

      // Update dispensation status
      await _supabase
          .from('medicine_dispensations')
          .update({'acknowledged_in_app': true})
          .eq('id', disp.id);

      _medications = [..._medications, newMed];
      _pendingDispensations = _pendingDispensations
          .where((d) => d.id != disp.id)
          .toList();
      notifyListeners();

      try {
        await NotificationService.instance.cancelAll();
        await NotificationService.instance.scheduleAllMedicationReminders(
          _medications,
        );
      } catch (e) {
        // Ignora erro de notificações - não deve impedir salvamento
      }
    } catch (e) {
      debugPrint('Erro ao reconhecer retirada de medicamento: $e');
    }
  }

  Future<void> updateMedication(Medication m) async {
    final user = _supabase.auth.currentUser;
    if (user != null) {
      try {
        final targetId = m.id;
        final isNumeric =
            int.tryParse(targetId) != null && targetId.length < 13;

        final doc = {
          'name': m.name,
          'dosage_instructions': m.dosage,
          'frequency': m.times
              .map(
                (t) =>
                    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}',
              )
              .toList(),
          'stock': m.stockUnits,
        };

        if (isNumeric) {
          await _supabase
              .from('medications')
              .update(doc)
              .eq('id', targetId)
              .eq('owner_id', user.id);
        } else {
          await _supabase
              .from('medications')
              .update(doc)
              .eq('remote_id', targetId)
              .eq('owner_id', user.id);
        }
      } catch (e) {
        debugPrint('Erro ao atualizar medicamento no Supabase: $e');
      }
    }

    _medications = _medications.map((e) => e.id == m.id ? m : e).toList();
    notifyListeners();
    // Para simplificar, cancela e reagenda todos os lembretes de medicação
    try {
      await NotificationService.instance.cancelAll();
      await NotificationService.instance.scheduleAllMedicationReminders(
        _medications,
      );
    } catch (e) {
      // Ignora erro de notificações - não deve impedir salvamento
    }
  }

  Future<void> decrementMedicationStock(String medId, {int by = 1}) async {
    final idx = _medications.indexWhere((e) => e.id == medId);
    if (idx == -1) return;

    final oldMed = _medications[idx];
    final current = oldMed.stockUnits;
    final newStock = (current - by) < 0 ? 0 : (current - by);

    final updatedMed = Medication(
      id: oldMed.id,
      name: oldMed.name,
      dosage: oldMed.dosage,
      times: oldMed.times,
      stockUnits: newStock,
      dispensationId: oldMed.dispensationId,
    );

    _medications = _medications
        .map((e) => e.id == medId ? updatedMed : e)
        .toList();
    notifyListeners();

    final user = _supabase.auth.currentUser;
    if (user != null) {
      try {
        final targetId = oldMed.id;
        final isNumeric =
            int.tryParse(targetId) != null && targetId.length < 13;
        final doc = {'stock': newStock};
        if (isNumeric) {
          await _supabase
              .from('medications')
              .update(doc)
              .eq('id', targetId)
              .eq('owner_id', user.id);
        } else {
          await _supabase
              .from('medications')
              .update(doc)
              .eq('remote_id', targetId)
              .eq('owner_id', user.id);
        }
      } catch (e) {
        debugPrint('Erro ao sincronizar estoque (decrement): $e');
      }
    }

    if (newStock <= 0) {
      try {
        await NotificationService.instance.cancelAll();
        await NotificationService.instance.scheduleAllMedicationReminders(
          _medications,
        );
      } catch (_) {}
    }
  }

  Future<void> incrementMedicationStock(String medId, {int by = 1}) async {
    final idx = _medications.indexWhere((e) => e.id == medId);
    if (idx == -1) return;

    final oldMed = _medications[idx];
    final current = oldMed.stockUnits;
    final newStock = current + by;

    final updatedMed = Medication(
      id: oldMed.id,
      name: oldMed.name,
      dosage: oldMed.dosage,
      times: oldMed.times,
      stockUnits: newStock,
      dispensationId: oldMed.dispensationId,
    );

    _medications = _medications
        .map((e) => e.id == medId ? updatedMed : e)
        .toList();
    notifyListeners();

    final user = _supabase.auth.currentUser;
    if (user != null) {
      try {
        final targetId = oldMed.id;
        final isNumeric =
            int.tryParse(targetId) != null && targetId.length < 13;
        final doc = {'stock': newStock};
        if (isNumeric) {
          await _supabase
              .from('medications')
              .update(doc)
              .eq('id', targetId)
              .eq('owner_id', user.id);
        } else {
          await _supabase
              .from('medications')
              .update(doc)
              .eq('remote_id', targetId)
              .eq('owner_id', user.id);
        }
      } catch (e) {
        debugPrint('Erro ao sincronizar estoque (increment): $e');
      }
    }

    // Se havia estoque 0 e agora voltou a ter, reagendamos lembretes
    if (oldMed.stockUnits <= 0 && newStock > 0) {
      try {
        await NotificationService.instance.scheduleMedicationReminders(
          updatedMed,
        );
      } catch (_) {}
    }
  }

  Future<void> removeMedication(String id) async {
    final user = _supabase.auth.currentUser;
    if (user != null) {
      try {
        final isNumeric = int.tryParse(id) != null && id.length < 13;
        if (isNumeric) {
          await _supabase
              .from('medications')
              .delete()
              .eq('id', id)
              .eq('owner_id', user.id);
        } else {
          await _supabase
              .from('medications')
              .delete()
              .eq('remote_id', id)
              .eq('owner_id', user.id);
        }
      } catch (e) {
        debugPrint('Erro ao remover medicamento no Supabase: $e');
      }
    }

    _medications = _medications.where((e) => e.id != id).toList();
    notifyListeners();
    // Cancela e reagenda lembretes restantes
    try {
      await NotificationService.instance.cancelAll();
      for (final med in _medications) {
        await NotificationService.instance.scheduleMedicationReminders(med);
      }
    } catch (e) {
      // Ignora erro de notificações - não deve impedir remoção
    }
  }

  void updateLowStockDaysThreshold(int days) {
    if (days < 1) days = 1;
    if (days > 14) days = 14;
    _lowStockDaysThreshold = days;
    notifyListeners();
  }
}
