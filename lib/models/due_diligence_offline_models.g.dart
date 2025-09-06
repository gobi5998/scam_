// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'due_diligence_offline_models.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class OfflineDueDiligenceReportAdapter
    extends TypeAdapter<OfflineDueDiligenceReport> {
  @override
  final int typeId = 10;

  @override
  OfflineDueDiligenceReport read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return OfflineDueDiligenceReport(
      id: fields[0] as String,
      groupId: fields[1] as String,
      status: fields[2] as String,
      comments: fields[3] as String?,
      categories: (fields[4] as List).cast<OfflineCategory>(),
      createdAt: fields[5] as DateTime,
      updatedAt: fields[6] as DateTime,
      isOffline: fields[7] as bool,
      needsSync: fields[8] as bool,
      serverId: fields[9] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, OfflineDueDiligenceReport obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.groupId)
      ..writeByte(2)
      ..write(obj.status)
      ..writeByte(3)
      ..write(obj.comments)
      ..writeByte(4)
      ..write(obj.categories)
      ..writeByte(5)
      ..write(obj.createdAt)
      ..writeByte(6)
      ..write(obj.updatedAt)
      ..writeByte(7)
      ..write(obj.isOffline)
      ..writeByte(8)
      ..write(obj.needsSync)
      ..writeByte(9)
      ..write(obj.serverId);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OfflineDueDiligenceReportAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class OfflineCategoryAdapter extends TypeAdapter<OfflineCategory> {
  @override
  final int typeId = 11;

  @override
  OfflineCategory read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return OfflineCategory(
      id: fields[0] as String,
      name: fields[1] as String,
      label: fields[2] as String,
      subcategories: (fields[3] as List).cast<OfflineSubcategory>(),
    );
  }

  @override
  void write(BinaryWriter writer, OfflineCategory obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.label)
      ..writeByte(3)
      ..write(obj.subcategories);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OfflineCategoryAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class OfflineSubcategoryAdapter extends TypeAdapter<OfflineSubcategory> {
  @override
  final int typeId = 12;

  @override
  OfflineSubcategory read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return OfflineSubcategory(
      id: fields[0] as String,
      name: fields[1] as String,
      label: fields[2] as String,
      files: (fields[3] as List).cast<OfflineFile>(),
    );
  }

  @override
  void write(BinaryWriter writer, OfflineSubcategory obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.label)
      ..writeByte(3)
      ..write(obj.files);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OfflineSubcategoryAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class OfflineFileAdapter extends TypeAdapter<OfflineFile> {
  @override
  final int typeId = 13;

  @override
  OfflineFile read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return OfflineFile(
      id: fields[0] as String,
      name: fields[1] as String,
      type: fields[2] as String,
      size: fields[3] as int,
      url: fields[4] as String?,
      localPath: fields[5] as String?,
      comments: fields[6] as String?,
      uploadTime: fields[7] as DateTime,
      isOffline: fields[8] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, OfflineFile obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.type)
      ..writeByte(3)
      ..write(obj.size)
      ..writeByte(4)
      ..write(obj.url)
      ..writeByte(5)
      ..write(obj.localPath)
      ..writeByte(6)
      ..write(obj.comments)
      ..writeByte(7)
      ..write(obj.uploadTime)
      ..writeByte(8)
      ..write(obj.isOffline);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OfflineFileAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class OfflineSyncQueueAdapter extends TypeAdapter<OfflineSyncQueue> {
  @override
  final int typeId = 14;

  @override
  OfflineSyncQueue read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return OfflineSyncQueue(
      id: fields[0] as String,
      action: fields[1] as String,
      reportId: fields[2] as String,
      data: (fields[3] as Map).cast<String, dynamic>(),
      createdAt: fields[4] as DateTime,
      retryCount: fields[5] as int,
      error: fields[6] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, OfflineSyncQueue obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.action)
      ..writeByte(2)
      ..write(obj.reportId)
      ..writeByte(3)
      ..write(obj.data)
      ..writeByte(4)
      ..write(obj.createdAt)
      ..writeByte(5)
      ..write(obj.retryCount)
      ..writeByte(6)
      ..write(obj.error);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OfflineSyncQueueAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
