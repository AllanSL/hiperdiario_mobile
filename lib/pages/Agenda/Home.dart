import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import '../../core/services/notification_service.dart';

import '../../state/app_state.dart';
import '../../core/providers/theme_provider.dart';
import 'Consultas.dart';
import 'HistoricoConsultas.dart';
import '../Medicamentos/Medicamentos.dart';
import '../Perfil/Perfil.dart';
import '../Medicamentos/NovoMedicamento.dart';
import 'NovaConsulta.dart';
import '../Perfil/Configuracoes.dart';
import '../Dicas/DicasSaude.dart';

// Classes exportadas de profile_page.dart
export '../Perfil/Perfil.dart'
    show EditPersonalContactsPage, EditEmergencyContactPage, QrProfilePage;

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _index = 0;
  late final PageController _pageController;
  double _currentPage = 0.0;
  Timer? _medFabTimer;
  Timer? _appointmentFabTimer;
  bool _canShowMedFab = false;
  bool _canShowAppointmentFab = false;
  static const Duration _fabDebounce = Duration(milliseconds: 150);
  // Bloqueio de navegação para evitar spam de cliques nas guias
  bool _isNavigating = false;
  Timer? _navigationReleaseTimer;
  StreamSubscription<String>? _notificationResponseSub;
  String? _pendingLaunchPayload;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _index, keepPage: true);
    _currentPage = _index.toDouble();
    _pageController.addListener(_onPageControllerScroll);
    _canShowMedFab = _index == 1;
    _canShowAppointmentFab = _index == 2;
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateFabVisibility());
    // Inscreve-se nas respostas de notificações (quando o usuário interage)
    _notificationResponseSub = NotificationService
        .instance
        .onNotificationResponse
        .listen((payload) {
          if (!mounted) return;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _onNotificationPayloadReceived(payload);
          });
        });

    // Trata o payload de notificação que abriu o app a partir do estado finalizado.
    _pendingLaunchPayload = NotificationService.instance
        .popLaunchNotificationPayload();
    if (_pendingLaunchPayload != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _processPendingLaunchPayload();
      });
    }
  }

  @override
  void dispose() {
    _medFabTimer?.cancel();
    _appointmentFabTimer?.cancel();
    _navigationReleaseTimer?.cancel();
    _notificationResponseSub?.cancel();
    _pageController.removeListener(_onPageControllerScroll);
    _pageController.dispose();
    super.dispose();
  }

  void _onNotificationPayloadReceived(String payload) async {
    final medIds = <String>{};

    try {
      final data = jsonDecode(payload) as Map<String, dynamic>;
      if (data['type'] == 'med_reminder') {
        if (data['medIds'] is List) {
          for (final item in data['medIds'] as List) {
            if (item != null) medIds.add(item.toString());
          }
        }
        if (data['medId'] != null) {
          medIds.add(data['medId']!.toString());
        }
      }
    } catch (_) {
      final reg = RegExp(r'"medId"\s*:\s*"([^\"]+)"');
      final match = reg.firstMatch(payload);
      if (match != null && match.groupCount >= 1) medIds.add(match.group(1)!);
    }

    if (medIds.isEmpty) return;

    _navigateToMedicationsPage();
    final appState = context.read<AppState>();
    final meds = appState.medications
        .where((m) => medIds.contains(m.id))
        .toList();
    if (meds.isEmpty) return;

    if (!mounted) return;

    final selected = Map<String, bool>.fromEntries(
      meds.map((m) => MapEntry(m.id, true)),
    );

    final confirmedIds = await showDialog<List<String>>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setState) {
            return AlertDialog(
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 24.0,
              ),
              title: Text(
                meds.length == 1
                    ? 'Tomou seu remédio?'
                    : 'Tomou seus remédios?',
              ),
              content: SizedBox(
                width: MediaQuery.of(ctx).size.width * 0.92,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(ctx).size.height * 0.65,
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: meds.map((m) {
                        return CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          value: selected[m.id] ?? true,
                          onChanged: (value) {
                            setState(() {
                              selected[m.id] = value ?? false;
                            });
                          },
                          title: Text(
                            '${m.name} ${_extractDoseLabel(m.dosage)}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            softWrap: true,
                          ),
                          controlAffinity: ListTileControlAffinity.leading,
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(null),
                  child: const Text('Sair'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final selectedIds = meds
                        .where((m) => selected[m.id] == true)
                        .map((m) => m.id)
                        .toList();
                    Navigator.of(ctx).pop(selectedIds);
                  },
                  child: const Text('Tomei'),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmedIds == null || confirmedIds.isEmpty) return;

    await Future.wait(
      confirmedIds.map((id) => appState.decrementMedicationStock(id, by: 1)),
    );
  }

  Future<void> _processPendingLaunchPayload() async {
    if (_pendingLaunchPayload == null) return;

    const maxAttempts = 12;
    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      if (!mounted) return;
      final meds = context.read<AppState>().medications;
      if (meds.isNotEmpty) {
        _onNotificationPayloadReceived(_pendingLaunchPayload!);
        _pendingLaunchPayload = null;
        return;
      }
      await Future.delayed(const Duration(milliseconds: 500));
    }

    // Tenta uma última vez antes de descartar.
    if (!mounted) return;
    if (context.read<AppState>().medications.isNotEmpty &&
        _pendingLaunchPayload != null) {
      _navigateToMedicationsPage();
      _onNotificationPayloadReceived(_pendingLaunchPayload!);
    }
    _pendingLaunchPayload = null;
  }

  void _navigateToMedicationsPage() {
    if (_pageController.hasClients) {
      _pageController.jumpToPage(1);
    }
    if (_index != 1) {
      setState(() {
        _index = 1;
        _currentPage = 1.0;
        _canShowMedFab = true;
        _canShowAppointmentFab = false;
      });
    }
  }

  String _extractDoseLabel(String dosage) {
    final doseRegex = RegExp(
      r'(\d+(?:[.,]\d+)?)\s*(mg|g|ml|mcg|µg|iu|unidades|comprimad[oa]s?|cápsulas?)',
      caseSensitive: false,
    );
    final match = doseRegex.firstMatch(dosage);
    if (match != null) {
      return '${match.group(1)!.trim()} ${match.group(2)!.toLowerCase()}';
    }
    return dosage.trim();
  }

  void _onPageControllerScroll() {
    if (!_pageController.hasClients) return;
    final page = _pageController.page ?? _currentPage;
    // Evita rebuilds excessivos: atualiza apenas quando houver diferença significativa
    if ((page - _currentPage).abs() > 0.0001) {
      setState(() => _currentPage = page);
      _updateFabVisibility();
    }

    // Se estivermos navegando por clique, libera o bloqueio quando a página
    // estiver suficientemente visível/estável (usa debounce para estabilidade)
    if (_isNavigating) {
      if (_isPageFullyVisible(_index)) {
        _navigationReleaseTimer ??= Timer(_fabDebounce, () {
          _navigationReleaseTimer = null;
          if (_isPageFullyVisible(_index) && mounted) {
            setState(() => _isNavigating = false);
          }
        });
      } else {
        _navigationReleaseTimer?.cancel();
        _navigationReleaseTimer = null;
      }
    }
  }

  bool _isPageFullyVisible(int pageIndex) {
    if (!_pageController.hasClients) return _index == pageIndex;
    // Considera a página visível apenas quando a posição estiver muito próxima
    // do índice inteiro (ajuste o threshold se necessário)
    return (_currentPage - pageIndex).abs() < 0.4;
  }

  void _updateFabVisibility() {
    // Medication FAB debounce
    if (_isPageFullyVisible(1)) {
      if (!_canShowMedFab && _medFabTimer == null) {
        _medFabTimer = Timer(_fabDebounce, () {
          _medFabTimer = null;
          if (_isPageFullyVisible(1)) {
            setState(() => _canShowMedFab = true);
          }
        });
      }
    } else {
      _medFabTimer?.cancel();
      _medFabTimer = null;
      if (_canShowMedFab) setState(() => _canShowMedFab = false);
    }

    // Appointment FAB debounce
    if (_isPageFullyVisible(2)) {
      if (!_canShowAppointmentFab && _appointmentFabTimer == null) {
        _appointmentFabTimer = Timer(_fabDebounce, () {
          _appointmentFabTimer = null;
          if (_isPageFullyVisible(2)) {
            setState(() => _canShowAppointmentFab = true);
          }
        });
      }
    } else {
      _appointmentFabTimer?.cancel();
      _appointmentFabTimer = null;
      if (_canShowAppointmentFab)
        setState(() => _canShowAppointmentFab = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = const [ProfilePage(), MedicationsPage(), AppointmentsPage()];
    const appTitle = 'HiperDiário';
    return Scaffold(
      appBar: AppBar(
        title: const Text(appTitle),
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.menu),
            tooltip: 'Menu',
            onPressed: () {
              final scaffold = Scaffold.of(ctx);
              if (scaffold.hasDrawer && scaffold.isDrawerOpen) {
                scaffold.closeDrawer();
              } else {
                scaffold.openDrawer();
              }
            },
          ),
        ),
        elevation: 0,
        scrolledUnderElevation: 0.0,
        // Mantém a cor estável sem aplicar "tint" ao rolar
        surfaceTintColor: Colors.transparent,
        backgroundColor: Theme.of(context).colorScheme.surface,
        shadowColor: Colors.transparent,
        actions: [
          Consumer<ThemeProvider>(
            builder: (context, themeProvider, _) {
              final isDark = themeProvider.isDark(context);
              return IconButton(
                tooltip: isDark
                    ? 'Mudar para tema claro'
                    : 'Mudar para tema escuro',
                icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode),
                onPressed: () => themeProvider.toggle(context),
              );
            },
          ),
          if (_canShowMedFab)
            Tooltip(
              message: 'Ajustar dias para aviso de estoque baixo',
              child: IconButton(
                tooltip: 'Configurar alerta de estoque',
                onPressed: () => _configureLowStock(context),
                icon: const Icon(Icons.notifications_active),
              ),
            ),
          if (_canShowMedFab)
            Tooltip(
              message: 'Atualizar medicamentos da UBS',
              child: IconButton(
                tooltip: 'Atualizar medicamentos da UBS',
                onPressed: () async {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      behavior: SnackBarBehavior.floating,
                      margin: const EdgeInsets.all(16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      backgroundColor: Theme.of(
                        context,
                      ).colorScheme.primaryContainer,
                      duration: const Duration(seconds: 2),
                      content: Row(
                        children: [
                          Icon(
                            Icons.sync,
                            color: Theme.of(
                              context,
                            ).colorScheme.onPrimaryContainer,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Buscando atualizações na UBS',
                              style: TextStyle(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onPrimaryContainer,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                  await context.read<AppState>().syncUbsData();
                },
                icon: const Icon(Icons.sync),
              ),
            ),
          if (_canShowAppointmentFab)
            Tooltip(
              message: 'Atualizar consultas',
              child: IconButton(
                tooltip: 'Atualizar consultas',
                onPressed: () async {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      behavior: SnackBarBehavior.floating,
                      margin: const EdgeInsets.all(16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      backgroundColor: Theme.of(
                        context,
                      ).colorScheme.primaryContainer,
                      duration: const Duration(seconds: 2),
                      content: Row(
                        children: [
                          Icon(
                            Icons.sync,
                            color: Theme.of(
                              context,
                            ).colorScheme.onPrimaryContainer,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Buscando atualizações na UBS',
                              style: TextStyle(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onPrimaryContainer,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                  await context.read<AppState>().syncUbsData();
                },
                icon: const Icon(Icons.sync),
              ),
            ),
        ],
      ),
      drawer: Drawer(
        child: SafeArea(
          child: ListView(
            children: [
              ListTile(
                leading: const Icon(Icons.menu),
                title: const Text('Menu'),
                onTap: () {
                  Navigator.of(context).pop();
                },
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.settings),
                title: const Text('Configurações'),
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SettingsPage()),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.favorite),
                title: const Text('Dicas de saúde'),
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const HealthTipsPage()),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.history),
                title: const Text('Histórico de Consultas'),
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const AppointmentHistoryPage(),
                    ),
                  );
                },
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.qr_code),
                title: const Text('Compartilhar perfil (QR)'),
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const QrProfilePage()),
                  );
                },
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.logout),
                title: const Text('Sair'),
                onTap: () async {
                  await _logout(context);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        behavior: SnackBarBehavior.floating,
                        margin: const EdgeInsets.all(16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        backgroundColor: Theme.of(context).colorScheme.error,
                        duration: const Duration(seconds: 2),
                        content: Row(
                          children: [
                            Icon(
                              Icons.logout,
                              color: Theme.of(context).colorScheme.onError,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Sessão encerrada',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.onError,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                },
              ),
            ],
          ),
        ),
      ),
      body: PageView(
        controller: _pageController,
        onPageChanged: (i) {
          setState(() {
            _index = i;
            _currentPage = i.toDouble();
            // Página confirmada: cancelar timers e atualizar flags imediatamente
            _medFabTimer?.cancel();
            _medFabTimer = null;
            _appointmentFabTimer?.cancel();
            _appointmentFabTimer = null;
            _canShowMedFab = (i == 1);
            _canShowAppointmentFab = (i == 2);
          });
          // Libera o bloqueio de navegação após um pequeno debounce para
          // garantir que a página destino esteja estável/visível
          _navigationReleaseTimer?.cancel();
          _navigationReleaseTimer = Timer(_fabDebounce, () {
            _navigationReleaseTimer = null;
            if (mounted) setState(() => _isNavigating = false);
          });
        },
        children: pages,
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Offstage(
            offstage: !_canShowMedFab,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FloatingActionButton.extended(
                  heroTag: 'btnAddMed',
                  onPressed: () async {
                    final result = await Navigator.of(context).push<String>(
                      MaterialPageRoute(
                        builder: (_) => const AddMedicationPage(),
                      ),
                    );
                    if (!mounted) return;
                    if (result == 'added') {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          behavior: SnackBarBehavior.floating,
                          margin: const EdgeInsets.all(16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.primaryContainer,
                          duration: const Duration(seconds: 2),
                          content: Row(
                            children: [
                              Icon(
                                Icons.check_circle_outline,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onPrimaryContainer,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Medicamento adicionado com sucesso',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onPrimaryContainer,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Adicionar medicamento'),
                ),
              ],
            ),
          ),
          Offstage(
            offstage: !_canShowAppointmentFab,
            child: FloatingActionButton.extended(
              heroTag: 'btnAddAppointment',
              onPressed: () async {
                final result = await Navigator.of(context).push<String>(
                  MaterialPageRoute(builder: (_) => const AddAppointmentPage()),
                );
                if (!mounted) return;
                if (result == 'added') {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      behavior: SnackBarBehavior.floating,
                      margin: const EdgeInsets.all(16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      backgroundColor: Theme.of(
                        context,
                      ).colorScheme.primaryContainer,
                      duration: const Duration(seconds: 2),
                      content: Row(
                        children: [
                          Icon(
                            Icons.check_circle_outline,
                            color: Theme.of(
                              context,
                            ).colorScheme.onPrimaryContainer,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Consulta agendada com sucesso',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onPrimaryContainer,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }
              },
              icon: const Icon(Icons.add),
              label: const Text('Nova consulta'),
            ),
          ),
        ],
      ),
      bottomNavigationBar: AbsorbPointer(
        absorbing: _isNavigating,
        child: NavigationBar(
          selectedIndex: _index,
          backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
          indicatorColor: Theme.of(context).colorScheme.primary,
          onDestinationSelected: (i) {
            if (_isNavigating) return;
            // Ignora cliques no mesmo destino para não travar o bloqueio de navegação
            if (i == _index) return;
            setState(() {
              _index = i;
              _isNavigating = true;
            });
            _pageController.animateToPage(
              i,
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOut,
            );
          },
          destinations: [
            NavigationDestination(
              icon: Icon(
                Icons.person_outline,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              selectedIcon: Icon(
                Icons.person,
                color: Theme.of(context).colorScheme.onPrimary,
              ),
              label: 'Perfil',
            ),
            NavigationDestination(
              icon: Icon(
                Icons.medication_outlined,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              selectedIcon: Icon(
                Icons.medication,
                color: Theme.of(context).colorScheme.onPrimary,
              ),
              label: 'Medicamentos',
            ),
            NavigationDestination(
              icon: Icon(
                Icons.event_outlined,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              selectedIcon: Icon(
                Icons.event,
                color: Theme.of(context).colorScheme.onPrimary,
              ),
              label: 'Consultas',
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _configureLowStock(BuildContext context) async {
    final app = context.read<AppState>();
    int temp = app.lowStockDaysThreshold;
    final result = await showDialog<int>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Alerta de estoque (em dias)'),
          content: StatefulBuilder(
            builder: (context, setState) {
              final colorScheme = Theme.of(context).colorScheme;
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Exibir "Estoque baixo" quando restarem $temp dia(s) ou menos de doses.',
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Botão diminuir (tons de vermelho quando ativo)
                      IconButton.filled(
                        onPressed: temp > 1
                            ? () => setState(() => temp--)
                            : null,
                        icon: const Icon(Icons.remove),
                        style: IconButton.styleFrom(
                          backgroundColor: temp > 1
                              ? colorScheme.errorContainer
                              : colorScheme.surfaceContainerHighest,
                          foregroundColor: temp > 1
                              ? colorScheme.onErrorContainer
                              : colorScheme.onSurfaceVariant,
                          minimumSize: const Size(52, 52),
                        ),
                      ),
                      // Número de dias (usa TextTheme para respeitar textScaleFactor)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 28),
                        child: Column(
                          children: [
                            Text(
                              '$temp',
                              style:
                                  Theme.of(
                                    context,
                                  ).textTheme.headlineMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: colorScheme.primary,
                                  ) ??
                                  TextStyle(
                                    fontSize: 40,
                                    fontWeight: FontWeight.bold,
                                    color: colorScheme.primary,
                                  ),
                            ),
                            Text(
                              temp == 1 ? 'dia' : 'dias',
                              style:
                                  Theme.of(
                                    context,
                                  ).textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ) ??
                                  TextStyle(
                                    fontSize: 14,
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      // Botão aumentar
                      IconButton.filled(
                        onPressed: temp < 14
                            ? () => setState(() => temp++)
                            : null,
                        icon: const Icon(Icons.add),
                        style: IconButton.styleFrom(
                          backgroundColor: temp < 14
                              ? colorScheme.primaryContainer
                              : colorScheme.surfaceContainerHighest,
                          foregroundColor: temp < 14
                              ? colorScheme.onPrimaryContainer
                              : colorScheme.onSurfaceVariant,
                          minimumSize: const Size(52, 52),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(temp),
              child: const Text('Salvar'),
            ),
          ],
        );
      },
    );
    if (result != null && context.mounted) {
      context.read<AppState>().updateLowStockDaysThreshold(result);
    }
  }

  Future<void> _logout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Confirmar saída'),
        content: const Text('Deseja encerrar a sessão?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Sair'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await context.read<AppState>().logout();
    }
  }
}
