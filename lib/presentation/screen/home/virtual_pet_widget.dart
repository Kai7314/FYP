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
    final catAsset = hasCheckedInToday
        ? 'lib/assets/images/smile.png'
        : 'lib/assets/images/oren.png';

    return Container(
      height: 255,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: Color(0x16000000),
            blurRadius: 12,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset('lib/assets/images/day.jpg', fit: BoxFit.cover),
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0x05000000), Color(0x28000000)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          Align(
            alignment: const Alignment(0, .35),
            child: AnimatedScale(
              duration: const Duration(milliseconds: 350),
              scale: hasCheckedInToday ? 1.08 : 1,
              child: Image.asset(catAsset, height: 145, fit: BoxFit.contain),
            ),
          ),
          Positioned(
            bottom: 12,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 13,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .92),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  hasCheckedInToday ? 'Oren 💚' : 'Oren 🐱',
                  style: const TextStyle(
                    color: AppColors.primaryDark,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
