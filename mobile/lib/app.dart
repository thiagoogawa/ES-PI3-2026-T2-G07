import 'package:flutter/material.dart';
import 'features/auth/presentation/pages/login_page.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Auth Test',
      debugShowCheckedModeBanner: false,
      home: const LoginPage(),
    );
  }
}
