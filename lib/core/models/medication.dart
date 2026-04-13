class Medication {
  final String id;
  final String name;
  final String dosage; // ex: 500mg 1x ao dia
  final List<TimeOfDayLite> times; // horários do dia
  int stockUnits; // unidades em casa

  Medication({
    required this.id,
    required this.name,
    required this.dosage,
    required this.times,
    required this.stockUnits,
  });
}

class TimeOfDayLite {
  final int hour;
  final int minute;
  const TimeOfDayLite(this.hour, this.minute);
}
