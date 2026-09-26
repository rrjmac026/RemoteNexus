import 'package:flutter/material.dart';
import '../services/connection_service.dart';
import 'pairing_screen.dart';

class ConnectionScreen extends StatefulWidget {
  const ConnectionScreen({super.key});

  @override
  State<ConnectionScreen> createState() => _ConnectionScreenState();
}

class _ConnectionScreenState extends State<ConnectionScreen> {
  final _ipController = TextEditingController(text: '192.168.1.20');
  final _portController = TextEditingController(text: '8080');

  bool _isConnecting = false;
  bool? _isConnected;

  Future<void> _connect() async {
    setState(() {
      _isConnecting = true;
      _isConnected = null;
    });

    final ip = _ipController.text.trim();
    final port = _portController.text.trim();

    // Set connection first so the health check itself goes through ConnectionService.
    await ConnectionService.setLocalConnection(ip, port);

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
  }

  void _goToPairing() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => const PairingScreen(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('JAM Remote')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Connect to Computer',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            TextField(
              controller: _ipController,
              decoration: const InputDecoration(labelText: 'IP Address', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _portController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Port', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isConnecting ? null : _connect,
              child: Text(_isConnecting ? 'Connecting...' : 'CONNECT'),
            ),
            const SizedBox(height: 24),
            if (_isConnected == true) ...[
              const Text('🟢 CONNECTED', style: TextStyle(color: Colors.green, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _goToPairing,
                child: const Text('PAIR DEVICE'),
              ),
            ],
            if (_isConnected == false)
              const Text('🔴 Connection failed. Check IP/port and try again.', style: TextStyle(color: Colors.red)),
          ],
        ),
      ),
    );
  }
}