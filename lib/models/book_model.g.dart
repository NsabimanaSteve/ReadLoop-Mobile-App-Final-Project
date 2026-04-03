// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'book_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class BookModelAdapter extends TypeAdapter<BookModel> {
  @override
  final int typeId = 0;

  @override
  BookModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return BookModel(
      id: fields[0] as String,
      title: fields[1] as String,
      author: fields[2] as String,
      isbn: fields[3] as String?,
      coverUrl: fields[4] as String?,
      description: fields[5] as String?,
      genre: fields[6] as String?,
      pageCount: fields[7] as int?,
      publishedDate: fields[8] as String?,
      status: fields[9] as BookStatus,
      currentPage: fields[10] as int?,
      startedReading: fields[11] as DateTime?,
      finishedReading: fields[12] as DateTime?,
      rating: fields[13] as double?,
      readingLists: (fields[14] as List).cast<String>(),
      createdAt: fields[15] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, BookModel obj) {
    writer
      ..writeByte(16)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.author)
      ..writeByte(3)
      ..write(obj.isbn)
      ..writeByte(4)
      ..write(obj.coverUrl)
      ..writeByte(5)
      ..write(obj.description)
      ..writeByte(6)
      ..write(obj.genre)
      ..writeByte(7)
      ..write(obj.pageCount)
      ..writeByte(8)
      ..write(obj.publishedDate)
      ..writeByte(9)
      ..write(obj.status)
      ..writeByte(10)
      ..write(obj.currentPage)
      ..writeByte(11)
      ..write(obj.startedReading)
      ..writeByte(12)
      ..write(obj.finishedReading)
      ..writeByte(13)
      ..write(obj.rating)
      ..writeByte(14)
      ..write(obj.readingLists)
      ..writeByte(15)
      ..write(obj.createdAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BookModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class BookStatusAdapter extends TypeAdapter<BookStatus> {
  @override
  final int typeId = 1;

  @override
  BookStatus read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return BookStatus.wantToRead;
      case 1:
        return BookStatus.currentlyReading;
      case 2:
        return BookStatus.finished;
      default:
        return BookStatus.wantToRead;
    }
  }

  @override
  void write(BinaryWriter writer, BookStatus obj) {
    switch (obj) {
      case BookStatus.wantToRead:
        writer.writeByte(0);
        break;
      case BookStatus.currentlyReading:
        writer.writeByte(1);
        break;
      case BookStatus.finished:
        writer.writeByte(2);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BookStatusAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
