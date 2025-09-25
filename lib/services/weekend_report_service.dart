import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class WeekendReportService {
  static const List<String> _eligibleRoles = [
    'middleSchoolMentor',
    'highSchoolMentor'
  ];

  /// Check if the current user should see the weekend report popup
  static Future<bool> shouldShowWeekendReportPopup() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;

      // Check if user has eligible role
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!userDoc.exists) return false;

      final userData = userDoc.data()!;
      final userRole = userData['role'] as String?;

      if (userRole == null || !_eligibleRoles.contains(userRole)) {
        return false;
      }

      // Check if it's Friday, Saturday, or Sunday
      final now = DateTime.now();
      final weekday = now.weekday;
      if (weekday < 5 || weekday > 7) {
        // Monday=1, Sunday=7
        return false;
      }

      // Check if user has already submitted a report for this week
      final hasReportThisWeek = await _hasReportForCurrentWeek(user.uid);

      return !hasReportThisWeek;
    } catch (e) {
      print('Error checking weekend report popup: $e');
      return false;
    }
  }

  /// Check if user has already submitted a report for the current week
  static Future<bool> _hasReportForCurrentWeek(String userId) async {
    try {
      // Get the Friday of current week as the base key
      final now = DateTime.now();
      final currentWeekFriday = _getFridayOfWeek(now);
      final baseWeekKey = DateFormat('yyyy-MM-dd').format(currentWeekFriday);

      final reportsRef = FirebaseFirestore.instance
          .collection('weekendReports')
          .doc(userId)
          .collection('reports');

      // Check for any reports with this week's base key
      final existing = await reportsRef
          .where(FieldPath.documentId, isGreaterThanOrEqualTo: baseWeekKey)
          .where(FieldPath.documentId, isLessThan: '$baseWeekKey\uf8ff')
          .limit(1)
          .get();

      return existing.docs.isNotEmpty;
    } catch (e) {
      print('Error checking existing reports: $e');
      return false; // If error, show popup to be safe
    }
  }

  /// Get the Friday of the week containing the given date
  static DateTime _getFridayOfWeek(DateTime date) {
    final weekday = date.weekday;
    int daysToFriday;

    if (weekday <= 5) {
      // Monday to Friday
      daysToFriday = 5 - weekday;
    } else {
      // Saturday or Sunday
      daysToFriday = 5 + (7 - weekday);
    }

    return date.add(Duration(days: daysToFriday));
  }

  /// Mark that the popup was shown today (to avoid showing multiple times)
  static Future<void> markPopupShownToday() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
        'lastWeekendReportPopupShown': today,
      });
    } catch (e) {
      print('Error marking popup shown: $e');
    }
  }

  /// Check if popup was already shown today
  static Future<bool> wasPopupShownToday() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return true;

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!userDoc.exists) return false;

      final userData = userDoc.data()!;
      final lastShown = userData['lastWeekendReportPopupShown'] as String?;

      if (lastShown == null) return false;

      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      return lastShown == today;
    } catch (e) {
      print('Error checking popup shown today: $e');
      return false;
    }
  }
}
