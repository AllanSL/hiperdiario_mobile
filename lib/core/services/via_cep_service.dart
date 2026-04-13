import 'dart:convert';

import 'package:http/http.dart' as http;

class ViaCepAddress {
  final String uf;
  final String localidade;
  final String logradouro;
  final String bairro;
  final String complemento;
  final int? codigoIbge;

  const ViaCepAddress({
    required this.uf,
    required this.localidade,
    required this.logradouro,
    required this.bairro,
    required this.complemento,
    this.codigoIbge,
  });
}

class ViaCepService {
  static Future<ViaCepAddress> buscarEndereco(String cep) async {
    final digits = cep.replaceAll(RegExp(r'\D'), '');
    if (digits.length != 8) {
      throw Exception('CEP inválido.');
    }

    final uri = Uri.parse('https://viacep.com.br/ws/$digits/json/');
    final response = await http.get(uri, headers: {'Accept': 'application/json'});

    if (response.statusCode != 200) {
      throw Exception('Erro ao consultar CEP.');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (data['erro'] == true) {
      throw Exception('CEP não encontrado.');
    }

  final uf = (data['uf'] ?? '').toString();
  final localidade = (data['localidade'] ?? '').toString();
  final logradouro = (data['logradouro'] ?? '').toString().trim();
  final bairro = (data['bairro'] ?? '').toString().trim();
  final complemento = (data['complemento'] ?? '').toString().trim();
  final ibgeRaw = (data['ibge'] ?? '').toString().trim();
  final ibgeDigits = ibgeRaw.replaceAll(RegExp(r'\D'), '');
  final codigoIbge = int.tryParse(ibgeDigits);
    if (uf.isEmpty || localidade.isEmpty) {
      throw Exception('Resposta inválida do ViaCEP.');
    }

    return ViaCepAddress(
      uf: uf,
      localidade: localidade,
      logradouro: logradouro,
      bairro: bairro,
      complemento: complemento,
      codigoIbge: codigoIbge,
    );
  }
}
