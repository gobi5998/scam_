import 'package:hive/hive.dart';

part 'file_model.g.dart';

@HiveType(typeId: 10)
class FileModel extends HiveObject {
  @HiveField(0)
  String? uploadPath;

  @HiveField(1)
  String? s3Url;

  @HiveField(2)
  String? s3Key;

  @HiveField(3)
  String? originalName;

  @HiveField(4)
  String? fileId;

  @HiveField(5)
  String? url;

  @override
  @HiveField(6)
  String? key;

  @HiveField(7)
  String? fileName;

  @HiveField(8)
  int? size;

  @HiveField(9)
  String? contentType;

  FileModel({
    this.uploadPath,
    this.s3Url,
    this.s3Key,
    this.originalName,
    this.fileId,
    this.url,
    this.key,
    this.fileName,
    this.size,
    this.contentType,
  });

  // Convert to JSON for API calls
  Map<String, dynamic> toJson() => {
    'uploadPath': uploadPath,
    's3Url': s3Url,
    's3Key': s3Key,
    'originalName': originalName,
    'fileId': fileId,
    'url': url,
    'key': key,
    'fileName': fileName,
    'size': size,
    'contentType': contentType,
  };

  // Create from JSON (backend response)
  factory FileModel.fromJson(Map<String, dynamic> json) => FileModel(
    uploadPath: json['uploadPath'],
    s3Url: json['s3Url'],
    s3Key: json['s3Key'],
    originalName: json['originalName'],
    fileId: json['fileId'],
    url: json['url'],
    key: json['key'],
    fileName: json['fileName'],
    size: json['size'] is int ? json['size'] : int.tryParse(json['size']?.toString() ?? '0'),
    contentType: json['contentType'],
  );

  // Create from simple string (for offline storage)
  factory FileModel.fromString(String filePath) => FileModel(
    uploadPath: filePath,
    s3Url: filePath,
    s3Key: '',
    originalName: filePath.split('/').last,
    fileId: '',
    url: filePath,
    key: '',
    fileName: filePath.split('/').last,
    size: 0,
    contentType: '',
  );

  // Get the primary URL for display/download
  String get displayUrl => s3Url ?? url ?? uploadPath ?? '';

  // Get the file name for display
  String get displayName => originalName ?? fileName ?? 'Unknown File';

  // Check if this is a complete file object from backend
  bool get isComplete => s3Url != null && fileId != null;

  // Check if this is just a local file path
  bool get isLocalPath => s3Url == null && fileId == null && uploadPath != null;

  FileModel copyWith({
    String? uploadPath,
    String? s3Url,
    String? s3Key,
    String? originalName,
    String? fileId,
    String? url,
    String? key,
    String? fileName,
    int? size,
    String? contentType,
  }) {
    return FileModel(
      uploadPath: uploadPath ?? this.uploadPath,
      s3Url: s3Url ?? this.s3Url,
      s3Key: s3Key ?? this.s3Key,
      originalName: originalName ?? this.originalName,
      fileId: fileId ?? this.fileId,
      url: url ?? this.url,
      key: key ?? this.key,
      fileName: fileName ?? this.fileName,
      size: size ?? this.size,
      contentType: contentType ?? this.contentType,
    );
  }
}
