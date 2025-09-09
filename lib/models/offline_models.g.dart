// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'offline_models.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class OfflineDueDiligenceReportAdapter
    extends TypeAdapter<OfflineDueDiligenceReport> {
  @override
  final int typeId = 20;

  @override
  OfflineDueDiligenceReport read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return OfflineDueDiligenceReport(
      id: fields[0] as String,
      groupId: fields[1] as String,
      categories: (fields[2] as List).cast<OfflineCategory>(),
      status: fields[3] as String,
      comments: fields[4] as String,
      createdAt: fields[5] as DateTime,
      updatedAt: fields[6] as DateTime,
      isSynced: fields[7] as bool,
      submissionId: fields[8] as String?,
      submittedAt: fields[9] as DateTime?,
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
      ..write(obj.categories)
      ..writeByte(3)
      ..write(obj.status)
      ..writeByte(4)
      ..write(obj.comments)
      ..writeByte(5)
      ..write(obj.createdAt)
      ..writeByte(6)
      ..write(obj.updatedAt)
      ..writeByte(7)
      ..write(obj.isSynced)
      ..writeByte(8)
      ..write(obj.submissionId)
      ..writeByte(9)
      ..write(obj.submittedAt);
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
  final int typeId = 21;

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
      status: fields[4] as String,
    );
  }

  @override
  void write(BinaryWriter writer, OfflineCategory obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.label)
      ..writeByte(3)
      ..write(obj.subcategories)
      ..writeByte(4)
      ..write(obj.status);
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
  final int typeId = 22;

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
      status: fields[4] as String,
    );
  }

  @override
  void write(BinaryWriter writer, OfflineSubcategory obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.label)
      ..writeByte(3)
      ..write(obj.files)
      ..writeByte(4)
      ..write(obj.status);
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
  final int typeId = 23;

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
      localPath: fields[4] as String?,
      url: fields[5] as String?,
      comments: fields[6] as String,
      uploadTime: fields[7] as DateTime,
      isUploaded: fields[8] as bool,
      documentId: fields[9] as String?,
      status: fields[10] as String,
    );
  }

  @override
  void write(BinaryWriter writer, OfflineFile obj) {
    writer
      ..writeByte(11)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.type)
      ..writeByte(3)
      ..write(obj.size)
      ..writeByte(4)
      ..write(obj.localPath)
      ..writeByte(5)
      ..write(obj.url)
      ..writeByte(6)
      ..write(obj.comments)
      ..writeByte(7)
      ..write(obj.uploadTime)
      ..writeByte(8)
      ..write(obj.isUploaded)
      ..writeByte(9)
      ..write(obj.documentId)
      ..writeByte(10)
      ..write(obj.status);
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

class OfflineCategoryTemplateAdapter
    extends TypeAdapter<OfflineCategoryTemplate> {
  @override
  final int typeId = 24;

  @override
  OfflineCategoryTemplate read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return OfflineCategoryTemplate(
      id: fields[0] as String,
      name: fields[1] as String,
      label: fields[2] as String,
      description: fields[3] as String,
      order: fields[4] as int,
      isActive: fields[5] as bool,
      subcategories: (fields[6] as List).cast<OfflineSubcategoryTemplate>(),
      lastUpdated: fields[7] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, OfflineCategoryTemplate obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.label)
      ..writeByte(3)
      ..write(obj.description)
      ..writeByte(4)
      ..write(obj.order)
      ..writeByte(5)
      ..write(obj.isActive)
      ..writeByte(6)
      ..write(obj.subcategories)
      ..writeByte(7)
      ..write(obj.lastUpdated);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OfflineCategoryTemplateAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class OfflineSubcategoryTemplateAdapter
    extends TypeAdapter<OfflineSubcategoryTemplate> {
  @override
  final int typeId = 25;

  @override
  OfflineSubcategoryTemplate read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return OfflineSubcategoryTemplate(
      id: fields[0] as String,
      name: fields[1] as String,
      label: fields[2] as String,
      type: fields[3] as String,
      required: fields[4] as bool,
      options: (fields[5] as List).cast<dynamic>(),
      order: fields[6] as int,
      categoryId: fields[7] as String,
      isActive: fields[8] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, OfflineSubcategoryTemplate obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.label)
      ..writeByte(3)
      ..write(obj.type)
      ..writeByte(4)
      ..write(obj.required)
      ..writeByte(5)
      ..write(obj.options)
      ..writeByte(6)
      ..write(obj.order)
      ..writeByte(7)
      ..write(obj.categoryId)
      ..writeByte(8)
      ..write(obj.isActive);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OfflineSubcategoryTemplateAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class OfflineUserDataAdapter extends TypeAdapter<OfflineUserData> {
  @override
  final int typeId = 26;

  @override
  OfflineUserData read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return OfflineUserData(
      userId: fields[0] as String,
      groupId: fields[1] as String,
      lastUpdated: fields[2] as DateTime,
      additionalData: (fields[3] as Map).cast<String, dynamic>(),
    );
  }

  @override
  void write(BinaryWriter writer, OfflineUserData obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.userId)
      ..writeByte(1)
      ..write(obj.groupId)
      ..writeByte(2)
      ..write(obj.lastUpdated)
      ..writeByte(3)
      ..write(obj.additionalData);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OfflineUserDataAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
