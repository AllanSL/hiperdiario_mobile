import 'dart:async';

import '../models/appointment.dart';
import '../models/medication.dart';
import '../models/patient.dart';

class MockSusService {
  Future<Patient> getPatient() async {
    await Future.delayed(const Duration(milliseconds: 400));
    return Patient(
      name: 'Allan Batista do Nascimento',
      cpf: '123.456.789-00',
      birthDate: DateTime(2001, 1, 16),
      diseases: const ['Hipertensão', 'Diabetes tipo 2'],
      contact: '(63) 99103-6533',
      ubs: 'UBS José Ronaldo',
      address: 'Rua 13, 284 - Dom Orione, Araguaína/TO',
      email: 'allanbatista2001@gmail.com',
      codigoUf: 17,
      siglaUf: 'TO',
      codigoMunicipio: 170388,
      nomeMunicipio: 'CARMOLANDIA',
    );
  }

  Future<List<Appointment>> getAppointments() async {
    await Future.delayed(const Duration(milliseconds: 400));
    final now = DateTime.now();
    return [
      Appointment(
        id: 'a1',
        dateTime: now.add(const Duration(days: 2, hours: 3)),
        location: 'UBS José Ronaldo',
        specialty: 'Cardiologia',
        notes: 'Levar exames de sangue',
      ),
      Appointment(
        id: 'a2',
        dateTime: now.add(const Duration(days: 10, hours: 1)),
        location: 'UBS José Ronaldo',
        specialty: 'Endocrinologia',
      ),
    ];
  }

  Future<List<Medication>> getMedications() async {
    await Future.delayed(const Duration(milliseconds: 400));
    return [
      Medication(
        id: 'm1',
        name: 'Losartana',
        dosage: '50mg duas vezes ao dia',
        times: const [TimeOfDayLite(8, 0), TimeOfDayLite(20, 0)],
        stockUnits: 20,
      ),
      Medication(
        id: 'm2',
        name: 'Metformina',
        dosage: '850mg após o almoço',
        times: const [TimeOfDayLite(13, 0)],
        stockUnits: 15,
      ),
    ];
  }

  Future<List<Medication>> syncMedicationStocks(List<Medication> current) async {
    // Simula atualização de estoque pela retirada na UBS
    await Future.delayed(const Duration(milliseconds: 600));
    return current
        .map((m) => Medication(
              id: m.id,
              name: m.name,
              dosage: m.dosage,
              times: m.times,
              stockUnits: m.stockUnits + 30, // recebeu nova caixa
            ))
        .toList();
  }
}
