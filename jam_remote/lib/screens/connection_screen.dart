import 'package:flutter/material.dart';
import '../services/connection_service.dart';
import 'pairing_screen.dart';
import '../services/authentication_service.dart';
import 'system_screen.dart';
import 'dart:ui';

class ConnectionScreen extends StatefulWidget {
  const ConnectionScreen({super.key});

  @override
  State<ConnectionScreen> createState() => _ConnectionScreenState();
}

class _ConnectionScreenState extends State<ConnectionScreen> {
  final _ipController = TextEditingController(text: '192.168.1.20');
  final _portController = TextEditingController(text: '8080');
  final _remoteUrlController = TextEditingController();

  bool _isConnecting = false;
  bool? _isConnected;
  bool _remoteMode = false;

  Future<void> _connect() async {
    setState(() {
      _isConnecting = true;
      _isConnected = null;
    });

    if (_remoteMode) {
      final url = _remoteUrlController.text.trim();
      await ConnectionService.setRemoteConnection(url);
    } else {
      final ip = _ipController.text.trim();
      final port = _portController.text.trim();
      await ConnectionService.setLocalConnection(ip, port);
    }

    bool success;
    try {
      final data = await ConnectionService.get('/api/health');
      success = data['success'] == true;
    } catch (e) {
      success = false;
    }

    setState(() {
      _isConnecting = false;
      _isConnected = success;
    });

    // NEW: if we're connected and already have a valid saved token, skip pairing entirely.
    if (success) {
      final alreadyPaired = await AuthenticationService.isAlreadyPaired();
      if (alreadyPaired && mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const SystemScreen()),
        );
      }
    }
  }

  void _goToPairing() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => const PairingScreen(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset('assets/images/logo.png', width: 28, height: 28),
            const SizedBox(width: 10),
            const Text('RemoteNexus', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          ],
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset('assets/images/background.png', fit: BoxFit.cover),
          // Strong blur + heavy dark scrim — image becomes ambient texture, not competing detail
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(color: Colors.black.withOpacity(0.72)),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 8),
                  const Text('Connect to Computer',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(height: 20),
                  SegmentedButton<bool>(
                    style: SegmentedButton.styleFrom(
                      backgroundColor: Colors.white.withOpacity(0.06),
                      foregroundColor: Colors.white70,
                      selectedForegroundColor: Colors.black,
                      selectedBackgroundColor: Colors.white,
                      side: BorderSide(color: Colors.white.withOpacity(0.15)),
                    ),
                    segments: const [
                      ButtonSegment(value: false, label: Text('Local Network')),
                      ButtonSegment(value: true, label: Text('Remote (Internet)')),
                    ],
                    selected: {_remoteMode},
                    onSelectionChanged: (selection) {
                      setState(() {
                        _remoteMode = selection.first;
                        _isConnected = null;
                      });
                    },
                  ),
                  const SizedBox(height: 24),
                  if (!_remoteMode) ...[
                    _field(_ipController, 'IP Address'),
                    const SizedBox(height: 16),
                    _field(_portController, 'Port', keyboard: TextInputType.number),
                  ] else ...[
                    _field(_remoteUrlController, 'Tunnel URL',
                        hint: 'https://your-tunnel.trycloudflare.com', keyboard: TextInputType.url),
                  ],
                  const SizedBox(height: 28),
                  SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF1A1A3E),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        textStyle: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5),
                      ),
                      onPressed: _isConnecting ? null : _connect,
                      child: Text(_isConnecting ? 'CONNECTING...' : 'CONNECT'),
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (_isConnected == true) ...[
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle, color: Color(0xFF2ECC71), size: 20),
                        SizedBox(width: 8),
                        Text('CONNECTED',
                            style: TextStyle(color: Color(0xFF2ECC71), fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 48,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: BorderSide(color: Colors.white.withOpacity(0.4)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: _goToPairing,
                        child: const Text('PAIR DEVICE'),
                      ),
                    ),
                  ],
                  if (_isConnected == false)
                    const Padding(
                      padding: EdgeInsets.only(top: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.error_outline, color: Color(0xFFE74C3C), size: 18),
                          SizedBox(width: 8),
                          Flexible(
                            child: Text('Connection failed. Check your details and try again.',
                                style: TextStyle(color: Color(0xFFE74C3C))),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _field(TextEditingController controller, String label, {String? hint, TextInputType? keyboard}) {
    return TextField(
      controller: controller,
      keyboardType: keyboard,
      style: const TextStyle(color: Colors.white, fontSize: 16),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: const TextStyle(color: Colors.white60),
        hintStyle: const TextStyle(color: Colors.white30),
        filled: true,
        fillColor: Colors.white.withOpacity(0.06),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.12)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.12)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.white, width: 1.5),
        ),
      ),
    );
  }
}