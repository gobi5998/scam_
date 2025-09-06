import 'package:hive/hive.dart';

part 'due_diligence_offline_models.g.dart';

@HiveType(typeId: 10)
class OfflineDueDiligenceReport extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String groupId;

  @HiveField(2)
  String status;

  @HiveField(3)
  String? comments;

  @HiveField(4)
  List<OfflineCategory> categories;

  @HiveField(5)
  DateTime createdAt;

  @HiveField(6)
  DateTime updatedAt;

  @HiveField(7)
  bool isOffline;

  @HiveField(8)
  bool needsSync;

  @HiveField(9)
  String? serverId; // ID from server when synced

  OfflineDueDiligenceReport({
    required this.id,
    required this.groupId,
    required this.status,
    this.comments,
    required this.categories,
    required this.createdAt,
    required this.updatedAt,
    this.isOffline = true,
    this.needsSync = true,
    this.serverId,
  });

  factory OfflineDueDiligenceReport.fromJson(Map<String, dynamic> json) {
    return OfflineDueDiligenceReport(
      id: json['id'] ?? '',
      groupId: json['group_id'] ?? json['groupId'] ?? '',
      status: json['status'] ?? 'draft',
      comments: json['comments'],
      categories:
          (json['categories'] as List<dynamic>?)
              ?.map((cat) => OfflineCategory.fromJson(cat))
              .toList() ??
          [],
      createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updatedAt'] ?? '') ?? DateTime.now(),
      isOffline: json['isOffline'] ?? true,
      needsSync: json['needsSync'] ?? true,
      serverId: json['serverId'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'group_id': groupId,
      'status': status,
      'comments': comments,
      'categories': categories.map((cat) => cat.toJson()).toList(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'isOffline': isOffline,
      'needsSync': needsSync,
      'serverId': serverId,
    };
  }
}

@HiveType(typeId: 11)
class OfflineCategory {
  @HiveField(0)
  String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  String label;

  @HiveField(3)
  List<OfflineSubcategory> subcategories;

  OfflineCategory({
    required this.id,
    required this.name,
    required this.label,
    required this.subcategories,
  });

  factory OfflineCategory.fromJson(Map<String, dynamic> json) {
    return OfflineCategory(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      label: json['label'] ?? '',
      subcategories:
          (json['subcategories'] as List<dynamic>?)
              ?.map((sub) => OfflineSubcategory.fromJson(sub))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'label': label,
      'subcategories': subcategories.map((sub) => sub.toJson()).toList(),
    };
  }
}

@HiveType(typeId: 12)
class OfflineSubcategory {
  @HiveField(0)
  String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  String label;

  @HiveField(3)
  List<OfflineFile> files;

  OfflineSubcategory({
    required this.id,
    required this.name,
    required this.label,
    required this.files,
  });

  factory OfflineSubcategory.fromJson(Map<String, dynamic> json) {
    return OfflineSubcategory(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      label: json['label'] ?? '',
      files:
          (json['files'] as List<dynamic>?)
              ?.map((file) => OfflineFile.fromJson(file))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'label': label,
      'files': files.map((file) => file.toJson()).toList(),
    };
  }
}

@HiveType(typeId: 13)
class OfflineFile {
  @HiveField(0)
  String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  String type;

  @HiveField(3)
  int size;

  @HiveField(4)
  String? url;

  @HiveField(5)
  String? localPath; // For offline files

  @HiveField(6)
  String? comments;

  @HiveField(7)
  DateTime uploadTime;

  @HiveField(8)
  bool isOffline;

  OfflineFile({
    required this.id,
    required this.name,
    required this.type,
    required this.size,
    this.url,
    this.localPath,
    this.comments,
    required this.uploadTime,
    this.isOffline = true,
  });

  factory OfflineFile.fromJson(Map<String, dynamic> json) {
    return OfflineFile(
      id: json['id'] ?? json['_id'] ?? '',
      name: json['name'] ?? json['fileName'] ?? '',
      type: json['type'] ?? json['fileType'] ?? 'unknown',
      size: json['size'] ?? json['fileSize'] ?? 0,
      url: json['url'] ?? json['filePath'],
      localPath: json['localPath'],
      comments: json['comments'] ?? json['documentNumber'],
      uploadTime:
          DateTime.tryParse(json['uploaded_at'] ?? json['uploadTime'] ?? '') ??
          DateTime.now(),
      isOffline: json['isOffline'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'size': size,
      'url': url,
      'localPath': localPath,
      'comments': comments,
      'uploadTime': uploadTime.toIso8601String(),
      'isOffline': isOffline,
    };
  }
}

@HiveType(typeId: 14)
class OfflineSyncQueue extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String action; // 'create', 'update', 'delete'

  @HiveField(2)
  String reportId;

  @HiveField(3)
  Map<String, dynamic> data;

  @HiveField(4)
  DateTime createdAt;

  @HiveField(5)
  int retryCount;

  @HiveField(6)
  String? error;

  OfflineSyncQueue({
    required this.id,
    required this.action,
    required this.reportId,
    required this.data,
    required this.createdAt,
    this.retryCount = 0,
    this.error,
  });
}
