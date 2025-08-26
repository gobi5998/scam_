// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'file_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class FileModelAdapter extends TypeAdapter<FileModel> {
  @override
  final int typeId = 10;

  @override
  FileModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return FileModel(
      uploadPath: fields[0] as String?,
      s3Url: fields[1] as String?,
      s3Key: fields[2] as String?,
      originalName: fields[3] as String?,
      fileId: fields[4] as String?,
      url: fields[5] as String?,
      key: fields[6] as String?,
      fileName: fields[7] as String?,
      size: fields[8] as int?,
      contentType: fields[9] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, FileModel obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.uploadPath)
      ..writeByte(1)
      ..write(obj.s3Url)
      ..writeByte(2)
      ..write(obj.s3Key)
      ..writeByte(3)
      ..write(obj.originalName)
      ..writeByte(4)
      ..write(obj.fileId)
      ..writeByte(5)
      ..write(obj.url)
      ..writeByte(6)
      ..write(obj.key)
      ..writeByte(7)
      ..write(obj.fileName)
      ..writeByte(8)
      ..write(obj.size)
      ..writeByte(9)
      ..write(obj.contentType);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FileModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
