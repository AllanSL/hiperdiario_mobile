import 'emergency_contact.dart';

class Patient {
  final String name;
  final String cpf;
  final DateTime birthDate;
  final List<String> diseases; // hipertensão, diabetes, etc.
  final String contact; // telefone principal
  final String ubs; // UBS de referência (código ou nome fallback)
  final String? ubsName; // Nome da UBS resolvido, caso disponível
  final String? address; // endereço residencial (opcional)
  final String? email; // e-mail de contato (opcional)
  final EmergencyContact? emergencyContact; // contato próximo (opcional)

  // Localização do paciente (usado para filtrar estabelecimentos CNES)
  final int? codigoUf; // código IBGE da UF, ex: 17
  final String? siglaUf; // sigla da UF, ex: "TO"
  final int? codigoMunicipio; // código IBGE do município, ex: 170388
  final String? nomeMunicipio; // nome do município, ex: "CARMOLANDIA"

  Patient({
    required this.name,
    required this.cpf,
    required this.birthDate,
    required this.diseases,
    required this.contact,
    required this.ubs,
    this.ubsName,
    this.address,
    this.email,
    this.emergencyContact,
    this.codigoUf,
    this.siglaUf,
    this.codigoMunicipio,
    this.nomeMunicipio,
  });

  Patient copyWith({
    String? contact,
    String? ubs,
    String? ubsName,
    String? address,
    String? email,
    EmergencyContact? emergencyContact,
    bool clearEmergencyContact = false,
    int? codigoUf,
    String? siglaUf,
    int? codigoMunicipio,
    String? nomeMunicipio,
    bool clearLocalizacao = false,
  }) {
    return Patient(
      name: name,
      cpf: cpf,
      birthDate: birthDate,
      diseases: diseases,
      contact: contact ?? this.contact,
      ubs: ubs ?? this.ubs,
      ubsName: ubsName ?? this.ubsName,
      address: address ?? this.address,
      email: email ?? this.email,
      emergencyContact: clearEmergencyContact
          ? null
          : (emergencyContact ?? this.emergencyContact),
      codigoUf: clearLocalizacao ? null : (codigoUf ?? this.codigoUf),
      siglaUf: clearLocalizacao ? null : (siglaUf ?? this.siglaUf),
      codigoMunicipio: clearLocalizacao
          ? null
          : (codigoMunicipio ?? this.codigoMunicipio),
      nomeMunicipio: clearLocalizacao
          ? null
          : (nomeMunicipio ?? this.nomeMunicipio),
    );
  }
}
