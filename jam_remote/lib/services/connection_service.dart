import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';
import 'storage_service.dart';

enum ConnectionMode { local, remote }

class ConnectionService {
  // ---- Current connection state (loaded once, cached) ----
  static ConnectionMode _mode = ConnectionMode.local;
  static String? _ip;
  static String? _port;
  static String? _token;
  static String? _relayUrl;   // used only in remote mode (Phase 8)
  static String? _deviceId;   // used only in remote mode (Phase 8)

  static ConnectionMode get mode => _mode;

  /// Call this once at app startup, and again after (re)connecting.
  static Future<void> load() async {
    _ip = await StorageService.getSavedIp();
    _port = await StorageService.getSavedPort();
    _token = await StorageService.getToken();
    // _mode/_relayUrl/_deviceId will be wired to StorageService in Phase 8.
  }

  static Future<void> setLocalConnection(String ip, String port) async {
    _mode = ConnectionMode.local;
    _ip = ip;
    _port = port;
    await StorageService.saveConnection(ip, port);
  }

  static void setToken(String token) {
    _token = token;
    StorageService.saveToken(token);
  }

  static String? get token => _token;

  /// Resolves the base HTTP(S) URL regardless of mode.
  static String get _baseUrl {
    switch (_mode) {
      case ConnectionMode.local:
        return 'http://$_ip:$_port';
      case ConnectionMode.remote:
        // Phase 8: e.g. 'https://$_relayUrl/agent/$_deviceId'
        throw UnimplementedError('Remote mode not wired yet');
    }
  }

  static String get _wsBaseUrl {
    switch (_mode) {
      case ConnectionMode.local:
        return 'ws://$_ip:$_port';
      case ConnectionMode.remote:
        // Phase 8: e.g. 'wss://$_relayUrl/agent/$_deviceId'
        throw UnimplementedError('Remote mode not wired yet');
    }
  }

  static Map<String, String> _authHeaders({bool json = false}) => {
        if (_token != null) 'Authorization': 'Bearer $_token',
        if (json) 'Content-Type': 'application/json',
      };

  // ---- Unified request methods ----

  static Future<Map<String, dynamic>> get(String path,
      {Duration timeout = const Duration(seconds: 5)}) async {
    final res = await http
        .get(Uri.parse('$_baseUrl$path'), headers: _authHeaders())
        .timeout(timeout);
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> post(String path, Map<String, dynamic> body,
      {Duration timeout = const Duration(seconds: 8)}) async {
    final res = await http
        .post(Uri.parse('$_baseUrl$path'),
            headers: _authHeaders(json: true), body: jsonEncode(body))
        .timeout(timeout);
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> delete(String path, Map<String, dynamic> body,
      {Duration timeout = const Duration(seconds: 8)}) async {
    final request = http.Request('DELETE', Uri.parse('$_baseUrl$path'));
    request.headers.addAll(_authHeaders(json: true));
    request.body = jsonEncode(body);
    final streamed = await request.send().timeout(timeout);
    final res = await http.Response.fromStream(streamed);
    return jsonDecode(res.body);
  }

  static Future<http.Response> getRaw(String path,
      {Duration timeout = const Duration(seconds: 60)}) {
    return http
        .get(Uri.parse('$_baseUrl$path'), headers: _authHeaders())
        .timeout(timeout);
  }

  /// Returns a plain [http.Response] (not a stream) so callers can jsonDecode it directly.
  static Future<http.Response> multipart(
      String path, String fileField, String filePath, String fileName,
      {Duration timeout = const Duration(seconds: 60)}) async {
    final request = http.MultipartRequest('POST', Uri.parse('$_baseUrl$path'));
    request.headers['Authorization'] = 'Bearer $_token';
    request.files.add(await http.MultipartFile.fromPath(fileField, filePath, filename: fileName));
    final streamed = await request.send().timeout(timeout);
    return http.Response.fromStream(streamed);
  }

  static WebSocketChannel connectWebSocket(String path) {
    return WebSocketChannel.connect(Uri.parse('$_wsBaseUrl$path'));
  }
}