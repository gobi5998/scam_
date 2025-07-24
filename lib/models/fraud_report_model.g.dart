// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'fraud_report_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class FraudReportModelAdapter extends TypeAdapter<FraudReportModel> {
  @override
  final int typeId = 1;

  @override
  FraudReportModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return FraudReportModel(
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
    );
  }

  @override
  void write(BinaryWriter writer, FraudReportModel obj) {
    writer
      ..writeByte(15)
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
      ..write(obj.keycloakUserId);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FraudReportModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
