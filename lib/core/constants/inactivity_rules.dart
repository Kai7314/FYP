class InactivityRules {
  const InactivityRules._();

  static const int minimumThresholdDays = 1;
  static const int maximumThresholdDays = 7;
  static const int defaultThresholdDays = 1;
  static const int minimumThresholdHours = 24;
  static const int maximumThresholdHours = 168;
  static const int defaultThresholdHours = 24;

  static int normalizeThresholdHours(Object? value) {
    final parsed = value is int
        ? value
        : int.tryParse(value?.toString().trim() ?? '');
    final clamped = (parsed ?? defaultThresholdHours)
        .clamp(minimumThresholdHours, maximumThresholdHours)
        .toInt();
    return ((clamped + 23) ~/ 24) * 24;
  }

  static bool isValidThresholdHours(int value) =>
      value >= minimumThresholdHours &&
      value <= maximumThresholdHours &&
      value % 24 == 0;

  static int normalizeThresholdDays(Object? value) {
    final parsed = value is int
        ? value
        : int.tryParse(value?.toString().trim() ?? '');
    return (parsed ?? defaultThresholdDays)
        .clamp(minimumThresholdDays, maximumThresholdDays)
        .toInt();
  }

  static bool isValidThresholdDays(int value) =>
      value >= minimumThresholdDays && value <= maximumThresholdDays;

  static int thresholdDaysFromHours(Object? value) =>
      normalizeThresholdHours(value) ~/ 24;

  static int thresholdHoursFromDays(Object? value) =>
      normalizeThresholdDays(value) * 24;

  static String dayLabelFromHours(Object? value) {
    final days = thresholdDaysFromHours(value);
    return '$days ${days == 1 ? 'day' : 'days'}';
  }
}
