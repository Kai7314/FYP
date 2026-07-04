import '../dataAccessLayer/repositories/auth_repository.dart';
import '../dataAccessLayer/repositories/user_repository.dart';
import '../utils/validators.dart';
import 'local_cache_service.dart';

class UserService {
  UserService({
    AuthRepository? authRepository,
    UserRepository? userRepository,
    LocalCacheService? cache,
  }) : authRepository = authRepository ?? AuthRepository(),
       userRepository = userRepository ?? UserRepository(),
       cache = cache ?? LocalCacheService();

  final AuthRepository authRepository;
  final UserRepository userRepository;
  final LocalCacheService cache;

  String _cacheKey(String userId) => 'profile_snapshot_v1_$userId';

  static const termsVersion = '2026-06-24';

  static bool isProfileSetupComplete(Map<String, dynamic> profile) {
    return AppProfileRules.missingSetupItems(profile).isEmpty;
  }

  Future<Map<String, dynamic>> getCurrentProfile({
    bool forceRefresh = false,
  }) async {
    final user = authRepository.currentUser;
    if (user == null) return {};
    if (!forceRefresh) {
      final cached = await cache.readMap(_cacheKey(user.id));
      if (cached != null) return cached;
    }
    final profile =
        await userRepository.getProfile(user.id) ?? <String, dynamic>{};
    profile['email'] ??= user.email;
    await cache.writeMap(_cacheKey(user.id), profile);
    return profile;
  }

  Future<void> updateCurrentProfile(Map<String, dynamic> values) async {
    final user = authRepository.currentUser;
    if (user == null) throw StateError('You must be signed in.');
    await userRepository.updateProfile(userId: user.id, values: values);
    await getCurrentProfile(forceRefresh: true);
  }

  Future<void> completeFirstLoginSetup(Map<String, dynamic> values) async {
    final user = authRepository.currentUser;
    if (user == null) throw StateError('You must be signed in.');
    final now = DateTime.now().toUtc().toIso8601String();
    await userRepository.updateProfile(
      userId: user.id,
      values: {
        ...values,
        'terms_version': termsVersion,
        'terms_accepted_at': now,
        'profile_completed_at': now,
      },
    );
    await getCurrentProfile(forceRefresh: true);
  }

  Future<void> signOut() async {
    final userId = authRepository.currentUser?.id;
    await authRepository.signOut();
    if (userId != null) await cache.removeUserData(userId);
  }
}

class AppProfileRules {
  static List<String> missingSetupItems(Map<String, dynamic> profile) {
    final missing = <String>[];
    final name = profile['name']?.toString() ?? '';
    final phone = profile['phone']?.toString() ?? '';
    final address = profile['address']?.toString() ?? '';
    final addressState = profile['address_state']?.toString() ?? '';
    final addressRegion = profile['address_region']?.toString() ?? '';
    final bloodType = profile['blood_type']?.toString() ?? '';
    final threshold = profile['inactivity_threshold']?.toString() ?? '';
    final termsAccepted = profile['terms_accepted_at']?.toString() ?? '';

    if (AppValidators.displayName(name) != null) missing.add('Name');
    if (AppValidators.phone(phone) != null) missing.add('Phone');
    if (AppValidators.address(address, required: true) != null) {
      missing.add('Home address');
    }
    if (addressState.trim().isEmpty) missing.add('State');
    if (addressRegion.trim().isEmpty) missing.add('Region');
    if (AppValidators.bloodType(bloodType, required: true) != null) {
      missing.add('Blood type');
    }
    if (AppValidators.inactivityThreshold(threshold) != null) {
      missing.add('Inactivity threshold');
    }
    if (termsAccepted.trim().isEmpty) {
      missing.add('Terms and Conditions');
    }
    return missing;
  }
}
