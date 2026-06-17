import 'package:flutter/material.dart';

import '../../../core/constants/colors.dart';

class VirtualPetWidget extends StatelessWidget {
  const VirtualPetWidget({
    super.key,
    required this.streak,
    required this.hasCheckedInToday,
  });

  final int streak;
  final bool hasCheckedInToday;

  @override
  Widget build(BuildContext context) {
    final asset = hasCheckedInToday
        ? 'lib/assets/images/smile.png'
        : 'lib/assets/images/oren.png';

    return Column(
      children: [
        Container(
          width: 220,
          height: 220,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF6DF),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.border),
          ),
          child: Image.asset(asset, fit: BoxFit.contain),
        ),
        const SizedBox(height: 14),
        Text(
          hasCheckedInToday
              ? 'Cat status: Happy and cared for'
              : 'Cat status: Waiting for today',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
            color: AppColors.ink,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '$streak day streak',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: AppColors.primaryDark,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
