import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/models/appointment.dart';
import '../core/services/cnes_service.dart';
import '../core/widgets/app_input_decoration.dart';
import '../state/app_state.dart';

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
  TimeOfDay? _selectedTime;

  CnesEstabelecimento? _estabelecimenteSelecionado;

  // CNES
  List<CnesEstabelecimento> _todosEstabelecimentos = [];
  List<CnesEstabelecimento> _sugestoesFiltradas = [];
  bool _cnesCarregando = true;
  bool _dropdownAberto = false;
  bool _locationModoDigitacao =
      false; // false = readOnly (sem teclado), true = editável

  final _locationFocusNode = FocusNode();
  final _locationFieldKey = GlobalKey<FormFieldState>();
  final _overlayController = OverlayPortalController();

  // Especialidades
  List<CnesProfissional> _todosProfissionais = [];
  List<CnesProfissional> _profissionaisFiltrados = [];
  bool _especialidadesCarregando = false;
  bool _dropdownEspecAberto = false;
  bool _especModoDigitacao = false;

  final _specialtyFocusNode = FocusNode();
  final _specialtyFieldKey = GlobalKey<FormFieldState>();
  final _dateFieldKey = GlobalKey<FormFieldState>();
  final _timeFieldKey = GlobalKey<FormFieldState>();
  final _specialtyOverlayController = OverlayPortalController();

  @override
  void initState() {
    super.initState();
    final appt = widget.appointment;
    _selectedDate = appt?.dateTime;
    _selectedTime = appt != null
        ? TimeOfDay(hour: appt.dateTime.hour, minute: appt.dateTime.minute)
        : null;
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
            _carregarEspecialidades(est);

            _carregarEspecialidades(est);

            if (_locationController.text.isEmpty) {
              _locationController.removeListener(_onLocationChanged);
              _locationController.text = est.nomeFantasia;
              _locationController.addListener(_onLocationChanged);
            }
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

  Future<void> _carregarEspecialidades(CnesEstabelecimento est) async {
    final codigoUf = context.read<AppState>().patient?.codigoUf;
    final codigoMunicipio = context.read<AppState>().patient?.codigoMunicipio;
    if (codigoUf == null || codigoMunicipio == null) return;

    int ibge = est.ibgeOriginal ?? (codigoUf * 100000 + codigoMunicipio);

    setState(() {
      _especialidadesCarregando = true;
      _todosProfissionais = [];
      _profissionaisFiltrados = [];
      _specialtyController.clear();
    });

    final profList = await CnesService.buscarProfissionais(
      ibge,
      est.codigoCnes,
    );

    if (mounted) {
      setState(() {
        _todosProfissionais = profList;
        _profissionaisFiltrados = profList;
        _especialidadesCarregando = false;
      });
    }
  }

  void _onSpecialtyChanged() {
    if (_specialtyController.text.trim().isEmpty) {
      if (_selectedDate != null) {
        setState(() {
          _selectedDate = null;
          _selectedTime = null;
        });
      }
    } else {
      _specialtyFieldKey.currentState?.validate();
    }

    final q = _specialtyController.text.trim().toLowerCase();
    setState(() {
      _profissionaisFiltrados = q.isEmpty
          ? _todosProfissionais
          : _todosProfissionais
                .where((e) => e.displayText.toLowerCase().contains(q))
                .toList();
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
      _abrirDropdownEspecialidade();
    } else if (!_especModoDigitacao) {
      setState(() => _especModoDigitacao = true);
      _specialtyFocusNode.requestFocus();
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

  void _selecionarEspecialidade(CnesProfissional prof) {
    _specialtyController.text = prof.displayText;
    _specialtyController.selection = TextSelection.collapsed(
      offset: prof.displayText.length,
    );
    _fecharDropdownEspecialidade();
    FocusManager.instance.primaryFocus?.unfocus();
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
    DateTime initial = _selectedDate ?? now;

    // Garantir que a initialDate seja um dia válido (não sábado nem domingo)
    while (initial.weekday == DateTime.saturday ||
        initial.weekday == DateTime.sunday) {
      initial = initial.add(const Duration(days: 1));
    }

    // Se a data já passou (por comparar com firstDate estrito), garante que pelo menos não seja antes do firstDate
    final first = DateTime(now.year, now.month, now.day);
    if (initial.isBefore(first)) {
      initial = first;
      while (initial.weekday == DateTime.saturday ||
          initial.weekday == DateTime.sunday) {
        initial = initial.add(const Duration(days: 1));
      }
    }

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: first.add(const Duration(days: 365)),
      selectableDayPredicate: (DateTime val) =>
          val.weekday != DateTime.saturday && val.weekday != DateTime.sunday,
    );
    if (picked != null) {
      if (_selectedDate != picked) {
        setState(() {
          _selectedDate = picked;
          _selectedTime = null; // Reseta a hora ao trocar a data
        });
        // Remove erro de validação (se houvesse) quando ganha valor
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _dateFieldKey.currentState?.validate();
        });
      }
    }
  }

  Future<void> _selectTime() async {
    FocusManager.instance.primaryFocus?.unfocus();

    if (_estabelecimenteSelecionado != null &&
        _selectedDate != null &&
        _estabelecimenteSelecionado!.ibgeOriginal != null) {
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );

      try {
        final horarios = await CnesService.buscarHorariosAtendimento(
          _estabelecimenteSelecionado!.ibgeOriginal!,
          _estabelecimenteSelecionado!.codigoCnes,
        );
        if (mounted) Navigator.pop(context); // fecha loading

        final dias = {
          DateTime.monday: 'Segunda-Feira',
          DateTime.tuesday: 'Terça-Feira',
          DateTime.wednesday: 'Quarta-Feira',
          DateTime.thursday: 'Quinta-Feira',
          DateTime.friday: 'Sexta-Feira',
          DateTime.saturday: 'Sábado',
          DateTime.sunday: 'Domingo',
        };
        final diaSelecionado = dias[_selectedDate!.weekday];

        final configDia = horarios.firstWhere(
          (h) =>
              (h['diaSemana'] as String?)?.toLowerCase() ==
              diaSelecionado?.toLowerCase(),
          orElse: () => null,
        );

        if (configDia != null) {
          final startStrs = (configDia['hrInicioAtendimento'] as String).split(
            ':',
          );
          final endStrs = (configDia['hrFimAtendimento'] as String).split(':');

          final startHour = int.parse(startStrs[0]);
          final startMin = int.parse(startStrs[1]);
          final endHour = int.parse(endStrs[0]);
          final endMin = int.parse(endStrs[1]);

          // Busca horários já agendados globalmente no Supabase
          final dataBusca = DateFormat('yyyy-MM-dd').format(_selectedDate!);

          final startOfDay = DateTime(
            _selectedDate!.year,
            _selectedDate!.month,
            _selectedDate!.day,
            0,
            0,
            0,
          ).toUtc();
          final endOfDay = DateTime(
            _selectedDate!.year,
            _selectedDate!.month,
            _selectedDate!.day,
            23,
            59,
            59,
            999,
          ).toUtc();

          final String dataInicio = startOfDay.toIso8601String();
          final String dataFim = endOfDay.toIso8601String();

          Set<TimeOfDay> horariosOcupados = {};

          try {
            final agendamentosDb = await Supabase.instance.client
                .from('appointments')
                .select('date_time')
                .filter('location', 'eq', _locationController.text)
                .gte('date_time', dataInicio)
                .lte('date_time', dataFim);

            horariosOcupados = agendamentosDb.map((e) {
              final dt = DateTime.parse(e['date_time']).toLocal();
              return TimeOfDay(hour: dt.hour, minute: dt.minute);
            }).toSet();
          } catch (e) {
            debugPrint(
              'Erro (não-fatal) ao buscar horários ocupados no Supabase: $e',
            );
          }

          // Adiciona horários recém-criados localmente nesta sessão
          if (mounted) {
            final appState = context.read<AppState>();
            final agendamentosLocais = appState.appointments
                .where(
                  (a) =>
                      a.location == _locationController.text &&
                      DateFormat('yyyy-MM-dd').format(a.dateTime) == dataBusca,
                )
                .map(
                  (a) => TimeOfDay(
                    hour: a.dateTime.hour,
                    minute: a.dateTime.minute,
                  ),
                );
            horariosOcupados.addAll(agendamentosLocais);
          }

          final slots = <TimeOfDay>[];
          TimeOfDay current = TimeOfDay(hour: startHour, minute: startMin);
          final endTime = TimeOfDay(hour: endHour, minute: endMin);

          while (current.hour < endTime.hour ||
              (current.hour == endTime.hour &&
                  current.minute < endTime.minute)) {
            slots.add(current);
            int nextMin = current.minute + 30;
            int nextHour = current.hour;
            if (nextMin >= 60) {
              nextMin -= 60;
              nextHour += 1;
            }
            current = TimeOfDay(hour: nextHour, minute: nextMin);
          }

          if (slots.isEmpty) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Sem horários disponíveis na unidade neste dia.',
                  ),
                ),
              );
            }
            return;
          }

          if (!mounted) return;
          if (!mounted) return;
          final selectedFromModal = await showModalBottomSheet<TimeOfDay>(
            context: context,
            builder: (context) {
              return SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: Text(
                          'Horários em ',
                          style: Theme.of(context).textTheme.titleMedium,
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const Divider(),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 250),
                        child: GridView.builder(
                          padding: const EdgeInsets.all(16),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 3,
                                crossAxisSpacing: 8,
                                mainAxisSpacing: 12,
                                childAspectRatio: 2.5,
                              ),
                          itemCount: slots.length,
                          itemBuilder: (context, index) {
                            final slot = slots[index];
                            final ocupado = horariosOcupados.contains(slot);
                            return ActionChip(
                              onPressed: ocupado
                                  ? null
                                  : () => Navigator.pop(context, slot),
                              label: Text(
                                ocupado ? 'Ocupado' : slot.format(context),
                                style: TextStyle(
                                  color: ocupado ? Colors.grey : null,
                                  decoration: ocupado
                                      ? TextDecoration.lineThrough
                                      : null,
                                ),
                              ),
                              backgroundColor: ocupado
                                  ? Colors.grey.shade200
                                  : null,
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );

          if (selectedFromModal != null) {
            setState(() {
              _selectedTime = selectedFromModal;
            });
          }
          return;
        } else {
          if (mounted)
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Unidade fechada no dia selecionado.'),
              ),
            );
          return;
        }
      } catch (e, st) {
        debugPrint('Erro em _selectTime: $e\n$st');
        if (mounted) {
          Navigator.pop(context); // fecha loading
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Erro ao buscar horários da unidade.'),
            ),
          );
        }
      }
    }

    if (!mounted) return;

    FocusScope.of(context).unfocus();
    bool isTimePickerOpen = true;

    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? const TimeOfDay(hour: 0, minute: 0),
      initialEntryMode: TimePickerEntryMode.input,
      builder: (BuildContext context, Widget? child) {
        return Listener(
          onPointerUp: (_) {
            Future.delayed(const Duration(milliseconds: 100), () {
              if (!isTimePickerOpen) return;
              final node = FocusManager.instance.primaryFocus;
              if (node != null && node.context != null) {
                EditableTextState? editable;
                void findEditable(Element element) {
                  if (editable != null) return;
                  if (element is StatefulElement &&
                      element.state is EditableTextState) {
                    editable = element.state as EditableTextState;
                  } else {
                    element.visitChildren(findEditable);
                  }
                }

                node.context!.visitChildElements(findEditable);
                if (editable != null) {
                  final text = editable!.textEditingValue.text;
                  editable!.userUpdateTextEditingValue(
                    editable!.textEditingValue.copyWith(
                      selection: TextSelection.collapsed(offset: text.length),
                    ),
                    null,
                  );
                }
              }
            });
          },
          child: child,
        );
      },
    );
    isTimePickerOpen = false;

    if (picked != null) {
      setState(() {
        _selectedTime = picked;
      });
      // Remove erro de validação (se houvesse) quando ganha valor
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _timeFieldKey.currentState?.validate();
      });
    }
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    final dateTime = DateTime(
      _selectedDate!.year,
      _selectedDate!.month,
      _selectedDate!.day,
      _selectedTime!.hour,
      _selectedTime!.minute,
    );

    final appointment = Appointment(
      id:
          widget.appointment?.id ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      dateTime: dateTime,
      location: _locationController.text.trim(),
      specialty: _specialtyController.text.trim(),
      notes: _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
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

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.appointment != null;
    final colorScheme = Theme.of(context).colorScheme;

    final hasLocation = _locationController.text.trim().isNotEmpty;
    final hasSpecialty = _specialtyController.text.trim().isNotEmpty;
    final hasDate = _selectedDate != null;

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
                    controller: _locationController,
                    focusNode: _locationFocusNode,
                    readOnly: !_locationModoDigitacao,
                    onTap: _onLocationTap,
                    textCapitalization: TextCapitalization.words,
                    decoration: AppInputDecoration.build(
                      context,
                      labelText: 'Local',
                      hintText: 'Toque para ver as UBS ou digite para filtrar',
                      prefixIcon: Icon(
                        Icons.location_on,
                        color: colorScheme.primary,
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
                          : _locationController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _estabelecimenteSelecionado = null;
                                _locationController.clear();
                                setState(() => _locationModoDigitacao = true);
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
                                  separatorBuilder: (_, __) => Divider(
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
                                              prof.nome,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodyMedium
                                                  ?.copyWith(
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                            ),
                                            Text(
                                              prof.especialidade,
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
                                : colorScheme.onSurface.withOpacity(0.38),
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
                                    ? IconButton(
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
                                      )
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
                              : colorScheme.onSurface.withOpacity(0.38),
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

                // Hora
                GestureDetector(
                  onTap: hasDate
                      ? _selectTime
                      : () {
                          _dateFieldKey.currentState?.validate();
                        },
                  child: AbsorbPointer(
                    child: TextFormField(
                      key: _timeFieldKey,
                      readOnly: true,
                      enabled: hasDate,
                      decoration: AppInputDecoration.build(
                        context,
                        labelText: 'Horário',
                        hintText: hasDate
                            ? 'Selecione um horário'
                            : 'Escolha uma data primeiro',
                        prefixIcon: Icon(
                          Icons.access_time,
                          color: hasDate
                              ? colorScheme.primary
                              : colorScheme.onSurface.withOpacity(0.38),
                        ),
                      ),
                      controller: TextEditingController(
                        text: _selectedTime == null
                            ? ''
                            : _selectedTime!.format(context),
                      ),
                      validator: (_) =>
                          _selectedTime == null ? 'Selecione um horário' : null,
                    ),
                  ),
                ),
                const SizedBox(height: 16),

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
                          'Você receberá lembretes 1 dia antes e 1 hora antes da consulta.',
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
                  onPressed: _save,
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
        separatorBuilder: (_, __) =>
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
                          est.nomeFantasia,
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
