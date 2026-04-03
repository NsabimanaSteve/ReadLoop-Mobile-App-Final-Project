// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class UserModelAdapter extends TypeAdapter<UserModel> {
  @override
  final int typeId = 5;

  @override
  UserModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return UserModel(
      id: fields[0] as String,
      email: fields[1] as String,
      displayName: fields[2] as String,
      avatarUrl: fields[3] as String?,
      bio: fields[4] as String?,
      favoriteGenres: (fields[5] as List).cast<String>(),
      readingGoals: (fields[6] as List).cast<String>(),
      dailyReadingGoal: fields[7] as int?,
      weeklyReadingGoal: fields[8] as int?,
      currentStreak: fields[9] as int,
      longestStreak: fields[10] as int,
      booksRead: fields[11] as int,
      pagesRead: fields[12] as int,
      createdAt: fields[13] as DateTime?,
      lastActive: fields[14] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, UserModel obj) {
    writer
      ..writeByte(15)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.email)
      ..writeByte(2)
      ..write(obj.displayName)
      ..writeByte(3)
      ..write(obj.avatarUrl)
      ..writeByte(4)
      ..write(obj.bio)
      ..writeByte(5)
      ..write(obj.favoriteGenres)
      ..writeByte(6)
      ..write(obj.readingGoals)
      ..writeByte(7)
      ..write(obj.dailyReadingGoal)
      ..writeByte(8)
      ..write(obj.weeklyReadingGoal)
      ..writeByte(9)
      ..write(obj.currentStreak)
      ..writeByte(10)
      ..write(obj.longestStreak)
      ..writeByte(11)
      ..write(obj.booksRead)
      ..writeByte(12)
      ..write(obj.pagesRead)
      ..writeByte(13)
      ..write(obj.createdAt)
      ..writeByte(14)
      ..write(obj.lastActive);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class ReadingGoalAdapter extends TypeAdapter<ReadingGoal> {
  @override
  final int typeId = 6;

  @override
  ReadingGoal read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ReadingGoal(
      id: fields[0] as String,
      userId: fields[1] as String,
      type: fields[2] as GoalType,
      target: fields[3] as int,
      currentProgress: fields[4] as int,
      startDate: fields[5] as DateTime,
      endDate: fields[6] as DateTime,
      isActive: fields[7] as bool,
      createdAt: fields[8] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, ReadingGoal obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.userId)
      ..writeByte(2)
      ..write(obj.type)
      ..writeByte(3)
      ..write(obj.target)
      ..writeByte(4)
      ..write(obj.currentProgress)
      ..writeByte(5)
      ..write(obj.startDate)
      ..writeByte(6)
      ..write(obj.endDate)
      ..writeByte(7)
      ..write(obj.isActive)
      ..writeByte(8)
      ..write(obj.createdAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReadingGoalAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class GoalTypeAdapter extends TypeAdapter<GoalType> {
  @override
  final int typeId = 7;

  @override
  GoalType read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return GoalType.dailyPages;
      case 1:
        return GoalType.weeklyPages;
      case 2:
        return GoalType.monthlyBooks;
      case 3:
        return GoalType.yearlyBooks;
      default:
        return GoalType.dailyPages;
    }
  }

  @override
  void write(BinaryWriter writer, GoalType obj) {
    switch (obj) {
      case GoalType.dailyPages:
        writer.writeByte(0);
        break;
      case GoalType.weeklyPages:
        writer.writeByte(1);
        break;
      case GoalType.monthlyBooks:
        writer.writeByte(2);
        break;
      case GoalType.yearlyBooks:
        writer.writeByte(3);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GoalTypeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
