import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../core/providers/theme_provider.dart';
import 'appointments_page.dart';
import 'appointment_history_page.dart';
import 'medications_page.dart';
import 'profile_page.dart';
import 'add_medication_page.dart';
import 'add_appointment_page.dart';
import 'settings_page.dart';
import 'health_tips_page.dart';

// Classes exportadas de profile_page.dart
export 'profile_page.dart' show EditPersonalContactsPage, EditEmergencyContactPage, QrProfilePage;

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _index = 0;
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _index, keepPage: true);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
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
                tooltip: isDark ? 'Mudar para tema claro' : 'Mudar para tema escuro',
                icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode),
                onPressed: () => themeProvider.toggle(context),
              );
            },
          ),
          if (_index == 1)
            Tooltip(
              message: 'Ajustar dias para aviso de estoque baixo',
              child: IconButton(
                tooltip: 'Configurar alerta de estoque',
                onPressed: () => _configureLowStock(context),
                icon: const Icon(Icons.notifications_active),
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
                    MaterialPageRoute(builder: (_) => const AppointmentHistoryPage()),
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
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        backgroundColor: Theme.of(context).colorScheme.error,
                        duration: const Duration(seconds: 2),
                        content: Row(
                          children: [
                            Icon(Icons.logout, color: Theme.of(context).colorScheme.onError),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Sessão encerrada',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: Theme.of(context).colorScheme.onError),
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
        onPageChanged: (i) => setState(() => _index = i),
        children: pages,
      ),
      floatingActionButton: _index == 1
          ? Column(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                FloatingActionButton.small(
                  heroTag: 'btnSyncMed',
                  tooltip: 'Atualizar medicamentos da UBS',
                  onPressed: () async {
                    ScaffoldMessenger.of(context).showSnackBar(
                       const SnackBar(
                        behavior: SnackBarBehavior.floating,
                        duration: Duration(seconds: 2),
                        content: Text('Buscando atualizações na UBS...'),
                      ),
                    );
                    await context.read<AppState>().syncUbsData();
                  },
                  child: const Icon(Icons.sync),
                ),
                const SizedBox(height: 16),
                FloatingActionButton.extended(
                  heroTag: 'btnAddMed',
                  onPressed: () async {
                final result = await Navigator.of(context).push<String>(
                  MaterialPageRoute(builder: (_) => const AddMedicationPage()),
                );
                if (!mounted) return;
                if (result == 'added') {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      behavior: SnackBarBehavior.floating,
                      margin: const EdgeInsets.all(16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                      duration: const Duration(seconds: 2),
                      content: Row(
                        children: [
                          Icon(Icons.check_circle_outline, color: Theme.of(context).colorScheme.onPrimaryContainer),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Medicamento adicionado com sucesso',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: Theme.of(context).colorScheme.onPrimaryContainer),
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
        )
          : _index == 2
              ? FloatingActionButton.extended(
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
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                          duration: const Duration(seconds: 2),
                          content: Row(
                            children: [
                              Icon(Icons.check_circle_outline, color: Theme.of(context).colorScheme.onPrimaryContainer),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Consulta agendada com sucesso',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(color: Theme.of(context).colorScheme.onPrimaryContainer),
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
                )
              : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
        indicatorColor: Theme.of(context).colorScheme.primary,
        onDestinationSelected: (i) {
          setState(() => _index = i);
          _pageController.animateToPage(
            i,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
          );
        },
        destinations: [
          NavigationDestination(
            icon: Icon(Icons.person_outline,
                color: Theme.of(context).colorScheme.onSurfaceVariant),
            selectedIcon: Icon(Icons.person,
                color: Theme.of(context).colorScheme.onPrimary),
            label: 'Perfil',
          ),
          NavigationDestination(
            icon: Icon(Icons.medication_outlined,
                color: Theme.of(context).colorScheme.onSurfaceVariant),
            selectedIcon: Icon(Icons.medication,
                color: Theme.of(context).colorScheme.onPrimary),
            label: 'Medicamentos',
          ),
          NavigationDestination(
            icon: Icon(Icons.event_outlined,
                color: Theme.of(context).colorScheme.onSurfaceVariant),
            selectedIcon: Icon(Icons.event,
                color: Theme.of(context).colorScheme.onPrimary),
            label: 'Consultas',
          ),
        ],
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
                              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: colorScheme.primary,
                                  ) ?? TextStyle(
                                    fontSize: 40,
                                    fontWeight: FontWeight.bold,
                                    color: colorScheme.primary,
                                  ),
                            ),
                            Text(
                              temp == 1 ? 'dia' : 'dias',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ) ?? TextStyle(
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
