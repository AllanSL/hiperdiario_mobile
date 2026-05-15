import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/models/emergency_contact.dart';
import '../../core/models/municipio.dart';
import '../../core/services/cnes_service.dart';
import '../../core/services/municipio_service.dart';
import '../../core/widgets/app_input_decoration.dart';
import '../../core/widgets/app_snackbar.dart';
import '../../state/app_state.dart';

/// Formatter para telefone brasileiro: (00) 00000-0000 ou (00) 0000-0000
class PhoneInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;
    final digitsOnly = text.replaceAll(RegExp(r'\D'), '');

    if (digitsOnly.isEmpty) {
      return newValue.copyWith(text: '');
    }

    final buffer = StringBuffer();

    // (00) 00000-0000 para 11 dígitos ou (00) 0000-0000 para 10 dígitos
    if (digitsOnly.isNotEmpty) {
      buffer.write('(');
      buffer.write(
        digitsOnly.substring(0, digitsOnly.length >= 2 ? 2 : digitsOnly.length),
      );

      if (digitsOnly.length >= 3) {
        buffer.write(') ');

        if (digitsOnly.length <= 10) {
          // Formato: (00) 0000-0000
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
          // Formato: (00) 00000-0000
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
    }

    final formatted = buffer.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

/// Formata um telefone para exibição: (00) 00000-0000 ou (00) 0000-0000
String formatPhoneDisplay(String phone) {
  final digitsOnly = phone.replaceAll(RegExp(r'\D'), '');

  if (digitsOnly.isEmpty) return phone;

  final buffer = StringBuffer();

  if (digitsOnly.length >= 2) {
    buffer.write('(');
    buffer.write(digitsOnly.substring(0, 2));
    buffer.write(') ');

    if (digitsOnly.length <= 10) {
      // Formato: (00) 0000-0000
      if (digitsOnly.length > 2) {
        buffer.write(
          digitsOnly.substring(
            2,
            digitsOnly.length >= 6 ? 6 : digitsOnly.length,
          ),
        );
      }
      if (digitsOnly.length >= 7) {
        buffer.write('-');
        buffer.write(digitsOnly.substring(6));
      }
    } else {
      // Formato: (00) 00000-0000
      if (digitsOnly.length > 2) {
        buffer.write(
          digitsOnly.substring(
            2,
            digitsOnly.length >= 7 ? 7 : digitsOnly.length,
          ),
        );
      }
      if (digitsOnly.length >= 8) {
        buffer.write('-');
        buffer.write(digitsOnly.substring(7));
      }
    }

    return buffer.toString();
  }

  return phone;
}

String formatCpfDisplay(String cpf) {
  final digitsOnly = cpf.replaceAll(RegExp(r'\D'), '');
  if (digitsOnly.length != 11) return cpf;
  return '${digitsOnly.substring(0, 3)}.${digitsOnly.substring(3, 6)}.${digitsOnly.substring(6, 9)}-${digitsOnly.substring(9)}';
}

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final p = app.patient;
    if (p == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final df = DateFormat('dd/MM/yyyy');

    // Usando o mesmo padrão de ListView que funciona em medications_page
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        _HeaderCard(name: p.name, cpf: p.cpf, birth: df.format(p.birthDate)),
        const SizedBox(height: 8),
        _SectionTitle('Condições registradas'),
        const SizedBox(height: 4),
        // Se vazio exibir "Nenhuma condição registrada"
        if (p.diseases.isEmpty) ...[
          _ChipsCard(items: ["Nenhuma condição registrada"]),
        ] else ...[
          _ChipsCard(items: p.diseases),
        ],
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const _SectionTitle('Contato e endereço'),
            TextButton.icon(
              icon: const Icon(Icons.edit, size: 16),
              label: const Text('Editar'),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const EditPersonalContactsPage(),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        _InfoCard(
          rows: [
            // Telefone
            _InfoRow.compact(formatPhoneDisplay(p.contact), icon: Icons.phone),
            // Email
            if (p.email != null && p.email!.isNotEmpty)
              _InfoRow.compact(p.email!, icon: Icons.email),
            // UBS
            _InfoRow.compact(
              // Exibe nome formatado da UBS quando disponível; caso contrário,
              // mostramos um placeholder amigável para indicar que não há UBS.
              (() {
                final resolved = (p.ubsName != null && p.ubsName!.isNotEmpty)
                    ? p.ubsName!
                    : (p.ubs.isNotEmpty ? p.ubs : 'UBS não informada');
                return formatCnesDisplayName(resolved);
              })(),
              icon: Icons.local_hospital,
            ),
            // Endereço
            if (p.fullAddress != null && p.fullAddress!.isNotEmpty)
              _InfoRow.compact(p.fullAddress!, icon: Icons.home),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const _SectionTitle('Localização'),
            TextButton.icon(
              icon: const Icon(Icons.edit, size: 16),
              label: const Text('Editar'),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const EditLocationPage()),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        _InfoCard(
          rows: [
            if (p.siglaUf != null && p.nomeMunicipio != null)
              _InfoRow.compact(
                '${p.nomeMunicipio} - ${p.siglaUf}',
                icon: Icons.location_city,
              )
            else
              _InfoRow.compact(
                'Município não configurado',
                icon: Icons.location_off,
              ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const _SectionTitle('Contato de emergência'),
            if (p.emergencyContact == null)
              TextButton.icon(
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Adicionar'),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const EditEmergencyContactPage(),
                  ),
                ),
              )
            else
              TextButton.icon(
                icon: const Icon(Icons.edit, size: 16),
                label: const Text('Editar'),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const EditEmergencyContactPage(),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        if (p.emergencyContact != null)
          _InfoCard(
            rows: [
              _InfoRow.compact(p.emergencyContact!.name, icon: Icons.person),
              _InfoRow.compact(
                p.emergencyContact!.relationship,
                icon: Icons.people_outline,
              ),
              _InfoRow.compact(
                formatPhoneDisplay(p.emergencyContact!.phone),
                icon: Icons.phone,
              ),
            ],
          )
        else
          _InfoCard(
            rows: [
              _InfoRow.compact(
                'Nenhum contato adicionado',
                icon: Icons.person_off,
              ),
            ],
          ),
        const SizedBox(height: 16),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);
  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  final String name;
  final String cpf;
  final String birth;
  const _HeaderCard({
    required this.name,
    required this.cpf,
    required this.birth,
  });
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final maskedCpf = formatCpfDisplay(cpf);
    return Semantics(
      container: true,
      label:
          'Cabeçalho do perfil. Nome $name. CPF $maskedCpf. Nascimento $birth.',
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: colorScheme.outline),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const CircleAvatar(
                    radius: 28,
                    child: Icon(Icons.person, size: 28),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.badge,
                              size: 18,
                              color: colorScheme.primary,
                            ),
                            const SizedBox(width: 6),
                            Text(maskedCpf),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.cake,
                              size: 18,
                              color: colorScheme.primary,
                            ),
                            const SizedBox(width: 6),
                            Text(birth),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Ações foram movidas para o menu lateral (Drawer) da Home
            ],
          ),
        ),
      ),
    );
  }
}

class _ChipsCard extends StatelessWidget {
  final List<String> items;
  const _ChipsCard({required this.items});
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outline),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: items
              .map(
                (d) => Chip(
                  label: Text(
                    d,
                    style: TextStyle(
                      fontSize: 16,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  backgroundColor: colorScheme.primaryContainer,
                  side: BorderSide(
                    color: colorScheme.primary.withValues(alpha: 0.5),
                  ),
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final List<_InfoRow> rows;
  const _InfoCard({required this.rows});
  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Theme.of(context).colorScheme.outline),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            for (int i = 0; i < rows.length; i++) ...[
              _InfoLine(rows[i]),
              if (i < rows.length - 1) const Divider(height: 20),
            ],
          ],
        ),
      ),
    );
  }
}

class _InfoRow {
  final String value;
  final IconData? icon;
  _InfoRow(this.value, {this.icon});
  factory _InfoRow.compact(String value, {IconData? icon}) =>
      _InfoRow(value, icon: icon);
}

class _InfoLine extends StatelessWidget {
  final _InfoRow row;
  const _InfoLine(this.row);
  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (row.icon != null) ...[
          Icon(
            row.icon!,
            size: 20,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 8),
        ],
        Expanded(child: Text(row.value)),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Página de edição de localização (Estado + Município)
// ─────────────────────────────────────────────────────────────────────────────

class EditLocationPage extends StatefulWidget {
  const EditLocationPage({super.key});

  @override
  State<EditLocationPage> createState() => _EditLocationPageState();
}

class _EditLocationPageState extends State<EditLocationPage> {
  EstadoBrasileiro? _estadoSelecionado;
  Municipio? _municipioSelecionado;

  // Todos os municípios carregados + lista filtrada exibida no dropdown
  List<Municipio> _todosMunicipios = [];
  List<Municipio> _municipiosFiltrados = [];
  bool _carregandoMunicipios = false;
  String? _erroMunicipios;
  // Cache simples em memória para municípios por sigla da UF — evita reconsultas
  // e melhora a experiência quando o usuário limpa o município antes da API responder.
  final Map<String, List<Municipio>> _municipiosCache = {};
  // Indica que o usuário limpou manualmente o campo de município durante uma
  // requisição em andamento — se verdadeiro, não reaplicamos preSelect quando
  // a API retornar.
  bool _usuarioLimpouMunicipio = false;
  // Indica que há uma requisição em andamento iniciada em background (showLoading=false)
  // e que devemos mostrar um indicador sutil de "aguardando resposta" em vez do
  // texto padrão de "Nenhum município encontrado".
  bool _aguardandoMunicipios = false;

  // Counter de geração — evita race condition quando o usuário troca de estado
  // rapidamente e uma resposta antiga chega depois de uma resposta mais nova.
  int _requestGeneration = 0;

  // OverlayPortal para o dropdown de estado
  final _estadoController = TextEditingController();
  final _estadoFocusNode = FocusNode();
  final _estadoFieldKey = GlobalKey();
  final _estadoOverlayController = OverlayPortalController();
  bool _estadoDropdownAberto = false;
  bool _estadoModoDigitacao =
      false; // false = readOnly (sem teclado), true = editável
  List<EstadoBrasileiro> _estadosFiltrados = estadosBrasileiros;

  // OverlayPortal para o dropdown de município
  final _municipioController = TextEditingController();
  final _municipioFocusNode = FocusNode();
  final _municipioFieldKey = GlobalKey();
  final _municipioOverlayController = OverlayPortalController();
  bool _municipioDropdownAberto = false;
  bool _municipioModoDigitacao =
      false; // false = readOnly (sem teclado), true = editável
  ModalRoute<dynamic>? _modalRoute;

  @override
  void initState() {
    super.initState();
    _estadoController.addListener(_onEstadoChanged);
    _estadoFocusNode.addListener(_onEstadoFocusChanged);
    _municipioController.addListener(_onMunicipioChanged);
    _municipioFocusNode.addListener(_onMunicipioFocusChanged);

    // Pré-seleciona com os valores já salvos no perfil
    final p = context.read<AppState>().patient;
    if (p?.siglaUf != null) {
      _estadoSelecionado = estadosBrasileiros
          .where((e) => e.sigla == p!.siglaUf)
          .firstOrNull;
      if (_estadoSelecionado != null) {
        _estadoController.text =
            '${_estadoSelecionado!.sigla} — ${_estadoSelecionado!.nome}';

        // Se já houver município salvo no perfil, mostre-o imediatamente
        // enquanto buscamos a lista atualizada em segundo plano. Isso evita
        // que a UI mostre "Carregando..." e pareça que o município não está
        // salvo.
        if (p?.codigoMunicipio != null && p?.nomeMunicipio != null) {
          _municipioSelecionado = Municipio(
            codigoUf: p!.codigoUf ?? _estadoSelecionado!.codigoIbge,
            siglaUf: p.siglaUf ?? _estadoSelecionado!.sigla,
            codigoMunicipio: p.codigoMunicipio!,
            nome: p.nomeMunicipio!,
          );
          _municipioController.text = _municipioSelecionado!.nome;
        }

        // Busca em background sem mostrar o indicador de loading inicial
        // (só mostramos loading quando o usuário trocar o estado explicitamente).
        _buscarMunicipios(
          _estadoSelecionado!.sigla,
          preSelectCodigo: p?.codigoMunicipio,
          showLoading: false,
        );
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
    }
  }

  @override
  void dispose() {
    _estadoController.removeListener(_onEstadoChanged);
    _estadoFocusNode.removeListener(_onEstadoFocusChanged);
    _estadoController.dispose();
    _estadoFocusNode.dispose();
    _municipioController.removeListener(_onMunicipioChanged);
    _municipioFocusNode.removeListener(_onMunicipioFocusChanged);
    _municipioController.dispose();
    _municipioFocusNode.dispose();
    _modalRoute?.removeScopedWillPopCallback(_onWillPop);
    super.dispose();
  }

  // ── Lógica OverlayPortal — Estado ────────────────────────────────────────

  void _onEstadoFocusChanged() {
    if (_estadoFocusNode.hasFocus) {
      // Ao ganhar foco: limpa o campo e abre o dropdown (sem teclado ainda)
      _estadoController.clear();
      setState(() {
        _estadosFiltrados = estadosBrasileiros;
        _estadoModoDigitacao = false;
      });
      _abrirDropdownEstado();
    } else {
      // Ao perder foco: fecha dropdown, reseta modo e restaura texto
      setState(() => _estadoModoDigitacao = false);
      _fecharDropdownEstado();
      if (_estadoSelecionado != null) {
        _estadoController.text =
            '${_estadoSelecionado!.sigla} — ${_estadoSelecionado!.nome}';
      }
    }
  }

  /// Chamado pelo onTap do campo de estado.
  /// 1º toque → apenas abre dropdown (readOnly, sem teclado).
  /// 2º toque → ativa digitação e abre o teclado.
  void _onEstadoTap() {
    if (!_estadoDropdownAberto) {
      _abrirDropdownEstado();
    } else if (!_estadoModoDigitacao) {
      setState(() => _estadoModoDigitacao = true);
      // Força a abertura do teclado sem perder o foco
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
    });
    _estadoController.text = '${estado.sigla} — ${estado.nome}';
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

  // ── Lógica OverlayPortal — Município ─────────────────────────────────────

  void _onMunicipioFocusChanged() {
    if (_municipioFocusNode.hasFocus) {
      setState(() => _municipioModoDigitacao = false);
      _abrirDropdownMunicipio();
    } else {
      setState(() => _municipioModoDigitacao = false);
      _fecharDropdownMunicipio();
    }
  }

  /// Chamado pelo onTap do campo de município.
  /// 1º toque → abre dropdown sem teclado.
  /// 2º toque → ativa digitação e abre o teclado.
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
      _usuarioLimpouMunicipio = false;
    });
    _municipioController.text = municipio.nome;
    _municipioController.selection = TextSelection.collapsed(
      offset: municipio.nome.length,
    );
    _fecharDropdownMunicipio();
    _municipioFocusNode.unfocus();
  }

  (Offset, double) _calcularPosicaoDropdownMunicipio() {
    final box =
        _municipioFieldKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return (Offset.zero, 300);
    final offset = box.localToGlobal(Offset.zero);
    return (Offset(offset.dx, offset.dy + box.size.height + 4), box.size.width);
  }

  // ── Busca de municípios com proteção contra race condition ───────────────

  Future<void> _buscarMunicipios(
    String siglaUf, {
    int? preSelectCodigo,
    bool showLoading = true,
  }) async {
    // Incrementa a geração — qualquer resposta de geração anterior será descartada
    _requestGeneration++;
    final minhaGeracao = _requestGeneration;

    // Se esta busca foi iniciada por ação explícita do usuário (showLoading==true),
    // resetamos o indicador de "usuário limpou" porque é uma nova carga.
    if (showLoading) {
      _usuarioLimpouMunicipio = false;
    }

    if (showLoading) {
      setState(() {
        _carregandoMunicipios = true;
        _erroMunicipios = null;
        _todosMunicipios = [];
        _municipiosFiltrados = [];
        _municipioSelecionado = null;
        _municipioController.text = '';
        _aguardandoMunicipios = false;
      });
    } else {
      // Busca em background: não mostramos o spinner grande, mas indicamos que
      // estamos aguardando a resposta para evitar a mensagem de "nenhum"
      setState(() {
        _erroMunicipios = null;
        _aguardandoMunicipios = true;
      });
    }

    final lista = await MunicipioService.buscarMunicipios(siglaUf);

    // Verifica se o widget ainda está montado E se a geração ainda é a mais recente
    if (!mounted || minhaGeracao != _requestGeneration) return;

    // Atualiza cache com o resultado (mesmo que vazio)
    _municipiosCache[siglaUf] = lista;

    setState(() {
      _carregandoMunicipios = false;
      _aguardandoMunicipios = false;
      if (lista.isEmpty) {
        _erroMunicipios =
            'Não foi possível carregar os municípios. Verifique sua conexão.';
      } else {
        _todosMunicipios = lista;
        _municipiosFiltrados = lista;

        // Apenas reaplicamos um preSelect vindo do perfil se o usuário
        // NÃO tiver limpado manualmente o campo durante a requisição.
        if (preSelectCodigo != null && !_usuarioLimpouMunicipio) {
          final preSelected = lista
              .where((m) => m.codigoMunicipio == preSelectCodigo)
              .firstOrNull;
          if (preSelected != null) {
            // Quando encontramos o município na lista da API, usamos o objeto
            // retornado para manter consistência (mesmo formato/campos).
            _municipioSelecionado = preSelected;
            _municipioController.text = preSelected.nome;
          } else {
            // Se não encontramos e já exibimos um município (do perfil),
            // não sobrescrevemos para evitar que a UI perca o valor do usuário.
            if (_municipioSelecionado == null) {
              _municipioController.text = '';
            }
          }
        }
      }
    });
  }

  // ── Salvar ───────────────────────────────────────────────────────────────

  Future<void> _salvar() async {
    if (_estadoSelecionado == null || _municipioSelecionado == null) return;

    await context.read<AppState>().updatePatientLocation(
      codigoUf: _estadoSelecionado!.codigoIbge,
      siglaUf: _estadoSelecionado!.sigla,
      codigoMunicipio: _municipioSelecionado!.codigoMunicipio,
      nomeMunicipio: _municipioSelecionado!.nome,
    );

    if (!mounted) return;
    Navigator.of(context).pop();
    AppSnackBar.showSuccess(context, 'Localização atualizada: ${_municipioSelecionado!.nome} / ${_estadoSelecionado!.sigla}');
  }

  Future<bool> _onWillPop() async {
    if (_estadoDropdownAberto || _municipioDropdownAberto) {
      if (_estadoDropdownAberto) _fecharDropdownEstado();
      if (_municipioDropdownAberto) _fecharDropdownMunicipio();
      return true;
    }
    return true;
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final podeSalvar =
        _estadoSelecionado != null && _municipioSelecionado != null;

    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
        _fecharDropdownEstado();
        _fecharDropdownMunicipio();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Editar localização'),
          elevation: 0,
          scrolledUnderElevation: 0.0,
          surfaceTintColor: Colors.transparent,
          backgroundColor: colorScheme.surface,
          shadowColor: Colors.transparent,
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Aviso informativo
            Card(
              color: colorScheme.surfaceContainerHighest,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: colorScheme.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Sua localização é usada para sugerir os estabelecimentos de saúde mais próximos ao agendar uma consulta.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // ── Campo de Estado com OverlayPortal ──────────────────────────
            OverlayPortal(
              controller: _estadoOverlayController,
              overlayChildBuilder: (overlayContext) {
                final (pos, width) = _calcularPosicaoDropdownEstado();
                final mq = MediaQuery.of(context);
                // Altura disponível = topo do teclado (ou fundo da tela) menos
                // a posição do dropdown menos uma margem de segurança
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
                      maxHeight: alturaDisponivel.clamp(120.0, double.infinity),
                    ),
                  ),
                );
              },
              child: TextField(
                key: _estadoFieldKey,
                controller: _estadoController,
                focusNode: _estadoFocusNode,
                readOnly: !_estadoModoDigitacao,
                onTap: _onEstadoTap,
                decoration: AppInputDecoration.build(
                  context,
                  labelText: 'Estado *',
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

            // ── Campo de Município com OverlayPortal ───────────────────────
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
                child: TextField(
                  key: _municipioFieldKey,
                  controller: _municipioController,
                  focusNode: _municipioFocusNode,
                  readOnly: !_municipioModoDigitacao,
                  onTap: _onMunicipioTap,
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
                    suffixIcon: (_carregandoMunicipios || _aguardandoMunicipios)
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
                        // Só permitimos limpar o município (X) quando não estivermos
                        // carregando nem aguardando uma resposta em background.
                        : (!_aguardandoMunicipios &&
                              _municipioController.text.isNotEmpty)
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              setState(() {
                                _municipioSelecionado = null;
                                _municipioModoDigitacao = false;
                                _usuarioLimpouMunicipio = true;
                                // Se já tivermos um cache para a UF atual,
                                // exibimos imediatamente essa lista para
                                // evitar mostrar "Nenhum município".
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
                                  // Caso não haja cache, mantemos a UI vazia e
                                  // aguardamos a resposta da API.
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

              // Mensagem de erro com botão de retry (fora do overlay)
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
                    Expanded(
                      child: Text(
                        _erroMunicipios!,
                        style: TextStyle(
                          color: colorScheme.error,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () =>
                          _buscarMunicipios(_estadoSelecionado!.sigla),
                      child: const Text('Tentar novamente'),
                    ),
                  ],
                ),
              ],
            ],

            const SizedBox(height: 32),

            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                onPressed: podeSalvar ? _salvar : null,
                child: const Text('Salvar localização'),
              ),
            ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

// ── Widget do dropdown de estados ────────────────────────────────────────────

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
    // Permite que a lista ocupe apenas o espaço necessário quando curta,
    // mas limita a altura total pelo `maxHeight` quando longa.
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
                      '${estado.sigla} — ${estado.nome}',
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

// ── Widget do dropdown de municípios ─────────────────────────────────────────

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
    // Permite que a lista ocupe apenas o espaço necessário quando curta,
    // mas limita a altura total pelo `maxHeight` quando longa.
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

class EditPersonalContactsPage extends StatefulWidget {
  const EditPersonalContactsPage({super.key});

  @override
  State<EditPersonalContactsPage> createState() =>
      _EditPersonalContactsPageState();
}

class _EditPersonalContactsPageState extends State<EditPersonalContactsPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _phone;
  late final TextEditingController _email;
  final _ubsController = TextEditingController();
  CnesEstabelecimento? _ubsSelecionada;

  bool _carregandoUbs = true;
  bool _ubsDropdownAberto = false;
  bool _ubsModoDigitacao = false;

  final _ubsFocusNode = FocusNode();
  final _ubsFieldKey = GlobalKey();
  final _ubsOverlayController = OverlayPortalController();

  ModalRoute<dynamic>? _modalRoute;

  List<CnesEstabelecimento> _todasUbs = [];
  List<CnesEstabelecimento> _ubsFiltradas = [];

  @override
  void initState() {
    super.initState();
    final p = context.read<AppState>().patient;

    final formattedPhone = PhoneInputFormatter()
        .formatEditUpdate(
          TextEditingValue.empty,
          TextEditingValue(text: p?.contact ?? ''),
        )
        .text;

    _phone = TextEditingController(text: formattedPhone);
    _email = TextEditingController(text: p?.email ?? '');

    // Mostra o nome fantasia se disponível, caso contrário cai pro código
    if (p?.ubsName != null && p!.ubsName!.isNotEmpty) {
      _ubsController.text = p.ubsName!;
    } else if (p?.ubs != null && p!.ubs != 'UBS não informada') {
      _ubsController.text = p.ubs;
    } else {
      _ubsController.text = ''; // Mostra vazio para o usuário preencher
    }

    _ubsController.addListener(_onUbsChanged);
    _ubsFocusNode.addListener(_onUbsFocusChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _carregarEstabelecimentos();
    });
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
    _ubsController.removeListener(_onUbsChanged);
    _ubsFocusNode.removeListener(_onUbsFocusChanged);
    _phone.dispose();
    _email.dispose();
    _ubsController.dispose();
    _ubsFocusNode.dispose();
    _modalRoute?.removeScopedWillPopCallback(_onWillPop);
    super.dispose();
  }

  Future<void> _carregarEstabelecimentos() async {
    final patient = context.read<AppState>().patient;
    final codigoUf = patient?.codigoUf;
    final codigoMunicipio = patient?.codigoMunicipio;

    if (codigoUf == null || codigoMunicipio == null) {
      if (mounted) setState(() => _carregandoUbs = false);
      return;
    }

    final resultado = await CnesService.buscarEstabelecimentos(
      codigoUf: codigoUf,
      codigoMunicipio: codigoMunicipio,
      tipoUnidade: 2,
    );

    if (mounted) {
      setState(() {
        _todasUbs = resultado;
        _ubsFiltradas = resultado;
        _carregandoUbs = false;

        // Se já tivermos um código cnes (p.ubs) e acabarmos de carregar as UBSs,
        // substituímos o texto pelo nome fantasia da UBS encontrada.
        if (patient?.ubs != null && patient!.ubs.isNotEmpty) {
          try {
            final ubsMatcheada = _todasUbs.firstWhere(
              (ubs) => ubs.codigoCnes.toString() == patient.ubs,
            );
            _ubsSelecionada = ubsMatcheada;
            _ubsController.text = ubsMatcheada.displayText;
          } catch (_) {
            // Nenhuma correspondência encontrada.
          }
        }
      });
    }
  }

  void _onUbsChanged() {
    final q = _ubsController.text.trim().toLowerCase();
    setState(() {
      _ubsFiltradas = q.isEmpty
          ? _todasUbs
          : _todasUbs
                .where(
                  (e) =>
                      e.nomeFantasia.toLowerCase().contains(q) ||
                      e.displayText.toLowerCase().contains(q) ||
                      e.endereco.toLowerCase().contains(q),
                )
                .toList();
    });
  }

  void _onUbsFocusChanged() {
    if (_ubsFocusNode.hasFocus) {
      setState(() => _ubsModoDigitacao = false);
      _abrirDropdown();
    } else {
      setState(() => _ubsModoDigitacao = false);
      _fecharDropdown();
    }
  }

  void _onUbsTap() {
    if (!_ubsDropdownAberto) {
      _abrirDropdown();
    } else if (!_ubsModoDigitacao) {
      setState(() => _ubsModoDigitacao = true);
      _ubsFocusNode.requestFocus();
    }
  }

  void _abrirDropdown() {
    if (!_ubsDropdownAberto) {
      setState(() => _ubsDropdownAberto = true);
      _ubsOverlayController.show();
    }
  }

  void _fecharDropdown() {
    if (_ubsDropdownAberto) {
      setState(() => _ubsDropdownAberto = false);
      _ubsOverlayController.hide();
    }
  }

  void _selecionarEstabelecimento(CnesEstabelecimento est) {
    _ubsSelecionada = est;
    _ubsController.text = est.displayText;
    _ubsController.selection = TextSelection.collapsed(
      offset: est.displayText.length,
    );
    _fecharDropdown();
    _ubsFocusNode.unfocus();
  }

  (Offset, double) _calcularPosicaoDropdown() {
    final box = _ubsFieldKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return (Offset.zero, 300);
    final offset = box.localToGlobal(Offset.zero);
    return (Offset(offset.dx, offset.dy + box.size.height + 4), box.size.width);
  }

  Future<bool> _onWillPop() async {
    if (_ubsDropdownAberto) {
      _fecharDropdown();
      return true;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final p = context.read<AppState>().patient;
    final colorScheme = Theme.of(context).colorScheme;

    if (p == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Editar contatos pessoais'),
          elevation: 0,
          scrolledUnderElevation: 0.0,
          surfaceTintColor: Colors.transparent,
          backgroundColor: Theme.of(context).colorScheme.surface,
          shadowColor: Colors.transparent,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
        _fecharDropdown();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Editar contatos pessoais'),
          elevation: 0,
          scrolledUnderElevation: 0.0,
          surfaceTintColor: Colors.transparent,
          backgroundColor: Theme.of(context).colorScheme.surface,
          shadowColor: Colors.transparent,
        ),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              if (p.fullAddress != null && p.fullAddress!.isNotEmpty)
                Card(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: Theme.of(context).colorScheme.primary,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Informações de endereço',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _buildReadOnlyField(
                          icon: Icons.home,
                          label: 'Endereço',
                          value: p.fullAddress!,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Para alterar este dado, compareça à UBS com documento de identificação.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              if (p.fullAddress != null && p.fullAddress!.isNotEmpty)
                const SizedBox(height: 24),
              Text(
                'Seus contatos',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(11),
                  PhoneInputFormatter(),
                ],
                decoration: AppInputDecoration.build(
                  context,
                  labelText: 'Telefone *',
                  hintText: '(00) 00000-0000',
                  prefixIcon: const Icon(Icons.phone),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Telefone é obrigatório';
                  }
                  final digitsOnly = value.replaceAll(RegExp(r'\D'), '');
                  if (digitsOnly.length < 10) {
                    return 'Telefone deve ter pelo menos 10 dígitos';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: AppInputDecoration.build(
                  context,
                  labelText: 'E-mail',
                  hintText: 'seu@email.com',
                  prefixIcon: const Icon(Icons.email),
                ),
                validator: (value) {
                  if (value != null && value.trim().isNotEmpty) {
                    final emailRegex = RegExp(
                      r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                    );
                    if (!emailRegex.hasMatch(value.trim())) {
                      return 'E-mail inválido';
                    }
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              OverlayPortal(
                controller: _ubsOverlayController,
                overlayChildBuilder: (overlayContext) {
                  final (pos, width) = _calcularPosicaoDropdown();
                  final mq = MediaQuery.of(context);
                  final alturaDisponivel =
                      mq.size.height - mq.viewInsets.bottom - pos.dy - 8;
                  return Positioned(
                    left: pos.dx,
                    top: pos.dy,
                    width: width,
                    child: MediaQuery(
                      data: mq,
                      child: _DropdownUbsLocal(
                        sugestoes: _ubsFiltradas,
                        carregando: _carregandoUbs,
                        colorScheme: colorScheme,
                        onSelected: _selecionarEstabelecimento,
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
                  textCapitalization: TextCapitalization.words,
                  decoration: AppInputDecoration.build(
                    context,
                    labelText: 'UBS de referência',
                    hintText: _ubsController.text.trim().isEmpty
                        ? 'Nenhuma UBS selecionada'
                        : 'Toque para ver as UBS ou digite para filtrar',
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
                        : _ubsController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _ubsController.clear();
                              _ubsFocusNode.requestFocus();
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
                                _fecharDropdown();
                              } else {
                                _onUbsTap();
                              }
                            },
                          ),
                  ),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Informe a UBS' : null,
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  onPressed: _save,
                  child: const Text('Salvar alterações'),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReadOnlyField({
    required IconData icon,
    required String label,
    required String value,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: colorScheme.onSurfaceVariant),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final app = context.read<AppState>();
    final phoneDigits = _phone.text.replaceAll(RegExp(r'\D'), '');

    final ubsToSave =
        _ubsSelecionada?.codigoCnes.toString() ?? _ubsController.text.trim();
    final ubsNameToSave =
        _ubsSelecionada?.nomeFantasia ?? _ubsController.text.trim();

    await app.updatePatientContacts(
      contact: phoneDigits,
      ubs: ubsToSave,
      ubsName: ubsNameToSave,
      email: _email.text.trim(),
    );

    if (!mounted) return;
    Navigator.of(context).pop();
    AppSnackBar.showSuccess(context, 'Contatos atualizados com sucesso');
  }
}

class _DropdownUbsLocal extends StatelessWidget {
  final List<CnesEstabelecimento> sugestoes;
  final bool carregando;
  final ColorScheme colorScheme;
  final ValueChanged<CnesEstabelecimento> onSelected;
  final double maxHeight;

  const _DropdownUbsLocal({
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
              'Nenhuma UBS encontrada para este município. \nDigite para buscar.',
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
                          est.displayText,
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

class EditEmergencyContactPage extends StatefulWidget {
  const EditEmergencyContactPage({super.key});

  @override
  State<EditEmergencyContactPage> createState() =>
      _EditEmergencyContactPageState();
}

class _EditEmergencyContactPageState extends State<EditEmergencyContactPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _emergencyName;
  late final TextEditingController _emergencyPhone;

  // Variáveis para o Dropdown customizado
  final _relationshipController = TextEditingController();
  final _relationshipFocusNode = FocusNode();
  final _relationshipFieldKey = GlobalKey();
  final _relationshipOverlayController = OverlayPortalController();
  bool _relationshipDropdownAberto = false;
  String? _emergencyRelationship;

  ModalRoute<dynamic>? _modalRoute;

  final List<String> _relationships = [
    'Pai',
    'Mãe',
    'Filho(a)',
    'Cônjuge',
    'Irmão(ã)',
    'Avô(ó)',
    'Outro',
  ];

  @override
  void initState() {
    super.initState();
    final p = context.read<AppState>().patient!;

    final formattedEmergencyPhone = PhoneInputFormatter()
        .formatEditUpdate(
          TextEditingValue.empty,
          TextEditingValue(text: p.emergencyContact?.phone ?? ''),
        )
        .text;

    _emergencyName = TextEditingController(
      text: p.emergencyContact?.name ?? '',
    );
    _emergencyPhone = TextEditingController(text: formattedEmergencyPhone);
    _emergencyRelationship = p.emergencyContact?.relationship;

    if (_emergencyRelationship != null) {
      _relationshipController.text = _emergencyRelationship!;
    }
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
    _emergencyName.dispose();
    _emergencyPhone.dispose();
    _relationshipController.dispose();
    _relationshipFocusNode.dispose();
    _modalRoute?.removeScopedWillPopCallback(_onWillPop);
    super.dispose();
  }

  void _toggleDropdownParentesco() {
    FocusScope.of(context).unfocus();
    if (_relationshipDropdownAberto) {
      _fecharDropdownParentesco();
    } else {
      setState(() => _relationshipDropdownAberto = true);
      _relationshipOverlayController.show();
    }
  }

  void _fecharDropdownParentesco() {
    if (_relationshipDropdownAberto) {
      setState(() => _relationshipDropdownAberto = false);
      _relationshipOverlayController.hide();
    }
  }

  void _selecionarParentesco(String parentesco) {
    setState(() {
      _emergencyRelationship = parentesco;
      _relationshipController.text = parentesco;
    });
    _fecharDropdownParentesco();
  }

  Rect _calcularDropdownParentescoLayout(BuildContext context) {
    final renderBox =
        _relationshipFieldKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return Rect.zero;

    final size = renderBox.size;
    final offset = renderBox.localToGlobal(Offset.zero);
    final mq = MediaQuery.of(context);

    double top = offset.dy + size.height + 4;
    final bottomSpace = mq.size.height - top - mq.viewInsets.bottom;
    double maxHeight = 400.0;
    if (bottomSpace < maxHeight) {
      // Se não houver espaço embaixo, abre para cima
      top = offset.dy - 4 - maxHeight;
    }

    return Rect.fromLTWH(offset.dx, top, size.width, maxHeight);
  }

  Future<bool> _onWillPop() async {
    if (_relationshipDropdownAberto) {
      _fecharDropdownParentesco();
      return true;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Contato de emergência'),
        elevation: 0,
        scrolledUnderElevation: 0.0,
        surfaceTintColor: Colors.transparent,
        backgroundColor: Theme.of(context).colorScheme.surface,
        shadowColor: Colors.transparent,
      ),
      body: GestureDetector(
        onTap: () {
          FocusScope.of(context).unfocus();
          _fecharDropdownParentesco();
        },
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              const SizedBox(height: 8),
              Text(
                'Contato de emergência (opcional)',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Adicione ou edite um contato de emergência caso necessário.',
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _emergencyName,
                decoration: AppInputDecoration.build(
                  context,
                  labelText: 'Nome do contato',
                  prefixIcon: const Icon(Icons.person),
                ),
                inputFormatters: [LengthLimitingTextInputFormatter(100)],
                validator: (value) {
                  if (_emergencyPhone.text.trim().isNotEmpty ||
                      _emergencyRelationship != null) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Nome é obrigatório';
                    }
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emergencyPhone,
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(11),
                  PhoneInputFormatter(),
                ],
                decoration: AppInputDecoration.build(
                  context,
                  labelText: 'Telefone do contato',
                  hintText: '(00) 00000-0000',
                  prefixIcon: const Icon(Icons.phone),
                ),
                validator: (value) {
                  if (_emergencyName.text.trim().isNotEmpty ||
                      _emergencyRelationship != null) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Telefone é obrigatório';
                    }
                    final digitsOnly = value.replaceAll(RegExp(r'\D'), '');
                    if (digitsOnly.length < 10) {
                      return 'Telefone deve ter pelo menos 10 dígitos';
                    }
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              OverlayPortal(
                controller: _relationshipOverlayController,
                overlayChildBuilder: (overlayContext) {
                  final layout = _calcularDropdownParentescoLayout(context);
                  final mq = MediaQuery.of(context);
                  return Positioned(
                    left: layout.left,
                    top: layout.top,
                    width: layout.width,
                    child: MediaQuery(
                      data: mq,
                      child: _DropdownString(
                        items: _relationships,
                        colorScheme: colorScheme,
                        emptyMessage: 'Nenhuma opção disponível.',
                        icon: Icons.family_restroom,
                        onSelected: _selecionarParentesco,
                        maxHeight: layout.height,
                      ),
                    ),
                  );
                },
                child: TextFormField(
                  key: _relationshipFieldKey,
                  controller: _relationshipController,
                  focusNode: _relationshipFocusNode,
                  readOnly: true,
                  onTap: _toggleDropdownParentesco,
                  validator: (v) {
                    if (_emergencyName.text.trim().isNotEmpty ||
                        _emergencyPhone.text.trim().isNotEmpty) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Selecione o grau de parentesco';
                      }
                    }
                    return null;
                  },
                  decoration: AppInputDecoration.build(
                    context,
                    labelText: 'Grau de parentesco',
                    hintText: 'Toque para selecionar',
                    prefixIcon: Icon(
                      Icons.family_restroom,
                      color: colorScheme.primary,
                    ),
                    suffixIcon: _emergencyRelationship != null
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              setState(() {
                                _emergencyRelationship = null;
                                _relationshipController.clear();
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
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  onPressed: _save,
                  child: const Text('Salvar alterações'),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    _fecharDropdownParentesco();

    if (!_formKey.currentState!.validate()) return;
    final app = context.read<AppState>();

    final emergencyPhoneDigits = _emergencyPhone.text.replaceAll(
      RegExp(r'\D'),
      '',
    );

    EmergencyContact? emergencyContact;
    bool clearEmergency = false;

    final hasEmergencyName = _emergencyName.text.trim().isNotEmpty;
    final hasEmergencyPhone = emergencyPhoneDigits.isNotEmpty;
    final hasEmergencyRel = _emergencyRelationship != null;

    if (hasEmergencyName && hasEmergencyPhone && hasEmergencyRel) {
      emergencyContact = EmergencyContact(
        name: _emergencyName.text.trim(),
        phone: emergencyPhoneDigits,
        relationship: _emergencyRelationship!,
      );
    } else if (!hasEmergencyName && !hasEmergencyPhone && !hasEmergencyRel) {
      clearEmergency = true;
    }

    final p = app.patient!;

    await app.updatePatientContacts(
      contact: p.contact,
      email: p.email,
      emergencyContact: emergencyContact,
      clearEmergencyContact: clearEmergency,
    );

    if (!mounted) return;
    Navigator.of(context).pop();
    AppSnackBar.showSuccess(context, 'Contato de emergência atualizado');
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
    super.key,
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
