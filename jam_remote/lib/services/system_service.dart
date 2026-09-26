import 'dart:convert';
import 'package:http/http.dart' as http;

class SystemService {
  static Future<Map<String, dynamic>?> _get(
      String ip, String port, String path, String token) async {
    final url = Uri.parse('http://$ip:$port$path');
    try {
      final response = await http.get(
        url,
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 5));

      final data = jsonDecode(response.body);
      if (data['success'] == true) {
        return data['data'] as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  static Future<Map<String, dynamic>?> getSystemInfo(String ip, String port, String token) =>
      _get(ip, port, '/api/system', token);

  static Future<Map<String, dynamic>?> getNetworkInfo(String ip, String port, String token) =>
      _get(ip, port, '/api/network', token);

  static Future<Map<String, dynamic>?> getServerInfo(String ip, String port, String token) =>
      _get(ip, port, '/api/server', token);
}