class FileItem {
  final String name;
  final bool isDirectory;
  final int? size;
  final double modified;

  FileItem({
    required this.name,
    required this.isDirectory,
    this.size,
    required this.modified,
  });

  factory FileItem.fromJson(Map<String, dynamic> json) {
    return FileItem(
      name: json['name'],
      isDirectory: json['is_directory'],
      size: json['size'],
      modified: (json['modified'] as num).toDouble(),
    );
  }

  String get sizeLabel {
    if (isDirectory || size == null) return '';
    final s = size!;
    if (s < 1024) return '$s B';
    if (s < 1024 * 1024) return '${(s / 1024).toStringAsFixed(1)} KB';
    return '${(s / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}