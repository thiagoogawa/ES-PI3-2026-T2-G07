/// Thiago Ryuji Ogawa - RA:24024450
///
/// Fonte de dados usada pelo modulo de autenticacao.
/// Encapsula acesso a Firebase, armazenamento ou backend para
/// manter a camada superior livre de detalhes de infraestrutura.

import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';

class AuthSecondFactor {
  final String uid;
  final String? displayName;
  final String? phoneNumber;

  const AuthSecondFactor({
    required this.uid,
    required this.displayName,
    required this.phoneNumber,
  });
}

class AuthPhoneVerificationRequest {
  final String verificationId;
  final int? resendToken;

  const AuthPhoneVerificationRequest({
    required this.verificationId,
    this.resendToken,
  });
}

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

  Future<void> sendEmailVerification() async {
    final user = _firebaseAuth.currentUser;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'user-not-found',
        message: 'Nenhum usuario autenticado foi encontrado.',
      );
    }

    await user.sendEmailVerification(
      ActionCodeSettings(
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

  Future<List<AuthSecondFactor>> getCurrentSecondFactors() async {
    final user = _firebaseAuth.currentUser;
    if (user == null) {
      return const [];
    }

    final enrolledFactors = await user.multiFactor.getEnrolledFactors();

    return enrolledFactors
        .whereType<PhoneMultiFactorInfo>()
        .map((factor) {
          return AuthSecondFactor(
            uid: factor.uid,
            displayName: factor.displayName,
            phoneNumber: factor.phoneNumber,
          );
        })
        .toList(growable: false);
  }

  Future<AuthPhoneVerificationRequest> startPhoneEnrollment({
    required String phoneNumber,
  }) async {
    final user = _firebaseAuth.currentUser;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'user-not-found',
        message: 'Nenhum usuario autenticado foi encontrado.',
      );
    }

    final session = await user.multiFactor.getSession();

    return _startPhoneVerification(
      multiFactorSession: session,
      phoneNumber: _normalizePhoneNumber(phoneNumber),
    );
  }

  Future<void> enrollPhoneSecondFactor({
    required String verificationId,
    required String smsCode,
    String? displayName,
  }) async {
    final user = _firebaseAuth.currentUser;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'user-not-found',
        message: 'Nenhum usuario autenticado foi encontrado.',
      );
    }

    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode,
    );
    final assertion = PhoneMultiFactorGenerator.getAssertion(credential);

    await user.multiFactor.enroll(assertion, displayName: displayName);
    await user.reload();
  }

  Future<void> unenrollSecondFactor(String factorUid) async {
    final user = _firebaseAuth.currentUser;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'user-not-found',
        message: 'Nenhum usuario autenticado foi encontrado.',
      );
    }

    await user.multiFactor.unenroll(factorUid: factorUid);
    await user.reload();
  }

  List<AuthSecondFactor> getSecondFactors(MultiFactorResolver resolver) {
    return resolver.hints
        .whereType<PhoneMultiFactorInfo>()
        .map((hint) {
          return AuthSecondFactor(
            uid: hint.uid,
            displayName: hint.displayName,
            phoneNumber: hint.phoneNumber,
          );
        })
        .toList(growable: false);
  }

  Future<AuthPhoneVerificationRequest> startSecondFactorSignIn({
    required MultiFactorResolver resolver,
    required String factorUid,
  }) async {
    final hint = _findPhoneFactorHint(resolver: resolver, factorUid: factorUid);

    return _startPhoneVerification(
      multiFactorSession: resolver.session,
      multiFactorInfo: hint,
    );
  }

  Future<UserCredential> resolveSecondFactorSignIn({
    required MultiFactorResolver resolver,
    required String verificationId,
    required String smsCode,
  }) {
    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode,
    );
    final assertion = PhoneMultiFactorGenerator.getAssertion(credential);

    return resolver.resolveSignIn(assertion);
  }

  PhoneMultiFactorInfo _findPhoneFactorHint({
    required MultiFactorResolver resolver,
    required String factorUid,
  }) {
    for (final hint in resolver.hints.whereType<PhoneMultiFactorInfo>()) {
      if (hint.uid == factorUid) {
        return hint;
      }
    }

    throw FirebaseAuthException(
      code: 'multi-factor-info-not-found',
      message: 'Nao foi possivel localizar o fator selecionado.',
    );
  }

  Future<AuthPhoneVerificationRequest> _startPhoneVerification({
    required MultiFactorSession multiFactorSession,
    PhoneMultiFactorInfo? multiFactorInfo,
    String? phoneNumber,
  }) async {
    final completer = Completer<AuthPhoneVerificationRequest>();
    var codeWasSent = false;

    await _firebaseAuth.verifyPhoneNumber(
      multiFactorSession: multiFactorSession,
      multiFactorInfo: multiFactorInfo,
      phoneNumber: phoneNumber,
      verificationCompleted: (_) {},
      verificationFailed: (error) {
        if (!completer.isCompleted) {
          completer.completeError(error);
        }
      },
      codeSent: (verificationId, resendToken) {
        codeWasSent = true;
        if (!completer.isCompleted) {
          completer.complete(
            AuthPhoneVerificationRequest(
              verificationId: verificationId,
              resendToken: resendToken,
            ),
          );
        }
      },
      codeAutoRetrievalTimeout: (verificationId) {
        if (codeWasSent && !completer.isCompleted) {
          completer.complete(
            AuthPhoneVerificationRequest(verificationId: verificationId),
          );
        }
      },
    );

    return completer.future;
  }

  String _normalizePhoneNumber(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      throw FirebaseAuthException(
        code: 'invalid-phone-number',
        message: 'Informe um telefone valido.',
      );
    }

    if (trimmed.startsWith('+')) {
      return trimmed;
    }

    final digits = trimmed.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) {
      throw FirebaseAuthException(
        code: 'invalid-phone-number',
        message: 'Informe um telefone valido.',
      );
    }

    if (digits.length == 10 || digits.length == 11) {
      return '+55$digits';
    }

    return '+$digits';
  }
}
