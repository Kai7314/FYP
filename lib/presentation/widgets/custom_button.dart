import 'package:flutter/material.dart';

class CustomButton extends StatelessWidget {
  const CustomButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.loading = false,
    this.danger = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool loading;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final child = loading
        ? const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : Text(label);

    if (icon == null) {
      return FilledButton(
        onPressed: loading ? null : onPressed,
        style: danger
            ? FilledButton.styleFrom(backgroundColor: Colors.red.shade700)
            : null,
        child: child,
      );
    }

    return FilledButton.icon(
      onPressed: loading ? null : onPressed,
      icon: loading ? const SizedBox.shrink() : Icon(icon),
      label: child,
      style: danger
          ? FilledButton.styleFrom(backgroundColor: Colors.red.shade700)
          : null,
    );
  }
}
