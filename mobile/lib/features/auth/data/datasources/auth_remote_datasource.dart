/// Thiago Ryuji Ogawa - RA:24024450
///
/// Fonte de dados usada pelo modulo de autenticacao.
/// Encapsula acesso a Firebase, armazenamento ou backend para
/// manter a camada superior livre de detalhes de infraestrutura.

import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';

class AuthSecondFactor {
  final MultiFactorInfo info;
  final String uid;
  final String factorId;
  final String? displayName;
  final String? phoneNumber;

  const AuthSecondFactor({
    required this.info,
    required this.uid,
    required this.factorId,
    required this.displayName,
    required this.phoneNumber,
  });

  factory AuthSecondFactor.fromInfo(MultiFactorInfo info) {
    return AuthSecondFactor(
      info: info,
      uid: info.uid,
      factorId: info.factorId,
      displayName: info.displayName,
      phoneNumber: info is PhoneMultiFactorInfo ? info.phoneNumber : null,
    );
  }

  String get label {
    final trimmedDisplayName = displayName?.trim();
    if (trimmedDisplayName != null && trimmedDisplayName.isNotEmpty) {
      return trimmedDisplayName;
    }

    return phoneNumber ?? 'Segundo fator';
  }
}

class AuthPhoneVerificationRequest {
  final String? verificationId;
  final int? forceResendingToken;
  final PhoneAuthCredential? instantCredential;

  const AuthPhoneVerificationRequest({
    required this.verificationId,
    required this.forceResendingToken,
    required this.instantCredential,
  });

  bool get wasAutoVerified => instantCredential != null;
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

  User? get currentUser => _firebaseAuth.currentUser;

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

  Future<void> reloadCurrentUser() async {
    await _requireCurrentUser().reload();
  }

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

  Future<void> sendEmailVerification() {
    return _requireCurrentUser().sendEmailVerification(
      ActionCodeSettings(
        url: _continueUrl,
        handleCodeInApp: false,
        androidPackageName: _androidPackageName,
        androidInstallApp: true,
        iOSBundleId: _iosBundleId,
      ),
    );
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

  Future<void> reauthenticateWithPassword({
    required String email,
    required String password,
  }) async {
    final credential = EmailAuthProvider.credential(
      email: email,
      password: password,
    );

    await _requireCurrentUser().reauthenticateWithCredential(credential);
  }

  Future<List<AuthSecondFactor>> getEnrolledSecondFactors() async {
    final factors = await _requireCurrentUser().multiFactor
        .getEnrolledFactors();

    return factors.map(AuthSecondFactor.fromInfo).toList();
  }

  List<AuthSecondFactor> mapSecondFactors(Iterable<MultiFactorInfo> factors) {
    return factors.map(AuthSecondFactor.fromInfo).toList();
  }

  Future<AuthPhoneVerificationRequest> startPhoneEnrollment({
    required String phoneNumber,
  }) async {
    final session = await _requireCurrentUser().multiFactor.getSession();

    return _startPhoneVerification(
      phoneNumber: normalizePhoneNumber(phoneNumber),
      multiFactorSession: session,
    );
  }

  Future<void> enrollPhoneSecondFactor({
    required AuthPhoneVerificationRequest request,
    required String smsCode,
    String? displayName,
  }) async {
    final user = _requireCurrentUser();
    final credential = _resolvePhoneCredential(
      request: request,
      smsCode: smsCode,
    );
    final assertion = PhoneMultiFactorGenerator.getAssertion(credential);

    await user.multiFactor.enroll(
      assertion,
      displayName: _normalizedDisplayName(displayName),
    );
    await user.reload();
  }

  Future<void> unenrollSecondFactor(AuthSecondFactor factor) async {
    final user = _requireCurrentUser();

    await user.multiFactor.unenroll(multiFactorInfo: factor.info);
    await user.reload();
  }

  Future<AuthPhoneVerificationRequest> startSecondFactorSignIn(
    MultiFactorResolver resolver, {
    required AuthSecondFactor factor,
  }) async {
    final info = factor.info;
    if (info is! PhoneMultiFactorInfo) {
      throw Exception('Somente fatores por SMS sao suportados neste app.');
    }

    return _startPhoneVerification(
      multiFactorInfo: info,
      multiFactorSession: resolver.session,
    );
  }

  Future<UserCredential> resolveSecondFactorSignIn({
    required MultiFactorResolver resolver,
    required AuthPhoneVerificationRequest request,
    required String smsCode,
  }) {
    final credential = _resolvePhoneCredential(
      request: request,
      smsCode: smsCode,
    );
    final assertion = PhoneMultiFactorGenerator.getAssertion(credential);

    return resolver.resolveSignIn(assertion);
  }

  static String normalizePhoneNumber(String phoneNumber) {
    final trimmed = phoneNumber.trim();
    if (trimmed.isEmpty) {
      throw Exception('Informe um numero de telefone para o 2FA.');
    }

    final startsWithPlus = trimmed.startsWith('+');
    final digitsOnly = trimmed.replaceAll(RegExp(r'\D'), '');

    if (digitsOnly.isEmpty) {
      throw Exception('Informe um telefone valido para o 2FA.');
    }

    final normalized = startsWithPlus ? '+$digitsOnly' : '+$digitsOnly';

    if (normalized.length < 12) {
      throw Exception('Telefone invalido para verificacao por SMS.');
    }

    return normalized;
  }

  User _requireCurrentUser() {
    final user = _firebaseAuth.currentUser;
    if (user == null) {
      throw Exception('Nenhum usuario autenticado para configurar o 2FA.');
    }

    return user;
  }

  Future<AuthPhoneVerificationRequest> _startPhoneVerification({
    String? phoneNumber,
    PhoneMultiFactorInfo? multiFactorInfo,
    required MultiFactorSession multiFactorSession,
  }) {
    final completer = Completer<AuthPhoneVerificationRequest>();
    String? currentVerificationId;
    int? currentForceResendingToken;
    PhoneAuthCredential? currentInstantCredential;
    var didSendCode = false;

    void completeIfPending() {
      if (completer.isCompleted) {
        return;
      }

      completer.complete(
        AuthPhoneVerificationRequest(
          verificationId: currentVerificationId,
          forceResendingToken: currentForceResendingToken,
          instantCredential: currentInstantCredential,
        ),
      );
    }

    _firebaseAuth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      multiFactorInfo: multiFactorInfo,
      multiFactorSession: multiFactorSession,
      timeout: const Duration(seconds: 45),
      verificationCompleted: (credential) {
        currentInstantCredential = credential;
        completeIfPending();
      },
      verificationFailed: (error) {
        if (!completer.isCompleted) {
          completer.completeError(error);
        }
      },
      codeSent: (verificationId, forceResendingToken) {
        currentVerificationId = verificationId;
        currentForceResendingToken = forceResendingToken;
        didSendCode = true;
        completeIfPending();
      },
      codeAutoRetrievalTimeout: (verificationId) {
        currentVerificationId = verificationId;
        if (!didSendCode && currentInstantCredential == null) {
          if (!completer.isCompleted) {
            completer.completeError(
              Exception(
                'O Firebase nao confirmou o envio do SMS para este numero. Verifique a configuracao do app e tente novamente.',
              ),
            );
          }
          return;
        }

        completeIfPending();
      },
    );

    return completer.future.timeout(
      const Duration(seconds: 55),
      onTimeout: () {
        throw Exception(
          'O Firebase nao respondeu a verificacao por SMS. Tente novamente em instantes.',
        );
      },
    );
  }

  PhoneAuthCredential _resolvePhoneCredential({
    required AuthPhoneVerificationRequest request,
    required String smsCode,
  }) {
    if (request.instantCredential != null) {
      return request.instantCredential!;
    }

    final verificationId = request.verificationId;
    if (verificationId == null || verificationId.isEmpty) {
      throw Exception(
        'Nao foi possivel confirmar o envio do SMS. Tente novamente.',
      );
    }

    final code = smsCode.trim();
    if (code.isEmpty) {
      throw Exception('Digite o codigo enviado por SMS.');
    }

    return PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: code,
    );
  }

  String? _normalizedDisplayName(String? displayName) {
    final value = displayName?.trim();
    if (value == null || value.isEmpty) {
      return null;
    }

    return value;
  }
}
