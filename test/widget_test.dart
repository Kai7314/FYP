import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fyp/presentation/screen/home/pet_button.dart';
import 'package:fyp/presentation/screen/home/virtual_pet_widget.dart';

void main() {
  testWidgets('pet button shows the daily check-in action', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: PetButton(onPressed: () {}, loading: false)),
      ),
    );

    expect(find.text('Pet the Cat'), findsOneWidget);
    expect(find.byIcon(Icons.pets), findsOneWidget);
  });

  testWidgets('virtual pet shows streak and happy status', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: VirtualPetWidget(streak: 7, hasCheckedInToday: true),
        ),
      ),
    );

    expect(find.text('Cat status: Happy and cared for'), findsOneWidget);
    expect(find.text('7 day streak'), findsOneWidget);
  });
}
