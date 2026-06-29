import '../dataAccessLayer/repositories/auth_repository.dart';
import '../dataAccessLayer/repositories/contact_repository.dart';
import 'local_cache_service.dart';

class ContactService {
  ContactService({
    AuthRepository? authRepository,
    ContactRepository? contactRepository,
    LocalCacheService? cache,
  }) : authRepository = authRepository ?? AuthRepository(),
       contactRepository = contactRepository ?? ContactRepository(),
       cache = cache ?? LocalCacheService();

  final AuthRepository authRepository;
  final ContactRepository contactRepository;
  final LocalCacheService cache;

  String _cacheKey(String userId) => 'contacts_snapshot_v1_$userId';

  Future<List<Map<String, dynamic>>> getContacts({
    bool forceRefresh = false,
  }) async {
    final user = authRepository.currentUser;
    if (user == null) throw StateError('You must be signed in.');
    if (!forceRefresh) {
      final cached = await cache.readMap(_cacheKey(user.id));
      final rows = cached?['rows'] as List?;
      if (rows != null) {
        return rows
            .map((row) => Map<String, dynamic>.from(row as Map))
            .toList();
      }
    }
    final rows = await contactRepository.getContacts(user.id);
    await cache.writeMap(_cacheKey(user.id), {'rows': rows});
    return rows;
  }

  Future<bool> hasPrimaryContact({bool forceRefresh = false}) async {
    final contacts = await getContacts(forceRefresh: forceRefresh);
    if (contacts.any((row) => row['is_primary'] == true)) return true;

    final user = authRepository.currentUser;
    if (user == null) throw StateError('You must be signed in.');
    return contactRepository.hasPrimaryContact(user.id);
  }

  Future<void> addContact({
    required String name,
    required String relationship,
    required String phone,
    String? address,
    bool isPrimary = false,
  }) async {
    final user = authRepository.currentUser;
    if (user == null) throw StateError('You must be signed in.');
    await contactRepository.addContact(
      userId: user.id,
      name: name,
      phone: phone,
      relationship: relationship,
      address: address,
      isPrimary: isPrimary,
    );
    await getContacts(forceRefresh: true);
  }

  Future<void> deleteContact(Map<String, dynamic> row) async {
    final user = authRepository.currentUser;
    if (user == null) throw StateError('You must be signed in.');
    await contactRepository.deleteContact(userId: user.id, row: row);
    await getContacts(forceRefresh: true);
  }

  Future<void> setPrimaryContact(Map<String, dynamic> row) async {
    final user = authRepository.currentUser;
    if (user == null) throw StateError('You must be signed in.');
    await contactRepository.setPrimaryContact(userId: user.id, row: row);
    await getContacts(forceRefresh: true);
  }
}
