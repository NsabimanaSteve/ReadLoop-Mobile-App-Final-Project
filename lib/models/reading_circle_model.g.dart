// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'reading_circle_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ReadingCircleAdapter extends TypeAdapter<ReadingCircle> {
  @override
  final int typeId = 2;

  @override
  ReadingCircle read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ReadingCircle(
      id: fields[0] as String,
      name: fields[1] as String,
      description: fields[2] as String,
      creatorId: fields[3] as String,
      bookId: fields[4] as String,
      bookTitle: fields[5] as String,
      bookCoverUrl: fields[6] as String?,
      genre: fields[7] as String,
      memberIds: (fields[8] as List).cast<String>(),
      latitude: fields[9] as double?,
      longitude: fields[10] as double?,
      locationName: fields[11] as String?,
      isPublic: fields[12] as bool,
      maxMembers: fields[13] as int,
      createdAt: fields[14] as DateTime?,
      lastActivity: fields[15] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, ReadingCircle obj) {
    writer
      ..writeByte(16)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.description)
      ..writeByte(3)
      ..write(obj.creatorId)
      ..writeByte(4)
      ..write(obj.bookId)
      ..writeByte(5)
      ..write(obj.bookTitle)
      ..writeByte(6)
      ..write(obj.bookCoverUrl)
      ..writeByte(7)
      ..write(obj.genre)
      ..writeByte(8)
      ..write(obj.memberIds)
      ..writeByte(9)
      ..write(obj.latitude)
      ..writeByte(10)
      ..write(obj.longitude)
      ..writeByte(11)
      ..write(obj.locationName)
      ..writeByte(12)
      ..write(obj.isPublic)
      ..writeByte(13)
      ..write(obj.maxMembers)
      ..writeByte(14)
      ..write(obj.createdAt)
      ..writeByte(15)
      ..write(obj.lastActivity);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReadingCircleAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
