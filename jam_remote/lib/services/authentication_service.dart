import 'dart:convert';
import 'package:http/http.dart' as http;

class PairResult {
  final String requestId;
  final String code;
  PairResult(this.requestId, this.code);
}

class AuthenticationService {
  static Future<PairResult> requestPairing(String ip, String port, String deviceName) async {
    final url = Uri.parse('http://$ip:$port/api/auth/pair');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'device_name': deviceName, 'ip': ip}),
    ).timeout(const Duration(seconds: 5));

    final data = jsonDecode(response.body);
    final result = data['data'];
    return PairResult(result['request_id'], result['code']);
  }

  /// Returns: 'pending' | 'approved' | 'denied' | 'error', and token if approved
  static Future<Map<String, String?>> checkPairingStatus(
      String ip, String port, String requestId) async {
    final url = Uri.parse('http://$ip:$port/api/auth/pair/status/$requestId');
    try {
      final response = await http.get(url).timeout(const Duration(seconds: 5));
      final data = jsonDecode(response.body);
      if (data['success'] == true) {
        final status = data['data']['status'] as String;
        final token = data['data']['token'] as String?;
        return {'status': status, 'token': token};
      }
      return {'status': 'error', 'token': null};
    } catch (e) {
      return {'status': 'error', 'token': null};
    }
  }
}