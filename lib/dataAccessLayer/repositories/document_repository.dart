import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/document_model.dart';
import '../../models/legacy_note_model.dart';

class DocumentRepository {
  DocumentRepository({SupabaseClient? client})
    : client = client ?? Supabase.instance.client;

  final SupabaseClient client;

  Future<FuneralPreferences> getPreferences(String userId) async {
    final rows = await client
        .from('funeral_preferences')
        .select()
        .eq('user_id', userId)
        .limit(1);
    return FuneralPreferences.fromJson(
      rows.isEmpty ? null : Map<String, dynamic>.from(rows.first),
    );
  }

  Future<void> savePreferences(String userId, FuneralPreferences preferences) {
    return client.from('funeral_preferences').upsert({
      'user_id': userId,
      ...preferences.toJson(),
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  Future<List<LegacyDocument>> getDocuments(String userId) async {
    final rows = await client
        .from('documents')
        .select()
        .eq('user_id', userId)
        .order('uploaded_at', ascending: false);
    return rows
        .map((row) => LegacyDocument.fromJson(Map<String, dynamic>.from(row)))
        .toList();
  }

  Future<List<LegacyNote>> getNotes(String userId) async {
    final rows = await client
        .from('legacy_notes')
        .select()
        .eq('user_id', userId)
        .order('updated_at', ascending: false);
    return rows
        .map((row) => LegacyNote.fromJson(Map<String, dynamic>.from(row)))
        .toList();
  }

  Future<void> createNote({
    required String userId,
    required String title,
    required String content,
  }) {
    return client.from('legacy_notes').insert({
      'user_id': userId,
      'title': title,
      'content': content,
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> updateNote({
    required String userId,
    required LegacyNote note,
  }) {
    return client
        .from('legacy_notes')
        .update({
          'title': note.title,
          'content': note.content,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', note.id)
        .eq('user_id', userId);
  }

  Future<void> deleteNote({
    required String userId,
    required String noteId,
  }) {
    return client
        .from('legacy_notes')
        .delete()
        .eq('id', noteId)
        .eq('user_id', userId);
  }

  Future<void> uploadDocument({
    required String userId,
    required String fileName,
    required Uint8List bytes,
  }) async {
    final safeName = fileName.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final path = '$userId/${DateTime.now().millisecondsSinceEpoch}_$safeName';
    await client.storage
        .from('legacy-documents')
        .uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(upsert: false),
        );
    await client.from('documents').insert({
      'user_id': userId,
      'name': fileName,
      'storage_path': path,
      'uploaded_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> deleteDocument(String id, String storagePath) async {
    await client.storage.from('legacy-documents').remove([storagePath]);
    await client.from('documents').delete().eq('id', id);
  }
}
