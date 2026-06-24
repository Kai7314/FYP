class AppValidators {
  static const minPasswordLength = 8;
  static const maxPasswordLength = 64;
  static const maxDisplayNameLength = 50;
  static const maxPhoneDigits = 15;
  static const maxAddressLength = 200;

  static String normalizeSpaces(String value) {
    return value.trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  static String normalizePhone(String value) {
    final trimmed = value.trim();
    final hasPlus = trimmed.startsWith('+');
    final digits = trimmed.replaceAll(RegExp(r'\D'), '');
    return hasPlus ? '+$digits' : digits;
  }

  static String? email(String value) {
    final email = value.trim();
    final pattern = RegExp(
      r"^[A-Za-z0-9.!#$%&'*+/=?^_`{|}~-]+@[A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)+$",
    );
    if (email.isEmpty || !pattern.hasMatch(email)) {
      return 'Enter a valid email address.';
    }
    if (email.length > 254) return 'Email address is too long.';
    return null;
  }

  static String? displayName(String value) {
    final name = normalizeSpaces(value);
    if (name.length < 2) return 'Name must contain at least 2 characters.';
    if (name.length > maxDisplayNameLength) {
      return 'Name must not exceed $maxDisplayNameLength characters.';
    }
    if (!RegExp(r"^[A-Za-z][A-Za-z .'-]*$").hasMatch(name)) {
      return 'Use letters, spaces, apostrophes, hyphens, or periods only.';
    }
    return null;
  }

  static String? loginPassword(String value) {
    if (value.isEmpty) return 'Enter your password.';
    return null;
  }

  static String? registrationPassword(
    String value, {
    String? email,
    String? name,
  }) {
    if (value.length < minPasswordLength) {
      return 'Password must contain at least $minPasswordLength characters.';
    }
    if (value.length > maxPasswordLength) {
      return 'Password must not exceed $maxPasswordLength characters.';
    }
    if (RegExp(r'\s').hasMatch(value)) {
      return 'Password must not contain spaces.';
    }
    if (!RegExp(r'[A-Z]').hasMatch(value) ||
        !RegExp(r'[a-z]').hasMatch(value) ||
        !RegExp(r'[0-9]').hasMatch(value) ||
        !RegExp(r'[^A-Za-z0-9]').hasMatch(value)) {
      return 'Use uppercase, lowercase, number, and special character.';
    }
    final lowered = value.toLowerCase();
    final emailPrefix = email?.trim().split('@').first.toLowerCase();
    if (emailPrefix != null &&
        emailPrefix.length >= 3 &&
        lowered.contains(emailPrefix)) {
      return 'Password must not contain your email name.';
    }
    final normalizedName = normalizeSpaces(
      name ?? '',
    ).replaceAll(RegExp(r'[^A-Za-z]'), '').toLowerCase();
    if (normalizedName.length >= 3 && lowered.contains(normalizedName)) {
      return 'Password must not contain your name.';
    }
    return null;
  }

  static String? phone(String value, {bool required = true}) {
    final normalized = normalizePhone(value);
    final digits = normalized.replaceAll('+', '');
    if (digits.isEmpty && !required) return null;
    if (digits.length < 8 || digits.length > maxPhoneDigits) {
      return 'Phone number must contain 8 to $maxPhoneDigits digits.';
    }
    if (!RegExp(r'^\+?[0-9]+$').hasMatch(normalized)) {
      return 'Enter a valid phone number.';
    }
    return null;
  }

  static String? relationship(String value, {bool required = false}) {
    final relationship = normalizeSpaces(value);
    if (relationship.isEmpty) {
      return required ? 'Relationship is required.' : null;
    }
    if (relationship.length < 2 || relationship.length > 30) {
      return 'Relationship must contain 2 to 30 characters.';
    }
    return null;
  }

  static String? address(String value, {bool required = false}) {
    final address = normalizeSpaces(value);
    if (address.isEmpty) return required ? 'Address is required.' : null;
    if (address.length > maxAddressLength) {
      return 'Address must not exceed $maxAddressLength characters.';
    }
    return null;
  }

  static String? age(String value, {bool required = false}) {
    if (value.trim().isEmpty) return required ? 'Age is required.' : null;
    final age = int.tryParse(value.trim());
    if (age == null || age < 18 || age > 120) {
      return 'Age must be between 18 and 120.';
    }
    return null;
  }

  static String? bloodType(String value, {bool required = false}) {
    if (value.trim().isEmpty) {
      return required ? 'Blood type is required.' : null;
    }
    const allowed = {'A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'};
    if (!allowed.contains(value.trim().toUpperCase())) {
      return 'Use A+, A-, B+, B-, AB+, AB-, O+, or O-.';
    }
    return null;
  }

  static String? inactivityThreshold(String value) {
    final hours = int.tryParse(value.trim());
    if (hours == null || hours < 1 || hours > 168) {
      return 'Threshold must be between 1 and 168 hours.';
    }
    return null;
  }
}
