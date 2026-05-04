import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:flutter/services.dart';

import 'municipio_service.dart';

class MunicipioLocalService {
  static List<Municipio>? _cache;

  static Future<List<Municipio>> buscarMunicipios(String siglaUf) async {
    _cache ??= await _carregarMunicipios();

    final upper = siglaUf.toUpperCase();
    return _cache!
        .where((m) => m.siglaUf.toUpperCase() == upper)
        .toList(growable: false);
  }

  static Future<List<Municipio>> _carregarMunicipios() async {
    final data = await rootBundle.load('CIDADES COMPLETO.xlsx');
    final bytes = data.buffer.asUint8List();
    final excel = Excel.decodeBytes(bytes);

    final municipios = <Municipio>[];
    final sheet = excel.tables.values.firstOrNull;
    if (sheet == null || sheet.rows.isEmpty) {
      return municipios;
    }

    final headerRow = sheet.rows.first;
    final headerMap = _mapearCabecalhos(headerRow);

    for (var i = 1; i < sheet.rows.length; i++) {
      final row = sheet.rows[i];
      final nome = _lerTexto(row, headerMap['nome']);
      if (nome.isEmpty) continue;

      final sigla = _lerTexto(row, headerMap['sigla_uf']);
      final codigoUf = _lerInteiro(row, headerMap['id_uf']);
      final codigoMunicipio6 = _lerInteiro(row, headerMap['id_municipio_6']);
      final codigoMunicipio7 = _lerInteiro(row, headerMap['id_municipio']);

      if (sigla.isEmpty && codigoUf == null) continue;
      final codigoMunicipio =
          codigoMunicipio6 ??
          (codigoMunicipio7 != null ? (codigoMunicipio7 ~/ 10) : null);
      if (codigoMunicipio == null) continue;

      municipios.add(
        Municipio(
          codigoUf: codigoUf ?? 0,
          siglaUf: sigla,
          codigoMunicipio: codigoMunicipio,
          nome: nome,
        ),
      );
    }

    final vistos = <int>{};
    final unicos = municipios.where((m) {
      if (vistos.contains(m.codigoMunicipio)) return false;
      vistos.add(m.codigoMunicipio);
      return true;
    }).toList();

    unicos.sort((a, b) => a.nome.compareTo(b.nome));
    return unicos;
  }

  static Map<String, int> _mapearCabecalhos(List<Data?> headerRow) {
    final headers = <String, int>{};
    for (var i = 0; i < headerRow.length; i++) {
      final raw = headerRow[i]?.value?.toString() ?? '';
      if (raw.isEmpty) continue;
      headers[_normalizar(raw)] = i;
    }

    int? pick(List<String> keys) {
      for (final key in keys) {
        final idx = headers[key];
        if (idx != null) return idx;
      }
      return null;
    }

    return {
      'nome': pick(['nome', 'municipio', 'cidade']) ?? -1,
      'sigla_uf': pick(['sigla_uf', 'uf', 'estado']) ?? -1,
      'id_uf': pick(['id_uf', 'codigo_uf', 'cod_uf', 'ibge_uf']) ?? -1,
      'id_municipio_6':
          pick([
            'id_municipio_6',
            'codigo_municipio_6',
            'cod_municipio_6',
            'ibge_municipio',
          ]) ??
          -1,
      'id_municipio':
          pick([
            'id_municipio',
            'codigo_municipio',
            'cod_municipio',
            'ibge_municipio_7',
            'codigo_municipio_7',
            'cod_municipio_7',
          ]) ??
          -1,
    };
  }

  static String _normalizar(String input) {
    return input
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), '_')
        .replaceAll(RegExp(r'[^a-z0-9_]'), '');
  }

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

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
