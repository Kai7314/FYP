import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/constants/colors.dart';
import '../../../models/location_model.dart';

class VirtualPetWidget extends StatefulWidget {
  const VirtualPetWidget({
    super.key,
    required this.streak,
    required this.hasCheckedInToday,
    this.weather,
    this.mood = 'Calm',
    this.lastAction,
    this.activeToyAsset,
    this.onTap,
    this.loading = false,
    this.energy = 65,
  });

  final int streak;
  final bool hasCheckedInToday;
  final WeatherSnapshot? weather;
  final String mood;
  final String? lastAction;
  final String? activeToyAsset;
  final VoidCallback? onTap;
  final bool loading;
  final int energy;

  @override
  State<VirtualPetWidget> createState() => _VirtualPetWidgetState();
}

class _VirtualPetWidgetState extends State<VirtualPetWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController idleController;

  @override
  void initState() {
    super.initState();
    idleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();
  }

  @override
  void dispose() {
    idleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final moodText = widget.mood.toLowerCase();
    final eating = moodText == 'eating';
    final playful = moodText == 'playful';
    final energetic = moodText == 'energetic' || widget.energy >= 90;
    final tired = moodText == 'tired' || widget.energy <= 25;
    final loved = moodText == 'loved' || moodText == 'happy';
    final catAsset = eating
        ? 'lib/assets/images/pixel/oren_pixel_eating.png'
        : loved || playful || energetic
        ? 'lib/assets/images/pixel/oren_pixel_full_energy.png'
        : tired
        ? 'lib/assets/images/pixel/oren_pixel_tired.png'
        : 'lib/assets/images/pixel/oren_pixel_calm.png';
    final status = _statusLabel(moodText, loved, energetic, tired);

    final enabled = widget.onTap != null && !widget.loading;

    return Semantics(
      button: widget.onTap != null,
      label: widget.loading ? 'Checking in with Oren' : 'Check in with Oren',
      child: MouseRegion(
        cursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: enabled ? widget.onTap : null,
          child: Container(
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
                    widget.weather?.backgroundAsset ??
                        'lib/assets/images/pixel/pixel_day.png',
                    key: ValueKey(widget.weather?.backgroundAsset ?? 'day'),
                    fit: BoxFit.cover,
                    filterQuality: FilterQuality.none,
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
                  child: AnimatedBuilder(
                    animation: idleController,
                    builder: (context, child) {
                      final bobSize = tired
                          ? 1.2
                          : energetic
                          ? 7.0
                          : playful
                          ? 5.0
                          : 4.0;
                      final bob =
                          math.sin(idleController.value * math.pi * 2) *
                          bobSize;
                      return Transform.translate(
                        offset: Offset(0, bob),
                        child: child,
                      );
                    },
                    child: AnimatedRotation(
                      duration: const Duration(milliseconds: 350),
                      turns: tired
                          ? .015
                          : playful || energetic
                          ? -.025
                          : 0,
                      child: AnimatedScale(
                        duration: const Duration(milliseconds: 350),
                        scale: eating
                            ? 1.16
                            : energetic
                            ? 1.14
                            : playful
                            ? 1.12
                            : loved
                            ? 1.08
                            : tired
                            ? .94
                            : 1,
                        child: Opacity(
                          opacity: tired ? .76 : 1,
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 260),
                            transitionBuilder: (child, animation) =>
                                FadeTransition(
                                  opacity: animation,
                                  child: ScaleTransition(
                                    scale: animation,
                                    child: child,
                                  ),
                                ),
                            child: Image.asset(
                              catAsset,
                              key: ValueKey('$catAsset-$status'),
                              height: 150,
                              fit: BoxFit.contain,
                              filterQuality: FilterQuality.none,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                if (energetic || tired || playful)
                  Positioned(
                    left: 28,
                    right: 28,
                    top: 72,
                    child: IgnorePointer(
                      child: _OrenStatusEffect(
                        energetic: energetic,
                        tired: tired,
                        playful: playful,
                      ),
                    ),
                  ),
                Positioned(
                  top: 48,
                  left: 12,
                  child: _EnergyChip(energy: widget.energy),
                ),
                if (widget.activeToyAsset != null)
                  Positioned(
                    right: 30,
                    bottom: 62,
                    child: _FloatingToy(asset: widget.activeToyAsset!),
                  ),
                Positioned(
                  top: 12,
                  left: 12,
                  right: 12,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Badge(
                        text: 'Status: $status',
                        icon: _statusIcon(status),
                      ),
                      const Spacer(),
                      Flexible(
                        child: _Badge(
                          text: widget.weather == null
                              ? 'Weather unavailable'
                              : widget.weather!.compactMalaysiaRegion,
                          icon: Icons.cloud_outlined,
                          alignRight: true,
                        ),
                      ),
                    ],
                  ),
                ),
                if (widget.lastAction != null &&
                    widget.lastAction!.trim().isNotEmpty)
                  Positioned(
                    left: 12,
                    right: 12,
                    bottom: 52,
                    child: Center(
                      child: _SpeechBubble(text: widget.lastAction!),
                    ),
                  ),
                Positioned(
                  bottom: 12,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: _Badge(
                      text: 'Oren care streak: ${widget.streak} days',
                      icon: Icons.pets,
                    ),
                  ),
                ),
                if (widget.loading)
                  Positioned.fill(
                    child: ColoredBox(
                      color: Colors.black.withValues(alpha: .14),
                      child: Center(
                        child: Container(
                          width: 54,
                          height: 54,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: .92),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: const CircularProgressIndicator(
                            strokeWidth: 3,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _statusLabel(
    String moodText,
    bool loved,
    bool energetic,
    bool tired,
  ) {
    if (moodText == 'eating') return 'Eating';
    if (energetic) return 'Full energy';
    if (tired) return 'Tired';
    if (moodText == 'playful') return 'Playful';
    if (loved) return 'Loved';
    if (moodText == 'curious') return 'Curious';
    if (moodText == 'happy') return 'Happy';
    return 'Calm';
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'Full energy':
        return Icons.bolt_rounded;
      case 'Tired':
        return Icons.bedtime_outlined;
      case 'Eating':
        return Icons.set_meal_outlined;
      case 'Playful':
        return Icons.auto_awesome;
      case 'Loved':
        return Icons.favorite_border;
      default:
        return Icons.pets;
    }
  }
}

class _OrenStatusEffect extends StatelessWidget {
  const _OrenStatusEffect({
    required this.energetic,
    required this.tired,
    required this.playful,
  });

  final bool energetic;
  final bool tired;
  final bool playful;

  @override
  Widget build(BuildContext context) {
    if (tired) {
      return const Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          _FloatingGlyph(text: 'z', delay: 0),
          SizedBox(width: 10),
          _FloatingGlyph(text: 'Z', delay: 120),
          SizedBox(width: 6),
          _FloatingGlyph(text: 'Z', delay: 240),
        ],
      );
    }

    final color = energetic ? AppColors.accent : AppColors.primary;
    final icons = energetic
        ? const [Icons.bolt_rounded, Icons.auto_awesome, Icons.bolt_rounded]
        : const [Icons.auto_awesome, Icons.favorite, Icons.auto_awesome];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: icons
          .map((icon) => Icon(icon, color: color, size: energetic ? 24 : 18))
          .toList(),
    );
  }
}

class _FloatingGlyph extends StatelessWidget {
  const _FloatingGlyph({required this.text, required this.delay});

  final String text;
  final int delay;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 900 + delay),
      curve: Curves.easeOut,
      builder: (context, value, child) {
        return Opacity(
          opacity: (1 - value).clamp(.25, .9),
          child: Transform.translate(
            offset: Offset(0, -10 * value),
            child: child,
          ),
        );
      },
      child: Text(
        text,
        style: const TextStyle(
          color: AppColors.ink,
          fontSize: 18,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _EnergyChip extends StatelessWidget {
  const _EnergyChip({required this.energy});

  final int energy;

  @override
  Widget build(BuildContext context) {
    final color = energy >= 90
        ? AppColors.accent
        : energy <= 25
        ? AppColors.muted
        : AppColors.primary;
    final label = energy >= 90
        ? 'Full'
        : energy <= 25
        ? 'Low'
        : '$energy%';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .92),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.battery_charging_full_rounded, size: 14, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
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

class _FloatingToy extends StatelessWidget {
  const _FloatingToy({required this.asset});

  final String asset;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      key: ValueKey(asset),
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 520),
      curve: Curves.easeOutBack,
      builder: (context, value, child) {
        return Opacity(
          opacity: value.clamp(0, 1),
          child: Transform.translate(
            offset: Offset(0, (1 - value) * 16),
            child: Transform.rotate(
              angle: math.sin(value * math.pi) * .12,
              child: Transform.scale(scale: .82 + value * .18, child: child),
            ),
          ),
        );
      },
      child: Image.asset(
        asset,
        width: 86,
        height: 86,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.none,
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
