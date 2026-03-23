import 'package:flutter/material.dart';
import '../../../../core/network/api_client.dart';
import '../../data/datasources/auth_api_datasource.dart';
import '../../data/datasources/auth_remote_datasource.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../controllers/auth_controller.dart';
import 'home_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  late final AuthController controller;

  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  @override
  void initState() {
    super.initState();

    controller = AuthController(
      AuthRepositoryImpl(
        AuthRemoteDataSource(),
        AuthApiDataSource(ApiClient()),
      ),
    );

    controller.addListener(() {
      if (controller.currentUser != null && mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => HomePage(controller: controller)),
        );
      }

      if (controller.errorMessage != null && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(controller.errorMessage!)));
      }

      setState(() {});
    });
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    controller.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    await controller.signIn(
      email: emailController.text.trim(),
      password: passwordController.text.trim(),
    );
  }

  Future<void> _handleSignUp() async {
    await controller.signUp(
      email: emailController.text.trim(),
      password: passwordController.text.trim(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: emailController,
              decoration: const InputDecoration(labelText: 'E-mail'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Senha'),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: controller.isLoading ? null : _handleLogin,
                child: controller.isLoading
                    ? const CircularProgressIndicator()
                    : const Text('Entrar'),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: controller.isLoading ? null : _handleSignUp,
                child: const Text('Criar conta'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
