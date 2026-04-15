import 'package:flutter/material.dart';
import '../../../services/checkin_service.dart';
import '../../../services/inactivity_service.dart';
import '../../../services/reward_service.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  Future<void> petCat() async {
    await CheckinService().addCheckin();
    await RewardService().checkReward();
  }

  @override
  Widget build(BuildContext context) {
    // check inactivity every time open screen
    InactivityService().checkInactivity();

    return Scaffold(
      appBar: AppBar(title: const Text("EthernaCare")),
      body: Center(
        child: ElevatedButton(
          onPressed: petCat,
          child: const Text("🐱 Pet Cat (Check-in)"),
        ),
      ),
    );
  }
}
