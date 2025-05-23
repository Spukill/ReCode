import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:recode/community_page.dart';
import 'package:recode/community_qa_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

void main() {
  late FakeFirebaseFirestore firestore;

  setUp(() {
    firestore = FakeFirebaseFirestore();
  });

  group('Community Tests', () {
    test('Can create a new post', () async {
      // Arrange
      final postData = {
        'title': 'Test Post',
        'content': 'This is a test post',
        'userId': 'test-user-id',
        'timestamp': DateTime.now(),
        'likes': 0,
        'comments': [],
      };

      // Act
      await firestore.collection('posts').add(postData);

      // Assert
      final snapshot = await firestore.collection('posts').get();
      expect(snapshot.docs.length, equals(1));
      expect(snapshot.docs.first.data()['title'], equals('Test Post'));
      expect(snapshot.docs.first.data()['likes'], equals(0));
    });

    test('Can add comment to post', () async {
      // Arrange
      final postRef = await firestore.collection('posts').add({
        'title': 'Test Post',
        'content': 'This is a test post',
        'userId': 'test-user-id',
        'timestamp': DateTime.now(),
        'likes': 0,
        'comments': [],
      });

      final comment = {
        'content': 'Test comment',
        'userId': 'comment-user-id',
        'timestamp': DateTime.now(),
      };

      // Act
      await postRef.update({
        'comments': FieldValue.arrayUnion([comment])
      });

      // Assert
      final doc = await postRef.get();
      expect(doc.data()?['comments'].length, equals(1));
      expect(doc.data()?['comments'][0]['content'], equals('Test comment'));
    });

    test('Can like a post', () async {
      // Arrange
      final postRef = await firestore.collection('posts').add({
        'title': 'Test Post',
        'content': 'This is a test post',
        'userId': 'test-user-id',
        'timestamp': DateTime.now(),
        'likes': 0,
        'comments': [],
      });

      // Act
      await postRef.update({
        'likes': FieldValue.increment(1)
      });

      // Assert
      final doc = await postRef.get();
      expect(doc.data()?['likes'], equals(1));
    });

    test('Can search posts', () async {
      // Arrange
      await firestore.collection('posts').add({
        'title': 'Python Post',
        'content': 'This is about Python',
        'userId': 'test-user-id',
        'timestamp': DateTime.now(),
        'likes': 0,
        'comments': [],
      });
      await firestore.collection('posts').add({
        'title': 'Java Post',
        'content': 'This is about Java',
        'userId': 'test-user-id',
        'timestamp': DateTime.now(),
        'likes': 0,
        'comments': [],
      });

      // Act
      final snapshot = await firestore
          .collection('posts')
          .where('title', isGreaterThanOrEqualTo: 'Python')
          .where('title', isLessThan: 'Pythonz')
          .get();

      // Assert
      expect(snapshot.docs.length, equals(1));
      expect(snapshot.docs.first.data()['title'], equals('Python Post'));
    });
  });

  group('Community QA Tests', () {
    test('Can create a new question', () async {
      // Arrange
      final questionData = {
        'title': 'Test Question',
        'content': 'This is a test question',
        'userId': 'test-user-id',
        'timestamp': DateTime.now(),
        'tags': ['python', 'flutter'],
        'answers': [],
      };

      // Act
      await firestore.collection('questions').add(questionData);

      // Assert
      final snapshot = await firestore.collection('questions').get();
      expect(snapshot.docs.length, equals(1));
      expect(snapshot.docs.first.data()['title'], equals('Test Question'));
      expect(snapshot.docs.first.data()['tags'], contains('python'));
    });

    test('Can add answer to question', () async {
      // Arrange
      final questionRef = await firestore.collection('questions').add({
        'title': 'Test Question',
        'content': 'This is a test question',
        'userId': 'test-user-id',
        'timestamp': DateTime.now(),
        'tags': ['python'],
        'answers': [],
      });

      final answer = {
        'content': 'Test answer',
        'userId': 'answer-user-id',
        'timestamp': DateTime.now(),
        'isAccepted': false,
      };

      // Act
      await questionRef.update({
        'answers': FieldValue.arrayUnion([answer])
      });

      // Assert
      final doc = await questionRef.get();
      expect(doc.data()?['answers'].length, equals(1));
      expect(doc.data()?['answers'][0]['content'], equals('Test answer'));
    });

    test('Can accept an answer', () async {
      // Arrange
      final questionRef = await firestore.collection('questions').add({
        'title': 'Test Question',
        'content': 'This is a test question',
        'userId': 'test-user-id',
        'timestamp': DateTime.now(),
        'tags': ['python'],
        'answers': [{
          'content': 'Test answer',
          'userId': 'answer-user-id',
          'timestamp': DateTime.now(),
          'isAccepted': false,
        }],
      });

      // Act
      await questionRef.update({
        'answers': [{
          'content': 'Test answer',
          'userId': 'answer-user-id',
          'timestamp': DateTime.now(),
          'isAccepted': true,
        }]
      });

      // Assert
      final doc = await questionRef.get();
      expect(doc.data()?['answers'][0]['isAccepted'], isTrue);
    });
  });
} 