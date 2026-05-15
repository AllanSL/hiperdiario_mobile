import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../models/municipio.dart';

/// Serviço unificado para consulta de municípios.
/// Tenta buscar via API e utiliza o JSON local como fallback.
class MunicipioService {
  static const _saudeApiUrl =
      'https://apidadosabertos.saude.gov.br/macrorregiao-e-regiao-de-saude/municipio';

  static List<Municipio>? _jsonCache;

  /// Busca todos os municípios de um estado pela sigla da UF (ex: "TO").
  /// Prioriza a API do Ministério da Saúde e usa o JSON local se falhar.
  static Future<List<Municipio>> buscarMunicipios(String siglaUf) async {
    // 1. Tenta via API do Ministério da Saúde
    final apiMeds = await _buscarViaApiSaude(siglaUf);
    if (apiMeds.isNotEmpty) {
      debugPrint('[MunicipioService] Lista obtida via API Saúde');
      return apiMeds;
    }

    // 2. Se falhar, tenta via JSON local
    debugPrint('[MunicipioService] API falhou ou retornou vazia, tentando fallback via JSON');
    return await _buscarViaJson(siglaUf);
  }

  /// Busca um município específico pelo ID do IBGE.
  static Future<Municipio?> buscarMunicipioPorId(int idMunicipio) async {
    try {
      final todos = await _carregarTudoDoJson();
      // Se o ID tiver 7 dígitos (padrão IBGE com dígito verificador), 
      // tentamos encontrar pelo código de 6 dígitos que é o usado no JSON e em algumas APIs.
      final id6 = idMunicipio > 999999 ? idMunicipio ~/ 10 : idMunicipio;
      
      return todos.cast<Municipio?>().firstWhere(
            (m) => m?.codigoMunicipio == id6 || m?.codigoMunicipio == idMunicipio,
            orElse: () => null,
          );
    } catch (e) {
      debugPrint('[MunicipioService] Erro ao buscar município por ID: $e');
      return null;
    }
  }

  static Future<List<Municipio>> _buscarViaApiSaude(String siglaUf) async {
    final uri = Uri.parse(_saudeApiUrl).replace(
      queryParameters: {
        'sigla_uf': siglaUf.toUpperCase(),
        'limit': '1000',
        'offset': '0',
      },
    );

    try {
      final response = await http
          .get(uri, headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 8));

      if (response.statusCode != 200) return [];

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final lista =
          data['macrorregiao_regiao_saude_municipios'] as List<dynamic>? ?? [];

      final municipios = lista
          .map((e) => Municipio.fromJson(e as Map<String, dynamic>))
          .toList();

      return _processarLista(municipios);
    } catch (e) {
      debugPrint('[MunicipioService] Erro na API Saúde: $e');
      return [];
    }
  }

  static Future<List<Municipio>> _buscarViaJson(String siglaUf) async {
    try {
      final todos = await _carregarTudoDoJson();
      final upper = siglaUf.toUpperCase();
      final filtrados = todos
          .where((m) => m.siglaUf.toUpperCase() == upper)
          .toList();

      return _processarLista(filtrados);
    } catch (e) {
      debugPrint('[MunicipioService] Erro ao ler JSON: $e');
      return [];
    }
  }

  static Future<List<Municipio>> _carregarTudoDoJson() async {
    if (_jsonCache != null) return _jsonCache!;

    try {
      final data = await rootBundle.loadString('assets/data/municipios.json');
      final List<dynamic> jsonList = jsonDecode(data);
      _jsonCache = jsonList
          .map((e) => Municipio(
                codigoUf: e['codigo_uf'] ?? 0,
                siglaUf: e['sigla_uf'] ?? '',
                codigoMunicipio: e['codigo_municipio'] ?? 0,
                nome: e['nome'] ?? '',
              ))
          .toList();
      return _jsonCache!;
    } catch (e) {
      debugPrint('[MunicipioService] Erro ao carregar JSON de municípios: $e');
      return [];
    }
  }

  static List<Municipio> _processarLista(List<Municipio> lista) {
    // Ordena alfabeticamente
    lista.sort((a, b) => a.nome.compareTo(b.nome));

    // Remove duplicatas
    final vistos = <int>{};
    return lista.where((m) {
      if (vistos.contains(m.codigoMunicipio)) return false;
      vistos.add(m.codigoMunicipio);
      return true;
    }).toList();
  }
}
