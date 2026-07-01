import 'package:flutter/material.dart';

import '../../../core/constants/colors.dart';
import '../../../services/onboarding_service.dart';
import '../../widgets/premium_shell.dart';

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
    _CoachStepData(
      title: 'Meet Oren',
      body:
          'This is your daily companion. Tap Oren once a day to send a safe check-in and keep your streak alive.',
      target: _CoachTarget.oren,
      bubbleAlignment: Alignment.bottomCenter,
      color: AppColors.primary,
    ),
    _CoachStepData(
      title: 'Check Your Safety Signal',
      body:
          'Your check-in status updates here. A completed check-in lets trusted people know your day is going well.',
      target: _CoachTarget.checkin,
      bubbleAlignment: Alignment.topCenter,
      color: AppColors.accent,
    ),
    _CoachStepData(
      title: 'Emergency Contacts',
      body:
          'Add family members or caregivers here. Mark one as primary so SOS follow-up knows who to prioritize.',
      target: _CoachTarget.contacts,
      bubbleAlignment: Alignment.bottomCenter,
      color: AppColors.purple,
    ),
    _CoachStepData(
      title: 'SOS Emergency',
      body:
          'Use SOS only when you need help. The app records the alert and location when permission is available. In Malaysia, call 999 for immediate danger.',
      target: _CoachTarget.sos,
      bubbleAlignment: Alignment.topCenter,
      color: AppColors.danger,
    ),
    _CoachStepData(
      title: 'Rewards & Profile',
      body:
          'Keep checking in to unlock rewards. Your profile stores important safety and medical details for better follow-up.',
      target: _CoachTarget.rewards,
      bubbleAlignment: Alignment.topCenter,
      color: AppColors.blue,
    ),
  ];

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    if (completing) return;
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
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final lastPage = page == pages.length - 1;
    final width = MediaQuery.sizeOf(context).width;
    final compact = width < 370;

    return PremiumScaffold(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 20),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Quick Guide',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
              TextButton(
                onPressed: completing ? null : _finish,
                child: const Text('Skip'),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Expanded(
            child: PageView.builder(
              controller: controller,
              itemCount: pages.length,
              onPageChanged: (value) => setState(() => page = value),
              itemBuilder: (context, index) {
                return _CoachStep(
                  data: pages[index],
                  compact: compact,
                  step: index + 1,
                  totalSteps: pages.length,
                );
              },
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    for (var index = 0; index < pages.length; index++)
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        width: index == page ? 26 : 8,
                        height: 8,
                        margin: const EdgeInsets.only(right: 6),
                        decoration: BoxDecoration(
                          color: index == page
                              ? pages[page].color
                              : AppColors.border,
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                  ],
                ),
              ),
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
                label: Text(lastPage ? 'Start' : 'Next'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CoachStep extends StatelessWidget {
  const _CoachStep({
    required this.data,
    required this.compact,
    required this.step,
    required this.totalSteps,
  });

  final _CoachStepData data;
  final bool compact;
  final int step;
  final int totalSteps;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final phoneHeight = (constraints.maxHeight * .84).clamp(430.0, 620.0);
        final phoneWidth = (phoneHeight * .49).clamp(220.0, 300.0);
        return Column(
          children: [
            Text(
              data.title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                fontSize: compact ? 28 : 32,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Step $step of $totalSteps',
              style: const TextStyle(
                color: AppColors.muted,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 14),
            Expanded(
              child: Center(
                child: SizedBox(
                  width: phoneWidth,
                  height: phoneHeight,
                  child: _PhoneCoachPreview(data: data),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _PhoneCoachPreview extends StatelessWidget {
  const _PhoneCoachPreview({required this.data});

  final _CoachStepData data;

  @override
  Widget build(BuildContext context) {
    final target = _targetRect(data.target);
    final bubbleTop = data.bubbleAlignment == Alignment.topCenter;

    return Container(
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: AppColors.ink,
        borderRadius: BorderRadius.circular(32),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 26,
            offset: Offset(0, 16),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            const _MockHomeScreen(),
            Positioned.fill(
              child: Container(color: Colors.black.withValues(alpha: .48)),
            ),
            Positioned.fromRect(
              rect: target,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: data.color, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: data.color.withValues(alpha: .44),
                      blurRadius: 22,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              left: 14,
              right: 14,
              top: bubbleTop ? 62 : null,
              bottom: bubbleTop ? null : 72,
              child: _CoachBubble(data: data, pointUp: !bubbleTop),
            ),
            Positioned(
              top: 10,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  width: 72,
                  height: 20,
                  decoration: BoxDecoration(
                    color: AppColors.ink,
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Rect _targetRect(_CoachTarget target) {
    return switch (target) {
      _CoachTarget.oren => const Rect.fromLTWH(38, 116, 168, 176),
      _CoachTarget.checkin => const Rect.fromLTWH(22, 302, 200, 64),
      _CoachTarget.contacts => const Rect.fromLTWH(88, 468, 42, 40),
      _CoachTarget.sos => const Rect.fromLTWH(24, 370, 198, 50),
      _CoachTarget.rewards => const Rect.fromLTWH(132, 468, 42, 40),
    };
  }
}

class _CoachBubble extends StatelessWidget {
  const _CoachBubble({required this.data, required this.pointUp});

  final _CoachStepData data;
  final bool pointUp;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (pointUp) _BubblePointer(color: AppColors.ink),
        Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: AppColors.ink.withValues(alpha: .96),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white.withValues(alpha: .12)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: data.color,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.auto_awesome, color: Colors.white, size: 16),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  data.body,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12.5,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (!pointUp) _BubblePointer(color: AppColors.ink, flip: true),
      ],
    );
  }
}

class _BubblePointer extends StatelessWidget {
  const _BubblePointer({required this.color, this.flip = false});

  final Color color;
  final bool flip;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: flip ? 3.14159 : 0,
      child: CustomPaint(
        size: const Size(20, 9),
        painter: _TrianglePainter(color),
      ),
    );
  }
}

class _TrianglePainter extends CustomPainter {
  const _TrianglePainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width / 2, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = color.withValues(alpha: .96));
  }

  @override
  bool shouldRepaint(covariant _TrianglePainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

class _MockHomeScreen extends StatelessWidget {
  const _MockHomeScreen();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: AppColors.appGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 42, 18, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Good Morning',
              style: TextStyle(
                color: AppColors.muted,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 3),
            const Text(
              'Hi, Kai Heng',
              style: TextStyle(
                color: AppColors.ink,
                fontSize: 19,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 14),
            _MockOrenCard(),
            const SizedBox(height: 10),
            _MockStatusCard(),
            const SizedBox(height: 10),
            _MockActionButton(
              icon: Icons.pets,
              label: 'Pet Oren & Check In',
              color: AppColors.primary,
            ),
            const SizedBox(height: 8),
            _MockActionButton(
              icon: Icons.sos,
              label: 'SOS Emergency',
              color: AppColors.danger,
            ),
            const Spacer(),
            _MockNavBar(),
          ],
        ),
      ),
    );
  }
}

class _MockOrenCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 176,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFBFEFD9), Color(0xFFE8F6FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Stack(
        children: [
          Positioned(
            right: 14,
            top: 14,
            child: _MockPill(label: 'Mood: Happy', color: AppColors.primary),
          ),
          Center(
            child: Container(
              width: 86,
              height: 86,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .9),
                shape: BoxShape.circle,
              ),
              child: Image.asset('lib/assets/images/oren.png', fit: BoxFit.contain),
            ),
          ),
        ],
      ),
    );
  }
}

class _MockStatusCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .9),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.warningSoft,
            child: Icon(Icons.warning_amber_rounded, color: AppColors.accent, size: 19),
          ),
          SizedBox(width: 9),
          Expanded(
            child: Text(
              'Oren is waiting for you',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }
}

class _MockActionButton extends StatelessWidget {
  const _MockActionButton({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: .24)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _MockNavBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    const items = [
      Icons.home_rounded,
      Icons.check_circle_outline,
      Icons.people_outline,
      Icons.card_giftcard_outlined,
      Icons.person_outline,
    ];
    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .92),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          for (final icon in items)
            Icon(icon, size: 19, color: icon == Icons.home_rounded ? AppColors.primary : AppColors.muted),
        ],
      ),
    );
  }
}

class _MockPill extends StatelessWidget {
  const _MockPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .82),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _CoachStepData {
  const _CoachStepData({
    required this.title,
    required this.body,
    required this.target,
    required this.bubbleAlignment,
    required this.color,
  });

  final String title;
  final String body;
  final _CoachTarget target;
  final Alignment bubbleAlignment;
  final Color color;
}

enum _CoachTarget { oren, checkin, contacts, sos, rewards }
