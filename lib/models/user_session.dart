import 'package:firebase_auth/firebase_auth.dart';

class UserSession {
  static final UserSession _instance = UserSession._internal();
  factory UserSession() => _instance;
  UserSession._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Getter to check if a user is currently cached
  User? get currentUser => _auth.currentUser;

  // SIGN IN
  Future<String?> signIn(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      return null; // Success
    } on FirebaseAuthException catch (e) {
      return e.message; // Return error message to show in UI
    }
  }

  // SIGN OUT
  Future<void> logOut() async {
    await _auth.signOut();
  }
}