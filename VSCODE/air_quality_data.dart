// lib/models/air_quality_model.dart

class AirQualityData {
  final double aqi;
  final String category;
  final Map<String, PollutantData> pollutants;
  final PollenRisk pollenRisk; // Ajouté pour correspondre à notre UI

  AirQualityData({
    required this.aqi,
    required this.category,
    required this.pollutants,
    required this.pollenRisk,
  });

  factory AirQualityData.fromJson(Map<String, dynamic> json) {
    // OpenWeather API: les données sont dans json['list'][0]
    final data = json['list'] != null && json['list'].isNotEmpty ? json['list'][0] : {};
    final components = data['components'] ?? {};
    final main = data['main'] ?? {};
    
    // Conversion de l'index AQI d'OpenWeather (1-5) en une valeur plus standard (0-500)
    final aqi = (main['aqi'] ?? 1) * 100.0;
    
    // Conversion de l'index en catégorie
    String category;
    switch (main['aqi']) {
      case 1:
        category = 'good';
        break;
      case 2:
        category = 'moderate';
        break;
      case 3:
        category = 'unhealthy for sensitive groups';
        break;
      case 4:
        category = 'unhealthy';
        break;
      case 5:
        category = 'very unhealthy';
        break;
      default:
        category = 'moderate';
    }
    
    // Extraction des polluants
    final pollutants = <String, PollutantData>{};
    if (components.isNotEmpty) {
      pollutants['pm25'] = PollutantData(
        name: 'Particules fines (PM₂.₅)',
        concentration: components['pm2_5']?.toDouble() ?? 0.0,
        unit: 'µg/m³',
        category: _getCategoryFromValue(components['pm2_5']?.toDouble() ?? 0.0, 'pm25'),
      );
      
      pollutants['pm10'] = PollutantData(
        name: 'Particules (PM₁₀)',
        concentration: components['pm10']?.toDouble() ?? 0.0,
        unit: 'µg/m³',
        category: _getCategoryFromValue(components['pm10']?.toDouble() ?? 0.0, 'pm10'),
      );
      
      pollutants['no2'] = PollutantData(
        name: 'Dioxyde d\'Azote (NO₂)',
        concentration: components['no2']?.toDouble() ?? 0.0,
        unit: 'µg/m³',
        category: _getCategoryFromValue(components['no2']?.toDouble() ?? 0.0, 'no2'),
      );
      
      pollutants['o3'] = PollutantData(
        name: 'Ozone (O₃)',
        concentration: components['o3']?.toDouble() ?? 0.0,
        unit: 'µg/m³',
        category: _getCategoryFromValue(components['o3']?.toDouble() ?? 0.0, 'o3'),
      );
    }
    
    // On ajoute un risque pollen par défaut (données non disponibles dans l'API OpenWeather)
    final pollenRisk = PollenRisk(
      level: 'Faible',
      description: 'Risques allergiques par pollen',
    );
    
    return AirQualityData(
      aqi: aqi,
      category: category,
      pollutants: pollutants,
      pollenRisk: pollenRisk,
    );
  }
  
  // Méthode utilitaire pour déterminer la catégorie en fonction de la valeur du polluant
  static String _getCategoryFromValue(double value, String pollutant) {
    switch (pollutant) {
      case 'pm25':
        if (value <= 12) return 'good';
        if (value <= 35.4) return 'moderate';
        if (value <= 55.4) return 'unhealthy for sensitive groups';
        if (value <= 150.4) return 'unhealthy';
        if (value <= 250.4) return 'very unhealthy';
        return 'hazardous';
      case 'pm10':
        if (value <= 54) return 'good';
        if (value <= 154) return 'moderate';
        if (value <= 254) return 'unhealthy for sensitive groups';
        if (value <= 354) return 'unhealthy';
        if (value <= 424) return 'very unhealthy';
        return 'hazardous';
      case 'no2':
        if (value <= 53) return 'good';
        if (value <= 100) return 'moderate';
        if (value <= 360) return 'unhealthy for sensitive groups';
        if (value <= 649) return 'unhealthy';
        if (value <= 1249) return 'very unhealthy';
        return 'hazardous';
      case 'o3':
        if (value <= 54) return 'good';
        if (value <= 70) return 'moderate';
        if (value <= 85) return 'unhealthy for sensitive groups';
        if (value <= 105) return 'unhealthy';
        if (value <= 200) return 'very unhealthy';
        return 'hazardous';
      default:
        return 'moderate';
    }
  }
  
  // Conversion de la catégorie en niveau compréhensible en français
  String get level {
    switch (category.toLowerCase()) {
      case 'good':
        return 'Bonne';
      case 'moderate':
        return 'Moyenne';
      case 'unhealthy for sensitive groups':
        return 'Attention ';
      case 'unhealthy':
        return 'Mauvaise';
      case 'very unhealthy':
        return 'Très mauvaise';
      case 'hazardous':
        return 'Dangereuse';
      default:
        return 'Moyenne';
    }
  }
  
  // Emoji correspondant au niveau de qualité de l'air
  String get emoji {
    switch (category.toLowerCase()) {
      case 'good':
        return '😀';
      case 'moderate':
        return '😐';
      case 'unhealthy for sensitive groups':
        return '🙁';
      case 'unhealthy':
        return '😷';
      case 'very unhealthy':
        return '🤢';
      case 'hazardous':
        return '☠️';
      default:
        return '😐';
    }
  }
  
  // Méthode utilitaire pour obtenir la couleur en fonction du niveau
  int get colorCode {
    switch (category.toLowerCase()) {
      case 'good':
        return 0xFF00E400; // Vert
      case 'moderate':
        return 0xFFFFFF00; // Jaune
      case 'unhealthy for sensitive groups':
        return 0xFFFF7E00; // Orange
      case 'unhealthy':
        return 0xFFFF0000; // Rouge
      case 'very unhealthy':
        return 0xFF8F3F97; // Violet
      case 'hazardous':
        return 0xFF7E0023; // Marron
      default:
        return 0xFF60C5BA; // Couleur par défaut
    }
  }
}

class PollutantData {
  final double concentration;
  final String unit;
  final String category;
  final String name; // Ajouté pour l'affichage

  PollutantData({
    required this.concentration,
    required this.unit,
    required this.category,
    required this.name,
  });

  factory PollutantData.fromJson(Map<String, dynamic> json) {
    String name;
    // Attribution d'un nom lisible en fonction du code
    switch (json['code']) {
      case 'pm25':
        name = 'Particules fines (PM₂.₅)';
        break;
      case 'pm10':
        name = 'Particules (PM₁₀)';
        break;
      case 'no2':
        name = 'Dioxyde d\'Azote (NO₂)';
        break;
      case 'o3':
        name = 'Ozone (O₃)';
        break;
      case 'so2':
        name = 'Dioxyde de Soufre (SO₂)';
        break;
      case 'co':
        name = 'Monoxyde de Carbone (CO)';
        break;
      default:
        name = json['displayName'] ?? json['code'];
    }
    
    return PollutantData(
      concentration: json['concentration']['value'].toDouble(),
      unit: json['concentration']['units'],
      category: json['category'] ?? '',
      name: name,
    );
  }
  
  // Conversion de la catégorie en niveau compréhensible en français
  String get quality {
    switch (category.toLowerCase()) {
      case 'good':
        return 'Bonne';
      case 'moderate':
        return 'Moyenne';
      case 'unhealthy for sensitive groups':
        return 'Mauvaise pour les groupes sensibles';
      case 'unhealthy':
        return 'Mauvaise';
      case 'very unhealthy':
        return 'Très mauvaise';
      case 'hazardous':
        return 'Dangereuse';
      default:
        return 'Moyenne';
    }
  }
  
  // Couleur associée à la qualité
  int get color {
    switch (category.toLowerCase()) {
      case 'good':
        return 0xFF00E400; // Vert
      case 'moderate':
        return 0xFFFFFF00; // Jaune
      case 'unhealthy for sensitive groups':
        return 0xFFFF7E00; // Orange
      case 'unhealthy':
        return 0xFFFF0000; // Rouge
      case 'very unhealthy':
        return 0xFF8F3F97; // Violet
      case 'hazardous':
        return 0xFF7E0023; // Marron
      default:
        return 0xFF60C5BA; // Couleur par défaut
    }
  }
}

class PollenRisk {
  final String level;
  final String description;

  PollenRisk({
    required this.level,
    required this.description,
  });

  factory PollenRisk.fromJson(Map<String, dynamic> json) {
    return PollenRisk(
      level: json['level'] ?? 'Faible',
      description: json['description'] ?? 'Risques allergiques par pollen',
    );
  }
}