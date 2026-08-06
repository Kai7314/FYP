import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fyp/models/legacy_note_model.dart';
import 'package:fyp/presentation/screen/planning/legacy_note_editor_screen.dart';

void main() {
  testWidgets('legacy note opens as a full page and returns a draft', (
    tester,
  ) async {
    LegacyNoteDraft? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () async {
                  result = await Navigator.of(context).push<LegacyNoteDraft>(
                    MaterialPageRoute(
                      builder: (_) => const LegacyNoteEditorScreen(),
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

    expect(find.byType(LegacyNoteEditorScreen), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('Add Legacy Note'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('legacy-note-title-field')),
      'A message for my family',
    );
    await tester.enterText(
      find.byKey(const Key('legacy-note-content-field')),
      'Please remember the good days we shared.',
    );
    await tester.tap(find.byKey(const Key('save-legacy-note')));
    await tester.pumpAndSettle();

    expect(result?.title, 'A message for my family');
    expect(result?.content, 'Please remember the good days we shared.');
  });

  testWidgets('edit page keeps credential protection on a narrow phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final now = DateTime(2026, 8, 7);
    await tester.pumpWidget(
      MaterialApp(
        home: LegacyNoteEditorScreen(
          note: LegacyNote(
            id: 'note-1',
            title: 'Family message',
            content: 'Please contact the executor.',
            createdAt: now,
            updatedAt: now,
          ),
        ),
      ),
    );

    expect(find.text('Edit Legacy Note'), findsOneWidget);
    expect(find.text('Family message'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('legacy-note-content-field')),
      'My password is secret123.',
    );
    await tester.tap(find.byKey(const Key('save-legacy-note')));
    await tester.pump();

    expect(
      find.textContaining('Do not store passwords'),
      findsOneWidget,
    );
    expect(find.byType(LegacyNoteEditorScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
