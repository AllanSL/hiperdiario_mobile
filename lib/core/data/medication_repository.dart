import 'package:supabase_flutter/supabase_flutter.dart';

/// Minimal repository demonstrating basic CRUD operations against a
/// `medications` table on Supabase.
///
/// Assumes a SQL table `medications` exists with at least the columns used
/// in the examples (name, brand, stock, low_stock_threshold).
class MedicationRepository {
  final SupabaseClient _client = Supabase.instance.client;
  String get _table => 'medications';

  /// Create a medication and set the owner_id to the currently authenticated
  /// user's id when available. Returns the created row or `null` on failure.
  Future<Map<String, dynamic>?> createMedication(Map<String, dynamic> data) async {
    final String? userId = _client.auth.currentUser?.id;
    final Map<String, dynamic> payload = Map<String, dynamic>.from(data);
    if (userId != null) payload['owner_id'] = userId;

    final resp = await _client.from(_table).insert(payload).select().maybeSingle();
    return resp as Map<String, dynamic>?;
  }

  /// Returns all medications for the currently authenticated user. If there is
  /// no authenticated user, an empty list is returned.
  Future<List<Map<String, dynamic>>> getAll() async {
    final String? userId = _client.auth.currentUser?.id;
    if (userId == null) return <Map<String, dynamic>>[];

    final resp = await _client.from(_table).select().eq('owner_id', userId).order('name');
    return List<Map<String, dynamic>>.from(resp as List);
  }

  Future<Map<String, dynamic>?> getById(int id) async {
    final String? userId = _client.auth.currentUser?.id;
    if (userId == null) return null;

    final resp = await _client.from(_table).select().eq('id', id).eq('owner_id', userId).maybeSingle();
    return resp as Map<String, dynamic>?;
  }

  Future<Map<String, dynamic>?> updateMedication(int id, Map<String, dynamic> changes) async {
    final String? userId = _client.auth.currentUser?.id;
    if (userId == null) return null;

    final resp = await _client.from(_table).update(changes).eq('id', id).eq('owner_id', userId).select().maybeSingle();
    return resp as Map<String, dynamic>?;
  }

  Future<bool> deleteMedication(int id) async {
    final String? userId = _client.auth.currentUser?.id;
    if (userId == null) return false;

    final resp = await _client.from(_table).delete().eq('id', id).eq('owner_id', userId).select().maybeSingle();
    return resp != null;
  }
}
