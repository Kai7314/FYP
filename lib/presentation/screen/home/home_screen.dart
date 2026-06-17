import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/colors.dart';
import '../../../services/checkin_service.dart';
import '../../../services/emergency_service.dart';
import '../../../services/inactivity_service.dart';
import '../../../services/reward_service.dart';
import '../checkin/checkin_history_screen.dart';
import '../contacts/contacts_screen.dart';
import '../profile/profile_screen.dart';
import '../rewards/rewards_screen.dart';
import 'pet_button.dart';
import 'virtual_pet_widget.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final supabase = Supabase.instance.client;
  int selectedIndex = 0;
  bool loading = false;
  int streak = 0;
  int totalCheckins = 0;
  DateTime? lastCheckin;

  @override
  void initState() {
    super.initState();
    _loadDashboard();
    InactivityService().checkInactivity();
  }

  Future<void> petCat() async {
    setState(() => loading = true);
    await CheckinService().addCheckin();
    await RewardService().checkReward();
    await _loadDashboard();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Check-in recorded. Your safety signal was sent.'),
        ),
      );
      setState(() => loading = false);
    }
  }

  Future<void> _loadDashboard() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    final rows = await supabase
        .from('checkins')
        .select()
        .eq('user_id', user.id)
        .order('checkin_time', ascending: false);

    final times = rows
        .map<DateTime?>(
          (row) => DateTime.tryParse(row['checkin_time'].toString()),
        )
        .whereType<DateTime>()
        .toList();

    if (!mounted) return;
    setState(() {
      totalCheckins = times.length;
      lastCheckin = times.isEmpty ? null : times.first;
      streak = _calculateStreak(times);
    });
  }

  int _calculateStreak(List<DateTime> times) {
    final days =
        times
            .map((date) => DateTime(date.year, date.month, date.day))
            .toSet()
            .toList()
          ..sort((a, b) => b.compareTo(a));
    if (days.isEmpty) return 0;

    final today = DateTime.now();
    var cursor = DateTime(today.year, today.month, today.day);
    var count = 0;

    for (final day in days) {
      if (day == cursor) {
        count++;
        cursor = cursor.subtract(const Duration(days: 1));
      } else if (count == 0 &&
          day == cursor.subtract(const Duration(days: 1))) {
        count++;
        cursor = day.subtract(const Duration(days: 1));
      }
    }
    return count;
  }

  Future<void> _triggerSos() async {
    await EmergencyService().triggerEmergency();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Emergency alert logged for your contacts.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      _HomeDashboard(
        loading: loading,
        streak: streak,
        totalCheckins: totalCheckins,
        lastCheckin: lastCheckin,
        onPet: petCat,
        onSos: _triggerSos,
        onRefresh: _loadDashboard,
      ),
      const CheckinHistoryScreen(),
      const ContactsScreen(),
      const RewardsScreen(),
      const ProfileScreen(),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('EthernaCare')),
      body: SafeArea(child: pages[selectedIndex]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: (value) {
          setState(() => selectedIndex = value);
          if (value == 0) _loadDashboard();
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(icon: Icon(Icons.history), label: 'History'),
          NavigationDestination(
            icon: Icon(Icons.contacts_outlined),
            selectedIcon: Icon(Icons.contacts),
            label: 'Contacts',
          ),
          NavigationDestination(
            icon: Icon(Icons.card_giftcard),
            label: 'Rewards',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

class _HomeDashboard extends StatelessWidget {
  const _HomeDashboard({
    required this.loading,
    required this.streak,
    required this.totalCheckins,
    required this.lastCheckin,
    required this.onPet,
    required this.onSos,
    required this.onRefresh,
  });

  final bool loading;
  final int streak;
  final int totalCheckins;
  final DateTime? lastCheckin;
  final VoidCallback onPet;
  final VoidCallback onSos;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final checkedToday =
        lastCheckin != null && DateUtils.isSameDay(lastCheckin, DateTime.now());
    final lastText = lastCheckin == null
        ? 'No check-in yet'
        : DateFormat('dd MMM yyyy, h:mm a').format(lastCheckin!);
    final progress = (streak.clamp(0, 7) / 7).toDouble();

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Well-being Dashboard',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          const Text(
            'Pet your cat once a day to send a safety heartbeat signal.',
          ),
          const SizedBox(height: 18),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  VirtualPetWidget(
                    streak: streak,
                    hasCheckedInToday: checkedToday,
                  ),
                  const SizedBox(height: 18),
                  PetButton(onPressed: onPet, loading: loading),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: onSos,
                    icon: const Icon(Icons.sos),
                    label: const Text('SOS Emergency'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.danger,
                      minimumSize: const Size.fromHeight(52),
                      side: const BorderSide(color: AppColors.danger),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _StatusTile(
            icon: Icons.schedule,
            label: 'Last check-in',
            value: lastText,
          ),
          const SizedBox(height: 10),
          _StatusTile(
            icon: Icons.fact_check,
            label: 'Total check-ins',
            value: totalCheckins.toString(),
          ),
          const SizedBox(height: 16),
          Text(
            'Reward progress',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: progress,
            minHeight: 12,
            borderRadius: BorderRadius.circular(8),
          ),
          const SizedBox(height: 8),
          Text(
            '${(7 - streak).clamp(0, 7)} more daily check-ins to reach the 7-day gift milestone.',
          ),
        ],
      ),
    );
  }
}

class _StatusTile extends StatelessWidget {
  const _StatusTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon, color: AppColors.primary),
        title: Text(label),
        subtitle: Text(
          value,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}
