import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/document_model.dart';
import '../../models/legacy_note_model.dart';

class DocumentRepository {
  DocumentRepository({SupabaseClient? client})
    : client = client ?? Supabase.instance.client;

  static const _documentBucket = 'legacy-documents';

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

  Future<bool> getLegacyAccessEnabled(String userId) async {
    final rows = await client.from('users').select().eq('id', userId).limit(1);
    return rows.isNotEmpty && rows.first['legacy_access_enabled'] == true;
  }

  Future<bool> getLegacyTestingAccessEnabled(String userId) async {
    final rows = await client.from('users').select().eq('id', userId).limit(1);
    return rows.isNotEmpty &&
        rows.first['legacy_access_test_enabled'] == true;
  }

  Future<void> setLegacyAccessEnabled({required bool enabled}) {
    return client.rpc(
      'set_legacy_access_enabled',
      params: {'enabled': enabled},
    );
  }

  Future<void> setLegacyTestingAccessEnabled({required bool enabled}) {
    return client.rpc(
      'set_legacy_access_test_enabled',
      params: {'enabled': enabled},
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

  Future<void> updateNote({required String userId, required LegacyNote note}) {
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

  Future<void> deleteNote({required String userId, required String noteId}) {
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
        .from(_documentBucket)
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            upsert: false,
            contentType: _contentTypeFor(fileName),
          ),
        );

    try {
      final response = await client.functions
          .invoke(
            'finalize-legacy-document',
            body: {'fileName': fileName, 'storagePath': path},
          )
          .timeout(const Duration(seconds: 30));
      if (response.data is! Map ||
          (response.data as Map)['document'] is! Map) {
        throw StateError('The server did not finalize the document.');
      }
    } catch (_) {
      try {
        await client.storage.from(_documentBucket).remove([path]);
      } catch (_) {
        // Preserve the metadata failure; orphan cleanup is best effort.
      }
      rethrow;
    }
  }

  Future<String> createDocumentSignedUrl(
    String storagePath, {
    int expiresInSeconds = 300,
  }) {
    return client.storage
        .from(_documentBucket)
        .createSignedUrl(storagePath, expiresInSeconds);
  }

  Future<void> deleteDocument({
    required String userId,
    required String id,
    required String storagePath,
  }) async {
    await client.storage.from(_documentBucket).remove([storagePath]);
    await client.from('documents').delete().eq('id', id).eq('user_id', userId);
  }

  String _contentTypeFor(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();
    return switch (extension) {
      'pdf' => 'application/pdf',
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      _ => 'application/octet-stream',
    };
  }
}
