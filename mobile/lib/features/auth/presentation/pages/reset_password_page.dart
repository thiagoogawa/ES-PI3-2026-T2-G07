/// Thiago Ryuji Ogawa - RA:24024450
///
/// Tela de recuperacao de senha.
/// Guia o usuario na solicitacao de redefinicao de credenciais e
/// apresenta o retorno necessario para concluir o fluxo.

import 'package:flutter/material.dart';

import '../../../../core/utils/app_snackbar.dart';
import '../../../../core/network/api_client.dart';
import '../../data/datasources/auth_api_datasource.dart';
import '../../data/datasources/auth_remote_datasource.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../controllers/auth_controller.dart';

class ResetPasswordPage extends StatefulWidget {
  final String initialEmail;

  const ResetPasswordPage({super.key, this.initialEmail = ''});

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  late final AuthController controller;
  late final TextEditingController emailController;
  bool emailSent = false;

  @override
  void initState() {
    super.initState();
    emailController = TextEditingController(text: widget.initialEmail);
    controller = AuthController(
      AuthRepositoryImpl(
        AuthRemoteDataSource(),
        AuthApiDataSource(ApiClient()),
      ),
    );
  }

  @override
  void dispose() {
    emailController.dispose();
    controller.dispose();
    super.dispose();
  }

  Future<void> _handleResetPassword() async {
    final email = emailController.text.trim();
    if (email.isEmpty) {
      showAppSnackBar(
        context,
        message: 'Digite seu e-mail.',
        type: AppSnackBarType.error,
      );
      return;
    }

    if (!email.contains('@')) {
      showAppSnackBar(
        context,
        message: 'Digite um e-mail valido.',
        type: AppSnackBarType.error,
      );
      return;
    }

    final success = await controller.sendPasswordResetEmail(email: email);
    if (!mounted) {
      return;
    }

    if (success) {
      setState(() {
        emailSent = true;
      });
      return;
    }

    if (controller.errorMessage != null) {
      showAppSnackBar(
        context,
        message: controller.errorMessage!,
        type: AppSnackBarType.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: const Color(0xFF111111),
          appBar: AppBar(
            backgroundColor: const Color(0xFF111111),
            foregroundColor: Colors.white,
            title: const Text('Redefinir senha'),
          ),
          body: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Esqueceu a senha?',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Digite o e-mail da sua conta para receber o link de redefinicao de senha pelo Firebase.',
                  style: TextStyle(
                    color: Color(0xFFBDBDBD),
                    fontSize: 15,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 28),
                if (emailSent) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF162338),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFF2D5CA8)),
                    ),
                    child: const Text(
                      'Se existir uma conta para este e-mail, o Firebase enviara uma mensagem de redefinicao. Verifique tambem a caixa de spam.',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        height: 1.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                ],
                TextField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'E-mail',
                    labelStyle: const TextStyle(color: Color(0xFFBDBDBD)),
                    filled: true,
                    fillColor: const Color(0xFF242424),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Color(0xFF323232)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(
                        color: Color(0xFF3C78D8),
                        width: 1.4,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: controller.isLoading
                        ? null
                        : _handleResetPassword,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF346AC0),
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(53),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: controller.isLoading
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            emailSent
                                ? 'Reenviar link de redefinicao'
                                : 'Enviar link de redefinicao',
                          ),
                  ),
                ),
                if (emailSent) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white38),
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text('Voltar ao login'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
