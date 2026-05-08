import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/municipio.dart';

class IbgeService {
  static const _baseUrl = 'https://servicodados.ibge.gov.br/api/v1/localidades';

  static Future<Municipio?> buscarMunicipioPorId({
    required int idMunicipio,
    required String siglaUf,
    required int codigoUf,
  }) async {
    final uri = Uri.parse('$_baseUrl/municipios/$idMunicipio');
    try {
      final response = await http.get(
        uri,
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode != 200) return null;

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final nome = (data['nome'] ?? '').toString().trim();
      if (nome.isEmpty) return null;

      return Municipio(
        codigoUf: codigoUf,
        siglaUf: siglaUf,
        codigoMunicipio: idMunicipio,
        nome: nome,
      );
    } catch (_) {
      return null;
    }
  }

  static Future<List<Municipio>> buscarMunicipiosPorEstado({
    required int codigoUf,
    required String siglaUf,
  }) async {
    final uri = Uri.parse('$_baseUrl/estados/$codigoUf/municipios');
    try {
      final response = await http.get(
        uri,
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode != 200) return [];

      final data = jsonDecode(response.body) as List<dynamic>;
      final municipios = data
          .map((item) => item as Map<String, dynamic>)
          .map((item) {
            final id = int.tryParse(item['id']?.toString() ?? '') ?? 0;
            final nome = (item['nome'] ?? '').toString().trim();
            if (id == 0 || nome.isEmpty) return null;
            return Municipio(
              codigoUf: codigoUf,
              siglaUf: siglaUf,
              codigoMunicipio: id,
              nome: nome,
            );
          })
          .whereType<Municipio>()
          .toList();

      municipios.sort((a, b) => a.nome.compareTo(b.nome));
      return municipios;
    } catch (_) {
      return [];
    }
  }
}
