import 'dart:convert';
import 'package:excel/excel.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../models/municipio.dart';

/// Serviço unificado para consulta de municípios.
/// Tenta buscar via API e utiliza o Excel local como fallback.
class MunicipioService {
  static const _saudeApiUrl =
      'https://apidadosabertos.saude.gov.br/macrorregiao-e-regiao-de-saude/municipio';

  static List<Municipio>? _excelCache;

  /// Busca todos os municípios de um estado pela sigla da UF (ex: "TO").
  /// Prioriza a API do Ministério da Saúde e usa o Excel local se falhar.
  static Future<List<Municipio>> buscarMunicipios(String siglaUf) async {
    // 1. Tenta via API do Ministério da Saúde
    final apiMeds = await _buscarViaApiSaude(siglaUf);
    if (apiMeds.isNotEmpty) {
      debugPrint('[MunicipioService] Lista obtida via API Saúde');
      return apiMeds;
    }

    // 2. Se falhar, tenta via Excel local
    debugPrint('[MunicipioService] API falhou, tentando fallback via Excel');
    return await _buscarViaExcel(siglaUf);
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

  static Future<List<Municipio>> _buscarViaExcel(String siglaUf) async {
    try {
      if (_excelCache == null) {
        final data = await rootBundle.load('CIDADES COMPLETO.xlsx');
        final bytes = data.buffer.asUint8List();
        final excel = Excel.decodeBytes(bytes);

        final sheet = excel.tables.values.firstOrNull;
        if (sheet == null || sheet.rows.isEmpty) return [];

        final headerMap = _mapearCabecalhos(sheet.rows.first);
        final listaExcel = <Municipio>[];

        for (var i = 1; i < sheet.rows.length; i++) {
          final row = sheet.rows[i];
          final nome = _lerTexto(row, headerMap['nome']);
          if (nome.isEmpty) continue;

          final sigla = _lerTexto(row, headerMap['sigla_uf']);
          final codigoUf = _lerInteiro(row, headerMap['id_uf']);
          final codigoMunicipio6 = _lerInteiro(row, headerMap['id_municipio_6']);
          final codigoMunicipio7 = _lerInteiro(row, headerMap['id_municipio']);

          if (sigla.isEmpty && codigoUf == null) continue;
          
          // Padroniza para 6 dígitos (formato usado nas APIs de saúde)
          final codigoMunicipio =
              codigoMunicipio6 ??
              (codigoMunicipio7 != null ? (codigoMunicipio7 ~/ 10) : null);
              
          if (codigoMunicipio == null) continue;

          listaExcel.add(
            Municipio(
              codigoUf: codigoUf ?? 0,
              siglaUf: sigla,
              codigoMunicipio: codigoMunicipio,
              nome: nome,
            ),
          );
        }
        _excelCache = listaExcel;
      }

      final upper = siglaUf.toUpperCase();
      final filtrados = _excelCache!
          .where((m) => m.siglaUf.toUpperCase() == upper)
          .toList();

      return _processarLista(filtrados);
    } catch (e) {
      debugPrint('[MunicipioService] Erro ao ler Excel: $e');
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

  static Map<String, int> _mapearCabecalhos(List<Data?> headerRow) {
    final headers = <String, int>{};
    for (var i = 0; i < headerRow.length; i++) {
      final val = headerRow[i]?.value?.toString() ?? '';
      if (val.isEmpty) continue;
      headers[_normalizar(val)] = i;
    }

    int? pick(List<String> keys) {
      for (final key in keys) {
        if (headers.containsKey(key)) return headers[key];
      }
      return null;
    }

    return {
      'nome': pick(['nome', 'municipio', 'cidade']) ?? -1,
      'sigla_uf': pick(['sigla_uf', 'uf', 'estado']) ?? -1,
      'id_uf': pick(['id_uf', 'codigo_uf', 'cod_uf', 'ibge_uf']) ?? -1,
      'id_municipio_6': pick(['id_municipio_6', 'codigo_municipio_6', 'cod_municipio_6', 'ibge_municipio']) ?? -1,
      'id_municipio': pick(['id_municipio', 'codigo_municipio', 'cod_municipio', 'ibge_municipio_7']) ?? -1,
    };
  }

  static String _normalizar(String input) => input
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'\s+'), '_')
      .replaceAll(RegExp(r'[^a-z0-9_]'), '');

  static String _lerTexto(List<Data?> row, int? index) {
    if (index == null || index < 0 || index >= row.length) return '';
    return row[index]?.value?.toString().trim() ?? '';
  }

  static int? _lerInteiro(List<Data?> row, int? index) {
    if (index == null || index < 0 || index >= row.length) return null;
    final raw = row[index]?.value?.toString().trim() ?? '';
    if (raw.isEmpty) return null;
    return int.tryParse(raw.replaceAll(RegExp(r'\D'), ''));
  }
}
