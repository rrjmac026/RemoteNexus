import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../services/remote_desktop_service.dart';
import '../services/storage_service.dart';

class RemoteDesktopScreen extends StatefulWidget {
  const RemoteDesktopScreen({super.key});

  @override
  State<RemoteDesktopScreen> createState() => _RemoteDesktopScreenState();
}

class _RemoteDesktopScreenState extends State<RemoteDesktopScreen> {
  final _service = RemoteDesktopService();

  String? _currentFrame;
  bool _connected = false;
  String _quality = 'medium';
  int _fps = 15;
  bool _showKeyboard = false;
  final _textController = TextEditingController();

  double _screenWidth = 1920;
  double _screenHeight = 1080;

  double _viewScale = 1.0;
  Offset _viewOffset = Offset.zero;
  double _scaleStartValue = 1.0;
  Offset _gestureStartFocal = Offset.zero;
  Offset? _pinchAnchorContentPoint;

  int _maxPointersSeen = 0;
  double _totalMovement = 0;
  DateTime? _gestureStartTime;
  Offset _lastFocalForMove = Offset.zero;
  static const double _tapSlop = 12.0;
  static const int _longPressMs = 450;

  @override
  void initState() {
    super.initState();
    _connect();
  }

  Future<void> _connect() async {
    final ip = await StorageService.getSavedIp();
    final port = await StorageService.getSavedPort();
    final token = await StorageService.getToken();

    if (ip == null || port == null || token == null) return;

    final ok = await _service.connect(ip, port, token);
    setState(() => _connected = ok);

    _service.frames.listen(
      (frame) {
        if (mounted) setState(() => _currentFrame = frame);
      },
      onError: (_) {
        if (mounted) setState(() => _connected = false);
      },
    );
  }

  Rect _imageRectWithin(BoxConstraints constraints) {
    final boxW = constraints.maxWidth;
    final boxH = constraints.maxHeight;
    final imageAspect = _screenWidth / _screenHeight;
    final boxAspect = boxW / boxH;

    double drawW, drawH, left, top;
    if (boxAspect > imageAspect) {
      drawH = boxH;
      drawW = boxH * imageAspect;
      left = (boxW - drawW) / 2;
      top = 0;
    } else {
      drawW = boxW;
      drawH = boxW / imageAspect;
      left = 0;
      top = (boxH - drawH) / 2;
    }
    return Rect.fromLTWH(left, top, drawW, drawH);
  }

  Offset? _toRemoteCoords(Offset localPos, BoxConstraints constraints) {
    final rect = _imageRectWithin(constraints);
    if (!rect.contains(localPos)) return null;

    final fracX = (localPos.dx - rect.left) / rect.width;
    final fracY = (localPos.dy - rect.top) / rect.height;

    return Offset(
      (fracX * _screenWidth).clamp(0, _screenWidth),
      (fracY * _screenHeight).clamp(0, _screenHeight),
    );
  }

  Offset _unTransform(Offset raw) {
    return (raw - _viewOffset) / _viewScale;
  }
  
    void _onScaleStart(ScaleStartDetails details) {
    _scaleStartValue = _viewScale;
    _gestureStartFocal = details.localFocalPoint;
    _lastFocalForMove = details.localFocalPoint;
    _pinchAnchorContentPoint = (details.localFocalPoint - _viewOffset) / _viewScale;

    _maxPointersSeen = details.pointerCount;
    _totalMovement = 0;
    _gestureStartTime = DateTime.now();
  }

  void _onScaleUpdate(ScaleUpdateDetails details, BoxConstraints constraints) {
    _maxPointersSeen = math.max(_maxPointersSeen, details.pointerCount);

    if (details.pointerCount >= 2) {
      setState(() {
        final newScale = (_scaleStartValue * details.scale).clamp(1.0, 5.0);
        final anchor = _pinchAnchorContentPoint ?? Offset.zero;
        _viewOffset = details.localFocalPoint - (anchor * newScale);
        _viewScale = newScale;
        _clampOffset(constraints);
      });
      return;
    }

    final delta = (details.localFocalPoint - _lastFocalForMove).distance;
    _totalMovement += delta;
    _lastFocalForMove = details.localFocalPoint;

    if (_totalMovement > _tapSlop) {
      final local = _unTransform(details.localFocalPoint);
      final remote = _toRemoteCoords(local, constraints);
      if (remote != null) _service.sendMove(remote.dx, remote.dy);
    }
  }

  void _onScaleEnd(ScaleEndDetails details, BoxConstraints constraints, Offset lastRawPosition) {
    if (_maxPointersSeen >= 2) return;
    if (_totalMovement > _tapSlop) return;

    final elapsedMs = _gestureStartTime == null
        ? 0
        : DateTime.now().difference(_gestureStartTime!).inMilliseconds;

    final local = _unTransform(lastRawPosition);
    final remote = _toRemoteCoords(local, constraints);
    if (remote == null) return;

    if (elapsedMs >= _longPressMs) {
      _service.sendClick(remote.dx, remote.dy, button: 'right');
    } else {
      _service.sendClick(remote.dx, remote.dy);
    }
  }

  void _clampOffset(BoxConstraints constraints) {
    final maxDx = constraints.maxWidth * (_viewScale - 1);
    final maxDy = constraints.maxHeight * (_viewScale - 1);
    _viewOffset = Offset(
      _viewOffset.dx.clamp(-maxDx, 0),
      _viewOffset.dy.clamp(-maxDy, 0),
    );
    if (_viewScale <= 1.0) _viewOffset = Offset.zero;
  }

  @override
  void dispose() {
    _service.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Remote Desktop'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.high_quality),
            onSelected: (q) {
              _quality = q;
              _service.setQuality(q);
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'low', child: Text('Low Quality')),
              PopupMenuItem(value: 'medium', child: Text('Medium Quality')),
              PopupMenuItem(value: 'high', child: Text('High Quality')),
            ],
          ),
          PopupMenuButton<int>(
            icon: const Icon(Icons.speed),
            onSelected: (fps) {
              _fps = fps;
              _service.setFps(fps);
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 15, child: Text('15 FPS')),
              PopupMenuItem(value: 30, child: Text('30 FPS')),
              PopupMenuItem(value: 60, child: Text('60 FPS')),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.keyboard),
            onPressed: () => setState(() => _showKeyboard = !_showKeyboard),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: !_connected
                ? const Center(
                    child: Text('Connecting to remote desktop...', style: TextStyle(color: Colors.white)))
                : _currentFrame == null
                    ? const Center(child: CircularProgressIndicator())
                    : LayoutBuilder(
                        builder: (context, constraints) {
                          final image = Image.memory(
                            base64Decode(_currentFrame!),
                            gaplessPlayback: true,
                            fit: BoxFit.contain,
                            width: double.infinity,
                            height: double.infinity,
                          );

                          return ClipRect(
                            child: GestureDetector(
                              onScaleStart: _onScaleStart,
                              onScaleUpdate: (d) => _onScaleUpdate(d, constraints),
                              onScaleEnd: (d) =>
                                  _onScaleEnd(d, constraints, _lastFocalForMove),
                              child: Transform(
                                transform: Matrix4.identity()
                                  ..translate(_viewOffset.dx, _viewOffset.dy)
                                  ..scale(_viewScale),
                                child: image,
                              ),
                            ),
                          );
                        },
                      ),
          ),
          if (_showKeyboard) _buildKeyboardBar(),
        ],
      ),
    );
  }

  Widget _buildKeyboardBar() {
    return Container(
      color: Colors.grey[900],
      padding: const EdgeInsets.all(8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _textController,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              hintText: 'Type text and press send',
              hintStyle: TextStyle(color: Colors.grey),
              border: OutlineInputBorder(),
            ),
            onSubmitted: (text) {
              _service.sendText(text);
              _textController.clear();
            },
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            children: [
              _keyButton('ENTER'),
              _keyButton('BACKSPACE'),
              _keyButton('TAB'),
              _keyButton('ESC'),
              _keyButton('CTRL'),
              _keyButton('ALT'),
              _keyButton('SHIFT'),
              _keyButton('WIN'),
              _keyButton('UP'),
              _keyButton('DOWN'),
              _keyButton('LEFT'),
              _keyButton('RIGHT'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _keyButton(String key) {
    return ElevatedButton(
      onPressed: () => _service.sendKey(key),
      child: Text(key, style: const TextStyle(fontSize: 11)),
    );
  }
}