// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'doc_document.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class DocDocumentAdapter extends TypeAdapter<DocDocument> {
  @override
  final int typeId = 2;

  @override
  DocDocument read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return DocDocument(
      id: fields[0] as String,
      groupId: fields[1] as String,
      name: fields[2] as String,
      description: fields[3] as String?,
      filePath: fields[4] as String,
      mimeType: fields[5] as String?,
      fileSize: fields[6] as int?,
      createdAt: fields[7] as DateTime,
      updatedAt: fields[8] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, DocDocument obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.groupId)
      ..writeByte(2)
      ..write(obj.name)
      ..writeByte(3)
      ..write(obj.description)
      ..writeByte(4)
      ..write(obj.filePath)
      ..writeByte(5)
      ..write(obj.mimeType)
      ..writeByte(6)
      ..write(obj.fileSize)
      ..writeByte(7)
      ..write(obj.createdAt)
      ..writeByte(8)
      ..write(obj.updatedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DocDocumentAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
