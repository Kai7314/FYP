class InactivityRules {
  const InactivityRules._();

  static const int minimumThresholdHours = 24;
  static const int maximumThresholdHours = 168;
  static const int defaultThresholdHours = 24;

  static int normalizeThresholdHours(Object? value) {
    final parsed = value is int
        ? value
        : int.tryParse(value?.toString().trim() ?? '');
    return (parsed ?? defaultThresholdHours)
        .clamp(minimumThresholdHours, maximumThresholdHours)
        .toInt();
  }

  static bool isValidThresholdHours(int value) =>
      value >= minimumThresholdHours && value <= maximumThresholdHours;
}
