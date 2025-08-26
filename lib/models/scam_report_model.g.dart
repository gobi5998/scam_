// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'scam_report_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ScamReportModelAdapter extends TypeAdapter<ScamReportModel> {
  @override
  final int typeId = 0;

  @override
  ScamReportModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ScamReportModel(
      id: fields[0] as String?,
      reportCategoryId: fields[1] as String?,
      reportTypeId: fields[2] as String?,
      alertLevels: fields[3] as String?,
      website: fields[4] as String?,
      description: fields[5] as String?,
      createdAt: fields[6] as DateTime?,
      updatedAt: fields[7] as DateTime?,
      isSynced: fields[8] as bool?,
      screenshots: (fields[9] as List).cast<FileModel>(),
      documents: (fields[10] as List).cast<FileModel>(),
      name: fields[11] as String?,
      keycloackUserId: fields[12] as String?,
      scammerName: fields[13] as String?,
      phoneNumbers: (fields[14] as List?)?.cast<String>(),
      emails: (fields[15] as List?)?.cast<String>(),
      socialMediaHandles: (fields[16] as List?)?.cast<String>(),
      incidentDateTime: fields[17] as DateTime?,
      amountLost: fields[18] as double?,
      currency: fields[19] as String?,
      voiceMessages: (fields[20] as List).cast<FileModel>(),
      videofiles: (fields[24] as List).cast<FileModel>(),
      methodOfContactId: fields[21] as String?,
      minAge: fields[22] as int?,
      maxAge: fields[23] as int?,
    );
  }

  @override
  void write(BinaryWriter writer, ScamReportModel obj) {
    writer
      ..writeByte(25)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.reportCategoryId)
      ..writeByte(2)
      ..write(obj.reportTypeId)
      ..writeByte(3)
      ..write(obj.alertLevels)
      ..writeByte(4)
      ..write(obj.website)
      ..writeByte(5)
      ..write(obj.description)
      ..writeByte(6)
      ..write(obj.createdAt)
      ..writeByte(7)
      ..write(obj.updatedAt)
      ..writeByte(8)
      ..write(obj.isSynced)
      ..writeByte(9)
      ..write(obj.screenshots)
      ..writeByte(10)
      ..write(obj.documents)
      ..writeByte(11)
      ..write(obj.name)
      ..writeByte(12)
      ..write(obj.keycloackUserId)
      ..writeByte(13)
      ..write(obj.scammerName)
      ..writeByte(14)
      ..write(obj.phoneNumbers)
      ..writeByte(15)
      ..write(obj.emails)
      ..writeByte(16)
      ..write(obj.socialMediaHandles)
      ..writeByte(17)
      ..write(obj.incidentDateTime)
      ..writeByte(18)
      ..write(obj.amountLost)
      ..writeByte(19)
      ..write(obj.currency)
      ..writeByte(20)
      ..write(obj.voiceMessages)
      ..writeByte(21)
      ..write(obj.methodOfContactId)
      ..writeByte(22)
      ..write(obj.minAge)
      ..writeByte(23)
      ..write(obj.maxAge)
      ..writeByte(24)
      ..write(obj.videofiles);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ScamReportModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
