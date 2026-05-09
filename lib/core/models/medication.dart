class Medication {
  final String id;
  final String name;
  final String dosage; // ex: 500mg 1x ao dia
  final List<TimeOfDayLite> times; // horários do dia
  final int stockUnits; // unidades em casa
  final String?
  dispensationId; // Identificador da UBS, se nulo = criado pelo paciente.
  final String syncStatus; // 'synced' or 'pending'

  Medication({
    required this.id,
    required this.name,
    required this.dosage,
    required this.times,
    required this.stockUnits,
    this.dispensationId,
    this.syncStatus = 'synced',
  });

  Medication copyWith({
    String? id,
    String? name,
    String? dosage,
    List<TimeOfDayLite>? times,
    int? stockUnits,
    String? dispensationId,
    String? syncStatus,
  }) {
    return Medication(
      id: id ?? this.id,
      name: name ?? this.name,
      dosage: dosage ?? this.dosage,
      times: times ?? this.times,
      stockUnits: stockUnits ?? this.stockUnits,
      dispensationId: dispensationId ?? this.dispensationId,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }
}

class TimeOfDayLite {
  final int hour;
  final int minute;
  const TimeOfDayLite(this.hour, this.minute);
}

class PendingDispensation {
  final String id;
  final String activePrinciple;
  final String strength;
  final String form;
  final int dispensedQuantity;
  final DateTime dispensedAt;
  final String prescribingDoctor;
  final int frequencyPerDay;
  final String? frequencyLabel;
  final List<String> scheduledTimes;

  PendingDispensation({
    required this.id,
    required this.activePrinciple,
    required this.strength,
    required this.form,
    required this.dispensedQuantity,
    required this.dispensedAt,
    required this.prescribingDoctor,
    required this.frequencyPerDay,
    this.frequencyLabel,
    this.scheduledTimes = const [],
  });
}
