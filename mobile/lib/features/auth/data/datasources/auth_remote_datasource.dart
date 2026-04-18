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
    required String fullName,
  }) async {
    final credential = await _firebaseAuth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    await credential.user?.updateDisplayName(fullName);
    await credential.user?.reload();

    return credential;
  }

  Future<String> getIdToken({bool forceRefresh = false}) async {
    final user = _firebaseAuth.currentUser;
    final token = await user?.getIdToken(forceRefresh);

    if (token == null || token.isEmpty) {
      throw Exception('Unable to get Firebase ID token');
    }

    return token;
  }

  Future<void> signOut() {
    return _firebaseAuth.signOut();
  }

  Future<void> sendPasswordResetEmail({required String email}) {
    return _firebaseAuth.sendPasswordResetEmail(email: email);
  }
}
