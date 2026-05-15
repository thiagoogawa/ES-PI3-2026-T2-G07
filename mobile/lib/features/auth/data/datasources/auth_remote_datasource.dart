import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';

class AuthRemoteDataSource {
  final FirebaseAuth _firebaseAuth;

  static const String _continueUrl = 'https://mesclainvest-dev.firebaseapp.com';
  static const String _androidPackageName = 'com.example.mobile';
  static const String _iosBundleId = 'com.example.mobile';

  AuthRemoteDataSource({FirebaseAuth? firebaseAuth})
    : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance {
    _firebaseAuth.setLanguageCode('pt-BR');
  }

  Future<UserCredential> signIn({
    required String email,
    required String password,
    Future<String?> Function(String phoneHint)? requestSecondFactorCode,
  }) async {
    try {
      return await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthMultiFactorException catch (error) {
      if (requestSecondFactorCode == null) {
        throw FirebaseAuthException(
          code: 'missing-second-factor-handler',
          message: 'Second-factor flow was not configured by the app.',
        );
      }

      return _resolvePhoneSecondFactorSignIn(
        resolver: error.resolver,
        requestSecondFactorCode: requestSecondFactorCode,
      );
    }
  }

  bool get isSignedIn => _firebaseAuth.currentUser != null;

  User? get currentUser => _firebaseAuth.currentUser;

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

  Future<void> deleteCurrentUser() async {
    final user = _firebaseAuth.currentUser;
    if (user == null) {
      return;
    }

    await user.delete();
  }

  Future<void> sendPasswordResetEmail({required String email}) {
    return _firebaseAuth.sendPasswordResetEmail(
      email: email,
      actionCodeSettings: ActionCodeSettings(
        url: _continueUrl,
        handleCodeInApp: false,
        androidPackageName: _androidPackageName,
        androidInstallApp: true,
        iOSBundleId: _iosBundleId,
      ),
    );
  }

  Future<void> reloadCurrentUser() async {
    await _firebaseAuth.currentUser?.reload();
  }

  Future<void> reauthenticateWithPassword({
    required String email,
    required String password,
  }) async {
    final user = _firebaseAuth.currentUser;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'user-not-found',
        message: 'No authenticated user found.',
      );
    }

    final credential = EmailAuthProvider.credential(
      email: email,
      password: password,
    );

    await user.reauthenticateWithCredential(credential);
  }

  Future<void> enrollSmsSecondFactor({
    required String phoneNumber,
    required Future<String?> Function(String phoneHint) requestSmsCode,
    String? displayName,
  }) async {
    final user = _firebaseAuth.currentUser;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'user-not-found',
        message: 'No authenticated user found.',
      );
    }

    final session = await user.multiFactor.getSession();
    final completer = Completer<void>();

    Future<void> completeEnrollment(PhoneAuthCredential credential) async {
      if (completer.isCompleted) {
        return;
      }

      try {
        await user.multiFactor.enroll(
          PhoneMultiFactorGenerator.getAssertion(credential),
          displayName: displayName,
        );
        await user.reload();
        completer.complete();
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    }

    await _firebaseAuth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      multiFactorSession: session,
      verificationCompleted: (credential) async {
        await completeEnrollment(credential);
      },
      verificationFailed: (error) {
        if (!completer.isCompleted) {
          completer.completeError(error);
        }
      },
      codeSent: (verificationId, resendToken) async {
        final smsCode = await requestSmsCode(phoneNumber);

        if (smsCode == null || smsCode.trim().isEmpty) {
          if (!completer.isCompleted) {
            completer.completeError(
              FirebaseAuthException(
                code: 'second-factor-cancelled',
                message: 'Second-factor verification was cancelled.',
              ),
            );
          }
          return;
        }

        final credential = PhoneAuthProvider.credential(
          verificationId: verificationId,
          smsCode: smsCode.trim(),
        );

        await completeEnrollment(credential);
      },
      codeAutoRetrievalTimeout: (_) {},
    );

    return completer.future;
  }

  Future<UserCredential> _resolvePhoneSecondFactorSignIn({
    required MultiFactorResolver resolver,
    required Future<String?> Function(String phoneHint) requestSecondFactorCode,
  }) async {
    final hint = resolver.hints.whereType<PhoneMultiFactorInfo>().firstWhere(
      (_) => true,
      orElse: () => throw FirebaseAuthException(
        code: 'unsupported-second-factor',
        message: 'No phone second factor is available for this account.',
      ),
    );
    final completer = Completer<UserCredential>();

    Future<void> completeSignIn(PhoneAuthCredential credential) async {
      if (completer.isCompleted) {
        return;
      }

      try {
        final result = await resolver.resolveSignIn(
          PhoneMultiFactorGenerator.getAssertion(credential),
        );
        completer.complete(result);
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    }

    await _firebaseAuth.verifyPhoneNumber(
      multiFactorSession: resolver.session,
      multiFactorInfo: hint,
      verificationCompleted: (credential) async {
        await completeSignIn(credential);
      },
      verificationFailed: (error) {
        if (!completer.isCompleted) {
          completer.completeError(error);
        }
      },
      codeSent: (verificationId, resendToken) async {
        final smsCode = await requestSecondFactorCode(hint.phoneNumber);

        if (smsCode == null || smsCode.trim().isEmpty) {
          if (!completer.isCompleted) {
            completer.completeError(
              FirebaseAuthException(
                code: 'second-factor-cancelled',
                message: 'Second-factor verification was cancelled.',
              ),
            );
          }
          return;
        }

        final credential = PhoneAuthProvider.credential(
          verificationId: verificationId,
          smsCode: smsCode.trim(),
        );

        await completeSignIn(credential);
      },
      codeAutoRetrievalTimeout: (_) {},
    );

    return completer.future;
  }
}
