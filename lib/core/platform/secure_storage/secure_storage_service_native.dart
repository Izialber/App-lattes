import 'secure_storage_service.dart';

/// Stub documentado da fase 2: `flutter_secure_storage` nativo (Keychain no
/// iOS, Keystore/EncryptedSharedPreferences no Android). Troca direta, sem
/// necessidade de cifragem manual.
class SecureStorageServiceNative implements SecureStorageService {
  @override
  Future<void> clearAll() => throw UnimplementedError('fase 2: flutter_secure_storage nativo');

  @override
  Future<void> delete({required String key}) =>
      throw UnimplementedError('fase 2: flutter_secure_storage nativo');

  @override
  Future<String?> read({required String key}) =>
      throw UnimplementedError('fase 2: flutter_secure_storage nativo');

  @override
  Future<void> write({required String key, required String value}) =>
      throw UnimplementedError('fase 2: flutter_secure_storage nativo');
}
