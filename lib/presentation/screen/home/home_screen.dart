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
  int selectedIndex = 0;
  bool loading = false;
  int streak = 0;
  int totalCheckins = 0;
  DateTime? lastCheckin;
  String userName = 'EthernaCare User';
  String? loadError;

  @override
  void initState() {
    super.initState();
    _loadDashboard();
    InactivityService().checkInactivity().catchError((_) {});
  }

  Future<void> petCat() async {
    setState(() => loading = true);
    try {
      final created = await CheckinService().addCheckin();
      if (created) await RewardService().checkReward();
      await _loadDashboard();
      if (!mounted) return;
      _showMessage(
        created
            ? 'Check-in recorded. Your safety signal was sent.'
            : 'You have already checked in today.',
      );
    } catch (error) {
      if (mounted) _showMessage('Could not record check-in: $error');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _loadDashboard() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
      final results = await Future.wait([
        Supabase.instance.client
            .from('checkins')
            .select()
            .eq('user_id', user.id)
            .order('checkin_time', ascending: false),
        Supabase.instance.client
            .from('users')
            .select()
            .eq('id', user.id)
            .limit(1),
      ]);
      final rows = results[0];
      final profiles = results[1];
      final times = rows
          .map<DateTime?>(
            (row) => DateTime.tryParse(row['checkin_time'].toString()),
          )
          .whereType<DateTime>()
          .toList();
      final profileName = profiles.isNotEmpty
          ? profiles.first['name']?.toString()
          : null;

      if (!mounted) return;
      setState(() {
        userName = profileName == null || profileName.trim().isEmpty
            ? (user.email?.split('@').first ?? 'EthernaCare User')
            : profileName;
        totalCheckins = times.length;
        lastCheckin = times.isEmpty ? null : times.first;
        streak = RewardService.calculateStreak(times);
        loadError = null;
      });
    } catch (_) {
      if (mounted) {
        setState(() => loadError = 'Unable to refresh dashboard data.');
      }
    }
  }

  Future<void> _triggerSos() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.sos, color: AppColors.danger, size: 40),
        title: const Text('Send emergency alert?'),
        content: const Text(
          'An emergency record will be created and your location will be attached when permission is available.',
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text('Send Alert'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      final sent = await EmergencyService().triggerEmergency();
      if (!mounted) return;
      _showMessage(
        sent
            ? 'Emergency alert recorded for your trusted contacts.'
            : 'Add an emergency contact before sending an alert.',
      );
    } catch (error) {
      if (mounted) _showMessage('Could not send emergency alert: $error');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      _HomeDashboard(
        loading: loading,
        streak: streak,
        totalCheckins: totalCheckins,
        lastCheckin: lastCheckin,
        userName: userName,
        loadError: loadError,
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
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.check_circle_outline),
            selectedIcon: Icon(Icons.check_circle),
            label: 'History',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people),
            label: 'Contacts',
          ),
          NavigationDestination(
            icon: Icon(Icons.card_giftcard_outlined),
            selectedIcon: Icon(Icons.card_giftcard),
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
    required this.userName,
    required this.loadError,
    required this.onPet,
    required this.onSos,
    required this.onRefresh,
  });

  final bool loading;
  final int streak;
  final int totalCheckins;
  final DateTime? lastCheckin;
  final String userName;
  final String? loadError;
  final VoidCallback onPet;
  final VoidCallback onSos;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final checkedToday =
        lastCheckin != null && DateUtils.isSameDay(lastCheckin, DateTime.now());
    final greeting = DateTime.now().hour < 12
        ? 'Good Morning'
        : DateTime.now().hour < 18
        ? 'Good Afternoon'
        : 'Good Evening';
    final nextReward = streak.clamp(0, 7);

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$greeting 👋',
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Hi, $userName',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: AppColors.ink,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x3500B884),
                      blurRadius: 12,
                      offset: Offset(0, 5),
                    ),
                  ],
                ),
                child: const Icon(Icons.shield_outlined, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (loadError != null) ...[
            Text(loadError!, style: const TextStyle(color: AppColors.danger)),
            const SizedBox(height: 12),
          ],
          Row(
            children: [
              Expanded(
                child: _MiniStat(
                  icon: Icons.fact_check_outlined,
                  color: AppColors.blue,
                  label: 'Check-ins',
                  value: '$totalCheckins total',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MiniStat(
                  icon: Icons.local_fire_department_outlined,
                  color: AppColors.accent,
                  label: 'Streak',
                  value: '$streak days',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  const CircleAvatar(
                    backgroundColor: AppColors.accent,
                    foregroundColor: Colors.white,
                    child: Icon(Icons.card_giftcard),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'Next Reward',
                                style: TextStyle(fontWeight: FontWeight.w800),
                              ),
                            ),
                            Text(
                              '$nextReward/7 days',
                              style: const TextStyle(
                                color: AppColors.muted,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        LinearProgressIndicator(
                          value: nextReward / 7,
                          minHeight: 8,
                          borderRadius: BorderRadius.circular(8),
                          backgroundColor: AppColors.surface,
                          color: AppColors.primary,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          VirtualPetWidget(streak: streak, hasCheckedInToday: checkedToday),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: checkedToday
                  ? AppColors.primarySoft
                  : AppColors.warningSoft,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: checkedToday
                    ? AppColors.primary.withValues(alpha: .35)
                    : AppColors.accent.withValues(alpha: .45),
              ),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: checkedToday
                      ? AppColors.primary
                      : AppColors.accent,
                  foregroundColor: Colors.white,
                  child: Icon(
                    checkedToday
                        ? Icons.check_rounded
                        : Icons.warning_amber_rounded,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        checkedToday
                            ? 'Daily check-in complete!'
                            : 'Oren is waiting for you!',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      Text(
                        checkedToday
                            ? 'Safety heartbeat sent ${DateFormat('h:mm a').format(lastCheckin!)}'
                            : 'Interact with Oren to check in today',
                        style: TextStyle(
                          color: checkedToday
                              ? AppColors.primaryDark
                              : const Color(0xFFC66D00),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'INTERACT WITH OREN',
            style: TextStyle(
              color: AppColors.muted,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: .8,
            ),
          ),
          const SizedBox(height: 8),
          PetButton(onPressed: onPet, loading: loading),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: onSos,
            icon: const Icon(Icons.sos),
            label: const Text('SOS Emergency'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.danger,
              minimumSize: const Size.fromHeight(52),
              side: const BorderSide(color: AppColors.danger),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final Color color;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(13),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: color.withValues(alpha: .12),
              foregroundColor: color,
              child: Icon(icon, size: 20),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(color: AppColors.muted, fontSize: 12),
                ),
                Text(
                  value,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
