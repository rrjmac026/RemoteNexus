import 'dart:async';
import 'package:flutter/material.dart';
import '../services/system_service.dart';
import '../services/storage_service.dart';
import 'terminal_screen.dart';
import 'files_screen.dart';
import 'processes_screen.dart';
import 'services_screen.dart';
import 'logs_screen.dart';
import 'remote_desktop_screen.dart';

class SystemScreen extends StatefulWidget {
  const SystemScreen({super.key});

  @override
  State<SystemScreen> createState() => _SystemScreenState();
}

class _SystemScreenState extends State<SystemScreen> {
  Map<String, dynamic>? _info;
  bool _initialLoading = true;
  String? _error;
  Timer? _timer;

  String? _ip;
  String? _port;
  String? _token;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await _refresh();
    _timer = Timer.periodic(const Duration(seconds: 2), (_) => _refresh());
  }

  Future<void> _refresh() async {
    final result = await SystemService.getSystemInfo();
    if (!mounted) return;
    setState(() {
      _initialLoading = false;
      if (result != null) {
        _info = result;
        _error = null;
      } else {
        _error = 'Connection lost.';
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
            title: const Text('System'),
            actions: [
            IconButton(
                icon: const Icon(Icons.terminal),
                onPressed: () {
                Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const TerminalScreen()),
                );
                },
            ),
            IconButton(
                icon: const Icon(Icons.folder),
                onPressed: () {
                    Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const FilesScreen()),
                    );
                },
            ),
            IconButton(
                icon: const Icon(Icons.list_alt),
                onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ProcessesScreen()),
                ),
            ),
                IconButton(
                icon: const Icon(Icons.build),
                onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ServicesScreen()),
                ),
            ),
                IconButton(
                icon: const Icon(Icons.receipt_long),
                onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const LogsScreen()),
                ),
            ),
            IconButton(
                icon: const Icon(Icons.desktop_windows),
                onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const RemoteDesktopScreen()),
                ),
            ),
            ],
        ),
      body: _initialLoading
          ? const Center(child: CircularProgressIndicator())
          : _info == null
              ? Center(child: Text(_error ?? 'No data'))
              : Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Text(_error!, style: const TextStyle(color: Colors.red)),
                        ),
                      _row('Computer', _info!['computer_name'].toString()),
                      _row('OS', _info!['os'].toString()),
                      _row('CPU', '${_info!['cpu_percent']}%'),
                      _row('RAM', '${_info!['ram_percent']}%'),
                      _row('Storage', '${_info!['storage_percent']}%'),
                      _row('Uptime', _info!['uptime'].toString()),
                    ],
                  ),
                ),
    );
  }
}