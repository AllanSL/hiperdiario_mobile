enum AppointmentShift { morning, afternoon }

extension AppointmentShiftX on AppointmentShift {
  String get dbValue => switch (this) {
    AppointmentShift.morning => 'morning',
    AppointmentShift.afternoon => 'afternoon',
  };

  String get label => switch (this) {
    AppointmentShift.morning => 'Manhã',
    AppointmentShift.afternoon => 'Tarde',
  };

  static AppointmentShift fromDb(String? value) {
    switch ((value ?? '').toLowerCase()) {
      case 'afternoon':
      case 'tarde':
        return AppointmentShift.afternoon;
      case 'morning':
      case 'manha':
      case 'manhã':
      default:
        return AppointmentShift.morning;
    }
  }
}

class Appointment {
  final String id;
  final DateTime dateTime;
  final String location;
  final String specialty; // Especialidade (ex: Cardiologia, Clínico Geral)
  final String? professionalName;
  final String? professionalId;
  final AppointmentShift shift;
  final String? notes; // Observações opcionais
  final bool?
  attended; // null: não ocorreu ainda, true: compareceu, false: faltou

  Appointment({
    required this.id,
    required this.dateTime,
    required this.location,
    required this.specialty,
    this.professionalName,
    this.professionalId,
    this.shift = AppointmentShift.morning,
    this.notes,
    this.attended,
  });

  Appointment copyWith({
    String? id,
    DateTime? dateTime,
    String? location,
    String? specialty,
    String? professionalName,
    String? professionalId,
    AppointmentShift? shift,
    String? notes,
    bool? attended,
  }) {
    return Appointment(
      id: id ?? this.id,
      dateTime: dateTime ?? this.dateTime,
      location: location ?? this.location,
      specialty: specialty ?? this.specialty,
      professionalName: professionalName ?? this.professionalName,
      professionalId: professionalId ?? this.professionalId,
      shift: shift ?? this.shift,
      notes: notes ?? this.notes,
      attended: attended ?? this.attended,
    );
  }
}
