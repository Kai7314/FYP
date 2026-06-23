import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/colors.dart';
import '../../../models/location_model.dart';
import '../../../models/reward_model.dart';
import '../../../services/checkin_service.dart';
import '../../../services/dashboard_service.dart';
import '../../../services/emergency_service.dart';
import '../../../services/inactivity_service.dart';
import '../../../services/reward_service.dart';
import '../../../services/weather_service.dart';
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
  final dashboardService = DashboardService();
  final rewardService = RewardService();
  final weatherService = WeatherService();

  int selectedIndex = 0;
  bool loading = false;
  int streak = 0;
  int totalCheckins = 0;
  DateTime? lastCheckin;
  String userName = 'EthernaCare User';
  String emergencyStatus = 'safe';
  String? loadError;
  RewardSnapshot? rewardSnapshot;
  WeatherSnapshot? weather;
  late final List<Widget> persistentPages;

  @override
  void initState() {
    super.initState();
    persistentPages = [
      const SizedBox.shrink(),
      CheckinHistoryScreen(),
      const ContactsScreen(),
      const RewardsScreen(),
      const ProfileScreen(),
    ];
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
    final cachedResults = await Future.wait([
      dashboardService.loadCached(),
      rewardService.loadCached(),
      weatherService.loadCached(),
    ]);
    if (!mounted) return;
    final cachedDashboard = cachedResults[0] as DashboardSnapshot?;
    if (cachedDashboard != null) _applyDashboard(cachedDashboard);
    setState(() {
      rewardSnapshot = cachedResults[1] as RewardSnapshot?;
      weather = cachedResults[2] as WeatherSnapshot?;
    });

    try {
      final results = await Future.wait([
        dashboardService.refresh(),
        rewardService.synchronize(),
        weatherService.getCurrentWeather(),
      ]);
      if (!mounted) return;
      _applyDashboard(results[0] as DashboardSnapshot);
      setState(() {
        rewardSnapshot = results[1] as RewardSnapshot;
        weather = results[2] as WeatherSnapshot?;
        loadError = null;
      });
    } catch (_) {
      if (mounted) {
        setState(() => loadError = 'Unable to refresh dashboard data.');
      }
    }
  }

  void _applyDashboard(DashboardSnapshot snapshot) {
    if (!mounted) return;
    setState(() {
      userName = snapshot.userName;
      totalCheckins = snapshot.totalCheckins;
      lastCheckin = snapshot.lastCheckin;
      streak = snapshot.streak;
      emergencyStatus = snapshot.emergencyStatus;
    });
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
    final pages = List<Widget>.of(persistentPages);
    pages[0] = _HomeDashboard(
      loading: loading,
      streak: streak,
      totalCheckins: totalCheckins,
      lastCheckin: lastCheckin,
      userName: userName,
      loadError: loadError,
      emergencyStatus: emergencyStatus,
      rewardSnapshot: rewardSnapshot,
      weather: weather,
      onPet: petCat,
      onSos: _triggerSos,
      onRefresh: _loadDashboard,
    );

    return Scaffold(
      body: SafeArea(
        child: IndexedStack(index: selectedIndex, children: pages),
      ),
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
    required this.emergencyStatus,
    required this.rewardSnapshot,
    required this.weather,
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
  final String emergencyStatus;
  final RewardSnapshot? rewardSnapshot;
  final WeatherSnapshot? weather;
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
    final nextReward = rewardSnapshot?.nextReward(streak);
    final rewardTarget = nextReward?.milestoneDays ?? streak.clamp(1, 30);
    final rewardProgress = rewardTarget == 0
        ? 1.0
        : (streak.clamp(0, rewardTarget) / rewardTarget).toDouble();

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
          const SizedBox(height: 10),
          Card(
            child: ListTile(
              leading: Icon(
                emergencyStatus.toLowerCase() == 'triggered'
                    ? Icons.warning_amber_rounded
                    : Icons.shield_outlined,
                color: emergencyStatus.toLowerCase() == 'triggered'
                    ? AppColors.danger
                    : AppColors.primary,
              ),
              title: const Text('Emergency status'),
              subtitle: Text(
                emergencyStatus.toLowerCase() == 'triggered'
                    ? 'Alert triggered - contact follow-up pending'
                    : 'No active emergency alert',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
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
                            Expanded(
                              child: Text(
                                nextReward?.title ?? 'All rewards earned',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            Text(
                              nextReward == null
                                  ? '$streak days'
                                  : '$streak/${nextReward.milestoneDays} days',
                              style: const TextStyle(
                                color: AppColors.muted,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        LinearProgressIndicator(
                          value: rewardProgress,
                          minHeight: 8,
                          borderRadius: BorderRadius.circular(8),
                          backgroundColor: AppColors.surface,
                          color: AppColors.primary,
                        ),
                        if (nextReward != null) ...[
                          const SizedBox(height: 6),
                          Text(
                            nextReward.rewardKind == 'voucher'
                                ? '${nextReward.sponsor} virtual voucher'
                                : 'Sponsored by ${nextReward.sponsor}',
                            style: const TextStyle(
                              color: AppColors.muted,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          VirtualPetWidget(
            streak: streak,
            hasCheckedInToday: checkedToday,
            weather: weather,
          ),
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
