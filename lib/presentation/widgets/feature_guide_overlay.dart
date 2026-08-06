import 'package:flutter/material.dart';

import '../../core/constants/colors.dart';

class FeatureGuideStep {
  const FeatureGuideStep({
    required this.pageIndex,
    required this.pageLabel,
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
  });

  final int pageIndex;
  final String pageLabel;
  final String title;
  final String description;
  final IconData icon;
  final Color color;
}

class FeatureGuideOverlay extends StatelessWidget {
  const FeatureGuideOverlay({
    super.key,
    required this.steps,
    required this.currentStep,
    required this.onNext,
    required this.onBack,
    required this.onSkip,
  });

  final List<FeatureGuideStep> steps;
  final int currentStep;
  final VoidCallback onNext;
  final VoidCallback? onBack;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final step = steps[currentStep];
    final lastStep = currentStep == steps.length - 1;

    return Material(
      key: const Key('live-feature-guide-overlay'),
      color: Colors.transparent,
      child: Stack(
        children: [
          const Positioned.fill(
            child: ModalBarrier(
              dismissible: false,
              color: Color(0x4D071D17),
            ),
          ),
          SafeArea(
            minimum: const EdgeInsets.fromLTRB(16, 12, 16, 92),
            child: Column(
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x22000000),
                              blurRadius: 10,
                              offset: Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.visibility_outlined,
                              size: 18,
                              color: step.color,
                            ),
                            const SizedBox(width: 7),
                            Flexible(
                              child: Text(
                                'Live ${step.pageLabel} screen',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: AppColors.ink,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      key: const Key('feature-guide-skip'),
                      onPressed: onSkip,
                      style: TextButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppColors.ink,
                      ),
                      child: const Text('Skip'),
                    ),
                  ],
                ),
                const Spacer(),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  child: Container(
                    key: ValueKey(currentStep),
                    width: double.infinity,
                    constraints: const BoxConstraints(maxWidth: 620),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: step.color.withValues(alpha: .45),
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x33000000),
                          blurRadius: 20,
                          offset: Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: step.color.withValues(alpha: .12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(step.icon, color: step.color),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Step ${currentStep + 1} of ${steps.length}',
                                    style: TextStyle(
                                      color: step.color,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    step.title,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleLarge
                                        ?.copyWith(
                                          color: AppColors.ink,
                                          fontWeight: FontWeight.w900,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          step.description,
                          style: const TextStyle(
                            color: AppColors.muted,
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            if (onBack != null)
                              IconButton.outlined(
                                key: const Key('feature-guide-back'),
                                onPressed: onBack,
                                icon: const Icon(Icons.arrow_back),
                                tooltip: 'Previous step',
                              ),
                            if (onBack != null) const SizedBox(width: 10),
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: LinearProgressIndicator(
                                  value: (currentStep + 1) / steps.length,
                                  minHeight: 7,
                                  color: step.color,
                                  backgroundColor: AppColors.surface,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            FilledButton.icon(
                              key: const Key('feature-guide-next'),
                              onPressed: onNext,
                              icon: Icon(
                                lastStep
                                    ? Icons.check_circle_outline
                                    : Icons.arrow_forward,
                              ),
                              label: Text(lastStep ? 'Finish' : 'Next'),
                              style: FilledButton.styleFrom(
                                backgroundColor: step.color,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
