import 'package:flutter/material.dart';
import '../controllers/auth_controller.dart';

class HomePage extends StatelessWidget {
  final AuthController controller;

  const HomePage({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final user = controller.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        actions: [
          IconButton(
            onPressed: () async {
              await controller.signOut();
              if (context.mounted) {
                Navigator.of(context).pop();
              }
            },
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: user == null
            ? const Text('Nenhum usuário autenticado')
            : Column(
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
