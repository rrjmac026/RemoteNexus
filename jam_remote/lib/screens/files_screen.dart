import 'dart:async';
import 'dart:ui';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../models/file_item.dart';
import '../services/file_service.dart';

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
  bool _busyWithAction = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await _load(silent: false);
    _timer = Timer.periodic(const Duration(seconds: 3), (_) => _load(silent: true));
  }

  Future<void> _load({required bool silent}) async {
    if (_busyWithAction) return;
    if (!silent) setState(() { _initialLoading = true; _error = null; });

    final items = await FileService.listDirectory(_currentPath);
    if (!mounted) return;

    setState(() {
      _initialLoading = false;
      if (items != null) { _items = items; _error = null; }
      else if (!silent || _items == null) { _error = 'Could not load directory.'; }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _enterFolder(String name) {
    setState(() => _currentPath = _currentPath.isEmpty ? name : '$_currentPath/$name');
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
      builder: (_) => _glassDialog(
        title: 'New Folder',
        field: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: _dialogFieldDecoration('Folder name'),
        ),
        confirmLabel: 'Create',
        onConfirm: () => Navigator.pop(context, controller.text.trim()),
      ),
    );
    if (name == null || name.isEmpty) return;
    _busyWithAction = true;
    final path = _currentPath.isEmpty ? name : '$_currentPath/$name';
    final result = await FileService.createDirectory(path);
    _busyWithAction = false;
    _showSnack(result.message);
    if (result.success) _load(silent: false);
  }

  Future<void> _rename(FileItem item) async {
    final controller = TextEditingController(text: item.name);
    final newName = await showDialog<String>(
      context: context,
      builder: (_) => _glassDialog(
        title: 'Rename',
        field: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: _dialogFieldDecoration(null),
        ),
        confirmLabel: 'Rename',
        onConfirm: () => Navigator.pop(context, controller.text.trim()),
      ),
    );
    if (newName == null || newName.isEmpty || newName == item.name) return;
    _busyWithAction = true;
    final path = _currentPath.isEmpty ? item.name : '$_currentPath/${item.name}';
    final result = await FileService.rename(path, newName);
    _busyWithAction = false;
    _showSnack(result.message);
    if (result.success) _load(silent: false);
  }

  Future<void> _delete(FileItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF0A0E27).withOpacity(0.85),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withOpacity(0.12)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Delete this item?',
                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Text(item.name, style: const TextStyle(color: Colors.white60)),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('CANCEL', style: TextStyle(color: Colors.white60)),
                      ),
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('DELETE', style: TextStyle(color: Color(0xFFE74C3C), fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    if (confirmed != true) return;
    _busyWithAction = true;
    final path = _currentPath.isEmpty ? item.name : '$_currentPath/${item.name}';
    final result = await FileService.delete(path);
    _busyWithAction = false;
    _showSnack(result.message);
    if (result.success) _load(silent: false);
  }

  Future<void> _download(FileItem item) async {
    final path = _currentPath.isEmpty ? item.name : '$_currentPath/${item.name}';
    _showSnack('Downloading ${item.name}...');
    final result = await FileService.downloadFile(path, item.name);
    _showSnack(result.message);
  }

  Future<void> _openFile(FileItem item) async {
    final path = _currentPath.isEmpty ? item.name : '$_currentPath/${item.name}';
    _showSnack('Opening ${item.name}...');
    final result = await FileService.openFile(path, item.name);
    if (!result.success) _showSnack(result.message);
  }

  Future<void> _upload() async {
    final picked = await FilePicker.platform.pickFiles();
    if (picked == null || picked.files.isEmpty) return;
    final file = picked.files.first;
    if (file.path == null) return;
    _busyWithAction = true;
    _showSnack('Uploading ${file.name}...');
    final result = await FileService.uploadFile(_currentPath, file.path!, file.name);
    _busyWithAction = false;
    _showSnack(result.message);
    if (result.success) _load(silent: false);
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFF1E2340),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _dialogFieldDecoration_unused() => const SizedBox(); // placeholder to keep structure obvious

  InputDecoration _dialogFieldDecoration(String? hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.white30),
      filled: true,
      fillColor: Colors.white.withOpacity(0.06),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.12)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.12)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.white, width: 1.5),
      ),
    );
  }

  Widget _glassDialog({
    required String title,
    required Widget field,
    required String confirmLabel,
    required VoidCallback onConfirm,
  }) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF0A0E27).withOpacity(0.85),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.12)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 16),
                field,
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('CANCEL', style: TextStyle(color: Colors.white60)),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: onConfirm,
                      child: Text(confirmLabel.toUpperCase(),
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData _fileIcon(FileItem item) {
    if (item.isDirectory) return Icons.folder_rounded;
    final name = item.name.toLowerCase();
    if (name.endsWith('.pdf')) return Icons.picture_as_pdf_rounded;
    if (name.endsWith('.jpg') || name.endsWith('.jpeg') || name.endsWith('.png') || name.endsWith('.gif')) {
      return Icons.image_rounded;
    }
    if (name.endsWith('.mp4') || name.endsWith('.mov') || name.endsWith('.mkv')) return Icons.movie_rounded;
    if (name.endsWith('.mp3') || name.endsWith('.wav')) return Icons.audiotrack_rounded;
    if (name.endsWith('.zip') || name.endsWith('.rar') || name.endsWith('.7z')) return Icons.folder_zip_rounded;
    if (name.endsWith('.doc') || name.endsWith('.docx')) return Icons.description_rounded;
    return Icons.insert_drive_file_rounded;
  }

  Color _fileIconColor(FileItem item) {
    if (item.isDirectory) return const Color(0xFFFDCB6E);
    final name = item.name.toLowerCase();
    if (name.endsWith('.pdf')) return const Color(0xFFE74C3C);
    if (name.endsWith('.jpg') || name.endsWith('.jpeg') || name.endsWith('.png') || name.endsWith('.gif')) {
      return const Color(0xFF9B8CFF);
    }
    if (name.endsWith('.mp4') || name.endsWith('.mov') || name.endsWith('.mkv')) return const Color(0xFF6C5CE7);
    if (name.endsWith('.mp3') || name.endsWith('.wav')) return const Color(0xFF00B894);
    if (name.endsWith('.zip') || name.endsWith('.rar') || name.endsWith('.7z')) return const Color(0xFFE17055);
    return Colors.white60;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          _currentPath.isEmpty ? 'Files' : _currentPath,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
          overflow: TextOverflow.ellipsis,
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        leading: _currentPath.isEmpty
            ? null
            : IconButton(icon: const Icon(Icons.arrow_back), onPressed: _goUp),
        actions: [
          IconButton(icon: const Icon(Icons.create_new_folder_outlined), onPressed: _createFolder),
          IconButton(icon: const Icon(Icons.upload_file_rounded), onPressed: _upload),
          IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: () => _load(silent: false)),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset('assets/images/background.png', fit: BoxFit.cover),
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(color: Colors.black.withOpacity(0.72)),
          ),
          SafeArea(
            child: _initialLoading
                ? const Center(child: CircularProgressIndicator(color: Colors.white))
                : _items == null
                    ? Center(
                        child: Text(_error ?? 'No data', style: const TextStyle(color: Colors.white70)))
                    : Column(
                        children: [
                          if (_error != null)
                            Container(
                              width: double.infinity,
                              margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE74C3C).withOpacity(0.15),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFE74C3C).withOpacity(0.3)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.error_outline, color: Color(0xFFE74C3C), size: 18),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(_error!,
                                        style: const TextStyle(color: Color(0xFFE74C3C), fontSize: 13)),
                                  ),
                                ],
                              ),
                            ),
                          Expanded(
                            child: _items!.isEmpty
                                ? Center(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.folder_open_rounded,
                                            size: 48, color: Colors.white.withOpacity(0.3)),
                                        const SizedBox(height: 12),
                                        const Text('This folder is empty',
                                            style: TextStyle(color: Colors.white38)),
                                      ],
                                    ),
                                  )
                                : ListView.separated(
                                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                                    itemCount: _items!.length,
                                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                                    itemBuilder: (context, i) {
                                      final item = _items![i];
                                      return ClipRRect(
                                        borderRadius: BorderRadius.circular(16),
                                        child: BackdropFilter(
                                          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                                          child: Material(
                                            color: Colors.white.withOpacity(0.07),
                                            child: InkWell(
                                              onTap: item.isDirectory ? () => _enterFolder(item.name) : () => _openFile(item),
                                              borderRadius: BorderRadius.circular(16),
                                              child: Container(
                                                decoration: BoxDecoration(
                                                  borderRadius: BorderRadius.circular(16),
                                                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                                                ),
                                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                                child: Row(
                                                  children: [
                                                    Container(
                                                      width: 40,
                                                      height: 40,
                                                      decoration: BoxDecoration(
                                                        color: _fileIconColor(item).withOpacity(0.18),
                                                        borderRadius: BorderRadius.circular(11),
                                                      ),
                                                      child: Icon(_fileIcon(item), color: _fileIconColor(item), size: 20),
                                                    ),
                                                    const SizedBox(width: 12),
                                                    Expanded(
                                                      child: Column(
                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                        children: [
                                                          Text(
                                                            item.name,
                                                            style: const TextStyle(
                                                                color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
                                                            maxLines: 1,
                                                            overflow: TextOverflow.ellipsis,
                                                          ),
                                                          if (!item.isDirectory && item.sizeLabel.isNotEmpty) ...[
                                                            const SizedBox(height: 2),
                                                            Text(item.sizeLabel,
                                                                style: const TextStyle(color: Colors.white38, fontSize: 12)),
                                                          ],
                                                        ],
                                                      ),
                                                    ),
                                                    PopupMenuButton<String>(
                                                      icon: const Icon(Icons.more_vert, color: Colors.white60, size: 20),
                                                      color: const Color(0xFF1E2340),
                                                      shape: RoundedRectangleBorder(
                                                          borderRadius: BorderRadius.circular(12)),
                                                      onSelected: (value) {
                                                        if (value == 'open') _openFile(item);
                                                        if (value == 'rename') _rename(item);
                                                        if (value == 'delete') _delete(item);
                                                        if (value == 'download') _download(item);
                                                      },
                                                      itemBuilder: (context) => [
                                                        if (!item.isDirectory)
                                                          const PopupMenuItem(
                                                            value: 'open',
                                                            child: Text('Open', style: TextStyle(color: Colors.white)),
                                                          ),
                                                        if (!item.isDirectory)
                                                          const PopupMenuItem(
                                                            value: 'download',
                                                            child: Text('Download', style: TextStyle(color: Colors.white)),
                                                          ),
                                                        const PopupMenuItem(
                                                          value: 'rename',
                                                          child: Text('Rename', style: TextStyle(color: Colors.white)),
                                                        ),
                                                        const PopupMenuItem(
                                                          value: 'delete',
                                                          child: Text('Delete', style: TextStyle(color: Color(0xFFE74C3C))),
                                                        ),
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                          ),
                        ],
                      ),
          ),
        ],
      ),
    );
  }
}