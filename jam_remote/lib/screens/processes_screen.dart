import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../services/storage_service.dart';

class ProcessesScreen extends StatefulWidget {
  const ProcessesScreen({super.key});

  @override
  State<ProcessesScreen> createState() => _ProcessesScreenState();
}

class _ProcessesScreenState extends State<ProcessesScreen> {
  List<dynamic>? _processes;
  bool _loading = true;
  Timer? _timer;
  String? _ip, _port, _token;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    _ip = await StorageService.getSavedIp();
    _port = await StorageService.getSavedPort();
    _token = await StorageService.getToken();
    await _load();
    _timer = Timer.periodic(const Duration(seconds: 4), (_) => _load());
  }

  Future<void> _load() async {
    if (_ip == null) return;
    try {
      final response = await http.get(
        Uri.parse('http://$_ip:$_port/api/processes'),
        headers: {'Authorization': 'Bearer $_token'},
      ).timeout(const Duration(seconds: 5));

      final data = jsonDecode(response.body);
      if (data['success'] == true && mounted) {
        setState(() {
          _processes = data['data']['processes'];
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Processes')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _processes == null
              ? const Center(child: Text('Could not load processes.'))
              : ListView.builder(
                  itemCount: _processes!.length,
                  itemBuilder: (context, i) {
                    final p = _processes![i];
                    return ListTile(
                      dense: true,
                      leading: Text(p['pid'].toString(), style: const TextStyle(color: Colors.grey)),
                      title: Text(p['name']),
                    );
                  },
                ),
    );
  }
}