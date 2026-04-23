import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/models/medication.dart';
import '../core/widgets/app_input_decoration.dart';
import '../state/app_state.dart';

// Formatter que limita valores numéricos a um máximo
class MaxValueInputFormatter extends TextInputFormatter {
  final int maxValue;

  MaxValueInputFormatter(this.maxValue);

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) {
      return newValue;
    }

    final intValue = int.tryParse(newValue.text);
    if (intValue == null) {
      return oldValue;
    }

    if (intValue > maxValue) {
      final newText = maxValue.toString();
      return TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: newText.length),
      );
    }

    return newValue;
  }
}

class AddMedicationPage extends StatefulWidget {
  final Medication? initial;
  const AddMedicationPage({super.key, this.initial});

  @override
  State<AddMedicationPage> createState() => _AddMedicationPageState();
}

class _AddMedicationPageState extends State<AddMedicationPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _dosageCtrl = TextEditingController();
  final _stockCtrl = TextEditingController();
  final List<TimeOfDayLite> _times = [];
  bool _isSaving = false; // proteção contra cliques múltiplos
  bool _isLoadingMeds = true;

  // Variável para controlar o teclado no campo de estoque
  bool _stockKeyboardActive = false;

  List<TimeOfDayLite> _generateFromBase(TimeOfDayLite base, int n) {
    final interval = 24 * 60 / n;
    final baseMinutes = base.hour * 60 + base.minute;
    final res = <TimeOfDayLite>[];
    for (var i = 0; i < n; i++) {
      final minutes = (baseMinutes + (interval * i)).round() % (24 * 60);
      final h = minutes ~/ 60;
      final m = minutes % 60;
      res.add(TimeOfDayLite(h, m));
    }
    return res;
  }

  Map<String, List<String>> _catalogMap =
      {}; // Cache do catálogo: ativo -> [doses formatadas]

  // Listas pré-definidas
  List<String> _medNames = const [
    'Dipirona',
    'Paracetamol',
    'Ibuprofeno',
    'Amoxicilina',
    'Losartana',
    'Metformina',
    'Omeprazol',
    'Outro',
  ];
  List<String> _doseOptions = const [
    '20 mg',
    '25 mg',
    '30 mg',
    '40 mg',
    '50 mg',
    '75 mg',
    '100 mg',
    '125 mg',
    '250 mg',
    '500 mg',
    '750 mg',
    '1 g',
    '5 ml',
    '10 ml',
  ];
  final List<int> _perDayOptions = const [1, 2, 3, 4];

  String? _selectedMedName;
  String? _selectedDose;
  int? _selectedPerDay;
  
  final FocusNode _nameFocusNode = FocusNode();
  final FocusNode _customNameFocusNode = FocusNode(); // Foco dedicado para o campo de texto "Outro"
  final FocusNode _doseFocusNode = FocusNode();
  final FocusNode _freqFocusNode = FocusNode();
  final FocusNode _timeFocusNode = FocusNode();
  final FocusNode _stockFocusNode = FocusNode();
  
  String? _freqErrorText;
  bool get _isOtherMed => _selectedMedName == 'Outro';
  bool get _canSelectDose {
    if (_selectedMedName == null) return false;
    if (!_isOtherMed) return true;
    return _nameCtrl.text.trim().isNotEmpty;
  }

  bool get _canSelectFrequency => _canSelectDose && _selectedDose != null;

  bool get _canAddTime =>
      _canSelectFrequency && _selectedPerDay != null &&
      _times.length < _selectedPerDay!;

  void _onOtherMedNameChanged() {
    if (_isOtherMed && mounted) {
      setState(() {});
    }
  }

  void _showCustomSnackBar(String message, {bool isError = true}) {
    if (!mounted) return;
    final colorScheme = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: isError
            ? colorScheme.errorContainer
            : colorScheme.primaryContainer,
        duration: const Duration(seconds: 3),
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: isError
                  ? colorScheme.onErrorContainer
                  : colorScheme.onPrimaryContainer,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isError
                      ? colorScheme.onErrorContainer
                      : colorScheme.onPrimaryContainer,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _nameCtrl.addListener(_onOtherMedNameChanged);
    _loadMedications();
    final initial = widget.initial;
    if (initial != null) {
      // Nome
      if (_medNames.contains(initial.name)) {
        _selectedMedName = initial.name;
      } else {
        _selectedMedName = 'Outro';
        _nameCtrl.text = initial.name;
      }
      // Dose
      final doseMatch = RegExp(
        r'(\d+)\s*(mg|g|ml)',
        caseSensitive: false,
      ).firstMatch(initial.dosage);
      if (doseMatch != null) {
        final num = doseMatch.group(1)!.trim();
        final unit = doseMatch.group(2)!.toLowerCase();
        _selectedDose = '$num $unit';
      }
      // Frequência
      final perDayMatch =
          RegExp(r'(\d+)x', caseSensitive: false).firstMatch(initial.dosage) ??
          RegExp(
            r'(\d+)\s*/\s*\d+\s*h',
            caseSensitive: false,
          ).firstMatch(initial.dosage);
      if (perDayMatch != null) {
        final n = int.tryParse(perDayMatch.group(1)!);
        if (n != null && _perDayOptions.contains(n)) {
          _selectedPerDay = n;
        }
      }
      _times.addAll(initial.times);
      _stockCtrl.text = initial.stockUnits.toString();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (widget.initial?.dispensationId == null) {
        _nameFocusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _nameCtrl.removeListener(_onOtherMedNameChanged);
    _nameCtrl.dispose();
    _dosageCtrl.dispose();
    _stockCtrl.dispose();
    _nameFocusNode.dispose();
    _customNameFocusNode.dispose();
    _doseFocusNode.dispose();
    _freqFocusNode.dispose();
    _timeFocusNode.dispose();
    _stockFocusNode.dispose();
    super.dispose();
  }

  void _updateDoseOptions() {
    if (_selectedMedName != null &&
        _selectedMedName != 'Outro' &&
        _catalogMap.containsKey(_selectedMedName)) {
      setState(() {
        _doseOptions = _catalogMap[_selectedMedName]!;
        if (_selectedDose != null && !_doseOptions.contains(_selectedDose)) {
          _selectedDose = null;
        }
      });
    }
  }

  Future<void> _loadMedications() async {
    // ... [Manteve igual ao original]
    try {
      final prefs = await SharedPreferences.getInstance();
      const cacheKey = 'medicine_catalog_cache';
      const cacheTimeKey = 'medicine_catalog_cache_time';

      final cachedJson = prefs.getString(cacheKey);
      final cacheTime = prefs.getInt(cacheTimeKey) ?? 0;
      final cacheExpired =
          DateTime.now().millisecondsSinceEpoch - cacheTime >
          7 * 24 * 60 * 60 * 1000;

      if (cachedJson != null && !cacheExpired) {
        debugPrint('[MedicationLoader] Usando cache de medicamentos');
        final decoded = jsonDecode(cachedJson) as Map<String, dynamic>;
        _catalogMap = decoded.map(
          (k, v) => MapEntry(k, (v as List).cast<String>()),
        );
      } else {
        final response = await Supabase.instance.client
            .from('medicine_catalog')
            .select('active_principle, strength, form')
            .order('active_principle');

        final Map<String, List<String>> tempMap = {};

        for (final row in response as List) {
          final principle = row['active_principle'] as String;
          final strength = row['strength'] as String;
          final form = row['form'] as String;
          final formatted = '$strength ($form)';

          if (!tempMap.containsKey(principle)) {
            tempMap[principle] = [];
          }
          if (!tempMap[principle]!.contains(formatted)) {
            tempMap[principle]!.add(formatted);
          }
        }

        _catalogMap = tempMap;

        try {
          await prefs.setString(cacheKey, jsonEncode(_catalogMap));
          await prefs.setInt(
            cacheTimeKey,
            DateTime.now().millisecondsSinceEpoch,
          );
        } catch (e) {
          debugPrint('[MedicationLoader] Erro ao salvar cache: $e');
        }
      }

      final names = _catalogMap.keys.toList()..sort();
      names.add('Outro');

      if (mounted) {
        setState(() {
          _medNames = names;
          _isLoadingMeds = false;

          if (widget.initial != null) {
            if (_medNames.contains(widget.initial!.name)) {
              _selectedMedName = widget.initial!.name;
              _updateDoseOptions();
              if (_doseOptions.contains(
                widget.initial!.dosage
                    .replaceAll(RegExp(r'\s*\d+x ao dia$'), '')
                    .trim(),
              )) {
                _selectedDose = widget.initial!.dosage
                    .replaceAll(RegExp(r'\s*\d+x ao dia$'), '')
                    .trim();
              }
            } else {
              _selectedMedName = 'Outro';
              _nameCtrl.text = widget.initial!.name;
            }
          }
        });
      }
    } catch (e) {
      debugPrint('Erro ao carregar medicamentos do catálogo: $e');
      if (mounted) {
        setState(() {
          _medNames = [
            'Dipirona',
            'Paracetamol',
            'Ibuprofeno',
            'Amoxicilina',
            'Losartana',
            'Metformina',
            'Omeprazol',
            'Outro',
          ];
          _isLoadingMeds = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSusMed = widget.initial?.dispensationId != null;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            widget.initial == null
                ? 'Adicionar medicamento'
                : 'Editar medicamento',
          ),
        ),
        body: Form(
          key: _formKey,
          child: ScrollConfiguration(
            behavior: ScrollConfiguration.of(context).copyWith(overscroll: false, scrollbars: false),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (isSusMed)
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: Theme.of(context).colorScheme.onPrimaryContainer,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Apenas o horário pode ser editado.',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onPrimaryContainer,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                _SelectorField(
                  label: 'Nome do medicamento',
                  icon: Icons.medical_services_rounded,
                  focusNode: _nameFocusNode,
                  valueText: isSusMed
                      ? widget.initial!.name
                      : (_isOtherMed ? 'Outro' : (_selectedMedName ?? '')),
                  onTap: isSusMed
                      ? null
                      : () async {
                          FocusScope.of(context).unfocus();
                          if (_isLoadingMeds) {
                            _showCustomSnackBar('Aguarde, carregando lista...', isError: false);
                            return;
                          }
                          final choice = await _openBottomSheet(context, 'Selecione o medicamento', _medNames);
                          await Future.delayed(const Duration(milliseconds: 100));
                          if (!mounted) return;
                          
                          if (choice == null) {
                            _nameFocusNode.requestFocus(); // Volta pro mesmo campo
                            return;
                          }
                          
                          setState(() {
                            _selectedMedName = choice;
                            if (!_isOtherMed) {
                              _nameCtrl.clear();
                              _updateDoseOptions();
                            }
                          });
                          
                          // Direciona foco para o próximo passo adequado
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (!mounted) return;
                            if (_isOtherMed) {
                              _customNameFocusNode.requestFocus();
                            } else {
                              _doseFocusNode.requestFocus();
                            }
                          });
                        },
                  validator: () => _selectedMedName == null && !isSusMed ? 'Selecione um medicamento' : null,
                  enabled: !isSusMed,
                ),
                if (_isOtherMed && !isSusMed) ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    focusNode: _customNameFocusNode,
                    controller: _nameCtrl,
                    textInputAction: TextInputAction.next,
                    onFieldSubmitted: (_) => _doseFocusNode.requestFocus(), // Passa o foco adiante pelo teclado
                    decoration: AppInputDecoration.build(
                      context,
                      labelText: 'Outro (digite o nome)',
                      prefixIcon: Icon(Icons.edit, color: Theme.of(context).colorScheme.primary),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Informe o nome' : null,
                  ),
                ],
                const SizedBox(height: 12),
                _SelectorField(
                  label: 'Dose',
                  icon: Icons.medication,
                  focusNode: _doseFocusNode,
                  valueText: isSusMed ? widget.initial!.dosage : (_selectedDose ?? ''),
                  onTap: isSusMed || !_canSelectDose
                      ? null
                      : () async {
                          FocusScope.of(context).unfocus();
                          final choice = await _openBottomSheet(context, 'Selecione a dose', _doseOptions);
                          await Future.delayed(const Duration(milliseconds: 100));
                          if (!mounted) return;
                          
                          if (choice == null) {
                            _doseFocusNode.requestFocus();
                            return;
                          }
                          
                          setState(() => _selectedDose = choice);
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (!mounted) return;
                            _freqFocusNode.requestFocus();
                          });
                        },
                  validator: () => _selectedDose == null && !isSusMed ? 'Selecione a dose' : null,
                  enabled: !isSusMed && _canSelectDose,
                ),
                const SizedBox(height: 12),
                _SelectorField(
                  label: 'Frequência',
                  icon: Icons.schedule,
                  focusNode: _freqFocusNode,
                  errorText: _freqErrorText,
                  valueText: _selectedPerDay != null ? _freqLabel(_selectedPerDay!) : '',
                  onTap: isSusMed || !_canSelectFrequency
                      ? null
                      : () async {
                          FocusScope.of(context).unfocus();
                          final options = _perDayOptions.map(_freqLabel).toList();
                          final choice = await _openBottomSheet(context, 'Selecione a frequência', options);
                          await Future.delayed(const Duration(milliseconds: 100));
                          if (!mounted) return;
                          
                          if (choice == null) {
                            _freqFocusNode.requestFocus();
                            return;
                          }
                          
                          final idx = options.indexOf(choice);
                          setState(() {
                            _freqErrorText = null;
                            _selectedPerDay = _perDayOptions[idx];
                            if (_selectedPerDay != null && _times.length > _selectedPerDay!) {
                              _times.removeRange(_selectedPerDay!, _times.length);
                            }
                          });
                          
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (!mounted) return;
                            if (_canAddTime) {
                              _timeFocusNode.requestFocus();
                            } else {
                              setState(() => _stockKeyboardActive = false); // Garante que não suba o teclado
                              _stockFocusNode.requestFocus();
                            }
                          });
                        },
                  validator: isSusMed ? () => null : () => _selectedPerDay == null ? 'Selecione a frequência' : null,
                  enabled: !isSusMed && _canSelectFrequency,
                ),
                const SizedBox(height: 12),
                _SelectorField(
                  label: 'Adicionar horário',
                  icon: Icons.access_time,
                  focusNode: _timeFocusNode,
                  valueText: '',
                  onTap: !isSusMed && !_canAddTime
                      ? null
                      : isSusMed &&
                              widget.initial != null &&
                              _times.length >= widget.initial!.times.length
                          ? null
                          : _pickTime,
                  validator: () {
                    if (isSusMed) {
                      final expected = widget.initial?.times.length;
                      if (_times.isEmpty) return 'Adicione pelo menos um horário';
                      if (expected != null && _times.length != expected) {
                        return 'Adicione exatamente $expected horário(s)';
                      }
                      return null;
                    }
                    if (_selectedPerDay != null && _times.length != _selectedPerDay!) {
                      return 'Adicione exatamente $_selectedPerDay horário(s)';
                    }
                    if (_times.isEmpty) return 'Adicione pelo menos um horário';
                    return null;
                  },
                  enabled: !isSusMed && _canAddTime,
                ),
                if (_times.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _times
                          .asMap()
                          .entries
                          .map(
                            (e) => InputChip(
                              label: Text(_fmt(e.value)),
                              onPressed: () => _pickTime(e.key),
                              onDeleted: () => setState(() {
                                _times.removeAt(e.key);
                                _timeFocusNode.requestFocus(); // Volta foco se apagar tempo
                              }),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _stockCtrl,
                  focusNode: _stockFocusNode,
                  enabled: !isSusMed,
                  readOnly: !_stockKeyboardActive, // Exibe border outline ativa sem abrir o teclado
                  onTap: () {
                    if (!_stockKeyboardActive) {
                      setState(() => _stockKeyboardActive = true);
                      // Tira e coloca o foco rapidamente para forçar abertura do teclado agora que ele não é mais readOnly
                      _stockFocusNode.unfocus();
                      Future.delayed(const Duration(milliseconds: 50), () {
                        if (mounted) _stockFocusNode.requestFocus();
                      });
                    }
                  },
                  decoration: AppInputDecoration.build(
                    context,
                    labelText: 'Estoque inicial (unidades)',
                    prefixIcon: Icon(
                      Icons.inventory,
                      color: !isSusMed
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    MaxValueInputFormatter(120),
                  ],
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Informe o estoque inicial';
                    final n = int.tryParse(v);
                    if (n == null || n < 0) return 'Informe um número válido';
                    if (n > 120) return 'Estoque máximo: 120 unidades';
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                FilledButton(
                  style: FilledButton.styleFrom(
                    minimumSize: Size(
                      double.infinity,
                      48 * (Theme.of(context).textTheme.bodyMedium?.fontSize ?? 18) / 18,
                    ),
                    backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                    foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                  onPressed: _isSaving ? null : _save,
                  child: _isSaving
                      ? SizedBox(
                          height: Theme.of(context).iconTheme.size ?? 24,
                          width: Theme.of(context).iconTheme.size ?? 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Theme.of(context).colorScheme.onPrimaryContainer,
                          ),
                        )
                      : Text('Salvar', style: Theme.of(context).textTheme.labelLarge),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pickTime([int? editIndex]) async {
    FocusScope.of(context).unfocus();
    final isSusMed = widget.initial?.dispensationId != null;

    if (!isSusMed && editIndex == null) {
      if (_selectedPerDay == null) {
        setState(() => _freqErrorText = 'Defina a frequência primeiro');
        _freqFocusNode.requestFocus();
        return;
      }
      if (_times.length >= _selectedPerDay!) {
        setState(() => _freqErrorText = 'Limite de $_selectedPerDay horário(s) atingido');
        _freqFocusNode.requestFocus();
        return;
      }
    }

    if (isSusMed && editIndex == null && widget.initial != null && _times.length >= widget.initial!.times.length) {
      _showCustomSnackBar('Já existem todos os horários da UBS');
      return;
    }

    final t = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 0, minute: 0),
      initialEntryMode: TimePickerEntryMode.input,
      // ... (Manteve builder original do bug de listener do Flutter)
    );
    
    // Se cancelou o modal de tempo, mantemos o foco no botão de tempo
    if (t == null) {
      _timeFocusNode.requestFocus();
      return;
    }

    final lite = TimeOfDayLite(t.hour, t.minute);
    final targetCount = !isSusMed ? (_selectedPerDay ?? 1) : (widget.initial?.times.length ?? 1);

    if (editIndex != null) {
      final existing = _times.indexWhere((e) => e.hour == lite.hour && e.minute == lite.minute);
      if (existing != -1 && existing != editIndex) {
        _showCustomSnackBar('Horário já adicionado');
        _timeFocusNode.requestFocus();
        return;
      }
      setState(() {
        _times[editIndex] = lite;
        _times.sort((a, b) => a.hour != b.hour ? a.hour - b.hour : a.minute - b.minute);
      });

      if (_times.length != targetCount) {
        _timeFocusNode.requestFocus();
      } else {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          setState(() => _stockKeyboardActive = false);
          _stockFocusNode.requestFocus();
        });
      }
      return;
    }

    if (_times.isEmpty && targetCount > 1) {
      setState(() {
        _times.clear();
        _times.addAll(_generateFromBase(lite, targetCount));
        _times.sort((a, b) => a.hour != b.hour ? a.hour - b.hour : a.minute - b.minute);
      });
    } else {
      final exists = _times.any((e) => e.hour == lite.hour && e.minute == lite.minute);
      if (exists) {
        _showCustomSnackBar('Horário já adicionado');
        _timeFocusNode.requestFocus();
      } else {
        setState(() {
          _times.add(lite);
          _times.sort((a, b) => a.hour != b.hour ? a.hour - b.hour : a.minute - b.minute);
        });
      }
    }

    if (_times.length != targetCount) {
      _timeFocusNode.requestFocus(); // Foco permanece se ainda faltam horários
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => _stockKeyboardActive = false); // Mantém o readOnly true antes do focus
        _stockFocusNode.requestFocus(); // Foco visual ativado sem pop-up do teclado!
      });
    }
  }

  String _fmt(TimeOfDayLite t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _save() async {
    // ... [Manteve igual ao original]
    if (_isSaving) return;
    if (!_formKey.currentState!.validate()) return;

    final isSusMed = widget.initial?.dispensationId != null;

    if (!isSusMed) {
      if (_selectedPerDay == null) {
        _showCustomSnackBar('Selecione a frequência');
        return;
      }
      if (_times.length != _selectedPerDay!) {
        _showCustomSnackBar('Adicione exatamente $_selectedPerDay horário(s)');
        return;
      }
    } else if (_times.isEmpty) {
      _showCustomSnackBar('Adicione pelo menos um horário');
      return;
    } else if (isSusMed && widget.initial != null &&
        _times.length != widget.initial!.times.length) {
      _showCustomSnackBar(
          'Adicione exatamente ${widget.initial!.times.length} horário(s)');
      return;
    }

    String finalDosage = widget.initial?.dosage ?? '';
    String medName = widget.initial?.name ?? '';

    if (!isSusMed) {
      _dosageCtrl.text = '${_selectedDose ?? ''} ${_selectedPerDay ?? 1}x ao dia';
      finalDosage = _dosageCtrl.text.trim();
      medName = _isOtherMed ? _nameCtrl.text.trim() : (_selectedMedName ?? '');
    }

    if (medName.isEmpty) {
      _showCustomSnackBar('Informe o nome do medicamento');
      return;
    }

    setState(() => _isSaving = true);

    try {
      final id = widget.initial?.id ?? DateTime.now().millisecondsSinceEpoch.toString();
      final stock = int.parse(_stockCtrl.text.trim());
      final med = Medication(
        id: id,
        name: medName,
        dosage: finalDosage,
        times: List.of(_times),
        stockUnits: stock,
        dispensationId: widget.initial?.dispensationId,
      );

      if (widget.initial == null) {
        await context.read<AppState>().addMedication(med);
      } else {
        await context.read<AppState>().updateMedication(med);
      }
    } catch (e) {
      if (mounted) {
        _showCustomSnackBar('Erro ao salvar: $e');
        setState(() => _isSaving = false);
      }
      return;
    }

    if (mounted) {
      Navigator.of(context).pop(widget.initial == null ? 'added' : 'updated');
    }
  }

  Future<String?> _openBottomSheet(
    BuildContext context,
    String title,
    List<String> options,
  ) async {
    // ... [Manteve igual ao original]
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        final maxHeight = MediaQuery.of(ctx).size.height * 0.6;
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxHeight),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
                const Divider(height: 1),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: options.length,
                    itemBuilder: (context, index) {
                      final opt = options[index];
                      return ListTile(
                        title: Text(opt),
                        onTap: () => Navigator.of(ctx).pop(opt),
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
  }

  String _freqLabel(int perDay) {
    switch (perDay) {
      case 1: return '1x/dia';
      case 2: return '2x/dia (12/12h)';
      case 3: return '3x/dia (8/8h)';
      case 4: return '4x/dia (6/6h)';
      default: return '${perDay}x/dia';
    }
  }
}

class _SelectorField extends StatelessWidget {
  // ... [Manteve igual ao original]
  final String label;
  final IconData icon;
  final String valueText;
  final String? Function()? validator;
  final Future<void> Function()? onTap;
  final FocusNode? focusNode;
  final String? errorText;
  final bool enabled;

  const _SelectorField({
    required this.label,
    required this.icon,
    required this.valueText,
    required this.onTap,
    required this.validator,
    this.focusNode,
    this.errorText,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: AbsorbPointer(
        child: TextFormField(
          focusNode: focusNode,
          readOnly: true,
          enabled: enabled,
          style: enabled
              ? null
              : TextStyle(color: colorScheme.onSurfaceVariant),
          decoration: AppInputDecoration.build(
            context,
            labelText: label,
            prefixIcon: Icon(
              icon,
              color: enabled
                  ? colorScheme.primary
                  : colorScheme.onSurfaceVariant,
            ),
          ).copyWith(errorText: errorText),
          controller: TextEditingController(text: valueText),
          validator: (_) => validator?.call(),
        ),
      ),
    );
  }
}