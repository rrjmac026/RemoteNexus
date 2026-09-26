import 'dart:async';
import 'package:flutter/material.dart';
import '../services/authentication_service.dart';
import '../services/storage_service.dart';
import 'system_screen.dart';

class PairingScreen extends StatefulWidget {
  final String ip;
  final String port;

  const PairingScreen({super.key, required this.ip, required this.port});

  @override
  State<PairingScreen> createState() => _PairingScreenState();
}

class _PairingScreenState extends State<PairingScreen> {
  String? _code;
  String? _requestId;
  String _status = 'requesting'; // requesting | pending | approved | denied | error
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _startPairing();
  }

  Future<void> _startPairing() async {
    try {
      final result = await AuthenticationService.requestPairing(
        widget.ip,
        widget.port,
        'JAM Android',
      );
      setState(() {
        _code = result.code;
        _requestId = result.requestId;
        _status = 'pending';
      });
      _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) => _poll());
    } catch (e) {
      setState(() => _status = 'error');
    }
  }

  Future<void> _poll() async {
    if (_requestId == null) return;
    final result = await AuthenticationService.checkPairingStatus(
      widget.ip,
      widget.port,
      _requestId!,
    );

    if (result['status'] == 'approved') {
      _pollTimer?.cancel();
      await StorageService.saveToken(result['token']!);
      await StorageService.saveConnection(widget.ip, widget.port);
      if (mounted) setState(() => _status = 'approved');
    } else if (result['status'] == 'denied') {
      _pollTimer?.cancel();
      if (mounted) setState(() => _status = 'denied');
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pairing')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_status == 'requesting') const CircularProgressIndicator(),
              if (_status == 'pending') ...[
                const Text('Waiting for approval on your PC'),
                const SizedBox(height: 16),
                Text(
                  _code ?? '',
                  style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold, letterSpacing: 4),
                ),
                const SizedBox(height: 16),
                const CircularProgressIndicator(),
              ],
              if (_status == 'approved') ...[
                const Icon(Icons.check_circle, color: Colors.green, size: 64),
                const SizedBox(height: 16),
                const Text('Paired successfully!', style: TextStyle(fontSize: 18)),
                const SizedBox(height: 24),
                ElevatedButton(
                onPressed: () {
                    Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => const SystemScreen()),
                    );
                },
                child: const Text('Continue'),
                ),
              ],
              if (_status == 'denied') ...[
                const Icon(Icons.cancel, color: Colors.red, size: 64),
                const SizedBox(height: 16),
                const Text('Pairing was denied.'),
              ],
              if (_status == 'error') ...[
                const Icon(Icons.error, color: Colors.red, size: 64),
                const SizedBox(height: 16),
                const Text('Could not reach the agent.'),
              ],
            ],
          ),
        ),
      ),
    );
  }
}