import 'package:flutter/material.dart';

import '../../../core/constants/app_terms.dart';
import '../../../core/constants/colors.dart';

class TermsAndConditionsScreen extends StatelessWidget {
  const TermsAndConditionsScreen({
    super.key,
    this.acceptanceMode = false,
    this.acceptedVersion,
    this.acceptedAt,
  });

  final bool acceptanceMode;
  final String? acceptedVersion;
  final DateTime? acceptedAt;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Terms and Conditions')),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: AppColors.appGradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          top: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: ListView(
                key: const Key('terms-document-scroll-view'),
                padding: const EdgeInsets.fromLTRB(22, 20, 22, 36),
                children: [
                  const Icon(
                    Icons.policy_outlined,
                    size: 52,
                    color: AppColors.primary,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'EthernaCare Terms and Conditions',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.ink,
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Effective ${AppTerms.effectiveDateLabel}  |  Version ${AppTerms.version}',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.muted),
                  ),
                  if (acceptedAt != null || acceptedVersion != null) ...[
                    const SizedBox(height: 16),
                    _AcceptanceStatus(
                      acceptedVersion: acceptedVersion,
                      acceptedAt: acceptedAt,
                    ),
                  ],
                  const SizedBox(height: 20),
                  const _ImportantNotice(),
                  const SizedBox(height: 24),
                  const _TermsSection(
                    number: '1',
                    title: 'Agreement and eligibility',
                    paragraphs: [
                      'These Terms explain how EthernaCare works and the responsibilities that apply when you create or use an account. By selecting the agreement checkbox and creating an account, you confirm that you have read and accepted these Terms.',
                      'You must be able to provide valid consent under applicable law. If another person helps you use the app, you remain responsible for confirming that the information and trusted contacts you provide are accurate and authorized.',
                    ],
                  ),
                  const _TermsSection(
                    number: '2',
                    title: 'What EthernaCare provides',
                    paragraphs: [
                      'EthernaCare supports daily well-being check-ins through Oren, check-in history, inactivity reminders, SOS alerts, trusted contacts, weather information, rewards, and Legacy Planning.',
                      'Some features depend on internet access, device permissions, Supabase, email or SMS providers, weather services, and other third-party systems. A feature may be delayed or unavailable when one of those services is unavailable.',
                    ],
                  ),
                  const _TermsSection(
                    number: '3',
                    title: 'Emergency and safety limitations',
                    paragraphs: [
                      'EthernaCare is a support and notification tool. It is not an emergency response service, medical monitoring device, ambulance service, or substitute for professional care.',
                      'For immediate danger in Malaysia, call 999. Do not wait for an EthernaCare notification, trusted-contact response, or app status.',
                      'SOS and inactivity messages may fail or arrive late because of network coverage, phone settings, provider restrictions, an invalid contact number, missing location permission, or service interruption. EthernaCare cannot guarantee message delivery or that a trusted contact will respond.',
                    ],
                  ),
                  const _TermsSection(
                    number: '4',
                    title: 'Your account and security',
                    paragraphs: [
                      'Provide accurate information and keep your email, phone number, home region, safety settings, and trusted contacts current. One email address may be associated with only one EthernaCare account.',
                      'Keep your password, email codes, SMS codes, and device access private. You are responsible for activity performed through your account unless you promptly report unauthorized access to the administrator.',
                      'Phone and email verification reduce misuse but do not prove identity in every situation. Do not register a phone number or email address that you do not control or have permission to use.',
                      'If you enable biometric unlock, EthernaCare asks the device operating system to verify fingerprint, face recognition, Touch ID, Windows Hello, or another supported device credential before showing a saved signed-in session. EthernaCare does not receive or store your biometric template. The setting applies only to that device and does not replace your account password or Supabase authentication.',
                    ],
                  ),
                  const _TermsSection(
                    number: '5',
                    title: 'Trusted contacts',
                    paragraphs: [
                      'Before adding a trusted contact, obtain their permission to store and use their name, relationship, phone number, address, and other contact details. Tell them that EthernaCare may send verification codes, inactivity messages, SOS alerts, location links, and Legacy Planning notices.',
                      'You must choose the correct primary trusted contact. The primary contact may receive sensitive safety or Legacy Planning information according to your settings and the release rules below.',
                    ],
                  ),
                  const _TermsSection(
                    number: '6',
                    title: 'Information collected and used',
                    paragraphs: [
                      'To operate the app, EthernaCare may process your account and profile information, phone and email verification records, home address and region, blood type, religious and funeral preferences, check-ins, inactivity status, alert history, available device location, trusted-contact details, rewards, Legacy Notes, and uploaded documents.',
                      'Some of this information may be sensitive personal data. By providing it and accepting these Terms, you expressly consent to its use for the features you request, subject to applicable Malaysian personal-data law.',
                      'Data is used to authenticate you, provide check-ins and alerts, display weather, manage rewards, protect Legacy Planning access, prevent misuse, troubleshoot the service, and maintain security records.',
                    ],
                  ),
                  const _TermsSection(
                    number: '7',
                    title: 'Check-ins and inactivity',
                    paragraphs: [
                      'A check-in records that you interacted with the check-in control at that time. It does not confirm your medical condition or guarantee your safety.',
                      'If no new check-in is recorded, the system may issue inactivity reminders according to your threshold. The second missed window may send an SMS reminder to your verified phone. Where configured, the third reminder may send an SMS alert to the selected escalation target. A failed or triggered alarm does not create a check-in and inactivity continues until a valid check-in is recorded.',
                    ],
                  ),
                  const _TermsSection(
                    number: '8',
                    title: 'Legacy Planning and Legacy Check',
                    paragraphs: [
                      'Legacy Planning stores personal wishes and supporting documents. It is not a legally executed will, legal advice, estate administration service, or guarantee that your wishes will be followed. Obtain qualified legal advice for legally binding arrangements.',
                      'Never store passwords, PINs, recovery phrases, one-time codes, banking credentials, or authentication secrets in Legacy Notes or documents.',
                      'A verified primary trusted contact may view the funeral preferences you chose to make available. Protected Legacy Notes and eligible planning information may be released only after the configured inactivity period, currently 90 days, and the required server checks.',
                      'Before protected information is released, EthernaCare may email the account owner and allow a cancellation period. If the owner does not cancel within that period, the primary contact may be notified and receive access for a limited window, currently seven days. Uploaded secure documents are shared only when the feature and release policy explicitly permit it.',
                      'Testing controls are for development only and must not be treated as proof that a real 90-day release has occurred.',
                    ],
                  ),
                  const _TermsSection(
                    number: '9',
                    title: 'Location, weather, and AI guidance',
                    paragraphs: [
                      'Location included with an alert depends on device permission and availability and may be inaccurate. Weather is based on the selected region and third-party weather data and may be delayed or incorrect.',
                      'AI Guidance and other informational content may contain mistakes. It is general information only and is not medical, legal, financial, emergency, or other professional advice. Verify important decisions with a qualified professional.',
                    ],
                  ),
                  const _TermsSection(
                    number: '10',
                    title: 'Virtual rewards',
                    paragraphs: [
                      'Oren tokens, milestone badges, and virtual vouchers are app benefits. They are not cash, stored value, physical products, or property and cannot be transferred, sold, refunded, or exchanged unless the displayed reward terms expressly permit it.',
                      'Eligible virtual rewards unlock automatically after the server verifies the required check-in streak. Voucher codes are generated for the account that earned them and should not be shared. An EthernaCare-generated code is an internal reward code and is not a third-party merchant coupon unless that issuer has expressly agreed to accept it.',
                      'No delivery request or administrator approval is required. Virtual rewards and voucher availability may change when the app or reward system is updated, while previously earned records may be retained for account history.',
                    ],
                  ),
                  const _TermsSection(
                    number: '11',
                    title: 'Service providers and data handling',
                    paragraphs: [
                      'EthernaCare may rely on service providers for hosting, authentication, database storage, file storage, email, SMS, weather, maps, and AI features. Information needed for a requested feature may be sent to the relevant provider.',
                      'Providers may process data in other countries and under their own terms and privacy practices. The administrator should configure only providers appropriate for the deployment and protect server credentials from app users.',
                    ],
                  ),
                  const _TermsSection(
                    number: '12',
                    title: 'Your choices and rights',
                    paragraphs: [
                      'You may review and correct profile information in the app. You may ask the EthernaCare administrator for access, correction, deletion, withdrawal of consent, or information about processing, subject to legal and operational retention requirements.',
                      'Withdrawing consent or deleting required information may disable check-ins, alerts, verification, rewards, or Legacy Planning. Records may be retained when reasonably necessary for security, dispute resolution, fraud prevention, or legal compliance.',
                    ],
                  ),
                  const _TermsSection(
                    number: '13',
                    title: 'Acceptable use',
                    paragraphs: [
                      'Do not misuse SOS or reminder testing, impersonate another person, submit a phone number without permission, attempt unauthorized Legacy access, interfere with the service, upload unlawful content, or use the app to harass or deceive others.',
                      'The administrator may restrict or terminate access when reasonably necessary to protect users, trusted contacts, the service, or legal compliance.',
                    ],
                  ),
                  const _TermsSection(
                    number: '14',
                    title: 'Availability and responsibility',
                    paragraphs: [
                      'The app is provided on an availability basis. Reasonable security and reliability controls should be used, but no software or online storage can be guaranteed to be uninterrupted, error-free, or completely secure.',
                      'To the extent permitted by law, EthernaCare and its administrator are not responsible for losses caused by reliance on delayed, missing, inaccurate, or unavailable notifications or information. Nothing in these Terms excludes rights that cannot lawfully be excluded.',
                    ],
                  ),
                  const _TermsSection(
                    number: '15',
                    title: 'Changes and governing law',
                    paragraphs: [
                      'These Terms may be updated when app features, providers, safety rules, or legal requirements change. A new version may require you to review and accept it before continuing to use affected features.',
                      'These Terms are governed by the laws of Malaysia. Contact the administrator responsible for your EthernaCare deployment with questions, privacy requests, security concerns, or complaints.',
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: acceptanceMode
          ? SafeArea(
              top: false,
              minimum: const EdgeInsets.fromLTRB(20, 10, 20, 16),
              child: FilledButton.icon(
                key: const Key('accept-terms-button'),
                onPressed: () => Navigator.of(context).pop(true),
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('I Have Read and Agree'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(54),
                ),
              ),
            )
          : null,
    );
  }
}

class _ImportantNotice extends StatelessWidget {
  const _ImportantNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.warningSoft,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.accent.withValues(alpha: .45)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded, color: AppColors.danger),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Important: EthernaCare supports safety follow-up but does not monitor you continuously and does not replace emergency, medical, or legal services.',
              style: TextStyle(
                color: AppColors.ink,
                fontWeight: FontWeight.w700,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AcceptanceStatus extends StatelessWidget {
  const _AcceptanceStatus({this.acceptedVersion, this.acceptedAt});

  final String? acceptedVersion;
  final DateTime? acceptedAt;

  @override
  Widget build(BuildContext context) {
    final details = <String>[
      if (acceptedAt != null) 'Accepted ${_formatDate(acceptedAt!.toLocal())}',
      if (acceptedVersion != null && acceptedVersion!.trim().isNotEmpty)
        'Version ${acceptedVersion!.trim()}',
    ].join('  |  ');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.primary.withValues(alpha: .3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.verified_outlined, color: AppColors.primaryDark),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              details,
              style: const TextStyle(
                color: AppColors.primaryDark,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _formatDate(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}

class _TermsSection extends StatelessWidget {
  const _TermsSection({
    required this.number,
    required this.title,
    required this.paragraphs,
  });

  final String number;
  final String title;
  final List<String> paragraphs;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$number. $title',
            style: const TextStyle(
              color: AppColors.ink,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          for (var index = 0; index < paragraphs.length; index++) ...[
            Text(
              paragraphs[index],
              style: const TextStyle(
                color: AppColors.ink,
                fontSize: 15,
                height: 1.5,
              ),
            ),
            if (index != paragraphs.length - 1) const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}
