import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/weather_data.dart';

class WeatherService {
  final String apiKey;
  final String baseUrl = 'https://api.openweathermap.org/data/2.5';
  
  WeatherService({required this.apiKey});
  
  // Constructeur sans clé API pour utiliser les données mockées
  WeatherService.mock() : apiKey = '';

  Future<WeatherData> getCurrentWeather(double latitude, double longitude) async {
    if (apiKey.isEmpty) {
      // Retourner des données mockées si pas de clé API
      return WeatherData.mock();
    }
    
    try {
      final url = Uri.parse('$baseUrl/weather?lat=$latitude&lon=$longitude&appid=$apiKey&units=metric&lang=fr');
      final response = await http.get(url);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return WeatherData.fromJson(data);
      } else {
        print('Erreur API OpenWeather: ${response.statusCode}');
        return WeatherData.mock();
      }
    } catch (e) {
      print('Erreur lors de la récupération des données météo: $e');
      return WeatherData.mock();
    }
  }

  Future<String> getLocationName(double latitude, double longitude) async {
    if (apiKey.isEmpty) {
      return 'Paris, France';
    }
    
    try {
      final url = Uri.parse('https://api.openweathermap.org/geo/1.0/reverse?lat=$latitude&lon=$longitude&limit=1&appid=$apiKey');
      final response = await http.get(url);
      
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        if (data.isNotEmpty) {
          final location = data[0];
          final String name = location['name'] ?? 'Inconnu';
          final String country = location['country'] ?? '';
          
          return '$name, $country';
        }
      }
      
      return 'Localisation inconnue';
    } catch (e) {
      print('Erreur lors de la récupération du nom de localisation: $e');
      return 'Localisation inconnue';
    }
  }
}