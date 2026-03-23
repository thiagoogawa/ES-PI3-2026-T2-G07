import 'package:firebase_auth/firebase_auth.dart';

class AuthRemoteDataSource {
  final FirebaseAuth _firebaseAuth;

  AuthRemoteDataSource({FirebaseAuth? firebaseAuth})
    : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance;

  Future<UserCredential> signIn({
    required String email,
    required String password,
  }) {
    return _firebaseAuth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  bool get isSignedIn => _firebaseAuth.currentUser != null;

  Future<UserCredential> signUp({
    required String email,
    required String password,
  }) {
    return _firebaseAuth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  Future<String> getIdToken() async {
    final user = _firebaseAuth.currentUser;
    final token = await user?.getIdToken();

    if (token == null || token.isEmpty) {
      throw Exception('Unable to get Firebase ID token');
    }

    return token;
  }

  Future<void> signOut() {
    return _firebaseAuth.signOut();
  }
}
