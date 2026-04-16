import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/models/medication.dart';
import '../core/widgets/app_input_decoration.dart';
import '../state/app_state.dart';

// Formatter que limita valores numéricos a um máximo
class MaxValueInputFormatter extends TextInputFormatter {
  final int maxValue;

  MaxValueInputFormatter(this.maxValue);

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
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

  // Listas pré-definidas
  final List<String> _medNames = const [
    'Dipirona', 'Paracetamol', 'Ibuprofeno', 'Amoxicilina', 'Losartana', 'Metformina', 'Omeprazol', 'Outro'
  ];
  final List<String> _doseOptions = const [
    '20 mg', '25 mg', '30 mg', '40 mg', '50 mg', '75 mg', '100 mg',
    '125 mg', '250 mg', '500 mg', '750 mg', '1 g',
    '5 ml', '10 ml'
  ];
  final List<int> _perDayOptions = const [1, 2, 3, 4];

  String? _selectedMedName;
  String? _selectedDose;
  int? _selectedPerDay;
  final FocusNode _freqFocusNode = FocusNode();
  String? _freqErrorText;
  bool get _isOtherMed => _selectedMedName == 'Outro';

  void _showCustomSnackBar(String message, {bool isError = true}) {
    if (!mounted) return;
    final colorScheme = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: isError ? colorScheme.errorContainer : colorScheme.primaryContainer,
        duration: const Duration(seconds: 3),
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: isError ? colorScheme.onErrorContainer : colorScheme.onPrimaryContainer,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isError ? colorScheme.onErrorContainer : colorScheme.onPrimaryContainer,
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
    final initial = widget.initial;
    if (initial != null) {
      // Nome
      if (_medNames.contains(initial.name)) {
        _selectedMedName = initial.name;
      } else {
        _selectedMedName = 'Outro';
        _nameCtrl.text = initial.name;
      }
      // Dose (tentativa de parse simples: ex.: "500mg" ou "500 mg" ou "10 ml")
      final doseMatch = RegExp(r'(\d+)\s*(mg|g|ml)', caseSensitive: false).firstMatch(initial.dosage);
      if (doseMatch != null) {
        final num = doseMatch.group(1)!.trim();
        final unit = doseMatch.group(2)!.toLowerCase();
        _selectedDose = '$num $unit';
      }
      // Frequência (ex.: "2x", "2x ao dia", "12/12h" etc)
      final perDayMatch = RegExp(r'(\d+)x', caseSensitive: false).firstMatch(initial.dosage) ??
          RegExp(r'(\d+)\s*/\s*\d+\s*h', caseSensitive: false).firstMatch(initial.dosage);
      if (perDayMatch != null) {
        final n = int.tryParse(perDayMatch.group(1)!);
        if (n != null && _perDayOptions.contains(n)) {
          _selectedPerDay = n;
        }
      }
      _times.addAll(initial.times);
      _stockCtrl.text = initial.stockUnits.toString();
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _dosageCtrl.dispose();
    _stockCtrl.dispose();
    _freqFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isSusMed = widget.initial?.dispensationId != null;

    return GestureDetector(
      onTap: () {
        // Fecha o teclado e remove o foco ao clicar fora dos campos
        FocusScope.of(context).unfocus();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.initial == null ? 'Adicionar medicamento' : 'Editar medicamento'),
        ),
        body: Form(
          key: _formKey,
          child: ScrollConfiguration(
            behavior: ScrollConfiguration.of(context).copyWith(
              overscroll: false,
              scrollbars: false,
            ),
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
                        Icon(Icons.info_outline, color: Theme.of(context).colorScheme.onPrimaryContainer),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Medicamento do SUS. O nome e a posologia não podem ser alterados.',
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
                  valueText: isSusMed ? widget.initial!.name : (_isOtherMed ? 'Outro' : (_selectedMedName ?? '')),
                  onTap: isSusMed ? null : () async {
                    FocusScope.of(context).unfocus(); // Fecha o teclado
                    final choice = await _openBottomSheet(context, 'Selecione o medicamento', _medNames);
                    // Garante que o foco não retorne após fechar o bottom sheet
                    await Future.delayed(const Duration(milliseconds: 100));
                    if (!mounted) return;
                    FocusScope.of(context).unfocus();
                    if (choice == null) return;
                    setState(() {
                      _selectedMedName = choice;
                      if (!_isOtherMed) _nameCtrl.clear();
                    });
                  },
                  validator: () => _selectedMedName == null && !isSusMed ? 'Selecione um medicamento' : null,
              ),
            if (_isOtherMed && !isSusMed) ...[
              const SizedBox(height: 12),
              TextFormField(
                controller: _nameCtrl,
                        decoration: AppInputDecoration.build(
                          context,
                          labelText: 'Outro (digite o nome)',
                          prefixIcon:
                              Icon(Icons.edit, color: Theme.of(context).colorScheme.primary),
                        ),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Informe o nome' : null,
              ),
            ],
            const SizedBox(height: 12),
            _SelectorField(
              label: 'Dose',
              icon: Icons.medication,
              valueText: isSusMed ? widget.initial!.dosage : (_selectedDose ?? ''),
              onTap: isSusMed ? null : () async {
                FocusScope.of(context).unfocus();
                final choice = await _openBottomSheet(context, 'Selecione a dose', _doseOptions);
                await Future.delayed(const Duration(milliseconds: 100));
                if (!mounted) return;
                FocusScope.of(context).unfocus();
                if (choice == null) return;
                setState(() => _selectedDose = choice);
              },
              validator: () => _selectedDose == null && !isSusMed ? 'Selecione a dose' : null,
            ),
            const SizedBox(height: 12),
            _SelectorField(
              label: 'Frequência',
              icon: Icons.schedule,
              focusNode: _freqFocusNode,
              errorText: _freqErrorText,
              valueText: _selectedPerDay != null ? _freqLabel(_selectedPerDay!) : '',
              onTap: () async {
                FocusScope.of(context).unfocus();
                final options = _perDayOptions.map(_freqLabel).toList();
                final choice = await _openBottomSheet(context, 'Selecione a frequência', options);
                await Future.delayed(const Duration(milliseconds: 100));
                if (!mounted) return;
                FocusScope.of(context).unfocus();
                if (choice == null) return;
                final idx = options.indexOf(choice);
                setState(() {
                  _freqErrorText = null;
                  _selectedPerDay = _perDayOptions[idx];
                  if (_selectedPerDay != null && _times.length > _selectedPerDay!) {
                    _times.removeRange(_selectedPerDay!, _times.length);
                  }
                });
              },
              validator: () => _selectedPerDay == null ? 'Selecione a frequência' : null,
            ),
            const SizedBox(height: 12),
            _SelectorField(
              label: 'Adicionar horário',
              icon: Icons.access_time,
              valueText: '',
              onTap: _pickTime,
              validator: () => _times.isEmpty ? 'Adicione pelo menos um horário' : null,
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
                      .map((e) => Chip(
                            label: Text(_fmt(e.value)),
                            onDeleted: () => setState(() => _times.removeAt(e.key)),
                          ))
                      .toList(),
                ),
              ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _stockCtrl,
              decoration: AppInputDecoration.build(
                context,
                labelText: 'Estoque inicial (unidades)',
                prefixIcon:
                    Icon(Icons.inventory, color: Theme.of(context).colorScheme.primary),
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                MaxValueInputFormatter(120), // Limita automaticamente a 120
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
                minimumSize: Size(double.infinity, 48 * (Theme.of(context).textTheme.bodyMedium?.fontSize ?? 18) / 18),
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
            )
          ],
        ),
        ),
      ),
      ),
    );
  }

  Future<void> _pickTime() async {
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

    final t = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 0, minute: 0),
      initialEntryMode: TimePickerEntryMode.input,
      builder: (BuildContext context, Widget? child) {
        return Listener(
          onPointerUp: (_) {
            Future.delayed(const Duration(milliseconds: 100), () {
              final node = FocusManager.instance.primaryFocus;
              if (node != null && node.context != null) {
                EditableTextState? editable;
                void findEditable(Element element) {
                  if (editable != null) return;
                  if (element is StatefulElement && element.state is EditableTextState) {
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
    if (t == null) return;
    
    final lite = TimeOfDayLite(t.hour, t.minute);
    final alreadyExists = _times.any((time) => time.hour == lite.hour && time.minute == lite.minute);
    
    if (alreadyExists) {
      _showCustomSnackBar('Este horário já foi adicionado');
      return;
    }

    setState(() {
      _times.add(lite);
      _times.sort((a, b) => a.hour != b.hour ? a.hour - b.hour : a.minute - b.minute);
    });
  }

  String _fmt(TimeOfDayLite t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}' ;

  Future<void> _save() async {
    if (_isSaving) return; // Evita cliques múltiplos
    if (!_formKey.currentState!.validate()) return;
    if (_times.isEmpty) {
      _showCustomSnackBar('Adicione pelo menos um horário');
      return;
    }
    
    final isSusMed = widget.initial?.dispensationId != null;

    // Monta a posologia a partir dos campos fixos (se não for SUS)
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
    
    setState(() => _isSaving = true); // Bloqueia botão
    
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
      // Em caso de erro, mostra mensagem e mantém na tela
      if (mounted) {
        _showCustomSnackBar('Erro ao salvar: $e');
        setState(() => _isSaving = false);
      }
      return;
    }
    
    // Navegação só acontece se não houver erro
    if (mounted) {
      Navigator.of(context).pop(widget.initial == null ? 'added' : 'updated');
    }
  }

  Future<String?> _openBottomSheet(BuildContext context, String title, List<String> options) async {
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
                ListTile(title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold))),
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
      case 1:
        return '1x/dia';
      case 2:
        return '2x/dia (12/12h)';
      case 3:
        return '3x/dia (8/8h)';
      case 4:
        return '4x/dia (6/6h)';
      default:
        return '${perDay}x/dia';
    }
  }
}

class _SelectorField extends StatelessWidget {
  final String label;
  final IconData icon;
  final String valueText;
  final String? Function()? validator;
  final Future<void> Function()? onTap;
  final FocusNode? focusNode;
  final String? errorText;

  const _SelectorField({
    required this.label,
    required this.icon,
    required this.valueText,
    required this.onTap,
    required this.validator,
    this.focusNode,
    this.errorText,
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
          decoration: AppInputDecoration.build(
            context,
            labelText: label,
            prefixIcon: Icon(icon, color: colorScheme.primary),
          ).copyWith(errorText: errorText),
          controller: TextEditingController(text: valueText),
          validator: (_) => validator?.call(),
        ),
      ),
    );
  }
}
