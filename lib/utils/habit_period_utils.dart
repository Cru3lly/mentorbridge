import 'package:intl/intl.dart';

class HabitPeriodUtils {
  /// Generates the correct dateKey based on habit period
  static String generateDateKey(DateTime date, String goalPeriod) {
    switch (goalPeriod.toLowerCase()) {
      case 'daily':
        return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      
      case 'weekly':
        // Get week of year (ISO 8601)
        final weekOfYear = _getWeekOfYear(date);
        return '${date.year}-W${weekOfYear.toString().padLeft(2, '0')}';
      
      case 'monthly':
        return '${date.year}-${date.month.toString().padLeft(2, '0')}';
      
      default:
        return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    }
  }

  /// Gets the week number of the year (ISO 8601)
  static int _getWeekOfYear(DateTime date) {
    // Find the first Thursday of the year
    final jan4 = DateTime(date.year, 1, 4);
    final firstThursday = jan4.subtract(Duration(days: jan4.weekday - 4));
    
    // Calculate weeks from first Thursday
    final difference = date.difference(firstThursday).inDays;
    return (difference / 7).floor() + 1;
  }

  /// Checks if a habit should be shown today based on taskDays
  static bool shouldShowHabitToday(String taskDays, DateTime date) {
    switch (taskDays.toLowerCase()) {
      case 'every day':
        return true;
      
      case 'weekdays':
        return date.weekday >= 1 && date.weekday <= 5; // Monday to Friday
      
      case 'weekends':
        return date.weekday == 6 || date.weekday == 7; // Saturday, Sunday
      
      case 'custom':
        // TODO: Implement custom days logic
        return true;
      
      default:
        return true;
    }
  }

  /// Checks if current time is within the specified time range
  static bool isWithinTimeRange(String timeRange) {
    final now = DateTime.now();
    final currentHour = now.hour;

    switch (timeRange.toLowerCase()) {
      case 'anytime':
        return true;
      
      case 'morning':
        return currentHour >= 6 && currentHour < 12; // 6 AM - 12 PM
      
      case 'afternoon':
        return currentHour >= 12 && currentHour < 18; // 12 PM - 6 PM
      
      case 'evening':
        return currentHour >= 18 && currentHour <= 23; // 6 PM - 11 PM
      
      default:
        return true;
    }
  }

  /// Gets the display text for the current period
  static String getPeriodDisplayText(String goalPeriod, DateTime date) {
    switch (goalPeriod.toLowerCase()) {
      case 'daily':
        return DateFormat('EEEE, MMM d').format(date);
      
      case 'weekly':
        final weekStart = date.subtract(Duration(days: date.weekday - 1));
        final weekEnd = weekStart.add(const Duration(days: 6));
        return 'Week ${_getWeekOfYear(date)} (${DateFormat('MMM d').format(weekStart)} - ${DateFormat('MMM d').format(weekEnd)})';
      
      case 'monthly':
        return DateFormat('MMMM yyyy').format(date);
      
      default:
        return DateFormat('MMM d, yyyy').format(date);
    }
  }

  /// Calculates progress percentage for the period
  static double calculatePeriodProgress(String goalPeriod, DateTime startDate, DateTime currentDate) {
    switch (goalPeriod.toLowerCase()) {
      case 'daily':
        return 1.0; // Always 100% for daily (single day)
      
      case 'weekly':
        final weekStart = currentDate.subtract(Duration(days: currentDate.weekday - 1));
        final daysPassed = currentDate.difference(weekStart).inDays + 1;
        return (daysPassed / 7.0).clamp(0.0, 1.0);
      
      case 'monthly':
        final monthStart = DateTime(currentDate.year, currentDate.month, 1);
        final monthEnd = DateTime(currentDate.year, currentDate.month + 1, 0);
        final daysPassed = currentDate.difference(monthStart).inDays + 1;
        final totalDays = monthEnd.day;
        return (daysPassed / totalDays).clamp(0.0, 1.0);
      
      default:
        return 1.0;
    }
  }
}
