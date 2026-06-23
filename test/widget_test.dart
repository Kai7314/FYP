import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fyp/models/location_model.dart';
import 'package:fyp/models/document_model.dart';
import 'package:fyp/models/reward_model.dart';
import 'package:fyp/presentation/screen/contacts/add_contact_dialog.dart';
import 'package:fyp/presentation/screen/home/pet_button.dart';
import 'package:fyp/presentation/screen/home/virtual_pet_widget.dart';
import 'package:fyp/presentation/screen/profile/profile_screen.dart';
import 'package:fyp/dataAccessLayer/repositories/contact_repository.dart';
import 'package:fyp/services/reward_service.dart';
import 'package:fyp/services/ai_service.dart';
import 'package:fyp/utils/validators.dart';

void main() {
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

  testWidgets('virtual pet switches to the checked-in state', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: VirtualPetWidget(streak: 7, hasCheckedInToday: true),
        ),
      ),
    );

    expect(find.text('Oren 💚'), findsOneWidget);
    expect(find.byType(Image), findsNWidgets(2));
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
      find.widgetWithText(TextField, 'Phone number'),
      '0123456789',
    );
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
      find.widgetWithText(TextFormField, 'Phone number'),
      '123',
    );
    await tester.tap(find.text('Save'));
    await tester.pump();

    expect(find.textContaining('8 to 15 digits'), findsOneWidget);
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
