import 'package:hive/hive.dart';

part 'offline_models.g.dart';

@HiveType(typeId: 20)
class OfflineDueDiligenceReport extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String groupId;

  @HiveField(2)
  List<OfflineCategory> categories;

  @HiveField(3)
  String status;

  @HiveField(4)
  String comments;

  @HiveField(5)
  DateTime createdAt;

  @HiveField(6)
  DateTime updatedAt;

  @HiveField(7)
  bool isSynced;

  @HiveField(8)
  String? submissionId;

  @HiveField(9)
  DateTime? submittedAt;

  OfflineDueDiligenceReport({
    required this.id,
    required this.groupId,
    required this.categories,
    required this.status,
    required this.comments,
    required this.createdAt,
    required this.updatedAt,
    this.isSynced = false,
    this.submissionId,
    this.submittedAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'group_id': groupId,
      'categories': categories.map((c) => c.toJson()).toList(),
      'status': status,
      'comments': comments,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'isSynced': isSynced,
      'submission_id': submissionId,
      'submitted_at': submittedAt?.toIso8601String(),
    };
  }

  factory OfflineDueDiligenceReport.fromJson(Map<String, dynamic> json) {
    return OfflineDueDiligenceReport(
      id: json['id'] ?? json['_id'] ?? '',
      groupId: json['group_id'] ?? json['groupId'] ?? '',
      categories:
          (json['categories'] as List<dynamic>?)
              ?.map((c) => OfflineCategory.fromJson(c))
              .toList() ??
          [],
      status: json['status'] ?? 'draft',
      comments: json['comments'] ?? '',
      createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updatedAt'] ?? '') ?? DateTime.now(),
      isSynced: json['isSynced'] ?? false,
      submissionId: json['submission_id'] ?? json['submissionId'],
      submittedAt: json['submitted_at'] != null
          ? DateTime.tryParse(json['submitted_at'])
          : null,
    );
  }
}

@HiveType(typeId: 21)
class OfflineCategory extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  String label;

  @HiveField(3)
  List<OfflineSubcategory> subcategories;

  @HiveField(4)
  String status;

  OfflineCategory({
    required this.id,
    required this.name,
    required this.label,
    required this.subcategories,
    required this.status,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'label': label,
      'subcategories': subcategories.map((s) => s.toJson()).toList(),
      'status': status,
    };
  }

  factory OfflineCategory.fromJson(Map<String, dynamic> json) {
    return OfflineCategory(
      id: json['id'] ?? json['_id'] ?? '',
      name: json['name'] ?? '',
      label: json['label'] ?? '',
      subcategories:
          (json['subcategories'] as List<dynamic>?)
              ?.map((s) => OfflineSubcategory.fromJson(s))
              .toList() ??
          [],
      status: json['status'] ?? 'draft',
    );
  }
}

@HiveType(typeId: 22)
class OfflineSubcategory extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  String label;

  @HiveField(3)
  List<OfflineFile> files;

  @HiveField(4)
  String status;

  OfflineSubcategory({
    required this.id,
    required this.name,
    required this.label,
    required this.files,
    required this.status,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'label': label,
      'files': files.map((f) => f.toJson()).toList(),
      'status': status,
    };
  }

  factory OfflineSubcategory.fromJson(Map<String, dynamic> json) {
    return OfflineSubcategory(
      id: json['id'] ?? json['_id'] ?? '',
      name: json['name'] ?? '',
      label: json['label'] ?? '',
      files:
          (json['files'] as List<dynamic>?)
              ?.map((f) => OfflineFile.fromJson(f))
              .toList() ??
          [],
      status: json['status'] ?? 'draft',
    );
  }
}

@HiveType(typeId: 23)
class OfflineFile extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  String type;

  @HiveField(3)
  int size;

  @HiveField(4)
  String? localPath;

  @HiveField(5)
  String? url;

  @HiveField(6)
  String comments;

  @HiveField(7)
  DateTime uploadTime;

  @HiveField(8)
  bool isUploaded;

  @HiveField(9)
  String? documentId;

  @HiveField(10)
  String status;

  OfflineFile({
    required this.id,
    required this.name,
    required this.type,
    required this.size,
    this.localPath,
    this.url,
    required this.comments,
    required this.uploadTime,
    this.isUploaded = false,
    this.documentId,
    required this.status,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'size': size,
      'localPath': localPath,
      'url': url,
      'comments': comments,
      'uploadTime': uploadTime.toIso8601String(),
      'isUploaded': isUploaded,
      'document_id': documentId,
      'status': status,
    };
  }

  factory OfflineFile.fromJson(Map<String, dynamic> json) {
    return OfflineFile(
      id: json['id'] ?? json['_id'] ?? '',
      name: json['name'] ?? '',
      type: json['type'] ?? '',
      size: json['size'] ?? 0,
      localPath: json['localPath'],
      url: json['url'],
      comments: json['comments'] ?? '',
      uploadTime: DateTime.tryParse(json['uploadTime'] ?? '') ?? DateTime.now(),
      isUploaded: json['isUploaded'] ?? false,
      documentId: json['document_id'] ?? json['documentId'],
      status: json['status'] ?? 'draft',
    );
  }
}

@HiveType(typeId: 24)
class OfflineCategoryTemplate extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  String label;

  @HiveField(3)
  String description;

  @HiveField(4)
  int order;

  @HiveField(5)
  bool isActive;

  @HiveField(6)
  List<OfflineSubcategoryTemplate> subcategories;

  @HiveField(7)
  DateTime lastUpdated;

  OfflineCategoryTemplate({
    required this.id,
    required this.name,
    required this.label,
    required this.description,
    required this.order,
    required this.isActive,
    required this.subcategories,
    required this.lastUpdated,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'label': label,
      'description': description,
      'order': order,
      'isActive': isActive,
      'subcategories': subcategories.map((s) => s.toJson()).toList(),
      'lastUpdated': lastUpdated.toIso8601String(),
    };
  }

  factory OfflineCategoryTemplate.fromJson(Map<String, dynamic> json) {
    return OfflineCategoryTemplate(
      id: json['id'] ?? json['_id'] ?? '',
      name: json['name'] ?? '',
      label: json['label'] ?? '',
      description: json['description'] ?? '',
      order: json['order'] ?? 0,
      isActive: json['isActive'] ?? false,
      subcategories:
          (json['subcategories'] as List<dynamic>?)
              ?.map((s) => OfflineSubcategoryTemplate.fromJson(s))
              .toList() ??
          [],
      lastUpdated:
          DateTime.tryParse(json['lastUpdated'] ?? '') ?? DateTime.now(),
    );
  }
}

@HiveType(typeId: 25)
class OfflineSubcategoryTemplate extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  String label;

  @HiveField(3)
  String type;

  @HiveField(4)
  bool required;

  @HiveField(5)
  List<dynamic> options;

  @HiveField(6)
  int order;

  @HiveField(7)
  String categoryId;

  @HiveField(8)
  bool isActive;

  OfflineSubcategoryTemplate({
    required this.id,
    required this.name,
    required this.label,
    required this.type,
    required this.required,
    required this.options,
    required this.order,
    required this.categoryId,
    required this.isActive,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'label': label,
      'type': type,
      'required': required,
      'options': options,
      'order': order,
      'categoryId': categoryId,
      'isActive': isActive,
    };
  }

  factory OfflineSubcategoryTemplate.fromJson(Map<String, dynamic> json) {
    return OfflineSubcategoryTemplate(
      id: json['id'] ?? json['_id'] ?? '',
      name: json['name'] ?? '',
      label: json['label'] ?? '',
      type: json['type'] ?? '',
      required: json['required'] ?? false,
      options: json['options'] ?? [],
      order: json['order'] ?? 0,
      categoryId: json['categoryId'] ?? json['category_id'] ?? '',
      isActive: json['isActive'] ?? false,
    );
  }
}

@HiveType(typeId: 26)
class OfflineUserData extends HiveObject {
  @HiveField(0)
  String userId;

  @HiveField(1)
  String groupId;

  @HiveField(2)
  DateTime lastUpdated;

  @HiveField(3)
  Map<String, dynamic> additionalData;

  OfflineUserData({
    required this.userId,
    required this.groupId,
    required this.lastUpdated,
    required this.additionalData,
  });

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'groupId': groupId,
      'lastUpdated': lastUpdated.toIso8601String(),
      'additionalData': additionalData,
    };
  }

  factory OfflineUserData.fromJson(Map<String, dynamic> json) {
    return OfflineUserData(
      userId: json['userId'] ?? '',
      groupId: json['groupId'] ?? '',
      lastUpdated:
          DateTime.tryParse(json['lastUpdated'] ?? '') ?? DateTime.now(),
      additionalData: json['additionalData'] ?? {},
    );
  }
}
