import os

with open('lib/state/app_state.dart', 'r', encoding='utf-8') as f:
    content = f.read()

start_marker = "--- INÍCIO DA SINCRONIZAÇÃO PONTO 2 e 3"
end_marker = "--- FIM DA SINCRONIZAÇÃO PONTO 2 e 3"

start_idx = content.find(start_marker)
end_idx = content.find(end_marker)

start_idx = content.rfind('//', 0, start_idx) if start_idx != -1 else -1

if start_idx != -1 and end_idx != -1:
    end_idx = content.find('\n', end_idx)
    
    new_block = '''// --- INÍCIO DA SINCRONIZAÇÃO PONTO 2, 3 e 4 (SUS) ---
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
              final int webStock = int.tryParse(webStockRaw?.toString() ?? '0') ?? 0;
              final currentStockRaw = medRow['stock'];
              final int currentStock = int.tryParse(currentStockRaw?.toString() ?? '0') ?? 0;

              if (timesChanged && newTimes.isNotEmpty) {
                updateMap['frequency'] = newTimes;
              }
              if (webStock != currentStock) {
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
        debugPrint('Erro ao sincronizar retornos da UBS: \');
      }
    }
    // --- FIM DA SINCRONIZAÇÃO PONTO 2, 3 e 4 (SUS) ---'''
    
    content = content[:start_idx] + new_block + content[end_idx:]
    with open('lib/state/app_state.dart', 'w', encoding='utf-8') as f:
        f.write(content)
else:
    print(f"Could not find markers {start_idx} {end_idx}")
