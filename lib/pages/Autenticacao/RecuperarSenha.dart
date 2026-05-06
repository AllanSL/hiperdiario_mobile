import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/widgets/app_input_decoration.dart';
import '../../state/app_state.dart';

class CpfInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final oldDigits = oldValue.text.replaceAll(RegExp(r'\D'), '');
    var digitsOnly = newValue.text.replaceAll(RegExp(r'\D'), '');

    final isDeleting = newValue.text.length < oldValue.text.length;
    final removedSeparator =
        isDeleting && digitsOnly.length == oldDigits.length;

    if (!isDeleting && oldDigits.length == 11) {
      return oldValue;
    }
    if (removedSeparator && digitsOnly.isNotEmpty) {
      digitsOnly = digitsOnly.substring(0, digitsOnly.length - 1);
    }

    if (digitsOnly.isEmpty) {
      return const TextEditingValue(
        text: '',
        selection: TextSelection.collapsed(offset: 0),
      );
    }

    final buffer = StringBuffer();
    for (var i = 0; i < digitsOnly.length; i++) {
      if (i == 3 || i == 6) {
        buffer.write('.');
      } else if (i == 9) {
        buffer.write('-');
      }
      buffer.write(digitsOnly[i]);
    }

    return TextEditingValue(
      text: buffer.toString(),
      selection: TextSelection.collapsed(offset: buffer.length),
    );
  }
}

class DateInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.selection.baseOffset == 0) {
      return newValue;
    }
    var digitsOnly = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digitsOnly.length > 8) {
      digitsOnly = digitsOnly.substring(0, 8);
    }

    final buffer = StringBuffer();
    for (var i = 0; i < digitsOnly.length; i++) {
      if (i == 2 || i == 4) {
        buffer.write('/');
      }
      buffer.write(digitsOnly[i]);
    }

    final newString = buffer.toString();
    return TextEditingValue(
      text: newString,
      selection: TextSelection.collapsed(offset: newString.length),
    );
  }
}

class RecoverPasswordPage extends StatefulWidget {
  const RecoverPasswordPage({super.key});

  @override
  State<RecoverPasswordPage> createState() => _RecoverPasswordPageState();
}

class _RecoverPasswordPageState extends State<RecoverPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _cpfController = TextEditingController();
  final _dobController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  bool _obscureNewPass = true;
  bool _obscureConfirmPass = true;

  int _step = 1;
  String? _realName;
  List<String> _nameOptions = [];
  String? _selectedName;

  final _fakeNamesTemplate = [
    'Maria da Silva Santos',
    'José Carvalho de Souza',
    'Raimundo Nonato Oliveira',
    'Ana Lúcia Costa',
    'Francisco Chagas Ferreira',
    'Antônio Carlos Almeida',
    'Marta Regina dos Santos',
    'João Batista Lima',
    'Francisca Marques Neto',
    'Paulo Roberto Gonçalves',
  ];

  @override
  void dispose() {
    _cpfController.dispose();
    _dobController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    final colorScheme = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: isError
            ? colorScheme.errorContainer
            : colorScheme.primaryContainer,
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: isError
                  ? colorScheme.onErrorContainer
                  : colorScheme.onPrimaryContainer,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: isError
                      ? colorScheme.onErrorContainer
                      : colorScheme.onPrimaryContainer,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _checkPatient() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final appState = Provider.of<AppState>(context, listen: false);
      final realName = await appState.obterNomePacienteRecuperacao(
        _cpfController.text,
        _dobController.text,
      );

      if (realName == null || realName.isEmpty) {
        throw Exception('Dados não encontrados.');
      }

      _realName = realName;

      _fakeNamesTemplate.shuffle(Random());
      _nameOptions = _fakeNamesTemplate
          .where((name) => name.toLowerCase() != realName.toLowerCase())
          .take(3)
          .toList();

      _nameOptions.add(realName);
      _nameOptions.shuffle(Random());

      setState(() {
        _step = 2;
      });
    } catch (e) {
      _showSnackBar(e.toString().replaceAll('Exception: ', ''), isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedName == null) {
      _showSnackBar(
        'Por favor, selecione qual é o seu nome nas opções.',
        isError: true,
      );
      return;
    }

    if (_newPasswordController.text != _confirmPasswordController.text) {
      _showSnackBar('As senhas não coincidem.', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final appState = Provider.of<AppState>(context, listen: false);

      await appState.recuperarSenha(
        cpf: _cpfController.text,
        novaSenha: _newPasswordController.text,
        nome: _selectedName,
        dataNascimento: _dobController.text,
      );

      _showSnackBar('Senha recuperada com sucesso! Você já pode fazer login.');
      Navigator.of(context).pop();
    } catch (e) {
      _showSnackBar(e.toString().replaceAll('Exception: ', ''), isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Recuperar Senha'), elevation: 0),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(
                  Icons.lock_reset_rounded,
                  size: 64,
                  color: colorScheme.primary,
                ),
                const SizedBox(height: 16),
                Text(
                  _step == 1 ? 'Esqueceu sua senha?' : 'Confirme seu nome',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  _step == 1
                      ? 'Informe seu CPF e Data de Nascimento para buscarmos seu cadastro.'
                      : 'Selecione seu nome na lista e crie uma nova senha para acessar sua conta.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),

                if (_step == 1) ...[
                  // CPF
                  TextFormField(
                    controller: _cpfController,
                    decoration: AppInputDecoration.build(
                      context,
                      labelText: 'CPF',
                      hintText: '000.000.000-00',
                      prefixIcon: const Icon(Icons.badge_outlined),
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [CpfInputFormatter()],
                    validator: (value) {
                      if (value == null || value.isEmpty)
                        return 'Informe o CPF';
                      if (value.length < 14) return 'CPF incompleto';
                      return null;
                    },
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 16),

                  // Data de Nascimento
                  TextFormField(
                    controller: _dobController,
                    decoration: AppInputDecoration.build(
                      context,
                      labelText: 'Data de Nascimento',
                      hintText: 'DD/MM/AAAA',
                      prefixIcon: const Icon(Icons.calendar_today_outlined),
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [DateInputFormatter()],
                    validator: (value) {
                      if (value == null || value.isEmpty)
                        return 'Informe a data';
                      if (value.length < 10) return 'Data incompleta';
                      return null;
                    },
                    onFieldSubmitted: (_) => _checkPatient(),
                  ),
                  const SizedBox(height: 32),

                  FilledButton(
                    onPressed: _isLoading ? null : _checkPatient,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(strokeWidth: 2.5),
                          )
                        : const Text(
                            'Continuar',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                  ),
                ],

                if (_step == 2) ...[
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: colorScheme.outlineVariant),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      children: _nameOptions.map((name) {
                        return RadioListTile<String>(
                          title: Text(name),
                          value: name,
                          groupValue: _selectedName,
                          onChanged: (value) {
                            setState(() {
                              _selectedName = value;
                            });
                          },
                        );
                      }).toList(),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Nova Senha
                  TextFormField(
                    controller: _newPasswordController,
                    obscureText: _obscureNewPass,
                    decoration: AppInputDecoration.build(
                      context,
                      labelText: 'Nova Senha',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureNewPass
                              ? Icons.visibility_off
                              : Icons.visibility,
                        ),
                        onPressed: () =>
                            setState(() => _obscureNewPass = !_obscureNewPass),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty)
                        return 'Informe a nova senha';
                      if (value.length < 6)
                        return 'A senha deve ter no mínimo 6 caracteres';
                      return null;
                    },
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 16),

                  // Confirmar Nova Senha
                  TextFormField(
                    controller: _confirmPasswordController,
                    obscureText: _obscureConfirmPass,
                    decoration: AppInputDecoration.build(
                      context,
                      labelText: 'Confirmar Nova Senha',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureConfirmPass
                              ? Icons.visibility_off
                              : Icons.visibility,
                        ),
                        onPressed: () => setState(
                          () => _obscureConfirmPass = !_obscureConfirmPass,
                        ),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty)
                        return 'Confirme a senha';
                      if (value != _newPasswordController.text)
                        return 'As senhas não coincidem';
                      return null;
                    },
                    onFieldSubmitted: (_) => _submit(),
                  ),
                  const SizedBox(height: 32),

                  Row(
                    children: [
                      TextButton(
                        onPressed: _isLoading
                            ? null
                            : () => setState(() => _step = 1),
                        child: const Text('Voltar'),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton(
                          onPressed: _isLoading ? null : _submit,
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  height: 24,
                                  width: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                  ),
                                )
                              : const Text(
                                  'Redefinir Senha',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
