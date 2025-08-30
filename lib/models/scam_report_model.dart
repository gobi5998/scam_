import 'package:hive/hive.dart';
import '../services/file_handling_service.dart';
import 'file_model.dart';
part 'scam_report_model.g.dart';

@HiveType(typeId: 0)
class ScamReportModel extends HiveObject {
  @HiveField(0)
  String? id; // maps to _id

  @HiveField(1)
  String? reportCategoryId;

  @HiveField(2)
  String? reportTypeId;

  @HiveField(3)
  String? alertLevels;

  @HiveField(4)
  String? website;

  @HiveField(5)
  String? description;

  @HiveField(6)
  DateTime? createdAt;

  @HiveField(7)
  DateTime? updatedAt;

  @HiveField(8)
  bool? isSynced;

  @HiveField(9)
  List<FileModel> screenshots; // maps to screenshots

  @HiveField(10)
  List<FileModel> documents; // maps to documents

  @HiveField(11)
  String? name; // maps to createdBy

  @HiveField(12)
  String? keycloackUserId; // maps to keycloackUserId

  @HiveField(13)
  String? scammerName;

  @HiveField(14)
  List<String>? phoneNumbers;

  @HiveField(15)
  List<String>? emails; // maps to emails

  @HiveField(16)
  List<String>? socialMediaHandles; // maps to mediaHandles

  @HiveField(17)
  DateTime? incidentDateTime; // maps to incidentDate

  @HiveField(18)
  double? amountLost; // maps to moneyLost

  @HiveField(19)
  String? currency; // maps to currency

  @HiveField(20)
  List<FileModel> voiceMessages; // maps to voiceMessages

  @HiveField(21)
  String? methodOfContactId; // maps to methodOfContact

  @HiveField(22)
  int? minAge; // maps to age.min

  @HiveField(23)
  int? maxAge; // maps to age.max

  @HiveField(24)
  List<FileModel> videofiles;

  // Add other fields as needed

  ScamReportModel({
    this.id,
    this.reportCategoryId,
    this.reportTypeId,
    this.alertLevels,
    this.website,
    this.description,
    this.createdAt,
    this.updatedAt,
    this.isSynced = false,
    this.screenshots = const [],
    this.documents = const [],
    this.name,
    this.keycloackUserId,
    this.scammerName,
    this.phoneNumbers,
    this.emails,
    this.socialMediaHandles,
    this.incidentDateTime,
    this.amountLost,
    this.currency,
    this.voiceMessages = const [],
    this.videofiles = const [],
    this.methodOfContactId,
    this.minAge,
    this.maxAge,
  }) {
    // Initialize arrays if they are null
    phoneNumbers ??= [];
    emails ??= [];
    socialMediaHandles ??= [];
  }

  Map<String, dynamic> toJson() => {
    '_id': id,
    'reportCategoryId': reportCategoryId,
    'reportTypeId': reportTypeId,
    'alertLevels': alertLevels,
    'keycloackUserId': keycloackUserId,
    'location': {
      'type': 'Point',
      'coordinates': [
        79.8114,
        11.9416,
      ], // Default coordinates, should be updated with actual location
    },
    'phoneNumbers': phoneNumbers ?? [],
    'emails': emails ?? [],
    'mediaHandles': socialMediaHandles ?? [],
    'website': website,
    'currency': currency ?? 'INR', // Use selected currency or default to INR
    'moneyLost': amountLost?.toString(),
    'reportOutcome': true, // Default value, should be made configurable
    'description': description,
    'incidentDate': incidentDateTime?.toIso8601String(),
    'scammerName': scammerName,
    'createdBy': name, // Using name as createdBy for now
    'screenshots': screenshots.map((f) => f.toJson()).toList(),
    'voiceMessages': voiceMessages.map((f) => f.toJson()).toList(),
    'documents': documents.map((f) => f.toJson()).toList(),
    'videofiles': videofiles.map((f) => f.toJson()).toList(),
    'methodOfContact': methodOfContactId,
    'age': {'min': minAge, 'max': maxAge},
  };

  factory ScamReportModel.fromJson(
    Map<String, dynamic> json,
  ) => ScamReportModel(
    id: json['id'] ?? json['_id'],
    reportCategoryId: json['reportCategoryId'],
    reportTypeId: json['reportTypeId'],
    alertLevels: json['alertLevels'],
    name: json['createdBy'], // Using createdBy as name
    website: json['website'],
    description: json['description'],
    createdAt: json['createdAt'] != null
        ? DateTime.tryParse(json['createdAt'])
        : null,
    updatedAt: json['updatedAt'] != null
        ? DateTime.tryParse(json['updatedAt'])
        : null,
    isSynced: json['isSynced'] ?? false,
    screenshots: FileHandlingService.parseBackendFiles(json['screenshots']),
    documents: FileHandlingService.parseBackendFiles(json['documents']),
    keycloackUserId: json['keycloackUserId'],
    scammerName: json['scammerName'],
    phoneNumbers:
        (json['phoneNumbers'] as List?)?.map((e) => e.toString()).toList() ??
        <String>[],
    emails:
        (json['emails'] as List?)?.map((e) => e.toString()).toList() ??
        <String>[],
    socialMediaHandles:
        (json['mediaHandles'] as List?)?.map((e) => e.toString()).toList() ??
        <String>[],
    incidentDateTime: json['incidentDate'] != null
        ? DateTime.tryParse(json['incidentDate'])
        : null,
    amountLost: json['moneyLost'] != null
        ? double.tryParse(json['moneyLost'].toString())
        : null,
    currency: json['currency'],
    voiceMessages: FileHandlingService.parseBackendFiles(json['voiceMessages']),
    videofiles: FileHandlingService.parseBackendFiles(json['videofiles']),
    methodOfContactId: json['methodOfContact'],
    minAge: json['age'] != null ? json['age']['min'] : null,
    maxAge: json['age'] != null ? json['age']['max'] : null,
  );

  ScamReportModel copyWith({
    String? id,
    String? reportCategoryId,
    String? reportTypeId,
    String? alertLevels,
    String? name,
    String? website,
    String? description,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isSynced,
    List<FileModel>? screenshots,
    List<FileModel>? documents,
    String? keycloakUserId,
    String? scammerName,
    List<String>? phoneNumbers,
    List<String>? emails,
    List<String>? socialMediaHandles,
    DateTime? incidentDateTime,
    double? amountLost,
    List<FileModel>? voiceMessages,
    List<FileModel>? videofiles,
    String? methodOfContactId,
  }) {
    return ScamReportModel(
      id: id ?? this.id,
      reportCategoryId: reportCategoryId ?? this.reportCategoryId,
      reportTypeId: reportTypeId ?? this.reportTypeId,
      alertLevels: alertLevels ?? this.alertLevels,
      name: name ?? this.name,
      website: website ?? this.website,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isSynced: isSynced ?? this.isSynced,
      screenshots: screenshots ?? this.screenshots,
      documents: documents ?? this.documents,
      keycloackUserId: keycloackUserId ?? keycloackUserId,
      scammerName: scammerName ?? this.scammerName,
      phoneNumbers: phoneNumbers ?? this.phoneNumbers,
      emails: emails ?? this.emails,
      socialMediaHandles: socialMediaHandles ?? this.socialMediaHandles,
      incidentDateTime: incidentDateTime ?? this.incidentDateTime,
      amountLost: amountLost ?? this.amountLost,
      voiceMessages: voiceMessages ?? this.voiceMessages,
      videofiles: videofiles ?? this.videofiles,
      methodOfContactId: methodOfContactId ?? this.methodOfContactId,
    );
  }
}
