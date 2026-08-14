import 'package:intl/intl.dart';
import 'package:timeago/timeago.dart' as timeago;

extension MyDateTime on DateTime {
  static DateTime? parse(String? date) {
    if (date == null || date.isEmpty) {
      return null;
    }
    return DateTime.parse(date);
  }

  bool isMoreThanMinute(DateTime b) {
    return difference(b).abs() > const Duration(minutes: 1);
  }

  static List<DateTime> generateYearMonthRange({int yearsAhead = 5}) {
    final now = DateTime.now();

    final start = DateTime(now.year, now.month);
    final end = DateTime(now.year + yearsAhead, now.month);

    final List<DateTime> result = [];

    var current = start;
    while (!current.isAfter(end)) {
      result.add(current);
      current = DateTime(current.year, current.month + 1);
    }

    return result;
  }

  String get timeAgo => timeago.format(this, locale: 'ar');

  String toIsoWithOffset() {
    final offset = timeZoneOffset;

    final sign = offset.isNegative ? '-' : '+';
    final hours = offset.inHours.abs().toString().padLeft(2, '0');
    final minutes = (offset.inMinutes.abs() % 60).toString().padLeft(2, '0');

    final offsetString = '$sign$hours:$minutes';

    return toIso8601String() + offsetString;
  }

  bool sameDay(DateTime b) =>
      year == b.year && month == b.month && day == b.day;

  DateTime get dateOnly => DateTime(year, month, day);

  bool isInBetween(DateTime first, DateTime end) {
    return (first.dateOnly.isBefore(dateOnly) &&
            end.dateOnly.isAfter(dateOnly)) ||
        first.dateOnly == dateOnly ||
        end.dateOnly == dateOnly;
  }

  String get formatYMD {
    return DateFormat('MMM dd, yyyy').format(this);
  }

  String get formatYYYYMMDD {
    return DateFormat('yyyy-MM-dd').format(this);
  }

  String get formatYM {
    return DateFormat('MM - yyyy').format(this);
  }

  String get formaHHMM {
    return DateFormat('HH:mm').format(this);
  }

  String get formatYMDHHMM {
    return DateFormat('MMM dd, yyyy - HH:mm').format(this);
  }

  String get arabicDayName {
    const days = {
      DateTime.monday: 'الاثنين',
      DateTime.tuesday: 'الثلاثاء',
      DateTime.wednesday: 'الأربعاء',
      DateTime.thursday: 'الخميس',
      DateTime.friday: 'الجمعة',
      DateTime.saturday: 'السبت',
      DateTime.sunday: 'الأحد',
    };

    return days[weekday] ?? '';
  }
}

// Simple one-line conversion functions
String toEnglishDay(String arabicDay) {
  const days = {
    'الأحد': 'sunday',
    'الإثنين': 'monday',
    'الثلاثاء': 'tuesday',
    'الأربعاء': 'wednesday',
    'الخميس': 'thursday',
    'الجمعة': 'friday',
    'السبت': 'saturday',
  };
  return days[arabicDay] ?? arabicDay.toLowerCase();
}

String toArabicDay(String englishDay) {
  const days = {
    'Sunday': 'الأحد',
    'Monday': 'الإثنين',
    'Tuesday': 'الثلاثاء',
    'Wednesday': 'الأربعاء',
    'Thursday': 'الخميس',
    'Friday': 'الجمعة',
    'Saturday': 'السبت',
  };
  return days[englishDay] ?? englishDay;
}

/// Returns the nearest upcoming delivery date for the given English weekday
/// names (e.g. ["Monday", "Wednesday"]). Returns today if today is a delivery
/// day; wraps into next week if all days this week have passed.
DateTime? nextDeliveryDate(List<String>? deliveryDays) {
  if (deliveryDays == null || deliveryDays.isEmpty) return null;

  // Dart weekday: Mon=1 … Sun=7
  const dayMap = {
    'Monday': 1,
    'Tuesday': 2,
    'Wednesday': 3,
    'Thursday': 4,
    'Friday': 5,
    'Saturday': 6,
    'Sunday': 7,
  };

  final weekdays = deliveryDays.map((d) => dayMap[d]).whereType<int>().toSet();

  if (weekdays.isEmpty) return null;

  final now = DateTime.now();
  final today = now.dateOnly;
  // After 6 PM the warehouse has closed; tomorrow's order window is gone,
  // so the earliest reachable delivery is the day after tomorrow.
  final startOffset = now.hour >= 18 ? 2 : 1;
  for (int offset = startOffset; offset < startOffset + 7; offset++) {
    final candidate = today.add(Duration(days: offset));
    if (weekdays.contains(candidate.weekday)) return candidate;
  }
  return null;
}
