import os

with open('lib/state/app_state.dart', 'r', encoding='utf-8') as f:
    content = f.read()

start_marker = "final pendingRows = await _supabase"
end_marker = "}).toList();"

start_idx = content.find(start_marker)
end_idx = content.find(end_marker)

if start_idx != -1 and end_idx != -1:
    end_idx = content.find('\n', end_idx)
    
    new_block = '''final pendingRows = await _supabase
              .from('medicine_dispensations')
              .select('id, dispensed_quantity, dispensed_at, prescribing_doctor, frequency_per_day, frequency_label, scheduled_times, medicine_catalog ( active_principle, strength, form )')
              .eq('patient_id', profileId)
              .eq('acknowledged_in_app', false);

          _pendingDispensations = (pendingRows as List).map((row) {
            final map = row as Map<String, dynamic>;
            final catalog = map['medicine_catalog'] as Map<String, dynamic>? ?? {};

            final timesRaw = map['scheduled_times'];
            final timesList = <String>[];
            if (timesRaw is List) {
              for (final t in timesRaw) {
                timesList.add(t.toString());
              }
            }

            return PendingDispensation(
              id: map['id'].toString(),
              activePrinciple: catalog['active_principle']?.toString() ?? 'Medicamento Local',
              strength: catalog['strength']?.toString() ?? '',
              form: catalog['form']?.toString() ?? '',
              dispensedQuantity: int.tryParse(map['dispensed_quantity']?.toString() ?? '0') ?? 0,
              dispensedAt: DateTime.tryParse(map['dispensed_at']?.toString() ?? '')?.toLocal() ?? DateTime.now(),
              prescribingDoctor: map['prescribing_doctor']?.toString() ?? 'Não informado',
              frequencyPerDay: int.tryParse(map['frequency_per_day']?.toString() ?? '1') ?? 1,
              frequencyLabel: map['frequency_label']?.toString(),
              scheduledTimes: timesList,
            );
          }).toList();'''
    
    content = content[:start_idx] + new_block + content[end_idx:]
    with open('lib/state/app_state.dart', 'w', encoding='utf-8') as f:
        f.write(content)
else:
    print(f"Could not find markers {start_idx} {end_idx}")
