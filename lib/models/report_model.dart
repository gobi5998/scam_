import 'package:hive/hive.dart';
import '../services/sync_service.dart';

part 'report_model.g.dart';

@HiveType(typeId: 10) // Using a new typeId to avoid conflicts
class ReportModel extends HiveObject implements SyncableReport {
  @HiveField(0)
  String? id; // maps to _id

  @HiveField(1)
  String? reportCategoryId;

  @HiveField(2)
  String? reportTypeId;

  @HiveField(3)
  String? alertLevels;

  @HiveField(4)
  String? phoneNumber;

  @HiveField(5)
  String? email;

  @HiveField(6)
  String? website;

  @HiveField(7)
  String? description;

  @HiveField(8)
  DateTime? createdAt;

  @HiveField(9)
  DateTime? updatedAt;

  @override
  @HiveField(10)
  bool isSynced;

  @HiveField(11)
  List<String> screenshotPaths;

  @HiveField(12)
  List<String> documentPaths;

  @HiveField(13)
  String? name;

  @HiveField(14)
  String? keycloakUserId;

  // Additional fields for comprehensive report data
  @HiveField(15)
  String? deviceTypeId;

  @HiveField(16)
  String? detectTypeId;

  @HiveField(17)
  String? operatingSystemName;

  @HiveField(18)
  String? severity;

  @HiveField(19)
  String? status;

  @HiveField(20)
  String? categoryName;

  @HiveField(21)
  String? typeName;

  @HiveField(22)
  String? deviceTypeName;

  @HiveField(23)
  String? detectTypeName;

  @HiveField(24)
  String? operatingSystemNameValue;

  @HiveField(25)
  Map<String, dynamic>? metadata;

  @HiveField(26)
  List<String> tags;

  @HiveField(27)
  String? userId;

  @HiveField(28)
  String? userName;

  @HiveField(29)
  String? userEmail;

  @HiveField(30)
  int? priority;

  @HiveField(31)
  String? location;

  @HiveField(32)
  String? ipAddress;

  @HiveField(33)
  String? userAgent;

  @HiveField(34)
  Map<String, dynamic>? additionalData;

  ReportModel({
    this.id,
    this.reportCategoryId,
    this.reportTypeId,
    this.alertLevels,
    this.phoneNumber,
    this.email,
    this.website,
    this.description,
    this.createdAt,
    this.updatedAt,
    this.isSynced = false,
    this.screenshotPaths = const [],
    this.documentPaths = const [],
    this.name,
    this.keycloakUserId,
    this.deviceTypeId,
    this.detectTypeId,
    this.operatingSystemName,
    this.severity,
    this.status,
    this.categoryName,
    this.typeName,
    this.deviceTypeName,
    this.detectTypeName,
    this.operatingSystemNameValue,
    this.metadata,
    this.tags = const [],
    this.userId,
    this.userName,
    this.userEmail,
    this.priority,
    this.location,
    this.ipAddress,
    this.userAgent,
    this.additionalData,
  });

  @override
  Map<String, dynamic> toSyncJson() => {
    '_id': id,
    'reportCategoryId': reportCategoryId,
    'reportTypeId': reportTypeId,
    'alertLevels': alertLevels,
    'phoneNumber': int.tryParse(phoneNumber ?? '') ?? 0,
    'email': email,
    'website': website,
    'description': description,
    'createdAt': createdAt?.toIso8601String(),
    'updatedAt': updatedAt?.toIso8601String(),
    'isSynced': isSynced,
    'screenshotPaths': screenshotPaths,
    'documentPaths': documentPaths,
    'name': name,
    'keycloackUserId': keycloakUserId,
    'deviceTypeId': deviceTypeId,
    'detectTypeId': detectTypeId,
    'operatingSystemName': operatingSystemName,
    'severity': severity,
    'status': status,
    'categoryName': categoryName,
    'typeName': typeName,
    'deviceTypeName': deviceTypeName,
    'detectTypeName': detectTypeName,
    'operatingSystemNameValue': operatingSystemNameValue,
    'metadata': metadata,
    'tags': tags,
    'userId': userId,
    'userName': userName,
    'userEmail': userEmail,
    'priority': priority,
    'location': location,
    'ipAddress': ipAddress,
    'userAgent': userAgent,
    'additionalData': additionalData,
  };

  @override
  String get endpoint => '/api/v1/reports';

  Map<String, dynamic> toJson() => {
    '_id': id,
    'reportCategoryId': reportCategoryId,
    'reportTypeId': reportTypeId,
    'alertLevels': alertLevels,
    'name': name,
    'phoneNumber': int.tryParse(phoneNumber ?? '') ?? 0,
    'email': email,
    'website': website,
    'description': description,
    'createdAt': createdAt?.toIso8601String(),
    'updatedAt': updatedAt?.toIso8601String(),
    'isSynced': isSynced,
    'screenshotPaths': screenshotPaths,
    'documentPaths': documentPaths,
    'keycloackUserId': keycloakUserId,
    'deviceTypeId': deviceTypeId,
    'detectTypeId': detectTypeId,
    'operatingSystemName': operatingSystemName,
    'severity': severity,
    'status': status,
    'categoryName': categoryName,
    'typeName': typeName,
    'deviceTypeName': deviceTypeName,
    'detectTypeName': detectTypeName,
    'operatingSystemNameValue': operatingSystemNameValue,
    'metadata': metadata,
    'tags': tags,
    'userId': userId,
    'userName': userName,
    'userEmail': userEmail,
    'priority': priority,
    'location': location,
    'ipAddress': ipAddress,
    'userAgent': userAgent,
    'additionalData': additionalData,
  };

  factory ReportModel.fromJson(Map<String, dynamic> json) {
    return ReportModel(
      id: json['id'] ?? json['_id'],
      reportCategoryId: json['reportCategoryId'],
      reportTypeId: json['reportTypeId'],
      alertLevels: json['alertLevels'],
      name: json['name'],
      phoneNumber: json['phoneNumber']?.toString(),
      email: json['email'],
      website: json['website'],
      description: json['description'],
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'])
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'])
          : null,
      isSynced: json['isSynced'] ?? false,
      screenshotPaths:
          (json['screenshotPaths'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      documentPaths:
          (json['documentPaths'] as List?)?.map((e) => e.toString()).toList() ??
          [],
      keycloakUserId: json['keycloackUserId'] ?? json['keycloakUserId'],
      deviceTypeId: json['deviceTypeId'],
      detectTypeId: json['detectTypeId'],
      operatingSystemName: json['operatingSystemName'],
      severity: json['severity'],
      status: json['status'],
      categoryName: json['categoryName'],
      typeName: json['typeName'],
      deviceTypeName: json['deviceTypeName'],
      detectTypeName: json['detectTypeName'],
      operatingSystemNameValue: json['operatingSystemNameValue'],
      metadata: json['metadata'] is Map<String, dynamic>
          ? Map<String, dynamic>.from(json['metadata'])
          : null,
      tags: (json['tags'] as List?)?.map((e) => e.toString()).toList() ?? [],
      userId: json['userId'],
      userName: json['userName'],
      userEmail: json['userEmail'],
      priority: json['priority'] is int
          ? json['priority']
          : int.tryParse(json['priority']?.toString() ?? ''),
      location: json['location'],
      ipAddress: json['ipAddress'],
      userAgent: json['userAgent'],
      additionalData: json['additionalData'] is Map<String, dynamic>
          ? Map<String, dynamic>.from(json['additionalData'])
          : null,
    );
  }

  ReportModel copyWith({
    String? id,
    String? reportCategoryId,
    String? reportTypeId,
    String? alertLevels,
    String? name,
    String? phoneNumber,
    String? email,
    String? website,
    String? description,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isSynced,
    List<String>? screenshotPaths,
    List<String>? documentPaths,
    String? keycloakUserId,
    String? deviceTypeId,
    String? detectTypeId,
    String? operatingSystemName,
    String? severity,
    String? status,
    String? categoryName,
    String? typeName,
    String? deviceTypeName,
    String? detectTypeName,
    String? operatingSystemNameValue,
    Map<String, dynamic>? metadata,
    List<String>? tags,
    String? userId,
    String? userName,
    String? userEmail,
    int? priority,
    String? location,
    String? ipAddress,
    String? userAgent,
    Map<String, dynamic>? additionalData,
  }) {
    return ReportModel(
      id: id ?? this.id,
      reportCategoryId: reportCategoryId ?? this.reportCategoryId,
      reportTypeId: reportTypeId ?? this.reportTypeId,
      alertLevels: alertLevels ?? this.alertLevels,
      name: name ?? this.name,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      email: email ?? this.email,
      website: website ?? this.website,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isSynced: isSynced ?? this.isSynced,
      screenshotPaths: screenshotPaths ?? this.screenshotPaths,
      documentPaths: documentPaths ?? this.documentPaths,
      keycloakUserId: keycloakUserId ?? this.keycloakUserId,
      deviceTypeId: deviceTypeId ?? this.deviceTypeId,
      detectTypeId: detectTypeId ?? this.detectTypeId,
      operatingSystemName: operatingSystemName ?? this.operatingSystemName,
      severity: severity ?? this.severity,
      status: status ?? this.status,
      categoryName: categoryName ?? this.categoryName,
      typeName: typeName ?? this.typeName,
      deviceTypeName: deviceTypeName ?? this.deviceTypeName,
      detectTypeName: detectTypeName ?? this.detectTypeName,
      operatingSystemNameValue:
          operatingSystemNameValue ?? this.operatingSystemNameValue,
      metadata: metadata ?? this.metadata,
      tags: tags ?? this.tags,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      userEmail: userEmail ?? this.userEmail,
      priority: priority ?? this.priority,
      location: location ?? this.location,
      ipAddress: ipAddress ?? this.ipAddress,
      userAgent: userAgent ?? this.userAgent,
      additionalData: additionalData ?? this.additionalData,
    );
  }

  // Helper methods for common operations
  bool get isHighPriority => priority != null && priority! >= 8;

  bool get isMediumPriority =>
      priority != null && priority! >= 5 && priority! < 8;

  bool get isLowPriority => priority != null && priority! < 5;

  String get displayName => name ?? 'Report Malware';

  String get displayCategory => categoryName ?? 'Unknown Category';

  String get displayType => typeName ?? 'Unknown Type';

  String get displaySeverity => severity ?? alertLevels ?? 'Unknown';

  DateTime? get sortDate => updatedAt ?? createdAt;

  // Method to check if report matches search criteria
  bool matchesSearch(String searchTerm) {
    if (searchTerm.isEmpty) return true;

    final term = searchTerm.toLowerCase();
    return displayName.toLowerCase().contains(term) ||
        description?.toLowerCase().contains(term) == true ||
        displayCategory.toLowerCase().contains(term) ||
        displayType.toLowerCase().contains(term) ||
        email?.toLowerCase().contains(term) == true ||
        website?.toLowerCase().contains(term) == true ||
        phoneNumber?.toLowerCase().contains(term) == true ||
        tags.any((tag) => tag.toLowerCase().contains(term));
  }

  // Method to get a summary for display
  String get summary {
    final parts = <String>[];
    if (displayName.isNotEmpty) parts.add(displayName);
    if (displayCategory.isNotEmpty) parts.add(displayCategory);
    if (displayType.isNotEmpty) parts.add(displayType);
    if (displaySeverity.isNotEmpty) parts.add(displaySeverity);

    return parts.join(' • ');
  }

  @override
  String toString() {
    return 'ReportModel(id: $id, name: $name, category: $categoryName, type: $typeName, severity: $severity)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ReportModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
