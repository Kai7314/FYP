import 'package:intl/intl.dart';

class AppDateUtils {
  const AppDateUtils._();

  static String shortDate(DateTime value) => DateFormat('d MMM yyyy').format(value);

  static String time(DateTime value) => DateFormat('h:mm a').format(value);

  static bool isSameLocalDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}
