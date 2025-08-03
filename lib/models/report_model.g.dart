// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'report_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ReportModelAdapter extends TypeAdapter<ReportModel> {
  @override
  final int typeId = 10;

  @override
  ReportModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ReportModel(
      id: fields[0] as String?,
      reportCategoryId: fields[1] as String?,
      reportTypeId: fields[2] as String?,
      alertLevels: fields[3] as String?,
      phoneNumber: fields[4] as String?,
      email: fields[5] as String?,
      website: fields[6] as String?,
      description: fields[7] as String?,
      createdAt: fields[8] as DateTime?,
      updatedAt: fields[9] as DateTime?,
      isSynced: fields[10] as bool,
      screenshotPaths: (fields[11] as List).cast<String>(),
      documentPaths: (fields[12] as List).cast<String>(),
      name: fields[13] as String?,
      keycloakUserId: fields[14] as String?,
      deviceTypeId: fields[15] as String?,
      detectTypeId: fields[16] as String?,
      operatingSystemName: fields[17] as String?,
      severity: fields[18] as String?,
      status: fields[19] as String?,
      categoryName: fields[20] as String?,
      typeName: fields[21] as String?,
      deviceTypeName: fields[22] as String?,
      detectTypeName: fields[23] as String?,
      operatingSystemNameValue: fields[24] as String?,
      metadata: (fields[25] as Map?)?.cast<String, dynamic>(),
      tags: (fields[26] as List).cast<String>(),
      userId: fields[27] as String?,
      userName: fields[28] as String?,
      userEmail: fields[29] as String?,
      priority: fields[30] as int?,
      location: fields[31] as String?,
      ipAddress: fields[32] as String?,
      userAgent: fields[33] as String?,
      additionalData: (fields[34] as Map?)?.cast<String, dynamic>(),
    );
  }

  @override
  void write(BinaryWriter writer, ReportModel obj) {
    writer
      ..writeByte(35)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.reportCategoryId)
      ..writeByte(2)
      ..write(obj.reportTypeId)
      ..writeByte(3)
      ..write(obj.alertLevels)
      ..writeByte(4)
      ..write(obj.phoneNumber)
      ..writeByte(5)
      ..write(obj.email)
      ..writeByte(6)
      ..write(obj.website)
      ..writeByte(7)
      ..write(obj.description)
      ..writeByte(8)
      ..write(obj.createdAt)
      ..writeByte(9)
      ..write(obj.updatedAt)
      ..writeByte(10)
      ..write(obj.isSynced)
      ..writeByte(11)
      ..write(obj.screenshotPaths)
      ..writeByte(12)
      ..write(obj.documentPaths)
      ..writeByte(13)
      ..write(obj.name)
      ..writeByte(14)
      ..write(obj.keycloakUserId)
      ..writeByte(15)
      ..write(obj.deviceTypeId)
      ..writeByte(16)
      ..write(obj.detectTypeId)
      ..writeByte(17)
      ..write(obj.operatingSystemName)
      ..writeByte(18)
      ..write(obj.severity)
      ..writeByte(19)
      ..write(obj.status)
      ..writeByte(20)
      ..write(obj.categoryName)
      ..writeByte(21)
      ..write(obj.typeName)
      ..writeByte(22)
      ..write(obj.deviceTypeName)
      ..writeByte(23)
      ..write(obj.detectTypeName)
      ..writeByte(24)
      ..write(obj.operatingSystemNameValue)
      ..writeByte(25)
      ..write(obj.metadata)
      ..writeByte(26)
      ..write(obj.tags)
      ..writeByte(27)
      ..write(obj.userId)
      ..writeByte(28)
      ..write(obj.userName)
      ..writeByte(29)
      ..write(obj.userEmail)
      ..writeByte(30)
      ..write(obj.priority)
      ..writeByte(31)
      ..write(obj.location)
      ..writeByte(32)
      ..write(obj.ipAddress)
      ..writeByte(33)
      ..write(obj.userAgent)
      ..writeByte(34)
      ..write(obj.additionalData);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReportModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
