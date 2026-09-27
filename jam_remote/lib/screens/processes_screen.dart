import 'dart:async';
import 'package:flutter/material.dart';
import '../services/connection_service.dart';

class ProcessesScreen extends StatefulWidget {
  const ProcessesScreen({super.key});

  @override
  State<ProcessesScreen> createState() => _ProcessesScreenState();
}

class _ProcessesScreenState extends State<ProcessesScreen> {
  List<dynamic>? _processes;
  bool _loading = true;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await _load();
    _timer = Timer.periodic(const Duration(seconds: 4), (_) => _load());
  }

  Future<void> _load() async {
    try {
      final data = await ConnectionService.get('/api/processes');
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