import 'package:flutter/material.dart';

import '../../../../core/network/api_client.dart';
import '../../data/datasources/auth_api_datasource.dart';
import '../../data/datasources/auth_remote_datasource.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../domain/entities/authenticated_user.dart';
import '../controllers/auth_controller.dart';
import 'app_home_router.dart';

class SignupFlowPage extends StatefulWidget {
  const SignupFlowPage({super.key});

  @override
  State<SignupFlowPage> createState() => _SignupFlowPageState();
}

class _SignupFlowPageState extends State<SignupFlowPage> {
  late final AuthController controller;

  final fullNameController = TextEditingController();
  final cpfController = TextEditingController();
  final phoneController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  int _step = 0;

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
        final authenticatedUser = controller.currentUser as AuthenticatedUser;
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) => buildHomePageForUser(authenticatedUser),
          ),
          (route) => false,
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
    fullNameController.dispose();
    cpfController.dispose();
    phoneController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    controller.dispose();
    super.dispose();
  }

  String _digitsOnly(String value) => value.replaceAll(RegExp(r'\D'), '');

  String _formatCpf(String value) {
    final digits = _digitsOnly(value);
    final buffer = StringBuffer();
    for (var index = 0; index < digits.length && index < 11; index++) {
      if (index == 3 || index == 6) {
        buffer.write('.');
      }
      if (index == 9) {
        buffer.write('-');
      }
      buffer.write(digits[index]);
    }
    return buffer.toString();
  }

  String _formatPhone(String value) {
    final digits = _digitsOnly(value);
    if (digits.isEmpty) {
      return '';
    }
    final buffer = StringBuffer();
    if (digits.isNotEmpty) buffer.write('(');
    for (var index = 0; index < digits.length && index < 11; index++) {
      if (index == 2) buffer.write(') ');
      if (index == 7) buffer.write('-');
      buffer.write(digits[index]);
    }
    return buffer.toString();
  }

  void _setFormattedValue(TextEditingController controller, String value) {
    controller.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
  }

  String? _validateCurrentStep() {
    switch (_step) {
      case 0:
        if (fullNameController.text.trim().split(RegExp(r'\s+')).length < 2) {
          return 'Digite o nome completo.';
        }
        if (_digitsOnly(cpfController.text).length != 11) {
          return 'Digite um CPF valido com 11 digitos.';
        }
        return null;
      case 1:
        if (_digitsOnly(phoneController.text).isEmpty ||
            _digitsOnly(phoneController.text).length < 10) {
          return 'Digite um telefone celular valido.';
        }
        if (!emailController.text.trim().contains('@')) {
          return 'Digite um e-mail valido.';
        }
        return null;
      case 2:
        if (passwordController.text.length < 6) {
          return 'A senha deve ter pelo menos 6 caracteres.';
        }
        if (passwordController.text != confirmPasswordController.text) {
          return 'As senhas nao conferem.';
        }
        return null;
      default:
        return null;
    }
  }

  Future<void> _handleContinue() async {
    final validationError = _validateCurrentStep();
    if (validationError != null && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(validationError)));
      return;
    }

    if (_step < 2) {
      setState(() {
        _step += 1;
      });
      return;
    }

    await controller.signUp(
      fullName: fullNameController.text.trim(),
      cpf: _digitsOnly(cpfController.text),
      phone: phoneController.text.trim(),
      email: emailController.text.trim(),
      password: passwordController.text,
    );
  }

  InputDecoration _lineInputDecoration(String label, {String? hintText}) {
    return InputDecoration(
      labelText: label,
      hintText: hintText,
      labelStyle: const TextStyle(color: Colors.white, fontSize: 15),
      hintStyle: const TextStyle(color: Color(0xFF8A8A8A), fontSize: 15),
      enabledBorder: const UnderlineInputBorder(
        borderSide: BorderSide(color: Color(0xFF838383)),
      ),
      focusedBorder: const UnderlineInputBorder(
        borderSide: BorderSide(color: Color(0xFF84B5FF), width: 1.5),
      ),
    );
  }

  Widget _buildProgress() {
    return Row(
      children: List.generate(3, (index) {
        final active = index == _step;
        return Expanded(
          child: Container(
            height: 5,
            margin: EdgeInsets.only(right: index == 2 ? 0 : 12),
            decoration: BoxDecoration(
              color: active ? const Color(0xFF84B5FF) : const Color(0xFF66686C),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildStepOne() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Para comecar, precisamos de algumas informacoes',
          style: TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.w500,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 34),
        TextField(
          controller: fullNameController,
          style: const TextStyle(color: Colors.white, fontSize: 18),
          decoration: _lineInputDecoration('Nome completo'),
        ),
        const SizedBox(height: 28),
        TextField(
          controller: cpfController,
          keyboardType: TextInputType.number,
          style: const TextStyle(color: Colors.white, fontSize: 18),
          decoration: _lineInputDecoration('CPF'),
          onChanged: (value) =>
              _setFormattedValue(cpfController, _formatCpf(value)),
        ),
      ],
    );
  }

  Widget _buildStepTwo() {
    final firstName = fullNameController.text
        .trim()
        .split(RegExp(r'\s+'))
        .first;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Bem-vindo, ${firstName.isEmpty ? 'investidor' : firstName}.\nDigite seu telefone e o seu e-mail',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.w500,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 34),
        TextField(
          controller: phoneController,
          keyboardType: TextInputType.phone,
          style: const TextStyle(color: Colors.white, fontSize: 18),
          decoration: _lineInputDecoration(
            'Telefone',
            hintText: 'Ex: (11) 91774-8080',
          ),
          onChanged: (value) =>
              _setFormattedValue(phoneController, _formatPhone(value)),
        ),
        const SizedBox(height: 28),
        TextField(
          controller: emailController,
          keyboardType: TextInputType.emailAddress,
          style: const TextStyle(color: Colors.white, fontSize: 18),
          decoration: _lineInputDecoration(
            'E-mail',
            hintText: 'Ex: joao@gmail.com',
          ),
        ),
      ],
    );
  }

  Widget _buildStepThree() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Para finalizar, precisamos que voce crie uma senha',
          style: TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.w500,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 28),
        const Text(
          'Sua senha precisa ter pelo menos 6 caracteres.',
          style: TextStyle(color: Color(0xFFE6E8EE), fontSize: 16, height: 1.6),
        ),
        const SizedBox(height: 24),
        TextField(
          controller: passwordController,
          obscureText: true,
          style: const TextStyle(color: Colors.white, fontSize: 18),
          decoration: _lineInputDecoration('Senha'),
        ),
        const SizedBox(height: 28),
        TextField(
          controller: confirmPasswordController,
          obscureText: true,
          style: const TextStyle(color: Colors.white, fontSize: 18),
          decoration: _lineInputDecoration('Confirme sua senha'),
        ),
      ],
    );
  }

  Widget _buildCurrentStep() {
    switch (_step) {
      case 0:
        return _buildStepOne();
      case 1:
        return _buildStepTwo();
      case 2:
        return _buildStepThree();
      default:
        return _buildStepOne();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF111111),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconButton(
                onPressed: () {
                  if (_step == 0) {
                    Navigator.of(context).pop();
                  } else {
                    setState(() {
                      _step -= 1;
                    });
                  }
                },
                icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(height: 28),
              _buildProgress(),
              const SizedBox(height: 42),
              Expanded(
                child: SingleChildScrollView(child: _buildCurrentStep()),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: controller.isLoading ? null : _handleContinue,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF346AC0),
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(56),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
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
                      : const Text('Continuar', style: TextStyle(fontSize: 18)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
