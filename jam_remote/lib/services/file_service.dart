import 'dart:convert';
import 'dart:io';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import '../models/file_item.dart';
import '../services/connection_service.dart';

class FileOpResult {
  final bool success;
  final String message;
  final String? savedPath;
  FileOpResult(this.success, this.message, {this.savedPath});
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

  static Future<FileOpResult> uploadFile(String targetDir, String filePath, String fileName) async {
    try {
      final response = await ConnectionService.multipart(
        '/api/files/upload', 'file', filePath, fileName,
        fields: {'path': targetDir},
      );
      final data = jsonDecode(response.body);
      if (data['success'] == true) return FileOpResult(true, 'Uploaded.');
      return FileOpResult(false, data['error']?['message'] ?? 'Upload failed.');
    } catch (e) {
      return FileOpResult(false, 'Connection error.');
    }
  }

  /// Downloads the file to a temp/cache location on the phone.
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
        return FileOpResult(true, 'Saved to $savePath', savedPath: savePath);
      }
      return FileOpResult(false, 'Download failed.');
    } catch (e) {
      return FileOpResult(false, 'Connection error.');
    }
  }

  /// Downloads (if not already cached) then opens the file in the phone's
  /// default app for that type — photo viewer, PDF reader, video player, etc.
  static Future<FileOpResult> openFile(String remotePath, String fileName) async {
    final dir = await getApplicationDocumentsDirectory();
    final localPath = '${dir.path}/$fileName';
    final localFile = File(localPath);

    // Reuse the cached copy if we already downloaded it, otherwise fetch it.
    if (!await localFile.exists()) {
      final result = await downloadFile(remotePath, fileName);
      if (!result.success) return result;
    }

    final openResult = await OpenFilex.open(localPath);
    if (openResult.type == ResultType.done) {
      return FileOpResult(true, 'Opened.');
    } else {
      return FileOpResult(false, openResult.message.isNotEmpty
          ? openResult.message
          : 'No app found to open this file type.');
    }
  }
}