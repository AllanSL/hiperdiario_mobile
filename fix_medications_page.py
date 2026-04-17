import os

with open('lib/pages/medications_page.dart', 'r', encoding='utf-8') as f:
    content = f.read()

start = "class _AcknowledgeDispensationSheetState extends State<_AcknowledgeDispensationSheet> {"
end = "}\n}"

idx_start = content.find(start)
idx_end = content.find(end, idx_start)

if idx_start != -1 and idx_end != -1:
    new_code = '''class _AcknowledgeDispensationSheetState extends State<_AcknowledgeDispensationSheet> {
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

    return Container(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Configurar medicamento do SUS',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text('\ - \ un. recebidas.'),
          const SizedBox(height: 24),
          Text(
            'Frequência indicada: \',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          if (horariosStr.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Horários pré-definidos: \',
              style: const TextStyle(fontSize: 14),
            ),
          ],
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: (_isSaving || d.scheduledTimes.isEmpty) ? null : _save,
            child: _isSaving
                ? const CircularProgressIndicator(color: Colors.white)
                : Text(d.scheduledTimes.isEmpty ? 'Nenhum horário definido na UBS' : 'Aceitar e Configurar Alarmes'),
          ),
        ],
      ),
    );
  }
'''
    
    content = content[:idx_start] + new_code + content[idx_end:]
    
    with open('lib/pages/medications_page.dart', 'w', encoding='utf-8') as f:
        f.write(content)
    print('done')
