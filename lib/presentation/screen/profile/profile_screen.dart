import 'package:flutter/material.dart';

import '../../../core/constants/colors.dart';
import '../../../core/constants/malaysia_locations.dart';
import '../../../models/emergency_escalation_target.dart';
import '../../../services/user_service.dart';
import '../../../utils/validators.dart';
import '../../widgets/country_phone_field.dart';
import '../../widgets/malaysia_address_fields.dart';
import '../../widgets/premium_shell.dart';
import '../planning/ai_guidance_screen.dart';
import '../planning/legacy_planning_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final userService = UserService();
  late Future<Map<String, dynamic>> profileFuture;

  @override
  void initState() {
    super.initState();
    profileFuture = _loadProfile();
  }

  Future<Map<String, dynamic>> _loadProfile() async {
    return userService.getCurrentProfile();
  }

  Future<void> _editProfile(Map<String, dynamic> profile) async {
    final updates = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => EditProfileDialog(profile: profile),
    );
    if (updates == null) return;

    try {
      await userService.updateCurrentProfile(updates);
      if (!mounted) return;
      setState(() {
        profileFuture = _loadProfile();
      });
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
      future: profileFuture,
      builder: (context, snapshot) {
        final profile = snapshot.data ?? {};
        final name = profile['name']?.toString() ?? 'EthernaCare User';
        final bloodType = profile['blood_type']?.toString();
        final bloodTypeLabel = (bloodType == null || bloodType.isEmpty)
            ? 'Not provided'
            : bloodType;
        final escalationTarget = EmergencyEscalationTarget.normalize(
          profile['emergency_escalation_target'],
        );
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          children: [
            PremiumHeader(
              title: 'My Profile',
              subtitle: 'Personal & medical info',
              action: IconButton.filled(
                onPressed: snapshot.connectionState == ConnectionState.done
                    ? () => _editProfile(profile)
                    : null,
                icon: const Icon(Icons.edit_outlined),
                tooltip: 'Edit profile',
              ),
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: AppColors.heroGradient,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(8),
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
                      borderRadius: BorderRadius.circular(8),
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
                          'Blood type: $bloodTypeLabel',
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
                _InfoTile(
                  icon: Icons.map_outlined,
                  iconColor: AppColors.blue,
                  label: 'State / region',
                  value: _formatAddressRegion(profile),
                ),
              ],
            ),
            const SizedBox(height: 17),
            _InfoSection(
              title: 'SAFETY SETTINGS',
              children: [
                _InfoTile(
                  icon: Icons.bloodtype_outlined,
                  label: 'Blood Type',
                  value: bloodTypeLabel,
                ),
                _InfoTile(
                  icon: Icons.timer_outlined,
                  label: 'Inactivity Threshold',
                  value: '${profile['inactivity_threshold'] ?? 24} hours',
                ),
                _InfoTile(
                  icon: Icons.emergency_share_outlined,
                  iconColor: AppColors.danger,
                  label: 'Escalation Target',
                  value: EmergencyEscalationTarget.label(escalationTarget),
                ),
              ],
            ),
            const SizedBox(height: 18),
            _ProfileAction(
              icon: Icons.description_outlined,
              title: 'Legacy Planning',
              subtitle: 'Funeral preferences and secure will documents',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const LegacyPlanningScreen()),
              ),
            ),
            const SizedBox(height: 10),
            _ProfileAction(
              icon: Icons.chat_outlined,
              title: 'AI Guidance',
              subtitle: 'General emergency and planning information',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AiGuidanceScreen()),
              ),
            ),
            const SizedBox(height: 18),
            OutlinedButton.icon(
              onPressed: userService.signOut,
              icon: const Icon(Icons.logout),
              label: const Text('Sign Out'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  String _formatAddressRegion(Map<String, dynamic> profile) {
    final state = profile['address_state']?.toString() ?? '';
    final region = profile['address_region']?.toString() ?? '';
    if (state.isEmpty && region.isEmpty) return 'Not provided';
    if (state.isEmpty) return region;
    if (region.isEmpty) return state;
    return '$region, $state';
  }
}

class _ProfileAction extends StatelessWidget {
  const _ProfileAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: EdgeInsets.zero,
      color: AppColors.glassStrong,
      child: ListTile(
        onTap: onTap,
        leading: Icon(icon, color: AppColors.primary),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
      ),
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
        GlassPanel(
          padding: EdgeInsets.zero,
          color: AppColors.glassStrong,
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

class EditProfileDialog extends StatefulWidget {
  const EditProfileDialog({super.key, required this.profile});

  final Map<String, dynamic> profile;

  @override
  State<EditProfileDialog> createState() => _EditProfileDialogState();
}

class _EditProfileDialogState extends State<EditProfileDialog> {
  final formKey = GlobalKey<FormState>();
  late final TextEditingController nameController;
  late final TextEditingController phoneController;
  late final TextEditingController addressController;
  late final TextEditingController thresholdController;
  String? selectedState;
  String? selectedRegion;
  String? selectedBloodType;
  late String escalationTarget;
  late String phoneDialCode;

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController(
      text: widget.profile['name']?.toString() ?? '',
    );
    final profilePhone = widget.profile['phone']?.toString() ?? '';
    phoneDialCode = AppValidators.detectPhoneCountry(profilePhone).dialCode;
    phoneController = TextEditingController(
      text: AppValidators.localPhoneForCountry(profilePhone, phoneDialCode),
    );
    addressController = TextEditingController(
      text: widget.profile['address']?.toString() ?? '',
    );
    selectedBloodType = _initialBloodType();
    thresholdController = TextEditingController(
      text: widget.profile['inactivity_threshold']?.toString() ?? '24',
    );
    escalationTarget = EmergencyEscalationTarget.normalize(
      widget.profile['emergency_escalation_target'],
    );
    selectedState = _initialState();
    selectedRegion = _initialRegion(selectedState);
  }

  String? _initialState() {
    final value = widget.profile['address_state']?.toString();
    return MalaysiaLocations.states.contains(value) ? value : null;
  }

  String? _initialRegion(String? state) {
    final value = widget.profile['address_region']?.toString();
    final regions = MalaysiaLocations.regionsFor(state);
    return regions.any((location) => location.region == value) ? value : null;
  }

  String? _initialBloodType() {
    final value = widget.profile['blood_type']?.toString().toUpperCase();
    return AppValidators.bloodTypes.contains(value) ? value : null;
  }

  String _compactEscalationLabel(String value) {
    return switch (EmergencyEscalationTarget.normalize(value)) {
      EmergencyEscalationTarget.official999 => '999 emergency',
      _ => 'Primary contact',
    };
  }

  @override
  void dispose() {
    nameController.dispose();
    phoneController.dispose();
    addressController.dispose();
    thresholdController.dispose();
    super.dispose();
  }

  void _save() {
    if (!(formKey.currentState?.validate() ?? false)) return;

    final name = AppValidators.normalizeSpaces(nameController.text);
    final threshold = int.tryParse(thresholdController.text.trim());

    Navigator.pop(context, {
      'name': name,
      'phone': AppValidators.normalizePhoneWithCountry(
        phoneController.text,
        phoneDialCode,
      ),
      'address': AppValidators.normalizeSpaces(addressController.text),
      'address_state': selectedState,
      'address_region': selectedRegion,
      'blood_type': selectedBloodType,
      'inactivity_threshold': threshold,
      'emergency_escalation_target': escalationTarget,
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final horizontalInset = size.width < 390 ? 14.0 : 24.0;

    return Dialog(
      insetPadding: EdgeInsets.symmetric(
        horizontal: horizontalInset,
        vertical: 20,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 440,
          maxHeight: size.height * .88,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(22, 22, 22, 10),
              child: Text(
                'Edit Profile',
                style: TextStyle(
                  color: AppColors.ink,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  height: 1.05,
                ),
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(22, 0, 22, 10),
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _ProfileFieldShell(
                        label: 'Name',
                        child: TextFormField(
                          controller: nameController,
                          maxLength: AppValidators.maxDisplayNameLength,
                          validator: (value) =>
                              AppValidators.displayName(value ?? ''),
                          decoration: const InputDecoration(
                            hintText: 'Full name',
                          ),
                          style: const TextStyle(
                            color: AppColors.ink,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      CountryPhoneField(
                        controller: phoneController,
                        dialCode: phoneDialCode,
                        onDialCodeChanged: (value) =>
                            setState(() => phoneDialCode = value),
                        labelText: 'Phone',
                        required: false,
                        externalLabels: true,
                      ),
                      const SizedBox(height: 10),
                      MalaysiaAddressFields(
                        addressController: addressController,
                        selectedState: selectedState,
                        selectedRegion: selectedRegion,
                        externalLabels: true,
                        addressLabel: 'House / unit, street',
                        addressHelperText: null,
                        stateLabel: 'State',
                        regionLabel: 'Region / district',
                        regionHelperText: null,
                        onStateChanged: (value) => setState(() {
                          selectedState = value;
                          selectedRegion = null;
                        }),
                        onRegionChanged: (value) =>
                            setState(() => selectedRegion = value),
                      ),
                      const SizedBox(height: 10),
                      _ProfileFieldShell(
                        label: 'Blood type',
                        child: DropdownButtonFormField<String>(
                          value: selectedBloodType,
                          isExpanded: true,
                          style: const TextStyle(
                            color: AppColors.ink,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                          items: AppValidators.bloodTypes
                              .map(
                                (type) => DropdownMenuItem(
                                  value: type,
                                  child: Text(
                                    type,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (value) =>
                              setState(() => selectedBloodType = value),
                          validator: (value) =>
                              AppValidators.bloodType(value ?? ''),
                          decoration: const InputDecoration(
                            hintText: 'Select blood type',
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      _ProfileFieldShell(
                        label: 'Inactivity threshold (hours)',
                        child: TextFormField(
                          controller: thresholdController,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(
                            color: AppColors.ink,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                          validator: (value) =>
                              AppValidators.inactivityThreshold(value ?? ''),
                          decoration: const InputDecoration(
                            hintText: '24',
                            helperText: 'Between 1 and 168 hours',
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      _ProfileFieldShell(
                        label: 'Inactivity escalation',
                        child: DropdownButtonFormField<String>(
                          value: escalationTarget,
                          isExpanded: true,
                          style: const TextStyle(
                            color: AppColors.ink,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                          selectedItemBuilder: (context) =>
                              EmergencyEscalationTarget.values
                                  .map(
                                    (value) => Align(
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        _compactEscalationLabel(value),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  )
                                  .toList(),
                          items: EmergencyEscalationTarget.values
                              .map(
                                (value) => DropdownMenuItem(
                                  value: value,
                                  child: Text(
                                    EmergencyEscalationTarget.label(value),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (value) => setState(
                            () => escalationTarget =
                                EmergencyEscalationTarget.normalize(value),
                          ),
                          decoration: const InputDecoration(
                            hintText: 'Select alert target',
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        EmergencyEscalationTarget.description(escalationTarget),
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 12,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SafeArea(
              top: false,
              minimum: const EdgeInsets.fromLTRB(22, 8, 22, 18),
              child: Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: _save,
                      child: const Text('Save'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileFieldShell extends StatelessWidget {
  const _ProfileFieldShell({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 6),
          child: Text(
            label,
            style: const TextStyle(
              color: AppColors.muted,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        child,
      ],
    );
  }
}
