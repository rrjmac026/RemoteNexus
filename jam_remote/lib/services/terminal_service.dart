import 'dart:convert';
import 'package:http/http.dart' as http;

class TerminalResult {
  final bool success;
  final String output;
  final bool shouldExit;

  TerminalResult({required this.success, required this.output, this.shouldExit = false});
}

class TerminalService {
  static Future<TerminalResult> sendCommand(
      String ip, String port, String token, String command) async {
    final url = Uri.parse('http://$ip:$port/api/terminal');
    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'command': command}),
      ).timeout(const Duration(seconds: 5));

      final data = jsonDecode(response.body);

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