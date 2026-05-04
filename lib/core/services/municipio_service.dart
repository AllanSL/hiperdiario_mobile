import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Representa um município brasileiro retornado pela API do Ministério da Saúde.
class Municipio {
  final int codigoUf;
  final String siglaUf;
  final int codigoMunicipio;
  final String nome;

  const Municipio({
    required this.codigoUf,
    required this.siglaUf,
    required this.codigoMunicipio,
    required this.nome,
  });

  factory Municipio.fromJson(Map<String, dynamic> json) {
    // O campo "municipio" vem como "TO - ABREULANDIA" — removemos o prefixo "XX - "
    final raw = (json['municipio'] as String? ?? '').trim();
    final nome = raw.contains(' - ')
        ? raw.substring(raw.indexOf(' - ') + 3).trim()
        : raw;

    return Municipio(
      codigoUf: int.tryParse(json['codigo_uf']?.toString() ?? '') ?? 0,
      siglaUf: (json['uf'] as String? ?? '').trim(),
      codigoMunicipio:
          int.tryParse(json['codigo_municipio']?.toString() ?? '') ?? 0,
      nome: nome,
    );
  }

  @override
  String toString() => nome;
}

/// Dados fixos dos 27 estados brasileiros (sigla + nome + código IBGE da UF).
class EstadoBrasileiro {
  final String sigla;
  final String nome;
  final int codigoIbge;

  const EstadoBrasileiro({
    required this.sigla,
    required this.nome,
    required this.codigoIbge,
  });

  @override
  String toString() => '$sigla — $nome';
}

const List<EstadoBrasileiro> estadosBrasileiros = [
  EstadoBrasileiro(sigla: 'AC', nome: 'Acre', codigoIbge: 12),
  EstadoBrasileiro(sigla: 'AL', nome: 'Alagoas', codigoIbge: 27),
  EstadoBrasileiro(sigla: 'AP', nome: 'Amapá', codigoIbge: 16),
  EstadoBrasileiro(sigla: 'AM', nome: 'Amazonas', codigoIbge: 13),
  EstadoBrasileiro(sigla: 'BA', nome: 'Bahia', codigoIbge: 29),
  EstadoBrasileiro(sigla: 'CE', nome: 'Ceará', codigoIbge: 23),
  EstadoBrasileiro(sigla: 'DF', nome: 'Distrito Federal', codigoIbge: 53),
  EstadoBrasileiro(sigla: 'ES', nome: 'Espírito Santo', codigoIbge: 32),
  EstadoBrasileiro(sigla: 'GO', nome: 'Goiás', codigoIbge: 52),
  EstadoBrasileiro(sigla: 'MA', nome: 'Maranhão', codigoIbge: 21),
  EstadoBrasileiro(sigla: 'MT', nome: 'Mato Grosso', codigoIbge: 51),
  EstadoBrasileiro(sigla: 'MS', nome: 'Mato Grosso do Sul', codigoIbge: 50),
  EstadoBrasileiro(sigla: 'MG', nome: 'Minas Gerais', codigoIbge: 31),
  EstadoBrasileiro(sigla: 'PA', nome: 'Pará', codigoIbge: 15),
  EstadoBrasileiro(sigla: 'PB', nome: 'Paraíba', codigoIbge: 25),
  EstadoBrasileiro(sigla: 'PR', nome: 'Paraná', codigoIbge: 41),
  EstadoBrasileiro(sigla: 'PE', nome: 'Pernambuco', codigoIbge: 26),
  EstadoBrasileiro(sigla: 'PI', nome: 'Piauí', codigoIbge: 22),
  EstadoBrasileiro(sigla: 'RJ', nome: 'Rio de Janeiro', codigoIbge: 33),
  EstadoBrasileiro(sigla: 'RN', nome: 'Rio Grande do Norte', codigoIbge: 24),
  EstadoBrasileiro(sigla: 'RS', nome: 'Rio Grande do Sul', codigoIbge: 43),
  EstadoBrasileiro(sigla: 'RO', nome: 'Rondônia', codigoIbge: 11),
  EstadoBrasileiro(sigla: 'RR', nome: 'Roraima', codigoIbge: 14),
  EstadoBrasileiro(sigla: 'SC', nome: 'Santa Catarina', codigoIbge: 42),
  EstadoBrasileiro(sigla: 'SP', nome: 'São Paulo', codigoIbge: 35),
  EstadoBrasileiro(sigla: 'SE', nome: 'Sergipe', codigoIbge: 28),
  EstadoBrasileiro(sigla: 'TO', nome: 'Tocantins', codigoIbge: 17),
];

/// Serviço para consulta de municípios via API do Ministério da Saúde.
class MunicipioService {
  static const _baseUrl =
      'https://apidadosabertos.saude.gov.br/macrorregiao-e-regiao-de-saude/municipio';

  /// Busca todos os municípios de um estado pela sigla da UF (ex: "TO").
  /// Retorna a lista em ordem alfabética.
  static Future<List<Municipio>> buscarMunicipios(String siglaUf) async {
    final uri = Uri.parse(_baseUrl).replace(
      queryParameters: {
        'sigla_uf': siglaUf.toUpperCase(),
        'limit': '1000',
        'offset': '0',
      },
    );

    const int maxAttempts = 3;
    const Duration retryDelay = Duration(milliseconds: 600);

    for (int attempt = 1; attempt <= maxAttempts; attempt++) {
      debugPrint('[MunicipioService] GET $uri (attempt $attempt)');
      try {
        final response = await http
            .get(uri, headers: {'Accept': 'application/json'})
            .timeout(const Duration(seconds: 15));

        debugPrint('[MunicipioService] Status: ${response.statusCode}');

        if (response.statusCode != 200) {
          debugPrint(
            '[MunicipioService] Erro ${response.statusCode}: ${response.body}',
          );
          // Retentar se ainda houver tentativas
          if (attempt < maxAttempts) await Future.delayed(retryDelay);
          continue;
        }

        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final lista =
            data['macrorregiao_regiao_saude_municipios'] as List<dynamic>? ??
            [];

        debugPrint('[MunicipioService] Municípios recebidos: ${lista.length}');

        final municipios = lista
            .map((e) => Municipio.fromJson(e as Map<String, dynamic>))
            .toList();

        // Ordena alfabeticamente pelo nome
        municipios.sort((a, b) => a.nome.compareTo(b.nome));

        // Remove duplicatas (mesmo município pode aparecer em múltiplas regiões de saúde)
        final vistos = <int>{};
        final unicos = municipios.where((m) {
          if (vistos.contains(m.codigoMunicipio)) return false;
          vistos.add(m.codigoMunicipio);
          return true;
        }).toList();

        debugPrint('[MunicipioService] Municípios únicos: ${unicos.length}');
        return unicos;
      } catch (e, stack) {
        debugPrint('[MunicipioService] ERRO (attempt $attempt): $e');
        debugPrint('[MunicipioService] Stack: $stack');
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
