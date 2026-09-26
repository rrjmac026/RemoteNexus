import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';

class RemoteDesktopService {
  WebSocketChannel? _channel;
  final _frameController = StreamController<String>.broadcast();

  Stream<String> get frames => _frameController.stream;

  Future<bool> connect(String ip, String port, String token) async {
    try {
      final uri = Uri.parse('ws://$ip:$port/ws/remote-desktop');
      _channel = WebSocketChannel.connect(uri);

      _channel!.sink.add(jsonEncode({'token': token}));

      _channel!.stream.listen(
        (message) {
          try {
            final data = jsonDecode(message);
            if (data['type'] == 'frame') {
              _frameController.add(data['data']);
            }
          } catch (_) {}
        },
        onDone: () => _frameController.addError('disconnected'),
        onError: (e) => _frameController.addError(e),
      );

      return true;
    } catch (e) {
      return false;
    }
  }

  void sendMove(double x, double y) {
    _send({'type': 'move', 'x': x.round(), 'y': y.round()});
  }

  void sendClick(double x, double y, {String button = 'left'}) {
    _send({'type': 'click', 'x': x.round(), 'y': y.round(), 'button': button});
  }

  void sendDrag(double x, double y) {
    _send({'type': 'drag', 'x': x.round(), 'y': y.round()});
  }

  void sendScroll(int amount) {
    _send({'type': 'scroll', 'amount': amount});
  }

  void sendKey(String key) {
    _send({'type': 'key', 'key': key});
  }

  void sendText(String text) {
    _send({'type': 'text', 'text': text});
  }

  void setQuality(String quality) {
    _send({'type': 'set_quality', 'quality': quality});
  }

  void setFps(int fps) {
    _send({'type': 'set_fps', 'fps': fps});
  }

  void _send(Map<String, dynamic> event) {
    try {
      _channel?.sink.add(jsonEncode(event));
    } catch (_) {}
  }

  void disconnect() {
    _channel?.sink.close();
    _frameController.close();
  }
}