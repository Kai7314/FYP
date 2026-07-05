import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/colors.dart';
import '../../../models/emergency_escalation_target.dart';
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
  final orenCareService = OrenCareService();
  final orenSoundService = OrenSoundService();
  final userService = UserService();

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
  OrenCareState orenCare = OrenCareState.initial();
  Timer? testAlarmTimer;
  Timer? orenResetTimer;
  String? activeToyAsset;
  bool testAlarmArmed = false;
  int testAlarmSecondsRemaining = 0;
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
    _loadOrenCare();
    InactivityService().checkInactivity().catchError((_) {});
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

  void _showTemporaryOrenState(
    OrenCareState state, {
    String? toyAsset,
  }) {
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
    final action = await showDialog<_SosAction>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.sos, color: AppColors.danger, size: 40),
        title: const Text('Emergency help'),
        content: const Text(
          'For immediate danger in Malaysia, call 999. EthernaCare can also record an SOS alert for your primary contact and trusted contacts.',
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          OutlinedButton.icon(
            onPressed: () => Navigator.pop(context, _SosAction.call999),
            icon: const Icon(Icons.call_outlined),
            label: const Text('Call 999'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, _SosAction.sendAlert),
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text('Send Alert'),
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

  String _checkInMessage({
    required bool created,
    required bool tokenAwarded,
  }) {
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

  Future<void> _armInactivityAlarmTest() async {
    if (testAlarmArmed) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(
          Icons.alarm_on_outlined,
          color: AppColors.accent,
          size: 38,
        ),
        title: const Text('Test inactivity alarm?'),
        content: const Text(
          'This waits 10 seconds, records a test inactivity alert, and sends an automated SMS to your primary contact. It will not open or call 999.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Start 10s Test'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    testAlarmTimer?.cancel();
    setState(() {
      testAlarmArmed = true;
      testAlarmSecondsRemaining = 10;
    });
    _showMessage('Safe inactivity alarm test armed for 10 seconds.');

    testAlarmTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (testAlarmSecondsRemaining <= 1) {
        timer.cancel();
        unawaited(_fireInactivityAlarmTest());
        return;
      }
      setState(() => testAlarmSecondsRemaining -= 1);
    });
  }

  Future<void> _fireInactivityAlarmTest() async {
    if (mounted) {
      setState(() {
        testAlarmArmed = false;
        testAlarmSecondsRemaining = 0;
      });
    }

    try {
      final result = await EmergencyService().triggerEmergencyDetailed(
        openPrimarySmsComposer: false,
        sendAutomatedSms: true,
        allow999Dialer: false,
        escalationTarget: EmergencyEscalationTarget.primaryContact,
      );
      if (!mounted) return;
      await _loadDashboard();
      _showMessage(
        result.alertRecorded
            ? 'Test inactivity alarm triggered safely. ${_emergencyResultMessage(result)}'
            : 'Add a primary emergency contact before testing the alarm.',
      );
    } catch (error) {
      if (mounted) {
        _showMessage('Could not trigger test inactivity alarm: $error');
      }
    }
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
    testAlarmTimer?.cancel();
    orenResetTimer?.cancel();
    unawaited(orenSoundService.dispose());
    super.dispose();
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
      orenCare: orenCare,
      activeToyAsset: activeToyAsset,
      onPet: petCat,
      onFeedFish: _feedFish,
      onBuyToy: _buyToy,
      onPlayToy: _playWithToy,
      onSos: _triggerSos,
      onTestSms: _testPrimarySms,
      onTestInactivityAlarm: _armInactivityAlarmTest,
      testAlarmArmed: testAlarmArmed,
      testAlarmSecondsRemaining: testAlarmSecondsRemaining,
      onSignOut: _signOut,
      onRefresh: _loadDashboard,
    );

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
    required this.testAlarmArmed,
    required this.testAlarmSecondsRemaining,
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
  final bool testAlarmArmed;
  final int testAlarmSecondsRemaining;
  final VoidCallback onSignOut;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final horizontalPadding = MediaQuery.sizeOf(context).width < 360 ? 14.0 : 20.0;
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
        padding: EdgeInsets.fromLTRB(horizontalPadding, 18, horizontalPadding, 24),
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
            mood: orenCare.mood,
            activeToyAsset: activeToyAsset,
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
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: onTestSms,
            icon: const Icon(Icons.sms_outlined),
            label: const Text('Send Test SMS Automatically'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: testAlarmArmed ? null : onTestInactivityAlarm,
            icon: const Icon(Icons.alarm_on_outlined),
            label: Text(
              testAlarmArmed
                  ? 'Test alarm in ${testAlarmSecondsRemaining}s'
                  : 'Test Inactivity Alarm (10s)',
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.accent,
              minimumSize: const Size.fromHeight(52),
              side: const BorderSide(color: AppColors.accent),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
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
    return GlassPanel(
      color: Colors.white.withValues(alpha: .78),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.primarySoft,
            foregroundColor: AppColors.primaryDark,
            child: Icon(Icons.pets, size: 19),
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
                  'Mood: $mood - Energy: $energy%',
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
