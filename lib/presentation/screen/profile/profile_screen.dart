import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/colors.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late Future<Map<String, dynamic>> profileFuture;

  @override
  void initState() {
    super.initState();
    profileFuture = _loadProfile();
  }

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

  Future<void> _editProfile(Map<String, dynamic> profile) async {
    final updates = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _EditProfileDialog(profile: profile),
    );
    if (updates == null) return;

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    try {
      await Supabase.instance.client.from('users').upsert({
        'id': user.id,
        ...updates,
      });
      if (!mounted) return;
      setState(() => profileFuture = _loadProfile());
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile updated.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not update profile: $error'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _loadProfile(),
      builder: (context, snapshot) {
        final profile = snapshot.data ?? {};
        final name = profile['name']?.toString() ?? 'EthernaCare User';
        final age = profile['age']?.toString() ?? '--';
        final bloodType = profile['blood_type']?.toString() ?? '--';
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          children: [
            Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'My Profile',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          color: AppColors.ink,
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'Personal & medical info',
                        style: TextStyle(color: AppColors.muted),
                      ),
                    ],
                  ),
                ),
                IconButton.filled(
                  onPressed: snapshot.connectionState == ConnectionState.done
                      ? () => _editProfile(profile)
                      : null,
                  icon: const Icon(Icons.edit_outlined),
                  tooltip: 'Edit profile',
                ),
              ],
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primary, AppColors.primaryDark],
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x3000B884),
                    blurRadius: 14,
                    offset: Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 65,
                    height: 65,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .18),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: const Icon(
                      Icons.person,
                      size: 42,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 21,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          '$age years old • $bloodType',
                          style: const TextStyle(color: Colors.white),
                        ),
                        const SizedBox(height: 5),
                        const Row(
                          children: [
                            Icon(
                              Icons.shield_outlined,
                              size: 16,
                              color: Colors.white,
                            ),
                            SizedBox(width: 5),
                            Expanded(
                              child: Text(
                                'SafeGuard Protected',
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _InfoSection(
              title: 'CONTACT INFORMATION',
              children: [
                _InfoTile(
                  icon: Icons.phone_outlined,
                  label: 'Phone',
                  value: profile['phone']?.toString() ?? 'Not provided',
                ),
                _InfoTile(
                  icon: Icons.email_outlined,
                  label: 'Email',
                  value: profile['email']?.toString() ?? 'Not provided',
                ),
              ],
            ),
            const SizedBox(height: 17),
            _InfoSection(
              title: 'HOME ADDRESS',
              children: [
                _InfoTile(
                  icon: Icons.home_outlined,
                  iconColor: AppColors.blue,
                  label: 'Address',
                  value: profile['address']?.toString() ?? 'Not provided',
                ),
              ],
            ),
            const SizedBox(height: 17),
            _InfoSection(
              title: 'MEDICAL INFORMATION',
              children: [
                _InfoTile(
                  icon: Icons.bloodtype_outlined,
                  label: 'Blood Type',
                  value: bloodType,
                ),
                _InfoTile(
                  icon: Icons.timer_outlined,
                  label: 'Inactivity Threshold',
                  value: '${profile['inactivity_threshold'] ?? 24} hours',
                ),
              ],
            ),
            const SizedBox(height: 18),
            OutlinedButton.icon(
              onPressed: () => Supabase.instance.client.auth.signOut(),
              icon: const Icon(Icons.logout),
              label: const Text('Sign Out'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
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
          style: const TextStyle(
            color: AppColors.muted,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: .7,
          ),
        ),
        const SizedBox(height: 8),
        Card(
          child: Column(
            children: [
              for (var index = 0; index < children.length; index++) ...[
                children[index],
                if (index < children.length - 1)
                  const Divider(height: 1, indent: 62),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
    this.iconColor = AppColors.muted,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        radius: 20,
        backgroundColor: iconColor.withValues(alpha: .1),
        foregroundColor: iconColor,
        child: Icon(icon, size: 20),
      ),
      title: Text(
        label,
        style: const TextStyle(color: AppColors.muted, fontSize: 12),
      ),
      subtitle: Text(
        value,
        style: const TextStyle(
          color: AppColors.ink,
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _EditProfileDialog extends StatefulWidget {
  const _EditProfileDialog({required this.profile});

  final Map<String, dynamic> profile;

  @override
  State<_EditProfileDialog> createState() => _EditProfileDialogState();
}

class _EditProfileDialogState extends State<_EditProfileDialog> {
  late final TextEditingController nameController;
  late final TextEditingController phoneController;
  late final TextEditingController addressController;
  late final TextEditingController ageController;
  late final TextEditingController bloodTypeController;
  late final TextEditingController thresholdController;

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController(
      text: widget.profile['name']?.toString() ?? '',
    );
    phoneController = TextEditingController(
      text: widget.profile['phone']?.toString() ?? '',
    );
    addressController = TextEditingController(
      text: widget.profile['address']?.toString() ?? '',
    );
    ageController = TextEditingController(
      text: widget.profile['age']?.toString() ?? '',
    );
    bloodTypeController = TextEditingController(
      text: widget.profile['blood_type']?.toString() ?? '',
    );
    thresholdController = TextEditingController(
      text: widget.profile['inactivity_threshold']?.toString() ?? '24',
    );
  }

  @override
  void dispose() {
    nameController.dispose();
    phoneController.dispose();
    addressController.dispose();
    ageController.dispose();
    bloodTypeController.dispose();
    thresholdController.dispose();
    super.dispose();
  }

  void _save() {
    final name = nameController.text.trim();
    final age = int.tryParse(ageController.text.trim());
    final threshold = int.tryParse(thresholdController.text.trim());
    if (name.isEmpty || threshold == null || threshold < 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter a name and a valid inactivity threshold.'),
        ),
      );
      return;
    }

    Navigator.pop(context, {
      'name': name,
      'phone': phoneController.text.trim(),
      'address': addressController.text.trim(),
      'age': age,
      'blood_type': bloodTypeController.text.trim(),
      'inactivity_threshold': threshold,
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Profile'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Phone'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: addressController,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Home address'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: ageController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Age'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: bloodTypeController,
              decoration: const InputDecoration(labelText: 'Blood type'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: thresholdController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Inactivity threshold (hours)',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}
