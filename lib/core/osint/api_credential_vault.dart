import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'api_access_policy.dart';

/// All credentials are local. Keys are never included in OSINT dataset cache,
/// map preferences, exports, crash reports, bridge messages or source metadata.
abstract interface class ApiCredentialVault {
  Future<bool> contains(ApiAccessPolicy policy);
  Future<void> save(ApiAccessPolicy policy, String key);
  Future<void> remove(ApiAccessPolicy policy);
}

/// On Android uses encrypted secure storage, not Drift/plaintext settings.
/// Browser WebCrypto/key persistence has weaker protection against page script
/// compromise; Web intentionally keeps keys in memory until this tab reloads.
class LocalApiCredentialVault implements ApiCredentialVault {
  LocalApiCredentialVault({FlutterSecureStorage? secureStorage})
    : _secureStorage = secureStorage ?? const FlutterSecureStorage();

  static final LocalApiCredentialVault shared = LocalApiCredentialVault();
  final FlutterSecureStorage _secureStorage;
  final Map<String, String> _webSessionKeys = {};

  String _slot(ApiAccessPolicy policy) {
    if (!policy.allowsUserKey ||
        !RegExp(r'^[a-z0-9-]{2,70}$').hasMatch(policy.id)) {
      throw ArgumentError('API credentials are not enabled for this provider');
    }
    return 'fpvmanager.api.key.${policy.id}';
  }

  @override
  Future<bool> contains(ApiAccessPolicy policy) async {
    final slot = _slot(policy);
    if (kIsWeb) return _webSessionKeys.containsKey(slot);
    return (await _secureStorage.read(key: slot))?.isNotEmpty ?? false;
  }

  @override
  Future<void> save(ApiAccessPolicy policy, String key) async {
    final slot = _slot(policy);
    // Do not sanitize away meaningful whitespace inside provider-defined keys.
    if (key.trim().isEmpty ||
        key.length > 4096 ||
        key.contains(RegExp(r'[\r\n]'))) {
      throw ArgumentError(
        'API key must be nonempty, at most 4096 characters and single-line',
      );
    }
    if (kIsWeb) {
      _webSessionKeys[slot] = key;
    } else {
      await _secureStorage.write(key: slot, value: key);
    }
  }

  @override
  Future<void> remove(ApiAccessPolicy policy) async {
    final slot = _slot(policy);
    if (kIsWeb) {
      _webSessionKeys.remove(slot);
    } else {
      await _secureStorage.delete(key: slot);
    }
  }

  /// Only an approved provider adapter should request its own secret when
  /// making a call to its exact official endpoint, never the embedded globe.
  Future<String?> readForProvider(ApiAccessPolicy policy) async {
    final slot = _slot(policy);
    if (kIsWeb) return _webSessionKeys[slot];
    return _secureStorage.read(key: slot);
  }
}
