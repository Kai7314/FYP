class EmergencyEscalationTarget {
  const EmergencyEscalationTarget._();

  static const primaryContact = 'primary_contact';
  static const trustedContacts = 'trusted_contacts';
  static const official999 = 'official_999';

  static const values = [primaryContact, official999];

  static String normalize(Object? value) {
    final text = value?.toString() ?? '';
    if (text == trustedContacts) return primaryContact;
    return values.contains(text) ? text : primaryContact;
  }

  static String label(String value) {
    return switch (normalize(value)) {
      official999 => '999 emergency dialer',
      _ => 'Primary trusted contact',
    };
  }

  static String description(String value) {
    return switch (normalize(value)) {
      official999 =>
        'Manual SOS opens 999. After three missed check-in windows, inactivity records an alert and shows a critical local notice.',
      _ =>
        'After three missed check-in windows, inactivity sends an SMS alert to your primary emergency contact. Manual SOS alerts immediately.',
    };
  }
}
