import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../domain/entities/authenticated_user.dart';
import 'login_page.dart';

class HomePage extends StatelessWidget {
  final AuthenticatedUser user;

  const HomePage({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        actions: [
          IconButton(
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginPage()),
                  (route) => false,
                );
              }
            },
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('UID: ${user.uid}'),
            Text('Email: ${user.email ?? "-"}'),
            Text('Email verificado: ${user.emailVerified}'),
            Text('Nome: ${user.name ?? "-"}'),
            Text('Provider: ${user.provider ?? "-"}'),
          ],
        ),
      ),
    );
  }
}
