import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:google_sign_in_mocks/google_sign_in_mocks.dart';
import 'package:recode/main.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';

void main() {
  late MockFirebaseAuth auth;
  late MockGoogleSignIn googleSignIn;
  late FakeFirebaseFirestore firestore;

  setUp(() async {
    auth = MockFirebaseAuth();
    googleSignIn = MockGoogleSignIn();
    firestore = FakeFirebaseFirestore();
    
    // Setup Firebase for testing
    TestWidgetsFlutterBinding.ensureInitialized();
    await Firebase.initializeApp();
  });

  group('Authentication Tests', () {
    test('User can sign in with email and password', () async {
      // Arrange
      final user = MockUser(
        uid: 'test-uid',
        email: 'test@example.com',
        displayName: 'Test User',
      );
      auth.mockUser = user;

      // Act
      final result = await auth.signInWithEmailAndPassword(
        email: 'test@example.com',
        password: 'password123',
      );

      // Assert
      expect(result.user, isNotNull);
      expect(result.user?.email, equals('test@example.com'));
      expect(result.user?.uid, equals('test-uid'));
    });

    test('User can sign up with email and password', () async {
      // Arrange
      final user = MockUser(
        uid: 'new-user-uid',
        email: 'new@example.com',
        displayName: 'New User',
      );

      // Act
      final result = await auth.createUserWithEmailAndPassword(
        email: 'new@example.com',
        password: 'password123',
      );

      // Assert
      expect(result.user, isNotNull);
      expect(result.user?.email, equals('new@example.com'));
    });

    test('User can sign in with Google', () async {
      // Arrange
      final googleSignIn = MockGoogleSignIn();

      // Act
      final result = await googleSignIn.signIn();

      // Assert
      expect(result, isNotNull);
      expect(result?.email, isNotNull); // Default mock user has a non-null email
    });

    test('User can sign out', () async {
      // Arrange
      final user = MockUser(
        uid: 'test-uid',
        email: 'test@example.com',
      );
      auth.mockUser = user;

      // Act
      await auth.signOut();

      // Assert
      expect(auth.currentUser, isNull);
    });
  });
} 