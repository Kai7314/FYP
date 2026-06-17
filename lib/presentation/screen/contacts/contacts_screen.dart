import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/colors.dart';
import 'add_contact_dialog.dart';

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  final supabase = Supabase.instance.client;
  late Future<List<Map<String, dynamic>>> contactsFuture;

  @override
  void initState() {
    super.initState();
    contactsFuture = _loadContacts();
  }

  Future<List<Map<String, dynamic>>> _loadContacts() async {
    final user = supabase.auth.currentUser;
    if (user == null) return [];

    final rows = await supabase
        .from('contacts')
        .select()
        .eq('user_id', user.id)
        .order('name', ascending: true);

    return List<Map<String, dynamic>>.from(rows);
  }

  Future<void> _addContact() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (_) => const AddContactDialog(),
    );

    if (result == null) return;

    final payload = {
      'user_id': user.id,
      'name': result['name'],
      'relationship': result['relationship'],
      'phone': result['phone'],
    };

    try {
      await supabase.from('contacts').insert({
        ...payload,
        'address': result['address'],
      });
    } catch (_) {
      await supabase.from('contacts').insert(payload);
    }

    setState(() => contactsFuture = _loadContacts());
  }

  Future<void> _deleteContact(Map<String, dynamic> row) async {
    final id = row['id'] ?? row['contact_id'];
    if (id == null) return;
    final idColumn = row.containsKey('id') ? 'id' : 'contact_id';
    await supabase.from('contacts').delete().eq(idColumn, id);
    setState(() => contactsFuture = _loadContacts());
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: contactsFuture,
      builder: (context, snapshot) {
        final rows = snapshot.data ?? [];

        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Emergency Contacts',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                IconButton.filled(
                  onPressed: _addContact,
                  icon: const Icon(Icons.add),
                  tooltip: 'Add contact',
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'These trusted people can receive emergency alerts and location updates.',
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (snapshot.connectionState == ConnectionState.waiting)
              const Center(child: CircularProgressIndicator())
            else if (rows.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Text(
                    'No contacts yet. Add at least one family member or caregiver.',
                  ),
                ),
              )
            else
              ...rows.map(
                (row) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Card(
                    child: ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: Color(0xFFE5F4EF),
                        child: Icon(Icons.person, color: AppColors.primary),
                      ),
                      title: Text(
                        row['name']?.toString() ?? 'Unnamed',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      subtitle: Text(
                        [
                              row['relationship']?.toString(),
                              row['phone']?.toString(),
                              row['address']?.toString(),
                            ]
                            .where((value) => value != null && value.isNotEmpty)
                            .join('\n'),
                      ),
                      isThreeLine: true,
                      trailing: IconButton(
                        onPressed: () => _deleteContact(row),
                        icon: const Icon(Icons.delete_outline),
                        color: AppColors.danger,
                        tooltip: 'Delete contact',
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
