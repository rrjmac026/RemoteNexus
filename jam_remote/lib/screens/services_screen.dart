import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../services/storage_service.dart';

class ServicesScreen extends StatefulWidget {
  const ServicesScreen({super.key});

  @override
  State<ServicesScreen> createState() => _ServicesScreenState();
}

class _ServicesScreenState extends State<ServicesScreen> {
  List<dynamic>? _services;
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
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _load());
  }

  Future<void> _load() async {
    if (_ip == null) return;
    try {
      final response = await http.get(
        Uri.parse('http://$_ip:$_port/api/services'),
        headers: {'Authorization': 'Bearer $_token'},
      ).timeout(const Duration(seconds: 5));

      final data = jsonDecode(response.body);
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