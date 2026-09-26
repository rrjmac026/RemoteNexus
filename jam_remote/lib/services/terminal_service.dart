import '../services/connection_service.dart';

class TerminalResult {
  final bool success;
  final String output;
  final bool shouldExit;

  TerminalResult({required this.success, required this.output, this.shouldExit = false});
}

class TerminalService {
  static Future<TerminalResult> sendCommand(String command) async {
    try {
      final data = await ConnectionService.post('/api/terminal', {'command': command});

      if (data['success'] == true) {
        final output = data['data']['output'] as String? ?? '';
        final action = data['data']['action'] as String?;
        return TerminalResult(success: true, output: output, shouldExit: action == 'exit');
      } else {
        final msg = data['error']?['message'] ?? 'Unknown error';
        return TerminalResult(success: false, output: msg);
      }
    } catch (e) {
      return TerminalResult(success: false, output: 'Connection error. Is the agent running?');
    }
  }
}