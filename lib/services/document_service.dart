import 'package:file_picker/file_picker.dart';

import '../dataAccessLayer/repositories/auth_repository.dart';
import '../dataAccessLayer/repositories/document_repository.dart';
import '../models/document_model.dart';
import '../models/legacy_note_model.dart';
import 'local_cache_service.dart';

class LegacyPlanningSnapshot {
  const LegacyPlanningSnapshot({
    required this.preferences,
    required this.documents,
    required this.notes,
  });

  final FuneralPreferences preferences;
  final List<LegacyDocument> documents;
  final List<LegacyNote> notes;
}

class DocumentService {
  DocumentService({
    AuthRepository? authRepository,
    DocumentRepository? documentRepository,
    LocalCacheService? cache,
  }) : authRepository = authRepository ?? AuthRepository(),
       documentRepository = documentRepository ?? DocumentRepository(),
       cache = cache ?? LocalCacheService();

  final AuthRepository authRepository;
  final DocumentRepository documentRepository;
  final LocalCacheService cache;

  Future<LegacyPlanningSnapshot> load() async {
    final user = authRepository.currentUser;
    if (user == null) throw StateError('You must be signed in.');
    final results = await Future.wait([
      documentRepository.getPreferences(user.id),
      documentRepository.getDocuments(user.id),
      documentRepository.getNotes(user.id),
    ]);
    return LegacyPlanningSnapshot(
      preferences: results[0] as FuneralPreferences,
      documents: results[1] as List<LegacyDocument>,
      notes: results[2] as List<LegacyNote>,
    );
  }

  Future<void> savePreferences(FuneralPreferences preferences) async {
    final user = authRepository.currentUser;
    if (user == null) throw StateError('You must be signed in.');
    await documentRepository.savePreferences(user.id, preferences);
  }

  Future<void> createNote({
    required String title,
    required String content,
  }) async {
    final user = authRepository.currentUser;
    if (user == null) throw StateError('You must be signed in.');
    final cleanTitle = _validateTitle(title);
    final cleanContent = _validateContent(content);
    await documentRepository.createNote(
      userId: user.id,
      title: cleanTitle,
      content: cleanContent,
    );
  }

  Future<void> updateNote(LegacyNote note) async {
    final user = authRepository.currentUser;
    if (user == null) throw StateError('You must be signed in.');
    final cleanTitle = _validateTitle(note.title);
    final cleanContent = _validateContent(note.content);
    await documentRepository.updateNote(
      userId: user.id,
      note: note.copyWith(title: cleanTitle, content: cleanContent),
    );
  }

  Future<void> deleteNote(LegacyNote note) async {
    final user = authRepository.currentUser;
    if (user == null) throw StateError('You must be signed in.');
    await documentRepository.deleteNote(userId: user.id, noteId: note.id);
  }

  Future<bool> pickAndUploadDocument() async {
    final user = authRepository.currentUser;
    if (user == null) throw StateError('You must be signed in.');
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png'],
      withData: true,
    );
    final file = result?.files.single;
    if (file == null) return false;
    if (file.size > 10 * 1024 * 1024) {
      throw StateError('Document must not exceed 10 MB.');
    }
    final bytes = file.bytes;
    if (bytes == null) throw StateError('Could not read the selected file.');
    await documentRepository.uploadDocument(
      userId: user.id,
      fileName: file.name,
      bytes: bytes,
    );
    return true;
  }

  Future<void> deleteDocument(LegacyDocument document) {
    return documentRepository.deleteDocument(document.id, document.storagePath);
  }

  String _validateTitle(String title) {
    final trimmed = title.trim();
    if (trimmed.length < 2) {
      throw StateError('Note title must contain at least 2 characters.');
    }
    if (trimmed.length > 80) {
      throw StateError('Note title must not exceed 80 characters.');
    }
    return trimmed;
  }

  String _validateContent(String content) {
    final trimmed = content.trim();
    if (trimmed.length < 2) {
      throw StateError('Note content must contain at least 2 characters.');
    }
    if (trimmed.length > 1000) {
      throw StateError('Note content must not exceed 1000 characters.');
    }
    return trimmed;
  }
}
