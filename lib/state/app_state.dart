import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import '../core/services/notification_service.dart';
import '../core/models/appointment.dart';
import '../core/models/emergency_contact.dart';
import '../core/models/medication.dart';
import '../core/models/patient.dart';
import '../core/models/municipio.dart';
import '../core/services/municipio_service.dart';
import '../core/services/cnes_service.dart';
import '../core/services/local_database.dart';
import '../core/services/sync_service.dart';
import 'package:uuid/uuid.dart';

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

  bool _isOffline = false;
  bool get isOffline => _isOffline;

  final SupabaseClient _supabase = Supabase.instance.client;
  final _localDb = LocalDatabase.instance;
  final _syncService = SyncService.instance;
  final _uuid = const Uuid();
  Timer? _syncTimer;

  AppState() {
    _syncService.init();
    _initConnectivity();
    // Check initial session
    _isLogged = _supabase.auth.currentSession != null;
    _loadInitialLocalData();
    
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

  Future<void> _loadInitialLocalData() async {
    try {
      _appointments = await _localDb.getAllAppointments();
      _medications = await _localDb.getAllMedications();
      
      if (_medications.isNotEmpty) {
        NotificationService.instance.scheduleAllMedicationReminders(_medications);
      }

      final patientMap = await _localDb.getPatient();
      if (patientMap != null) {
        final p = Patient.fromMap(patientMap);
        _patient = p;
        notifyListeners(); // Notifica para mostrar dados básicos (nome, cpf) o mais rápido possível

        if (p.codigoMunicipio != null) {
          try {
            final municipio = await MunicipioService.buscarMunicipioPorId(p.codigoMunicipio!);
            if (municipio != null) {
              _patient = p.copyWith(
                nomeMunicipio: municipio.nome,
                siglaUf: p.siglaUf?.isNotEmpty == true ? p.siglaUf : municipio.siglaUf,
                codigoUf: p.codigoUf ?? municipio.codigoUf,
              );
              debugPrint('[AppState] Município resolvido offline: ${_patient?.nomeMunicipio}');
              notifyListeners(); // Notifica novamente com o nome do município e estado
            }
          } catch (e) {
            debugPrint('[AppState] Erro ao resolver município offline: $e');
          }
        }
      } else {
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[AppState] Erro ao carregar dados locais iniciais: $e');
    }
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

  void _initConnectivity() {
    Connectivity().onConnectivityChanged.listen((results) {
      final isOffline = results.contains(ConnectivityResult.none);
      if (_isOffline != isOffline) {
        _isOffline = isOffline;
        notifyListeners();
      }
    });

    // Check initial state
    Connectivity().checkConnectivity().then((results) {
      final isOffline = results.contains(ConnectivityResult.none);
      if (_isOffline != isOffline) {
        _isOffline = isOffline;
        notifyListeners();
      }
    });
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

    _isAuthenticating = true;
    notifyListeners();

    try {
      // 1. Tentar obter o e-mail real associado a este CPF via Edge Function
      String authEmail;
      try {
        final response = await _supabase.functions.invoke(
          'manage-patient-auth',
          body: {'action': 'check', 'cpf': cleanCpf},
        );

        if (response.status == 200 && response.data['email'] != null) {
          authEmail = response.data['email'];
        } else {
          // Se não encontrado ou erro, usar o padrão
          authEmail = _cpfToEmail(cleanCpf);
        }
      } catch (e) {
        // Fallback para o padrão em caso de erro na função
        authEmail = _cpfToEmail(cleanCpf);
      }

      await _supabase.auth.signInWithPassword(
        email: authEmail,
        password: password,
      );
      await _loadDataAndSchedule();
    } on AuthException catch (e) {
      _isLogged = false;
      _patient = null;
      // Trata erro de rede específico do Supabase Auth
      if (e.message.contains('fetch') || e.message.contains('network') || e.toString().contains('AuthRetryableFetchException')) {
        throw Exception('Sem conexão com a internet. Verifique sua rede e tente novamente.');
      }
      rethrow;
    } catch (e) {
      _isLogged = false;
      _patient = null;
      final errorStr = e.toString();
      if (errorStr.contains('fetch') || errorStr.contains('network') || errorStr.contains('SocketException') || errorStr.contains('AuthRetryableFetchException')) {
        throw Exception('Sem conexão com a internet. Verifique sua rede.');
      }
      rethrow;
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
    String? zipCode,
    String? street,
    String? number,
    String? neighborhood,
    String? complement,
  }) async {
    final cleanCpf = cpf.replaceAll(RegExp(r'\D'), '');
    if (!_isValidCpf(cleanCpf)) {
      throw Exception('CPF inválido. Verifique e tente novamente.');
    }

    _isAuthenticating = true;
    notifyListeners();

    try {
      // 1. Chamar a Edge Function para lidar com a criação/vínculo do usuário e registro do paciente
      final response = await _supabase.functions.invoke(
        'manage-patient-auth',
        body: {
          'action': 'create',
          'cpf': cleanCpf,
          'password': password,
          'patientData': {
            'name': name,
            'birth_date': _formatDateToIso(birthDate),
            'gender': gender,
            'diseases': diseases,
            'phone': phone?.replaceAll(RegExp(r'\D'), ''),
            'email': email,
            'emergency_contact': {
              'name': emergencyContactName,
              'phone': emergencyContactPhone?.replaceAll(RegExp(r'\D'), ''),
              'relationship': emergencyContactRelationship,
            },
            'state_code': uf,
            'city_ibge':
                municipioIbge != null ? int.tryParse(municipioIbge) : null,
            'ubs_cnes': ubsCnes,
            'zip_code': zipCode,
            'street': street,
            'number': number,
            'neighborhood': neighborhood,
            'complement': complement,
          },
        },
      );

      if (response.status != 200) {
        final errorMsg = response.data['error'] ?? 'Erro no cadastro';
        throw Exception(errorMsg);
      }

      final authEmail = response.data['email'];
      if (authEmail == null) {
        throw Exception('Não foi possível obter o e-mail para login após cadastro');
      }

      // 2. Realizar login com o e-mail retornado pela função (pode ser o existente ou o novo)
      await _supabase.auth.signInWithPassword(
        email: authEmail,
        password: password,
      );

      await _loadDataAndSchedule();
    } catch (e) {
      final errorStr = e.toString();
      if (errorStr.contains('fetch') || errorStr.contains('network') || errorStr.contains('SocketException') || errorStr.contains('AuthRetryableFetchException')) {
        throw Exception('Sem conexão com a internet. Verifique sua rede e tente novamente.');
      }
      rethrow;
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
    try {
      final existing = await _supabase
          .from('patients')
          .select('id')
          .eq('cpf', cleanCpf)
          .maybeSingle();
      return existing != null;
    } catch (e) {
      final errorStr = e.toString();
      if (errorStr.contains('fetch') || errorStr.contains('network') || errorStr.contains('SocketException')) {
        throw Exception('Sem conexão com a internet. Não foi possível verificar o CPF.');
      }
      rethrow;
    }
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

    Map<String, dynamic>? profile;
    try {
      profile = await _supabase
          .from('patients')
          .select('*')
          .eq('user_id', user.id)
          .maybeSingle()
          .timeout(const Duration(seconds: 5));
    } catch (e) {
      debugPrint('Erro ao buscar perfil (possivelmente offline): $e');
      // Se falhar e já tivermos o paciente carregado do cache, mantemos o que temos
      if (_patient != null) return;
    }

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
          .maybeSingle()
          .timeout(const Duration(seconds: 5), onTimeout: () => null);

      if (isProf != null) {
        debugPrint(
          'Profissional detectado no mobile sem perfil de paciente. Forçando logout.',
        );
        await logout();
        throw Exception(
          'Acesso negado. Este aplicativo é exclusivo para pacientes.',
        );
      } else {
        debugPrint('Usuário logado sem perfil de paciente e sem ser profissional.');
        // Se estivermos offline, podemos ter um perfil local mas o fetch falhou
        if (_patient != null) return;
        
        await logout();
        throw Exception(
          'Perfil de paciente não encontrado. Entre em contato com a recepção.',
        );
      }
    }

    String? nomeMunicipio;
    final municipioRaw = profile['city_ibge'];
    final codigoMunicipio = municipioRaw is int
        ? municipioRaw
        : int.tryParse('${municipioRaw ?? ''}');
    String? siglaUf = profile['state_code']?.toString();
    int? codigoUf = _resolveCodigoUf(siglaUf);

    if (codigoMunicipio != null) {
      try {
        final municipio = await MunicipioService.buscarMunicipioPorId(codigoMunicipio);
        if (municipio != null) {
          nomeMunicipio = municipio.nome;
          // Se a sigla da UF estiver ausente no perfil, recuperamos do município resolvido
          if (siglaUf == null || siglaUf.isEmpty) {
            siglaUf = municipio.siglaUf;
            codigoUf = municipio.codigoUf;
          }
        }
      } catch (_) {}
    }

    String? ubsName = profile['ubs_name']?.toString().trim();
    final ubsCnes = profile['ubs_cnes']?.toString();
    if ((ubsName == null || ubsName.isEmpty) &&
        ubsCnes != null &&
        ubsCnes.trim().isNotEmpty) {
      try {
        ubsName = formatCnesDisplayName(await _resolveUbsNameFromLocalCnes(ubsCnes.trim()) ?? '');
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
            ubsName = formatCnesDisplayName(match.nomeFantasia);
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

    // Salva o perfil localmente para uso offline
    await _localDb.savePatient(_patient!.toMap());

    final profileId = profile?['id'];
    if (profileId != null) {
      final appointmentRows = await _supabase
          .from('appointments')
          .select('*, professionals(name, specialty), cnes_establishments(name)')
          .eq('patient_id', profileId)
          .order('date_time', ascending: true);
      _appointments = (appointmentRows as List)
          .map((row) => _mapAppointmentFromDb(row as Map<String, dynamic>))
          .toList();
      
      // Save to local cache
      for (final appt in _appointments) {
        await _localDb.saveAppointment(appt);
      }
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
      
      // Save to local cache
      for (final med in _medications) {
        await _localDb.saveMedication(med);
      }

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
      final trimmed = value.trim();
      // Se for apenas data (YYYY-MM-DD), não usamos toLocal() para evitar deslocamento de fuso
      if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(trimmed)) {
        return DateTime.tryParse(trimmed);
      }
      return DateTime.tryParse(trimmed)?.toLocal();
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
    final municipio = row?['city_ibge'];
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
      ubsName: ubsName != null ? formatCnesDisplayName(ubsName) : (row?['ubs_name'] != null ? formatCnesDisplayName(row!['ubs_name'].toString()) : null),
      zipCode: row?['zip_code']?.toString(),
      street: row?['street']?.toString(),
      number: row?['number']?.toString(),
      neighborhood: row?['neighborhood']?.toString(),
      complement: row?['complement']?.toString(),
      email: (row?['email'] ?? email)?.toString(),
      emergencyContact: emergencyContact,
      codigoUf: _resolveCodigoUf(row?['state_code']?.toString()),
      siglaUf: row?['state_code']?.toString(),
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
        return (name?.isNotEmpty == true) ? formatCnesDisplayName(name!) : null;
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

    final profData = row['professionals'] as Map<String, dynamic>?;
    final estabData = row['cnes_establishments'] as Map<String, dynamic>?;

    final professionalName = profData?['name'] ?? row['professional_name'];
    final professionalSpecialty = profData?['specialty'];
    final establishmentName = estabData?['name'];

    return Appointment(
      id: (row['remote_id'] ?? row['id']).toString(),
      dateTime: dateTime,
      location: formatCnesDisplayName((establishmentName ?? row['cnes_id'] ?? 'Local não informado').toString()),
      specialty: (professionalSpecialty ?? row['specialty'] ?? 'Consulta').toString(),
      professionalName: professionalName?.toString(),
      professionalId: row['professional_cns']?.toString(),
      shift: shiftRaw != null
          ? AppointmentShiftX.fromDb(shiftRaw)
          : (dateTime.hour >= 12
                ? AppointmentShift.afternoon
                : AppointmentShift.morning),
      notes: row['notes']?.toString(),
      attended: attended,
      status: status,
      syncStatus: 'synced',
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
      syncStatus: 'synced',
    );
  }

  // === Gerenciamento de Consultas ===

  Future<void> addAppointment(Appointment appt) async {
    // Generate local ID if not present
    final apptId = appt.id.isEmpty ? _uuid.v4() : appt.id;
    final finalAppt = appt.id.isEmpty ? appt.copyWith(id: apptId) : appt;

    // 1. Update memory and Local DB immediately
    _appointments = [..._appointments, finalAppt];
    notifyListeners();
    await _localDb.saveAppointment(finalAppt, syncStatus: 'pending');

    final user = _supabase.auth.currentUser;
    if (user != null && _patient != null) {
      try {
        final profile = await _supabase
            .from('patients')
            .select('id')
            .eq('cpf', _patient!.cpf)
            .maybeSingle();

        final estab = await _supabase
            .from('cnes_establishments')
            .select('id')
            .eq('cnes_id', finalAppt.location)
            .maybeSingle();

        if (profile != null) {
          final doc = {
            'patient_id': profile['id'],
            'remote_id': apptId, // Store local ID as remote_id for sync
            'date_time': finalAppt.dateTime.toUtc().toIso8601String(),
            'establishment_id': estab?['id'],
            'cnes_id': finalAppt.location,
            'specialty': finalAppt.professionalId != null ? null : finalAppt.specialty,
            'professional_cns': finalAppt.professionalId,
            'shift': finalAppt.shift.dbValue,
            'notes': finalAppt.notes,
            'status': finalAppt.attended == true
                ? 'attended'
                : finalAppt.attended == false
                ? 'missed'
                : 'scheduled',
          };
          
          // Try to insert, but also queue for sync if it fails
          try {
            await _supabase.from('appointments').insert(doc);
            await _localDb.saveAppointment(finalAppt, syncStatus: 'synced');
            // Update memory state
            _appointments = _appointments.map((a) => a.id == apptId ? a.copyWith(syncStatus: 'synced') : a).toList();
            notifyListeners();
          } catch (e) {
            await _localDb.addToSyncQueue(
              tableName: 'appointments',
              operation: 'INSERT',
              data: doc,
              localId: apptId,
            );
          }
        }
      } catch (e) {
        debugPrint('Erro ao processar agendamento: $e');
      }
    }
    try {
      await NotificationService.instance.scheduleAppointmentReminders(appt);
    } catch (e) {
      // Ignora erro de notificaes - no deve impedir salvamento
    }
  }

  Future<void> updateAppointment(Appointment appt) async {
    // 1. Update memory and Local DB
    _appointments = _appointments
        .map((e) => e.id == appt.id ? appt : e)
        .toList();
    notifyListeners();
    await _localDb.saveAppointment(appt, syncStatus: 'pending');

    final user = _supabase.auth.currentUser;
    if (user != null) {
      try {
        final targetId = appt.id;
        final isNumeric =
            int.tryParse(targetId) != null && targetId.length < 13;

        final estab = await _supabase
            .from('cnes_establishments')
            .select('id')
            .eq('cnes_id', appt.location)
            .maybeSingle();

        final doc = {
          'date_time': appt.dateTime.toUtc().toIso8601String(),
          'establishment_id': estab?['id'],
          'cnes_id': appt.location,
          'specialty': appt.professionalId != null ? null : appt.specialty,
          'professional_cns': appt.professionalId,
          'shift': appt.shift.dbValue,
          'notes': appt.notes,
          'status': appt.attended == true
              ? 'attended'
              : appt.attended == false
              ? 'missed'
              : 'scheduled',
        };

        try {
          if (isNumeric) {
            await _supabase.from('appointments').update(doc).eq('id', targetId);
          } else {
            await _supabase
                .from('appointments')
                .update(doc)
                .eq('remote_id', targetId);
          }
          await _localDb.saveAppointment(appt, syncStatus: 'synced');
          // Update memory state
          _appointments = _appointments.map((a) => a.id == targetId ? a.copyWith(syncStatus: 'synced') : a).toList();
          notifyListeners();
        } catch (e) {
          await _localDb.addToSyncQueue(
            tableName: 'appointments',
            operation: 'UPDATE',
            data: doc,
            localId: targetId,
          );
        }
      } catch (e) {
        debugPrint('Erro ao atualizar agendamento: $e');
      }
    }
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
    // 1. Update memory and Local DB
    _appointments = _appointments.where((e) => e.id != id).toList();
    notifyListeners();
    await _localDb.deleteAppointment(id);

    final user = _supabase.auth.currentUser;
    if (user != null) {
      try {
        final isNumeric = int.tryParse(id) != null && id.length < 13;
        try {
          if (isNumeric) {
            await _supabase.from('appointments').delete().eq('id', id);
          } else {
            await _supabase.from('appointments').delete().eq('remote_id', id);
          }
        } catch (e) {
          await _localDb.addToSyncQueue(
            tableName: 'appointments',
            operation: 'DELETE',
            data: {},
            localId: id,
          );
        }
      } catch (e) {
        debugPrint('Erro ao remover agendamento: $e');
      }
    }
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
    // 1. Update memory and Local DB
    _appointments = _appointments.map((appt) {
      if (appt.id == id) {
        final updated = appt.copyWith(attended: attended);
        _localDb.saveAppointment(updated, syncStatus: 'pending');
        return updated;
      }
      return appt;
    }).toList();
    notifyListeners();

    final user = _supabase.auth.currentUser;
    if (user != null) {
      try {
        final isNumeric = int.tryParse(id) != null && id.length < 13;
        final doc = {'status': attended ? 'attended' : 'missed'};

        try {
          if (isNumeric) {
            await _supabase.from('appointments').update(doc).eq('id', id);
          } else {
            await _supabase.from('appointments').update(doc).eq('remote_id', id);
          }
          final updatedAppt = _appointments.firstWhere((a) => a.id == id);
          await _localDb.saveAppointment(updatedAppt, syncStatus: 'synced');
          // Update memory state
          _appointments = _appointments.map((a) => a.id == id ? a.copyWith(syncStatus: 'synced') : a).toList();
          notifyListeners();
        } catch (e) {
          await _localDb.addToSyncQueue(
            tableName: 'appointments',
            operation: 'UPDATE',
            data: doc,
            localId: id,
          );
        }
      } catch (e) {
        debugPrint('Erro ao atualizar presença: $e');
      }
    }
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
    if (contact != null) {
      payload['phone'] = contact.replaceAll(RegExp(r'\D'), '');
    }
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
        'phone': emergencyContact.phone.replaceAll(RegExp(r'\D'), ''),
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
        'state_code': siglaUf,
        'city_ibge': codigoMunicipio,
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
    // Generate local ID if not present
    final medId = m.id.isEmpty ? _uuid.v4() : m.id;
    final finalMed = m.id.isEmpty ? Medication(
      id: medId,
      name: m.name,
      dosage: m.dosage,
      times: m.times,
      stockUnits: m.stockUnits,
      dispensationId: m.dispensationId,
    ) : m;

    // 1. Update memory and Local DB immediately
    _medications = [..._medications, finalMed];
    notifyListeners();
    await _localDb.saveMedication(finalMed, syncStatus: 'pending');

    final user = _supabase.auth.currentUser;
    if (user != null) {
      try {
        final doc = {
          'remote_id': medId,
          'owner_id': user.id,
          'name': finalMed.name,
          'dosage_instructions': finalMed.dosage,
          'frequency': finalMed.times
              .map(
                (t) =>
                    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}',
              )
              .toList(),
          'stock': finalMed.stockUnits,
          'active': true,
        };

        try {
          await _supabase.from('medications').insert(doc);
          await _localDb.saveMedication(finalMed, syncStatus: 'synced');
          // Update memory state
          _medications = _medications.map((m) => m.id == medId ? m.copyWith(syncStatus: 'synced') : m).toList();
          notifyListeners();
        } catch (e) {
          await _localDb.addToSyncQueue(
            tableName: 'medications',
            operation: 'INSERT',
            data: doc,
            localId: medId,
          );
        }
      } catch (e) {
        debugPrint('Erro ao salvar medicamento: $e');
      }
    }
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
    // 1. Update memory and Local DB
    _medications = _medications.map((e) => e.id == m.id ? m : e).toList();
    notifyListeners();
    await _localDb.saveMedication(m, syncStatus: 'pending');

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

        try {
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
          await _localDb.saveMedication(m, syncStatus: 'synced');
          // Update memory state
          _medications = _medications.map((med) => med.id == targetId ? med.copyWith(syncStatus: 'synced') : med).toList();
          notifyListeners();
        } catch (e) {
          await _localDb.addToSyncQueue(
            tableName: 'medications',
            operation: 'UPDATE',
            data: doc,
            localId: targetId,
          );
        }
      } catch (e) {
        debugPrint('Erro ao atualizar medicamento: $e');
      }
    }
    
    // Reagenda notificações após a alteração (funciona offline)
    try {
      await NotificationService.instance.cancelAll();
      await NotificationService.instance.scheduleAllMedicationReminders(_medications);
    } catch (e) {
      debugPrint('Erro ao reagendar notificações: $e');
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
    await _localDb.saveMedication(updatedMed, syncStatus: 'pending');

    final user = _supabase.auth.currentUser;
    if (user != null) {
      try {
        final targetId = oldMed.id;
        final isNumeric =
            int.tryParse(targetId) != null && targetId.length < 13;
        final doc = {'stock': newStock};
        try {
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
          await _localDb.saveMedication(updatedMed, syncStatus: 'synced');
        } catch (e) {
          await _localDb.addToSyncQueue(
            tableName: 'medications',
            operation: 'UPDATE',
            data: doc,
            localId: targetId,
          );
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
    await _localDb.saveMedication(updatedMed, syncStatus: 'pending');

    final user = _supabase.auth.currentUser;
    if (user != null) {
      try {
        final targetId = oldMed.id;
        final isNumeric =
            int.tryParse(targetId) != null && targetId.length < 13;
        final doc = {'stock': newStock};
        try {
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
          await _localDb.saveMedication(updatedMed, syncStatus: 'synced');
        } catch (e) {
          await _localDb.addToSyncQueue(
            tableName: 'medications',
            operation: 'UPDATE',
            data: doc,
            localId: targetId,
          );
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
    // 1. Update memory and Local DB
    _medications = _medications.where((e) => e.id != id).toList();
    notifyListeners();
    await _localDb.deleteMedication(id);

    final user = _supabase.auth.currentUser;
    if (user != null) {
      try {
        final isNumeric = int.tryParse(id) != null && id.length < 13;
        try {
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
          await _localDb.addToSyncQueue(
            tableName: 'medications',
            operation: 'DELETE',
            data: {},
            localId: id,
          );
        }
      } catch (e) {
        debugPrint('Erro ao remover medicamento: $e');
      }
    }
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

  String? _formatDateToIso(String? date) {
    if (date == null || date.isEmpty) return null;
    final parts = date.split('/');
    if (parts.length == 3) {
      // Assumindo DD/MM/YYYY
      final day = parts[0].padLeft(2, '0');
      final month = parts[1].padLeft(2, '0');
      final year = parts[2];
      return '$year-$month-$day';
    }
    return date; // Fallback se não for no formato esperado
  }
}
