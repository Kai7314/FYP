import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/colors.dart';
import '../../../models/location_model.dart';
import '../../../models/oren_care_model.dart';
import '../../../models/reward_model.dart';
import '../../../services/checkin_service.dart';
import '../../../services/dashboard_service.dart';
import '../../../services/emergency_service.dart';
import '../../../services/inactivity_service.dart';
import '../../../services/oren_care_service.dart';
import '../../../services/oren_sound_service.dart';
import '../../../services/reward_service.dart';
import '../../../services/user_service.dart';
import '../../../services/weather_service.dart';
import '../checkin/checkin_history_screen.dart';
import '../contacts/contacts_screen.dart';
import '../profile/profile_screen.dart';
import '../rewards/rewards_screen.dart';
import '../../widgets/premium_shell.dart';
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
  final orenCareService = OrenCareService();
  final orenSoundService = OrenSoundService();
  final userService = UserService();
  final inactivityService = InactivityService();

  int selectedIndex = 0;
  bool loading = false;
  int streak = 0;
  int totalCheckins = 0;
  DateTime? lastCheckin;
  DateTime? latestEmergencyAlertTime;
  String userName = 'EthernaCare User';
  String emergencyStatus = 'safe';
  String? loadError;
  RewardSnapshot? rewardSnapshot;
  WeatherSnapshot? weather;
  OrenCareState orenCare = OrenCareState.initial();
  Timer? orenResetTimer;
  String? activeToyAsset;
  bool testReminderBusy = false;
  int testReminderCount = 0;
  int inactivityNotificationCount = 0;
  bool inactivityEscalated = false;
  int dataRefreshTick = 0;
  int historyRefreshTick = 0;

  @override
  void initState() {
    super.initState();
    _loadDashboard();
    _loadOrenCare();
    unawaited(_refreshInactivityMonitor());
  }

  Future<void> _refreshInactivityMonitor() async {
    try {
      await inactivityService.checkInactivity();
      await _loadInactivityStatus(lastCheckin);
    } catch (_) {
      // Dashboard loading and manual check-in remain available offline.
    }
  }

  Future<void> _loadInactivityStatus(DateTime? latestCheckIn) async {
    final status = await inactivityService.getCurrentStatus(
      latestCheckIn: latestCheckIn,
    );
    if (!mounted) return;
    setState(() {
      inactivityNotificationCount = status.notificationCount;
      inactivityEscalated = status.escalated;
    });
  }

  Future<void> _loadOrenCare() async {
    final previous = await orenCareService.load();
    final state = await orenCareService.claimDailyLoginToken();
    if (!mounted) return;
    setState(() => orenCare = state);
    if (previous.lastDailyTokenDate != state.lastDailyTokenDate) {
      unawaited(orenSoundService.playDailyBonus());
    }
  }

  Future<void> petCat() async {
    setState(() => loading = true);
    try {
      final careState = await orenCareService.pet();
      if (mounted) setState(() => orenCare = careState);
      unawaited(orenSoundService.playPet());
      final created = await CheckinService().addCheckin();
      final rewardedState = await orenCareService.awardDailyCheckInTokens();
      final tokenAwarded = rewardedState.tokens > careState.tokens;
      _showTemporaryOrenState(rewardedState);
      if (created) {
        await RewardService().checkReward();
      }
      await _loadDashboard();
      if (!mounted) return;
      _showMessage(
        _checkInMessage(created: created, tokenAwarded: tokenAwarded),
      );
    } catch (error) {
      if (mounted) _showMessage('Could not record check-in: $error');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _feedFish() async {
    final state = await orenCareService.feedFish();
    if (!mounted) return;
    _showTemporaryOrenState(state);
    unawaited(orenSoundService.playFeed());
    _showMessage('Oren enjoyed the fish snack.');
  }

  Future<void> _buyToy(OrenToy toy) async {
    final state = await orenCareService.buyToy(toy);
    if (!mounted) return;
    _showTemporaryOrenState(
      state,
      toyAsset: state.ownedToyIds.contains(toy.id) ? toy.imageAsset : null,
    );
    if (state.ownedToyIds.contains(toy.id)) {
      unawaited(orenSoundService.playPlayful());
    }
    _showMessage(state.lastAction);
  }

  Future<void> _playWithToy(OrenToy toy) async {
    final state = await orenCareService.playWithToy(toy);
    if (!mounted) return;
    _showTemporaryOrenState(
      state,
      toyAsset: state.ownedToyIds.contains(toy.id) ? toy.imageAsset : null,
    );
    if (state.ownedToyIds.contains(toy.id)) {
      unawaited(orenSoundService.playPlayful());
    }
    _showMessage(state.lastAction);
  }

  void _showTemporaryOrenState(OrenCareState state, {String? toyAsset}) {
    if (!mounted) return;
    orenResetTimer?.cancel();
    setState(() {
      orenCare = state;
      activeToyAsset = toyAsset;
    });
    orenResetTimer = Timer(const Duration(seconds: 4), () async {
      final calmState = await orenCareService.resetMood();
      if (!mounted) return;
      setState(() {
        orenCare = calmState;
        activeToyAsset = null;
      });
    });
  }

  Future<void> _loadDashboard() async {
    final cachedResults = await Future.wait([
      dashboardService.loadCached(),
      rewardService.loadCached(),
      weatherService.loadCached(),
    ]);
    if (!mounted) return;
    final cachedDashboard = cachedResults[0] as DashboardSnapshot?;
    if (cachedDashboard != null) {
      _applyDashboard(cachedDashboard);
      await _loadInactivityStatus(cachedDashboard.lastCheckin);
    }
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
      final dashboard = results[0] as DashboardSnapshot;
      _applyDashboard(dashboard);
      await _loadInactivityStatus(dashboard.lastCheckin);
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
      latestEmergencyAlertTime = snapshot.latestEmergencyAlertTime;
    });
  }

  Future<void> _triggerSos() async {
    final action = await showDialog<_SosAction>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: AppColors.glassStrong,
        icon: const Icon(Icons.sos, color: AppColors.danger, size: 40),
        title: const Text('Emergency help'),
        content: const Text(
          'For immediate danger in Malaysia, call 999. EthernaCare can also record an SOS alert for your primary contact and trusted contacts.',
          textAlign: TextAlign.center,
        ),
        actionsPadding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
        actions: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FilledButton.icon(
                onPressed: () => Navigator.pop(context, _SosAction.sendAlert),
                icon: const Icon(Icons.sms_outlined),
                label: const Text('Send Emergency Alert'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.danger,
                  minimumSize: const Size.fromHeight(50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () => Navigator.pop(context, _SosAction.call999),
                icon: const Icon(Icons.call_outlined),
                label: const Text('Open 999 Dialer'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.danger,
                  minimumSize: const Size.fromHeight(50),
                  side: const BorderSide(color: AppColors.danger),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
            ],
          ),
        ],
      ),
    );
    if (action == null || !mounted) return;

    if (action == _SosAction.call999) {
      try {
        await EmergencyService().callMalaysiaEmergency999();
      } catch (error) {
        if (mounted) _showMessage('Could not open phone dialer: $error');
      }
      return;
    }

    try {
      final result = await EmergencyService().triggerEmergencyDetailed(
        openPrimarySmsComposer: false,
        sendAutomatedSms: true,
        allow999Dialer: true,
      );
      if (!mounted) return;
      _showMessage(
        result.alertRecorded
            ? _emergencyResultMessage(result)
            : 'Add a primary emergency contact before sending an alert.',
      );
    } catch (error) {
      if (mounted) _showMessage('Could not send emergency alert: $error');
    }
  }

  String _checkInMessage({required bool created, required bool tokenAwarded}) {
    if (created && tokenAwarded) {
      return 'Check-in recorded. +${OrenCareService.dailyCheckInTokenReward} Oren tokens earned.';
    }
    if (created) return 'Check-in recorded. Your safety signal was sent.';
    if (tokenAwarded) {
      return 'Today\'s check-in already exists. +${OrenCareService.dailyCheckInTokenReward} Oren tokens added.';
    }
    return 'You have already checked in today. Oren token bonus is once per day.';
  }

  Future<void> _testPrimarySms() async {
    try {
      final sent = await EmergencyService().sendPrimaryContactTestSms();
      if (!mounted) return;
      _showMessage(
        sent
            ? 'Automated test SMS sent to your primary contact.'
            : 'Add a primary emergency contact before testing SMS.',
      );
    } catch (error) {
      if (mounted) _showMessage('Could not send test SMS: $error');
    }
  }

  Future<void> _triggerInactivityReminderTest() async {
    if (testReminderBusy) return;
    setState(() => testReminderBusy = true);
    try {
      final result = await InactivityService().triggerReminderTest(
        currentCount: testReminderCount,
      );
      if (!mounted) return;
      setState(() => testReminderCount = result.reminderCount);
      final emergencyResult = result.emergencyResult;
      if (emergencyResult == null) {
        _showMessage(
          'Test reminder ${result.reminderCount} of ${InactivityService.missedCheckInsBeforeEscalation} triggered. No SMS sent yet.',
        );
        return;
      }
      _showMessage(_testReminderResultMessage(emergencyResult));
    } catch (error) {
      if (mounted) {
        _showMessage('Could not run reminder test: $error');
      }
    } finally {
      if (mounted) setState(() => testReminderBusy = false);
    }
  }

  String _testReminderResultMessage(EmergencyTriggerResult result) {
    if (!result.alertRecorded) {
      return 'Third test reminder triggered, but no SMS was sent. Add a primary emergency contact and try again.';
    }
    if (result.autoSmsSent > 0) {
      return 'Third test reminder triggered. Automated TEST SMS sent to your primary contact.';
    }
    final error = result.autoSmsError;
    if (error != null && error.trim().isNotEmpty) {
      return 'Third test reminder triggered, but the TEST SMS failed: $error';
    }
    return 'Third test reminder triggered. The TEST SMS is queued for delivery.';
  }

  String _emergencyResultMessage(EmergencyTriggerResult result) {
    if (result.official999Selected) {
      return result.dialerOpened
          ? 'Emergency alert recorded. The 999 dialer is open for you to place the call.'
          : 'Emergency alert recorded. Call 999 directly for immediate help.';
    }
    if (result.autoSmsSent > 0) {
      return 'Emergency alert recorded. Automated SMS sent to your primary contact.';
    }
    if (result.autoSmsAttempted) {
      final error = result.autoSmsError;
      if (error != null && error.trim().isNotEmpty) {
        return 'Emergency alert recorded, but automated SMS did not send: $error';
      }
      return 'Emergency alert recorded. SMS is queued for automated delivery.';
    }
    if (result.primarySmsComposerOpened) {
      return 'Emergency alert recorded. SMS composer opened for your primary contact.';
    }
    return 'Emergency alert recorded. SMS is queued for your primary contact.';
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _signOut() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.logout),
        title: const Text('Sign out?'),
        content: const Text('You will return to the login screen.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await userService.signOut();
    } catch (error) {
      if (mounted) _showMessage('Could not sign out: $error');
    }
  }

  @override
  void dispose() {
    orenResetTimer?.cancel();
    unawaited(orenSoundService.dispose());
    super.dispose();
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
        emergencyStatus: emergencyStatus,
        latestEmergencyAlertTime: latestEmergencyAlertTime,
        rewardSnapshot: rewardSnapshot,
        weather: weather,
        orenCare: orenCare,
        activeToyAsset: activeToyAsset,
        onPet: petCat,
        onFeedFish: _feedFish,
        onBuyToy: _buyToy,
        onPlayToy: _playWithToy,
        onSos: _triggerSos,
        onTestSms: _testPrimarySms,
        onTestInactivityAlarm: _triggerInactivityReminderTest,
        testReminderBusy: testReminderBusy,
        testReminderCount: testReminderCount,
        inactivityNotificationCount: inactivityNotificationCount,
        inactivityEscalated: inactivityEscalated,
        onSignOut: _signOut,
        onRefresh: _loadDashboard,
      ),
      CheckinHistoryScreen(refreshVersion: historyRefreshTick),
      ContactsScreen(key: ValueKey('contacts-$dataRefreshTick')),
      RewardsScreen(key: ValueKey('rewards-$dataRefreshTick')),
      ProfileScreen(key: ValueKey('profile-$dataRefreshTick')),
    ];

    return PremiumScaffold(
      padding: EdgeInsets.zero,
      safeAreaBottom: false,
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(14, 0, 14, 12),
        child: GlassPanel(
          padding: EdgeInsets.zero,
          color: Colors.white.withValues(alpha: .84),
          child: NavigationBar(
            selectedIndex: selectedIndex,
            onDestinationSelected: (value) {
              setState(() {
                selectedIndex = value;
                dataRefreshTick += 1;
                if (value == 1) historyRefreshTick += 1;
              });
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
        ),
      ),
      child: IndexedStack(index: selectedIndex, children: pages),
    );
  }
}

enum _SosAction { call999, sendAlert }

class _HomeDashboard extends StatelessWidget {
  const _HomeDashboard({
    required this.loading,
    required this.streak,
    required this.totalCheckins,
    required this.lastCheckin,
    required this.userName,
    required this.loadError,
    required this.emergencyStatus,
    required this.latestEmergencyAlertTime,
    required this.rewardSnapshot,
    required this.weather,
    required this.orenCare,
    required this.activeToyAsset,
    required this.onPet,
    required this.onFeedFish,
    required this.onBuyToy,
    required this.onPlayToy,
    required this.onSos,
    required this.onTestSms,
    required this.onTestInactivityAlarm,
    required this.testReminderBusy,
    required this.testReminderCount,
    required this.inactivityNotificationCount,
    required this.inactivityEscalated,
    required this.onSignOut,
    required this.onRefresh,
  });

  final bool loading;
  final int streak;
  final int totalCheckins;
  final DateTime? lastCheckin;
  final String userName;
  final String? loadError;
  final String emergencyStatus;
  final DateTime? latestEmergencyAlertTime;
  final RewardSnapshot? rewardSnapshot;
  final WeatherSnapshot? weather;
  final OrenCareState orenCare;
  final String? activeToyAsset;
  final VoidCallback onPet;
  final VoidCallback onFeedFish;
  final void Function(OrenToy toy) onBuyToy;
  final void Function(OrenToy toy) onPlayToy;
  final VoidCallback onSos;
  final VoidCallback onTestSms;
  final VoidCallback onTestInactivityAlarm;
  final bool testReminderBusy;
  final int testReminderCount;
  final int inactivityNotificationCount;
  final bool inactivityEscalated;
  final VoidCallback onSignOut;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final horizontalPadding = MediaQuery.sizeOf(context).width < 360
        ? 14.0
        : 20.0;
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
        padding: EdgeInsets.fromLTRB(
          horizontalPadding,
          18,
          horizontalPadding,
          24,
        ),
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      greeting,
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
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: AppColors.heroGradient,
                      ),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x3500B884),
                          blurRadius: 12,
                          offset: Offset(0, 5),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.shield_outlined,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filledTonal(
                    onPressed: onSignOut,
                    icon: const Icon(Icons.logout),
                    tooltip: 'Sign out',
                  ),
                ],
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
          _InactivityReminderCard(
            count: inactivityNotificationCount,
            escalated: inactivityEscalated,
            testCount: testReminderCount,
            testBusy: testReminderBusy,
            onTriggerTest: onTestInactivityAlarm,
          ),
          const SizedBox(height: 10),
          _EmergencyStatusCard(
            status: emergencyStatus,
            latestAlertTime: latestEmergencyAlertTime,
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
          const SizedBox(height: 10),
          const _ScrollCue(),
          const SizedBox(height: 14),
          VirtualPetWidget(
            streak: streak,
            hasCheckedInToday: checkedToday,
            weather: weather,
            mood: orenCare.mood,
            energy: orenCare.energy,
            activeToyAsset: activeToyAsset,
            onTap: onPet,
            loading: loading,
          ),
          const SizedBox(height: 12),
          _OrenStatusBar(
            message: orenCare.lastAction,
            mood: orenCare.mood,
            energy: orenCare.energy,
          ),
          const SizedBox(height: 12),
          _OrenCarePanel(
            state: orenCare,
            onFeedFish: onFeedFish,
            onBuyToy: onBuyToy,
            onPlayToy: onPlayToy,
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: checkedToday
                  ? AppColors.primarySoft
                  : AppColors.warningSoft,
              borderRadius: BorderRadius.circular(8),
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
                            : 'Tap Oren to check in today',
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
          const SizedBox(height: 10),
          _SafetyActionPanel(onSos: onSos, onTestSms: onTestSms),
        ],
      ),
    );
  }
}

class _InactivityReminderCard extends StatelessWidget {
  const _InactivityReminderCard({
    required this.count,
    required this.escalated,
    required this.testCount,
    required this.testBusy,
    required this.onTriggerTest,
  });

  final int count;
  final bool escalated;
  final int testCount;
  final bool testBusy;
  final VoidCallback onTriggerTest;

  @override
  Widget build(BuildContext context) {
    const requiredCount = InactivityService.missedCheckInsBeforeEscalation;
    final safeCount = count.clamp(0, requiredCount).toInt();
    final safeTestCount = testCount.clamp(0, requiredCount).toInt();
    final nextTestCount = safeTestCount >= requiredCount
        ? 1
        : safeTestCount + 1;
    final reachedLimit = safeCount >= requiredCount;
    final color = reachedLimit ? AppColors.danger : AppColors.accent;
    final detail = escalated
        ? 'Configured emergency escalation triggered.'
        : reachedLimit
        ? 'Third reminder reached. SMS delivery is pending.'
        : safeCount == 0
        ? 'No missed check-in reminders in the current cycle.'
        : 'SMS will be attempted when reminder 3 is triggered.';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    reachedLimit
                        ? Icons.sms_outlined
                        : Icons.notifications_active_outlined,
                    color: color,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Inactivity reminders',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                      Text(
                        'Current missed check-in cycle',
                        style: TextStyle(color: AppColors.muted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Text(
                  '$safeCount/$requiredCount',
                  style: TextStyle(
                    color: color,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            LinearProgressIndicator(
              value: safeCount / requiredCount,
              minHeight: 7,
              borderRadius: BorderRadius.circular(8),
              color: color,
              backgroundColor: AppColors.surface,
            ),
            const SizedBox(height: 8),
            Text(
              detail,
              style: const TextStyle(
                color: AppColors.muted,
                fontSize: 12,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Safe reminder test  $safeTestCount/$requiredCount',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'The third test sends a labelled TEST SMS. It never calls 999.',
                        style: TextStyle(
                          color: AppColors.muted,
                          fontSize: 11,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                FilledButton.icon(
                  onPressed: testBusy ? null : onTriggerTest,
                  icon: testBusy
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.notifications_active_outlined),
                  label: Text(testBusy ? 'Testing' : 'Test $nextTestCount/3'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EmergencyStatusCard extends StatelessWidget {
  const _EmergencyStatusCard({
    required this.status,
    required this.latestAlertTime,
  });

  final String status;
  final DateTime? latestAlertTime;

  @override
  Widget build(BuildContext context) {
    final normalizedStatus = status.toLowerCase().trim();
    final isRealAlert = normalizedStatus == 'triggered';
    final isTestAlert = normalizedStatus.contains('test');
    final color = isRealAlert
        ? AppColors.danger
        : isTestAlert
        ? AppColors.blue
        : AppColors.primary;
    final icon = isRealAlert
        ? Icons.warning_amber_rounded
        : isTestAlert
        ? Icons.task_alt_rounded
        : Icons.shield_outlined;
    final timeText = latestAlertTime == null
        ? null
        : DateFormat('MMM d, h:mm a').format(latestAlertTime!.toLocal());
    final title = isRealAlert ? 'Latest emergency alert' : 'Safety monitor';
    final statusText = isRealAlert
        ? 'Emergency alert recorded'
        : isTestAlert
        ? 'Last alarm test completed'
        : 'No active emergency alert';
    final detailText = isRealAlert
        ? [
            if (timeText != null) 'Recorded $timeText.',
            'Use Safety Actions below if follow-up is still needed.',
          ].join(' ')
        : isTestAlert
        ? [
            if (timeText != null) 'Test recorded $timeText.',
            'No real emergency is active.',
          ].join(' ')
        : 'Tap Oren daily to keep your safety heartbeat updated.';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: color.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    statusText,
                    style: const TextStyle(
                      color: AppColors.ink,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    detailText,
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 12,
                      height: 1.25,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScrollCue extends StatelessWidget {
  const _ScrollCue();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.center,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .72),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.keyboard_arrow_down_rounded, size: 18),
            SizedBox(width: 4),
            Text(
              'More tools below',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }
}

class _SafetyActionPanel extends StatelessWidget {
  const _SafetyActionPanel({required this.onSos, required this.onTestSms});

  final VoidCallback onSos;
  final VoidCallback onTestSms;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      color: AppColors.glassStrong,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.danger.withValues(alpha: .10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.health_and_safety_outlined,
                  color: AppColors.danger,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Safety Actions',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                    Text(
                      'Emergency and testing controls',
                      style: TextStyle(color: AppColors.muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _SafetyActionTile(
            icon: Icons.sos,
            color: AppColors.danger,
            title: 'SOS emergency',
            subtitle: 'Record an alert and notify your primary contact.',
            onTap: onSos,
          ),
          const SizedBox(height: 10),
          _SafetyActionTile(
            icon: Icons.sms_outlined,
            color: AppColors.blue,
            title: 'Test primary SMS',
            subtitle: 'Send a safe automated test message.',
            onTap: onTestSms,
          ),
        ],
      ),
    );
  }
}

class _SafetyActionTile extends StatelessWidget {
  const _SafetyActionTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.trailingText,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final String? trailingText;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: enabled
                ? color.withValues(alpha: .07)
                : AppColors.surface.withValues(alpha: .72),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: enabled
                  ? color.withValues(alpha: .22)
                  : AppColors.border.withValues(alpha: .8),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: enabled ? .14 : .08),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  icon,
                  color: enabled ? color : AppColors.muted,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: enabled ? AppColors.ink : AppColors.muted,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 12,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              if (trailingText != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: .14),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    trailingText!,
                    style: TextStyle(
                      color: color,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                )
              else
                Icon(
                  Icons.chevron_right_rounded,
                  color: enabled ? color : AppColors.muted,
                ),
            ],
          ),
        ),
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
    return GlassPanel(
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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.muted, fontSize: 12),
                ),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OrenStatusBar extends StatelessWidget {
  const _OrenStatusBar({
    required this.message,
    required this.mood,
    required this.energy,
  });

  final String message;
  final String mood;
  final int energy;

  @override
  Widget build(BuildContext context) {
    final status = _statusLabel;
    final statusColor = energy >= 90
        ? AppColors.accent
        : energy <= 25
        ? AppColors.muted
        : AppColors.primary;

    return GlassPanel(
      color: Colors.white.withValues(alpha: .78),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: statusColor.withValues(alpha: .14),
            foregroundColor: statusColor,
            child: Icon(_statusIcon, size: 19),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message.trim().isEmpty ? 'Oren is ready for today.' : message,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Status: $status - Energy: $energy%',
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String get _statusLabel {
    final moodText = mood.toLowerCase();
    if (moodText == 'eating') return 'Eating';
    if (energy >= 90 || moodText == 'energetic') return 'Full energy';
    if (energy <= 25 || moodText == 'tired') return 'Tired';
    if (moodText == 'playful') return 'Playful';
    if (moodText == 'loved' || moodText == 'happy') return 'Loved';
    if (moodText == 'curious') return 'Curious';
    return 'Calm';
  }

  IconData get _statusIcon {
    switch (_statusLabel) {
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

class _OrenCarePanel extends StatelessWidget {
  const _OrenCarePanel({
    required this.state,
    required this.onFeedFish,
    required this.onBuyToy,
    required this.onPlayToy,
  });

  final OrenCareState state;
  final VoidCallback onFeedFish;
  final void Function(OrenToy toy) onBuyToy;
  final void Function(OrenToy toy) onPlayToy;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      color: AppColors.glassStrong,
      padding: const EdgeInsets.all(14),
      child: Padding(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const CircleAvatar(
                  backgroundColor: AppColors.primarySoft,
                  foregroundColor: AppColors.primaryDark,
                  child: Icon(Icons.toll_outlined),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Oren Tokens',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                      Text(
                        '${state.tokens} tokens - daily login gives 5',
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                _EnergyPill(energy: state.energy),
              ],
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final feedButton = OutlinedButton.icon(
                  onPressed: onFeedFish,
                  icon: const Icon(Icons.set_meal_outlined),
                  label: const Text('Feed Fish'),
                );
                final playButton = OutlinedButton.icon(
                  onPressed: state.ownedToyIds.isEmpty
                      ? null
                      : () => onPlayToy(
                          OrenCareService.toyCatalog.firstWhere(
                            (toy) => state.ownedToyIds.contains(toy.id),
                          ),
                        ),
                  icon: const Icon(Icons.sports_esports_outlined),
                  label: const Text('Play'),
                );

                if (constraints.maxWidth < 310) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      feedButton,
                      const SizedBox(height: 10),
                      playButton,
                    ],
                  );
                }

                return Row(
                  children: [
                    Expanded(child: feedButton),
                    const SizedBox(width: 10),
                    Expanded(child: playButton),
                  ],
                );
              },
            ),
            const SizedBox(height: 14),
            const Text(
              'OREN TOY SHOP',
              style: TextStyle(
                color: AppColors.muted,
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: .8,
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 172,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: OrenCareService.toyCatalog.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  final toy = OrenCareService.toyCatalog[index];
                  final owned = state.ownedToyIds.contains(toy.id);
                  return _ToyCard(
                    toy: toy,
                    owned: owned,
                    canBuy: state.tokens >= toy.price,
                    onTap: owned ? () => onPlayToy(toy) : () => onBuyToy(toy),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ToyCard extends StatelessWidget {
  const _ToyCard({
    required this.toy,
    required this.owned,
    required this.canBuy,
    required this.onTap,
  });

  final OrenToy toy;
  final bool owned;
  final bool canBuy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 164,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: owned ? AppColors.primarySoft : AppColors.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: owned
                  ? AppColors.primary.withValues(alpha: .35)
                  : AppColors.border,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 64,
                width: double.infinity,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Image.asset(toy.imageAsset, fit: BoxFit.contain),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      toy.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                  Text(
                    owned ? 'Owned' : '${toy.price} tok',
                    style: TextStyle(
                      color: owned || canBuy
                          ? AppColors.primaryDark
                          : AppColors.muted,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                owned ? 'Tap to play' : toy.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppColors.muted, fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EnergyPill extends StatelessWidget {
  const _EnergyPill({required this.energy});

  final int energy;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.warningSoft,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '$energy energy',
        style: const TextStyle(
          color: Color(0xFFC66D00),
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
