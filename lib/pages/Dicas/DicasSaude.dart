import 'package:flutter/material.dart';

class HealthTipsPage extends StatelessWidget {
  const HealthTipsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dicas de saúde')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          Text(
            'Cuidados e orientações gerais',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 12),
          Text(
            'Este é um modelo de tela com dicas de saúde.\n\n'
            'Exemplos de conteúdos que podemos apresentar:\n'
            '• Alimentação equilibrada para hipertensão/diabetes\n'
            '• Rotina de atividade física leve\n'
            '• Sinais de alerta e quando procurar atendimento\n'
            '• Cuidados com medicação: horários e estoque\n'
            '• Acompanhamento regular na UBS',
          ),
        ],
      ),
    );
  }
}
