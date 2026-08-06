import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fyp/models/document_model.dart';
import 'package:fyp/presentation/screen/planning/funeral_preferences_editor_screen.dart';

void main() {
  testWidgets('funeral preferences open as a full page and return edits', (
    tester,
  ) async {
    FuneralPreferences? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () async {
                  result = await Navigator.of(context).push<FuneralPreferences>(
                    MaterialPageRoute(
                      builder: (_) => const FuneralPreferencesEditorScreen(
                        preferences: FuneralPreferences(
                          religion: 'Taoism',
                          serviceType: 'Burial',
                          venue: 'Community Hall',
                          notes: 'Simple arrangements',
                          authorizedContact: 'Jerome - +60108286648',
                        ),
                        contacts: [
                          {
                            'name': 'Jerome',
                            'phone': '+60108286648',
                            'is_primary': true,
                          },
                        ],
                      ),
                    ),
                  );
                },
                child: const Text('Open editor'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open editor'));
    await tester.pumpAndSettle();

    expect(find.byType(FuneralPreferencesEditorScreen), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('Funeral Preferences'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('funeral-venue-field')),
      'Peace Memorial Centre',
    );
    await tester.tap(find.byKey(const Key('save-funeral-preferences')));
    await tester.pumpAndSettle();

    expect(result?.venue, 'Peace Memorial Centre');
    expect(result?.religion, 'Taoism');
    expect(result?.authorizedContact, 'Jerome - +60108286648');
  });

  testWidgets('venue validation remains readable on a narrow phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: FuneralPreferencesEditorScreen(
          preferences: FuneralPreferences(
            religion: 'Taoism',
            serviceType: 'Burial',
          ),
          contacts: [],
        ),
      ),
    );

    final oversizedVenue = List.filled(101, 'A').join();
    await tester.enterText(
      find.byKey(const Key('funeral-venue-field')),
      oversizedVenue,
    );
    await tester.pump();

    expect(
      find.text('Preferred venue must not exceed 100 characters.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
