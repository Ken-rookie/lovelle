class PrintFileItem {
  const PrintFileItem({
    required this.name,
    required this.bytes,
    required this.extension,
    this.previewUri,
    this.storagePath,
  });

  final String name;
  final int bytes;
  final String extension;
  final String? previewUri;
  final String? storagePath;

  String get readableSize {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  Map<String, dynamic> toJson() => {
    'file_name': name,
    'file_size_bytes': bytes,
    'file_extension': extension,
    'storage_path': storagePath,
  };
}
