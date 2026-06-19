import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fyp/presentation/screen/contacts/add_contact_dialog.dart';
import 'package:fyp/presentation/screen/home/pet_button.dart';
import 'package:fyp/presentation/screen/home/virtual_pet_widget.dart';
import 'package:fyp/services/reward_service.dart';

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
}
