import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/file_item.dart';
import '../services/connection_service.dart';

class FileOpResult {
  final bool success;
  final String message;
  FileOpResult(this.success, this.message);
}

class FileService {
  static Future<List<FileItem>?> listDirectory(String path) async {
    try {
      final data = await ConnectionService.get('/api/files?path=${Uri.encodeComponent(path)}');
      if (data['success'] == true) {
        return (data['data']['items'] as List).map((e) => FileItem.fromJson(e)).toList();
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  static Future<FileOpResult> createDirectory(String path) async {
    try {
      final data = await ConnectionService.post('/api/files/directory', {'path': path});
      if (data['success'] == true) return FileOpResult(true, 'Folder created.');
      return FileOpResult(false, data['error']?['message'] ?? 'Failed to create folder.');
    } catch (e) {
      return FileOpResult(false, 'Connection error.');
    }
  }

  static Future<FileOpResult> rename(String path, String newName) async {
    try {
      final data = await ConnectionService.post('/api/files/rename', {'path': path, 'new_name': newName});
      if (data['success'] == true) return FileOpResult(true, 'Renamed.');
      return FileOpResult(false, data['error']?['message'] ?? 'Failed to rename.');
    } catch (e) {
      return FileOpResult(false, 'Connection error.');
    }
  }

  static Future<FileOpResult> delete(String path) async {
    try {
      final data = await ConnectionService.delete('/api/files', {'path': path});
      if (data['success'] == true) return FileOpResult(true, 'Deleted.');
      return FileOpResult(false, data['error']?['message'] ?? 'Failed to delete.');
    } catch (e) {
      return FileOpResult(false, 'Connection error.');
    }
  }

  static Future<FileOpResult> uploadFile(String filePath, String fileName) async {
    try {
      final response = await ConnectionService.multipart('/api/files/upload', 'file', filePath, fileName);
      final data = jsonDecode(response.body);
      if (data['success'] == true) return FileOpResult(true, 'Uploaded.');
      return FileOpResult(false, data['error']?['message'] ?? 'Upload failed.');
    } catch (e) {
      return FileOpResult(false, 'Connection error.');
    }
  }

  static Future<FileOpResult> downloadFile(String remotePath, String fileName) async {
    try {
      final response = await ConnectionService.getRaw(
        '/api/files/download?path=${Uri.encodeComponent(remotePath)}',
        timeout: const Duration(seconds: 60),
      );
      if (response.statusCode == 200) {
        final dir = await getApplicationDocumentsDirectory();
        final savePath = '${dir.path}/$fileName';
        final file = File(savePath);
        await file.writeAsBytes(response.bodyBytes);
        return FileOpResult(true, 'Saved to $savePath');
      }
      return FileOpResult(false, 'Download failed.');
    } catch (e) {
      return FileOpResult(false, 'Connection error.');
    }
  }
}