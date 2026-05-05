import 'dart:convert';
import 'package:http/http.dart' as http;

Future<void> main() async {
  try {
    final id = '1703882469588';
    final uri = Uri.parse('https://cnes.datasus.gov.br/services/estabelecimentos-profissionais/$id');
    final response = await http.get(uri, headers: {
      'Referer': 'https://cnes.datasus.gov.br/',
      'Accept': 'application/json',
    });

    if (response.statusCode == 200) {
      final body = response.body;
      print('Status: 200 OK');
      print('First 1000 chars of body: ${body.substring(0, body.length > 1000 ? 1000 : body.length)}');
    } else {
      print('Status: ${response.statusCode}');
    }
  } catch (e) {
    print('Error: $e');
  }
}
