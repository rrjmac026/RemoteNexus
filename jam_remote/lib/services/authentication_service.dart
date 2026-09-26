import '../services/connection_service.dart';

class PairResult {
  final String requestId;
  final String code;
  PairResult(this.requestId, this.code);
}

class AuthenticationService {
  static Future<PairResult> requestPairing(String deviceName) async {
    final data = await ConnectionService.post('/api/auth/pair', {
      'device_name': deviceName,
    });
    final result = data['data'];
    return PairResult(result['request_id'], result['code']);
  }

  /// Returns: 'pending' | 'approved' | 'denied' | 'error', and token if approved
  static Future<Map<String, String?>> checkPairingStatus(String requestId) async {
    try {
      final data = await ConnectionService.get('/api/auth/pair/status/$requestId');
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