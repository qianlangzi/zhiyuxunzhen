import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../core/config/app_config.dart';

abstract class TokenStore {
  Future<String?> readAccessToken();
  Future<String?> readRefreshToken();
  Future<void> writeTokens({
    required String accessToken,
    required String refreshToken,
  });
  Future<void> clear();
}

class SecureTokenStore implements TokenStore {
  SecureTokenStore(this._storage);

  final FlutterSecureStorage _storage;

  @override
  Future<String?> readAccessToken() => _storage.read(key: AppConfig.kToken);

  @override
  Future<String?> readRefreshToken() =>
      _storage.read(key: AppConfig.kRefreshToken);

  @override
  Future<void> writeTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await _storage.write(key: AppConfig.kToken, value: accessToken);
    await _storage.write(
      key: AppConfig.kRefreshToken,
      value: refreshToken,
    );
  }

  @override
  Future<void> clear() async {
    await _storage.delete(key: AppConfig.kToken);
    await _storage.delete(key: AppConfig.kRefreshToken);
  }
}

final Provider<TokenStore> tokenStoreProvider = Provider<TokenStore>((ref) {
  return SecureTokenStore(const FlutterSecureStorage());
});
