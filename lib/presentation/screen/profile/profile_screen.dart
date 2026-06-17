import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/colors.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  Future<Map<String, dynamic>> _loadProfile() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return {};

    final rows = await Supabase.instance.client
        .from('users')
        .select()
        .eq('id', user.id)
        .limit(1);

    final profile = rows.isEmpty
        ? <String, dynamic>{}
        : Map<String, dynamic>.from(rows.first);
    profile['email'] ??= user.email;
    return profile;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _loadProfile(),
      builder: (context, snapshot) {
        final profile = snapshot.data ?? {};
        final name = profile['name']?.toString() ?? 'EthernaCare User';

        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              'My Profile',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 18),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Row(
                  children: [
                    const CircleAvatar(
                      radius: 38,
                      backgroundColor: Color(0xFFE5F4EF),
                      child: Icon(
                        Icons.verified_user,
                        size: 38,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Chip(
                            avatar: Icon(Icons.shield_outlined, size: 18),
                            label: Text('EthernaCare Protected'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            _InfoSection(
              title: 'Contact Information',
              children: [
                _InfoTile(
                  icon: Icons.email_outlined,
                  label: 'Email',
                  value: profile['email']?.toString() ?? 'Not provided',
                ),
                _InfoTile(
                  icon: Icons.phone_outlined,
                  label: 'Phone',
                  value: profile['phone']?.toString() ?? 'Not provided',
                ),
              ],
            ),
            const SizedBox(height: 16),
            _InfoSection(
              title: 'Home Address',
              children: [
                _InfoTile(
                  icon: Icons.home_outlined,
                  label: 'Address',
                  value: profile['address']?.toString() ?? 'Not provided',
                ),
              ],
            ),
            const SizedBox(height: 16),
            _InfoSection(
              title: 'Medical Information',
              children: [
                _InfoTile(
                  icon: Icons.cake_outlined,
                  label: 'Age',
                  value: profile['age']?.toString() ?? 'Not provided',
                ),
                _InfoTile(
                  icon: Icons.bloodtype_outlined,
                  label: 'Blood type',
                  value: profile['blood_type']?.toString() ?? 'Not provided',
                ),
                _InfoTile(
                  icon: Icons.timer_outlined,
                  label: 'Inactivity threshold',
                  value: '${profile['inactivity_threshold'] ?? 24} hours',
                ),
              ],
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => Supabase.instance.client.auth.signOut(),
              icon: const Icon(Icons.logout),
              label: const Text('Sign Out'),
            ),
          ],
        );
      },
    );
  }
}

class _InfoSection extends StatelessWidget {
  const _InfoSection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 8),
        Card(child: Column(children: children)),
      ],
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppColors.primary),
      title: Text(label),
      subtitle: Text(
        value,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    );
  }
}
