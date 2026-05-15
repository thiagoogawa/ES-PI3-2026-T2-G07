import 'package:flutter/material.dart';

class MfaEnrollmentRequest {
  final String phoneNumber;
  final String password;

  const MfaEnrollmentRequest({
    required this.phoneNumber,
    required this.password,
  });
}

Future<String?> showSmsCodePrompt(
  BuildContext context, {
  required String title,
  required String subtitle,
}) async {
  final controller = TextEditingController();

  final result = await showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      return AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(subtitle),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Codigo SMS',
                hintText: '123456',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(dialogContext).pop(controller.text.trim());
            },
            child: const Text('Confirmar'),
          ),
        ],
      );
    },
  );

  controller.dispose();
  return result;
}

Future<MfaEnrollmentRequest?> showMfaEnrollmentPrompt(
  BuildContext context, {
  String? initialPhoneNumber,
}) async {
  final phoneController = TextEditingController(text: initialPhoneNumber ?? '');
  final passwordController = TextEditingController();

  final result = await showDialog<MfaEnrollmentRequest>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      return AlertDialog(
        title: const Text('Ativar 2FA por SMS'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Informe o celular em formato internacional e sua senha para reenviar a verificacao.',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: phoneController,
              autofocus: true,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Celular com codigo do pais',
                hintText: '+5511999999999',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Senha atual'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              final phoneNumber = phoneController.text.trim();
              final password = passwordController.text.trim();

              if (!phoneNumber.startsWith('+') || password.isEmpty) {
                return;
              }

              Navigator.of(dialogContext).pop(
                MfaEnrollmentRequest(
                  phoneNumber: phoneNumber,
                  password: password,
                ),
              );
            },
            child: const Text('Continuar'),
          ),
        ],
      );
    },
  );

  phoneController.dispose();
  passwordController.dispose();
  return result;
}
