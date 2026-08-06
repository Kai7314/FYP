import '../core/constants/inactivity_rules.dart';

class PhoneCountry {
  const PhoneCountry({
    required this.name,
    required this.isoCode,
    required this.dialCode,
    required this.minNationalDigits,
    required this.maxNationalDigits,
    required this.example,
  });

  final String name;
  final String isoCode;
  final String dialCode;
  final int minNationalDigits;
  final int maxNationalDigits;
  final String example;

  String get label => '$isoCode $dialCode';
}

class AppValidators {
  static const minPasswordLength = 8;
  static const maxPasswordLength = 64;
  static const maxDisplayNameLength = 100;
  static const maxPhoneDigits = 15;
  static const maxAddressLength = 200;
  static const emailVerificationCodeLength = 8;
  static const bloodTypes = [
    'A+',
    'A-',
    'B+',
    'B-',
    'AB+',
    'AB-',
    'O+',
    'O-',
  ];
  static const defaultPhoneCountry = PhoneCountry(
    name: 'Malaysia',
    isoCode: 'MY',
    dialCode: '+60',
    minNationalDigits: 8,
    maxNationalDigits: 10,
    example: '0123456789',
  );
  static const phoneCountries = [
    defaultPhoneCountry,
    PhoneCountry(
      name: 'Singapore',
      isoCode: 'SG',
      dialCode: '+65',
      minNationalDigits: 8,
      maxNationalDigits: 8,
      example: '81234567',
    ),
    PhoneCountry(
      name: 'Indonesia',
      isoCode: 'ID',
      dialCode: '+62',
      minNationalDigits: 8,
      maxNationalDigits: 12,
      example: '81234567890',
    ),
    PhoneCountry(
      name: 'Thailand',
      isoCode: 'TH',
      dialCode: '+66',
      minNationalDigits: 8,
      maxNationalDigits: 9,
      example: '812345678',
    ),
    PhoneCountry(
      name: 'Brunei',
      isoCode: 'BN',
      dialCode: '+673',
      minNationalDigits: 7,
      maxNationalDigits: 7,
      example: '7123456',
    ),
    PhoneCountry(
      name: 'Philippines',
      isoCode: 'PH',
      dialCode: '+63',
      minNationalDigits: 10,
      maxNationalDigits: 10,
      example: '9123456789',
    ),
    PhoneCountry(
      name: 'China',
      isoCode: 'CN',
      dialCode: '+86',
      minNationalDigits: 11,
      maxNationalDigits: 11,
      example: '13123456789',
    ),
    PhoneCountry(
      name: 'India',
      isoCode: 'IN',
      dialCode: '+91',
      minNationalDigits: 10,
      maxNationalDigits: 10,
      example: '9123456789',
    ),
    PhoneCountry(
      name: 'United States',
      isoCode: 'US',
      dialCode: '+1',
      minNationalDigits: 10,
      maxNationalDigits: 10,
      example: '4155552671',
    ),
    PhoneCountry(
      name: 'United Kingdom',
      isoCode: 'GB',
      dialCode: '+44',
      minNationalDigits: 9,
      maxNationalDigits: 10,
      example: '7400123456',
    ),
  ];

  static String normalizeSpaces(String value) {
    return value.trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  static String normalizePhone(String value) {
    final trimmed = value.trim();
    final hasPlus = trimmed.startsWith('+');
    final digits = trimmed.replaceAll(RegExp(r'\D'), '');
    return hasPlus ? '+$digits' : digits;
  }

  static PhoneCountry phoneCountryForDialCode(String dialCode) {
    return phoneCountries.firstWhere(
      (country) => country.dialCode == dialCode,
      orElse: () => defaultPhoneCountry,
    );
  }

  static PhoneCountry detectPhoneCountry(String value) {
    final normalized = normalizePhone(value);
    final digits = normalized.replaceAll('+', '');
    final sortedCountries = [...phoneCountries]
      ..sort((a, b) => b.dialCode.length.compareTo(a.dialCode.length));

    for (final country in sortedCountries) {
      final dialDigits = country.dialCode.replaceAll('+', '');
      if (normalized.startsWith(country.dialCode) ||
          digits.startsWith(dialDigits)) {
        return country;
      }
    }
    return defaultPhoneCountry;
  }

  static String localPhoneForCountry(String value, String dialCode) {
    final normalized = normalizePhone(value);
    if (normalized.isEmpty) return '';

    final country = phoneCountryForDialCode(dialCode);
    final dialDigits = country.dialCode.replaceAll('+', '');
    var digits = normalized.replaceAll('+', '');
    if (digits.startsWith(dialDigits)) {
      digits = digits.substring(dialDigits.length);
    }
    if (country.isoCode == defaultPhoneCountry.isoCode &&
        digits.startsWith('0')) {
      return digits;
    }
    return digits;
  }

  static String normalizePhoneWithCountry(String value, String dialCode) {
    final normalized = normalizePhone(value);
    if (normalized.isEmpty) return '';
    if (normalized.startsWith('+')) return normalized;

    final country = phoneCountryForDialCode(dialCode);
    var nationalDigits = normalized.replaceAll(RegExp(r'\D'), '');
    final dialDigits = country.dialCode.replaceAll('+', '');
    if (nationalDigits.startsWith(dialDigits)) {
      nationalDigits = nationalDigits.substring(dialDigits.length);
    }
    nationalDigits = nationalDigits.replaceFirst(RegExp(r'^0+'), '');
    return '${country.dialCode}$nationalDigits';
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
    if (value.trim().length > maxDisplayNameLength) {
      return 'Name must not exceed $maxDisplayNameLength characters.';
    }
    final name = normalizeSpaces(value);
    if (name.length < 2) return 'Name must contain at least 2 characters.';
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

  static String? emailVerificationCode(String value) {
    final code = value.trim();
    final pattern = RegExp(
      '^[0-9]{$emailVerificationCodeLength}\$',
    );
    if (!pattern.hasMatch(code)) {
      return 'Enter the $emailVerificationCodeLength-digit code from your verification email.';
    }
    return null;
  }

  static String? phoneForCountry(
    String value, {
    required String dialCode,
    bool required = true,
  }) {
    final normalized = normalizePhoneWithCountry(value, dialCode);
    final digits = normalized.replaceAll('+', '');
    if (digits.isEmpty && !required) return null;
    if (!RegExp(r'^\+[0-9]+$').hasMatch(normalized)) {
      return 'Enter a valid phone number.';
    }
    if (digits.length > maxPhoneDigits) {
      return 'Phone number must not exceed $maxPhoneDigits digits including country code.';
    }

    final country = phoneCountryForDialCode(dialCode);
    final dialDigits = country.dialCode.replaceAll('+', '');
    if (!digits.startsWith(dialDigits)) {
      return 'Phone number must start with ${country.dialCode}.';
    }
    final nationalDigits = digits.substring(dialDigits.length);
    if (nationalDigits.length < country.minNationalDigits ||
        nationalDigits.length > country.maxNationalDigits) {
      final range = country.minNationalDigits == country.maxNationalDigits
          ? '${country.minNationalDigits}'
          : '${country.minNationalDigits} to ${country.maxNationalDigits}';
      return '${country.name} phone number must contain $range digits after ${country.dialCode}.';
    }
    return null;
  }

  static String? relationship(String value, {bool required = false}) {
    if (value.trim().length > 30) {
      return 'Relationship must not exceed 30 characters.';
    }
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
    if (value.trim().length > maxAddressLength) {
      return 'Address must not exceed $maxAddressLength characters.';
    }
    final address = normalizeSpaces(value);
    if (address.isEmpty) return required ? 'Address is required.' : null;
    final letterCount = RegExp(r'[A-Za-z]').allMatches(address).length;
    if (address.length < 5 || letterCount < 2) {
      return 'Enter a complete address with a street, building, or landmark.';
    }
    return null;
  }

  static String? bloodType(String value, {bool required = false}) {
    if (value.trim().isEmpty) {
      return required ? 'Blood type is required.' : null;
    }
    if (!bloodTypes.contains(value.trim().toUpperCase())) {
      return 'Use A+, A-, B+, B-, AB+, AB-, O+, or O-.';
    }
    return null;
  }

  static String? inactivityThreshold(String value) {
    final days = int.tryParse(value.trim());
    if (days == null || !InactivityRules.isValidThresholdDays(days)) {
      return 'Threshold must be between 1 and 7 days.';
    }
    return null;
  }
}
