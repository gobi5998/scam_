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
  List<String> screenshots; // maps to screenshots

  @HiveField(10)
  List<String> documents; // maps to documents

  @HiveField(11)
  String? name; // maps to createdBy

  @HiveField(12)
  String? keycloackUserId; // maps to keycloackUserId (matching online API)

  @HiveField(13)
  String? fraudsterName;

  @HiveField(14)
  List<String> phoneNumbers;

  @HiveField(15)
  List<String> emails; // maps to emails

  @HiveField(16)
  String? companyName;

  @HiveField(17)
  List<String> mediaHandles; // maps to mediaHandles (matching online API)

  @HiveField(18)
  DateTime? incidentDate; // maps to incidentDate (matching online API)

  @HiveField(19)
  double? moneyLost; // maps to moneyLost (matching online API)

  @HiveField(20)
  List<String> voiceMessages; // maps to voiceMessages (matching online API)

  @HiveField(21)
  List<String> videofiles; // maps to videofiles (matching online API)

  @HiveField(22)
  String? currency; // maps to currency

  @HiveField(23)
  int? minAge; // maps to age.min

  @HiveField(24)
  int? maxAge; // maps to age.max

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
    this.screenshots = const [],
    this.documents = const [],
    this.name,
    this.keycloackUserId,
    this.fraudsterName,
    this.phoneNumbers = const [],
    this.emails = const [],
    this.companyName,
    this.mediaHandles = const [],
    this.incidentDate,
    this.moneyLost,
    this.voiceMessages = const [],
    this.videofiles = const [],
    this.currency,
    this.minAge,
    this.maxAge,
  });

  @override
  Map<String, dynamic> toSyncJson() => toJson();

  @override
  String get endpoint => '/api/v1/reports';

  bool get isInBox =>
      Hive.box<FraudReportModel>('fraud_reports').containsKey(id);

  Map<String, dynamic> toJson() {
    final json = {
      '_id': id,
      'reportCategoryId': reportCategoryId,
      'reportTypeId': reportTypeId,
      'keycloackUserId': keycloackUserId,
      'location': {
        'type': 'Point',
        'coordinates': [
          79.8114,
          11.9416,
        ], // Default coordinates, should be updated with actual location
        'address': 'Default Location', // Required by backend
      },
      'phoneNumbers': phoneNumbers,
      'emails': emails,
      'mediaHandles': mediaHandles,
      'website': website,
      'currency':
          currency ?? 'INR', // Use currency from model or default to INR
      'moneyLost': moneyLost?.toString(),
      'reportOutcome': true, // Default value, should be made configurable
      'description': description,
      'incidentDate': incidentDate?.toIso8601String(),
      'fraudsterName': fraudsterName,
      'companyName': companyName,
      'createdBy': name, // Using name as createdBy for now
      'screenshots': screenshots,
      'voiceMessages': voiceMessages,
      'documents': documents,
      'videofiles': videofiles,
      'age': {'min': minAge, 'max': maxAge},
    };

    // Only add alertLevels if it's not null
    if (alertLevels != null && alertLevels!.isNotEmpty) {
      json['alertLevels'] = alertLevels;
    }

    return json;
  }

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
    screenshots:
        (json['screenshots'] as List?)?.map((e) => e.toString()).toList() ?? [],
    documents:
        (json['documents'] as List?)?.map((e) => e.toString()).toList() ?? [],
    keycloackUserId: json['keycloackUserId'],
    fraudsterName: json['fraudsterName'],
    phoneNumbers:
        (json['phoneNumbers'] as List?)?.map((e) => e.toString()).toList() ??
        [],
    emails: (json['emails'] as List?)?.map((e) => e.toString()).toList() ?? [],
    companyName: json['companyName'],
    mediaHandles:
        (json['mediaHandles'] as List?)?.map((e) => e.toString()).toList() ??
        [],
    incidentDate: json['incidentDate'] != null
        ? DateTime.tryParse(json['incidentDate'])
        : null,
    moneyLost: json['moneyLost'] != null
        ? double.tryParse(json['moneyLost'].toString())
        : null,
    voiceMessages:
        (json['voiceMessages'] as List?)?.map((e) => e.toString()).toList() ??
        [],
    videofiles:
        (json['videofiles'] as List?)?.map((e) => e.toString()).toList() ?? [],
    currency: json['currency'],
    minAge: json['age'] != null ? json['age']['min'] : null,
    maxAge: json['age'] != null ? json['age']['max'] : null,
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
    List<String>? screenshots,
    List<String>? documents,
    String? keycloackUserId,
    String? fraudsterName,
    List<String>? phoneNumbers,
    List<String>? emails,
    String? companyName,
    List<String>? mediaHandles,
    DateTime? incidentDate,
    double? moneyLost,
    List<String>? voiceMessages,
    List<String>? videofiles,
    String? currency,
    int? minAge,
    int? maxAge,
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
      screenshots: screenshots ?? this.screenshots,
      documents: documents ?? this.documents,
      keycloackUserId: keycloackUserId ?? this.keycloackUserId,
      fraudsterName: fraudsterName ?? this.fraudsterName,
      phoneNumbers: phoneNumbers ?? this.phoneNumbers,
      emails: emails ?? this.emails,
      companyName: companyName ?? this.companyName,
      mediaHandles: mediaHandles ?? this.mediaHandles,
      incidentDate: incidentDate ?? this.incidentDate,
      moneyLost: moneyLost ?? this.moneyLost,
      voiceMessages: voiceMessages ?? this.voiceMessages,
      videofiles: videofiles ?? this.videofiles,
      currency: currency ?? this.currency,
      minAge: minAge ?? this.minAge,
      maxAge: maxAge ?? this.maxAge,
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
//   List<String> screenshots;

//   @HiveField(12)
//   List<String> documents;

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
//     this.screenshots = const [],
//     this.documents = const [],
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
//     'screenshots': screenshots,
//     'documents': documents,
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
//     'screenshots': screenshots,
//     'documents': documents,
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
//     screenshots: (json['screenshots'] as List?)?.map((e) => e as String).toList() ?? [],
//     documents: (json['documents'] as List?)?.map((e) => e as String).toList() ?? [],
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
