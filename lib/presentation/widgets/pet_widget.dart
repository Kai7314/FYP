import 'package:flutter/material.dart';

import '../screen/home/virtual_pet_widget.dart';

class PetWidget extends StatelessWidget {
  const PetWidget({
    super.key,
    required this.streak,
    required this.hasCheckedInToday,
  });

  final int streak;
  final bool hasCheckedInToday;

  @override
  Widget build(BuildContext context) {
    return VirtualPetWidget(
      streak: streak,
      hasCheckedInToday: hasCheckedInToday,
    );
  }
}
