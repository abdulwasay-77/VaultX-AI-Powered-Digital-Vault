import 'package:http/http.dart' as http;
import 'dart:convert';

void main() async {
  print('Testing API connection...');

  try {
    final response = await http.get(
      Uri.parse('http://localhost:8000/api/auth/users'),
    );

    print('Status: ${response.statusCode}');
    print('Body: ${response.body}');

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      print('Parsed successfully! Found ${data.length} users');
    }
  } catch (e) {
    print('Error: $e');
  }
}
