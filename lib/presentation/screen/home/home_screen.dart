import 'dart:async';

import 'package:flutter/foundation.dart';
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
import '../../widgets/feature_guide_overlay.dart';
import 'virtual_pet_widget.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    this.startFeatureGuide = false,
    this.onFeatureGuideComplete,
  });

  final bool startFeatureGuide;
  final Future<void> Function()? onFeatureGuideComplete;

  static const showSafetyTestTools = bool.fromEnvironment(
    'ENABLE_SAFETY_TESTS',
    defaultValue: kDebugMode,
  );

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  static const featureGuideSteps = [
    FeatureGuideStep(
      pageIndex: 0,
      pageLabel: 'Home',
      title: 'Meet Oren',
      description:
          'Tap Oren on this page when your check-in is due. Feed Oren or play with an owned item between check-ins.',
      icon: Icons.pets_outlined,
      color: AppColors.primary,
    ),
    FeatureGuideStep(
      pageIndex: 0,
      pageLabel: 'Home',
      title: 'Your safety heartbeat',
      description:
          'The live status follows your inactivity threshold. Missed windows can remind you and later alert your primary contact.',
      icon: Icons.health_and_safety_outlined,
      color: AppColors.accent,
    ),
    FeatureGuideStep(
      pageIndex: 1,
      pageLabel: 'History',
      title: 'Review check-ins',
      description:
          'History shows your recorded check-ins. The newest successful check-in starts a new safety window.',
      icon: Icons.history,
      color: AppColors.blue,
    ),
    FeatureGuideStep(
      pageIndex: 2,
      pageLabel: 'Contacts',
      title: 'Manage trusted contacts',
      description:
          'Add verified contacts and choose one primary contact for SOS, inactivity alerts, and protected Legacy access.',
      icon: Icons.people_outline,
      color: AppColors.purple,
    ),
    FeatureGuideStep(
      pageIndex: 3,
      pageLabel: 'Rewards',
      title: 'Collect virtual rewards',
      description:
          'Check streak goals, collect badges or vouchers, and open earned rewards to view their details and redeem codes.',
      icon: Icons.card_giftcard_outlined,
      color: AppColors.blue,
    ),
    FeatureGuideStep(
      pageIndex: 4,
      pageLabel: 'Profile',
      title: 'Profile and Legacy Planning',
      description:
          'Manage safety details, your Legacy UID, funeral preferences, protected notes, documents, and biometric security here.',
      icon: Icons.person_outline,
      color: AppColors.purple,
    ),
    FeatureGuideStep(
      pageIndex: 4,
      pageLabel: 'Profile',
      title: 'Settings and help',
      description:
          'Open Settings for reminders, Oren sounds, accessibility, and security. You can restart this live guide from Profile anytime.',
      icon: Icons.settings_outlined,
      color: AppColors.primary,
    ),
  ];

  final dashboardService = DashboardService();
  final checkinService = CheckinService();
  final rewardService = RewardService();
  final weatherService = WeatherService();
  final orenCareService = OrenCareService();
  final orenSoundService = OrenSoundService();
  final userService = UserService();
  final inactivityService = InactivityService();
  final pageScrollControllers = List<ScrollController>.generate(
    5,
    (_) => ScrollController(),
  );

  int selectedIndex = 0;
  bool loading = false;
  int streak = 0;
  DateTime? lastCheckin;
  DateTime? latestEmergencyAlertTime;
  String userName = 'EthernaCare User';
  String emergencyStatus = 'safe';
  String? loadError;
  RewardSnapshot? rewardSnapshot;
  WeatherSnapshot? weather;
  OrenCareState orenCare = OrenCareState.initial();
  Timer? orenResetTimer;
  String? activeToyId;
  String? activeToyAsset;
  int inactivityNotificationCount = 0;
  bool inactivityEscalated = false;
  bool inactivityUserSmsAccepted = false;
  String? inactivityUserSmsError;
  int inactivityThresholdHours = 24;
  Timer? thresholdRefreshTimer;
  DateTime? lastInactivityRefreshAt;
  int contactsRefreshTick = 0;
  int rewardsRefreshTick = 0;
  int profileRefreshTick = 0;
  int historyRefreshTick = 0;
  int dashboardRequestId = 0;
  bool featureGuideActive = false;
  int featureGuideStep = 0;
  int featureGuideScrollRequest = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadDashboard();
    _loadOrenCare();
    unawaited(_refreshInactivityMonitor());
    if (widget.startFeatureGuide) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _startFeatureGuide();
      });
    }
    thresholdRefreshTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (!mounted) return;
      setState(() {});
      final now = DateTime.now();
      if (now.difference(orenCare.updatedAt) >=
          OrenCareService.energyDecayInterval) {
        unawaited(_refreshOrenEnergy());
      }
      if (lastInactivityRefreshAt == null ||
          now.difference(lastInactivityRefreshAt!) >=
              const Duration(minutes: 5)) {
        lastInactivityRefreshAt = now;
        unawaited(_refreshInactivityMonitor());
      }
    });
  }

  @override
  void didUpdateWidget(covariant HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.startFeatureGuide && widget.startFeatureGuide) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _startFeatureGuide();
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    unawaited(_loadDashboard());
    unawaited(_refreshOrenEnergy());
    unawaited(_refreshInactivityMonitor());
  }

  Future<void> _refreshInactivityMonitor() async {
    lastInactivityRefreshAt = DateTime.now();
    try {
      await inactivityService.checkInactivity();
      await _loadInactivityStatus(lastCheckin);
    } catch (_) {
      // Dashboard loading and manual check-in remain available offline.
    }
  }

  Future<void> _refreshOrenEnergy() async {
    final state = await orenCareService.load();
    if (!mounted) return;
    setState(() => orenCare = state);
  }

  Future<void> _loadInactivityStatus(
    DateTime? latestCheckIn, {
    int? requestId,
  }) async {
    final status = await inactivityService.getCurrentStatus(
      latestCheckIn: latestCheckIn,
    );
    if (!mounted || (requestId != null && requestId != dashboardRequestId)) {
      return;
    }
    setState(() {
      inactivityNotificationCount = status.notificationCount;
      inactivityEscalated = status.escalated;
      inactivityUserSmsAccepted = status.userSmsAccepted;
      inactivityUserSmsError = status.userSmsError;
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
      final checkedAt = DateTime.now();
      final created = await checkinService.addCheckin();
      if (created && mounted) {
        setState(() {
          lastCheckin = checkedAt;
          inactivityNotificationCount = 0;
          inactivityEscalated = false;
          inactivityUserSmsAccepted = false;
          inactivityUserSmsError = null;
          historyRefreshTick += 1;
        });
      }
      final rewardedState = await orenCareService.awardDailyCheckInTokens();
      final tokenAwarded = rewardedState.tokens > careState.tokens;
      _showTemporaryOrenState(rewardedState);
      if (created) {
        try {
          await RewardService().checkReward();
        } catch (_) {
          // The safety check-in succeeded; rewards can synchronize later.
        }
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

  Future<OrenCareState> _buyToy(OrenToy toy) async {
    final state = await orenCareService.buyToy(toy);
    if (!mounted) return state;
    _showTemporaryOrenState(
      state,
      toy: state.ownedToyIds.contains(toy.id) ? toy : null,
    );
    if (state.ownedToyIds.contains(toy.id)) {
      unawaited(orenSoundService.playPlayful());
    }
    _showMessage(state.lastAction);
    return state;
  }

  Future<void> _playWithToy(OrenToy toy) async {
    final state = await orenCareService.playWithToy(toy);
    if (!mounted) return;
    _showTemporaryOrenState(
      state,
      toy: state.ownedToyIds.contains(toy.id) ? toy : null,
    );
    if (state.ownedToyIds.contains(toy.id)) {
      unawaited(orenSoundService.playPlayful());
    }
    _showMessage(state.lastAction);
  }

  Future<void> _playSelectedToy() async {
    final toy = _selectedToyFor(orenCare);
    if (toy == null) {
      _showMessage('Buy and choose an item before playing with Oren.');
      await _showOrenShop();
      return;
    }
    await _playWithToy(toy);
  }

  Future<OrenCareState> _selectToy(OrenToy toy) async {
    final state = await orenCareService.selectToy(toy);
    if (!mounted) return state;
    _showTemporaryOrenState(state, toy: toy);
    _showMessage(state.lastAction);
    return state;
  }

  OrenToy? _selectedToyFor(OrenCareState state) {
    for (final toy in OrenCareService.toyCatalog) {
      if (toy.id == state.selectedToyId && state.ownedToyIds.contains(toy.id)) {
        return toy;
      }
    }
    return null;
  }

  Future<void> _showOrenHelp() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: AppColors.glassStrong,
      builder: (context) => const _OrenHelpSheet(),
    );
  }

  void _startFeatureGuide() {
    _showFeatureGuideStep(0, activate: true);
  }

  void _showFeatureGuideStep(int step, {bool activate = false}) {
    final nextStep = step.clamp(0, featureGuideSteps.length - 1).toInt();
    final pageIndex = featureGuideSteps[nextStep].pageIndex;
    setState(() {
      featureGuideActive = activate || featureGuideActive;
      featureGuideStep = nextStep;
      selectedIndex = pageIndex;
      if (pageIndex == 1) historyRefreshTick += 1;
      if (pageIndex == 2) contactsRefreshTick += 1;
      if (pageIndex == 3) rewardsRefreshTick += 1;
      if (pageIndex == 4) profileRefreshTick += 1;
    });
    if (pageIndex == 0) unawaited(_loadDashboard());
    unawaited(_scrollFeatureGuidePageToTop(pageIndex));
  }

  Future<void> _scrollFeatureGuidePageToTop(int pageIndex) async {
    final request = ++featureGuideScrollRequest;
    const attempts = [
      Duration.zero,
      Duration(milliseconds: 60),
      Duration(milliseconds: 360),
    ];

    for (final delay in attempts) {
      if (delay > Duration.zero) await Future<void>.delayed(delay);
      if (!mounted ||
          request != featureGuideScrollRequest ||
          selectedIndex != pageIndex) {
        return;
      }

      await WidgetsBinding.instance.endOfFrame;
      if (!mounted ||
          request != featureGuideScrollRequest ||
          selectedIndex != pageIndex) {
        return;
      }

      final controller = pageScrollControllers[pageIndex];
      if (!controller.hasClients) continue;
      try {
        controller.jumpTo(controller.position.minScrollExtent);
      } on StateError {
        // A tab can detach its old ScrollPosition while rebuilding.
      }
    }
  }

  Future<void> _finishFeatureGuide() async {
    if (!featureGuideActive) return;
    setState(() => featureGuideActive = false);
    try {
      await widget.onFeatureGuideComplete?.call();
    } catch (error) {
      if (mounted) _showMessage('Could not save guide progress: $error');
    }
  }

  void _nextFeatureGuideStep() {
    if (featureGuideStep == featureGuideSteps.length - 1) {
      unawaited(_finishFeatureGuide());
      return;
    }
    _showFeatureGuideStep(featureGuideStep + 1);
  }

  Future<void> _showOrenShop() async {
    var sheetState = orenCare;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: AppColors.glassStrong,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => _OrenShopSheet(
          state: sheetState,
          onToyPressed: (toy) async {
            final nextState = sheetState.ownedToyIds.contains(toy.id)
                ? await _selectToy(toy)
                : await _buyToy(toy);
            if (!sheetContext.mounted) return;
            setSheetState(() => sheetState = nextState);
          },
        ),
      ),
    );
  }

  Future<void> _showOwnedToyPicker() async {
    final ownedToys = OrenCareService.toyCatalog
        .where((toy) => orenCare.ownedToyIds.contains(toy.id))
        .toList();
    if (ownedToys.isEmpty) {
      _showMessage('No bought items yet. Open Oren Shop to get one.');
      await _showOrenShop();
      return;
    }

    final selected = await showModalBottomSheet<OrenToy>(
      context: context,
      showDragHandle: true,
      backgroundColor: AppColors.glassStrong,
      builder: (context) => _OwnedToyPickerSheet(
        toys: ownedToys,
        selectedToyId: orenCare.selectedToyId,
      ),
    );
    if (selected != null) await _selectToy(selected);
  }

  void _showTemporaryOrenState(OrenCareState state, {OrenToy? toy}) {
    if (!mounted) return;
    orenResetTimer?.cancel();
    setState(() {
      orenCare = state;
      activeToyId = toy?.id;
      activeToyAsset = toy?.imageAsset;
    });
    orenResetTimer = Timer(const Duration(seconds: 4), () async {
      final calmState = await orenCareService.resetMood();
      if (!mounted) return;
      setState(() {
        orenCare = calmState;
        activeToyId = null;
        activeToyAsset = null;
      });
    });
  }

  Future<void> _loadDashboard() async {
    final requestId = ++dashboardRequestId;
    final cachedResults = await Future.wait([
      dashboardService.loadCached(),
      rewardService.loadCached(),
      weatherService.loadCached(),
      checkinService.getLatestCachedCheckinTime(),
    ]);
    if (!mounted || requestId != dashboardRequestId) return;
    final cachedDashboard = cachedResults[0] as DashboardSnapshot?;
    if (cachedDashboard != null) {
      _applyDashboard(cachedDashboard);
    }
    final cachedCheckIn = cachedResults[3] as DateTime?;
    if (cachedCheckIn != null &&
        (lastCheckin == null || cachedCheckIn.isAfter(lastCheckin!))) {
      setState(() => lastCheckin = cachedCheckIn);
    }
    if (cachedDashboard != null || cachedCheckIn != null) {
      await _loadInactivityStatus(
        lastCheckin,
        requestId: requestId,
      );
    }
    if (!mounted || requestId != dashboardRequestId) return;
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
      if (!mounted || requestId != dashboardRequestId) return;
      final dashboard = results[0] as DashboardSnapshot;
      _applyDashboard(dashboard);
      await _loadInactivityStatus(lastCheckin, requestId: requestId);
      if (!mounted || requestId != dashboardRequestId) return;
      setState(() {
        rewardSnapshot = results[1] as RewardSnapshot;
        weather = results[2] as WeatherSnapshot?;
        loadError = null;
      });
    } catch (_) {
      if (mounted && requestId == dashboardRequestId) {
        setState(() => loadError = 'Unable to refresh dashboard data.');
      }
    }
  }

  void _applyDashboard(DashboardSnapshot snapshot) {
    if (!mounted) return;
    setState(() {
      userName = snapshot.userName;
      final refreshedCheckIn = snapshot.lastCheckin;
      if (refreshedCheckIn != null &&
          (lastCheckin == null || refreshedCheckIn.isAfter(lastCheckin!))) {
        lastCheckin = refreshedCheckIn;
      }
      streak = snapshot.streak;
      emergencyStatus = snapshot.emergencyStatus;
      latestEmergencyAlertTime = snapshot.latestEmergencyAlertTime;
      inactivityThresholdHours = snapshot.inactivityThresholdHours;
    });
  }

  Future<void> _triggerSos() async {
    final action = await showDialog<_SosAction>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
                    borderRadius: BorderRadius.circular(8),
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
                    borderRadius: BorderRadius.circular(8),
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
        allowDirectSms: false,
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
      return 'Your check-in is still current. +${OrenCareService.dailyCheckInTokenReward} daily Oren tokens added.';
    }
    return 'Your check-in is still current for the $inactivityThresholdHours-hour window. Oren token bonus is once per day.';
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

  String _emergencyResultMessage(EmergencyTriggerResult result) {
    if (result.official999Selected) {
      return result.dialerOpened
          ? 'Emergency alert recorded. The 999 dialer is open for you to place the call.'
          : 'Emergency alert recorded. Call 999 directly for immediate help.';
    }
    if (result.autoSmsSent > 0) {
      return result.locationIncluded
          ? 'Emergency alert recorded. Automated SMS and location link sent to your primary contact.'
          : 'Emergency alert recorded and SMS sent, but GPS location was unavailable.';
    }
    if (result.autoSmsAttempted) {
      final error = result.autoSmsError;
      if (error != null && error.trim().isNotEmpty) {
        return 'Emergency alert recorded, but automated SMS did not send: $error';
      }
      return result.locationIncluded
          ? 'Emergency alert recorded. SMS with the location link is queued for automated delivery.'
          : 'Emergency alert recorded. SMS is queued, but GPS location was unavailable.';
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
    WidgetsBinding.instance.removeObserver(this);
    featureGuideScrollRequest += 1;
    orenResetTimer?.cancel();
    thresholdRefreshTimer?.cancel();
    for (final controller in pageScrollControllers) {
      controller.dispose();
    }
    unawaited(orenSoundService.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      _HomeDashboard(
        scrollController: pageScrollControllers[0],
        loading: loading,
        streak: streak,
        lastCheckin: lastCheckin,
        inactivityThresholdHours: inactivityThresholdHours,
        userName: userName,
        loadError: loadError,
        emergencyStatus: emergencyStatus,
        latestEmergencyAlertTime: latestEmergencyAlertTime,
        rewardSnapshot: rewardSnapshot,
        weather: weather,
        orenCare: orenCare,
        activeToyId: activeToyId,
        activeToyAsset: activeToyAsset,
        onPet: petCat,
        onFeedFish: _feedFish,
        onPlay: _playSelectedToy,
        onChooseToy: _showOwnedToyPicker,
        onOpenShop: _showOrenShop,
        onOrenInfo: _showOrenHelp,
        onSos: _triggerSos,
        onTestSms: _testPrimarySms,
        showSafetyTestTools: HomeScreen.showSafetyTestTools,
        inactivityNotificationCount: inactivityNotificationCount,
        inactivityEscalated: inactivityEscalated,
        inactivityUserSmsAccepted: inactivityUserSmsAccepted,
        inactivityUserSmsError: inactivityUserSmsError,
        onSignOut: _signOut,
        onRefresh: _loadDashboard,
      ),
      CheckinHistoryScreen(
        refreshVersion: historyRefreshTick,
        scrollController: pageScrollControllers[1],
      ),
      ContactsScreen(
        key: ValueKey('contacts-$contactsRefreshTick'),
        scrollController: pageScrollControllers[2],
      ),
      RewardsScreen(
        key: ValueKey('rewards-$rewardsRefreshTick'),
        scrollController: pageScrollControllers[3],
      ),
      ProfileScreen(
        key: ValueKey('profile-$profileRefreshTick'),
        onOpenFeatureGuide: _startFeatureGuide,
        scrollController: pageScrollControllers[4],
      ),
    ];

    return Stack(
      children: [
        PremiumScaffold(
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
                    if (value == 1) historyRefreshTick += 1;
                    if (value == 2) contactsRefreshTick += 1;
                    if (value == 3) rewardsRefreshTick += 1;
                    if (value == 4) profileRefreshTick += 1;
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
        ),
        if (featureGuideActive)
          Positioned.fill(
            child: FeatureGuideOverlay(
              steps: featureGuideSteps,
              currentStep: featureGuideStep,
              onNext: _nextFeatureGuideStep,
              onBack: featureGuideStep == 0
                  ? null
                  : () => _showFeatureGuideStep(featureGuideStep - 1),
              onSkip: () => unawaited(_finishFeatureGuide()),
            ),
          ),
      ],
    );
  }
}

enum _SosAction { call999, sendAlert }

class _HomeDashboard extends StatelessWidget {
  const _HomeDashboard({
    required this.scrollController,
    required this.loading,
    required this.streak,
    required this.lastCheckin,
    required this.inactivityThresholdHours,
    required this.userName,
    required this.loadError,
    required this.emergencyStatus,
    required this.latestEmergencyAlertTime,
    required this.rewardSnapshot,
    required this.weather,
    required this.orenCare,
    required this.activeToyId,
    required this.activeToyAsset,
    required this.onPet,
    required this.onFeedFish,
    required this.onPlay,
    required this.onChooseToy,
    required this.onOpenShop,
    required this.onOrenInfo,
    required this.onSos,
    required this.onTestSms,
    required this.showSafetyTestTools,
    required this.inactivityNotificationCount,
    required this.inactivityEscalated,
    required this.inactivityUserSmsAccepted,
    required this.inactivityUserSmsError,
    required this.onSignOut,
    required this.onRefresh,
  });

  final ScrollController scrollController;
  final bool loading;
  final int streak;
  final DateTime? lastCheckin;
  final int inactivityThresholdHours;
  final String userName;
  final String? loadError;
  final String emergencyStatus;
  final DateTime? latestEmergencyAlertTime;
  final RewardSnapshot? rewardSnapshot;
  final WeatherSnapshot? weather;
  final OrenCareState orenCare;
  final String? activeToyId;
  final String? activeToyAsset;
  final VoidCallback onPet;
  final VoidCallback onFeedFish;
  final VoidCallback onPlay;
  final VoidCallback onChooseToy;
  final VoidCallback onOpenShop;
  final VoidCallback onOrenInfo;
  final VoidCallback onSos;
  final VoidCallback onTestSms;
  final bool showSafetyTestTools;
  final int inactivityNotificationCount;
  final bool inactivityEscalated;
  final bool inactivityUserSmsAccepted;
  final String? inactivityUserSmsError;
  final VoidCallback onSignOut;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final horizontalPadding = MediaQuery.sizeOf(context).width < 360
        ? 14.0
        : 20.0;
    final now = DateTime.now();
    final checkInCurrent = InactivityService.isCheckInCurrent(
      lastCheckIn: lastCheckin,
      now: now,
      thresholdHours: inactivityThresholdHours,
    );
    final nextDueAt = InactivityService.nextCheckInDueAt(
      lastCheckIn: lastCheckin,
      thresholdHours: inactivityThresholdHours,
    );
    final greeting = now.hour < 12
        ? 'Good Morning'
        : now.hour < 18
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
        controller: scrollController,
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
                  const OrenPageTitleIcon(
                    asset:
                        'lib/assets/images/pixel/oren_pixel_full_energy_transparent.png',
                    semanticLabel: 'Energetic Oren welcoming you home',
                    size: 54,
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
          Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: _OrenStatusBar(
                message: orenCare.lastAction,
                mood: orenCare.mood,
                energy: orenCare.energy,
                onInfo: onOrenInfo,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: VirtualPetWidget(
                streak: streak,
                hasCheckedInToday: checkInCurrent,
                weather: weather,
                mood: orenCare.mood,
                energy: orenCare.energy,
                tokens: orenCare.tokens,
                activeToyId: activeToyId,
                activeToyAsset: activeToyAsset,
                onOpenShop: onOpenShop,
                onTap: onPet,
                loading: loading,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: _OrenActionPanel(
                state: orenCare,
                onFeedFish: onFeedFish,
                onPlay: onPlay,
                onChooseToy: onChooseToy,
              ),
            ),
          ),
          const SizedBox(height: 14),
          _CenteredHomeSection(
            child: Column(
              children: [
                Card(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        const CircleAvatar(
                          backgroundColor: AppColors.accent,
                          foregroundColor: Colors.white,
                          child: Icon(Icons.workspace_premium_outlined),
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
                                      nextReward?.title ??
                                          'All rewards earned',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
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
                                const Text(
                                  'Virtual badge unlocks automatically',
                                  style: TextStyle(
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
                _CheckInStatusBanner(
                  isCurrent: checkInCurrent,
                  lastCheckIn: lastCheckin,
                  nextDueAt: nextDueAt,
                  thresholdHours: inactivityThresholdHours,
                ),
                const SizedBox(height: 18),
                _SafetyActionPanel(
                  onSos: onSos,
                  onTestSms: onTestSms,
                  showTestTools: showSafetyTestTools,
                ),
                const SizedBox(height: 14),
                _InactivityReminderCard(
                  count: inactivityNotificationCount,
                  escalated: inactivityEscalated,
                  userSmsAccepted: inactivityUserSmsAccepted,
                  userSmsError: inactivityUserSmsError,
                ),
                const SizedBox(height: 14),
                _EmergencyStatusCard(
                  status: emergencyStatus,
                  latestAlertTime: latestEmergencyAlertTime,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CenteredHomeSection extends StatelessWidget {
  const _CenteredHomeSection({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: SizedBox(width: double.infinity, child: child),
      ),
    );
  }
}

class _CheckInStatusBanner extends StatelessWidget {
  const _CheckInStatusBanner({
    required this.isCurrent,
    required this.lastCheckIn,
    required this.nextDueAt,
    required this.thresholdHours,
  });

  final bool isCurrent;
  final DateTime? lastCheckIn;
  final DateTime? nextDueAt;
  final int thresholdHours;

  @override
  Widget build(BuildContext context) {
    final title = isCurrent
        ? 'Check-in is current'
        : 'Oren is waiting for you!';
    final detail = isCurrent && nextDueAt != null
        ? 'Current until ${DateFormat('MMM d, h:mm a').format(nextDueAt!.toLocal())}'
        : lastCheckIn == null
        ? 'Tap Oren to start your safety heartbeat.'
        : '${thresholdHours}h window ended. Tap Oren to renew it.';
    final color = isCurrent ? AppColors.primary : AppColors.accent;
    final detailColor = isCurrent
        ? AppColors.primaryDark
        : const Color(0xFFC66D00);

    return Semantics(
      container: true,
      liveRegion: true,
      label: '$title. $detail',
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: SizeTransition(sizeFactor: animation, child: child),
        ),
        child: Container(
          key: ValueKey(isCurrent),
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 78),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: isCurrent ? AppColors.primarySoft : AppColors.warningSoft,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withValues(alpha: .38)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  isCurrent
                      ? Icons.check_circle_outline_rounded
                      : Icons.warning_amber_rounded,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: AppColors.ink,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      detail,
                      style: TextStyle(
                        color: detailColor,
                        fontSize: 12,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InactivityReminderCard extends StatelessWidget {
  const _InactivityReminderCard({
    required this.count,
    required this.escalated,
    required this.userSmsAccepted,
    required this.userSmsError,
  });

  final int count;
  final bool escalated;
  final bool userSmsAccepted;
  final String? userSmsError;

  @override
  Widget build(BuildContext context) {
    const requiredCount = InactivityService.missedCheckInsBeforeEscalation;
    final safeCount = count.clamp(0, requiredCount).toInt();
    final reachedLimit = safeCount >= requiredCount;
    final color = reachedLimit ? AppColors.danger : AppColors.accent;
    final detail = escalated
        ? 'Your configured emergency escalation started after reminder 3. Tap Oren to check in and reset this cycle.'
        : reachedLimit
        ? 'Reminder 3 reached. Your primary contact receives the emergency SMS. Tap Oren to check in and reset this cycle.'
        : safeCount >= InactivityService.userSmsReminderMiss && userSmsAccepted
        ? 'Reminder 2 reached. An SMS reminder was sent or queued for your verified phone.'
        : safeCount >= InactivityService.userSmsReminderMiss
        ? 'Reminder 2 reached, but the SMS to your verified phone needs attention${userSmsError == null ? '.' : ': $userSmsError'}'
        : safeCount == 0
        ? 'No missed reminders. Reminder 2 sends an SMS to you; reminder 3 starts primary-contact escalation.'
        : 'Reminder 1 reached. The next missed threshold sends an SMS to your verified phone.';

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
            Semantics(
              label: 'Inactivity reminders',
              value: '$safeCount of $requiredCount reminders reached',
              child: LinearProgressIndicator(
                value: safeCount / requiredCount,
                minHeight: 7,
                borderRadius: BorderRadius.circular(8),
                color: color,
                backgroundColor: AppColors.surface,
              ),
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
    final isInactivityAlert = normalizedStatus == 'inactivity_triggered';
    final isRealAlert = normalizedStatus == 'triggered' || isInactivityAlert;
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
    final title = isInactivityAlert
        ? 'Latest inactivity escalation'
        : isRealAlert
        ? 'Latest emergency alert'
        : 'Safety monitor';
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

class _SafetyActionPanel extends StatelessWidget {
  const _SafetyActionPanel({
    required this.onSos,
    required this.onTestSms,
    required this.showTestTools,
  });

  final VoidCallback onSos;
  final VoidCallback onTestSms;
  final bool showTestTools;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.danger.withValues(alpha: .10),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.health_and_safety_outlined,
                  color: AppColors.danger,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Safety Actions',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                    Text(
                      showTestTools
                          ? 'Emergency and testing controls'
                          : 'Emergency contact controls',
                      style: const TextStyle(
                        color: AppColors.muted,
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
        _SafetyActionTile(
          icon: Icons.sos,
          color: AppColors.danger,
          title: 'SOS emergency',
          subtitle: 'Record an alert and notify your primary contact.',
          onTap: onSos,
        ),
        if (showTestTools) ...[
          const SizedBox(height: 10),
          _SafetyActionTile(
            icon: Icons.sms_outlined,
            color: AppColors.blue,
            title: 'Test primary SMS',
            subtitle: 'Send a safe automated test message.',
            onTap: onTestSms,
          ),
        ],
      ],
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
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 78),
      child: Material(
        color: Colors.white.withValues(alpha: .82),
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Ink(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: enabled
                  ? color.withValues(alpha: .07)
                  : AppColors.surface.withValues(alpha: .72),
              borderRadius: BorderRadius.circular(8),
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
                    borderRadius: BorderRadius.circular(8),
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
                Icon(
                  Icons.chevron_right_rounded,
                  color: enabled ? color : AppColors.muted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OrenStatusBar extends StatelessWidget {
  const _OrenStatusBar({
    required this.message,
    required this.mood,
    required this.energy,
    required this.onInfo,
  });

  final String message;
  final String mood;
  final int energy;
  final VoidCallback onInfo;

  @override
  Widget build(BuildContext context) {
    final status = _statusLabel;
    final statusColor = energy >= 90
        ? AppColors.accent
        : energy <= 25
        ? AppColors.muted
        : AppColors.primary;

    return Semantics(
      container: true,
      label: 'Oren status: $status.',
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(_statusIcon, size: 26, color: statusColor),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  status,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  message.trim().isEmpty ? 'Oren is ready for today.' : message,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filledTonal(
            onPressed: onInfo,
            icon: const Icon(Icons.info_outline_rounded),
            tooltip: 'How to care for Oren',
            color: AppColors.primaryDark,
            style: IconButton.styleFrom(
              minimumSize: const Size.square(44),
              backgroundColor: AppColors.primarySoft,
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

class _OrenActionPanel extends StatelessWidget {
  const _OrenActionPanel({
    required this.state,
    required this.onFeedFish,
    required this.onPlay,
    required this.onChooseToy,
  });

  final OrenCareState state;
  final VoidCallback onFeedFish;
  final VoidCallback onPlay;
  final VoidCallback onChooseToy;

  @override
  Widget build(BuildContext context) {
    OrenToy? selectedToy;
    for (final toy in OrenCareService.toyCatalog) {
      if (toy.id == state.selectedToyId && state.ownedToyIds.contains(toy.id)) {
        selectedToy = toy;
        break;
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: onFeedFish,
                  icon: const Icon(Icons.set_meal_outlined),
                  label: const Text('Feed Fish'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 54),
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: selectedToy == null ? null : onPlay,
                  icon: const Icon(Icons.sports_esports_outlined),
                  label: const Text('Play'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 54),
                    backgroundColor: AppColors.accent,
                    foregroundColor: AppColors.ink,
                    disabledBackgroundColor: AppColors.border,
                    disabledForegroundColor: AppColors.muted,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: onChooseToy,
            icon: Icon(
              selectedToy == null
                  ? Icons.inventory_2_outlined
                  : Icons.check_circle_outline,
            ),
            label: Text(
              selectedToy == null
                  ? 'Choose a bought item'
                  : 'Selected: ${selectedToy.name}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 54),
              backgroundColor: Colors.white.withValues(alpha: .74),
              side: const BorderSide(color: AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }
}

class _OrenHelpSheet extends StatelessWidget {
  const _OrenHelpSheet();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'Meet Oren',
              style: TextStyle(
                color: AppColors.ink,
                fontSize: 24,
                fontWeight: FontWeight.w900,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Oren is your threshold-based check-in companion.',
              style: TextStyle(color: AppColors.muted),
            ),
            SizedBox(height: 16),
            _OrenHelpItem(
              icon: Icons.pets_outlined,
              title: 'Tap Oren',
              detail: 'Records today\'s safety check-in and cares for Oren.',
            ),
            _OrenHelpItem(
              icon: Icons.set_meal_outlined,
              title: 'Feed Fish',
              detail: 'Restores Oren\'s energy.',
            ),
            _OrenHelpItem(
              icon: Icons.inventory_2_outlined,
              title: 'Choose, then Play',
              detail: 'Select a bought item and watch its play animation.',
            ),
            Divider(height: 26),
            Text(
              'Earning tokens',
              style: TextStyle(
                color: AppColors.ink,
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
            SizedBox(height: 8),
            _OrenHelpItem(
              icon: Icons.wb_sunny_outlined,
              title: 'Daily visit: +5',
              detail: 'Open EthernaCare before your check-in window expires.',
            ),
            _OrenHelpItem(
              icon: Icons.check_circle_outline,
              title: 'Daily check-in: +3',
              detail:
                  'The token bonus is daily; safety check-ins follow your configured threshold.',
            ),
          ],
        ),
      ),
    );
  }
}

class _OrenHelpItem extends StatelessWidget {
  const _OrenHelpItem({
    required this.icon,
    required this.title,
    required this.detail,
  });

  final IconData icon;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.primarySoft,
            foregroundColor: AppColors.primaryDark,
            child: Icon(icon, size: 19),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.ink,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  detail,
                  style: const TextStyle(color: AppColors.muted, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OrenShopSheet extends StatelessWidget {
  const _OrenShopSheet({required this.state, required this.onToyPressed});

  final OrenCareState state;
  final Future<void> Function(OrenToy toy) onToyPressed;

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.sizeOf(context).height * .68;
    return SafeArea(
      top: false,
      child: SizedBox(
        height: maxHeight.clamp(390.0, 560.0),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Oren Shop',
                style: TextStyle(
                  color: AppColors.ink,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Use tokens earned from daily visits and check-ins.',
                style: TextStyle(color: AppColors.muted),
              ),
              const SizedBox(height: 12),
              _TokenBalanceBar(tokens: state.tokens),
              const SizedBox(height: 14),
              Expanded(
                child: ListView.separated(
                  itemCount: OrenCareService.toyCatalog.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final toy = OrenCareService.toyCatalog[index];
                    final owned = state.ownedToyIds.contains(toy.id);
                    return _ShopToyTile(
                      toy: toy,
                      owned: owned,
                      selected: state.selectedToyId == toy.id,
                      canBuy: state.tokens >= toy.price,
                      onPressed: () => unawaited(onToyPressed(toy)),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OwnedToyPickerSheet extends StatelessWidget {
  const _OwnedToyPickerSheet({required this.toys, required this.selectedToyId});

  final List<OrenToy> toys;
  final String selectedToyId;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Choose an item',
              style: TextStyle(
                color: AppColors.ink,
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'The selected item will be used when you tap Play.',
              style: TextStyle(color: AppColors.muted),
            ),
            const SizedBox(height: 12),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: toys.length,
                separatorBuilder: (context, index) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final toy = toys[index];
                  final selected = toy.id == selectedToyId;
                  return _ShopToyTile(
                    toy: toy,
                    owned: true,
                    selected: selected,
                    canBuy: true,
                    onPressed: selected
                        ? null
                        : () => Navigator.pop(context, toy),
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

class _ShopToyTile extends StatelessWidget {
  const _ShopToyTile({
    required this.toy,
    required this.owned,
    required this.selected,
    required this.canBuy,
    required this.onPressed,
  });

  final OrenToy toy;
  final bool owned;
  final bool selected;
  final bool canBuy;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: selected ? AppColors.primarySoft : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: selected ? AppColors.primary : AppColors.border,
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 72,
            height: 72,
            child: Image.asset(
              toy.imageAsset,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.none,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  toy.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 3),
                Text(
                  selected
                      ? 'Selected for playtime'
                      : owned
                      ? 'Owned item'
                      : toy.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.muted, fontSize: 11),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 88,
            child: FilledButton.tonal(
              onPressed: selected ? null : onPressed,
              style: FilledButton.styleFrom(
                minimumSize: const Size(88, 42),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                foregroundColor: owned || canBuy
                    ? AppColors.primaryDark
                    : AppColors.muted,
              ),
              child: Text(
                selected
                    ? 'Selected'
                    : owned
                    ? 'Select'
                    : '${toy.price} tok',
                maxLines: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TokenBalanceBar extends StatelessWidget {
  const _TokenBalanceBar({required this.tokens});

  final int tokens;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.warningSoft,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Image.asset(
            'lib/assets/images/pixel/oren_pixel_token_transparent.png',
            width: 30,
            height: 30,
            filterQuality: FilterQuality.none,
          ),
          const SizedBox(width: 9),
          const Expanded(
            child: Text(
              'Token balance',
              style: TextStyle(
                color: AppColors.ink,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Text(
            '$tokens tokens',
            style: const TextStyle(
              color: Color(0xFFC66D00),
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}
