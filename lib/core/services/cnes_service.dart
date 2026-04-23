import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

/// Representa um estabelecimento de saúde retornado pela API CNES.
class CnesEstabelecimento {
  final int codigoCnes;
  final String nomeFantasia;
  final String endereco;
  final int? ibgeOriginal; // Guardamos o IBGE de 7 dígitos para formar o path

  const CnesEstabelecimento({
    required this.codigoCnes,
    required this.nomeFantasia,
    required this.endereco,
    this.ibgeOriginal,
  });

  factory CnesEstabelecimento.fromJson(Map<String, dynamic> json, {int? ibge}) {
    final nome = (json['nome_fantasia'] as String? ?? '').trim();
    final rua = (json['endereco_estabelecimento'] as String? ?? '').trim();
    final numero = (json['numero_estabelecimento'] as String? ?? '').trim();
    final bairro = (json['bairro_estabelecimento'] as String? ?? '').trim();

    final partes = [rua, numero, bairro].where((p) => p.isNotEmpty).join(', ');

    return CnesEstabelecimento(
      codigoCnes: (json['codigo_cnes'] as num?)?.toInt() ?? 0,
      nomeFantasia: nome.isNotEmpty ? nome : 'Estabelecimento sem nome',
      endereco: partes,
      ibgeOriginal: ibge,
    );
  }

  /// Texto exibido no campo de texto após selecionar a opção.
  String get displayText => nomeFantasia;

  @override
  String toString() => nomeFantasia;
}

/// Representa um profissional de saúde retornado pela API CNES.
class CnesProfissional {
  final String nome;
  final String especialidade;

  const CnesProfissional({
    required this.nome,
    required this.especialidade,
  });

  /// Texto exibido no campo de texto após selecionar a opção.
  String get displayText => '$especialidade - $nome';

  @override
  String toString() => displayText;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CnesProfissional &&
          runtimeType == other.runtimeType &&
          nome == other.nome &&
          especialidade == other.especialidade;

  @override
  int get hashCode => nome.hashCode ^ especialidade.hashCode;
}

/// Serviço para consulta à API de Dados Abertos do CNES (Cadastro Nacional de Estabelecimentos de Saúde) e Edge Function Supabase.
class CnesService {
  static const _baseUrl =
      'https://apidadosabertos.saude.gov.br/cnes/estabelecimentos';
  static const _requestTimeout = Duration(seconds: 20);
  static const _maxAttempts = 3;

  static Future<http.Response?> _getWithRetry(
    Uri uri,
    Map<String, String> headers,
  ) async {
    for (var attempt = 1; attempt <= _maxAttempts; attempt++) {
      try {
        final response = await http
            .get(uri, headers: headers)
            .timeout(_requestTimeout);
        debugPrint('[CnesService] GET $uri (attempt $attempt)');
        debugPrint('[CnesService] Status: ${response.statusCode}');
        return response;
      } catch (e) {
        debugPrint(
          '[CnesService] ERRO na requisição $uri (attempt $attempt): $e',
        );
        if (attempt == _maxAttempts) return null;
        await Future.delayed(const Duration(milliseconds: 600));
      }
    }
    return null;
  }

  /// Busca os profissionais consultando diretamente a API do CNES com headers específicos.
  static Future<List<CnesProfissional>> buscarProfissionais(int ibge7Digitos, int cnes7Digitos) async {
    try {
      String ibgeStr = ibge7Digitos.toString();
      if (ibgeStr.length == 7) {
        ibgeStr = ibgeStr.substring(0, 6);
      }
      final cnesStr = cnes7Digitos.toString().padLeft(7, '0');
      final id = '$ibgeStr$cnesStr';
      debugPrint('[CnesService] Buscando profissionais do ID completo: $id');

      // Obtém um cookie de sessão válido simulando o acesso à página principal
      final mainPageResponse = await _getWithRetry(
        Uri.parse('https://cnes.datasus.gov.br/pages/estabelecimentos/consulta.jsp'),
        {
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/146.0.0.0 Safari/537.36',
        },
      );
      if (mainPageResponse == null) return [];

      final cookies = mainPageResponse.headers['set-cookie'] ?? '';

      final uri = Uri.parse('https://cnes.datasus.gov.br/services/estabelecimentos-profissionais/$id');
      final response = await _getWithRetry(uri, {
        'Referer': 'https://cnes.datasus.gov.br/pages/estabelecimentos/consulta.jsp',
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/146.0.0.0 Safari/537.36',
        'Accept': 'application/json',
        if (cookies.isNotEmpty) 'Cookie': cookies,
      });
      if (response == null || response.statusCode != 200) {
        return [];
      }

      final data = jsonDecode(response.body);
      if (data is List) {
        final profissionais = <CnesProfissional>{};
        for (final e in data) {
          String cbo = (e['dsCbo'] as String?)?.trim().toUpperCase() ?? '';
          String nome = (e['nome'] as String?)?.trim() ?? '';

          if (cbo.isEmpty || nome.isEmpty) continue;

          if (cbo.contains('MEDICO') ||
              cbo.contains('MÉDICO') ||
              cbo.contains('DENTISTA') ||
              cbo.contains('PSICOLOGO') ||
              cbo.contains('PSICÓLOGO') ||
              cbo.contains('NUTRICIONISTA') ||
              cbo.contains('PSIQUIATRA') ||
              cbo.contains('GINECOLOGISTA') ||
              cbo.contains('FISIOTERAPEUTA')) {
            cbo = cbo.replaceAll('CIRURGIAODENTISTA', 'CIRURGIÃO DENTISTA');
            cbo = cbo.replaceAll('CIRURGIAO DENTISTA', 'CIRURGIÃO DENTISTA');
            cbo = cbo.replaceAll(RegExp(r'\s+'), ' ').trim();

            if (cbo.startsWith('MEDICO ')) {
              cbo = cbo.replaceFirst('MEDICO ', 'MÉDICO ');
            }
            if (cbo.startsWith('PSICOLOGO ')) {
              cbo = cbo.replaceFirst('PSICOLOGO ', 'PSICÓLOGO ');
            }

            profissionais.add(CnesProfissional(
              nome: nome,
              especialidade: cbo,
            ));
          }
        }

        final sortedList = profissionais.toList()
          ..sort((a, b) => a.displayText.compareTo(b.displayText));
        return sortedList;
      }
      return [];
    } catch (e) {
      debugPrint('[CnesService] Exception ao buscar profissionais: $e');
      return [];
    }
  }

  static final SupabaseClient _supabase = Supabase.instance.client;

  /// Busca os horários de atendimento consultando diretamente o CNES com headers específicos.
  static Future<List<dynamic>> buscarHorariosAtendimento(int ibge7Digitos, int cnes7Digitos) async {
    try {
      String ibgeStr = ibge7Digitos.toString();
      if (ibgeStr.length == 7) {
        ibgeStr = ibgeStr.substring(0, 6);
      }
      final cnesStr = cnes7Digitos.toString().padLeft(7, '0');
      final id = '$ibgeStr$cnesStr';
      debugPrint('[CnesService] Buscando horários do ID completo: $id');

      // Obtém um cookie de sessão válido simulando o acesso à página principal
      final mainPageResponse = await _getWithRetry(
        Uri.parse('https://cnes.datasus.gov.br/pages/estabelecimentos/consulta.jsp'),
        {
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/146.0.0.0 Safari/537.36',
        },
      );
      if (mainPageResponse == null) return [];

      final cookies = mainPageResponse.headers['set-cookie'] ?? '';

      final uri = Uri.parse('https://cnes.datasus.gov.br/services/estabelecimentos/atendimento/$id');
      final response = await _getWithRetry(uri, {
        'Referer': 'https://cnes.datasus.gov.br/pages/estabelecimentos/consulta.jsp',
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/146.0.0.0 Safari/537.36',
        'Accept': 'application/json',
        if (cookies.isNotEmpty) 'Cookie': cookies,
      });
      if (response == null || response.statusCode != 200) {
        return [];
      }

      final data = jsonDecode(response.body);
      if (data is List) {
        return data;
      }
      return [];
    } catch (e) {
      debugPrint('[CnesService] Exception ao buscar horários: $e');
      return [];
    }
  }

  /// Busca todos os estabelecimentos de saúde de um município.
  ///
  /// [codigoUf] e [codigoMunicipio] filtram pelo município do paciente.
  /// [query] filtra localmente pelo texto digitado (vazio = retorna todos).
  /// [tipoUnidade] padrão 0 = todos os tipos; use 2 para UBS, 5 para PA, etc.
  static Future<List<CnesEstabelecimento>> buscarEstabelecimentos({
    required int codigoUf,
    required int codigoMunicipio,
    String query = '',
    int tipoUnidade = 0,
    int limit = 100,
  }) async {
    // A API do CNES usa o código IBGE de 6 dígitos (ignora o dígito verificador final)
    String codMunicipioStr = codigoMunicipio.toString();
    if (codMunicipioStr.length == 7) {
      codMunicipioStr = codMunicipioStr.substring(0, 6);
    }

    final params = <String, String>{
      'codigo_uf': codigoUf.toString(),
      'codigo_municipio': codMunicipioStr,
      'status': '1',
      'limit': limit.toString(),
      'offset': '0',
    };

    if (tipoUnidade > 0) {
      params['codigo_tipo_unidade'] = tipoUnidade.toString();
    }

    final uri = Uri.parse(_baseUrl).replace(queryParameters: params);

    const int maxAttempts = 3;
    const Duration retryDelay = Duration(milliseconds: 600);

    for (int attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        final response = await http
            .get(uri, headers: {'Accept': 'application/json'})
            .timeout(const Duration(seconds: 10));

        debugPrint('[CnesService] GET $uri (attempt $attempt)');
        debugPrint('[CnesService] Status: ${response.statusCode}');

        if (response.statusCode != 200) {
          debugPrint('[CnesService] Resposta não-200: ${response.body}');
          if (attempt < maxAttempts) await Future.delayed(retryDelay);
          continue;
        }

        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final lista = data['estabelecimentos'] as List<dynamic>? ?? [];
        debugPrint('[CnesService] Estabelecimentos recebidos: ${lista.length}');

        final todos = lista
            .map((e) => CnesEstabelecimento.fromJson(e as Map<String, dynamic>, ibge: codigoMunicipio))
            .toList();

        // Filtra localmente pelo texto digitado (a API não suporta busca por nome)
        final q = query.trim().toLowerCase();
        if (q.isEmpty) return todos;

        return todos
            .where(
              (e) =>
                  e.nomeFantasia.toLowerCase().contains(q) ||
                  e.endereco.toLowerCase().contains(q),
            )
            .toList();
      } catch (e, stack) {
        debugPrint('[CnesService] ERRO (attempt $attempt): $e');
        debugPrint('[CnesService] Stack: $stack');
        if (attempt < maxAttempts) {
          await Future.delayed(retryDelay);
          continue;
        }
        return [];
      }
    }

    return [];
  }
}
