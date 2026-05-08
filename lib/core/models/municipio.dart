import 'package:flutter/foundation.dart';

/// Representa um município brasileiro.
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
    // Tratamento para API do Ministério da Saúde
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

/// Dados fixos dos 27 estados brasileiros.
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
