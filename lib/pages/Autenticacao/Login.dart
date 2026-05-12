import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/widgets/app_input_decoration.dart';
import '../../core/widgets/app_snackbar.dart';
import '../../core/providers/accessibility_provider.dart';
import '../../core/providers/theme_provider.dart';
import '../../core/models/municipio.dart';
import '../../core/services/ibge_service.dart';
import '../../core/services/municipio_service.dart';
import '../../core/services/via_cep_service.dart';
import '../../core/services/cnes_service.dart';
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

    final cursorIndex = newValue.selection.baseOffset.clamp(
      0,
      newValue.text.length,
    );
    final digitsBeforeCursor = newValue.text
        .substring(0, cursorIndex)
        .replaceAll(RegExp(r'\D'), '')
        .length;

    final buffer = StringBuffer();
    int? selectionOffset;
    if (digitsOnly.length > 11) {
      digitsOnly = digitsOnly.substring(0, 11);
    }

    for (int i = 0; i < digitsOnly.length && i < 11; i++) {
      buffer.write(digitsOnly[i]);
      if (i == 2 || i == 5) buffer.write('.');
      if (i == 8) buffer.write('-');
      if (selectionOffset == null && digitsBeforeCursor == i + 1) {
        selectionOffset = buffer.length;
      }
    }

    final formatted = buffer.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(
        offset: selectionOffset ?? formatted.length,
      ),
    );
  }
}

class DateInputFormatter extends TextInputFormatter {
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

    if (!isDeleting && oldDigits.length == 8) {
      return oldValue;
    }
    if (removedSeparator && digitsOnly.isNotEmpty) {
      digitsOnly = digitsOnly.substring(0, digitsOnly.length - 1);
    }

    if (digitsOnly.isEmpty) return newValue.copyWith(text: '');

    final buffer = StringBuffer();
    for (int i = 0; i < digitsOnly.length && i < 8; i++) {
      buffer.write(digitsOnly[i]);
      if (i == 1 || i == 3) buffer.write('/');
    }
    final formatted = buffer.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class PhoneInputFormatter extends TextInputFormatter {
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

    if (digitsOnly.isEmpty) return newValue.copyWith(text: '');

    final buffer = StringBuffer();
    buffer.write('(');
    buffer.write(
      digitsOnly.substring(0, digitsOnly.length >= 2 ? 2 : digitsOnly.length),
    );

    if (digitsOnly.length >= 3) {
      buffer.write(') ');
      if (digitsOnly.length <= 10) {
        buffer.write(
          digitsOnly.substring(
            2,
            digitsOnly.length >= 6 ? 6 : digitsOnly.length,
          ),
        );
        if (digitsOnly.length >= 7) {
          buffer.write('-');
          buffer.write(digitsOnly.substring(6));
        }
      } else {
        buffer.write(
          digitsOnly.substring(
            2,
            digitsOnly.length >= 7 ? 7 : digitsOnly.length,
          ),
        );
        if (digitsOnly.length >= 8) {
          buffer.write('-');
          buffer.write(
            digitsOnly.substring(
              7,
              digitsOnly.length > 11 ? 11 : digitsOnly.length,
            ),
          );
        }
      }
    }

    final formatted = buffer.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class CepInputFormatter extends TextInputFormatter {
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

    if (!isDeleting && oldDigits.length == 8) {
      return oldValue;
    }
    if (removedSeparator && digitsOnly.isNotEmpty) {
      digitsOnly = digitsOnly.substring(0, digitsOnly.length - 1);
    }

    if (digitsOnly.isEmpty) return newValue.copyWith(text: '');

    final buffer = StringBuffer();
    for (int i = 0; i < digitsOnly.length && i < 8; i++) {
      buffer.write(digitsOnly[i]);
      if (i == 4) buffer.write('-');
    }
    final formatted = buffer.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _cpfController = TextEditingController();
  final _passwordController = TextEditingController();
  final _cpfFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();
  String? _cpfBackendError;
  String? _passwordBackendError;
  bool _isLoading = false;

  @override
  void dispose() {
    _cpfController.dispose();
    _passwordController.dispose();
    _cpfFocusNode.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  void _showErrorSnackBar(String message) {
    AppSnackBar.showError(context, message);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      final cpfDigits = _cpfController.text.replaceAll(RegExp(r'\D'), '');
      if (cpfDigits.length != 11) {
        _cpfFocusNode.requestFocus();
      } else if (_passwordController.text.length < 6) {
        _passwordFocusNode.requestFocus();
      }
      return;
    }
    final app = context.read<AppState>();
    final cpf = _cpfController.text;
    final password = _passwordController.text;

    setState(() => _isLoading = true);
    try {
      await app.loginWithCpfPassword(cpf, password);
    } catch (e) {
      if (!mounted) return;
      var msg = e.toString().trim();
      if (msg.startsWith('Exception: ')) {
        msg = msg.substring('Exception: '.length).trim();
      }
      final normalized = msg.toLowerCase();
      String? shortCpfMsg;
      String? shortPasswordMsg;

      if (normalized.contains('cpf inválido') ||
          normalized.contains('cpf invalido')) {
        msg = 'CPF inválido. Confira os números e tente novamente.';
        shortCpfMsg = 'CPF inválido';
      } else if (normalized.contains('acesso negado') ||
          normalized.contains('exclusivo para pacientes')) {
        msg = 'Credenciais inválidas. Verifique seu CPF e senha.';
        shortCpfMsg = 'Acesso negado';
        shortPasswordMsg = null;
      } else if (normalized.contains('perfil de paciente não encontrado')) {
        msg = 'Seu perfil de paciente ainda não foi criado. Entre em contato com a recepção da UBS.';
        shortCpfMsg = 'Perfil não encontrado';
        shortPasswordMsg = null;
      } else if (normalized.contains('invalid credentials') ||
          normalized.contains('invalid login credentials') ||
          normalized.contains('authapi')) {
        msg = 'Credenciais inválidas. Verifique seu CPF e senha.';
        shortCpfMsg = null;
        shortPasswordMsg = 'Senha incorreta';
      }

      _showErrorSnackBar(msg);

      setState(() {
        _cpfBackendError = shortCpfMsg;
        _passwordBackendError = shortPasswordMsg;
      });

      if (shortPasswordMsg != null) {
        _passwordFocusNode.requestFocus();
      } else {
        _cpfFocusNode.requestFocus();
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final themeProvider = context.watch<ThemeProvider>();
    final accessibility = context.watch<AccessibilityProvider>();

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.opaque,
        child: SafeArea(
          child: Stack(
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32.0,
                      vertical: 12.0,
                    ),
                    child: SingleChildScrollView(
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 96,
                              height: 96,
                              decoration: BoxDecoration(
                                color: colorScheme.primaryContainer,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.favorite,
                                size: 52,
                                color: colorScheme.onPrimaryContainer,
                              ),
                            ),
                            const SizedBox(height: 24),
                            Text(
                              'HiperDiário',
                              style: textTheme.titleLarge?.copyWith(
                                fontSize: 32,
                                color: colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Entre com CPF e senha para continuar.',
                              style: textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 32),
                            TextFormField(
                              controller: _cpfController,
                              focusNode: _cpfFocusNode,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(12),
                                CpfInputFormatter(),
                              ],
                              decoration: AppInputDecoration.build(
                                context,
                                labelText: 'CPF',
                                hintText: '000.000.000-00',
                              ).copyWith(errorText: _cpfBackendError),
                              onChanged: (v) {
                                if (_cpfBackendError != null) {
                                  setState(() {
                                    _cpfBackendError = null;
                                  });
                                }
                              },
                              validator: (value) {
                                if (_cpfBackendError != null)
                                  return _cpfBackendError;
                                final v =
                                    value?.replaceAll(RegExp(r'\D'), '') ?? '';
                                if (v.length != 11)
                                  return 'Informe um CPF com 11 dígitos';
                                return null;
                              },
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _passwordController,
                              focusNode: _passwordFocusNode,
                              obscureText: true,
                              decoration: AppInputDecoration.build(
                                context,
                                labelText: 'Senha',
                              ).copyWith(errorText: _passwordBackendError),
                              onChanged: (v) {
                                if (_passwordBackendError != null) {
                                  setState(() {
                                    _passwordBackendError = null;
                                  });
                                }
                              },
                              validator: (value) {
                                if (_passwordBackendError != null)
                                  return _passwordBackendError;
                                if ((value ?? '').length < 6)
                                  return 'Use pelo menos 6 caracteres';
                                return null;
                              },
                            ),
                            const SizedBox(height: 24),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton(
                                onPressed: _isLoading ? null : _submit,
                                child: _isLoading
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Text('Entrar'),
                              ),
                            ),
                            const SizedBox(height: 64),
                            SizedBox(
                              width: double.infinity,
                              child: TextButton(
                                onPressed: _isLoading
                                    ? null
                                    : () {
                                        FocusScope.of(context).unfocus();
                                        Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                const RegisterPage(),
                                          ),
                                        );
                                      },
                                child: const Text(
                                  'Não tem uma conta?\nCadastre-se',
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 16,
                right: 16,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.text_increase),
                      tooltip: 'Tamanho da Fonte',
                      onPressed: () {
                        final currentScale = accessibility.scale;
                        final currentIndex = AccessibilityScale.values.indexOf(
                          currentScale,
                        );
                        final nextIndex =
                            (currentIndex + 1) %
                            AccessibilityScale.values.length;
                        accessibility.setScale(
                          AccessibilityScale.values[nextIndex],
                        );
                      },
                      style: IconButton.styleFrom(
                        backgroundColor: colorScheme.surfaceContainerHighest,
                        foregroundColor: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: Icon(
                        themeProvider.isDark(context)
                            ? Icons.light_mode
                            : Icons.dark_mode,
                      ),
                      tooltip: 'Alternar Tema',
                      onPressed: () => themeProvider.toggle(context),
                      style: IconButton.styleFrom(
                        backgroundColor: colorScheme.surfaceContainerHighest,
                        foregroundColor: colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  static const List<MapEntry<String, String>> _genderOptions =
      <MapEntry<String, String>>[
        MapEntry('Masculino', 'masculino'),
        MapEntry('Feminino', 'feminino'),
        MapEntry('Outro', 'outro'),
      ];

  static const List<String> _healthConditionOptions = <String>[
    'Diabetes tipo 1',
    'Diabetes tipo 2',
    'Hipertensão',
  ];

  static const List<String> _relationshipOptions = <String>[
    'Cônjuge',
    'Mãe',
    'Pai',
    'Filho(a)',
    'Irmão(ã)',
    'Avô/Avó',
    'Tio(a)',
    'Outro',
  ];

  final _stepKeys = [
    GlobalKey<FormState>(),
    GlobalKey<FormState>(),
    GlobalKey<FormState>(),
  ];
  final _cpfController = TextEditingController();
  final _nameController = TextEditingController();
  final _birthDateController = TextEditingController();
  final _genderController = TextEditingController();
  final _genderDisplayController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _emergencyNameController = TextEditingController();
  final _emergencyPhoneController = TextEditingController();
  final _emergencyRelationshipController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _cepController = TextEditingController();
  final _logradouroController = TextEditingController();
  final _numeroController = TextEditingController();
  final _complementoController = TextEditingController();
  final _bairroController = TextEditingController();
  final _estadoController = TextEditingController();
  final _municipioController = TextEditingController();
  final _ubsController = TextEditingController();

  String? _cpfBackendError;
  final _cpfFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();
  final _confirmPasswordFocusNode = FocusNode();
  final _nameFocusNode = FocusNode();
  final _birthDateFocusNode = FocusNode();
  final _genderFocusNode = FocusNode();
  final _conditionFocusNode = FocusNode();
  final _phoneFocusNode = FocusNode();
  final _emailFocusNode = FocusNode();
  final _emergencyNameFocusNode = FocusNode();
  final _emergencyPhoneFocusNode = FocusNode();
  final _emergencyRelationshipFocusNode = FocusNode();
  final _cepFocusNode = FocusNode();
  final _logradouroFocusNode = FocusNode();
  final _numeroFocusNode = FocusNode();
  final _bairroFocusNode = FocusNode();

  EstadoBrasileiro? _estadoSelecionado;
  Municipio? _municipioSelecionado;
  CnesEstabelecimento? _ubsSelecionada;

  List<Municipio> _todosMunicipios = [];
  List<Municipio> _municipiosFiltrados = [];
  List<CnesEstabelecimento> _todasUbs = [];
  List<CnesEstabelecimento> _ubsFiltradas = [];

  bool _carregandoMunicipios = false;
  bool _carregandoUbs = false;
  String? _erroMunicipios;
  String? _erroUbs;
  bool _aguardandoMunicipios = false;
  final Map<String, List<Municipio>> _municipiosCache = {};
  int _requestGeneration = 0;

  final _estadoFocusNode = FocusNode();
  final _municipioFocusNode = FocusNode();
  final _ubsFocusNode = FocusNode();
  final _estadoFieldKey = GlobalKey();
  final _municipioFieldKey = GlobalKey();
  final _ubsFieldKey = GlobalKey();
  final _genderFieldKey = GlobalKey();
  final _estadoOverlayController = OverlayPortalController();
  final _municipioOverlayController = OverlayPortalController();
  final _ubsOverlayController = OverlayPortalController();
  final _genderOverlayController = OverlayPortalController();
  ModalRoute<dynamic>? _modalRoute;
  final _conditionFieldKey = GlobalKey();
  final _conditionOverlayController = OverlayPortalController();
  final _relationshipFieldKey = GlobalKey();
  final _relationshipOverlayController = OverlayPortalController();
  bool _estadoDropdownAberto = false;
  bool _municipioDropdownAberto = false;
  bool _ubsDropdownAberto = false;
  bool _genderDropdownAberto = false;
  bool _conditionDropdownAberto = false;
  bool _relationshipDropdownAberto = false;
  bool _estadoModoDigitacao = false;
  bool _municipioModoDigitacao = false;
  bool _ubsModoDigitacao = false;
  final _scrollController = ScrollController();
  List<EstadoBrasileiro> _estadosFiltrados = estadosBrasileiros;

  bool _isLoading = false;
  int _currentStep = 0;
  bool _showPassword = false;
  bool _showConfirmPassword = false;
  bool _carregandoCep = false;
  String? _erroCep;
  String _ultimoCepBuscado = '';
  final List<String> _selectedConditions = <String>[];
  String? _selectedEmergencyRelationship;

  String _extractErrorMessage(Object error) {
    var message = error.toString().trim();
    if (message.startsWith('Exception: ')) {
      message = message.substring('Exception: '.length).trim();
    }

    final normalized = message.toLowerCase();
    if (normalized.contains('cpf inválido') ||
        normalized.contains('cpf invalido')) {
      return 'CPF inválido. Confira os números e tente novamente.';
    }
    if (normalized.contains('invalid credentials') ||
        normalized.contains('invalid login credentials') ||
        normalized.contains('authapi')) {
      return 'CPF já cadastrado. Faça login ou recupere a senha.';
    }

    return message;
  }

  void _showErrorSnackBar(Object error) {
    final message = error is String ? error : _extractErrorMessage(error);
    AppSnackBar.showError(context, message);
  }

  @override
  void initState() {
    super.initState();

    _estadoController.addListener(_onEstadoChanged);
    _estadoFocusNode.addListener(_onEstadoFocusChanged);
    _municipioController.addListener(_onMunicipioChanged);
    _municipioFocusNode.addListener(_onMunicipioFocusChanged);
    _ubsController.addListener(_onUbsChanged);
    _ubsFocusNode.addListener(_onUbsFocusChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != _modalRoute) {
      if (_modalRoute != null) {
        _modalRoute!.removeScopedWillPopCallback(_onWillPop);
      }
      _modalRoute = route;
      _modalRoute?.addScopedWillPopCallback(_onWillPop);
    }
  }

  @override
  void dispose() {
    _cpfController.dispose();
    _nameController.dispose();
    _birthDateController.dispose();
    _genderController.dispose();
    _genderDisplayController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _emergencyNameController.dispose();
    _emergencyPhoneController.dispose();
    _emergencyRelationshipController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _cepController.dispose();
    _logradouroController.dispose();
    _numeroController.dispose();
    _complementoController.dispose();
    _bairroController.dispose();
    _estadoController.removeListener(_onEstadoChanged);
    _estadoFocusNode.removeListener(_onEstadoFocusChanged);
    _municipioController.removeListener(_onMunicipioChanged);
    _municipioFocusNode.removeListener(_onMunicipioFocusChanged);
    _ubsController.removeListener(_onUbsChanged);
    _ubsFocusNode.removeListener(_onUbsFocusChanged);
    _estadoController.dispose();
    _estadoFocusNode.dispose();
    _municipioFocusNode.dispose();
    _municipioController.dispose();
    _ubsFocusNode.dispose();
    _ubsController.dispose();
    _modalRoute?.removeScopedWillPopCallback(_onWillPop);
    _cpfFocusNode.dispose();
    _passwordFocusNode.dispose();
    _confirmPasswordFocusNode.dispose();
    _nameFocusNode.dispose();
    _birthDateFocusNode.dispose();
    _genderFocusNode.dispose();
    _phoneFocusNode.dispose();
    _emailFocusNode.dispose();
    _emergencyNameFocusNode.dispose();
    _emergencyPhoneFocusNode.dispose();
    _emergencyRelationshipFocusNode.dispose();
    _cepFocusNode.dispose();
    _logradouroFocusNode.dispose();
    _numeroFocusNode.dispose();
    _bairroFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  List<String> _selectedDiseases() {
    return List<String>.from(_selectedConditions);
  }

  bool _hasPartialEmergencyContact() {
    final name = _emergencyNameController.text.trim();
    final phone = _emergencyPhoneController.text.trim();
    final relationship = _emergencyRelationshipController.text.trim();

    final anyFilled =
        name.isNotEmpty || phone.isNotEmpty || relationship.isNotEmpty;
    final minimallyValid = name.isNotEmpty && phone.isNotEmpty;
    return anyFilled && !minimallyValid;
  }

  void _focusFirstInvalidField() {
    if (_currentStep == 2) {
      final cpfDigits = _cpfController.text.replaceAll(RegExp(r'\D'), '');
      if (cpfDigits.length != 11) {
        _cpfFocusNode.requestFocus();
        return;
      }
      if (_passwordController.text.length < 6) {
        _passwordFocusNode.requestFocus();
        return;
      }
      if (_confirmPasswordController.text != _passwordController.text) {
        _confirmPasswordFocusNode.requestFocus();
        return;
      }
    }

    if (_currentStep == 0) {
      // 1. Dados Pessoais
      final name = _nameController.text.trim();
      if (name.length < 3) {
        _nameFocusNode.requestFocus();
        return;
      }

      final birthText = _birthDateController.text;
      bool dateHasError = false;
      if (birthText.length < 10) {
        dateHasError = true;
      } else {
        final parts = birthText.split('/');
        if (parts.length == 3) {
          final d = int.tryParse(parts[0]) ?? 0;
          final m = int.tryParse(parts[1]) ?? 0;
          final y = int.tryParse(parts[2]) ?? 0;

          final testDate = DateTime(y, m, d);
          if (y < 1900 ||
              y > DateTime.now().year ||
              testDate.year != y ||
              testDate.month != m ||
              testDate.day != d) {
            dateHasError = true;
          }
        } else {
          dateHasError = true;
        }
      }
      if (dateHasError) {
        _birthDateFocusNode.requestFocus();
        return;
      }

      final gender = _genderController.text.trim();
      if (gender.isEmpty) {
        _genderFocusNode.requestFocus();
        _toggleDropdownGenero();
        return;
      }

      final phone = _phoneController.text.replaceAll(RegExp(r'\D'), '');
      if (phone.length < 10) {
        _phoneFocusNode.requestFocus();
        return;
      }

      final email = _emailController.text.trim();
      if (email.isNotEmpty) {
        final emailRegex = RegExp(r'^.+@.+\..+$');
        if (!emailRegex.hasMatch(email)) {
          _emailFocusNode.requestFocus();
          return;
        }
      }

      // 2. Condições de Saúde
      if (_selectedConditions.isEmpty) {
        _conditionFocusNode.requestFocus();
        _toggleDropdownCondicao();
        return;
      }

      // 3. Contato de Emergência
      if (_hasPartialEmergencyContact()) {
        final ename = _emergencyNameController.text.trim();
        if (ename.isEmpty) {
          _emergencyNameFocusNode.requestFocus();
          return;
        }

        final ephone = _emergencyPhoneController.text.replaceAll(
          RegExp(r'\D'),
          '',
        );
        if (ephone.length < 10) {
          _emergencyPhoneFocusNode.requestFocus();
          return;
        }

        final rel = _emergencyRelationshipController.text.trim();
        if (rel.isEmpty) {
          _emergencyRelationshipFocusNode.requestFocus();
          _toggleDropdownParentesco();
          return;
        }
      }
    }

    if (_currentStep == 1) {
      // 4. Endereço
      final cepDigits = _cepController.text.replaceAll(RegExp(r'\D'), '');
      if (cepDigits.length != 8) {
        _cepFocusNode.requestFocus();
        return;
      }
      if (_logradouroController.text.trim().isEmpty) {
        _logradouroFocusNode.requestFocus();
        return;
      }
      if (_numeroController.text.trim().isEmpty) {
        _numeroFocusNode.requestFocus();
        return;
      }
      if (_bairroController.text.trim().isEmpty) {
        _bairroFocusNode.requestFocus();
        return;
      }
      if (_estadoSelecionado == null) {
        _estadoFocusNode.requestFocus();
        return;
      }
      if (_municipioSelecionado == null) {
        _municipioFocusNode.requestFocus();
        return;
      }
    }
  }

  String _normalizarNome(String input) {
    const mapa = {
      'á': 'a',
      'à': 'a',
      'â': 'a',
      'ã': 'a',
      'ä': 'a',
      'é': 'e',
      'è': 'e',
      'ê': 'e',
      'ë': 'e',
      'í': 'i',
      'ì': 'i',
      'î': 'i',
      'ï': 'i',
      'ó': 'o',
      'ò': 'o',
      'ô': 'o',
      'õ': 'o',
      'ö': 'o',
      'ú': 'u',
      'ù': 'u',
      'û': 'u',
      'ü': 'u',
      'ç': 'c',
    };

    return input
        .trim()
        .toLowerCase()
        .split('')
        .map((char) => mapa[char] ?? char)
        .join();
  }

  Future<void> _buscarEnderecoPorCep(String cep) async {
    final digits = cep.replaceAll(RegExp(r'\D'), '');
    if (digits.length != 8) return;
    if (digits == _ultimoCepBuscado) return;

    setState(() {
      _carregandoCep = true;
      _erroCep = null;
      _ultimoCepBuscado = digits;
    });

    try {
      final endereco = await ViaCepService.buscarEndereco(digits);
      if (!mounted) return;

      if (endereco.logradouro.isNotEmpty) {
        _logradouroController.text = endereco.logradouro;
      }
      if (endereco.bairro.isNotEmpty) {
        _bairroController.text = endereco.bairro;
      }
      if (endereco.complemento.isNotEmpty) {
        _complementoController.text = endereco.complemento;
      }

      EstadoBrasileiro? estado;
      for (final e in estadosBrasileiros) {
        if (e.sigla.toLowerCase() == endereco.uf.toLowerCase()) {
          estado = e;
          break;
        }
      }

      if (estado == null) {
        setState(() => _erroCep = 'UF não encontrada para este CEP.');
        return;
      }

      setState(() {
        _estadoSelecionado = estado;
        _estadosFiltrados = estadosBrasileiros;
        _estadoController.text = '${estado!.sigla} - ${estado.nome}';
        _estadoController.selection = TextSelection.collapsed(
          offset: _estadoController.text.length,
        );
        _municipioSelecionado = null;
        _municipioController.text = '';
      });

      var municipios = await _buscarMunicipios(estado.sigla);
      if (!mounted) return;

      Municipio? municipioEncontrado;
      final codigoIbge = endereco.codigoIbge;
      if (codigoIbge != null && codigoIbge > 0) {
        municipioEncontrado = await IbgeService.buscarMunicipioPorId(
          idMunicipio: codigoIbge,
          siglaUf: estado.sigla,
          codigoUf: estado.codigoIbge,
        );
      }

      if (municipioEncontrado == null && municipios.isNotEmpty) {
        final localidadeNormalizada = _normalizarNome(endereco.localidade);
        for (final municipio in municipios) {
          if (_normalizarNome(municipio.nome) == localidadeNormalizada) {
            municipioEncontrado = municipio;
            break;
          }
        }
      }

      if (municipioEncontrado != null) {
        if (municipios.isEmpty ||
            !municipios.any(
              (m) => m.codigoMunicipio == municipioEncontrado!.codigoMunicipio,
            )) {
          municipios = [...municipios, municipioEncontrado];
          municipios.sort((a, b) => a.nome.compareTo(b.nome));
          setState(() {
            _todosMunicipios = municipios;
            _municipiosFiltrados = municipios;
            _erroMunicipios = null;
            _carregandoMunicipios = false;
          });
        }
      }

      if (municipioEncontrado == null) {
        setState(() => _erroCep = 'Município não encontrado para este CEP.');
        return;
      }

      setState(() {
        _municipioSelecionado = municipioEncontrado;
        _municipioController.text = municipioEncontrado!.nome;
        _municipioController.selection = TextSelection.collapsed(
          offset: municipioEncontrado.nome.length,
        );
      });
      _buscarUbs();
    } catch (e) {
      if (!mounted) return;
      setState(() => _erroCep = 'Não foi possível localizar o CEP.');
    } finally {
      if (mounted) setState(() => _carregandoCep = false);
    }
  }

  void _onEstadoFocusChanged() {
    if (_estadoFocusNode.hasFocus) {
      _estadoController.clear();
      setState(() {
        _estadosFiltrados = estadosBrasileiros;
        _estadoModoDigitacao = false;
      });
      _abrirDropdownEstado();
    } else {
      setState(() => _estadoModoDigitacao = false);
      _fecharDropdownEstado();
      if (_estadoSelecionado != null) {
        _estadoController.text =
            '${_estadoSelecionado!.sigla} - ${_estadoSelecionado!.nome}';
      }
    }
  }

  void _onEstadoTap() {
    if (!_estadoDropdownAberto) {
      _abrirDropdownEstado();
    } else if (!_estadoModoDigitacao) {
      setState(() => _estadoModoDigitacao = true);
      _estadoFocusNode.requestFocus();
    }
  }

  void _onEstadoChanged() {
    final q = _estadoController.text.trim().toLowerCase();
    setState(() {
      _estadosFiltrados = q.isEmpty
          ? estadosBrasileiros
          : estadosBrasileiros
                .where(
                  (e) =>
                      e.sigla.toLowerCase().contains(q) ||
                      e.nome.toLowerCase().contains(q),
                )
                .toList();
    });
  }

  void _abrirDropdownEstado() {
    if (!_estadoDropdownAberto) {
      setState(() => _estadoDropdownAberto = true);
      _estadoOverlayController.show();
    }
  }

  void _fecharDropdownEstado() {
    if (_estadoDropdownAberto) {
      setState(() => _estadoDropdownAberto = false);
      _estadoOverlayController.hide();
    }
  }

  void _selecionarEstado(EstadoBrasileiro estado) {
    setState(() {
      _estadoSelecionado = estado;
      _estadosFiltrados = estadosBrasileiros;
      _municipioSelecionado = null;
      _todosMunicipios = [];
      _municipiosFiltrados = [];
    });
    _estadoController.text = '${estado.sigla} - ${estado.nome}';
    _estadoController.selection = TextSelection.collapsed(
      offset: _estadoController.text.length,
    );
    _fecharDropdownEstado();
    _estadoFocusNode.unfocus();
    _buscarMunicipios(estado.sigla);
  }

  (Offset, double) _calcularPosicaoDropdownEstado() {
    final box =
        _estadoFieldKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return (Offset.zero, 300);
    final offset = box.localToGlobal(Offset.zero);
    return (Offset(offset.dx, offset.dy + box.size.height + 4), box.size.width);
  }

  void _onMunicipioFocusChanged() {
    if (_municipioFocusNode.hasFocus) {
      setState(() => _municipioModoDigitacao = false);
      _abrirDropdownMunicipio();
    } else {
      setState(() => _municipioModoDigitacao = false);
      _fecharDropdownMunicipio();
    }
  }

  void _onMunicipioTap() {
    if (!_municipioDropdownAberto) {
      _abrirDropdownMunicipio();
    } else if (!_municipioModoDigitacao) {
      setState(() => _municipioModoDigitacao = true);
      _municipioFocusNode.requestFocus();
    }
  }

  void _onMunicipioChanged() {
    final q = _municipioController.text.trim().toLowerCase();
    setState(() {
      _municipiosFiltrados = q.isEmpty
          ? _todosMunicipios
          : _todosMunicipios
                .where((m) => m.nome.toLowerCase().contains(q))
                .toList();
    });
  }

  void _abrirDropdownMunicipio() {
    if (!_municipioDropdownAberto) {
      setState(() => _municipioDropdownAberto = true);
      _municipioOverlayController.show();
    }
  }

  void _fecharDropdownMunicipio() {
    if (_municipioDropdownAberto) {
      setState(() => _municipioDropdownAberto = false);
      _municipioOverlayController.hide();
    }
  }

  void _selecionarMunicipio(Municipio municipio) {
    setState(() {
      _municipioSelecionado = municipio;
    });
    _municipioController.text = municipio.nome;
    _municipioController.selection = TextSelection.collapsed(
      offset: municipio.nome.length,
    );
    _fecharDropdownMunicipio();
    _municipioFocusNode.unfocus();
    _buscarUbs();
  }

  (Offset, double) _calcularPosicaoDropdownMunicipio() {
    final box =
        _municipioFieldKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return (Offset.zero, 300);
    final offset = box.localToGlobal(Offset.zero);
    return (Offset(offset.dx, offset.dy + box.size.height + 4), box.size.width);
  }

  void _onUbsChanged() {
    final q = _ubsController.text.trim().toLowerCase();
    setState(() {
      _ubsFiltradas = q.isEmpty
          ? _todasUbs
          : _todasUbs
                .where((u) => u.nomeFantasia.toLowerCase().contains(q))
                .toList();
    });
  }

  void _onUbsFocusChanged() {
    if (_ubsFocusNode.hasFocus) {
      setState(() => _ubsModoDigitacao = false);
      if (!_ubsDropdownAberto) {
        setState(() => _ubsDropdownAberto = true);
        _ubsOverlayController.show();
      }
    } else {
      Future.delayed(const Duration(milliseconds: 150), () {
        if (mounted) _fecharDropdownUbs();
      });
    }
  }

  void _fecharDropdownUbs() {
    if (_ubsDropdownAberto) {
      setState(() => _ubsDropdownAberto = false);
      _ubsOverlayController.hide();
    }
  }

  void _selecionarUbs(CnesEstabelecimento ubs) {
    setState(() {
      _ubsSelecionada = ubs;
      _erroUbs = null;
      _ubsModoDigitacao = false;
    });
    final formatted = formatCnesDisplayName(ubs.nomeFantasia);
    _ubsController.text = formatted;
    _ubsController.selection = TextSelection.collapsed(
      offset: formatted.length,
    );
    _fecharDropdownUbs();
    _ubsFocusNode.unfocus();
  }

  Future<void> _onUbsTap({bool fromArrow = false}) async {
    if (!_ubsDropdownAberto) {
      if (!fromArrow && !_ubsFocusNode.hasFocus) {
        _ubsFocusNode.requestFocus();
      }
      setState(() => _ubsDropdownAberto = true);
      await Future.delayed(const Duration(milliseconds: 50));
      if (_ubsFieldKey.currentContext != null) {
        await Scrollable.ensureVisible(
          _ubsFieldKey.currentContext!,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          alignment: 0.1,
        );
      }
      _ubsOverlayController.show();
    } else if (!_ubsModoDigitacao && !fromArrow) {
      setState(() => _ubsModoDigitacao = true);
      _ubsFocusNode.requestFocus();
    }
  }

  (Offset, double) _calcularPosicaoDropdownUbs() {
    final box = _ubsFieldKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return (Offset.zero, 300);
    final offset = box.localToGlobal(Offset.zero);
    return (Offset(offset.dx, offset.dy + box.size.height + 4), box.size.width);
  }

  Future<void> _buscarUbs() async {
    if (_municipioSelecionado == null) return;

    setState(() {
      _carregandoUbs = true;
      _erroUbs = null;
      _todasUbs = [];
      _ubsFiltradas = [];
      _ubsSelecionada = null;
      _ubsController.clear();
      _ubsModoDigitacao = true;
    });

    try {
      final codigoUf = _municipioSelecionado!.codigoUf;
      final codigoMunicipio = _municipioSelecionado!.codigoMunicipio;

      final resultado = await CnesService.buscarEstabelecimentos(
        codigoUf: codigoUf,
        codigoMunicipio: codigoMunicipio,
        tipoUnidade: 2,
      );

      if (mounted) {
        setState(() {
          _todasUbs = resultado;
          _ubsFiltradas = resultado;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _erroUbs = 'Erro ao buscar UBS';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _carregandoUbs = false;
        });
      }
    }
  }

  void _abrirDropdownGenero() {
    if (!_genderDropdownAberto) {
      setState(() => _genderDropdownAberto = true);
      _genderOverlayController.show();
    }
  }

  void _fecharDropdownGenero() {
    if (_genderDropdownAberto) {
      setState(() => _genderDropdownAberto = false);
      _genderOverlayController.hide();
    }
  }

  void _toggleDropdownGenero() {
    if (_genderDropdownAberto) {
      _fecharDropdownGenero();
      return;
    }
    _abrirDropdownGenero();
  }

  void _selecionarGenero(MapEntry<String, String> option) {
    setState(() {
      _genderController.text = option.value;
      _genderDisplayController.text = option.key;
    });
    _fecharDropdownGenero();
  }

  (Offset, double) _calcularPosicaoDropdownGenero() {
    final box =
        _genderFieldKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return (Offset.zero, 300);
    final offset = box.localToGlobal(Offset.zero);
    return (Offset(offset.dx, offset.dy + box.size.height + 4), box.size.width);
  }

  List<String> get _availableHealthConditions => _healthConditionOptions
      .where((condition) => !_selectedConditions.contains(condition))
      .toList();

  void _abrirDropdownCondicao() {
    if (!_conditionDropdownAberto) {
      setState(() => _conditionDropdownAberto = true);
      _conditionOverlayController.show();
    }
  }

  void _fecharDropdownCondicao() {
    if (_conditionDropdownAberto) {
      setState(() => _conditionDropdownAberto = false);
      _conditionOverlayController.hide();
    }
  }

  void _toggleDropdownCondicao() {
    if (_conditionDropdownAberto) {
      _fecharDropdownCondicao();
      return;
    }
    _abrirDropdownCondicao();
  }

  void _selecionarCondicao(String condition) {
    if (_selectedConditions.contains(condition)) return;
    setState(() {
      _selectedConditions.add(condition);
    });
    // Se o formulário já tinha erro, revalida para remover a mensagem em vermelho
    _stepKeys[1].currentState?.validate();
    _fecharDropdownCondicao();
  }

  (Offset, double) _calcularPosicaoDropdownCondicao() {
    final box =
        _conditionFieldKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return (Offset.zero, 300);
    final offset = box.localToGlobal(Offset.zero);
    return (Offset(offset.dx, offset.dy + box.size.height + 4), box.size.width);
  }

  void _fecharDropdownParentesco() {
    if (_relationshipDropdownAberto) {
      setState(() => _relationshipDropdownAberto = false);
      _relationshipOverlayController.hide();
    }
  }

  Future<void> _prepararCampoParentescoParaDropdown() async {
    final fieldContext = _relationshipFieldKey.currentContext;
    if (fieldContext == null) return;

    final scrollable = Scrollable.of(fieldContext);
    if (scrollable.position.maxScrollExtent > 0) {
      await scrollable.position.animateTo(
        scrollable.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _toggleDropdownParentesco() async {
    if (!_emergencyRelationshipFocusNode.hasFocus) {
      _emergencyRelationshipFocusNode.requestFocus();
    }

    if (_relationshipDropdownAberto) {
      _fecharDropdownParentesco();
      return;
    }

    // Primeiro expende o layout falso do fundo, sem mostrar o overlay ainda
    setState(() => _relationshipDropdownAberto = true);
    // Aguarda o container fantasma no fim da tela expandir para ter espaço de scroll
    await Future.delayed(const Duration(milliseconds: 50));
    // Sobe a tela com a animação
    await _prepararCampoParentescoParaDropdown();
    // Agora que a tela e o campo estão nas posições finais, exibimos o menu (que vai ter mais espaço calculado)
    _relationshipOverlayController.show();
  }

  void _selecionarParentesco(String relationship) {
    setState(() {
      _selectedEmergencyRelationship = relationship;
      _emergencyRelationshipController.text = relationship;
    });
    _fecharDropdownParentesco();
  }

  ({double top, double width, double maxHeight})
  _calcularDropdownParentescoLayout(BuildContext context) {
    final box =
        _relationshipFieldKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) {
      return (top: 0, width: 300, maxHeight: 240);
    }

    final offset = box.localToGlobal(Offset.zero);
    final fieldBottom = offset.dy + box.size.height;

    final mq = MediaQuery.of(context);
    final viewportBottom = mq.size.height - mq.viewInsets.bottom;
    final availableBelow = (viewportBottom - fieldBottom - 8.0).clamp(
      0.0,
      double.infinity,
    );
    final maxHeight = availableBelow.clamp(120.0, double.infinity);
    final top = fieldBottom + 4.0;

    return (top: top, width: box.size.width, maxHeight: maxHeight);
  }

  Future<List<Municipio>> _buscarMunicipios(String siglaUf) async {
    _requestGeneration++;
    final minhaGeracao = _requestGeneration;

    setState(() {
      _carregandoMunicipios = true;
      _erroMunicipios = null;
      _todosMunicipios = [];
      _municipiosFiltrados = [];
      _municipioSelecionado = null;
      _municipioController.text = '';
      _aguardandoMunicipios = false;
    });

    final estadoSelecionado = estadosBrasileiros.firstWhere(
      (e) => e.sigla.toUpperCase() == siglaUf.toUpperCase(),
    );
    var lista = await IbgeService.buscarMunicipiosPorEstado(
      codigoUf: estadoSelecionado.codigoIbge,
      siglaUf: estadoSelecionado.sigla,
    );
    if (!mounted || minhaGeracao != _requestGeneration) return [];

    _municipiosCache[siglaUf] = lista;

    setState(() {
      _carregandoMunicipios = false;
      if (lista.isEmpty) {
        _erroMunicipios =
            'Não foi possível carregar os municípios. Verifique sua conexão.';
      } else {
        _todosMunicipios = lista;
        _municipiosFiltrados = lista;
      }
    });
    return lista;
  }

  Widget _buildStepContent(ColorScheme colorScheme, TextTheme textTheme) {
    switch (_currentStep) {
      case 0:
        return Form(
          key: _stepKeys[0],
          child: Column(
            children: [
              const SizedBox(height: 24),
              Align(
                alignment: Alignment.centerLeft,
                child: Text('Dados pessoais', style: textTheme.titleSmall),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _nameController,
                focusNode: _nameFocusNode,
                decoration: AppInputDecoration.build(
                  context,
                  labelText: 'Nome completo',
                ),
                validator: (v) => (v == null || v.trim().length < 3)
                    ? 'Informe seu nome'
                    : null,
                enabled: !_isLoading,
                onChanged: (v) => setState(() {}),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _birthDateController,
                focusNode: _birthDateFocusNode,
                decoration: AppInputDecoration.build(
                  context,
                  labelText: 'Data de nascimento',
                  hintText: 'dd/mm/aaaa',
                ),
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Informe a data';
                  if (v.length < 10) return 'Data incompleta';
                  final parts = v.split('/');
                  if (parts.length == 3) {
                    final d = int.tryParse(parts[0]) ?? 0;
                    final m = int.tryParse(parts[1]) ?? 0;
                    final y = int.tryParse(parts[2]) ?? 0;

                    final testDate = DateTime(y, m, d);
                    if (y < 1900 ||
                        y > DateTime.now().year ||
                        testDate.year != y ||
                        testDate.month != m ||
                        testDate.day != d) {
                      return 'Data inválida';
                    }
                  } else {
                    return 'Data inválida';
                  }
                  return null;
                },
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(9),
                  DateInputFormatter(),
                ],
                enabled: !_isLoading && _nameController.text.trim().length >= 3,
                onChanged: (v) => setState(() {}),
              ),
              const SizedBox(height: 16),
              OverlayPortal(
                controller: _genderOverlayController,
                overlayChildBuilder: (overlayContext) {
                  final (pos, width) = _calcularPosicaoDropdownGenero();
                  final mq = MediaQuery.of(context);
                  final alturaDisponivel =
                      mq.size.height - mq.viewInsets.bottom - pos.dy - 8;
                  return Positioned(
                    left: pos.dx,
                    top: pos.dy,
                    width: width,
                    child: MediaQuery(
                      data: mq,
                      child: _DropdownString(
                        items: _genderOptions
                            .map((option) => option.key)
                            .toList(),
                        colorScheme: colorScheme,
                        emptyMessage: 'Nenhuma opção disponível.',
                        icon: Icons.wc_outlined,
                        onSelected: (selectedLabel) {
                          final option = _genderOptions.firstWhere(
                            (entry) => entry.key == selectedLabel,
                          );
                          _selecionarGenero(option);
                        },
                        maxHeight: alturaDisponivel.clamp(
                          120.0,
                          double.infinity,
                        ),
                      ),
                    ),
                  );
                },
                child: TextFormField(
                  key: _genderFieldKey,
                  controller: _genderDisplayController,
                  focusNode: _genderFocusNode,
                  readOnly: true,
                  onTap: _toggleDropdownGenero,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Selecione o gênero';
                    }
                    return null;
                  },
                  decoration: AppInputDecoration.build(
                    context,
                    labelText: 'Gênero',
                    hintText: 'Toque para selecionar',
                    prefixIcon: Icon(
                      Icons.wc_outlined,
                      color: colorScheme.primary,
                    ),
                    suffixIcon: _genderController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              setState(() {
                                _genderController.clear();
                                _genderDisplayController.clear();
                              });
                              _fecharDropdownGenero();
                            },
                          )
                        : IconButton(
                            icon: Icon(
                              _genderDropdownAberto
                                  ? Icons.arrow_drop_up
                                  : Icons.arrow_drop_down,
                              color: colorScheme.onSurfaceVariant,
                            ),
                            onPressed: () {
                              if (_genderDropdownAberto) {
                                _fecharDropdownGenero();
                              } else {
                                _toggleDropdownGenero();
                              }
                            },
                          ),
                  ),
                  enabled:
                      !_isLoading && _birthDateController.text.length == 10,
                  onChanged: (v) => setState(() {}),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phoneController,
                focusNode: _phoneFocusNode,
                decoration: AppInputDecoration.build(
                  context,
                  labelText: 'Telefone',
                  hintText: '(00) 00000-0000',
                ),
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(12),
                  PhoneInputFormatter(),
                ],
                enabled:
                    !_isLoading && _genderDisplayController.text.isNotEmpty,
                onChanged: (v) => setState(() {}),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailController,
                focusNode: _emailFocusNode,
                decoration: AppInputDecoration.build(
                  context,
                  labelText: 'Email de contato',
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (v) {
                  if (v == null || v.isEmpty) return null;
                  final emailRegex = RegExp(r'^.+@.+\..+$');
                  return emailRegex.hasMatch(v) ? null : 'Email inválido';
                },
                enabled:
                    !_isLoading &&
                    _phoneController.text
                            .replaceAll(RegExp(r'\D'), '')
                            .length >=
                        10,
                onChanged: (v) => setState(() {}),
              ),
              const SizedBox(height: 32),
              Align(
                alignment: Alignment.centerLeft,
                child: Text('Condições de saúde', style: textTheme.titleSmall),
              ),
              const SizedBox(height: 8),
              OverlayPortal(
                controller: _conditionOverlayController,
                overlayChildBuilder: (overlayContext) {
                  final (pos, width) = _calcularPosicaoDropdownCondicao();
                  final mq = MediaQuery.of(context);
                  final alturaDisponivel =
                      mq.size.height - mq.viewInsets.bottom - pos.dy - 8;
                  return Positioned(
                    left: pos.dx,
                    top: pos.dy,
                    width: width,
                    child: MediaQuery(
                      data: mq,
                      child: _DropdownString(
                        items: _availableHealthConditions,
                        colorScheme: colorScheme,
                        emptyMessage:
                            'Todas as condições já foram adicionadas.',
                        icon: Icons.monitor_heart_outlined,
                        onSelected: _selecionarCondicao,
                        maxHeight: alturaDisponivel.clamp(
                          120.0,
                          double.infinity,
                        ),
                      ),
                    ),
                  );
                },
                child: TextFormField(
                  key: _conditionFieldKey,
                  focusNode: _conditionFocusNode,
                  readOnly: true,
                  onTap: _toggleDropdownCondicao,
                  validator: (v) {
                    if (_selectedConditions.isEmpty) {
                      return 'Selecione ao menos uma condição';
                    }
                    return null;
                  },
                  enabled:
                      !_isLoading &&
                      _phoneController.text
                              .replaceAll(RegExp(r'\D'), '')
                              .length >=
                          10,
                  decoration: AppInputDecoration.build(
                    context,
                    labelText: 'Selecionar condição',
                    hintText: 'Toque para adicionar',
                    prefixIcon: Icon(
                      Icons.monitor_heart_outlined,
                      color: colorScheme.primary,
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _conditionDropdownAberto
                            ? Icons.arrow_drop_up
                            : Icons.arrow_drop_down,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      onPressed: _toggleDropdownCondicao,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              if (_selectedConditions.isNotEmpty)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _selectedConditions
                        .map(
                          (condition) => Chip(
                            label: Text(condition),
                            onDeleted: () {
                              setState(() {
                                _selectedConditions.remove(condition);
                              });
                              _stepKeys[0].currentState?.validate();
                            },
                          ),
                        )
                        .toList(),
                  ),
                ),
              const SizedBox(height: 32),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Contato de emergência (opcional)',
                  style: textTheme.titleSmall,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _emergencyNameController,
                focusNode: _emergencyNameFocusNode,
                validator: (v) {
                  final anyFilled =
                      _hasPartialEmergencyContact() ||
                      _emergencyPhoneController.text.isNotEmpty ||
                      _emergencyRelationshipController.text.isNotEmpty;
                  if (anyFilled && (v == null || v.trim().isEmpty)) {
                    return 'Informe o nome de contato';
                  }
                  return null;
                },
                decoration: AppInputDecoration.build(
                  context,
                  labelText: 'Nome do contato',
                ),
                enabled: !_isLoading && _selectedConditions.isNotEmpty,
                onChanged: (v) => setState(() {}),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _emergencyPhoneController,
                focusNode: _emergencyPhoneFocusNode,
                validator: (v) {
                  final anyFilled =
                      _hasPartialEmergencyContact() ||
                      _emergencyNameController.text.isNotEmpty ||
                      _emergencyRelationshipController.text.isNotEmpty;
                  if (anyFilled) {
                    final digits = v?.replaceAll(RegExp(r'\D'), '') ?? '';
                    if (digits.isEmpty) return 'Informe o telefone';
                    if (digits.length < 10) return 'Telefone inválido';
                  }
                  return null;
                },
                decoration: AppInputDecoration.build(
                  context,
                  labelText: 'Telefone do contato',
                  hintText: '(00) 00000-0000',
                ),
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(12),
                  PhoneInputFormatter(),
                ],
                enabled:
                    !_isLoading &&
                    _emergencyNameController.text.trim().isNotEmpty,
                onChanged: (v) => setState(() {}),
              ),
              const SizedBox(height: 12),
              OverlayPortal(
                controller: _relationshipOverlayController,
                overlayChildBuilder: (overlayContext) {
                  final layout = _calcularDropdownParentescoLayout(context);
                  final mq = MediaQuery.of(context);
                  return Positioned(
                    left:
                        (_relationshipFieldKey.currentContext
                                    ?.findRenderObject()
                                as RenderBox?)
                            ?.localToGlobal(Offset.zero)
                            .dx ??
                        0,
                    top: layout.top,
                    width: layout.width,
                    child: MediaQuery(
                      data: mq,
                      child: _DropdownString(
                        items: _relationshipOptions,
                        colorScheme: colorScheme,
                        emptyMessage: 'Nenhuma opção disponível.',
                        icon: Icons.people_outline,
                        onSelected: _selecionarParentesco,
                        maxHeight: layout.maxHeight,
                      ),
                    ),
                  );
                },
                child: TextFormField(
                  key: _relationshipFieldKey,
                  controller: _emergencyRelationshipController,
                  focusNode: _emergencyRelationshipFocusNode,
                  readOnly: true,
                  onTap: _toggleDropdownParentesco,
                  validator: (v) {
                    final anyFilled =
                        _hasPartialEmergencyContact() ||
                        _emergencyNameController.text.isNotEmpty ||
                        _emergencyPhoneController.text.isNotEmpty;
                    if (anyFilled && (v == null || v.trim().isEmpty)) {
                      return 'Informe o parentesco';
                    }
                    return null;
                  },
                  decoration: AppInputDecoration.build(
                    context,
                    labelText: 'Parentesco',
                    hintText: 'Toque para selecionar',
                    prefixIcon: Icon(
                      Icons.people_outline,
                      color: colorScheme.primary,
                    ),
                    suffixIcon: _selectedEmergencyRelationship != null
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              setState(() {
                                _selectedEmergencyRelationship = null;
                                _emergencyRelationshipController.clear();
                              });
                              _fecharDropdownParentesco();
                            },
                          )
                        : IconButton(
                            icon: Icon(
                              _relationshipDropdownAberto
                                  ? Icons.arrow_drop_up
                                  : Icons.arrow_drop_down,
                              color: colorScheme.onSurfaceVariant,
                            ),
                            onPressed: _toggleDropdownParentesco,
                          ),
                  ),
                  enabled:
                      !_isLoading &&
                      _emergencyPhoneController.text.length >= 14,
                ),
              ),
              const SizedBox(height: 32),
              Row(
                children: [
                  TextButton(
                    onPressed: _isLoading ? null : _handleCancel,
                    child: const Text('Cancelar'),
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: _isLoading ? null : _handleContinue,
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Próximo'),
                  ),
                ],
              ),
            ],
          ),
        );
      case 1:
        return Form(
          key: _stepKeys[1],
          child: Column(
            children: [
              const SizedBox(height: 24),
              Align(
                alignment: Alignment.centerLeft,
                child: Text('Endereço', style: textTheme.titleSmall),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _cepController,
                focusNode: _cepFocusNode,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(8),
                  CepInputFormatter(),
                ],
                onChanged: (value) => _buscarEnderecoPorCep(value),
                decoration: AppInputDecoration.build(
                  context,
                  labelText: 'CEP',
                  hintText: '00000-000',
                  prefixIcon: Icon(
                    Icons.local_post_office_outlined,
                    color: colorScheme.primary,
                  ),
                  suffixIcon: _carregandoCep
                      ? Padding(
                          padding: const EdgeInsets.all(12),
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: colorScheme.primary,
                            ),
                          ),
                        )
                      : (_cepController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  setState(() {
                                    _cepController.clear();
                                    _logradouroController.clear();
                                    _numeroController.clear();
                                    _complementoController.clear();
                                    _bairroController.clear();
                                    _estadoController.clear();
                                    _municipioController.clear();
                                    _erroCep = null;
                                    _ultimoCepBuscado = '';
                                  });
                                },
                              )
                            : null),
                ),
                validator: (value) {
                  final v = value?.replaceAll(RegExp(r'\D'), '') ?? '';
                  if (v.length != 8) return 'Informe um CEP válido';
                  return null;
                },
                enabled: !_isLoading,
              ),
              if (_erroCep != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.error_outline,
                      color: colorScheme.error,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_erroCep!)),
                  ],
                ),
              ],
              const SizedBox(height: 16),
              TextFormField(
                controller: _logradouroController,
                focusNode: _logradouroFocusNode,
                decoration: AppInputDecoration.build(
                  context,
                  labelText: 'Logradouro *',
                  hintText: 'Rua, avenida, etc.',
                  prefixIcon: Icon(
                    Icons.signpost_outlined,
                    color: colorScheme.primary,
                  ),
                ),
                enabled:
                    !_isLoading &&
                    _cepController.text.replaceAll(RegExp(r'\D'), '').length ==
                        8,
                onChanged: (v) => setState(() {}),
                validator: (value) {
                  if ((value ?? '').trim().isEmpty) {
                    return 'Informe o logradouro';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _numeroController,
                focusNode: _numeroFocusNode,
                keyboardType: TextInputType.number,
                decoration: AppInputDecoration.build(
                  context,
                  labelText: 'Número *',
                  hintText: 'Ex.: 123',
                  prefixIcon: Icon(
                    Icons.tag_outlined,
                    color: colorScheme.primary,
                  ),
                ),
                enabled:
                    !_isLoading && _logradouroController.text.trim().isNotEmpty,
                onChanged: (v) => setState(() {}),
                validator: (value) {
                  if ((value ?? '').trim().isEmpty) {
                    return 'Informe o número';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _complementoController,
                decoration: AppInputDecoration.build(
                  context,
                  labelText: 'Complemento',
                  hintText: 'Apartamento, bloco, etc.',
                  prefixIcon: Icon(
                    Icons.domain_add_outlined,
                    color: colorScheme.primary,
                  ),
                ),
                enabled:
                    !_isLoading && _numeroController.text.trim().isNotEmpty,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _bairroController,
                focusNode: _bairroFocusNode,
                decoration: AppInputDecoration.build(
                  context,
                  labelText: 'Bairro *',
                  hintText: 'Seu bairro',
                  prefixIcon: Icon(
                    Icons.location_on_outlined,
                    color: colorScheme.primary,
                  ),
                ),
                enabled:
                    !_isLoading && _numeroController.text.trim().isNotEmpty,
                onChanged: (v) => setState(() {}),
                validator: (value) {
                  if ((value ?? '').trim().isEmpty) {
                    return 'Informe o bairro';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              OverlayPortal(
                controller: _estadoOverlayController,
                overlayChildBuilder: (overlayContext) {
                  final (pos, width) = _calcularPosicaoDropdownEstado();
                  final mq = MediaQuery.of(context);
                  final alturaDisponivel =
                      mq.size.height - mq.viewInsets.bottom - pos.dy - 8;
                  return Positioned(
                    left: pos.dx,
                    top: pos.dy,
                    width: width,
                    child: MediaQuery(
                      data: mq,
                      child: _DropdownEstado(
                        estados: _estadosFiltrados,
                        colorScheme: colorScheme,
                        onSelected: _selecionarEstado,
                        maxHeight: alturaDisponivel.clamp(
                          120.0,
                          double.infinity,
                        ),
                      ),
                    ),
                  );
                },
                child: TextFormField(
                  key: _estadoFieldKey,
                  controller: _estadoController,
                  focusNode: _estadoFocusNode,
                  readOnly: !_estadoModoDigitacao,
                  onTap: _onEstadoTap,
                  enabled:
                      !_isLoading && _bairroController.text.trim().isNotEmpty,
                  validator: (v) {
                    if (_estadoSelecionado == null) return 'Informe a UF';
                    return null;
                  },
                  decoration: AppInputDecoration.build(
                    context,
                    labelText: 'UF *',
                    hintText: _estadoDropdownAberto && _estadoModoDigitacao
                        ? 'Digite para filtrar...'
                        : 'Toque para selecionar',
                    prefixIcon: Icon(
                      Icons.map_outlined,
                      color: colorScheme.primary,
                    ),
                    suffixIcon: _estadoSelecionado != null
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              setState(() {
                                _estadoSelecionado = null;
                                _estadosFiltrados = estadosBrasileiros;
                                _estadoModoDigitacao = false;
                                _municipioSelecionado = null;
                                _todosMunicipios = [];
                                _municipiosFiltrados = [];
                              });
                              _estadoController.clear();
                              _municipioController.clear();
                              _fecharDropdownEstado();
                            },
                          )
                        : IconButton(
                            icon: Icon(
                              _estadoDropdownAberto
                                  ? Icons.arrow_drop_up
                                  : Icons.arrow_drop_down,
                              color: colorScheme.onSurfaceVariant,
                            ),
                            onPressed: () {
                              if (_estadoDropdownAberto) {
                                _fecharDropdownEstado();
                              } else {
                                _onEstadoTap();
                              }
                            },
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (_estadoSelecionado != null) ...[
                OverlayPortal(
                  controller: _municipioOverlayController,
                  overlayChildBuilder: (overlayContext) {
                    final (pos, width) = _calcularPosicaoDropdownMunicipio();
                    final mq = MediaQuery.of(context);
                    final alturaDisponivel =
                        mq.size.height - mq.viewInsets.bottom - pos.dy - 8;
                    return Positioned(
                      left: pos.dx,
                      top: pos.dy,
                      width: width,
                      child: MediaQuery(
                        data: mq,
                        child: _DropdownMunicipio(
                          municipios: _municipiosFiltrados,
                          carregando: _carregandoMunicipios,
                          aguardando: _aguardandoMunicipios,
                          erro: _erroMunicipios,
                          colorScheme: colorScheme,
                          onSelected: _selecionarMunicipio,
                          onRetry: () =>
                              _buscarMunicipios(_estadoSelecionado!.sigla),
                          maxHeight: alturaDisponivel.clamp(
                            120.0,
                            double.infinity,
                          ),
                        ),
                      ),
                    );
                  },
                  child: TextFormField(
                    key: _municipioFieldKey,
                    controller: _municipioController,
                    focusNode: _municipioFocusNode,
                    readOnly: !_municipioModoDigitacao,
                    onTap: _onMunicipioTap,
                    validator: (v) {
                      if (_municipioSelecionado == null)
                        return 'Informe o município';
                      return null;
                    },
                    enabled: !_carregandoMunicipios && _erroMunicipios == null,
                    decoration: AppInputDecoration.build(
                      context,
                      labelText: 'Município *',
                      hintText: _carregandoMunicipios
                          ? 'Carregando municípios...'
                          : _municipioDropdownAberto && _municipioModoDigitacao
                          ? 'Digite para filtrar...'
                          : 'Toque para selecionar',
                      prefixIcon: Icon(
                        Icons.location_city,
                        color: colorScheme.primary,
                      ),
                      suffixIcon:
                          (_carregandoMunicipios || _aguardandoMunicipios)
                          ? Padding(
                              padding: const EdgeInsets.all(12),
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: colorScheme.primary,
                                ),
                              ),
                            )
                          : (!_aguardandoMunicipios &&
                                _municipioController.text.isNotEmpty)
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                setState(() {
                                  _municipioSelecionado = null;
                                  _municipioModoDigitacao = false;
                                  if (_estadoSelecionado != null &&
                                      _municipiosCache.containsKey(
                                        _estadoSelecionado!.sigla,
                                      )) {
                                    _todosMunicipios =
                                        _municipiosCache[_estadoSelecionado!
                                            .sigla]!;
                                    _municipiosFiltrados = _todosMunicipios;
                                    _carregandoMunicipios = false;
                                    _erroMunicipios = null;
                                  } else {
                                    _todosMunicipios = [];
                                    _municipiosFiltrados = [];
                                  }
                                });
                                _municipioController.clear();
                                _fecharDropdownMunicipio();
                              },
                            )
                          : IconButton(
                              icon: Icon(
                                _municipioDropdownAberto
                                    ? Icons.arrow_drop_up
                                    : Icons.arrow_drop_down,
                                color: colorScheme.onSurfaceVariant,
                              ),
                              onPressed: () {
                                if (_municipioDropdownAberto) {
                                  _fecharDropdownMunicipio();
                                } else {
                                  _onMunicipioTap();
                                }
                              },
                            ),
                    ),
                  ),
                ),
                if (_erroMunicipios != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.error_outline,
                        color: colorScheme.error,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: Text(_erroMunicipios!)),
                    ],
                  ),
                ],
              ],
              if (_municipioSelecionado != null) ...[
                const SizedBox(height: 16),
                OverlayPortal(
                  controller: _ubsOverlayController,
                  overlayChildBuilder: (overlayContext) {
                    final (pos, width) = _calcularPosicaoDropdownUbs();
                    final mq = MediaQuery.of(context);
                    final alturaDisponivel =
                        mq.size.height - mq.viewInsets.bottom - pos.dy - 8;
                    return Positioned(
                      left: pos.dx,
                      top: pos.dy,
                      width: width,
                      child: MediaQuery(
                        data: mq,
                        child: _DropdownUbs(
                          sugestoes: _ubsFiltradas,
                          carregando: _carregandoUbs,
                          colorScheme: colorScheme,
                          onSelected: _selecionarUbs,
                          maxHeight: alturaDisponivel.clamp(
                            120.0,
                            double.infinity,
                          ),
                        ),
                      ),
                    );
                  },
                  child: TextFormField(
                    key: _ubsFieldKey,
                    controller: _ubsController,
                    focusNode: _ubsFocusNode,
                    readOnly: !_ubsModoDigitacao,
                    onTap: _onUbsTap,
                    enabled:
                        !_carregandoUbs &&
                        _erroUbs == null &&
                        _todasUbs.isNotEmpty,
                    decoration: AppInputDecoration.build(
                      context,
                      labelText: 'UBS de Preferência (Opcional)',
                      hintText: _carregandoUbs
                          ? 'Buscando UBS...'
                          : (_todasUbs.isEmpty && _erroUbs == null)
                          ? 'Nenhuma UBS disponível'
                          : _ubsDropdownAberto && _ubsModoDigitacao
                          ? 'Digite para filtrar...'
                          : 'Toque para selecionar',
                      prefixIcon: Icon(
                        Icons.local_hospital,
                        color: colorScheme.primary,
                      ),
                      suffixIcon: _carregandoUbs
                          ? Padding(
                              padding: const EdgeInsets.all(12),
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: colorScheme.primary,
                                ),
                              ),
                            )
                          : (_ubsController.text.isNotEmpty)
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                setState(() {
                                  _ubsSelecionada = null;
                                  _ubsController.clear();
                                  _ubsFiltradas = _todasUbs;
                                });
                                _fecharDropdownUbs();
                              },
                            )
                          : IconButton(
                              icon: Icon(
                                _ubsDropdownAberto
                                    ? Icons.arrow_drop_up
                                    : Icons.arrow_drop_down,
                                color: colorScheme.onSurfaceVariant,
                              ),
                              onPressed: () {
                                if (_ubsDropdownAberto) {
                                  _fecharDropdownUbs();
                                } else {
                                  _onUbsTap(fromArrow: true);
                                }
                              },
                            ),
                    ),
                  ),
                ),
                if (_erroUbs != null ||
                    (!_carregandoUbs && _todasUbs.isEmpty)) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        _erroUbs != null
                            ? Icons.error_outline
                            : Icons.info_outline,
                        color: _erroUbs != null
                            ? colorScheme.error
                            : colorScheme.onSurfaceVariant,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _erroUbs ??
                              'Nenhuma UBS encontrada para esta cidade. Você poder adicioná-la posteriormente no seu perfil.',
                          style: TextStyle(
                            color: _erroUbs != null
                                ? colorScheme.error
                                : colorScheme.onSurfaceVariant,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
              const SizedBox(height: 32),
              Row(
                children: [
                  TextButton(
                    onPressed: _isLoading
                        ? null
                        : () => setState(() => _currentStep = 0),
                    child: const Text('Voltar'),
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: _isLoading ? null : _handleContinue,
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Próximo'),
                  ),
                ],
              ),
            ],
          ),
        );
      case 2:
        return Form(
          key: _stepKeys[2],
          child: Column(
            children: [
              const SizedBox(height: 24),
              Align(
                alignment: Alignment.centerLeft,
                child: Text('Dados de acesso', style: textTheme.titleSmall),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _cpfController,
                focusNode: _cpfFocusNode,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(12),
                  CpfInputFormatter(),
                ],
                decoration: AppInputDecoration.build(
                  context,
                  labelText: 'CPF',
                  hintText: '000.000.000-00',
                  prefixIcon: Icon(
                    Icons.badge_outlined,
                    color: colorScheme.primary,
                  ),
                ).copyWith(errorText: _cpfBackendError),
                onChanged: (v) {
                  setState(() {
                    if (_cpfBackendError != null) _cpfBackendError = null;
                  });
                },
                validator: (value) {
                  if (_cpfBackendError != null) {
                    return _cpfBackendError;
                  }
                  final v = value?.replaceAll(RegExp(r'\D'), '') ?? '';
                  if (v.length != 11) return 'Informe um CPF com 11 dígitos';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                focusNode: _passwordFocusNode,
                obscureText: !_showPassword,
                decoration: AppInputDecoration.build(
                  context,
                  labelText: 'Senha',
                  prefixIcon: Icon(
                    Icons.lock_outline,
                    color: colorScheme.primary,
                  ),
                  suffixIcon: IconButton(
                    tooltip: _showPassword ? 'Ocultar senha' : 'Ver senha',
                    icon: Icon(
                      _showPassword ? Icons.visibility_off : Icons.visibility,
                    ),
                    onPressed: () =>
                        setState(() => _showPassword = !_showPassword),
                  ),
                ),
                enabled:
                    !_isLoading &&
                    _cpfController.text.replaceAll(RegExp(r'\D'), '').length ==
                        11,
                onChanged: (v) => setState(() {}),
                validator: (value) {
                  if ((value ?? '').length < 6) {
                    return 'Use pelo menos 6 caracteres';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _confirmPasswordController,
                focusNode: _confirmPasswordFocusNode,
                obscureText: !_showConfirmPassword,
                decoration: AppInputDecoration.build(
                  context,
                  labelText: 'Confirmar senha',
                  prefixIcon: Icon(
                    Icons.lock_outline,
                    color: colorScheme.primary,
                  ),
                  suffixIcon: IconButton(
                    tooltip: _showConfirmPassword
                        ? 'Ocultar senha'
                        : 'Ver senha',
                    icon: Icon(
                      _showConfirmPassword
                          ? Icons.visibility_off
                          : Icons.visibility,
                    ),
                    onPressed: () => setState(
                      () => _showConfirmPassword = !_showConfirmPassword,
                    ),
                  ),
                ),
                enabled: !_isLoading && _passwordController.text.length >= 6,
                onChanged: (v) => setState(() {}),
                validator: (value) {
                  if (value != _passwordController.text) {
                    return 'As senhas não coincidem';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 32),
              Row(
                children: [
                  TextButton(
                    onPressed: _isLoading
                        ? null
                        : () => setState(() => _currentStep = 1),
                    child: const Text('Voltar'),
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: _isLoading ? null : _handleContinue,
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Finalizar cadastro'),
                  ),
                ],
              ),
            ],
          ),
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Future<void> _submit() async {
    final app = context.read<AppState>();

    final diseases = _selectedDiseases();

    setState(() => _isLoading = true);
    try {
      await app.signUpWithCpfPassword(
        cpf: _cpfController.text,
        password: _passwordController.text,
        name: _nameController.text,
        birthDate: _birthDateController.text,
        gender: _genderController.text,
        diseases: diseases,
        phone: _phoneController.text,
        email: _emailController.text,
        emergencyContactName: _emergencyNameController.text,
        emergencyContactPhone: _emergencyPhoneController.text,
        emergencyContactRelationship: _emergencyRelationshipController.text,
        uf: _estadoSelecionado?.sigla,
        municipioIbge: _municipioSelecionado?.codigoMunicipio.toString(),
        ubsCnes: _ubsSelecionada?.codigoCnes.toString(),
        zipCode: _cepController.text,
        street: _logradouroController.text,
        number: _numeroController.text,
        neighborhood: _bairroController.text,
        complement: _complementoController.text,
      );
      if (!mounted) return;
      AppSnackBar.showSuccess(context, 'Cadastro realizado com sucesso!');
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      final msg = _extractErrorMessage(e);
      if (msg.toLowerCase().contains('cpf')) {
        setState(() {
          _currentStep = 2; // Access is now Step 2
          _cpfBackendError = 'CPF já cadastrado';
        });
        _showErrorSnackBar(msg);
        // Delay focus request slightly to ensure step animation completes
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted) _cpfFocusNode.requestFocus();
        });
      } else {
        _showErrorSnackBar(e);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleContinue() async {
    final currentKey = _stepKeys[_currentStep];
    if (!(currentKey.currentState?.validate() ?? false)) {
      _focusFirstInvalidField();
      return;
    }

    if (_currentStep == 0 || _currentStep == 1) {
      setState(() => _currentStep++);
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      return;
    }

    if (_currentStep == 2) {
      final app = context.read<AppState>();
      setState(() => _isLoading = true);
      try {
        final exists = await app.cpfExists(_cpfController.text);
        if (!mounted) return;
        if (exists) {
          setState(() {
            _cpfBackendError = 'CPF já cadastrado';
          });
          _showErrorSnackBar(
            'CPF já cadastrado. Faça login ou recupere a senha.',
          );
          _cpfFocusNode.requestFocus();
          return;
        }
        await _submit();
      } catch (e) {
        if (!mounted) return;
        final msg = _extractErrorMessage(e);
        setState(() {
          _cpfBackendError = 'CPF inválido';
        });
        _showErrorSnackBar(msg);
        _cpfFocusNode.requestFocus();
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  void _handleCancel() {
    if (_currentStep == 0) {
      Navigator.of(context).pop();
      return;
    }
    setState(() => _currentStep--);
  }

  Future<bool> _onWillPop() async {
    if (_estadoDropdownAberto ||
        _municipioDropdownAberto ||
        _ubsDropdownAberto ||
        _genderDropdownAberto ||
        _conditionDropdownAberto ||
        _relationshipDropdownAberto) {
      if (_estadoDropdownAberto) _fecharDropdownEstado();
      if (_municipioDropdownAberto) _fecharDropdownMunicipio();
      if (_ubsDropdownAberto) _fecharDropdownUbs();
      if (_genderDropdownAberto) _fecharDropdownGenero();
      if (_conditionDropdownAberto) _fecharDropdownCondicao();
      if (_relationshipDropdownAberto) _fecharDropdownParentesco();
      return true;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await _onWillPop();
        if (shouldPop && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Cadastro')),
        body: GestureDetector(
          onTap: () {
            FocusScope.of(context).unfocus();
            _fecharDropdownEstado();
            _fecharDropdownMunicipio();
            _fecharDropdownGenero();
            _fecharDropdownCondicao();
            _fecharDropdownParentesco();
          },
          behavior: HitTestBehavior.opaque,
          child: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24.0,
                    vertical: 16.0,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 8),
                      Expanded(
                        child: SingleChildScrollView(
                          controller: _scrollController,
                          child: Column(
                            children: [
                              _buildStepContent(colorScheme, textTheme),
                              SizedBox(
                                height: _relationshipDropdownAberto
                                    ? (_relationshipOptions.length * 44.0)
                                    : _ubsDropdownAberto
                                    ? (_ubsFiltradas.isEmpty
                                              ? 70.0
                                              : (_ubsFiltradas.length * 64.0))
                                          .clamp(0.0, 300.0)
                                    : 0.0,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DropdownString extends StatelessWidget {
  final List<String> items;
  final ColorScheme colorScheme;
  final String emptyMessage;
  final IconData icon;
  final ValueChanged<String> onSelected;
  final double maxHeight;

  const _DropdownString({
    required this.items,
    required this.colorScheme,
    required this.emptyMessage,
    required this.icon,
    required this.onSelected,
    required this.maxHeight,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 6,
      borderRadius: BorderRadius.circular(8),
      color: colorScheme.surface,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: items.isEmpty ? _buildVazio(context) : _buildLista(context),
      ),
    );
  }

  Widget _buildVazio(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Icon(Icons.search_off, color: colorScheme.onSurfaceVariant, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              emptyMessage,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLista(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: ListView.separated(
        padding: EdgeInsets.zero,
        shrinkWrap: true,
        itemCount: items.length,
        separatorBuilder: (_, __) =>
            Divider(height: 1, color: colorScheme.outlineVariant),
        itemBuilder: (context, index) {
          final item = items[index];
          return InkWell(
            onTap: () => onSelected(item),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
              child: Row(
                children: [
                  Icon(icon, color: colorScheme.primary, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      item,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _DropdownEstado extends StatelessWidget {
  final List<EstadoBrasileiro> estados;
  final ColorScheme colorScheme;
  final ValueChanged<EstadoBrasileiro> onSelected;
  final double maxHeight;

  const _DropdownEstado({
    required this.estados,
    required this.colorScheme,
    required this.onSelected,
    required this.maxHeight,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 6,
      borderRadius: BorderRadius.circular(8),
      color: colorScheme.surface,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: estados.isEmpty ? _buildVazio(context) : _buildLista(context),
      ),
    );
  }

  Widget _buildVazio(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Icon(Icons.search_off, color: colorScheme.onSurfaceVariant, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Nenhum estado encontrado.\nTente outro termo de busca.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLista(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: ListView.separated(
        padding: EdgeInsets.zero,
        shrinkWrap: true,
        itemCount: estados.length,
        separatorBuilder: (_, __) =>
            Divider(height: 1, color: colorScheme.outlineVariant),
        itemBuilder: (context, index) {
          final estado = estados[index];
          return InkWell(
            onTap: () => onSelected(estado),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
              child: Row(
                children: [
                  Icon(
                    Icons.map_outlined,
                    color: colorScheme.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${estado.sigla} - ${estado.nome}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _DropdownMunicipio extends StatelessWidget {
  final List<Municipio> municipios;
  final bool carregando;
  final bool aguardando;
  final String? erro;
  final ColorScheme colorScheme;
  final ValueChanged<Municipio> onSelected;
  final VoidCallback onRetry;
  final double maxHeight;

  const _DropdownMunicipio({
    required this.municipios,
    required this.carregando,
    required this.aguardando,
    required this.erro,
    required this.colorScheme,
    required this.onSelected,
    required this.onRetry,
    required this.maxHeight,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 6,
      borderRadius: BorderRadius.circular(8),
      color: colorScheme.surface,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: carregando
            ? _buildLoading(context)
            : erro != null
            ? _buildErro(context)
            : municipios.isEmpty
            ? (aguardando ? _buildWaiting(context) : _buildVazio(context))
            : _buildLista(context),
      ),
    );
  }

  Widget _buildWaiting(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'Aguardando resposta...',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoading(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'Carregando municípios...',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErro(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: colorScheme.error, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Erro ao carregar',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('Tentar novamente')),
        ],
      ),
    );
  }

  Widget _buildVazio(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Icon(Icons.search_off, color: colorScheme.onSurfaceVariant, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Nenhum município encontrado.\nTente outro termo de busca.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLista(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: ListView.separated(
        padding: EdgeInsets.zero,
        shrinkWrap: true,
        itemCount: municipios.length,
        separatorBuilder: (_, __) =>
            Divider(height: 1, color: colorScheme.outlineVariant),
        itemBuilder: (context, index) {
          final municipio = municipios[index];
          return InkWell(
            onTap: () => onSelected(municipio),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
              child: Row(
                children: [
                  Icon(
                    Icons.location_city_outlined,
                    color: colorScheme.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      municipio.nome,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _DropdownUbs extends StatelessWidget {
  final List<CnesEstabelecimento> sugestoes;
  final bool carregando;
  final ColorScheme colorScheme;
  final ValueChanged<CnesEstabelecimento> onSelected;
  final double maxHeight;

  const _DropdownUbs({
    required this.sugestoes,
    required this.carregando,
    required this.colorScheme,
    required this.onSelected,
    required this.maxHeight,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 6,
      borderRadius: BorderRadius.circular(8),
      color: colorScheme.surface,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: carregando
            ? _buildLoading(context)
            : sugestoes.isEmpty
            ? _buildVazio(context)
            : _buildLista(context),
      ),
    );
  }

  Widget _buildLoading(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'Buscando UBS...',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVazio(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Icon(Icons.search_off, color: colorScheme.onSurfaceVariant, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Nenhuma UBS encontrada para este município.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLista(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: ListView.separated(
        padding: EdgeInsets.zero,
        shrinkWrap: true,
        itemCount: sugestoes.length,
        separatorBuilder: (_, __) =>
            Divider(height: 1, color: colorScheme.outlineVariant),
        itemBuilder: (context, index) {
          final est = sugestoes[index];
          return InkWell(
            onTap: () => onSelected(est),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  Icon(
                    Icons.local_hospital_outlined,
                    color: colorScheme.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          formatCnesDisplayName(est.nomeFantasia),
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: colorScheme.onSurface,
                                fontWeight: FontWeight.w500,
                              ),
                        ),
                        if (est.endereco.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            est.endereco,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: colorScheme.onSurfaceVariant),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
