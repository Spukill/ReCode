import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recode/code_storing.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CodeStoringPage Widget Tests', () {
    testWidgets('renders CodeStoringPage without crashing', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: CodeStoringPage(),
        ),
      );

      expect(find.byType(CodeStoringPage), findsOneWidget);
    });

    testWidgets('can enter text in title and code fields', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: CodeStoringPage(),
        ),
      );

      final titleField = find.byKey(const Key('titleField'));
      final codeField = find.byKey(const Key('codeField'));

      await tester.enterText(titleField, 'Sample Title');
      await tester.enterText(codeField, 'print("Hello World");');

      expect(find.text('Sample Title'), findsOneWidget);
      expect(find.text('print("Hello World");'), findsOneWidget);
    });

    testWidgets('can save a note to mocked Firestore', (WidgetTester tester) async {
      final fakeFirestore = FakeFirebaseFirestore();

      await tester.pumpWidget(
        MaterialApp(
          home: Provider<FirebaseFirestore>.value(
            value: fakeFirestore,
            child: CodeStoringPage(),
          ),
        ),
      );

      final titleField = find.byKey(const Key('titleField'));
      final codeField = find.byKey(const Key('codeField'));
      final saveButton = find.byKey(const Key('saveNoteButton'));

      await tester.enterText(titleField, 'Test Note');
      await tester.enterText(codeField, 'void main() => print("Test");');
      await tester.tap(saveButton);
      await tester.pumpAndSettle();

      final snapshot = await fakeFirestore.collection('codes').get();
      expect(snapshot.docs.length, 1);
      expect(snapshot.docs.first['title'], 'Test Note');
    });
  });
}
