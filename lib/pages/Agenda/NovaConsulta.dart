import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/models/appointment.dart';
import '../../core/services/cnes_service.dart';
import '../../core/widgets/app_input_decoration.dart';
import '../../state/app_state.dart';

class AddAppointmentPage extends StatefulWidget {
  final Appointment? appointment;

  const AddAppointmentPage({super.key, this.appointment});

  @override
  State<AddAppointmentPage> createState() => _AddAppointmentPageState();
}

class _AddAppointmentPageState extends State<AddAppointmentPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _locationController;
  late TextEditingController _specialtyController;
  late TextEditingController _notesController;
  DateTime? _selectedDate;
  AppointmentShift _selectedShift = AppointmentShift.morning;

  CnesEstabelecimento? _estabelecimenteSelecionado;

  bool _isDateLoading = false;
  bool _isDateBlocked = false;
  bool _isDateFull = false;
  bool _dateAvailabilityCalculated = false;
  int? _dailyCapacity;
  int _appointmentsCount = 0;
  String? _dateAvailabilityLabel;
  Set<AppointmentShift> _blockedShifts = {};
  Set<AppointmentShift> _fullShifts = {};

  // CNES
  List<CnesEstabelecimento> _todosEstabelecimentos = [];
  List<CnesEstabelecimento> _sugestoesFiltradas = [];
  bool _cnesCarregando = true;
  bool _dropdownAberto = false;
  bool _locationModoDigitacao =
      false; // false = readOnly (sem teclado), true = editável
  bool _locationFixa = false; // local vindo do cadastro do paciente

  final _locationFocusNode = FocusNode();
  final _locationFieldKey = GlobalKey<FormFieldState>();
  final _overlayController = OverlayPortalController();

  // Especialidades
  List<CnesProfissional> _todosProfissionais = [];
  List<CnesProfissional> _profissionaisFiltrados = [];
  CnesProfissional? _profissionalSelecionado;
  bool _especialidadesCarregando = false;
  bool _dropdownEspecAberto = false;
  bool _especModoDigitacao = false;

  final _specialtyFocusNode = FocusNode();
  final _specialtyFieldKey = GlobalKey<FormFieldState>();
  final _dateFieldKey = GlobalKey<FormFieldState>();
  final _specialtyOverlayController = OverlayPortalController();
  ModalRoute<dynamic>? _modalRoute;

  @override
  void initState() {
    super.initState();
    final appt = widget.appointment;
    _selectedDate = appt?.dateTime;
    _selectedShift = appt?.shift ?? AppointmentShift.morning;
    _locationController = TextEditingController(text: appt?.location ?? '');
    _specialtyController = TextEditingController(text: appt?.specialty ?? '');
    _notesController = TextEditingController(text: appt?.notes ?? '');

    _locationController.addListener(_onLocationChanged);
    _locationFocusNode.addListener(_onFocusChanged);

    _specialtyController.addListener(_onSpecialtyChanged);
    _specialtyFocusNode.addListener(_onSpecialtyFocusChanged);

    // Carrega após o primeiro frame para ter acesso ao context (Provider)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _carregarEstabelecimentos();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != _modalRoute) {
      if (_modalRoute != null) {
        _modalRoute!.removeScopedWillPopCallback(_onWillPop);
      }
      _modalRoute = route;
      _modalRoute?.addScopedWillPopCallback(_onWillPop);
    }
  }

  @override
  void dispose() {
    _locationController.removeListener(_onLocationChanged);
    _locationFocusNode.removeListener(_onFocusChanged);

    _specialtyController.removeListener(_onSpecialtyChanged);
    _specialtyFocusNode.removeListener(_onSpecialtyFocusChanged);
    _specialtyFocusNode.dispose();
    _locationController.dispose();
    _specialtyController.dispose();
    _notesController.dispose();
    _locationFocusNode.dispose();
    _modalRoute?.removeScopedWillPopCallback(_onWillPop);
    super.dispose();
  }

  Future<void> _carregarEstabelecimentos() async {
    final patient = context.read<AppState>().patient;
    final codigoUf = patient?.codigoUf;
    final codigoMunicipio = patient?.codigoMunicipio;

    if (codigoUf == null || codigoMunicipio == null) {
      debugPrint(
        '[AddAppointment] Município não configurado no perfil — campo CNES desabilitado.',
      );
      if (mounted) {
        setState(() => _cnesCarregando = false);
      }
      return;
    }

    debugPrint(
      '[AddAppointment] Buscando estabelecimentos: UF=$codigoUf, Município=$codigoMunicipio (${patient?.nomeMunicipio})',
    );
    final resultado = await CnesService.buscarEstabelecimentos(
      codigoUf: codigoUf,
      codigoMunicipio: codigoMunicipio,
      // Filtra apenas UBS (codigo_tipo_unidade = 2)
      tipoUnidade: 2,
    );
    debugPrint(
      '[AddAppointment] Estabelecimentos carregados: ${resultado.length}',
    );
    if (mounted) {
      if (widget.appointment == null &&
          patient != null &&
          patient.ubs.isNotEmpty) {
        final codigoUbs = int.tryParse(patient.ubs);
        for (final est in resultado) {
          if ((codigoUbs != null && est.codigoCnes == codigoUbs) ||
              est.nomeFantasia.toLowerCase() == patient.ubs.toLowerCase()) {
            _estabelecimenteSelecionado = est;
            _carregarEspecialidades(est, initial: true);

            if (_locationController.text.isEmpty) {
              _locationController.removeListener(_onLocationChanged);
              _locationController.text = est.nomeFantasia;
              _locationController.addListener(_onLocationChanged);
              _locationFixa = true;
            }
            break;
          }
        }
      } else if (widget.appointment != null &&
          widget.appointment!.location.trim().isNotEmpty) {
        final appointmentLocation = widget.appointment!.location.toLowerCase();
        for (final est in resultado) {
          if (est.nomeFantasia.toLowerCase() == appointmentLocation ||
              est.codigoCnes.toString() == appointmentLocation) {
            _estabelecimenteSelecionado = est;
            _carregarEspecialidades(est, initial: true);
            break;
          }
        }
      }

      setState(() {
        _todosEstabelecimentos = resultado;
        _sugestoesFiltradas = resultado;
        _cnesCarregando = false;
      });
    }
  }

  void _onLocationChanged() {
    if (_estabelecimenteSelecionado != null &&
        _locationController.text != _estabelecimenteSelecionado!.nomeFantasia) {
      _estabelecimenteSelecionado = null;
    }

    if (_locationController.text.trim().isNotEmpty) {
      _locationFieldKey.currentState?.validate();
    }

    if (_locationController.text.trim().isEmpty &&
        _specialtyController.text.isNotEmpty) {
      _specialtyController.clear();
    }

    final q = _locationController.text.trim().toLowerCase();
    setState(() {
      _sugestoesFiltradas = q.isEmpty
          ? _todosEstabelecimentos
          : _todosEstabelecimentos
                .where(
                  (e) =>
                      e.nomeFantasia.toLowerCase().contains(q) ||
                      e.endereco.toLowerCase().contains(q),
                )
                .toList();
    });
  }

  void _onFocusChanged() {
    if (_locationFocusNode.hasFocus) {
      // Ao ganhar foco, abrimos o dropdown em modo readOnly (sem teclado).
      setState(() => _locationModoDigitacao = false);
      _abrirDropdown();
    } else {
      setState(() => _locationModoDigitacao = false);
      _fecharDropdown();
    }
  }

  /// Comportamento de toque no campo de local:
  /// 1º toque -> abre dropdown sem teclado
  /// 2º toque -> ativa digitação e abre teclado
  void _onLocationTap() {
    if (!_dropdownAberto) {
      _abrirDropdown();
    } else if (!_locationModoDigitacao) {
      setState(() => _locationModoDigitacao = true);
      _locationFocusNode.requestFocus();
    }
  }

  Future<void> _carregarEspecialidades(CnesEstabelecimento est,
      {bool initial = false}) async {
    final codigoUf = context.read<AppState>().patient?.codigoUf;
    final codigoMunicipio = context.read<AppState>().patient?.codigoMunicipio;
    if (codigoUf == null || codigoMunicipio == null) return;

    int ibge = est.ibgeOriginal ?? (codigoUf * 100000 + codigoMunicipio);

    setState(() {
      _especialidadesCarregando = true;
      _todosProfissionais = [];
      _profissionaisFiltrados = [];
      if (!initial) {
        _specialtyController.clear();
      }
    });

    final profList = await CnesService.buscarProfissionais(
      ibge,
      est.codigoCnes,
    );

    if (mounted) {
      CnesProfissional? found;
      if (widget.appointment != null) {
        final targetId = widget.appointment!.professionalId;
        final targetName = widget.appointment!.professionalName;
        final targetSpec = widget.appointment!.specialty;

        for (final p in profList) {
          if (targetId != null && p.id == targetId) {
            found = p;
            break;
          } else if (p.name == targetName && p.specialty == targetSpec) {
            found = p;
            break;
          }
        }
      }

      setState(() {
        _todosProfissionais = profList;
        _profissionaisFiltrados = profList;
        _especialidadesCarregando = false;
        if (found != null) {
          _profissionalSelecionado = found;
          _specialtyController.text = found.displayText;
        }
      });
      if (_selectedDate != null &&
          _specialtyController.text.trim().isNotEmpty) {
        await _refreshDateAvailability();
      }
    }
  }

  void _onSpecialtyChanged() {
    if (_specialtyController.text.trim().isEmpty) {
      if (_selectedDate != null) {
        setState(() {
          _selectedDate = null;
        });
      }
    } else {
      _specialtyFieldKey.currentState?.validate();
    }

    final q = _specialtyController.text
        .trim()
        .replaceAll('\n', ' - ')
        .toLowerCase();
    setState(() {
      _profissionaisFiltrados = q.isEmpty
          ? _todosProfissionais
          : _todosProfissionais.where((e) {
              final display = e.displayText.toLowerCase();
              final nomeAndSpec = '${e.name} - ${e.specialty}'
                  .toLowerCase();
              return display.contains(q) ||
                  nomeAndSpec.contains(q) ||
                  q.contains(e.name.toLowerCase());
            }).toList();
    });
  }

  void _onSpecialtyFocusChanged() {
    if (_specialtyFocusNode.hasFocus) {
      setState(() => _especModoDigitacao = false);
      _abrirDropdownEspecialidade();
    } else {
      setState(() => _especModoDigitacao = false);
      _fecharDropdownEspecialidade();
    }
  }

  void _onSpecialtyTap() {
    if (!_dropdownEspecAberto) {
      // Ao abrir sem digitação, mostra lista completa para facilitar troca.
      if (!_especModoDigitacao) {
        setState(() {
          _profissionaisFiltrados = _todosProfissionais;
        });
      }
      _abrirDropdownEspecialidade();
    } else if (!_especModoDigitacao) {
      setState(() => _especModoDigitacao = true);
      _specialtyFocusNode.requestFocus();
    }
  }

  void _clearSpecialty() {
    _specialtyController.clear();
    setState(() {
      _dateAvailabilityCalculated = false;
      _dateAvailabilityLabel = null;
      _isDateBlocked = false;
      _isDateFull = false;
      _dailyCapacity = null;
      _appointmentsCount = 0;
      _selectedShift = AppointmentShift.morning;
      _especModoDigitacao = true;
    });

    // Esconde o dropdown para evitar que ele fique mal posicionado
    if (_dropdownEspecAberto) {
      _fecharDropdownEspecialidade();
    }
  }

  void _abrirDropdownEspecialidade() {
    if (!_dropdownEspecAberto && _todosProfissionais.isNotEmpty) {
      setState(() => _dropdownEspecAberto = true);
      _specialtyOverlayController.show();
    }
  }

  void _fecharDropdownEspecialidade() {
    if (_dropdownEspecAberto) {
      setState(() => _dropdownEspecAberto = false);
      _specialtyOverlayController.hide();
    }
  }

  String _capitalize(String text) {
    if (text.isEmpty) return text;
    return text
        .toLowerCase()
        .split(' ')
        .map((word) {
          if (word.isEmpty) return word;
          // Preposições comuns para não capitalizar, se desejar. Mas o básico está ótimo:
          if (['de', 'da', 'do', 'dos', 'das', 'e'].contains(word)) return word;
          return word[0].toUpperCase() + word.substring(1);
        })
        .join(' ');
  }

  void _selecionarEspecialidade(CnesProfissional prof) {
    setState(() {
      _profissionalSelecionado = prof;
    });
    final newText =
        '${_capitalize(prof.name)}\n${_capitalize(prof.specialty)}';
    _specialtyController.text = newText;
    _specialtyController.selection = TextSelection.collapsed(
      offset: newText.length,
    );
    _fecharDropdownEspecialidade();
    FocusManager.instance.primaryFocus?.unfocus();
    if (_selectedDate != null) {
      _refreshDateAvailability();
    }
  }

  (Offset, double) _calcularPosicaoDropdownEspecialidade() {
    final box =
        _specialtyFieldKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return (Offset.zero, 300);
    final offset = box.localToGlobal(Offset.zero);
    return (Offset(offset.dx, offset.dy + box.size.height + 4), box.size.width);
  }

  void _abrirDropdown() {
    if (!_dropdownAberto) {
      setState(() => _dropdownAberto = true);
      _overlayController.show();
    }
  }

  void _fecharDropdown() {
    if (_dropdownAberto) {
      setState(() => _dropdownAberto = false);
      _overlayController.hide();
    }
  }

  void _selecionarEstabelecimento(CnesEstabelecimento est) {
    _estabelecimenteSelecionado = est;
    _carregarEspecialidades(est);

    _locationController.text = est.nomeFantasia;
    _locationController.selection = TextSelection.collapsed(
      offset: est.nomeFantasia.length,
    );
    _fecharDropdown();
    FocusManager.instance.primaryFocus?.unfocus();
    if (_selectedDate != null) {
      _refreshDateAvailability();
    }
  }

  /// Calcula posição e largura do dropdown com base no campo de texto.
  (Offset, double) _calcularPosicaoDropdown() {
    final box =
        _locationFieldKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return (Offset.zero, 300);
    final offset = box.localToGlobal(Offset.zero);
    return (Offset(offset.dx, offset.dy + box.size.height + 4), box.size.width);
  }

  Future<void> _selectDate() async {
    FocusManager.instance.primaryFocus?.unfocus();

    final now = DateTime.now();

    // Calcula o primeiro dia disponível baseado nas regras de bloqueio.
    DateTime first = DateTime(now.year, now.month, now.day);
    // Tarde vai até 17h, com 3h de antecedência limite é 14h.
    if (now.hour >= 14) {
      first = first.add(const Duration(days: 1));
    }
    while (first.weekday == DateTime.saturday ||
        first.weekday == DateTime.sunday) {
      first = first.add(const Duration(days: 1));
    }

    DateTime initial = _selectedDate ?? first;
    if (initial.isBefore(first)) {
      initial = first;
    }
    while (initial.weekday == DateTime.saturday ||
        initial.weekday == DateTime.sunday) {
      initial = initial.add(const Duration(days: 1));
    }

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: first.add(const Duration(days: 365)),
      selectableDayPredicate: (DateTime val) =>
          val.weekday != DateTime.saturday && val.weekday != DateTime.sunday,
    );

    if (picked != null && _selectedDate != picked) {
      setState(() {
        _selectedDate = picked;
        // Se escolheu hoje e já for >= 9h, obriga a selecionar tarde pois a manhã já encerrou (12h - 3h limite = 9h).
        final isToday =
            picked.year == now.year &&
            picked.month == now.month &&
            picked.day == now.day;
        if (isToday && now.hour >= 9) {
          _selectedShift = AppointmentShift.afternoon;
        } else {
          _selectedShift = AppointmentShift.morning;
        }
        _dateAvailabilityCalculated = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _dateFieldKey.currentState?.validate();
      });
      await _refreshDateAvailability();
    }
  }

  Future<void> _refreshDateAvailability() async {
    if (_selectedDate == null ||
        _estabelecimenteSelecionado == null ||
        _specialtyController.text.trim().isEmpty) {
      setState(() {
        _dateAvailabilityCalculated = false;
        _isDateLoading = false;
        _isDateBlocked = false;
        _isDateFull = false;
        _dailyCapacity = null;
        _appointmentsCount = 0;
        _dateAvailabilityLabel = null;
        _blockedShifts = {};
        _fullShifts = {};
      });
      return;
    }

    setState(() {
      _isDateLoading = true;
      _dateAvailabilityCalculated = false;
      // Mantemos _blockedShifts e _fullShifts anteriores para evitar flicker nos botões
    });

    final date = _selectedDate!;
    final now = DateTime.now();
    final isToday =
        date.year == now.year && date.month == now.month && date.day == now.day;

    // 1. Verificações de horário para hoje
    Set<AppointmentShift> timeBlocked = {};
    if (isToday) {
      if (now.hour >= 9) timeBlocked.add(AppointmentShift.morning);
      if (now.hour >= 14) timeBlocked.add(AppointmentShift.afternoon);
    }

    if (date.weekday == DateTime.saturday || date.weekday == DateTime.sunday) {
      setState(() {
        _isDateLoading = false;
        _isDateBlocked = true;
        _dailyCapacity = 0;
        _appointmentsCount = 0;
        _dateAvailabilityCalculated = true;
        _dateAvailabilityLabel = 'Dia indisponível';
        _blockedShifts = {
          AppointmentShift.morning,
          AppointmentShift.afternoon,
        };
      });
      return;
    }

    final startOfDay =
        DateTime(date.year, date.month, date.day, 0, 0, 0).toUtc();
    final endOfDay =
        DateTime(date.year, date.month, date.day, 23, 59, 59, 999).toUtc();
    final dataInicio = startOfDay.toIso8601String();
    final dataFim = endOfDay.toIso8601String();

    try {
      final cnes = _estabelecimenteSelecionado!.codigoCnes.toString();
      final spec = _profissionalSelecionado?.specialty ??
          (_specialtyController.text.contains('\n')
              ? _specialtyController.text.split('\n').last
              : _specialtyController.text.trim());
      final profCns = _profissionalSelecionado?.id;

      // 2. Buscar todos os bloqueios do dia (da unidade e do profissional)
      final blockedResp = await Supabase.instance.client
          .from('blocked_times')
          .select('shift, professional_cns')
          .eq('cnes_id', cnes)
          .gte('date_time', dataInicio)
          .lte('date_time', dataFim);

      Set<AppointmentShift> dbBlocked = {};
      for (final b in blockedResp) {
        final bProfCns = b['professional_cns'] as String?;
        
        // Um bloqueio é relevante se for da unidade toda (profCns null) 
        // ou se for específico para o profissional selecionado
        bool isRelevant = bProfCns == null; 
        if (!isRelevant && profCns != null) {
          isRelevant = bProfCns == profCns;
        }

        if (!isRelevant) continue;

        final s = (b['shift'] as String?)?.toLowerCase();
        if (s == null) continue;
        
        if (s == 'all') {
          dbBlocked.add(AppointmentShift.morning);
          dbBlocked.add(AppointmentShift.afternoon);
        } else {
          dbBlocked.add(AppointmentShiftX.fromDb(s));
        }
      }

      debugPrint('[AddAppointment] dbBlocked for $date: $dbBlocked');
      debugPrint('[AddAppointment] timeBlocked for $date: $timeBlocked');
      debugPrint('[AddAppointment] selectedShift: $_selectedShift');

      // 3. Buscar contagem de agendamentos para cada turno
      const capacity = 5;
      Map<AppointmentShift, int> counts = {
        AppointmentShift.morning: 0,
        AppointmentShift.afternoon: 0,
      };

      for (final s in AppointmentShift.values) {
        var countQuery = Supabase.instance.client
            .from('appointments')
            .select('id')
            .eq('cnes_id', cnes)
            .eq('shift', s.dbValue)
            .gte('date_time', dataInicio)
            .lte('date_time', dataFim);

        if (profCns != null) {
          countQuery = countQuery.eq('professional_cns', profCns);
        } else {
          countQuery = countQuery.eq('specialty', spec);
        }

        final resp = await countQuery;
        int c = resp.length;

        // Se estiver editando, não conta a si mesmo
        if (widget.appointment != null &&
            widget.appointment!.shift == s &&
            DateFormat('yyyy-MM-dd').format(widget.appointment!.dateTime) ==
                DateFormat('yyyy-MM-dd').format(date)) {
          c = (c > 0) ? c - 1 : 0;
        }
        counts[s] = c;
      }

      final isBlockedMorning = dbBlocked.contains(AppointmentShift.morning) || (isToday && now.hour >= 9);
      final isBlockedAfternoon = dbBlocked.contains(AppointmentShift.afternoon) || (isToday && now.hour >= 14);
      
      final isFullMorning = counts[AppointmentShift.morning]! >= capacity;
      final isFullAfternoon = counts[AppointmentShift.afternoon]! >= capacity;

      final currentBlocked = _selectedShift == AppointmentShift.morning ? isBlockedMorning : isBlockedAfternoon;
      final currentFull = _selectedShift == AppointmentShift.morning ? isFullMorning : isFullAfternoon;

      setState(() {
        _isDateLoading = false;
        _blockedShifts = {
          if (isBlockedMorning) AppointmentShift.morning,
          if (isBlockedAfternoon) AppointmentShift.afternoon,
        };
        _fullShifts = {
          if (isFullMorning) AppointmentShift.morning,
          if (isFullAfternoon) AppointmentShift.afternoon,
        };
        _isDateBlocked = currentBlocked;
        _isDateFull = currentFull;
        _dailyCapacity = capacity;
        _appointmentsCount = counts[_selectedShift] ?? 0;
        _dateAvailabilityCalculated = true;

        if (isBlockedMorning && isBlockedAfternoon) {
          _dateAvailabilityLabel = 'Dia indisponível';
        } else if (currentBlocked) {
          _dateAvailabilityLabel = 'Turno indisponível';
        } else if (currentFull) {
          _dateAvailabilityLabel = 'Turno lotado';
        } else {
          _dateAvailabilityLabel =
              '$_appointmentsCount/$_dailyCapacity vagas ocupadas';
        }
      });
    } catch (e) {
      debugPrint('[AddAppointment] Erro ao verificar disponibilidade: $e');
      setState(() {
        _isDateLoading = false;
        _dateAvailabilityCalculated = true;
        _dateAvailabilityLabel = 'Erro ao verificar disponibilidade';
      });
    }
  }

  bool get _canSaveAppointment {
    if (_selectedDate == null) return false;
    if (_isDateLoading) return false;
    if (!_dateAvailabilityCalculated) return false;
    if (_isDateBlocked || _isDateFull || (_dailyCapacity ?? 0) == 0) {
      return false;
    }
    return true;
  }

  void _showDateAvailabilityError() {
    if (_isDateBlocked) {
      _showToast(
        'Este turno está indisponível. Tente outro turno ou data.',
      );
    } else if (_isDateFull) {
      _showToast('Limite do turno atingido. Escolha outro turno ou data.');
    } else if ((_dailyCapacity ?? 0) == 0) {
      _showToast('Sem vagas disponíveis para este turno.');
    }
  }

  void _showToast(String message) {
    if (!mounted) return;
    final theme = Theme.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: theme.colorScheme.error,
        duration: const Duration(seconds: 2),
        content: Row(
          children: [
            Icon(Icons.error_outline, color: theme.colorScheme.onError),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: TextStyle(color: theme.colorScheme.onError),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_dateAvailabilityCalculated) {
      await _refreshDateAvailability();
    }
    if (_isDateLoading) return;
    if (_isDateBlocked || _isDateFull || (_dailyCapacity ?? 0) == 0) {
      _showDateAvailabilityError();
      return;
    }

    final dateTime = DateTime(
      _selectedDate!.year,
      _selectedDate!.month,
      _selectedDate!.day,
    );

    final appointment = Appointment(
      id:
          widget.appointment?.id ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      dateTime: dateTime,
      location: _estabelecimenteSelecionado!.codigoCnes.toString(),
      specialty: _profissionalSelecionado != null
          ? _profissionalSelecionado!.specialty
          : (_specialtyController.text.contains('\n')
              ? _specialtyController.text.split('\n').last
              : _specialtyController.text.trim()),
      professionalName: _profissionalSelecionado?.name ??
          (_specialtyController.text.contains('\n')
              ? _specialtyController.text.split('\n').first
              : null),
      professionalId: _profissionalSelecionado?.id,
      notes: _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
      shift: _selectedShift,
      attended: widget.appointment?.attended,
    );

    final appState = context.read<AppState>();
    if (widget.appointment == null) {
      appState.addAppointment(appointment);
      Navigator.pop(context, 'added');
    } else {
      appState.updateAppointment(appointment);
      Navigator.pop(context, 'updated');
    }
  }

  Future<bool> _onWillPop() async {
    if (_dropdownAberto || _dropdownEspecAberto) {
      if (_dropdownAberto) _fecharDropdown();
      if (_dropdownEspecAberto) _fecharDropdownEspecialidade();
      return true;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.appointment != null;
    final colorScheme = Theme.of(context).colorScheme;

    final hasLocation = _locationController.text.trim().isNotEmpty;
    final hasSpecialty = _specialtyController.text.trim().isNotEmpty;

    return GestureDetector(
      onTap: () {
        FocusManager.instance.primaryFocus?.unfocus();
        _fecharDropdown();
        _fecharDropdownEspecialidade();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(isEditing ? 'Editar consulta' : 'Nova consulta'),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Campo Local com dropdown próprio via OverlayPortal ──
                OverlayPortal(
                  controller: _overlayController,
                  overlayChildBuilder: (overlayContext) {
                    final (pos, width) = _calcularPosicaoDropdown();
                    final mq = MediaQuery.of(context);
                    final alturaDisponivel =
                        mq.size.height - mq.viewInsets.bottom - pos.dy - 8;
                    return Positioned(
                      left: pos.dx,
                      top: pos.dy,
                      width: width,
                      child: MediaQuery(
                        data: mq,
                        child: _DropdownCnes(
                          sugestoes: _sugestoesFiltradas,
                          carregando: _cnesCarregando,
                          colorScheme: colorScheme,
                          onSelected: _selecionarEstabelecimento,
                          maxHeight: alturaDisponivel.clamp(
                            120.0,
                            double.infinity,
                          ),
                        ),
                      ),
                    );
                  },
                  child: TextFormField(
                    key: _locationFieldKey,
                    controller: _locationModoDigitacao
                        ? _locationController
                        : TextEditingController(
                            text: formatCnesDisplayName(
                              _locationController.text,
                            ),
                          ),
                    focusNode: _locationFocusNode,
                    enabled: !_locationFixa,
                    readOnly: !_locationModoDigitacao,
                    onTap: _locationFixa ? null : _onLocationTap,
                    textCapitalization: TextCapitalization.words,
                    decoration: AppInputDecoration.build(
                      context,
                      labelText: 'Local',
                      hintText: 'Toque para ver as UBS ou digite para filtrar',
                      prefixIcon: Icon(
                        Icons.location_on,
                        color: _locationFixa
                            ? colorScheme.onSurfaceVariant.withValues(alpha: 0.38)
                            : colorScheme.primary,
                      ),
                      suffixIcon: _cnesCarregando
                          ? Padding(
                              padding: const EdgeInsets.all(12),
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: colorScheme.primary,
                                ),
                              ),
                            )
                          : _locationFixa
                          ? null
                          : _locationController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _estabelecimenteSelecionado = null;
                                _locationController.clear();
                                setState(() {
                                  _locationModoDigitacao = true;
                                  _locationFixa = false;
                                });
                                _locationFocusNode.requestFocus();
                                _abrirDropdown();
                              },
                            )
                          : IconButton(
                              icon: Icon(
                                _dropdownAberto
                                    ? Icons.arrow_drop_up
                                    : Icons.arrow_drop_down,
                                color: colorScheme.onSurfaceVariant,
                              ),
                              onPressed: () {
                                if (_dropdownAberto) {
                                  _fecharDropdown();
                                } else {
                                  _onLocationTap();
                                }
                              },
                            ),
                    ),
                    validator: (v) => v == null || v.trim().isEmpty
                        ? 'Informe o local'
                        : null,
                  ),
                ),
                const SizedBox(height: 16),
                // Especialidade
                OverlayPortal(
                  controller: _specialtyOverlayController,
                  overlayChildBuilder: (overlayContext) {
                    final (pos, width) =
                        _calcularPosicaoDropdownEspecialidade();
                    final mq = MediaQuery.of(overlayContext);
                    double top = pos.dy;
                    final bottomSpace =
                        mq.size.height - top - mq.viewInsets.bottom;
                    double maxHeight = 300.0;
                    if (bottomSpace < maxHeight) {
                      top = pos.dy - 32 - mq.viewInsets.bottom - (200.0);
                      if (top < 80) top = 80;
                      maxHeight = pos.dy - top - 8;
                    }

                    return Positioned(
                      left: pos.dx,
                      top: top,
                      width: width,
                      child: Material(
                        elevation: 6,
                        borderRadius: BorderRadius.circular(8),
                        color: colorScheme.surface,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(maxHeight: maxHeight),
                          child: _especialidadesCarregando
                              ? Padding(
                                  padding: const EdgeInsets.all(20),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: colorScheme.primary,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        'Buscando especialidades...',
                                        style: Theme.of(overlayContext)
                                            .textTheme
                                            .bodyMedium
                                            ?.copyWith(
                                              color:
                                                  colorScheme.onSurfaceVariant,
                                            ),
                                      ),
                                    ],
                                  ),
                                )
                              : _profissionaisFiltrados.isEmpty
                              ? Padding(
                                  padding: const EdgeInsets.all(20),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.search_off,
                                        color: colorScheme.onSurfaceVariant,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          'Nenhum profissional \nencontrada.',
                                          style: Theme.of(overlayContext)
                                              .textTheme
                                              .bodySmall
                                              ?.copyWith(
                                                color: colorScheme
                                                    .onSurfaceVariant,
                                              ),
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : ListView.separated(
                                  padding: EdgeInsets.zero,
                                  shrinkWrap: true,
                                  itemCount: _profissionaisFiltrados.length,
                                  separatorBuilder: (_, _) => Divider(
                                    height: 1,
                                    color: colorScheme.outlineVariant,
                                  ),
                                  itemBuilder: (_, index) {
                                    final prof = _profissionaisFiltrados[index];
                                    return InkWell(
                                      onTap: () =>
                                          _selecionarEspecialidade(prof),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 10,
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              _capitalize(prof.name),
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodyMedium
                                                  ?.copyWith(
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                            ),
                                            Text(
                                              _capitalize(prof.specialty),
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodySmall
                                                  ?.copyWith(
                                                    color: colorScheme
                                                        .onSurfaceVariant,
                                                  ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                        ),
                      ),
                    );
                  },
                  child: GestureDetector(
                    onTap: !hasLocation
                        ? () {
                            _locationFieldKey.currentState?.validate();
                            _locationFocusNode.requestFocus();
                          }
                        : null,
                    child: AbsorbPointer(
                      absorbing: !hasLocation,
                      child: TextFormField(
                        key: _specialtyFieldKey,
                        controller: _specialtyController,
                        focusNode: _specialtyFocusNode,
                        readOnly: !_especModoDigitacao,
                        enabled: hasLocation,
                        maxLines: null,
                        onTap: () {
                          if (_todosProfissionais.isNotEmpty) {
                            _onSpecialtyTap();
                          }
                        },
                        decoration: AppInputDecoration.build(
                          context,
                          labelText: 'Especialidade',
                          hintText: hasLocation
                              ? 'Selecione uma especialidade'
                              : 'Escolha um local primeiro',
                          prefixIcon: Icon(
                            Icons.medical_services,
                            color: hasLocation
                                ? colorScheme.primary
                                : colorScheme.onSurface.withValues(alpha: 0.38),
                          ),
                          suffixIcon: _especialidadesCarregando
                              ? Container(
                                  width: 24,
                                  height: 24,
                                  padding: const EdgeInsets.all(12),
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: colorScheme.primary,
                                  ),
                                )
                              : (_todosProfissionais.isNotEmpty && hasLocation
                                    ? (_specialtyController.text.isNotEmpty
                                          ? IconButton(
                                              icon: const Icon(Icons.clear),
                                              onPressed: _clearSpecialty,
                                            )
                                          : IconButton(
                                              icon: Icon(
                                                _dropdownEspecAberto
                                                    ? Icons.keyboard_arrow_up
                                                    : Icons.keyboard_arrow_down,
                                                color: colorScheme.outline,
                                              ),
                                              onPressed: () {
                                                if (_dropdownEspecAberto) {
                                                  _fecharDropdownEspecialidade();
                                                } else {
                                                  _onSpecialtyTap();
                                                }
                                              },
                                            ))
                                    : null),
                        ),
                        validator: (v) => v == null || v.trim().isEmpty
                            ? 'Informe a especialidade'
                            : null,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Data
                GestureDetector(
                  onTap: hasSpecialty
                      ? _selectDate
                      : () {
                          _specialtyFieldKey.currentState?.validate();
                          _specialtyFocusNode.requestFocus();
                        },
                  child: AbsorbPointer(
                    child: TextFormField(
                      key: _dateFieldKey,
                      readOnly: true,
                      enabled: hasSpecialty,
                      decoration: AppInputDecoration.build(
                        context,
                        labelText: 'Data',
                        hintText: hasSpecialty
                            ? 'Selecione uma data'
                            : 'Escolha uma especialidade primeiro',
                        prefixIcon: Icon(
                          Icons.calendar_today,
                          color: hasSpecialty
                              ? colorScheme.primary
                              : colorScheme.onSurface.withValues(alpha: 0.38),
                        ),
                      ),
                      controller: TextEditingController(
                        text: _selectedDate == null
                            ? ''
                            : DateFormat('dd/MM/yyyy').format(_selectedDate!),
                      ),
                      validator: (_) =>
                          _selectedDate == null ? 'Selecione uma data' : null,
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Turno (bloqueado até selecionar a data)
                Opacity(
                  opacity: _selectedDate == null ? 0.6 : 1,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Turno',
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                      const SizedBox(height: 8),
                      SegmentedButton<AppointmentShift>(
                        segments: [
                          ButtonSegment<AppointmentShift>(
                            value: AppointmentShift.morning,
                            label: const Text('Manhã'),
                            enabled: !_blockedShifts.contains(AppointmentShift.morning) && 
                                     !_fullShifts.contains(AppointmentShift.morning),
                          ),
                          ButtonSegment<AppointmentShift>(
                            value: AppointmentShift.afternoon,
                            label: const Text('Tarde'),
                            enabled: !_blockedShifts.contains(AppointmentShift.afternoon) && 
                                     !_fullShifts.contains(AppointmentShift.afternoon),
                          ),
                        ],
                        selected: {_selectedShift},
                        onSelectionChanged: _selectedDate == null
                            ? null
                            : (selected) {
                                final next = selected.first;
                                if (next == _selectedShift) {
                                  return;
                                }
                                setState(() {
                                  _selectedShift = next;
                                  _dateAvailabilityCalculated = false;
                                });
                                _refreshDateAvailability();
                              },
                      ),
                      if (_selectedDate == null) ...[
                        const SizedBox(height: 6),
                        Text(
                          'Selecione a data para liberar o turno.',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                if (_isDateLoading)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(10, 0, 0, 16),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: colorScheme.primary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text('Verificando disponibilidade...'),
                      ],
                    ),
                  ),
                if (_dateAvailabilityCalculated &&
                    _dateAvailabilityLabel != null) ...[
                  Text(
                    _dateAvailabilityLabel!,
                    style: TextStyle(
                      color: _isDateBlocked || _isDateFull
                          ? colorScheme.error
                          : colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // Observações
                TextFormField(
                  controller: _notesController,
                  decoration: AppInputDecoration.build(
                    context,
                    labelText: 'Observações (opcional)',
                    hintText: 'Ex: Levar exames anteriores',
                    prefixIcon: Icon(Icons.note, color: colorScheme.primary),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 24),

                // Informação sobre lembretes
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: colorScheme.secondary),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.notifications_active,
                        color: colorScheme.onSecondaryContainer,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Limite de 5 consultas por turno. Atendimento por ordem de chegada na UBS.',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: colorScheme.onSecondaryContainer,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Botão Salvar
                FilledButton.icon(
                  onPressed: _canSaveAppointment ? _save : null,
                  icon: const Icon(Icons.check),
                  label: Text(
                    isEditing ? 'Salvar Alterações' : 'Agendar Consulta',
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: colorScheme.primaryContainer,
                    foregroundColor: colorScheme.onPrimaryContainer,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Widget do dropdown de estabelecimentos CNES ───────────────────────────────

class _DropdownCnes extends StatelessWidget {
  final List<CnesEstabelecimento> sugestoes;
  final bool carregando;
  final ColorScheme colorScheme;
  final ValueChanged<CnesEstabelecimento> onSelected;
  final double maxHeight;

  const _DropdownCnes({
    required this.sugestoes,
    required this.carregando,
    required this.colorScheme,
    required this.onSelected,
    required this.maxHeight,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 6,
      borderRadius: BorderRadius.circular(8),
      color: colorScheme.surface,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: carregando
            ? _buildLoading(context)
            : sugestoes.isEmpty
            ? _buildVazio(context)
            : _buildLista(context),
      ),
    );
  }

  Widget _buildLoading(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'Buscando estabelecimentos...',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVazio(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Icon(Icons.search_off, color: colorScheme.onSurfaceVariant, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Nenhuma UBS encontrada para este município.\nDigite livremente o nome do local.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLista(BuildContext context) {
    // Use ConstrainedBox para limitar a altura máxima, mas permita que o
    // ListView (com shrinkWrap: true) ocupe somente a altura necessária
    // quando houver poucos itens.
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: ListView.separated(
        padding: EdgeInsets.zero,
        shrinkWrap: true,
        itemCount: sugestoes.length,
        separatorBuilder: (_, _) =>
            Divider(height: 1, color: colorScheme.outlineVariant),
        itemBuilder: (context, index) {
          final est = sugestoes[index];
          return InkWell(
            onTap: () => onSelected(est),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  Icon(
                    Icons.local_hospital_outlined,
                    color: colorScheme.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          est.displayText,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: colorScheme.onSurface,
                                fontWeight: FontWeight.w500,
                              ),
                        ),
                        if (est.endereco.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            est.endereco,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: colorScheme.onSurfaceVariant),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
