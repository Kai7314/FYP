import 'package:file_picker/file_picker.dart';

import '../dataAccessLayer/repositories/auth_repository.dart';
import '../dataAccessLayer/repositories/document_repository.dart';
import '../models/document_model.dart';
import 'local_cache_service.dart';

class LegacyPlanningSnapshot {
  const LegacyPlanningSnapshot({
    required this.preferences,
    required this.documents,
  });

  final FuneralPreferences preferences;
  final List<LegacyDocument> documents;
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
    ]);
    return LegacyPlanningSnapshot(
      preferences: results[0] as FuneralPreferences,
      documents: results[1] as List<LegacyDocument>,
    );
  }

  Future<void> savePreferences(FuneralPreferences preferences) async {
    final user = authRepository.currentUser;
    if (user == null) throw StateError('You must be signed in.');
    await documentRepository.savePreferences(user.id, preferences);
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
}
