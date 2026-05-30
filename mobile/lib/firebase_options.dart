/// Thiago Ryuji Ogawa - RA:24024450
///
/// Define as opcoes de inicializacao do Firebase por plataforma.
/// Esse arquivo fornece as credenciais e identificadores usados no
/// bootstrap do app para Android, iOS, web e desktop.

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for this platform.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCeWGesRfbKVF15lVMl7hft1EE0C1MDWRI',
    appId: '1:11219755352:web:15a42f1e1492824400852d',
    messagingSenderId: '11219755352',
    projectId: 'mesclainvest-dev',
    authDomain: 'mesclainvest-dev.firebaseapp.com',
    storageBucket: 'mesclainvest-dev.firebasestorage.app',
    measurementId: 'G-FF72SWLQQ0',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDcdTmHx4tyIEfH8rjytKsMQ7ag_-X7qLU',
    appId: '1:11219755352:android:555ebf7d5d150b4700852d',
    messagingSenderId: '11219755352',
    projectId: 'mesclainvest-dev',
    storageBucket: 'mesclainvest-dev.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyCJlFkVjtNydqYhg2m9-L-XAMkO-q78ieQ',
    appId: '1:11219755352:ios:ed7ed1af7ebf2cfb00852d',
    messagingSenderId: '11219755352',
    projectId: 'mesclainvest-dev',
    storageBucket: 'mesclainvest-dev.firebasestorage.app',
    iosBundleId: 'com.example.mobile',
  );
}
