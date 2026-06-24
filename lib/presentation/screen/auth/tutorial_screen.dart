import 'package:flutter/material.dart';

import '../../../core/constants/colors.dart';
import '../../../services/onboarding_service.dart';

class TutorialScreen extends StatefulWidget {
  const TutorialScreen({super.key, required this.onComplete});

  final VoidCallback onComplete;

  @override
  State<TutorialScreen> createState() => _TutorialScreenState();
}

class _TutorialScreenState extends State<TutorialScreen> {
  final controller = PageController();
  final onboardingService = OnboardingService();
  int page = 0;
  bool completing = false;

  static const pages = [
    _TutorialPageData(
      icon: Icons.pets,
      title: 'Meet Oren',
      body:
          'Tap Oren once per day to complete your safety check-in. Your streak and rewards grow when you keep checking in.',
      color: AppColors.primary,
    ),
    _TutorialPageData(
      icon: Icons.cloud_outlined,
      title: 'Weather-Aware Home',
      body:
          'Oren uses your Malaysia location to show local weather and change the background for rain, night, sunset, and daytime.',
      color: AppColors.blue,
    ),
    _TutorialPageData(
      icon: Icons.people_outline,
      title: 'Trusted Contacts',
      body:
          'Add family members or caregivers as emergency contacts. Mark one as primary so they are prioritized during SOS follow-up.',
      color: AppColors.purple,
    ),
    _TutorialPageData(
      icon: Icons.sos,
      title: 'SOS Emergency',
      body:
          'Use SOS only when you need help. EthernaCare records the alert and location when permission is available. For immediate danger in Malaysia, call 999.',
      color: AppColors.danger,
    ),
    _TutorialPageData(
      icon: Icons.card_giftcard_outlined,
      title: 'Rewards & Planning',
      body:
          'Check your next reward, update your profile, and keep legacy planning details or documents ready for trusted people.',
      color: AppColors.accent,
    ),
  ];

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    setState(() => completing = true);
    await onboardingService.markTutorialComplete();
    if (mounted) widget.onComplete();
  }

  void _next() {
    if (page == pages.length - 1) {
      _finish();
      return;
    }
    controller.nextPage(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final lastPage = page == pages.length - 1;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 18, 22, 24),
          child: Column(
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Quick Guide',
                      style: TextStyle(
                        color: AppColors.ink,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: completing ? null : _finish,
                    child: const Text('Skip'),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Expanded(
                child: PageView.builder(
                  controller: controller,
                  itemCount: pages.length,
                  onPageChanged: (value) => setState(() => page = value),
                  itemBuilder: (context, index) {
                    final data = pages[index];
                    return _TutorialPage(data: data);
                  },
                ),
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var index = 0; index < pages.length; index++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: index == page ? 24 : 8,
                      height: 8,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: index == page
                            ? AppColors.primary
                            : AppColors.border,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: completing ? null : _next,
                icon: completing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        lastPage
                            ? Icons.check_circle_outline
                            : Icons.arrow_forward,
                      ),
                label: Text(lastPage ? 'Start Using EthernaCare' : 'Next'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TutorialPage extends StatelessWidget {
  const _TutorialPage({required this.data});

  final _TutorialPageData data;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 126,
          height: 126,
          decoration: BoxDecoration(
            color: data.color.withValues(alpha: .12),
            borderRadius: BorderRadius.circular(28),
          ),
          child: Icon(data.icon, color: data.color, size: 62),
        ),
        const SizedBox(height: 30),
        Text(
          data.title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppColors.ink,
            fontSize: 28,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 14),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 430),
          child: Text(
            data.body,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.muted,
              fontSize: 15,
              height: 1.45,
            ),
          ),
        ),
      ],
    );
  }
}

class _TutorialPageData {
  const _TutorialPageData({
    required this.icon,
    required this.title,
    required this.body,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String body;
  final Color color;
}
