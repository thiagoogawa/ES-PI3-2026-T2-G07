part of 'home_page.dart';

class _EditProfilePage extends StatefulWidget {
  final AuthenticatedUser user;

  const _EditProfilePage({required this.user});

  @override
  State<_EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<_EditProfilePage> {
  final AuthApiDataSource _authApi = AuthApiDataSource(ApiClient());
  final AuthRemoteDataSource _authRemote = AuthRemoteDataSource();
  final ImagePicker _imagePicker = ImagePicker();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _cpfController;
  late final TextEditingController _phoneController;
  String? _picture;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.user.name ?? '');
    _cpfController = TextEditingController(text: _formatCpf(widget.user.cpf));
    _phoneController = TextEditingController(text: widget.user.phone ?? '');
    _picture = widget.user.picture;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _cpfController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  String _digitsOnly(String? value) {
    if (value == null) {
      return '';
    }

    return value.replaceAll(RegExp(r'\D'), '');
  }

  String _formatCpf(String? value) {
    final digits = _digitsOnly(value);
    if (digits.isEmpty) {
      return '';
    }

    final buffer = StringBuffer();
    for (var index = 0; index < digits.length && index < 11; index++) {
      buffer.write(digits[index]);
      if (index == 2 || index == 5) {
        buffer.write('.');
      } else if (index == 8) {
        buffer.write('-');
      }
    }

    return buffer.toString();
  }

  Uint8List? _decodePendingPicture(String? value) {
    if (value == null || value.isEmpty) {
      return null;
    }

    try {
      return base64Decode(value.trim());
    } catch (_) {
      return null;
    }
  }

  Future<String?> _resolvePictureForSave() async {
    final value = _picture?.trim();

    if (value == null) {
      return null;
    }

    if (value.isEmpty) {
      return '';
    }

    if (value.startsWith('http')) {
      return value;
    }

    final bytes = _decodePendingPicture(value);
    if (bytes == null) {
      throw Exception('Imagem de perfil invalida.');
    }

    return value;
  }

  Future<void> _pickProfilePicture() async {
    try {
      FocusScope.of(context).unfocus();

      final pickedFile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
        maxWidth: 512,
        maxHeight: 512,
        requestFullMetadata: false,
      );

      if (pickedFile == null || !mounted) {
        return;
      }

      final bytes = await pickedFile.readAsBytes();

      if (!mounted) {
        return;
      }

      setState(() {
        _picture = base64Encode(bytes);
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      showAppSnackBar(
        context,
        message: mapUserFriendlyError(
          error,
          fallbackMessage: 'Nao foi possivel abrir a galeria agora.',
        ),
        type: AppSnackBarType.error,
      );
    }
  }

  void _removeProfilePicture() {
    setState(() {
      _picture = '';
    });
  }

  Future<void> _save() async {
    final formState = _formKey.currentState;
    if (formState == null || !formState.validate() || _isSaving) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final idToken = await _authRemote.getIdToken(forceRefresh: true);
      final picture = await _resolvePictureForSave();
      final updatedUser = await _authApi.updateProfile(
        idToken,
        name: _nameController.text.trim(),
        cpf: _digitsOnly(_cpfController.text),
        phone: _phoneController.text.trim(),
        picture: picture,
      );

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop(updatedUser);
    } catch (error) {
      if (!mounted) {
        return;
      }

      showAppSnackBar(
        context,
        message: mapUserFriendlyError(
          error,
          fallbackMessage: 'Nao foi possivel salvar o perfil agora.',
        ),
        type: AppSnackBarType.error,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Widget _buildInput({
    required String label,
    required TextEditingController controller,
    String? helper,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    bool readOnly = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Color(0xFF8F96A3), fontSize: 12),
        ),
        if (helper != null) ...[
          const SizedBox(height: 4),
          Text(
            helper,
            style: const TextStyle(color: Color(0xFF646B78), fontSize: 11),
          ),
        ],
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          validator: validator,
          readOnly: readOnly,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFF1A1C20),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFF2E323A)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFF2E323A)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFF4E91F3)),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFFFF7A8B)),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFFFF7A8B)),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 15,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final displayName = widget.user.name?.trim().isNotEmpty == true
        ? widget.user.name!.trim()
        : widget.user.email?.split('@').first ?? 'Investidor';
    final initials = displayName
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part[0].toUpperCase())
        .join();

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F10),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0F10),
        foregroundColor: Colors.white,
        title: const Text('Editar perfil'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF151618),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFF2A2E36)),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF17191D), Color(0xFF11141A)],
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF4C5B80),
                          border: Border.all(color: const Color(0xFF7586B3)),
                        ),
                        child: _ProfileAvatar(
                          picture: _picture,
                          initials: initials,
                          size: 72,
                          fontSize: 28,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              displayName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              widget.user.email ?? '-',
                              style: const TextStyle(
                                color: Color(0xFFB7BCC8),
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Atualize seus dados para manter o cadastro consistente na plataforma.',
                              style: TextStyle(
                                color: Color(0xFF9398A6),
                                fontSize: 12,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _pickProfilePicture,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Color(0xFF4E91F3)),
                            minimumSize: const Size.fromHeight(46),
                          ),
                          icon: const Icon(Icons.photo_library_outlined),
                          label: const Text('Escolher foto'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      OutlinedButton(
                        onPressed: (_picture == null || _picture!.isEmpty)
                            ? null
                            : _removeProfilePicture,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFFFA2AE),
                          side: const BorderSide(color: Color(0xFF3A2830)),
                          minimumSize: const Size(52, 46),
                        ),
                        child: const Icon(Icons.delete_outline_rounded),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFF151618),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF2A2E36)),
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Dados pessoais',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Edite apenas as informacoes que deseja atualizar.',
                      style: TextStyle(color: Color(0xFFB7BCC8), fontSize: 13),
                    ),
                    const SizedBox(height: 18),
                    _buildInput(
                      label: 'Nome completo',
                      controller: _nameController,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Informe seu nome.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    _buildInput(
                      label: 'CPF',
                      controller: _cpfController,
                      keyboardType: TextInputType.number,
                      helper: '11 digitos.',
                      validator: (value) {
                        if (_digitsOnly(value).length != 11) {
                          return 'CPF invalido.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    _buildInput(
                      label: 'Telefone',
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      helper: 'DDD + numero.',
                      validator: (value) {
                        if (_digitsOnly(value).length < 10) {
                          return 'Telefone invalido.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    _buildInput(
                      label: 'E-mail',
                      controller: TextEditingController(
                        text: widget.user.email ?? '-',
                      ),
                      readOnly: true,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF346AC0),
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(52),
                ),
                icon: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.save_rounded),
                label: Text(_isSaving ? 'Salvando...' : 'Salvar alteracoes'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  final String? picture;
  final String initials;
  final double size;
  final double fontSize;

  const _ProfileAvatar({
    required this.picture,
    required this.initials,
    required this.size,
    required this.fontSize,
  });

  Uint8List? _decodeProfilePicture(String? value) {
    if (value == null || value.trim().isEmpty || value.startsWith('http')) {
      return null;
    }

    try {
      return base64Decode(value.trim());
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bytes = _decodeProfilePicture(picture);

    if (bytes != null) {
      return ClipOval(
        child: Image.memory(
          bytes,
          width: size,
          height: size,
          fit: BoxFit.cover,
        ),
      );
    }

    if (picture != null && picture!.startsWith('http')) {
      return ClipOval(
        child: Image.network(
          picture!,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => Center(
            child: Text(
              initials,
              style: TextStyle(
                color: Colors.white,
                fontSize: fontSize,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      );
    }

    return Center(
      child: Text(
        initials,
        style: TextStyle(
          color: Colors.white,
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
