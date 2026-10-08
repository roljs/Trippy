import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final FirebaseAuth? _customAuth;

  AuthService({FirebaseAuth? firebaseAuth}) : _customAuth = firebaseAuth;

  FirebaseAuth? get _auth {
    if (_customAuth != null) return _customAuth;
    try {
      return FirebaseAuth.instance;
    } catch (_) {
      return null;
    }
  }

  Stream<User?> get authStateChanges {
    try {
      final auth = _auth;
      if (auth == null) return const Stream.empty();
      return auth.authStateChanges();
    } catch (_) {
      return const Stream.empty();
    }
  }

  User? get currentUser {
    try {
      return _auth?.currentUser;
    } catch (_) {
      return null;
    }
  }

  static const String _serverClientId =
      '392329008088-cc3p9vbfg1lr70at96cf5r4vr2lhv6qs.apps.googleusercontent.com';

  bool _isGoogleSignInInitialized = false;

  Future<void> _ensureGoogleSignInInitialized() async {
    if (!_isGoogleSignInInitialized && !kIsWeb) {
      await GoogleSignIn.instance.initialize(
        serverClientId: _serverClientId,
      );
      _isGoogleSignInInitialized = true;
    }
  }

  /// Sign in using Google Account
  Future<UserCredential?> signInWithGoogle() async {
    final auth = _auth;
    if (auth == null) {
      throw StateError('Firebase is not initialized');
    }
    try {
      if (kIsWeb) {
        final GoogleAuthProvider authProvider = GoogleAuthProvider();
        return await auth.signInWithPopup(authProvider);
      } else {
        await _ensureGoogleSignInInitialized();
        final GoogleSignInAccount googleUser =
            await GoogleSignIn.instance.authenticate();
        final GoogleSignInAuthentication googleAuth =
            googleUser.authentication;

        final AuthCredential credential = GoogleAuthProvider.credential(
          idToken: googleAuth.idToken,
        );

        return await auth.signInWithCredential(credential);
      }
    } catch (e) {
      debugPrint('Error during Google Sign-In: $e');
      rethrow;
    }
  }

  /// Sign in anonymously as guest
  Future<UserCredential?> signInAnonymously() async {
    final auth = _auth;
    if (auth == null) {
      throw StateError('Firebase is not initialized');
    }
    try {
      return await auth.signInAnonymously();
    } catch (e) {
      debugPrint('Error during Anonymous Sign-In: $e');
      rethrow;
    }
  }

  /// Sign out
  Future<void> signOut() async {
    try {
      if (!kIsWeb) {
        try {
          await GoogleSignIn.instance.signOut();
        } catch (_) {}
      }
      await _auth?.signOut();
    } catch (e) {
      debugPrint('Error signing out: $e');
      rethrow;
    }
  }
}
