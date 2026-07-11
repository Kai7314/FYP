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

  static final RegExp _credentialTerms = RegExp(
    r'\b(password|passcode|pin|otp|one[ -]?time password|api[ _-]?key|access[ _-]?token|secret[ _-]?key|private[ _-]?key|seed[ _-]?phrase|recovery[ _-]?phrase|cvv|security[ _-]?code)\b',
    caseSensitive: false,
  );
  static final RegExp _credentialValuePatterns = RegExp(
    r'(-----BEGIN [A-Z ]*PRIVATE KEY-----|\bsk-[A-Za-z0-9_-]{16,}\b|\beyJ[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{10,})',
    caseSensitive: false,
  );

  static String? legacyNoteSecurityWarning({
    required String title,
    required String content,
  }) {
    final text = '$title\n$content';
    if (_credentialTerms.hasMatch(text) ||
        _credentialValuePatterns.hasMatch(text)) {
      return 'Do not store passwords, PINs, OTPs, recovery phrases, API keys, access tokens, or security codes in Legacy Notes.';
    }
    return null;
  }

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
    _validateNoteSecurity(cleanTitle, cleanContent);
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
    _validateNoteSecurity(cleanTitle, cleanContent);
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

  void _validateNoteSecurity(String title, String content) {
    final warning = legacyNoteSecurityWarning(title: title, content: content);
    if (warning != null) throw StateError(warning);
  }
}
