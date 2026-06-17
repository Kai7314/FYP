import 'package:flutter/material.dart';

class PetButton extends StatelessWidget {
  const PetButton({super.key, required this.onPressed, required this.loading});

  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: loading ? null : onPressed,
      icon: loading
          ? const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 3),
            )
          : const Icon(Icons.pets, size: 28),
      label: Text(loading ? 'Checking in...' : 'Pet the Cat'),
    );
  }
}
