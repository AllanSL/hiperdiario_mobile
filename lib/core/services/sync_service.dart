import 'dart:async';
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'local_database.dart';
import 'package:flutter/foundation.dart';

class SyncService {
  static final SyncService instance = SyncService._init();
  final _supabase = Supabase.instance.client;
  final _localDb = LocalDatabase.instance;
  
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  bool _isSyncing = false;
  
  final _syncStatusController = StreamController<bool>.broadcast();
  Stream<bool> get isSyncingStream => _syncStatusController.stream;

  SyncService._init();

  void init() {
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((results) {
      if (results.any((r) => r != ConnectivityResult.none)) {
        sync();
      }
    });
  }

  void dispose() {
    _connectivitySubscription?.cancel();
    _syncStatusController.close();
  }

  Future<void> sync() async {
    if (_isSyncing) return;
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    _isSyncing = true;
    _syncStatusController.add(true);
    
    try {
      await _processSyncQueue();
      // Em uma implementação real, aqui poderíamos disparar o pull de dados
      // Mas para manter compatibilidade com o AppState atual, deixaremos
      // o AppState chamar o pull quando necessário.
    } catch (e) {
      debugPrint('Sync error: $e');
    } finally {
      _isSyncing = false;
      _syncStatusController.add(false);
    }
  }

  Future<void> _processSyncQueue() async {
    final queue = await _localDb.getSyncQueue();
    if (queue.isEmpty) return;

    for (final item in queue) {
      final id = item['id'] as int;
      final tableName = item['table_name'] as String;
      final operation = item['operation'] as String;
      final data = jsonDecode(item['data'] as String) as Map<String, dynamic>;
      final localId = item['local_id'] as String;

      try {
        if (operation == 'INSERT') {
          await _supabase.from(tableName).insert(data);
        } else if (operation == 'UPDATE') {
          final isNumeric = int.tryParse(localId) != null && localId.length < 13;
          if (isNumeric) {
             await _supabase.from(tableName).update(data).eq('id', localId);
          } else {
             await _supabase.from(tableName).update(data).eq('remote_id', localId);
          }
        } else if (operation == 'DELETE') {
           final isNumeric = int.tryParse(localId) != null && localId.length < 13;
           if (isNumeric) {
             await _supabase.from(tableName).delete().eq('id', localId);
           } else {
             await _supabase.from(tableName).delete().eq('remote_id', localId);
           }
        }
        await _localDb.removeFromSyncQueue(id);
        
        // Update local status to synced
        if (tableName == 'appointments') {
          await _localDb.database.then((db) => db.update(
            'appointments', 
            {'sync_status': 'synced'}, 
            where: 'id = ?', 
            whereArgs: [localId]
          ));
        } else if (tableName == 'medications') {
          await _localDb.database.then((db) => db.update(
            'medications', 
            {'sync_status': 'synced'}, 
            where: 'id = ?', 
            whereArgs: [localId]
          ));
        }
      } catch (e) {
        debugPrint('Failed to sync queue item $id: $e');
        // Se for erro de rede, paramos o processamento da fila por agora
        if (e is TimeoutException || e.toString().contains('Failed host lookup')) {
          break;
        }
      }
    }
  }
}
