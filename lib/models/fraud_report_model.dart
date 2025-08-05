import 'package:hive/hive.dart';
import '../services/sync_service.dart';

part 'fraud_report_model.g.dart';

@HiveType(typeId: 1)
class FraudReportModel extends HiveObject implements SyncableReport {
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
  bool isSynced;

  @HiveField(9)
  List<String> screenshotPaths; // maps to screenshots

  @HiveField(10)
  List<String> documentPaths; // maps to documents

  @HiveField(11)
  String? name; // maps to createdBy

  @HiveField(12)
  String? keycloakUserId; // maps to keycloackUserId

  @HiveField(13)
  String? fraudsterName;

  @HiveField(14)
  List<String> phoneNumbers;

  @HiveField(15)
  List<String> emailAddresses; // maps to emails

  @HiveField(16)
  String? companyName;

  @HiveField(17)
  List<String> socialMediaHandles; // maps to mediaHandles

  @HiveField(18)
  DateTime? incidentDateTime; // maps to incidentDate

  @HiveField(19)
  double? amountInvolved; // maps to moneyLost

  @HiveField(20)
  List<String> voiceRecordings; // maps to voiceMessages

  @HiveField(21)
  String? currency; // maps to currency

  FraudReportModel({
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
    this.fraudsterName,
    this.phoneNumbers = const [],
    this.emailAddresses = const [],
    this.companyName,
    this.socialMediaHandles = const [],
    this.incidentDateTime,
    this.amountInvolved,
    this.voiceRecordings = const [],
    this.currency,
  });

  @override
  Map<String, dynamic> toSyncJson() => toJson();

  @override
  String get endpoint => '/api/reports';

  bool get isInBox =>
      Hive.box<FraudReportModel>('fraud_reports').containsKey(id);

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
    'phoneNumbers': phoneNumbers,
    'emails': emailAddresses,
    'mediaHandles': socialMediaHandles,
    'website': website,
    'currency': currency ?? 'INR', // Use currency from model or default to INR
    'moneyLost': amountInvolved?.toString(),
    'reportOutcome': true, // Default value, should be made configurable
    'description': description,
    'incidentDate': incidentDateTime?.toIso8601String(),
    'fraudsterName': fraudsterName,
    'companyName': companyName,
    'createdBy': name, // Using name as createdBy for now

    'screenshots': screenshotPaths,
    'voiceMessages': voiceRecordings,
    'documents': documentPaths,
  };

  factory FraudReportModel.fromJson(
    Map<String, dynamic> json,
  ) => FraudReportModel(
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
    fraudsterName: json['fraudsterName'],
    phoneNumbers:
        (json['phoneNumbers'] as List?)?.map((e) => e.toString()).toList() ??
        [],
    emailAddresses:
        (json['emails'] as List?)?.map((e) => e.toString()).toList() ?? [],
    companyName: json['companyName'],
    socialMediaHandles:
        (json['mediaHandles'] as List?)?.map((e) => e.toString()).toList() ??
        [],
    incidentDateTime: json['incidentDate'] != null
        ? DateTime.tryParse(json['incidentDate'])
        : null,
    amountInvolved: json['moneyLost'] != null
        ? double.tryParse(json['moneyLost'].toString())
        : null,
    voiceRecordings:
        (json['voiceMessages'] as List?)?.map((e) => e.toString()).toList() ??
        [],
  );

  FraudReportModel copyWith({
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
    String? fraudsterName,
    List<String>? phoneNumbers,
    List<String>? emailAddresses,
    String? companyName,
    List<String>? socialMediaHandles,
    DateTime? incidentDateTime,
    double? amountInvolved,
    List<String>? voiceRecordings,
    String? currency,
  }) {
    return FraudReportModel(
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
      fraudsterName: fraudsterName ?? this.fraudsterName,
      phoneNumbers: phoneNumbers ?? this.phoneNumbers,
      emailAddresses: emailAddresses ?? this.emailAddresses,
      companyName: companyName ?? this.companyName,
      socialMediaHandles: socialMediaHandles ?? this.socialMediaHandles,
      incidentDateTime: incidentDateTime ?? this.incidentDateTime,
      amountInvolved: amountInvolved ?? this.amountInvolved,
      voiceRecordings: voiceRecordings ?? this.voiceRecordings,
      currency: currency ?? this.currency,
    );
  }
}







// import 'dart:convert';

// import 'package:hive/hive.dart';
// import '../services/sync_service.dart';
// part 'fraud_report_model.g.dart';

// @HiveType(typeId: 1)
// class FraudReportModel extends HiveObject implements SyncableReport {
//   @HiveField(0)
//   String? id; // maps to _id

//   @HiveField(1)
//   String? reportCategoryId;

//   @HiveField(2)
//   String? reportTypeId;

//   @HiveField(3)
//   String? alertLevels;

//   @HiveField(4)
//   String? phoneNumber; // store as String for flexibility

//   @HiveField(5)
//   String? email;

//   @HiveField(6)
//   String? website;

//   @HiveField(7)
//   String? description;

//   @HiveField(8)
//   DateTime? createdAt;

//   @HiveField(9)
//   DateTime? updatedAt;

//   @HiveField(10)
//   bool isSynced;

//   @HiveField(11)
//   List<String> screenshotPaths;

//   @HiveField(12)
//   List<String> documentPaths;

//   @HiveField(13)
//   String? name;

//   FraudReportModel({
//     this.id,
//     this.reportCategoryId,
//     this.reportTypeId,
//     this.alertLevels,
//     this.phoneNumber,
//     this.email,
//     this.website,
//     this.description,
//     this.createdAt,
//     this.updatedAt,
//     this.isSynced = false,
//     this.screenshotPaths = const [],
//     this.documentPaths = const [],
//     this.name,
//   });

//   @override
//   Map<String, dynamic> toSyncJson() => {
//     '_id': id,
//     'reportCategoryId': reportCategoryId,
//     'reportTypeId': reportTypeId,
//     'alertLevels': alertLevels,
//     // If backend expects int, convert here:
//     'phoneNumber': int.tryParse(phoneNumber ?? '') ?? 0,
//     'email': email,
//     'website': website,
//     'description': description,
//     'createdAt': createdAt?.toIso8601String(),
//     'updatedAt': updatedAt?.toIso8601String(),
//     'isSynced': isSynced,
//     'screenshotPaths': screenshotPaths,
//     'documentPaths': documentPaths,
//     'name':name
//   };

//   @override
//   String get endpoint => '/reports';


//   Map<String, dynamic> toJson() => {
//     '_id': id,
//     'reportCategoryId': reportCategoryId,
//     'reportTypeId': reportTypeId,
//     'alertLevels': alertLevels,
//     'name':name,
//     // If backend expects int, convert here:
//     'phoneNumber': int.tryParse(phoneNumber ?? '') ?? 0,
//     'email': email,
//     'website': website,
//     'description': description,
//     'createdAt': createdAt?.toIso8601String(),
//     'updatedAt': updatedAt?.toIso8601String(),
//     'isSynced': isSynced,
//     'screenshotPaths': screenshotPaths,
//     'documentPaths': documentPaths,
//   };

//   factory FraudReportModel.fromJson(Map<String, dynamic> json) => FraudReportModel(
//     id: json['id'] ?? json['_id'],
//     reportCategoryId: json['reportCategoryId'],
//     reportTypeId: json['reportTypeId'],
//     name: json['name'],
//     alertLevels: json['alertLevels'],
//     phoneNumber: json['phoneNumber'],
//     email: json['email'],
//     website: json['website'],
//     description: json['description'],
//     createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt']) : null,
//     updatedAt: json['updatedAt'] != null ? DateTime.tryParse(json['updatedAt']) : null,
//     isSynced: json['isSynced'],
//     screenshotPaths: (json['screenshotPaths'] as List?)?.map((e) => e as String).toList() ?? [],
//     documentPaths: (json['documentPaths'] as List?)?.map((e) => e as String).toList() ?? [],
//   );

//   FraudReportModel copyWith({
//     String? id,
//     String? reportCategoryId,
//     String? reportTypeId,
//     String? alertLevels,
//     String? name,
//     String? phoneNumber,
//     String? email,
//     String? website,
//     String? description,
//     DateTime? createdAt,
//     DateTime? updatedAt,
//     bool? isSynced,
//     // add other fields as needed
//   }) {
//     return FraudReportModel(
//       id: id ?? this.id,
//       reportCategoryId: reportCategoryId ?? this.reportCategoryId,
//       reportTypeId: reportTypeId ?? this.reportTypeId,
//       alertLevels: alertLevels ?? this.alertLevels,
//       name: name?? this.name,
//       phoneNumber: phoneNumber ?? this.phoneNumber,
//       email: email ?? this.email,
//       website: website ?? this.website,
//       description: description ?? this.description,
//       createdAt: createdAt ?? this.createdAt,
//       updatedAt: updatedAt ?? this.updatedAt,
//       isSynced: isSynced ?? this.isSynced,
//       // add other fields as needed
//     );}
// }
