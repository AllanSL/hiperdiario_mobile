import os

with open('lib/pages/medications_page.dart', 'r', encoding='utf-8') as f:
    text = f.read()

import re

# Match class through container start
pattern = re.compile(r"class _AcknowledgeDispensationSheetState extends State<_AcknowledgeDispensationSheet> \{.*?return Container\(", re.DOTALL)

new_text = '''class _AcknowledgeDispensationSheetState extends State<_AcknowledgeDispensationSheet> {
  bool _isSaving = false;

  void _save() async {
    final d = widget.dispensation;
    
    // Converte scheduledTimes (array de string 'HH:mm') em TimeOfDayLite
    final times = <TimeOfDayLite>[];
    for (final timeStr in d.scheduledTimes) {
      final parts = timeStr.split(':');
      if (parts.length >= 2) {
        final h = int.tryParse(parts[0]) ?? 0;
        final m = int.tryParse(parts[1]) ?? 0;
        times.add(TimeOfDayLite(h, m));
      }
    }

    setState(() => _isSaving = true);

    final freqStr = d.frequencyLabel ?? 'x ao dia';
    final finalDosage = ' () ';

    try {
      await context.read<AppState>().acknowledgeDispensation(
        widget.dispensation,
        times,
        finalDosage,
      );
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Medicamento da UBS sincronizado e alarmes ativados!'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: ')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.dispensation;

    final freqStr = d.frequencyLabel ?? 'x ao dia';
    final horariosStr = d.scheduledTimes.join(' - ');

    return Container('''

new_content = pattern.sub(new_text.replace('\\', '\\\\').replace('$', '\\$'), text)

# wait I don't need to replace $ in python string literals.
# let me just write exactly what's above but escape properly for regex sub
new_content = pattern.sub(new_text.replace('\\\\', '\\\\\\\\'), text)

with open('lib/pages/medications_page.dart', 'w', encoding='utf-8') as f:
    f.write(new_content)
