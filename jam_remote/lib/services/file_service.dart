import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../models/file_item.dart';

class FileOpResult {
  final bool success;
  final String message;
  FileOpResult(this.success, this.message);
}

class FileService {
  static Future<List<FileItem>?> listDirectory(
      String ip, String port, String token, String path) async {
    final url = Uri.parse('http://$ip:$port/api/files?path=${Uri.encodeComponent(path)}');
    try {
      final response = await http.get(
        url,
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 8));

      final data = jsonDecode(response.body);
      if (data['success'] == true) {
        final items = (data['data']['items'] as List)
            .map((e) => FileItem.fromJson(e))
            .toList();
        return items;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  static Future<FileOpResult> createDirectory(
      String ip, String port, String token, String path) async {
    final url = Uri.parse('http://$ip:$port/api/files/directory');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
        body: jsonEncode({'path': path}),
      ).timeout(const Duration(seconds: 8));

      final data = jsonDecode(response.body);
      if (data['success'] == true) return FileOpResult(true, 'Folder created.');
      return FileOpResult(false, data['error']?['message'] ?? 'Failed to create folder.');
    } catch (e) {
      return FileOpResult(false, 'Connection error.');
    }
  }

  static Future<FileOpResult> rename(
      String ip, String port, String token, String path, String newName) async {
    final url = Uri.parse('http://$ip:$port/api/files/rename');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
        body: jsonEncode({'path': path, 'new_name': newName}),
      ).timeout(const Duration(seconds: 8));

      final data = jsonDecode(response.body);
      if (data['success'] == true) return FileOpResult(true, 'Renamed.');
      return FileOpResult(false, data['error']?['message'] ?? 'Failed to rename.');
    } catch (e) {
      return FileOpResult(false, 'Connection error.');
    }
  }

  static Future<FileOpResult> delete(
      String ip, String port, String token, String path) async {
    final url = Uri.parse('http://$ip:$port/api/files');
    try {
      final request = http.Request('DELETE', url);
      request.headers['Content-Type'] = 'application/json';
      request.headers['Authorization'] = 'Bearer $token';
      request.body = jsonEncode({'path': path});

      final streamed = await request.send().timeout(const Duration(seconds: 8));
      final response = await http.Response.fromStream(streamed);
      final data = jsonDecode(response.body);

      if (data['success'] == true) return FileOpResult(true, 'Deleted.');
      return FileOpResult(false, data['error']?['message'] ?? 'Failed to delete.');
    } catch (e) {
      return FileOpResult(false, 'Connection error.');
    }
  }

  static Future<FileOpResult> uploadFile(
      String ip, String port, String token, String filePath, String fileName) async {
    final url = Uri.parse('http://$ip:$port/api/files/upload');
    try {
      final request = http.MultipartRequest('POST', url);
      request.headers['Authorization'] = 'Bearer $token';
      request.files.add(await http.MultipartFile.fromPath('file', filePath, filename: fileName));

      final streamed = await request.send().timeout(const Duration(seconds: 60));
      final response = await http.Response.fromStream(streamed);
      final data = jsonDecode(response.body);

      if (data['success'] == true) return FileOpResult(true, 'Uploaded.');
      return FileOpResult(false, data['error']?['message'] ?? 'Upload failed.');
    } catch (e) {
      return FileOpResult(false, 'Connection error.');
    }
  }

  static Future<FileOpResult> downloadFile(
      String ip, String port, String token, String remotePath, String fileName) async {
    final url = Uri.parse('http://$ip:$port/api/files/download?path=${Uri.encodeComponent(remotePath)}');
    try {
      final response = await http.get(
        url,
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 60));

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