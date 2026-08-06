import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fyp/main.dart' as app;
import 'package:fyp/core/constants/colors.dart';
import 'package:fyp/core/routes/app_routes.dart';
import 'package:fyp/core/theme/app_theme.dart';
import 'package:fyp/models/ai_chat_message.dart';
import 'package:fyp/models/location_model.dart';
import 'package:fyp/models/checkin_model.dart';
import 'package:fyp/models/contact_model.dart';
import 'package:fyp/models/document_model.dart';
import 'package:fyp/models/emergency_alert_model.dart';
import 'package:fyp/models/legacy_note_model.dart';
import 'package:fyp/models/legacy_access_result.dart';
import 'package:fyp/models/oren_care_model.dart';
import 'package:fyp/models/reward_model.dart';
import 'package:fyp/models/user_model.dart';
import 'package:fyp/businessLogicLayer/controllers/checkin_controller.dart';
import 'package:fyp/businessLogicLayer/controllers/contact_controller.dart';
import 'package:fyp/businessLogicLayer/providers/auth_provider.dart';
import 'package:fyp/presentation/screen/admin/admin_auth_gate.dart';
import 'package:fyp/presentation/screen/admin/admin_reward_catalog_screen.dart';
import 'package:fyp/presentation/screen/auth/login_screen.dart';
import 'package:fyp/presentation/screen/contacts/add_contact_dialog.dart';
import 'package:fyp/presentation/screen/home/home_screen.dart';
import 'package:fyp/presentation/screen/home/pet_button.dart';
import 'package:fyp/presentation/screen/home/virtual_pet_widget.dart';
import 'package:fyp/presentation/screen/legal/terms_and_conditions_screen.dart';
import 'package:fyp/presentation/screen/planning/legacy_check_screen.dart';
import 'package:fyp/presentation/screen/profile/profile_screen.dart';
import 'package:fyp/presentation/screen/rewards/reward_collection_screen.dart';
import 'package:fyp/presentation/widgets/custom_button.dart';
import 'package:fyp/presentation/widgets/error_dialog.dart';
import 'package:fyp/presentation/widgets/feature_guide_overlay.dart';
import 'package:fyp/presentation/widgets/guidance_sheet.dart';
import 'package:fyp/presentation/widgets/loading_indicator.dart';
import 'package:fyp/presentation/widgets/premium_shell.dart';
import 'package:fyp/dataAccessLayer/repositories/contact_repository.dart';
import 'package:fyp/services/reward_service.dart';
import 'package:fyp/services/ai_service.dart';
import 'package:fyp/services/document_service.dart';
import 'package:fyp/services/emergency_service.dart';
import 'package:fyp/services/inactivity_service.dart';
import 'package:fyp/services/local_cache_service.dart';
import 'package:fyp/services/oren_care_service.dart';
import 'package:fyp/services/phone_verification_service.dart';
import 'package:fyp/services/user_service.dart';
import 'package:fyp/utils/validators.dart';

void main() {
  test('app bootstrap compiles', () {
    expect(app.MyApp, isNotNull);
  });

  test('auth screen remains available for email and OAuth flows', () {
    expect(LoginScreen, isNotNull);
  });

  test('reward admin uses a separate direct route and protected gate', () {
    expect(AppRoutes.adminRewards, '/admin/rewards');
    expect(AdminAuthGate, isNotNull);
    expect(AdminRewardCatalogScreen, isNotNull);
  });

  test('inactivity escalates only after three missed threshold windows', () {
    final lastCheckIn = DateTime.utc(2026, 7, 1, 8);

    int missesAfter(Duration elapsed) =>
        InactivityService.calculateMissedCheckIns(
          lastCheckIn: lastCheckIn,
          now: lastCheckIn.add(elapsed),
          thresholdHours: 24,
        );

    expect(missesAfter(const Duration(hours: 23, minutes: 59)), 0);
    expect(missesAfter(const Duration(hours: 24)), 1);
    expect(missesAfter(const Duration(hours: 48)), 2);
    expect(missesAfter(const Duration(hours: 72)), 3);
  });

  test('sub-day inactivity values normalize to the 24-hour minimum', () {
    final lastCheckIn = DateTime.utc(2026, 8, 1, 8);

    expect(
      InactivityService.calculateMissedCheckIns(
        lastCheckIn: lastCheckIn,
        now: lastCheckIn.add(const Duration(hours: 23, minutes: 59)),
        thresholdHours: 1,
      ),
      0,
    );
    expect(
      InactivityService.calculateMissedCheckIns(
        lastCheckIn: lastCheckIn,
        now: lastCheckIn.add(const Duration(hours: 24)),
        thresholdHours: 1,
      ),
      1,
    );
    expect(
      InactivityService.calculateMissedCheckIns(
        lastCheckIn: lastCheckIn,
        now: lastCheckIn.add(const Duration(hours: 48)),
        thresholdHours: 1,
      ),
      InactivityService.userSmsReminderMiss,
    );
  });

  test('check-in current state follows the rolling threshold', () {
    final lastCheckIn = DateTime.utc(2026, 8, 1, 8);

    expect(
      InactivityService.isCheckInCurrent(
        lastCheckIn: lastCheckIn,
        now: lastCheckIn.add(const Duration(hours: 23, minutes: 59)),
        thresholdHours: 24,
      ),
      isTrue,
    );
    expect(
      InactivityService.isCheckInCurrent(
        lastCheckIn: lastCheckIn,
        now: lastCheckIn.add(const Duration(hours: 24)),
        thresholdHours: 24,
      ),
      isFalse,
    );
    expect(
      InactivityService.nextCheckInDueAt(
        lastCheckIn: lastCheckIn,
        thresholdHours: 24,
      ),
      lastCheckIn.add(const Duration(hours: 24)),
    );
  });

  test(
    'test reminders use stage two for user SMS and stage three for contact',
    () {
      expect(InactivityService.nextTestReminderCount(0), 1);
      expect(InactivityService.nextTestReminderCount(1), 2);
      expect(InactivityService.nextTestReminderCount(2), 3);
      expect(InactivityService.nextTestReminderCount(3), 1);
      expect(InactivityService.userSmsReminderMiss, 2);
      expect(InactivityService.missedCheckInsBeforeEscalation, 3);
    },
  );

  test('inactivity user SMS explains the missed threshold windows', () {
    final message = EmergencyService.inactivityUserSmsMessage(
      thresholdHours: 1,
    );

    expect(message, contains('missed two 24-hour check-in windows'));
    expect(message, contains('primary trusted contact'));
  });

  test('Oren loses one energy for every complete inactive hour', () {
    final updatedAt = DateTime.utc(2026, 8, 1, 8);
    final state = OrenCareState.initial().copyWith(
      energy: 65,
      updatedAt: updatedAt,
    );

    final beforeOneHour = OrenCareService.applyEnergyDecay(
      state,
      updatedAt.add(const Duration(minutes: 59)),
    );
    final afterThreeAndHalfHours = OrenCareService.applyEnergyDecay(
      state,
      updatedAt.add(const Duration(hours: 3, minutes: 30)),
    );

    expect(beforeOneHour.energy, 65);
    expect(beforeOneHour.updatedAt, updatedAt);
    expect(afterThreeAndHalfHours.energy, 62);
    expect(
      afterThreeAndHalfHours.updatedAt,
      updatedAt.add(const Duration(hours: 3)),
    );
  });

  test('Oren energy decay stops at zero', () {
    final updatedAt = DateTime.utc(2026, 8, 1, 8);
    final state = OrenCareState.initial().copyWith(
      energy: 2,
      updatedAt: updatedAt,
    );

    final decayed = OrenCareService.applyEnergyDecay(
      state,
      updatedAt.add(const Duration(hours: 10)),
    );

    expect(decayed.energy, 0);
    expect(decayed.mood, 'Tired');
  });

  test('live feature guide is available for first login guidance', () {
    expect(FeatureGuideOverlay, isNotNull);
  });

  testWidgets('feature guide keeps the current app screen visible', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    const steps = [
      FeatureGuideStep(
        pageIndex: 0,
        pageLabel: 'Home',
        title: 'Meet Oren',
        description: 'Use the real Home screen.',
        icon: Icons.pets_outlined,
        color: AppColors.primary,
      ),
      FeatureGuideStep(
        pageIndex: 1,
        pageLabel: 'History',
        title: 'Review check-ins',
        description: 'Use the real History screen.',
        icon: Icons.history,
        color: AppColors.blue,
      ),
    ];
    var currentStep = 0;

    await tester.pumpWidget(MaterialApp(
      home: StatefulBuilder(
        builder: (context, setState) => Stack(
          children: [
            const Scaffold(body: Text('Current live app content')),
            FeatureGuideOverlay(
              steps: steps,
              currentStep: currentStep,
              onNext: () => setState(() => currentStep += 1),
              onBack: currentStep == 0
                  ? null
                  : () => setState(() => currentStep -= 1),
              onSkip: () {},
            ),
          ],
        ),
      ),
    ));
    await tester.pump();

    expect(find.text('Current live app content'), findsOneWidget);
    expect(find.text('Live Home screen'), findsOneWidget);
    expect(find.text('Meet Oren'), findsOneWidget);
    expect(find.text('Next'), findsOneWidget);

    await tester.tap(find.byKey(const Key('feature-guide-next')));
    await tester.pumpAndSettle();

    expect(find.text('Current live app content'), findsOneWidget);
    expect(find.text('Live History screen'), findsOneWidget);
    expect(find.text('Review check-ins'), findsOneWidget);
  });

  testWidgets('Terms document can be reviewed and explicitly accepted', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    bool? accepted;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () async {
                  accepted = await Navigator.of(context).push<bool>(
                    MaterialPageRoute(
                      builder: (_) =>
                          const TermsAndConditionsScreen(acceptanceMode: true),
                    ),
                  );
                },
                child: const Text('Open Terms'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open Terms'));
    await tester.pumpAndSettle();

    expect(find.text('EthernaCare Terms and Conditions'), findsOneWidget);
    expect(find.text('1. Agreement and eligibility'), findsOneWidget);
    expect(find.byKey(const Key('accept-terms-button')), findsOneWidget);

    await tester.tap(find.byKey(const Key('accept-terms-button')));
    await tester.pumpAndSettle();
    expect(accepted, isTrue);
  });

  testWidgets('contextual guidance opens and closes without overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: IconButton(
                tooltip: 'Open guide',
                icon: const Icon(Icons.info_outline),
                onPressed: () => GuidanceSheet.show(
                  context,
                  title: 'Screen Guide',
                  description: 'Learn what this screen does.',
                  items: const [
                    GuidanceItem(
                      icon: Icons.check_circle_outline,
                      title: 'Main action',
                      description: 'This explains the main action clearly.',
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byTooltip('Open guide'));
    await tester.pumpAndSettle();

    expect(find.text('Screen Guide'), findsOneWidget);
    expect(find.text('Main action'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Got it'));
    await tester.pumpAndSettle();
    expect(find.text('Screen Guide'), findsNothing);
  });

  test('home screen compiles with oren care shop', () {
    expect(HomeScreen, isNotNull);
  });

  test('missing profile columns are not reported as a contacts failure', () {
    final profileMessage = AppErrorDialog.friendlyMessage(
      "PostgrestException(message: Could not find the 'address_state' column of 'users' in the schema cache, code: PGRST204)",
    );
    final contactMessage = AppErrorDialog.friendlyMessage(
      "PostgrestException(message: Could not find the 'is_primary' column of 'contacts' in the schema cache, code: PGRST204)",
    );

    expect(profileMessage, contains('profile database'));
    expect(profileMessage, isNot(contains('contacts database')));
    expect(contactMessage, contains('contacts database'));
  });

  test('missing document columns report the Legacy Documents setup', () {
    final message = AppErrorDialog.friendlyMessage(
      "PostgrestException(message: Could not find the 'storage_path' column of 'documents' in the schema cache, code: PGRST204)",
    );

    expect(message, contains('document storage'));
    expect(message, isNot(contains('schema is still updating')));
  });

  testWidgets('page header displays a compact Oren pose without overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 180);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(
          body: Padding(
            padding: EdgeInsets.all(20),
            child: PremiumHeader(
              title: 'Emergency Contacts',
              subtitle: 'Oren can help you call a trusted contact.',
              orenAsset:
                  'lib/assets/images/pixel/oren_pixel_phone_call_transparent.png',
              orenSemanticLabel: 'Oren holding a phone',
              action: IconButton(
                onPressed: null,
                icon: Icon(Icons.person_add_alt_1),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Emergency Contacts'), findsOneWidget);
    expect(find.bySemanticsLabel('Oren holding a phone'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('themed action buttons remain bounded inside horizontal rows', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Row(
            children: [
              const Expanded(child: Text('Safe reminder test')),
              FilledButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.notifications_active_outlined),
                label: const Text('Test 1/3'),
              ),
            ],
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Test 1/3'), findsOneWidget);
  });

  test('architecture scaffold exposes models controllers and providers', () {
    final contact = ContactModel.fromJson({
      'id': '1',
      'user_id': 'u1',
      'name': 'Daughter',
      'relationship': 'Family',
      'phone': '0123456789',
      'email': 'daughter@example.com',
      'address': 'Kuala Lumpur',
      'is_primary': true,
    });
    final checkin = CheckinModel.fromJson({
      'user_id': 'u1',
      'checkin_time': '2026-06-25T08:00:00Z',
    });
    final alert = EmergencyAlertModel.fromJson({
      'user_id': 'u1',
      'triggered_time': '2026-06-25T08:00:00Z',
    });
    final user = UserModel.fromJson({
      'id': 'u1',
      'name': 'Kai Heng',
      'inactivity_threshold': 24,
    });

    expect(contact.isPrimary, isTrue);
    expect(contact.email, 'daughter@example.com');
    expect(checkin.status, 'active');
    expect(alert.status, 'triggered');
    expect(user.name, 'Kai Heng');
    expect(CheckinController, isNotNull);
    expect(ContactController, isNotNull);
    expect(authControllerProvider, isNotNull);
  });

  testWidgets('pet button exposes the real daily check-in action', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: PetButton(onPressed: () {}, loading: false)),
      ),
    );

    expect(find.text('Pet Oren & Check In'), findsOneWidget);
    expect(find.byIcon(Icons.pets), findsOneWidget);
  });

  testWidgets('shared widgets render common controls', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              CustomButton(label: 'Save', onPressed: () {}),
              const LoadingIndicator(message: 'Loading'),
            ],
          ),
        ),
      ),
    );

    expect(find.text('Save'), findsOneWidget);
    expect(find.text('Loading'), findsOneWidget);
  });

  testWidgets('virtual pet switches to the checked-in state', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: VirtualPetWidget(
            streak: 7,
            hasCheckedInToday: true,
            mood: 'Loved',
          ),
        ),
      ),
    );

    expect(find.text('Status: Loved'), findsOneWidget);
    expect(find.byType(Image), findsAtLeastNWidgets(3));
  });

  testWidgets('virtual pet supports tapping Oren to check in', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: VirtualPetWidget(
            streak: 2,
            hasCheckedInToday: false,
            onTap: () => tapped = true,
          ),
        ),
      ),
    );

    await tester.tap(find.byType(VirtualPetWidget));
    expect(tapped, isTrue);
  });

  testWidgets('virtual pet reflects energy status differences', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: VirtualPetWidget(
            streak: 3,
            hasCheckedInToday: true,
            mood: 'Energetic',
            energy: 96,
          ),
        ),
      ),
    );
    expect(find.text('Status: Full energy'), findsOneWidget);
    expect(find.textContaining('%'), findsNothing);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: VirtualPetWidget(
            streak: 3,
            hasCheckedInToday: true,
            mood: 'Tired',
            energy: 12,
          ),
        ),
      ),
    );
    expect(find.text('Status: Tired'), findsOneWidget);
  });

  testWidgets('virtual pet status stays aligned on a narrow screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: VirtualPetWidget(
            streak: 12,
            hasCheckedInToday: true,
            mood: 'Playful',
            energy: 64,
            tokens: 120,
            weather: WeatherSnapshot(
              temperatureCelsius: 29,
              weatherCode: 2,
              isDay: true,
              latitude: 1.49,
              longitude: 103.74,
              fetchedAt: DateTime(2026, 7, 22),
              locationName: 'Johor Bahru',
            ),
            onOpenShop: () {},
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Status: Playful'), findsOneWidget);
    expect(find.text('JB'), findsOneWidget);
    expect(tester.getCenter(find.text('JB')).dx, greaterThan(250));
    expect(find.text('Shop'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('oren care state serializes tokens and toys', () {
    final state = OrenCareState.initial().copyWith(
      tokens: 15,
      ownedToyIds: {'fish_plush'},
      selectedToyId: 'fish_plush',
      mood: 'Playful',
      lastAction: 'Oren played with Fish Plush.',
    );
    final restored = OrenCareState.fromJson(state.toJson());

    expect(restored.tokens, 15);
    expect(restored.ownedToyIds, contains('fish_plush'));
    expect(restored.selectedToyId, 'fish_plush');
    expect(restored.mood, 'Playful');
  });

  test(
    'sign-out cache cleanup preserves Oren progress only when requested',
    () async {
      SharedPreferences.setMockInitialValues({});
      final cache = LocalCacheService();
      const userId = 'user-1';
      final orenKey = OrenCareService.cacheKeyForUser(userId);
      const profileKey = 'profile_snapshot_v1_user-1';
      await cache.writeMap(orenKey, {
        'tokens': 18,
        'owned_toy_ids': ['yarn_ball'],
      });
      await cache.writeMap(profileKey, {'name': 'Test User'});

      await cache.removeUserData(userId, preservedKeys: {orenKey});

      expect(await cache.readMap(orenKey), containsPair('tokens', 18));
      expect(await cache.readMap(profileKey), isNull);
      SharedPreferences.setMockInitialValues({});
    },
  );

  test(
    'inactivity test SMS keeps the SOS message style and a test warning',
    () {
      expect(
        EmergencyService.testEmergencySmsMessage,
        contains(EmergencyService.emergencySmsMessage),
      );
      expect(EmergencyService.testEmergencySmsMessage, startsWith('TEST -'));
      expect(
        EmergencyService.testEmergencySmsMessage,
        contains('999 was not contacted'),
      );
    },
  );

  test('phone verification errors are safe to show directly', () {
    const error = PhoneVerificationException(
      'SMS provider authentication failed.',
    );

    expect(error.toString(), 'SMS provider authentication failed.');
    expect(error.toString(), isNot(contains('FunctionException')));
  });

  testWidgets('contact dialog validates required details', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: AddContactDialog())),
    );

    await tester.tap(find.text('Save'));
    await tester.pump();
    expect(find.byType(AddContactDialog), findsOneWidget);

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Family Member');
    await tester.enterText(fields.at(1), 'Daughter');
    await tester.enterText(fields.at(2), '0123456789');
    final emailField = find.byKey(const Key('contact-email-field'));
    await tester.drag(find.byType(ListView), const Offset(0, -360));
    await tester.pump();
    await tester.enterText(emailField.first, 'family@example.com');
    final addressField = find.byKey(const Key('contact-address-field'));
    await tester.drag(find.byType(ListView), const Offset(0, -260));
    await tester.pump();
    await tester.enterText(addressField.first, 'Kuala Lumpur');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.byType(AddContactDialog), findsNothing);
  });

  testWidgets('contact dialog rejects an invalid phone number', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: AddContactDialog())),
    );

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Daughter');
    await tester.enterText(fields.at(1), 'Daughter');
    await tester.enterText(fields.at(2), '123');
    await tester.tap(find.text('Save'));
    await tester.pump();

    expect(find.textContaining('Malaysia phone number'), findsOneWidget);
    expect(find.byType(AddContactDialog), findsOneWidget);
  });

  testWidgets('profile dialog accepts selected blood type and valid details', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: EditProfileDialog(
            profile: {
              'name': 'Kai Heng',
              'address': '12 Jalan Sutera 1',
              'address_state': 'Johor',
              'address_region': 'Johor Bahru',
              'address_latitude': 1.4927,
              'address_longitude': 103.7414,
              'address_verified_at': '2026-08-05T04:30:00.000Z',
              'address_validation_provider': 'platform_geocoder',
              'blood_type': 'O+',
              'inactivity_threshold': 24,
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.byType(EditProfileDialog), findsNothing);
  });

  testWidgets('profile dialog preserves an unchanged legacy address', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: EditProfileDialog(
            profile: {
              'name': 'Kai Heng',
              'address': '12 Jalan Sutera 1',
              'address_state': 'Johor',
              'address_region': 'Johor Bahru',
              'blood_type': 'O+',
              'inactivity_threshold': 24,
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.byType(EditProfileDialog), findsNothing);
  });

  testWidgets('profile name shows an error without truncating long input', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: EditProfileDialog(
            profile: {
              'name': 'Kai Heng',
              'address': '12 Jalan Sutera 1',
              'address_state': 'Johor',
              'address_region': 'Johor Bahru',
              'blood_type': 'O+',
              'inactivity_threshold': 24,
            },
          ),
        ),
      ),
    );

    final nameField = find.byType(TextFormField).first;
    final oversizedName = List.filled(101, 'A').join();
    await tester.enterText(nameField, oversizedName);
    await tester.pump();

    final field = tester.widget<TextFormField>(nameField);
    expect(field.controller?.text, oversizedName);
    expect(
      find.text('Name must not exceed 100 characters.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Save'));
    await tester.pump();
    expect(find.byType(EditProfileDialog), findsOneWidget);
  });

  test('streak calculation counts consecutive unique days', () {
    final now = DateTime.now();
    final times = [
      now,
      now.subtract(const Duration(hours: 2)),
      now.subtract(const Duration(days: 1)),
      now.subtract(const Duration(days: 2)),
      now.subtract(const Duration(days: 5)),
    ];

    expect(RewardService.calculateStreak(times), 3);
  });

  test('reward snapshot survives local JSON caching', () {
    final snapshot = RewardSnapshot(
      catalog: RewardService.fallbackCatalog,
      earnedCodes: const {'oren_sprout_badge'},
      claimedBadgeCodes: const {'oren_sprout_badge'},
      redemptionCodes: const {'oren_sprout_badge': 'EC-1234ABCD-5678EF90'},
      catalogVersion: 4,
      syncedAt: DateTime(2026, 6, 22),
    );

    final restored = RewardSnapshot.fromJson(snapshot.toJson());

    expect(restored.catalogVersion, 4);
    expect(restored.earnedCodes, contains('oren_sprout_badge'));
    expect(restored.isBadgeClaimed('oren_sprout_badge'), isTrue);
    expect(restored.isBadgeClaimed('oren_companion_badge'), isFalse);
    expect(
      restored.redemptionCodeFor('oren_sprout_badge'),
      'EC-1234ABCD-5678EF90',
    );
    expect(restored.nextReward(3)?.code, 'oren_companion_badge');
  });

  test('claimed badges and earned vouchers move into reward collection', () {
    const badge = RewardCatalogItem(
      code: 'badge-one',
      title: 'First Badge',
      sponsor: 'EthernaCare',
      description: 'A collected badge.',
      milestoneDays: 1,
      rewardKind: 'virtual',
      catalogVersion: 1,
    );
    const voucher = RewardCatalogItem(
      code: 'voucher-one',
      title: 'Wellness Voucher',
      sponsor: 'EthernaCare',
      description: 'A virtual voucher.',
      milestoneDays: 2,
      rewardKind: 'voucher',
      catalogVersion: 1,
      voucherValue: 'RM 5',
    );
    const pendingBadge = RewardCatalogItem(
      code: 'badge-pending',
      title: 'Pending Badge',
      sponsor: 'EthernaCare',
      description: 'An earned badge waiting to be collected.',
      milestoneDays: 3,
      rewardKind: 'virtual',
      catalogVersion: 1,
    );
    final snapshot = RewardSnapshot(
      catalog: const [badge, voucher, pendingBadge],
      earnedCodes: const {'badge-one', 'voucher-one', 'badge-pending'},
      claimedBadgeCodes: const {'badge-one'},
      redemptionCodes: const {'voucher-one': 'EC-1234ABCD-5678EF90'},
      catalogVersion: 1,
      syncedAt: DateTime(2026, 8, 5),
    );

    expect(
      snapshot.collectionItems.map((item) => item.code),
      orderedEquals(['badge-one', 'voucher-one']),
    );
    expect(
      snapshot.goalItems.map((item) => item.code),
      orderedEquals(['badge-pending']),
    );
  });

  testWidgets('reward collection shows badge and voucher details', (
    tester,
  ) async {
    const badge = RewardCatalogItem(
      code: 'badge-one',
      title: 'First Badge',
      sponsor: 'EthernaCare',
      description: 'A collected badge.',
      milestoneDays: 1,
      rewardKind: 'virtual',
      catalogVersion: 1,
    );
    const voucher = RewardCatalogItem(
      code: 'voucher-one',
      title: 'Wellness Voucher',
      sponsor: 'EthernaCare',
      description: 'A virtual voucher.',
      milestoneDays: 2,
      rewardKind: 'voucher',
      catalogVersion: 1,
      voucherValue: 'RM 5',
    );
    final snapshot = RewardSnapshot(
      catalog: const [badge, voucher],
      earnedCodes: const {'badge-one', 'voucher-one'},
      claimedBadgeCodes: const {'badge-one'},
      redemptionCodes: const {'voucher-one': 'EC-1234ABCD-5678EF90'},
      catalogVersion: 1,
      syncedAt: DateTime(2026, 8, 5),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: RewardCollectionScreen(snapshot: snapshot),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Reward Collection'), findsOneWidget);
    expect(find.text('Vouchers'), findsOneWidget);
    expect(find.text('Badges'), findsOneWidget);
    expect(find.text('Wellness Voucher'), findsOneWidget);
    expect(find.text('First Badge'), findsOneWidget);
  });

  test('fallback rewards remain automatic virtual badge unlocks', () {
    expect(RewardService.fallbackCatalog, hasLength(5));
    expect(
      RewardService.fallbackCatalog.every(
        (reward) => reward.rewardKind == 'virtual',
      ),
      isTrue,
    );
    expect(
      RewardService.fallbackCatalog.map((reward) => reward.milestoneDays),
      orderedEquals([3, 7, 10, 14, 30]),
    );
  });

  test('inactive virtual rewards remain identifiable in admin data', () {
    final item = RewardCatalogItem.fromJson({
      'code': 'oren_test_badge',
      'title': 'Oren Test Badge',
      'sponsor': 'EthernaCare',
      'description': 'A virtual test reward.',
      'milestone_days': 5,
      'reward_kind': 'virtual',
      'catalog_version': 9,
      'active': false,
    });

    expect(item.active, isFalse);
    expect(item.toJson()['active'], isFalse);
  });

  test('voucher catalog entries keep their displayed value', () {
    final voucher = RewardCatalogItem.fromJson({
      'code': 'oren_rm5_voucher',
      'title': 'RM5 Wellness Voucher',
      'sponsor': 'EthernaCare',
      'description': 'A virtual RM5 wellness voucher.',
      'milestone_days': 5,
      'reward_kind': 'voucher',
      'voucher_value': 'RM5',
      'catalog_version': 10,
      'active': true,
    });

    expect(voucher.isVoucher, isTrue);
    expect(voucher.voucherValue, 'RM5');
  });

  test('weather selects rain and night backgrounds', () {
    final rainy = WeatherSnapshot(
      temperatureCelsius: 28,
      weatherCode: 63,
      isDay: true,
      latitude: 3.14,
      longitude: 101.69,
      fetchedAt: DateTime.now(),
    );
    final night = WeatherSnapshot(
      temperatureCelsius: 26,
      weatherCode: 0,
      isDay: false,
      latitude: 3.14,
      longitude: 101.69,
      fetchedAt: DateTime.now(),
    );

    expect(rainy.backgroundAsset, endsWith('pixel_raining.png'));
    expect(night.backgroundAsset, endsWith('pixel_night.png'));
    expect(rainy.malaysiaRegion, 'Klang Valley');
    expect(rainy.compactMalaysiaRegion, 'KV');

    final johor = WeatherSnapshot(
      temperatureCelsius: 29,
      weatherCode: 3,
      isDay: true,
      latitude: 0,
      longitude: 0,
      fetchedAt: DateTime.now(),
      locationName: 'Johor Bahru, Johor',
    );
    expect(johor.compactMalaysiaRegion, 'JB');
    expect(johor.backgroundAsset, endsWith('pixel_cloudy.png'));
  });

  test('validation rules enforce account and contact limits', () {
    expect(ContactRepository.maxContacts, 5);
    expect(AppValidators.displayName('A'), isNotNull);
    expect(
      AppValidators.displayName(List.filled(100, 'A').join()),
      isNull,
    );
    expect(
      AppValidators.displayName(List.filled(101, 'A').join()),
      'Name must not exceed 100 characters.',
    );
    expect(
      AppValidators.registrationPassword(
        'weakpass',
        email: 'user@example.com',
        name: 'Kai Heng',
      ),
      'Use uppercase, lowercase, number, and special character.',
    );
    expect(
      AppValidators.registrationPassword(
        'Strong#Pass9',
        email: 'user@example.com',
        name: 'Kai Heng',
      ),
      isNull,
    );
    expect(AppValidators.inactivityThreshold('23'), isNotNull);
    expect(AppValidators.inactivityThreshold('24'), isNull);
    expect(AppValidators.inactivityThreshold('169'), isNotNull);
    expect(AppValidators.bloodType('AB+'), isNull);
    expect(
      AppValidators.normalizePhoneWithCountry('0123456789', '+60'),
      '+60123456789',
    );
    expect(
      AppValidators.phoneForCountry('0123456789', dialCode: '+60'),
      isNull,
    );
  });

  test('first login profile rules require safety details and terms', () {
    expect(
      AppProfileRules.missingSetupItems({
        'name': 'Kai Heng',
        'phone': '0123456789',
        'address': 'Kuala Lumpur',
        'address_state': 'Selangor',
        'address_region': 'Klang Valley',
        'blood_type': 'O+',
        'inactivity_threshold': 24,
      }),
      contains('Terms and Conditions'),
    );

    expect(
      UserService.isProfileSetupComplete({
        'name': 'Kai Heng',
        'phone': '0123456789',
        'address': 'Kuala Lumpur',
        'address_state': 'Selangor',
        'address_region': 'Klang Valley',
        'blood_type': 'O+',
        'inactivity_threshold': 24,
        'terms_accepted_at': '2026-06-24T00:00:00Z',
      }),
      isTrue,
    );
  });

  test('funeral preferences serialize for secure persistence', () {
    const preferences = FuneralPreferences(
      religion: 'Buddhist',
      serviceType: 'Memorial',
      venue: 'Kuala Lumpur',
      notes: 'Simple service',
      authorizedContact: 'Daughter',
    );

    final restored = FuneralPreferences.fromJson(preferences.toJson());

    expect(restored.serviceType, 'Memorial');
    expect(restored.authorizedContact, 'Daughter');
  });

  test('legacy notes serialize for CRUD persistence', () {
    final note = LegacyNote(
      id: 'note-1',
      title: 'Account reminder',
      content: 'Important instructions for trusted contacts.',
      createdAt: DateTime(2026, 7, 6),
      updatedAt: DateTime(2026, 7, 7),
    );
    final restored = LegacyNote.fromJson(note.toJson());

    expect(restored.id, 'note-1');
    expect(restored.title, 'Account reminder');
    expect(restored.content, contains('trusted contacts'));
  });

  test('legacy notes reject credentials and authentication secrets', () {
    expect(
      DocumentService.legacyNoteSecurityWarning(
        title: 'Family instructions',
        content: 'Contact the lawyer listed in my trusted contacts.',
      ),
      isNull,
    );
    expect(
      DocumentService.legacyNoteSecurityWarning(
        title: 'Account password',
        content: 'Use the value written below.',
      ),
      isNotNull,
    );
    expect(
      DocumentService.legacyNoteSecurityWarning(
        title: 'Temporary access',
        content: 'OTP: 123456',
      ),
      isNotNull,
    );
    expect(
      DocumentService.legacyNoteSecurityWarning(
        title: 'Developer access',
        content: 'sk-exampleSecretValue123456789',
      ),
      isNotNull,
    );
  });

  test('legacy documents validate size, extension, and file signature', () {
    final pdfBytes = Uint8List.fromList([
      0x25,
      0x50,
      0x44,
      0x46,
      0x2d,
      0x31,
      0x2e,
      0x37,
    ]);

    expect(
      DocumentService.documentUploadValidationError(
        fileName: 'will.pdf',
        fileSize: pdfBytes.length,
        bytes: pdfBytes,
      ),
      isNull,
    );
    expect(
      DocumentService.documentUploadValidationError(
        fileName: 'will.exe',
        fileSize: pdfBytes.length,
        bytes: pdfBytes,
      ),
      contains('PDF'),
    );
    expect(
      DocumentService.documentUploadValidationError(
        fileName: 'fake.pdf',
        fileSize: 3,
        bytes: Uint8List.fromList([0x4d, 0x5a, 0x90]),
      ),
      contains('does not match'),
    );
    expect(
      DocumentService.documentUploadValidationError(
        fileName: 'large.pdf',
        fileSize: DocumentService.maxDocumentBytes + 1,
        bytes: pdfBytes,
      ),
      contains('10 MB'),
    );
  });

  test('legacy checking parses preferences, notes, and secure documents', () {
    final result = LegacyAccessResult.fromJson({
      'ownerName': 'Test User',
      'lastActivityAt': '2026-01-01T00:00:00Z',
      'protectedContentAvailable': true,
      'protectedStatus': 'available',
      'preferences': {
        'religion': 'Buddhism',
        'service_type': 'Cremation',
        'venue': 'Johor Bahru',
        'notes': 'Keep the service simple.',
        'authorized_contact': 'Primary contact',
      },
      'notes': [
        {
          'id': 'note-1',
          'title': 'Family message',
          'content': 'Please contact the family lawyer.',
          'created_at': '2026-01-01T00:00:00Z',
          'updated_at': '2026-01-02T00:00:00Z',
        },
      ],
      'documents': [
        {
          'id': 'document-1',
          'name': 'private-will.pdf',
          'signedUrl':
              'https://example.supabase.co/storage/v1/object/sign/private-will.pdf?token=test',
          'uploadedAt': '2026-01-03T00:00:00Z',
        },
      ],
    });

    expect(result.ownerName, 'Test User');
    expect(result.protectedContentAvailable, isTrue);
    expect(result.preferences.serviceType, 'Cremation');
    expect(result.notes.single.title, 'Family message');
    expect(result.documents.single.name, 'private-will.pdf');
    expect(result.documents.single.signedUrl, contains('token=test'));
    expect(const LegacyCheckScreen(), isA<LegacyCheckScreen>());
  });

  test('legacy checking supports preference-only verified access', () {
    final result = LegacyAccessResult.fromJson({
      'ownerName': 'Test User',
      'protectedContentAvailable': false,
      'protectedStatus': 'waiting_period',
      'protectedMessage':
          'Legacy Notes and secure documents remain locked until day 90.',
      'protectedAvailableAt': '2026-09-02T00:00:00Z',
      'daysRemaining': 47,
      'preferences': {'religion': 'Buddhism', 'service_type': 'Cremation'},
      'notes': [],
      'documents': [],
    });

    expect(result.preferences.religion, 'Buddhism');
    expect(result.protectedContentAvailable, isFalse);
    expect(result.protectedStatus, 'waiting_period');
    expect(result.daysRemaining, 47);
    expect(result.notes, isEmpty);
    expect(result.documents, isEmpty);
  });

  test('legacy checking sends SMS while protected content is waiting', () {
    final status = LegacyAccessRequestStatus.fromJson({
      'codeSent': true,
      'status': 'code_sent',
      'protectedContentAvailable': false,
      'protectedStatus': 'waiting_period',
      'daysRemaining': 47,
      'availableAt': '2026-09-02T00:00:00Z',
      'message':
          'A code was sent. Funeral preferences are available after verification.',
    });

    expect(status.codeSent, isTrue);
    expect(status.status, 'code_sent');
    expect(status.protectedContentAvailable, isFalse);
    expect(status.protectedStatus, 'waiting_period');
    expect(status.daysRemaining, 47);
    expect(status.availableAt, DateTime.utc(2026, 9, 2));
    expect(status.message, contains('Funeral preferences'));
  });

  test('legacy checking reports a non-primary contact phone', () {
    final status = LegacyAccessRequestStatus.fromJson({
      'codeSent': false,
      'status': 'contact_mismatch',
      'message':
          "No SMS was sent. This phone number does not match the account's primary trusted contact.",
    });

    expect(status.codeSent, isFalse);
    expect(status.status, 'contact_mismatch');
    expect(status.message, contains('does not match'));
  });

  test('legacy checking sends SMS during the owner protection period', () {
    final status = LegacyAccessRequestStatus.fromJson({
      'codeSent': true,
      'status': 'code_sent',
      'protectedContentAvailable': false,
      'protectedStatus': 'owner_grace_period',
      'availableAt': '2026-10-01T04:00:00Z',
      'message':
          'Funeral preferences are available. Protected content remains locked during the 24-hour protection period.',
    });

    expect(status.codeSent, isTrue);
    expect(status.status, 'code_sent');
    expect(status.protectedStatus, 'owner_grace_period');
    expect(status.availableAt, DateTime.utc(2026, 10, 1, 4));
    expect(status.message, contains('24-hour protection period'));
  });

  test('legacy checking parses the seven-day server access window', () {
    final status = LegacyAccessRequestStatus.fromJson({
      'codeSent': true,
      'status': 'code_sent',
      'message': 'Code sent.',
      'accessExpiresAt': '2026-10-08T04:00:00Z',
    });

    expect(status.codeSent, isTrue);
    expect(status.accessExpiresAt, DateTime.utc(2026, 10, 8, 4));
  });

  testWidgets('legacy checking debug switch shows owner-scoped testing', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      const MaterialApp(home: LegacyCheckScreen(showTestingMode: true)),
    );

    expect(find.text('Testing mode'), findsOneWidget);
    expect(find.text('Verify UID and Phone'), findsOneWidget);
    expect(
      find.textContaining('owner enabled account testing'),
      findsOneWidget,
    );

    await tester.tap(find.byType(SwitchListTile));
    await tester.pump();

    expect(find.text('Send Verification Code'), findsOneWidget);
    expect(find.textContaining('protected 90-day release'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('legacy checking release mode keeps SMS verification', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: LegacyCheckScreen(showTestingMode: false)),
    );

    expect(find.text('Testing mode'), findsNothing);
    expect(find.text('Send Verification Code'), findsOneWidget);
    expect(find.textContaining('protected 90-day release'), findsOneWidget);
  });

  test('AI guidance has an offline safety fallback', () {
    expect(
      AiService.offlineAnswer('What do I do in an emergency?'),
      contains('999'),
    );
    expect(
      AiService.offlineAnswer('Can the app create my will?'),
      contains('does not create'),
    );
  });

  test('AI chat messages serialize for local chat history', () {
    final message = AiChatMessage.user('How do daily check-ins work?');
    final restored = AiChatMessage.fromJson(message.toJson());

    expect(restored.isUser, isTrue);
    expect(restored.text, 'How do daily check-ins work?');
  });
}
