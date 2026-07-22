import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/colors.dart';
import '../../../models/legacy_access_result.dart';
import '../../../services/legacy_access_service.dart';
import '../../../utils/validators.dart';
import '../../widgets/country_phone_field.dart';
import '../../widgets/guidance_sheet.dart';
import '../../widgets/premium_shell.dart';

class LegacyCheckScreen extends StatefulWidget {
  const LegacyCheckScreen({
    super.key,
    this.service,
    this.showTestingMode = kDebugMode,
  });

  final LegacyAccessService? service;
  final bool showTestingMode;

  @override
  State<LegacyCheckScreen> createState() => _LegacyCheckScreenState();
}

class _LegacyCheckScreenState extends State<LegacyCheckScreen>
    with WidgetsBindingObserver {
  final formKey = GlobalKey<FormState>();
  final uidController = TextEditingController();
  final phoneController = TextEditingController();
  final codeController = TextEditingController();

  LegacyAccessService? _service;
  String phoneDialCode = '+60';
  bool codeRequested = false;
  bool busy = false;
  bool testingMode = false;
  LegacyAccessResult? result;
  LegacyAccessRequestStatus? requestStatus;
  Timer? sessionTimer;

  LegacyAccessService get service =>
      widget.service ?? (_service ??= LegacyAccessService());

  @override
  void initState() {
    super.initState();
    testingMode = widget.showTestingMode;
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    sessionTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    uidController.dispose();
    phoneController.dispose();
    codeController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed && result != null) {
      _clearSensitiveSession();
    }
  }

  String get normalizedPhone => AppValidators.normalizePhoneWithCountry(
    phoneController.text,
    phoneDialCode,
  );

  Future<void> _requestCode() async {
    if (busy || formKey.currentState?.validate() != true) return;
    setState(() => busy = true);
    try {
      final status = await service.requestCode(
        ownerUid: uidController.text,
        phone: normalizedPhone,
      );
      if (!mounted) return;
      setState(() {
        requestStatus = status;
        codeRequested = status.codeSent;
        if (!status.codeSent) codeController.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(status.message),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (error) {
      if (mounted) await _showError(error.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _verifyCode() async {
    if (busy || formKey.currentState?.validate() != true) return;
    final code = codeController.text.trim();
    if (!RegExp(r'^\d{6}$').hasMatch(code)) {
      await _showError('Enter the 6-digit code sent by SMS.');
      return;
    }

    setState(() => busy = true);
    try {
      final verified = await service.verifyCode(
        ownerUid: uidController.text,
        phone: normalizedPhone,
        code: code,
      );
      if (!mounted) return;
      sessionTimer?.cancel();
      setState(() => result = verified);
      sessionTimer = Timer(const Duration(minutes: 10), _clearSensitiveSession);
    } catch (error) {
      if (mounted) await _showError(error.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _verifyTestingAccess() async {
    if (busy || formKey.currentState?.validate() != true) return;
    setState(() => busy = true);
    try {
      final verified = await service.verifyTestingAccess(
        ownerUid: uidController.text,
        phone: normalizedPhone,
      );
      if (!mounted) return;
      sessionTimer?.cancel();
      setState(() => result = verified);
      sessionTimer = Timer(const Duration(minutes: 10), _clearSensitiveSession);
    } catch (error) {
      if (mounted) await _showError(error.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _showError(String message) {
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.error_outline, color: AppColors.danger),
        title: const Text('Legacy access unavailable'),
        content: Text(message),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _openDocument(LegacyAccessDocument document) async {
    final uri = Uri.tryParse(document.signedUrl);
    if (uri == null || !uri.hasScheme) {
      await _showError('The secure document link is invalid or expired.');
      return;
    }

    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      await _showError('The secure document could not be opened.');
    }
  }

  void _startAgain() {
    sessionTimer?.cancel();
    setState(() {
      codeRequested = false;
      busy = false;
      result = null;
      requestStatus = null;
      codeController.clear();
    });
  }

  void _clearSensitiveSession() {
    sessionTimer?.cancel();
    if (!mounted) return;
    setState(() {
      result = null;
      codeRequested = false;
      requestStatus = null;
      codeController.clear();
    });
  }

  Future<void> _showGuide() {
    return GuidanceSheet.show(
      context,
      title: 'Legacy Check Guide',
      description:
          'This protected page is for the account owner\'s verified primary trusted contact.',
      items: [
        const GuidanceItem(
          icon: Icons.fingerprint,
          title: 'Legacy UID',
          description:
              'Ask the account owner for the Legacy UID shown in their Profile. Enter the full UID exactly as provided.',
          color: AppColors.purple,
        ),
        const GuidanceItem(
          icon: Icons.phone_outlined,
          title: 'Primary contact phone',
          description:
              'Use the phone number saved and SMS-verified as the owner\'s primary trusted contact. Other numbers are not accepted.',
        ),
        const GuidanceItem(
          icon: Icons.schedule_outlined,
          title: 'When access becomes available',
          description:
              'The owner must enable Legacy Checking. After 90 days without a check-in, the daily server check emails the primary contact and opens access for seven days.',
          color: AppColors.accent,
        ),
        if (widget.showTestingMode)
          const GuidanceItem(
            icon: Icons.science_outlined,
            title: 'Testing mode',
            description:
                'Debug builds can skip SMS and the 90-day wait only when the account owner enables Testing access in Legacy Planning. The Legacy UID and SMS-verified primary contact phone must still match.',
            color: AppColors.danger,
          ),
        const GuidanceItem(
          icon: Icons.visibility_outlined,
          title: 'What can be viewed',
          description:
              'Funeral preferences, Legacy Notes, and uploaded secure documents are shown. Document links expire after 10 minutes. Credentials are never shared. Results close after 10 minutes or when the app leaves the foreground.',
          color: AppColors.blue,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Legacy Check'),
        actions: [
          IconButton(
            onPressed: _showGuide,
            icon: const Icon(Icons.info_outline_rounded),
            tooltip: 'Legacy Check guide',
          ),
          if (result != null)
            IconButton(
              onPressed: _startAgain,
              icon: const Icon(Icons.restart_alt),
              tooltip: 'Start another check',
            ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 620),
              child: result == null ? _buildAccessForm() : _buildResult(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAccessForm() {
    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(
            Icons.verified_user_outlined,
            size: 58,
            color: AppColors.primary,
          ),
          const SizedBox(height: 12),
          const Text(
            'Trusted Contact Verification',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 23, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Text(
            testingMode
                ? 'Testing mode works only when the owner enabled account testing in Legacy Planning. The UID and verified primary contact phone must match.'
                : 'After 90 days without a check-in, the server emails the primary contact and opens SMS-verified access for seven days.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.muted),
          ),
          const SizedBox(height: 22),
          GlassPanel(
            color: AppColors.glassStrong,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (widget.showTestingMode) ...[
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    value: testingMode,
                    onChanged: busy || codeRequested
                        ? null
                        : (value) => setState(() {
                            testingMode = value;
                            requestStatus = null;
                          }),
                    secondary: const Icon(
                      Icons.science_outlined,
                      color: AppColors.danger,
                    ),
                    title: const Text(
                      'Testing mode',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    subtitle: const Text(
                      'Requires owner approval in Legacy Planning. UID and verified primary phone must still match.',
                    ),
                  ),
                  const Divider(height: 24),
                ],
                TextFormField(
                  controller: uidController,
                  enabled: !codeRequested,
                  textInputAction: TextInputAction.next,
                  autocorrect: false,
                  decoration: const InputDecoration(
                    labelText: 'User Legacy UID',
                    prefixIcon: Icon(Icons.fingerprint),
                  ),
                  validator: (value) {
                    final uid = value?.trim() ?? '';
                    if (!RegExp(
                      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
                    ).hasMatch(uid)) {
                      return 'Enter the complete Legacy UID.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                CountryPhoneField(
                  controller: phoneController,
                  dialCode: phoneDialCode,
                  enabled: !codeRequested,
                  onDialCodeChanged: (value) {
                    setState(() => phoneDialCode = value);
                  },
                  labelText: 'Primary contact phone',
                ),
                if (requestStatus != null) ...[
                  const SizedBox(height: 16),
                  _LegacyAvailabilityStatus(status: requestStatus!),
                ],
                if (codeRequested) ...[
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: codeController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(6),
                    ],
                    textInputAction: TextInputAction.done,
                    decoration: const InputDecoration(
                      labelText: '6-digit SMS code',
                      prefixIcon: Icon(Icons.sms_outlined),
                    ),
                    onFieldSubmitted: (_) => _verifyCode(),
                  ),
                ],
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: busy
                      ? null
                      : testingMode
                      ? _verifyTestingAccess
                      : codeRequested
                      ? _verifyCode
                      : _requestCode,
                  icon: busy
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Icon(
                          testingMode
                              ? Icons.fact_check_outlined
                              : codeRequested
                              ? Icons.lock_open_outlined
                              : Icons.sms_outlined,
                        ),
                  label: Text(
                    testingMode
                        ? 'Verify UID and Phone'
                        : codeRequested
                        ? 'Verify and View'
                        : 'Send Verification Code',
                  ),
                ),
                if (codeRequested) ...[
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: busy
                        ? null
                        : () => setState(() {
                            codeRequested = false;
                            requestStatus = null;
                            codeController.clear();
                          }),
                    child: const Text('Change UID or phone'),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Secure documents are released only after verification. Account credentials must never be stored or shared.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.muted, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildResult() {
    final access = result!;
    final preferences = access.preferences;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const GlassPanel(
          color: AppColors.primarySoft,
          borderColor: AppColors.primary,
          child: Row(
            children: [
              Icon(Icons.verified_outlined, color: AppColors.primaryDark),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Primary contact verified. Legacy access is active for this session.',
                  style: TextStyle(
                    color: AppColors.primaryDark,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Text(
          '${access.ownerName}\'s Legacy Plan',
          style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w900),
        ),
        if (access.lastActivityAt != null) ...[
          const SizedBox(height: 4),
          Text(
            'Last recorded activity: ${DateFormat('dd MMM yyyy').format(access.lastActivityAt!.toLocal())}',
            style: const TextStyle(color: AppColors.muted),
          ),
        ],
        if (access.accessExpiresAt != null) ...[
          const SizedBox(height: 4),
          Text(
            'Access window closes: ${DateFormat('dd MMM yyyy, h:mm a').format(access.accessExpiresAt!.toLocal())}',
            style: const TextStyle(
              color: AppColors.danger,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
        const SizedBox(height: 20),
        const Text(
          'Funeral Preferences',
          style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 8),
        Card(
          child: Column(
            children: [
              _LegacyResultRow('Religion', preferences.religion),
              _LegacyResultRow('Service', preferences.serviceType),
              _LegacyResultRow('Venue', preferences.venue),
              _LegacyResultRow(
                'Authorized contact',
                preferences.authorizedContact,
              ),
              _LegacyResultRow('Notes', preferences.notes),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'Legacy Notes',
          style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 8),
        if (access.notes.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('No Legacy Notes were provided.'),
            ),
          )
        else
          ...access.notes.map(
            (note) => Card(
              child: ListTile(
                leading: const Icon(Icons.sticky_note_2_outlined),
                title: Text(
                  note.title,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 7),
                  child: Text(note.content),
                ),
              ),
            ),
          ),
        const SizedBox(height: 20),
        const Text(
          'Secure Documents',
          style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 4),
        const Text(
          'Links are private and expire after 10 minutes.',
          style: TextStyle(color: AppColors.muted, fontSize: 12),
        ),
        const SizedBox(height: 8),
        if (access.documents.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('No secure documents were provided.'),
            ),
          )
        else
          ...access.documents.map(
            (document) => Card(
              child: ListTile(
                onTap: () => _openDocument(document),
                leading: const Icon(Icons.description_outlined),
                title: Text(
                  document.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: Text(
                  document.uploadedAt == null
                      ? 'Tap to open securely'
                      : '${DateFormat('dd MMM yyyy').format(document.uploadedAt!.toLocal())}\nTap to open securely',
                ),
                isThreeLine: document.uploadedAt != null,
                trailing: const Icon(Icons.open_in_new),
              ),
            ),
          ),
      ],
    );
  }
}

class _LegacyAvailabilityStatus extends StatelessWidget {
  const _LegacyAvailabilityStatus({required this.status});

  final LegacyAccessRequestStatus status;

  @override
  Widget build(BuildContext context) {
    final waiting = status.status == 'waiting_period';
    final color = status.codeSent
        ? AppColors.primary
        : waiting
        ? AppColors.accent
        : AppColors.danger;
    final availableDate = status.availableAt == null
        ? null
        : DateFormat('dd MMM yyyy').format(status.availableAt!.toLocal());
    final expiryDate = status.accessExpiresAt == null
        ? null
        : DateFormat(
            'dd MMM yyyy, h:mm a',
          ).format(status.accessExpiresAt!.toLocal());

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        border: Border.all(color: color.withValues(alpha: 0.55)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            status.codeSent
                ? Icons.mark_email_read_outlined
                : waiting
                ? Icons.schedule_outlined
                : Icons.info_outline,
            color: color,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (waiting && status.daysRemaining != null)
                  Text(
                    '${status.daysRemaining} day${status.daysRemaining == 1 ? '' : 's'} remaining',
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                Text(status.message),
                if (availableDate != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Expected availability: $availableDate',
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 12,
                    ),
                  ),
                ],
                if (expiryDate != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Access window closes: $expiryDate',
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LegacyResultRow extends StatelessWidget {
  const _LegacyResultRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(label),
      subtitle: Text(value.trim().isEmpty ? 'Not provided' : value),
    );
  }
}
