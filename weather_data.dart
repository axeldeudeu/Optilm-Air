// lib/models/weather_data.dart

class WeatherData {
  final String cityName;
  final String country;
  final double temperature;
  final double feelsLike;
  final int humidity;
  final double windSpeed;
  final String description;
  final String icon;

  WeatherData({
    required this.cityName,
    required this.country,
    required this.temperature,
    required this.feelsLike,
    required this.humidity,
    required this.windSpeed,
    required this.description,
    required this.icon,
  });

  factory WeatherData.fromJson(Map<String, dynamic> json) {
    return WeatherData(
      cityName: json['name'] ?? 'Inconnu',
      country: json['sys']?['country'] ?? '',
      temperature: (json['main']?['temp'] ?? 0).toDouble(),
      feelsLike: (json['main']?['feels_like'] ?? 0).toDouble(),
      humidity: json['main']?['humidity'] ?? 0,
      windSpeed: (json['wind']?['speed'] ?? 0).toDouble(),
      description: json['weather']?[0]?['description'] ?? 'Inconnu',
      icon: json['weather']?[0]?['icon'] ?? '01d',
    );
  }

  factory WeatherData.mock() {
    return WeatherData(
      cityName: 'Paris',
      country: 'FR',
      temperature: 18.5,
      feelsLike: 17.8,
      humidity: 65,
      windSpeed: 3.5,
      description: 'ciel dégagé',
      icon: '01d',
    );
  }

  // Méthode pour obtenir l'URL de l'icône météo
  String get iconUrl => 'https://openweathermap.org/img/wn/$icon@2x.png';
}