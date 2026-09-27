import 'dart:async';
import 'package:flutter/material.dart';
import '../services/connection_service.dart';

class ServicesScreen extends StatefulWidget {
  const ServicesScreen({super.key});

  @override
  State<ServicesScreen> createState() => _ServicesScreenState();
}

class _ServicesScreenState extends State<ServicesScreen> {
  List<dynamic>? _services;
  bool _loading = true;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await _load();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _load());
  }

  Future<void> _load() async {
    try {
      final data = await ConnectionService.get('/api/services');
      if (data['success'] == true && mounted) {
        setState(() {
          _services = data['data']['services'];
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
      appBar: AppBar(title: const Text('Services')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _services == null
              ? const Center(child: Text('Could not load services.'))
              : ListView.builder(
                  itemCount: _services!.length,
                  itemBuilder: (context, i) {
                    final s = _services![i];
                    final running = s['status'] == 'Running';
                    return ListTile(
                      title: Text(s['name']),
                      trailing: Text(
                        s['status'],
                        style: TextStyle(
                          color: running ? Colors.green : Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}