// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'discussion_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class DiscussionAdapter extends TypeAdapter<Discussion> {
  @override
  final int typeId = 3;

  @override
  Discussion read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Discussion(
      id: fields[0] as String,
      circleId: fields[1] as String,
      bookId: fields[2] as String,
      chapterNumber: fields[3] as int?,
      title: fields[4] as String,
      content: fields[5] as String,
      authorId: fields[6] as String,
      authorName: fields[7] as String,
      authorAvatar: fields[8] as String?,
      createdAt: fields[9] as DateTime?,
      lastActivity: fields[10] as DateTime?,
      likes: (fields[11] as List).cast<String>(),
      replyCount: fields[12] as int,
      tags: (fields[13] as List).cast<String>(),
    );
  }

  @override
  void write(BinaryWriter writer, Discussion obj) {
    writer
      ..writeByte(14)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.circleId)
      ..writeByte(2)
      ..write(obj.bookId)
      ..writeByte(3)
      ..write(obj.chapterNumber)
      ..writeByte(4)
      ..write(obj.title)
      ..writeByte(5)
      ..write(obj.content)
      ..writeByte(6)
      ..write(obj.authorId)
      ..writeByte(7)
      ..write(obj.authorName)
      ..writeByte(8)
      ..write(obj.authorAvatar)
      ..writeByte(9)
      ..write(obj.createdAt)
      ..writeByte(10)
      ..write(obj.lastActivity)
      ..writeByte(11)
      ..write(obj.likes)
      ..writeByte(12)
      ..write(obj.replyCount)
      ..writeByte(13)
      ..write(obj.tags);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DiscussionAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class ReplyAdapter extends TypeAdapter<Reply> {
  @override
  final int typeId = 4;

  @override
  Reply read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Reply(
      id: fields[0] as String,
      discussionId: fields[1] as String,
      content: fields[2] as String,
      authorId: fields[3] as String,
      authorName: fields[4] as String,
      authorAvatar: fields[5] as String?,
      createdAt: fields[6] as DateTime?,
      likes: (fields[7] as List).cast<String>(),
      parentReplyId: fields[8] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, Reply obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.discussionId)
      ..writeByte(2)
      ..write(obj.content)
      ..writeByte(3)
      ..write(obj.authorId)
      ..writeByte(4)
      ..write(obj.authorName)
      ..writeByte(5)
      ..write(obj.authorAvatar)
      ..writeByte(6)
      ..write(obj.createdAt)
      ..writeByte(7)
      ..write(obj.likes)
      ..writeByte(8)
      ..write(obj.parentReplyId);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReplyAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
