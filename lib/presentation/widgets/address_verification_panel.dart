import 'package:flutter/material.dart';

import '../../core/constants/colors.dart';

class AddressVerificationPanel extends StatelessWidget {
  const AddressVerificationPanel({
    super.key,
    required this.isVerified,
    required this.isValidating,
    required this.onValidate,
  });

  final bool isVerified;
  final bool isValidating;
  final VoidCallback? onValidate;

  @override
  Widget build(BuildContext context) {
    final color = isVerified ? AppColors.accent : AppColors.muted;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Row(
            children: [
              Icon(
                isVerified ? Icons.verified_outlined : Icons.location_searching,
                color: color,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isVerified
                      ? 'Address verified'
                      : 'Validate before saving',
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        OutlinedButton.icon(
          onPressed: isValidating ? null : onValidate,
          icon: isValidating
              ? const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.location_on_outlined),
          label: Text(isVerified ? 'Revalidate' : 'Validate'),
        ),
      ],
    );
  }
}
