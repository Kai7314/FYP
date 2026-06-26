import '../../services/contact_service.dart';

class ContactController {
  ContactController({ContactService? contactService})
    : contactService = contactService ?? ContactService();

  final ContactService contactService;

  Future<List<Map<String, dynamic>>> list({bool refresh = false}) {
    return contactService.getContacts(forceRefresh: refresh);
  }

  Future<void> add({
    required String name,
    required String relationship,
    required String phone,
    String? address,
    bool isPrimary = false,
  }) {
    return contactService.addContact(
      name: name,
      relationship: relationship,
      phone: phone,
      address: address,
      isPrimary: isPrimary,
    );
  }

  Future<void> delete(Map<String, dynamic> contact) {
    return contactService.deleteContact(contact);
  }
}
