import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recode/bottom_navigation.dart';
import 'package:recode/related_note.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';

void main() {
  late FakeFirebaseFirestore firestore;

  setUp(() {
    firestore = FakeFirebaseFirestore();
  });

  group('Navigation Tests', () {
    testWidgets('Bottom navigation shows all tabs', (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: BottomNavigation(),
        ),
      ));

      // Assert
      expect(find.byIcon(Icons.home), findsOneWidget);
      expect(find.byIcon(Icons.code), findsOneWidget);
      expect(find.byIcon(Icons.people), findsOneWidget);
      expect(find.byIcon(Icons.question_answer), findsOneWidget);
    });

    testWidgets('Can switch between tabs', (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: BottomNavigation(),
        ),
      ));

      // Act
      await tester.tap(find.byIcon(Icons.code));
      await tester.pumpAndSettle();

      // Assert
      expect(find.byIcon(Icons.code), findsOneWidget);
      // Add more specific assertions based on your UI
    });
  });

  group('Related Notes Tests', () {
    test('Can find related notes by language', () async {
      // Arrange
      await firestore.collection('code_snippets').add({
        'title': 'Python Code 1',
        'code': 'print("Hello")',
        'language': 'python',
        'userId': 'test-user-id',
        'timestamp': DateTime.now(),
      });
      await firestore.collection('code_snippets').add({
        'title': 'Python Code 2',
        'code': 'print("World")',
        'language': 'python',
        'userId': 'test-user-id',
        'timestamp': DateTime.now(),
      });
      await firestore.collection('code_snippets').add({
        'title': 'Java Code',
        'code': 'System.out.println("Hello")',
        'language': 'java',
        'userId': 'test-user-id',
        'timestamp': DateTime.now(),
      });

      // Act
      final snapshot = await firestore
          .collection('code_snippets')
          .where('language', isEqualTo: 'python')
          .get();

      // Assert
      expect(snapshot.docs.length, equals(2));
      expect(snapshot.docs[0].data()['language'], equals('python'));
      expect(snapshot.docs[1].data()['language'], equals('python'));
    });

    test('Can find related notes by tags', () async {
      // Arrange
      await firestore.collection('code_snippets').add({
        'title': 'Flutter UI',
        'code': 'Container()',
        'language': 'dart',
        'tags': ['flutter', 'ui'],
        'userId': 'test-user-id',
        'timestamp': DateTime.now(),
      });
      await firestore.collection('code_snippets').add({
        'title': 'Flutter State',
        'code': 'setState()',
        'language': 'dart',
        'tags': ['flutter', 'state'],
        'userId': 'test-user-id',
        'timestamp': DateTime.now(),
      });

      // Act
      final snapshot = await firestore
          .collection('code_snippets')
          .where('tags', arrayContains: 'flutter')
          .get();

      // Assert
      expect(snapshot.docs.length, equals(2));
      expect(snapshot.docs[0].data()['tags'], contains('flutter'));
      expect(snapshot.docs[1].data()['tags'], contains('flutter'));
    });

    test('Can sort related notes by timestamp', () async {
      // Arrange
      final now = DateTime.now();
      await firestore.collection('code_snippets').add({
        'title': 'Old Code',
        'code': 'print("Old")',
        'language': 'python',
        'userId': 'test-user-id',
        'timestamp': now.subtract(Duration(days: 2)),
      });
      await firestore.collection('code_snippets').add({
        'title': 'New Code',
        'code': 'print("New")',
        'language': 'python',
        'userId': 'test-user-id',
        'timestamp': now,
      });

      // Act
      final snapshot = await firestore
          .collection('code_snippets')
          .orderBy('timestamp', descending: true)
          .get();

      // Assert
      expect(snapshot.docs.length, equals(2));
      expect(snapshot.docs[0].data()['title'], equals('New Code'));
      expect(snapshot.docs[1].data()['title'], equals('Old Code'));
    });
  });
} 