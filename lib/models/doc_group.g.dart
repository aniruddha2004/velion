// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'doc_group.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class DocGroupAdapter extends TypeAdapter<DocGroup> {
  @override
  final int typeId = 1;

  @override
  DocGroup read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return DocGroup(
      id: fields[0] as String,
      name: fields[1] as String,
      description: fields[2] as String?,
      createdAt: fields[3] as DateTime,
      updatedAt: fields[4] as DateTime,
      documentIds: (fields[5] as List).cast<String>(),
    );
  }

  @override
  void write(BinaryWriter writer, DocGroup obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.description)
      ..writeByte(3)
      ..write(obj.createdAt)
      ..writeByte(4)
      ..write(obj.updatedAt)
      ..writeByte(5)
      ..write(obj.documentIds);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DocGroupAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
