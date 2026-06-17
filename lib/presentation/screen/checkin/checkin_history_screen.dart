import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/colors.dart';

class CheckinHistoryScreen extends StatelessWidget {
  const CheckinHistoryScreen({super.key});

  Future<List<Map<String, dynamic>>> _loadCheckins() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return [];

    final rows = await Supabase.instance.client
        .from('checkins')
        .select()
        .eq('user_id', user.id)
        .order('checkin_time', ascending: false);

    return List<Map<String, dynamic>>.from(rows);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _loadCheckins(),
      builder: (context, snapshot) {
        final rows = snapshot.data ?? [];

        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              'Check-In History',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            const Text('A clear record of every daily heartbeat signal.'),
            const SizedBox(height: 18),
            if (snapshot.connectionState == ConnectionState.waiting)
              const Center(child: CircularProgressIndicator())
            else if (rows.isEmpty)
              const _EmptyState()
            else
              ...rows.map((row) => _CheckinTile(row: row)),
          ],
        );
      },
    );
  }
}

class _CheckinTile extends StatelessWidget {
  const _CheckinTile({required this.row});

  final Map<String, dynamic> row;

  @override
  Widget build(BuildContext context) {
    final time = DateTime.tryParse(row['checkin_time'].toString());
    final title = time == null
        ? 'Recorded check-in'
        : DateFormat('EEEE, dd MMM yyyy').format(time);
    final subtitle = time == null
        ? 'Time unavailable'
        : DateFormat('h:mm a').format(time);
    final status = row['status']?.toString() ?? 'active';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        child: ListTile(
          leading: const CircleAvatar(
            backgroundColor: Color(0xFFE5F4EF),
            child: Icon(Icons.pets, color: AppColors.primary),
          ),
          title: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          subtitle: Text('$subtitle - $status'),
          trailing: const Icon(Icons.check_circle, color: AppColors.primary),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Text(
          'No check-ins yet. Pet the cat from the Home tab to begin your history.',
        ),
      ),
    );
  }
}
