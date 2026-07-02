import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fyp/main.dart' as app;
import 'package:fyp/models/location_model.dart';
import 'package:fyp/models/checkin_model.dart';
import 'package:fyp/models/contact_model.dart';
import 'package:fyp/models/document_model.dart';
import 'package:fyp/models/emergency_alert_model.dart';
import 'package:fyp/models/oren_care_model.dart';
import 'package:fyp/models/reward_model.dart';
import 'package:fyp/models/user_model.dart';
import 'package:fyp/businessLogicLayer/controllers/checkin_controller.dart';
import 'package:fyp/businessLogicLayer/controllers/contact_controller.dart';
import 'package:fyp/businessLogicLayer/providers/auth_provider.dart';
import 'package:fyp/presentation/screen/auth/login_screen.dart';
import 'package:fyp/presentation/screen/auth/tutorial_screen.dart';
import 'package:fyp/presentation/screen/contacts/add_contact_dialog.dart';
import 'package:fyp/presentation/screen/home/home_screen.dart';
import 'package:fyp/presentation/screen/home/pet_button.dart';
import 'package:fyp/presentation/screen/home/virtual_pet_widget.dart';
import 'package:fyp/presentation/screen/profile/profile_screen.dart';
import 'package:fyp/presentation/widgets/custom_button.dart';
import 'package:fyp/presentation/widgets/loading_indicator.dart';
import 'package:fyp/dataAccessLayer/repositories/contact_repository.dart';
import 'package:fyp/services/reward_service.dart';
import 'package:fyp/services/ai_service.dart';
import 'package:fyp/services/user_service.dart';
import 'package:fyp/utils/validators.dart';

void main() {
  test('app bootstrap compiles', () {
    expect(app.MyApp, isNotNull);
  });

  test('auth screen remains available for email and OAuth flows', () {
    expect(LoginScreen, isNotNull);
  });

  test('tutorial screen is available for first login guidance', () {
    expect(TutorialScreen, isNotNull);
  });

  testWidgets('tutorial screen renders the first login guide', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(home: TutorialScreen(onComplete: () {})),
    );
    await tester.pump();

    expect(find.text('Quick Guide'), findsOneWidget);
    expect(find.text('Meet Oren'), findsOneWidget);
    expect(find.text('Next'), findsOneWidget);
  });

  test('home screen compiles with oren care shop', () {
    expect(HomeScreen, isNotNull);
  });

  test('architecture scaffold exposes models controllers and providers', () {
    final contact = ContactModel.fromJson({
      'id': '1',
      'user_id': 'u1',
      'name': 'Daughter',
      'relationship': 'Family',
      'phone': '0123456789',
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
          body: VirtualPetWidget(streak: 7, hasCheckedInToday: true),
        ),
      ),
    );

    expect(find.text('Mood: Loved'), findsOneWidget);
    expect(find.byType(Image), findsNWidgets(2));
  });

  test('oren care state serializes tokens and toys', () {
    final state = OrenCareState.initial().copyWith(
      tokens: 15,
      ownedToyIds: {'fish_plush'},
      mood: 'Playful',
      lastAction: 'Oren played with Fish Plush.',
    );
    final restored = OrenCareState.fromJson(state.toJson());

    expect(restored.tokens, 15);
    expect(restored.ownedToyIds, contains('fish_plush'));
    expect(restored.mood, 'Playful');
  });

  testWidgets('contact dialog validates required details', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: AddContactDialog())),
    );

    await tester.tap(find.text('Save'));
    await tester.pump();
    expect(find.byType(AddContactDialog), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextField, 'Name'),
      'Family Member',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Relationship'),
      'Daughter',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Phone number'),
      '0123456789',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Address'),
      'Kuala Lumpur',
    );
    await tester.ensureVisible(find.byType(SwitchListTile));
    await tester.tap(find.byType(SwitchListTile));
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.byType(AddContactDialog), findsNothing);
  });

  testWidgets('contact dialog rejects an invalid phone number', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: AddContactDialog())),
    );

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Name'),
      'Daughter',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Relationship'),
      'Daughter',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Phone number'),
      '123',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Address'),
      'Kuala Lumpur',
    );
    await tester.tap(find.text('Save'));
    await tester.pump();

    expect(find.textContaining('Malaysia phone number'), findsOneWidget);
    expect(find.byType(AddContactDialog), findsOneWidget);
  });

  testWidgets('profile dialog validates age and accepts valid details', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: EditProfileDialog(
            profile: {'name': 'Kai Heng', 'inactivity_threshold': 24},
          ),
        ),
      ),
    );

    await tester.enterText(find.widgetWithText(TextFormField, 'Age'), '10');
    await tester.tap(find.text('Save'));
    await tester.pump();
    expect(find.text('Age must be between 18 and 120.'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextFormField, 'Age'), '70');
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Blood type'),
      'O+',
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.byType(EditProfileDialog), findsNothing);
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
      earnedCodes: const {'tealive_bogo'},
      catalogVersion: 4,
      syncedAt: DateTime(2026, 6, 22),
    );

    final restored = RewardSnapshot.fromJson(snapshot.toJson());

    expect(restored.catalogVersion, 4);
    expect(restored.earnedCodes, contains('tealive_bogo'));
    expect(restored.nextReward(3)?.code, 'milo_400g');
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

    expect(rainy.backgroundAsset, endsWith('raining.jpg'));
    expect(night.backgroundAsset, endsWith('night.jpg'));
    expect(rainy.malaysiaRegion, 'Klang Valley');
  });

  test('validation rules enforce account and contact limits', () {
    expect(ContactRepository.maxContacts, 5);
    expect(AppValidators.displayName('A'), isNotNull);
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
        'age': 72,
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
        'age': 72,
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
}
