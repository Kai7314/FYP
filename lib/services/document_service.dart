import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';

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
    required this.legacyAccessEnabled,
  });

  final FuneralPreferences preferences;
  final List<LegacyDocument> documents;
  final List<LegacyNote> notes;
  final bool legacyAccessEnabled;
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

  static const maxDocumentBytes = 10 * 1024 * 1024;
  static const _allowedDocumentExtensions = {'pdf', 'jpg', 'jpeg', 'png'};

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

  static String? documentUploadValidationError({
    required String fileName,
    required int fileSize,
    required Uint8List? bytes,
  }) {
    final trimmedName = fileName.trim();
    if (trimmedName.isEmpty || trimmedName.length > 180) {
      return 'Rename the file using between 1 and 180 characters.';
    }

    final extension = _fileExtension(trimmedName);
    if (!_allowedDocumentExtensions.contains(extension)) {
      return 'Choose a PDF, JPG, JPEG, or PNG file.';
    }
    if (bytes == null) return 'Could not read the selected document.';
    if (fileSize <= 0 || bytes.isEmpty) {
      return 'The selected document is empty.';
    }
    if (fileSize > maxDocumentBytes || bytes.length > maxDocumentBytes) {
      return 'Document must not exceed 10 MB.';
    }
    if (!_matchesDocumentSignature(extension, bytes)) {
      return 'The file content does not match its PDF or image extension.';
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
      documentRepository.getLegacyAccessEnabled(user.id),
    ]);
    return LegacyPlanningSnapshot(
      preferences: results[0] as FuneralPreferences,
      documents: results[1] as List<LegacyDocument>,
      notes: results[2] as List<LegacyNote>,
      legacyAccessEnabled: results[3] as bool,
    );
  }

  Future<void> setLegacyAccessEnabled(bool enabled) async {
    final user = authRepository.currentUser;
    if (user == null) throw StateError('You must be signed in.');
    await documentRepository.setLegacyAccessEnabled(enabled: enabled);
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
    final bytes = file.bytes;
    final validationError = documentUploadValidationError(
      fileName: file.name,
      fileSize: file.size,
      bytes: bytes,
    );
    if (validationError != null) throw StateError(validationError);
    await documentRepository.uploadDocument(
      userId: user.id,
      fileName: file.name.trim(),
      bytes: bytes!,
    );
    return true;
  }

  Future<void> openDocument(LegacyDocument document) async {
    final user = authRepository.currentUser;
    if (user == null) throw StateError('You must be signed in.');
    _requireOwnedDocumentPath(user.id, document.storagePath);

    final signedUrl = await documentRepository.createDocumentSignedUrl(
      document.storagePath,
    );
    final uri = Uri.tryParse(signedUrl);
    if (uri == null || !uri.hasScheme) {
      throw StateError('Could not create a secure link for this document.');
    }
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened) {
      throw StateError('Could not open the selected document.');
    }
  }

  Future<void> deleteDocument(LegacyDocument document) async {
    final user = authRepository.currentUser;
    if (user == null) throw StateError('You must be signed in.');
    _requireOwnedDocumentPath(user.id, document.storagePath);
    await documentRepository.deleteDocument(
      userId: user.id,
      id: document.id,
      storagePath: document.storagePath,
    );
  }

  static String _fileExtension(String fileName) {
    final separator = fileName.lastIndexOf('.');
    if (separator < 0 || separator == fileName.length - 1) return '';
    return fileName.substring(separator + 1).toLowerCase();
  }

  static bool _matchesDocumentSignature(String extension, Uint8List bytes) {
    return switch (extension) {
      'pdf' => _containsPdfHeader(bytes),
      'jpg' || 'jpeg' => _startsWith(bytes, const [0xff, 0xd8, 0xff]),
      'png' => _startsWith(bytes, const [
        0x89,
        0x50,
        0x4e,
        0x47,
        0x0d,
        0x0a,
        0x1a,
        0x0a,
      ]),
      _ => false,
    };
  }

  static bool _containsPdfHeader(Uint8List bytes) {
    const signature = [0x25, 0x50, 0x44, 0x46, 0x2d];
    final lastStart = bytes.length - signature.length;
    final searchEnd = lastStart < 1024 ? lastStart : 1024;
    for (var start = 0; start <= searchEnd; start++) {
      var matches = true;
      for (var index = 0; index < signature.length; index++) {
        if (bytes[start + index] != signature[index]) {
          matches = false;
          break;
        }
      }
      if (matches) return true;
    }
    return false;
  }

  static bool _startsWith(Uint8List bytes, List<int> signature) {
    if (bytes.length < signature.length) return false;
    for (var index = 0; index < signature.length; index++) {
      if (bytes[index] != signature[index]) return false;
    }
    return true;
  }

  void _requireOwnedDocumentPath(String userId, String storagePath) {
    if (!storagePath.startsWith('$userId/') || storagePath.contains('..')) {
      throw StateError('This document does not belong to the signed-in user.');
    }
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
