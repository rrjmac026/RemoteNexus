import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class StorageService {
  static const _storage = FlutterSecureStorage();
  static const _tokenKey = 'auth_token';
  static const _ipKey = 'saved_ip';
  static const _portKey = 'saved_port';

  static Future<void> saveToken(String token) => _storage.write(key: _tokenKey, value: token);
  static Future<String?> getToken() => _storage.read(key: _tokenKey);
  static Future<void> clearToken() => _storage.delete(key: _tokenKey);

  static Future<void> saveConnection(String ip, String port) async {
    await _storage.write(key: _ipKey, value: ip);
    await _storage.write(key: _portKey, value: port);
  }

  static Future<String?> getSavedIp() => _storage.read(key: _ipKey);
  static Future<String?> getSavedPort() => _storage.read(key: _portKey);

  static const _remoteUrlKey = 'remote_url';

  static Future<void> saveRemoteUrl(String url) => _storage.write(key: _remoteUrlKey, value: url);
  static Future<String?> getSavedRemoteUrl() => _storage.read(key: _remoteUrlKey);
}