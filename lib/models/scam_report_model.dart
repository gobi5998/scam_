import 'package:hive/hive.dart';
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
  List<String> screenshots; // maps to screenshots (matching online API)

  @HiveField(10)
  List<String> documents; // maps to documents (matching online API)

  @HiveField(11)
  String? name; // maps to createdBy

  @HiveField(12)
  String? keycloackUserId; // maps to keycloackUserId (matching online API)

  @HiveField(13)
  String? scammerName;

  @HiveField(14)
  List<String>? phoneNumbers;

  @HiveField(15)
  List<String>? emails; // maps to emails (matching online API)

  @HiveField(16)
  List<String>? mediaHandles; // maps to mediaHandles (matching online API)

  @HiveField(17)
  DateTime? incidentDate; // maps to incidentDate (matching online API)

  @HiveField(18)
  double? moneyLost; // maps to moneyLost (matching online API)

  @HiveField(19)
  String? currency; // maps to currency

  @HiveField(20)
  List<String> voiceMessages; // maps to voiceMessages (matching online API)

  @HiveField(21)
  List<String> videofiles; // maps to videofiles (matching online API)

  @HiveField(22)
  String? methodOfContactId; // maps to methodOfContact

  @HiveField(23)
  int? minAge; // maps to age.min

  @HiveField(24)
  int? maxAge; // maps to age.max

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
    this.mediaHandles,
    this.incidentDate,
    this.moneyLost,
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
    mediaHandles ??= [];
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
    'mediaHandles': mediaHandles ?? [],
    'website': website,
    'currency': currency ?? 'INR', // Use selected currency or default to INR
    'moneyLost': moneyLost?.toString(),
    'reportOutcome': true, // Default value, should be made configurable
    'description': description,
    'incidentDate': incidentDate?.toIso8601String(),
    'scammerName': scammerName,
    'createdBy': name, // Using name as createdBy for now
    'screenshots': screenshots,
    'voiceMessages': voiceMessages,
    'documents': documents,
    'videofiles': videofiles,
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
    screenshots:
        (json['screenshots'] as List?)?.map((e) => e.toString()).toList() ?? [],
    documents:
        (json['documents'] as List?)?.map((e) => e.toString()).toList() ?? [],
    keycloackUserId: json['keycloackUserId'],
    scammerName: json['scammerName'],
    phoneNumbers:
        (json['phoneNumbers'] as List?)?.map((e) => e.toString()).toList() ??
        <String>[],
    emails:
        (json['emails'] as List?)?.map((e) => e.toString()).toList() ??
        <String>[],
    mediaHandles:
        (json['mediaHandles'] as List?)?.map((e) => e.toString()).toList() ??
        <String>[],
    incidentDate: json['incidentDate'] != null
        ? DateTime.tryParse(json['incidentDate'])
        : null,
    moneyLost: json['moneyLost'] != null
        ? double.tryParse(json['moneyLost'].toString())
        : null,
    currency: json['currency'],
    voiceMessages:
        (json['voiceMessages'] as List?)?.map((e) => e.toString()).toList() ??
        [],
    videofiles:
        (json['videofiles'] as List?)?.map((e) => e.toString()).toList() ?? [],
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
    List<String>? screenshots,
    List<String>? documents,
    String? keycloackUserId,
    String? scammerName,
    List<String>? phoneNumbers,
    List<String>? emails,
    List<String>? mediaHandles,
    DateTime? incidentDate,
    double? moneyLost,
    List<String>? voiceMessages,
    List<String>? videofiles,
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
      keycloackUserId: keycloackUserId ?? this.keycloackUserId,
      scammerName: scammerName ?? this.scammerName,
      phoneNumbers: phoneNumbers ?? this.phoneNumbers,
      emails: emails ?? this.emails,
      mediaHandles: mediaHandles ?? this.mediaHandles,
      incidentDate: incidentDate ?? this.incidentDate,
      moneyLost: moneyLost ?? this.moneyLost,
      voiceMessages: voiceMessages ?? this.voiceMessages,
      videofiles: videofiles ?? this.videofiles,
      methodOfContactId: methodOfContactId ?? this.methodOfContactId,
    );
  }
}
