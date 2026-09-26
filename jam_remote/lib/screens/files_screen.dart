import 'dart:async';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import '../models/file_item.dart';
import '../services/file_service.dart';
import '../services/storage_service.dart';

class FilesScreen extends StatefulWidget {
  const FilesScreen({super.key});

  @override
  State<FilesScreen> createState() => _FilesScreenState();
}

class _FilesScreenState extends State<FilesScreen> {
  String _currentPath = '';
  List<FileItem>? _items;
  bool _initialLoading = true;
  String? _error;
  Timer? _timer;
  bool _busyWithAction = false; // pauses polling during create/rename/delete/upload

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

    if (_ip == null || _port == null || _token == null) {
      setState(() {
        _initialLoading = false;
        _error = 'Not paired.';
      });
      return;
    }

    await _load(silent: false);
    _timer = Timer.periodic(const Duration(seconds: 3), (_) => _load(silent: true));
  }

  Future<void> _load({required bool silent}) async {
    if (_busyWithAction) return; // don't refresh mid-operation

    if (!silent) {
      setState(() {
        _initialLoading = true;
        _error = null;
      });
    }

    final items = await FileService.listDirectory(_ip!, _port!, _token!, _currentPath);
    if (!mounted) return;

    setState(() {
      _initialLoading = false;
      if (items != null) {
        _items = items;
        _error = null;
      } else if (!silent || _items == null) {
        // Only surface the error if we have nothing to show yet,
        // or this was an explicit (non-background) load.
        _error = 'Could not load directory.';
      }
      // On a failed silent refresh, keep showing the last known _items.
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _enterFolder(String name) {
    setState(() {
      _currentPath = _currentPath.isEmpty ? name : '$_currentPath/$name';
    });
    _load(silent: false);
  }

  void _goUp() {
    if (_currentPath.isEmpty) return;
    final parts = _currentPath.split('/')..removeLast();
    setState(() => _currentPath = parts.join('/'));
    _load(silent: false);
  }

  Future<void> _createFolder() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('New Folder'),
        content: TextField(controller: controller, decoration: const InputDecoration(hintText: 'Folder name')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('Create')),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;

    _busyWithAction = true;
    final path = _currentPath.isEmpty ? name : '$_currentPath/$name';
    final result = await FileService.createDirectory(_ip!, _port!, _token!, path);
    _busyWithAction = false;
    _showSnack(result.message);
    if (result.success) _load(silent: false);
  }

  Future<void> _rename(FileItem item) async {
    final controller = TextEditingController(text: item.name);
    final newName = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Rename'),
        content: TextField(controller: controller),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('Rename')),
        ],
      ),
    );
    if (newName == null || newName.isEmpty || newName == item.name) return;

    _busyWithAction = true;
    final path = _currentPath.isEmpty ? item.name : '$_currentPath/${item.name}';
    final result = await FileService.rename(_ip!, _port!, _token!, path, newName);
    _busyWithAction = false;
    _showSnack(result.message);
    if (result.success) _load(silent: false);
  }

  Future<void> _delete(FileItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete this item?'),
        content: Text(item.name),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('CANCEL')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('DELETE', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    _busyWithAction = true;
    final path = _currentPath.isEmpty ? item.name : '$_currentPath/${item.name}';
    final result = await FileService.delete(_ip!, _port!, _token!, path);
    _busyWithAction = false;
    _showSnack(result.message);
    if (result.success) _load(silent: false);
  }

  Future<void> _download(FileItem item) async {
    final path = _currentPath.isEmpty ? item.name : '$_currentPath/${item.name}';
    _showSnack('Downloading ${item.name}...');
    final result = await FileService.downloadFile(_ip!, _port!, _token!, path, item.name);
    _showSnack(result.message);
  }

  Future<void> _upload() async {
    final picked = await FilePicker.platform.pickFiles();
    if (picked == null || picked.files.isEmpty) return;

    final file = picked.files.first;
    if (file.path == null) return;

    _busyWithAction = true;
    _showSnack('Uploading ${file.name}...');
    final result = await FileService.uploadFile(_ip!, _port!, _token!, file.path!, file.name);
    _busyWithAction = false;
    _showSnack(result.message);
    if (result.success) _load(silent: false);
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_currentPath.isEmpty ? 'Files' : _currentPath),
        leading: _currentPath.isEmpty
            ? null
            : IconButton(icon: const Icon(Icons.arrow_back), onPressed: _goUp),
        actions: [
          IconButton(icon: const Icon(Icons.create_new_folder), onPressed: _createFolder),
          IconButton(icon: const Icon(Icons.upload_file), onPressed: _upload),
          IconButton(icon: const Icon(Icons.refresh), onPressed: () => _load(silent: false)),
        ],
      ),
      body: _initialLoading
          ? const Center(child: CircularProgressIndicator())
          : _items == null
              ? Center(child: Text(_error ?? 'No data'))
              : Column(
                  children: [
                    if (_error != null)
                      Container(
                        width: double.infinity,
                        color: Colors.red.withOpacity(0.1),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Text(_error!, style: const TextStyle(color: Colors.red)),
                      ),
                    Expanded(
                      child: _items!.isEmpty
                          ? const Center(child: Text('(empty)'))
                          : ListView.builder(
                              itemCount: _items!.length,
                              itemBuilder: (context, i) {
                                final item = _items![i];
                                return ListTile(
                                  leading: Icon(item.isDirectory ? Icons.folder : Icons.insert_drive_file),
                                  title: Text(item.name),
                                  subtitle: item.isDirectory ? null : Text(item.sizeLabel),
                                  onTap: item.isDirectory ? () => _enterFolder(item.name) : null,
                                  trailing: PopupMenuButton<String>(
                                    onSelected: (value) {
                                      if (value == 'rename') _rename(item);
                                      if (value == 'delete') _delete(item);
                                      if (value == 'download') _download(item);
                                    },
                                    itemBuilder: (context) => [
                                      if (!item.isDirectory)
                                        const PopupMenuItem(value: 'download', child: Text('Download')),
                                      const PopupMenuItem(value: 'rename', child: Text('Rename')),
                                      const PopupMenuItem(value: 'delete', child: Text('Delete')),
                                    ],
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
    );
  }
}