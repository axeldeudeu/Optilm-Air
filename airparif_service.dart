import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:csv/csv.dart';

class AirparifService {
  static const String _baseUrl = 'https://data.airparif.asso.fr/api/v2/';
  
  Future<List<Map<String, dynamic>>> getStationsData() async {
    try {
      // URL de l'API Airparif pour les stations
      final response = await http.get(Uri.parse('${_baseUrl}stations'));
      
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.cast<Map<String, dynamic>>();
      } else {
        throw Exception('Failed to load stations data');
      }
    } catch (e) {
      print('Error fetching Airparif data: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getMeasurements(String stationId) async {
    try {
      // URL de l'API Airparif pour les mesures
      final response = await http.get(
        Uri.parse('${_baseUrl}mesures?station=$stationId')
      );
      
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.cast<Map<String, dynamic>>();
      } else {
        throw Exception('Failed to load measurements data');
      }
    } catch (e) {
      print('Error fetching measurements: $e');
      return [];
    }
  }

  // Méthode pour parser un fichier CSV local
  Future<List<Map<String, dynamic>>> parseLocalCSV(String csvData) async {
    try {
      List<List<dynamic>> rowsAsListOfValues = const CsvToListConverter().convert(csvData);
      
      // Convertir en liste de maps
      List<Map<String, dynamic>> result = [];
      if (rowsAsListOfValues.isNotEmpty) {
        List<String> headers = rowsAsListOfValues[0].cast<String>();
        
        for (var i = 1; i < rowsAsListOfValues.length; i++) {
          Map<String, dynamic> row = {};
          for (var j = 0; j < headers.length; j++) {
            row[headers[j]] = rowsAsListOfValues[i][j];
          }
          result.add(row);
        }
      }
      return result;
    } catch (e) {
      print('Error parsing CSV: $e');
      return [];
    }
  }
} 