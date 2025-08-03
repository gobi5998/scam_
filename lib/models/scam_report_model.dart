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
  List<String> screenshotPaths; // maps to screenshots

  @HiveField(10)
  List<String> documentPaths; // maps to documents

  @HiveField(11)
  String? name; // maps to createdBy

  @HiveField(12)
  String? keycloakUserId; // maps to keycloackUserId

  @HiveField(13)
  String? scammerName;

  @HiveField(14)
  List<String>? phoneNumbers;

  @HiveField(15)
  List<String>? emailAddresses; // maps to emails

  @HiveField(16)
  List<String>? socialMediaHandles; // maps to mediaHandles

  @HiveField(17)
  DateTime? incidentDateTime; // maps to incidentDate

  @HiveField(18)
  double? amountLost; // maps to moneyLost

  @HiveField(19)
  String? currency; // maps to currency

  @HiveField(20)
  List<String> voiceRecordings; // maps to voiceMessages

  @HiveField(21)
  String? methodOfContactId; // maps to methodOfContact

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
    this.screenshotPaths = const [],
    this.documentPaths = const [],
    this.name,
    this.keycloakUserId,
    this.scammerName,
    this.phoneNumbers,
    this.emailAddresses,
    this.socialMediaHandles,
    this.incidentDateTime,
    this.amountLost,
    this.currency,
    this.voiceRecordings = const [],
    this.methodOfContactId,
  }) {
    // Initialize arrays if they are null
    phoneNumbers ??= [];
    emailAddresses ??= [];
    socialMediaHandles ??= [];
  }

  Map<String, dynamic> toJson() => {
    '_id': id,
    'reportCategoryId': reportCategoryId,
    'reportTypeId': reportTypeId,
    'alertLevels': alertLevels,
    'keycloackUserId': keycloakUserId,
    'location': {
      'type': 'Point',
      'coordinates': [
        79.8114,
        11.9416,
      ], // Default coordinates, should be updated with actual location
    },
    'phoneNumbers': phoneNumbers ?? [],
    'emails': emailAddresses ?? [],
    'mediaHandles': socialMediaHandles ?? [],
    'website': website,
    'currency': currency ?? 'INR', // Use selected currency or default to INR
    'moneyLost': amountLost?.toString(),
    'reportOutcome': true, // Default value, should be made configurable
    'description': description,
    'incidentDate': incidentDateTime?.toIso8601String(),
    'scammerName': scammerName,
    'createdBy': name, // Using name as createdBy for now
    'screenshots': screenshotPaths,
    'voiceMessages': voiceRecordings,
    'documents': documentPaths,
    'methodOfContact': methodOfContactId,
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
    screenshotPaths:
        (json['screenshots'] as List?)?.map((e) => e.toString()).toList() ?? [],
    documentPaths:
        (json['documents'] as List?)?.map((e) => e.toString()).toList() ?? [],
    keycloakUserId: json['keycloackUserId'],
    scammerName: json['scammerName'],
    phoneNumbers:
        (json['phoneNumbers'] as List?)?.map((e) => e.toString()).toList() ??
        <String>[],
    emailAddresses:
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
    voiceRecordings:
        (json['voiceMessages'] as List?)?.map((e) => e.toString()).toList() ??
        [],
    methodOfContactId: json['methodOfContact'],
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
    List<String>? screenshotPaths,
    List<String>? documentPaths,
    String? keycloakUserId,
    String? scammerName,
    List<String>? phoneNumbers,
    List<String>? emailAddresses,
    List<String>? socialMediaHandles,
    DateTime? incidentDateTime,
    double? amountLost,
    List<String>? voiceRecordings,
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
      screenshotPaths: screenshotPaths ?? this.screenshotPaths,
      documentPaths: documentPaths ?? this.documentPaths,
      keycloakUserId: keycloakUserId ?? this.keycloakUserId,
      scammerName: scammerName ?? this.scammerName,
      phoneNumbers: phoneNumbers ?? this.phoneNumbers,
      emailAddresses: emailAddresses ?? this.emailAddresses,
      socialMediaHandles: socialMediaHandles ?? this.socialMediaHandles,
      incidentDateTime: incidentDateTime ?? this.incidentDateTime,
      amountLost: amountLost ?? this.amountLost,
      voiceRecordings: voiceRecordings ?? this.voiceRecordings,
      methodOfContactId: methodOfContactId ?? this.methodOfContactId,
    );
  }
}
