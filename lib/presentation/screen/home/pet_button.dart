import 'package:flutter/material.dart';

class PetButton extends StatelessWidget {
  const PetButton({super.key, required this.onPressed, required this.loading});

  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: loading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFFF3E7F),
          shadowColor: const Color(0x55FF3E7F),
          elevation: 4,
        ),
        icon: loading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.pets, size: 28),
        label: Text(loading ? 'Checking in...' : 'Pet Oren & Check In'),
      ),
    );
  }
}
