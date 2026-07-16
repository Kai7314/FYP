import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/constants/colors.dart';
import '../../../core/constants/malaysia_locations.dart';
import '../../../models/emergency_escalation_target.dart';
import '../../../services/user_service.dart';
import '../../../utils/validators.dart';
import '../../widgets/country_phone_field.dart';
import '../../widgets/error_dialog.dart';
import '../../widgets/guidance_sheet.dart';
import '../../widgets/malaysia_address_fields.dart';
import '../../widgets/phone_otp_verification_card.dart';
import '../../widgets/premium_shell.dart';
import '../../../services/phone_verification_service.dart';
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
    final updates = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(builder: (_) => EditProfileDialog(profile: profile)),
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
      AppErrorDialog.show(
        context,
        title: 'Could not update profile',
        error: error,
      );
    }
  }

  Future<void> _copyLegacyUid(String uid) async {
    if (uid.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: uid));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Legacy UID copied.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _showAppGuide() {
    return GuidanceSheet.show(
      context,
      title: 'EthernaCare Guide',
      description:
          'A quick reference for the main tabs, safety tools, and Oren care features.',
      items: const [
        GuidanceItem(
          icon: Icons.home_outlined,
          title: 'Home',
          description:
              'Tap Oren for your daily check-in, view Oren\'s status and weather, use care actions, and review the Safety Monitor lower on the page.',
        ),
        GuidanceItem(
          icon: Icons.history,
          title: 'History',
          description:
              'Review recorded check-ins and their dates. Pull down or reopen the page to refresh recent activity.',
          color: AppColors.blue,
        ),
        GuidanceItem(
          icon: Icons.contacts_outlined,
          title: 'Contacts and SOS',
          description:
              'Add trusted contacts, verify their phone numbers, and select one primary contact for SOS and inactivity follow-up.',
          color: AppColors.danger,
        ),
        GuidanceItem(
          icon: Icons.redeem_outlined,
          title: 'Rewards, tokens, and Oren',
          description:
              'Daily activity earns tokens. Use them in Oren\'s shop, select an owned toy, then tap Play to see Oren interact with it.',
          color: AppColors.accent,
        ),
        GuidanceItem(
          icon: Icons.person_outline,
          title: 'Profile and planning',
          description:
              'Update personal and safety details, copy your Legacy UID, manage Legacy Planning, and open general AI Guidance.',
          color: AppColors.purple,
        ),
        GuidanceItem(
          icon: Icons.warning_amber_rounded,
          title: 'Safety messages',
          description:
              'Green means the current status is normal, amber needs attention, and red indicates an emergency or failed safety action. Call 999 for immediate danger in Malaysia.',
          color: AppColors.danger,
        ),
      ],
    );
  }

  Future<void> _showLegacyUidGuide() {
    return GuidanceSheet.show(
      context,
      title: 'About Your Legacy UID',
      description:
          'Your Legacy UID identifies your account during a protected Legacy Check.',
      items: const [
        GuidanceItem(
          icon: Icons.copy_outlined,
          title: 'Copy and share carefully',
          description:
              'Use the copy button beside the UID and give it only to your intended primary trusted contact.',
          color: AppColors.purple,
        ),
        GuidanceItem(
          icon: Icons.lock_outline,
          title: 'The UID is not enough by itself',
          description:
              'Access also requires your verified primary contact\'s phone, an SMS code, your consent, and at least 90 days without a check-in.',
        ),
        GuidanceItem(
          icon: Icons.visibility_off_outlined,
          title: 'Documents stay private',
          description:
              'Legacy Checking can show preferences and Legacy Notes only. Uploaded secure documents are never included.',
          color: AppColors.blue,
        ),
      ],
    );
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
        final legacyUid =
            profile['id']?.toString() ?? userService.currentUserId ?? '';
        final escalationTarget = EmergencyEscalationTarget.normalize(
          profile['emergency_escalation_target'],
        );
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          children: [
            PremiumHeader(
              title: 'My Profile',
              subtitle: 'Personal & medical info',
              orenAsset:
                  'lib/assets/images/pixel/oren_pixel_calm_transparent.png',
              orenSemanticLabel: 'Calm Oren beside your profile',
              action: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    onPressed: _showAppGuide,
                    icon: const Icon(Icons.help_outline_rounded),
                    tooltip: 'App guide',
                  ),
                  const SizedBox(width: 4),
                  IconButton.filled(
                    onPressed:
                        snapshot.connectionState == ConnectionState.done
                        ? () => _editProfile(profile)
                        : null,
                    icon: const Icon(Icons.edit_outlined),
                    tooltip: 'Edit profile',
                  ),
                ],
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
              title: 'LEGACY ACCESS',
              action: IconButton(
                onPressed: _showLegacyUidGuide,
                icon: const Icon(Icons.info_outline_rounded),
                tooltip: 'About Legacy UID',
                visualDensity: VisualDensity.compact,
              ),
              children: [
                _InfoTile(
                  icon: Icons.fingerprint,
                  iconColor: AppColors.purple,
                  label: 'Legacy UID',
                  value: legacyUid.isEmpty ? 'Unavailable' : legacyUid,
                  trailing: IconButton(
                    onPressed: legacyUid.isEmpty
                        ? null
                        : () => _copyLegacyUid(legacyUid),
                    icon: const Icon(Icons.copy_outlined),
                    tooltip: 'Copy Legacy UID',
                  ),
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
  const _InfoSection({
    required this.title,
    required this.children,
    this.action,
  });

  final String title;
  final List<Widget> children;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: AppColors.muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: .7,
                ),
              ),
            ),
            if (action != null) action!,
          ],
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
    this.trailing,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color iconColor;
  final Widget? trailing;

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
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: AppColors.ink,
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
      trailing: trailing,
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
  late String initialPhone;
  String? verifiedPhone;

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController(
      text: widget.profile['name']?.toString() ?? '',
    );
    final profilePhone = widget.profile['phone']?.toString() ?? '';
    initialPhone = AppValidators.normalizePhone(profilePhone);
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
    final phone = _normalizedPhone();
    if (phone.isNotEmpty && phone != initialPhone && verifiedPhone != phone) {
      _showMessage('Please verify your new phone number first.');
      return;
    }

    Navigator.pop(context, {
      'name': name,
      'phone': phone,
      'address': AppValidators.normalizeSpaces(addressController.text),
      'address_state': selectedState,
      'address_region': selectedRegion,
      'blood_type': selectedBloodType,
      'inactivity_threshold': threshold,
      'emergency_escalation_target': escalationTarget,
    });
  }

  String _normalizedPhone() {
    return AppValidators.normalizePhoneWithCountry(
      phoneController.text,
      phoneDialCode,
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Profile')),
      body: SafeArea(
        child: Form(
          key: formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            children: [
              const Text(
                'Personal details',
                style: TextStyle(
                  color: AppColors.ink,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Keep your emergency profile accurate and easy to contact.',
                style: TextStyle(color: AppColors.muted),
              ),
              const SizedBox(height: 22),
              _ProfileFieldShell(
                label: 'Name',
                child: TextFormField(
                  controller: nameController,
                  maxLength: AppValidators.maxDisplayNameLength,
                  validator: (value) => AppValidators.displayName(value ?? ''),
                  decoration: const InputDecoration(hintText: 'Full name'),
                  style: const TextStyle(
                    color: AppColors.ink,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              CountryPhoneField(
                controller: phoneController,
                dialCode: phoneDialCode,
                onDialCodeChanged: (value) =>
                    setState(() => phoneDialCode = value),
                labelText: 'Phone',
                required: false,
                externalLabels: true,
              ),
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: phoneController,
                builder: (context, value, child) {
                  final phone = _normalizedPhone();
                  if (phone.isEmpty || phone == initialPhone) {
                    return const SizedBox.shrink();
                  }
                  return PhoneOtpVerificationCard(
                    phone: phone,
                    purpose: PhoneVerificationPurpose.userPhone,
                    onVerified: (phone) =>
                        setState(() => verifiedPhone = phone),
                  );
                },
              ),
              const SizedBox(height: 16),
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
              const SizedBox(height: 12),
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
                  validator: (value) => AppValidators.bloodType(value ?? ''),
                  decoration: const InputDecoration(
                    hintText: 'Select blood type',
                  ),
                ),
              ),
              const SizedBox(height: 12),
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
                    helperText: '1-168 hours for each missed check-in',
                  ),
                ),
              ),
              const SizedBox(height: 12),
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
                  selectedItemBuilder: (context) => EmergencyEscalationTarget
                      .values
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
      bottomNavigationBar: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(20, 8, 20, 16),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(onPressed: _save, child: const Text('Save')),
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
