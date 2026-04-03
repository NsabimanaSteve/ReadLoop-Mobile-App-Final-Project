import '../models/reading_session.dart';

class ReadingStatsService {
  static int calculateCurrentStreak(List<ReadingSession> sessions) {
    if (sessions.isEmpty) return 0;
    
    final now = DateTime.now();
    int streak = 0;
    DateTime currentDate = now;
    
    for (int i = 0; i < 365; i++) {
      final dayStart = DateTime(currentDate.year, currentDate.month, currentDate.day);
      final dayEnd = dayStart.add(const Duration(days: 1));
      
      final hasReadingOnDay = sessions.any((session) => 
        session.startTime.isAfter(dayStart) && session.startTime.isBefore(dayEnd)
      );
      
      if (hasReadingOnDay) {
        streak++;
      } else if (i > 0) {
        break;
      }
      
      currentDate = currentDate.subtract(const Duration(days: 1));
    }
    
    return streak;
  }
  
  static int calculatePagesToday(List<ReadingSession> sessions) {
    final today = DateTime.now();
    final dayStart = DateTime(today.year, today.month, today.day);
    final dayEnd = dayStart.add(const Duration(days: 1));
    
    return sessions
        .where((session) => 
            session.startTime.isAfter(dayStart) && session.startTime.isBefore(dayEnd))
        .fold(0, (sum, session) => sum + session.pagesRead);
  }
  
  static int calculatePagesThisWeek(List<ReadingSession> sessions) {
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final weekStartDay = DateTime(weekStart.year, weekStart.month, weekStart.day);
    
    return sessions
        .where((session) => session.startTime.isAfter(weekStartDay))
        .fold(0, (sum, session) => sum + session.pagesRead);
  }
  
  static double calculateDailyProgress(int pagesReadToday, int dailyGoal) {
    if (dailyGoal == 0) return 0.0;
    return (pagesReadToday / dailyGoal).clamp(0.0, 2.0);
  }
  
  static double calculateWeeklyProgress(int pagesReadThisWeek, int weeklyGoal) {
    if (weeklyGoal == 0) return 0.0;
    return (pagesReadThisWeek / weeklyGoal).clamp(0.0, 2.0);
  }
}
