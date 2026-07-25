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
    this.activeToyId,
    this.activeToyAsset,
    this.onOpenShop,
    this.onTap,
    this.loading = false,
    this.energy = 65,
    this.tokens = 0,
  });

  final int streak;
  final bool hasCheckedInToday;
  final WeatherSnapshot? weather;
  final String mood;
  final String? lastAction;
  final String? activeToyId;
  final String? activeToyAsset;
  final VoidCallback? onOpenShop;
  final VoidCallback? onTap;
  final bool loading;
  final int energy;
  final int tokens;

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
    final playful = moodText == 'playful' || widget.activeToyId != null;
    final energetic = moodText == 'energetic' || widget.energy >= 90;
    final tired = moodText == 'tired' || widget.energy <= 25;
    final loved = moodText == 'loved' || moodText == 'happy';
    final catAsset = eating
        ? 'lib/assets/images/pixel/oren_pixel_eating_transparent.png'
        : loved || playful || energetic
        ? 'lib/assets/images/pixel/oren_pixel_full_energy_transparent.png'
        : tired
        ? 'lib/assets/images/pixel/oren_pixel_tired_transparent.png'
        : 'lib/assets/images/pixel/oren_pixel_calm_transparent.png';
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
            height: 306,
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
            child: LayoutBuilder(
              builder: (context, constraints) {
                final sceneWidth = math.min(constraints.maxWidth, 720.0);
                return Center(
                  child: SizedBox(
                    width: sceneWidth,
                    height: 306,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 500),
                          layoutBuilder: (currentChild, previousChildren) =>
                              Stack(
                                fit: StackFit.expand,
                                children: [...previousChildren, ?currentChild],
                              ),
                          child: SizedBox.expand(
                            key: ValueKey(
                              widget.weather?.backgroundAsset ?? 'day',
                            ),
                            child: Image.asset(
                              widget.weather?.backgroundAsset ??
                                  'lib/assets/images/pixel/pixel_day.png',
                              fit: BoxFit.cover,
                              filterQuality: FilterQuality.none,
                            ),
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
                              final progress =
                                  idleController.value * math.pi * 2;
                              final bobSize = tired
                                  ? 1.2
                                  : energetic
                                  ? 7.0
                                  : playful
                                  ? 5.0
                                  : 4.0;
                              var horizontalMotion = 0.0;
                              var playLift = 0.0;
                              var playRotation = 0.0;
                              switch (widget.activeToyId) {
                                case 'yarn_ball':
                                  horizontalMotion = math.sin(progress) * 18;
                                  playLift = -math.sin(progress).abs() * 8;
                                  playRotation = math.sin(progress) * .035;
                                  break;
                                case 'fish_plush':
                                  horizontalMotion = math.sin(progress) * 5;
                                  playRotation = math.sin(progress) * .018;
                                  break;
                                case 'feather_wand':
                                  horizontalMotion = math.sin(progress) * 12;
                                  playLift = -math.sin(progress).abs() * 15;
                                  playRotation = math.sin(progress) * .06;
                                  break;
                                default:
                                  break;
                              }
                              final bob = math.sin(progress) * bobSize;
                              return Transform.translate(
                                offset: Offset(
                                  horizontalMotion,
                                  bob + playLift,
                                ),
                                child: Transform.rotate(
                                  angle: playRotation,
                                  child: child,
                                ),
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
                        if (widget.activeToyAsset != null &&
                            widget.activeToyId != null)
                          Positioned(
                            left: 32,
                            right: 32,
                            top: 92,
                            bottom: 48,
                            child: IgnorePointer(
                              child: _AnimatedToy(
                                id: widget.activeToyId!,
                                asset: widget.activeToyAsset!,
                                animation: idleController,
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
                                text: 'Status: $status',
                                icon: _statusIcon(status),
                              ),
                              const Spacer(),
                              Flexible(
                                child: Align(
                                  alignment: Alignment.topRight,
                                  child: _Badge(
                                    text: widget.weather == null
                                        ? 'Weather unavailable'
                                        : widget.weather!.compactMalaysiaRegion,
                                    icon: Icons.cloud_outlined,
                                    alignRight: true,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Positioned(
                          top: 50,
                          right: 12,
                          child: FilledButton.icon(
                            onPressed: widget.onOpenShop,
                            icon: const Icon(
                              Icons.storefront_outlined,
                              size: 18,
                            ),
                            label: const Text('Shop'),
                            style: FilledButton.styleFrom(
                              minimumSize: const Size(0, 38),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                        Positioned(
                          top: 94,
                          left: 12,
                          child: _TokenChip(tokens: widget.tokens),
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
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  String _statusLabel(String moodText, bool loved, bool energetic, bool tired) {
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
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 230),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: alignRight
              ? MainAxisAlignment.end
              : MainAxisAlignment.start,
          children: [
            Icon(
              icon,
              size: 14,
              color: Colors.white,
              shadows: _sceneTextShadows,
            ),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                text,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: alignRight ? TextAlign.right : TextAlign.left,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  shadows: _sceneTextShadows,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnimatedToy extends StatelessWidget {
  const _AnimatedToy({
    required this.id,
    required this.asset,
    required this.animation,
  });

  final String id;
  final String asset;
  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      key: ValueKey('$id-$asset'),
      animation: animation,
      builder: (context, child) {
        final progress = animation.value * math.pi * 2;
        final motion = switch (id) {
          'yarn_ball' => (
            alignment: Alignment.bottomCenter,
            offset: Offset(
              math.sin(progress) * 66,
              -math.cos(progress).abs() * 18,
            ),
            angle: progress * .42,
            scale: .88,
          ),
          'fish_plush' => (
            alignment: const Alignment(.58, .5),
            offset: Offset(0, math.sin(progress) * 6),
            angle: math.sin(progress) * .1,
            scale: .82 + math.sin(progress).abs() * .05,
          ),
          'feather_wand' => (
            alignment: Alignment.topCenter,
            offset: Offset(
              58 + math.sin(progress) * 42,
              10 + math.cos(progress) * 12,
            ),
            angle: -.5 + math.sin(progress) * .34,
            scale: .88,
          ),
          _ => (
            alignment: Alignment.bottomRight,
            offset: Offset(0, math.sin(progress) * 8),
            angle: math.sin(progress) * .1,
            scale: .86,
          ),
        };
        return Align(
          alignment: motion.alignment,
          child: Transform.translate(
            offset: motion.offset,
            child: Transform.rotate(
              angle: motion.angle,
              child: Transform.scale(scale: motion.scale, child: child),
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

class _TokenChip extends StatelessWidget {
  const _TokenChip({required this.tokens});

  final int tokens;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            'lib/assets/images/pixel/oren_pixel_token_transparent.png',
            width: 22,
            height: 22,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.none,
          ),
          const SizedBox(width: 5),
          Text(
            '$tokens',
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w900,
              shadows: _sceneTextShadows,
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
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 280),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Text(
          text,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w900,
            shadows: _sceneTextShadows,
          ),
        ),
      ),
    );
  }
}

const _sceneTextShadows = <Shadow>[
  Shadow(color: Color(0xB3000000), blurRadius: 3, offset: Offset(0, 1)),
];
