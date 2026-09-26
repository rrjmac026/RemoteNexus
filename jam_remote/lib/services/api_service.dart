import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static Future<bool> checkHealth(String ip, String port) async {
    final url = Uri.parse('http://$ip:$port/api/health');
    try {
      final response = await http
          .get(url)
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['success'] == true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }
}