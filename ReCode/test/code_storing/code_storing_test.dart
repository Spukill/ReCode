import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_storage_mocks/firebase_storage_mocks.dart';
import 'package:recode/code_storing.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late MockFirebaseStorage storage;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    storage = MockFirebaseStorage();
  });

  group('Code Storing Tests', () {
    test('Can store code snippet', () async {
      // Arrange
      final codeData = {
        'title': 'Test Code',
        'code': 'print("Hello World")',
        'language': 'python',
        'userId': 'test-user-id',
        'timestamp': DateTime.now(),
      };

      // Act
      await firestore.collection('code_snippets').add(codeData);

      // Assert
      final snapshot = await firestore.collection('code_snippets').get();
      expect(snapshot.docs.length, equals(1));
      expect(snapshot.docs.first.data()['title'], equals('Test Code'));
      expect(snapshot.docs.first.data()['language'], equals('python'));
    });

    test('Can retrieve code snippets by user', () async {
      // Arrange
      final userId = 'test-user-id';
      await firestore.collection('code_snippets').add({
        'title': 'Test Code 1',
        'code': 'print("Hello")',
        'language': 'python',
        'userId': userId,
        'timestamp': DateTime.now(),
      });
      await firestore.collection('code_snippets').add({
        'title': 'Test Code 2',
        'code': 'console.log("Hello")',
        'language': 'javascript',
        'userId': userId,
        'timestamp': DateTime.now(),
      });

      // Act
      final snapshot = await firestore
          .collection('code_snippets')
          .where('userId', isEqualTo: userId)
          .get();

      // Assert
      expect(snapshot.docs.length, equals(2));
      expect(snapshot.docs[0].data()['title'], equals('Test Code 1'));
      expect(snapshot.docs[1].data()['title'], equals('Test Code 2'));
    });

    test('Can delete code snippet', () async {
      // Arrange
      final docRef = await firestore.collection('code_snippets').add({
        'title': 'Test Code',
        'code': 'print("Hello")',
        'language': 'python',
        'userId': 'test-user-id',
        'timestamp': DateTime.now(),
      });

      // Act
      await docRef.delete();

      // Assert
      final snapshot = await firestore.collection('code_snippets').get();
      expect(snapshot.docs.length, equals(0));
    });

    test('Can update code snippet', () async {
      // Arrange
      final docRef = await firestore.collection('code_snippets').add({
        'title': 'Test Code',
        'code': 'print("Hello")',
        'language': 'python',
        'userId': 'test-user-id',
        'timestamp': DateTime.now(),
      });

      // Act
      await docRef.update({
        'title': 'Updated Code',
        'code': 'print("Updated")',
      });

      // Assert
      final doc = await docRef.get();
      expect(doc.data()?['title'], equals('Updated Code'));
      expect(doc.data()?['code'], equals('print("Updated")'));
    });
  });
} 