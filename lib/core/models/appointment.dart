class Appointment {
  final String id;
  final DateTime dateTime;
  final String location;
  final String specialty; // Especialidade (ex: Cardiologia, Clínico Geral)
  final String? notes; // Observações opcionais
  final bool? attended; // null: não ocorreu ainda, true: compareceu, false: faltou

  Appointment({
    required this.id,
    required this.dateTime,
    required this.location,
    required this.specialty,
    this.notes,
    this.attended,
  });

  Appointment copyWith({
    String? id,
    DateTime? dateTime,
    String? location,
    String? specialty,
    String? notes,
    bool? attended,
  }) {
    return Appointment(
      id: id ?? this.id,
      dateTime: dateTime ?? this.dateTime,
      location: location ?? this.location,
      specialty: specialty ?? this.specialty,
      notes: notes ?? this.notes,
      attended: attended ?? this.attended,
    );
  }
}
