/// Thiago Ryuji Ogawa - RA:24024450
///
/// Ponto de entrada do aplicativo Flutter.
/// Inicializa dependencias globais e delega a composicao visual para
/// a arvore principal definida em app.dart.

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(const MyApp());
}
