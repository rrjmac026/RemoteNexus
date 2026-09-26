import '../services/connection_service.dart';

class SystemService {
  static Future<Map<String, dynamic>?> _get(String path) async {
    try {
      final data = await ConnectionService.get(path);
      if (data['success'] == true) {
        return data['data'] as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  static Future<Map<String, dynamic>?> getSystemInfo() => _get('/api/system');
  static Future<Map<String, dynamic>?> getNetworkInfo() => _get('/api/network');
  static Future<Map<String, dynamic>?> getServerInfo() => _get('/api/server');
}