import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/providers/accessibility_provider.dart';
import '../../core/services/notification_service.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _hasExactAlarmPermission = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkPermission();
  }

  Future<void> _checkPermission() async {
    final hasPermission = await NotificationService.instance
        .hasExactAlarmPermission();
    if (mounted) {
      setState(() {
        _hasExactAlarmPermission = hasPermission;
        _isLoading = false;
      });
    }
  }

  Future<void> _requestPermission() async {
    await NotificationService.instance.requestExactAlarmPermission();
    // Recarrega o status após solicitar
    await _checkPermission();
    if (mounted && _hasExactAlarmPermission) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          duration: const Duration(seconds: 2),
          content: Row(
            children: [
              Icon(
                Icons.check_circle_outline,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Permissão de alarmes concedida',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final accessibility = context.watch<AccessibilityProvider>();
    final scale = accessibility.factor;

    return Scaffold(
      appBar: AppBar(title: const Text('Configurações')),
      body: ListView(
        padding: EdgeInsets.all(16 * scale),
        children: [
          // ─── Seção: Acessibilidade ───────────────────────────────
          const Text(
            'Acessibilidade',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 12 * scale),
          Card(
            child: Padding(
              padding: EdgeInsets.all(16 * scale),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.accessibility_new,
                        color: accessibility.isAccessibilityMode
                            ? Colors.teal
                            : Colors.grey,
                      ),
                      SizedBox(width: 12 * scale),
                      const Expanded(
                        child: Text(
                          'Modo Acessibilidade',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8 * scale),
                  Text(
                    'Aumenta o tamanho dos textos, botões e ícones para facilitar a leitura e interação.',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 14,
                    ),
                  ),
                  SizedBox(height: 16 * scale),
                  // Seletor de escala
                  ...AccessibilityScale.values.map((option) {
                    final isSelected = accessibility.scale == option;
                    final colorScheme = Theme.of(context).colorScheme;
                    return Padding(
                      padding: EdgeInsets.only(bottom: 8 * scale),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => accessibility.setScale(option),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: EdgeInsets.symmetric(
                            horizontal: 16 * scale,
                            vertical: 12 * scale,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? colorScheme.primaryContainer
                                : colorScheme.surfaceContainerHighest,
                            border: Border.all(
                              color: isSelected
                                  ? colorScheme.primary
                                  : colorScheme.outline,
                              width: isSelected ? 2 : 1,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                isSelected
                                    ? Icons.radio_button_checked
                                    : Icons.radio_button_off,
                                color: isSelected
                                    ? colorScheme.primary
                                    : colorScheme.onSurfaceVariant,
                              ),
                              SizedBox(width: 12 * scale),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      option.label,
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: isSelected
                                            ? FontWeight.bold
                                            : FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      _scaleDescription(option),
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Preview: texto Aa em tamanho escalado
                              Text(
                                'Aa',
                                style: TextStyle(
                                  fontSize: 18 * option.factor,
                                  fontWeight: FontWeight.bold,
                                  color: isSelected
                                      ? colorScheme.primary
                                      : colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
          SizedBox(height: 24 * scale),

          // ─── Seção: Notificações ─────────────────────────────────
          const Text(
            'Notificações',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 12 * scale),
          Card(
            child: Padding(
              padding: EdgeInsets.all(16 * scale),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.alarm,
                        color: _isLoading
                            ? Colors.grey
                            : (_hasExactAlarmPermission
                                  ? Colors.green
                                  : Colors.orange),
                      ),
                      SizedBox(width: 12 * scale),
                      const Expanded(
                        child: Text(
                          'Lembretes de medicamentos',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (_isLoading)
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      else
                        Chip(
                          label: Text(
                            _hasExactAlarmPermission ? 'Ativo' : 'Inativo',
                          ),
                          backgroundColor: _hasExactAlarmPermission
                              ? Colors.green.shade50
                              : Colors.orange.shade50,
                          labelStyle: TextStyle(
                            color: _hasExactAlarmPermission
                                ? Colors.green.shade700
                                : Colors.orange.shade700,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                  SizedBox(height: 8 * scale),
                  Text(
                    _hasExactAlarmPermission
                        ? 'O app tem permissão para enviar lembretes nos horários exatos dos seus medicamentos.'
                        : 'Para receber lembretes nos horários corretos, é necessário conceder permissão de alarmes exatos.',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 14,
                    ),
                  ),
                  if (!_hasExactAlarmPermission && !_isLoading) ...[
                    SizedBox(height: 12 * scale),
                    FilledButton.icon(
                      onPressed: _requestPermission,
                      icon: const Icon(Icons.settings),
                      label: const Text('Conceder permissão'),
                    ),
                  ],
                ],
              ),
            ),
          ),
          SizedBox(height: 24 * scale),

          // ─── Seção: Sobre ────────────────────────────────────────
          const Text(
            'Sobre',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 12 * scale),
          Card(
            child: Padding(
              padding: EdgeInsets.all(16 * scale),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'HiperDiário',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Aplicativo para controle de medicamentos e acompanhamento de hipertensão.',
                    style: TextStyle(fontSize: 14),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _scaleDescription(AccessibilityScale scale) {
    return switch (scale) {
      AccessibilityScale.normal => 'Tamanho padrão de textos e elementos',
      AccessibilityScale.grande =>
        'Textos e botões 30% maiores – recomendado para leitura confortável',
      AccessibilityScale.extraGrande =>
        'Textos e botões 60% maiores – ideal para baixa visão',
    };
  }
}
