import 'package:flutter/material.dart';

class ReadingSession {
  String id;
  String userId;
  String bookId;
  DateTime startTime;
  DateTime? endTime;
  int pagesRead;
  int minutesRead;
  bool completed;

  ReadingSession({
    required this.id,
    required this.userId,
    required this.bookId,
    required this.startTime,
    this.endTime,
    this.pagesRead = 0,
    this.minutesRead = 0,
    this.completed = false,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'userId': userId,
    'bookId': bookId,
    'startTime': startTime.toIso8601String(),
    'endTime': endTime?.toIso8601String(),
    'pagesRead': pagesRead,
    'minutesRead': minutesRead,
    'completed': completed,
  };

  factory ReadingSession.fromJson(Map<String, dynamic> json) => ReadingSession(
    id: json['id'].toString(),
    userId: json['userId'].toString(),
    bookId: json['bookId'].toString(),
    startTime: DateTime.parse(json['startTime']),
    endTime: json['endTime'] != null ? DateTime.parse(json['endTime']) : null,
    pagesRead: json['pagesRead'] ?? 0,
    minutesRead: json['minutesRead'] ?? 0,
    completed: json['completed'] ?? false,
  );
}

class ReadingGoal {
  int dailyPages;
  int weeklyPages;
  int dailyMinutes;
  int weeklyMinutes;

  ReadingGoal({
    this.dailyPages = 30,
    this.weeklyPages = 210,
    this.dailyMinutes = 60,
    this.weeklyMinutes = 420,
  });

  Map<String, dynamic> toJson() => {
    'dailyPages': dailyPages,
    'weeklyPages': weeklyPages,
    'dailyMinutes': dailyMinutes,
    'weeklyMinutes': weeklyMinutes,
  };

  factory ReadingGoal.fromJson(Map<String, dynamic> json) => ReadingGoal(
    dailyPages: json['dailyPages'] ?? 30,
    weeklyPages: json['weeklyPages'] ?? 210,
    dailyMinutes: json['dailyMinutes'] ?? 60,
    weeklyMinutes: json['weeklyMinutes'] ?? 420,
  );
}
