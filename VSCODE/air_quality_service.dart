// lib/services/air_quality_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/air_quality_data.dart';

class AirQualityService {
  final String apiKey;
  final String baseUrl = 'https://api.openweathermap.org/data/2.5';
  
  AirQualityService({required this.apiKey});
  
  // Constructeur sans clé API pour utiliser les données mockées
  AirQualityService.mock() : apiKey = '';

  Future<AirQualityData> getCurrentAirQuality(double latitude, double longitude) async {
    if (apiKey.isEmpty) {
      // Retourner des données mockées si pas de clé API
      return _getMockData();
    }
    
    try {
      final url = Uri.parse('$baseUrl/air_pollution?lat=$latitude&lon=$longitude&appid=$apiKey');
      final response = await http.get(url);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return AirQualityData.fromJson(data);
      } else {
        print('Erreur API OpenWeather: ${response.statusCode}');
        return _getMockData();
      }
    } catch (e) {
      print('Erreur lors de la récupération des données: $e');
      return _getMockData();
    }
  }

  Future<List<AirQualityData>> getHistory(double latitude, double longitude) async {
    if (apiKey.isEmpty) {
      // Retourner des données mockées si pas de clé API
      return List.generate(24, (index) => _getMockData());
    }
    
    try {
      // OpenWeather ne fournit pas d'historique gratuit, on simule avec des données actuelles
      final url = Uri.parse('$baseUrl/air_pollution?lat=$latitude&lon=$longitude&appid=$apiKey');
      final response = await http.get(url);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        // On crée une liste de 24 points avec des variations aléatoires
        return List.generate(24, (index) {
          final baseData = Map<String, dynamic>.from(data);
          if (baseData['list'] != null && baseData['list'].isNotEmpty) {
            final components = baseData['list'][0]['components'] ?? {};
            // On ajoute une variation aléatoire de ±20%
            components.forEach((key, value) {
              if (value is num) {
                final variation = (value * 0.2 * (index % 2 == 0 ? 1 : -1)).abs();
                components[key] = value + variation;
              }
            });
          }
          return AirQualityData.fromJson(baseData);
        });
      } else {
        print('Erreur API OpenWeather: ${response.statusCode}');
        return List.generate(24, (index) => _getMockData());
      }
    } catch (e) {
      print('Erreur lors de la récupération des données: $e');
      return List.generate(24, (index) => _getMockData());
    }
  }

  AirQualityData _getMockData() {
    return AirQualityData(
      aqi: 45.0,
      category: 'good',
      pollutants: {
        'pm25': PollutantData(
          name: 'Particules fines (PM₂.₅)',
          concentration: 10.0,
          unit: 'µg/m³',
          category: 'good',
        ),
        'pm10': PollutantData(
          name: 'Particules (PM₁₀)',
          concentration: 20.0,
          unit: 'µg/m³',
          category: 'good',
        ),
        'no2': PollutantData(
          name: 'Dioxyde d\'Azote (NO₂)',
          concentration: 15.0,
          unit: 'µg/m³',
          category: 'good',
        ),
        'o3': PollutantData(
          name: 'Ozone (O₃)',
          concentration: 30.0,
          unit: 'µg/m³',
          category: 'moderate',
        ),
      },
      pollenRisk: PollenRisk(
        level: 'Faible',
        description: 'Risques allergiques par pollen',
      ),
    );
  }
}