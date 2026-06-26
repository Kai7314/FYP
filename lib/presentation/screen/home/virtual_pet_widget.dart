import 'package:flutter/material.dart';

import '../../../core/constants/colors.dart';
import '../../../models/location_model.dart';

class VirtualPetWidget extends StatelessWidget {
  const VirtualPetWidget({
    super.key,
    required this.streak,
    required this.hasCheckedInToday,
    this.weather,
    this.mood = 'Calm',
    this.lastAction,
  });

  final int streak;
  final bool hasCheckedInToday;
  final WeatherSnapshot? weather;
  final String mood;
  final String? lastAction;

  @override
  Widget build(BuildContext context) {
    final moodText = mood.toLowerCase();
    final eating = moodText == 'eating';
    final playful = moodText == 'playful';
    final loved = moodText == 'loved' || hasCheckedInToday;
    final catAsset = eating
        ? 'lib/assets/images/eating.png'
        : loved
        ? 'lib/assets/images/smile.png'
        : 'lib/assets/images/oren.png';

    return Container(
      height: 270,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
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
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 500),
            child: Image.asset(
              weather?.backgroundAsset ?? 'lib/assets/images/day.jpg',
              key: ValueKey(weather?.backgroundAsset ?? 'day'),
              fit: BoxFit.cover,
            ),
          ),
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0x08000000), Color(0x33000000)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          Align(
            alignment: const Alignment(0, .28),
            child: AnimatedRotation(
              duration: const Duration(milliseconds: 350),
              turns: playful ? -.025 : 0,
              child: AnimatedScale(
                duration: const Duration(milliseconds: 350),
                scale: eating
                    ? 1.16
                    : playful
                    ? 1.12
                    : loved
                    ? 1.08
                    : 1,
                child: Image.asset(catAsset, height: 150, fit: BoxFit.contain),
              ),
            ),
          ),
          Positioned(
            top: 12,
            left: 12,
            right: 12,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Badge(
                  text: 'Mood: ${_label(moodText, loved)}',
                  icon: Icons.favorite_border,
                ),
                const Spacer(),
                Flexible(
                  child: _Badge(
                    text: weather == null
                        ? 'Weather unavailable'
                        : '${weather!.malaysiaRegion}: ${weather!.description} ${weather!.temperatureCelsius.round()} C',
                    icon: Icons.cloud_outlined,
                    alignRight: true,
                  ),
                ),
              ],
            ),
          ),
          if (lastAction != null && lastAction!.trim().isNotEmpty)
            Positioned(
              left: 12,
              right: 12,
              bottom: 52,
              child: Center(
                child: _SpeechBubble(text: lastAction!),
              ),
            ),
          Positioned(
            bottom: 12,
            left: 0,
            right: 0,
            child: Center(
              child: _Badge(
                text: 'Oren care streak: $streak days',
                icon: Icons.pets,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _label(String moodText, bool loved) {
    if (moodText == 'eating') return 'Eating';
    if (moodText == 'playful') return 'Playful';
    if (loved) return 'Loved';
    if (moodText == 'curious') return 'Curious';
    if (moodText == 'happy') return 'Happy';
    return 'Calm';
  }
}

class _Badge extends StatelessWidget {
  const _Badge({
    required this.text,
    required this.icon,
    this.alignRight = false,
  });

  final String text;
  final IconData icon;
  final bool alignRight;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 230),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .9),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: alignRight
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        children: [
          Icon(icon, size: 13, color: AppColors.primaryDark),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: alignRight ? TextAlign.right : TextAlign.left,
              style: const TextStyle(
                color: AppColors.ink,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SpeechBubble extends StatelessWidget {
  const _SpeechBubble({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 280),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .94),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        text,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: AppColors.ink,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
