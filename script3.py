import os

with open('lib/pages/medications_page.dart', 'r', encoding='utf-8') as f:
    content = f.read()

start_marker = "class _AcknowledgeDispensationSheetState extends State<_AcknowledgeDispensationSheet> {"
end_marker = "      return Container("

start_idx = content.find(start_marker)
end_idx = content.find(end_marker)

if start_idx != -1 and end_idx != -1:
    new_block = '''class _AcknowledgeDispensationSheetState extends State<_AcknowledgeDispensationSheet> {
  bool _isSaving = false;

  void _save() async {
    final d = widget.dispensation;
    
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

    final freqStr = d.frequencyLabel ?? '\x ao dia';
    final finalDosage = '\ (\) \';

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
          SnackBar(content: Text('Erro: \')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.dispensation;

    final freqStr = d.frequencyLabel ?? '\x ao dia';
    final horariosStr = d.scheduledTimes.join(' - ');

'''
    
    content = content[:start_idx] + new_block + content[end_idx:]
    with open('lib/pages/medications_page.dart', 'w', encoding='utf-8') as f:
        f.write(content)
else:
    print(f"Could not find markers")
