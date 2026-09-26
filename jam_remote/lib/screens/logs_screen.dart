import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../services/storage_service.dart';

class LogsScreen extends StatefulWidget {
  const LogsScreen({super.key});

  @override
  State<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends State<LogsScreen> {
  List<dynamic>? _entries;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final ip = await StorageService.getSavedIp();
    final port = await StorageService.getSavedPort();
    final token = await StorageService.getToken();

    try {
      final response = await http.get(
        Uri.parse('http://$ip:$port/api/logs'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 5));

      final data = jsonDecode(response.body);
      if (data['success'] == true) {
        setState(() {
          _entries = data['data']['entries'];
          _loading = false;
        });
        return;
      }
    } catch (e) {
      // fall through
    }
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Activity Logs'),
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _load)],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _entries == null || _entries!.isEmpty
              ? const Center(child: Text('No activity yet.'))
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _entries!.length,
                  itemBuilder: (context, i) => Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(_entries![i], style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
                    ),
                  ),
                ),
    );
  }
}