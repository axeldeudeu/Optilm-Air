import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class WeatherData {
  final String? timestamp;
  final Map<String, dynamic>? location;
  final Map<String, dynamic>? collectionStatus;
  final AirQualityData? airQuality;
  final WeatherCurrentData? weather;
  final DateTime? collectedAt;

  WeatherData({
    this.timestamp,
    this.location,
    this.collectionStatus,
    this.airQuality,
    this.weather,
    this.collectedAt,
  });

  factory WeatherData.fromFirestore(Map<String, dynamic> data) {
    return WeatherData(
      timestamp: data['timestamp'],
      location: data['location'],
      collectionStatus: data['collection_status'],
      airQuality: data['air_quality'] != null 
          ? AirQualityData.fromMap(data['air_quality']) 
          : null,
      weather: data['weather'] != null 
          ? WeatherCurrentData.fromMap(data['weather']) 
          : null,
      collectedAt: data['collected_at'] is Timestamp 
          ? (data['collected_at'] as Timestamp).toDate()
          : DateTime.tryParse(data['collected_at'] ?? ''),
    );
  }
}

class AirQualityData {
  final String? dataSource;
  final int? overallAqi;
  final String? overallCategory;
  final String? dominantPollutant;
  final List<AirQualityIndex> indexes;
  final List<Pollutant> mainPollutants;

  AirQualityData({
    this.dataSource,
    this.overallAqi,
    this.overallCategory,
    this.dominantPollutant,
    this.indexes = const [],
    this.mainPollutants = const [],
  });

  factory AirQualityData.fromMap(Map<String, dynamic> map) {
    return AirQualityData(
      dataSource: map['data_source'],
      overallAqi: map['overall_aqi'],
      overallCategory: map['overall_category'],
      dominantPollutant: map['dominant_pollutant'],
      indexes: (map['indexes'] as List<dynamic>?)
          ?.map((e) => AirQualityIndex.fromMap(e))
          .toList() ?? [],
      mainPollutants: (map['main_pollutants'] as List<dynamic>?)
          ?.map((e) => Pollutant.fromMap(e))
          .toList() ?? [],
    );
  }
}

class AirQualityIndex {
  final String? code;
  final String? name;
  final int? aqi;
  final String? category;
  final Map<String, dynamic>? color;

  AirQualityIndex({this.code, this.name, this.aqi, this.category, this.color});

  factory AirQualityIndex.fromMap(Map<String, dynamic> map) {
    return AirQualityIndex(
      code: map['code'],
      name: map['name'],
      aqi: map['aqi'],
      category: map['category'],
      color: map['color'],
    );
  }
}

class Pollutant {
  final String? code;
  final String? name;
  final double? concentration;
  final String? units;

  Pollutant({this.code, this.name, this.concentration, this.units});

  factory Pollutant.fromMap(Map<String, dynamic> map) {
    return Pollutant(
      code: map['code'],
      name: map['name'],
      concentration: map['concentration']?.toDouble(),
      units: map['units'],
    );
  }
}

class WeatherCurrentData {
  final String? dataSource;
  final Map<String, dynamic>? location;
  final CurrentWeather? current;
  final List<ForecastItem> forecast24h;
  final Map<String, dynamic>? forecastSummary;

  WeatherCurrentData({
    this.dataSource,
    this.location,
    this.current,
    this.forecast24h = const [],
    this.forecastSummary,
  });

  factory WeatherCurrentData.fromMap(Map<String, dynamic> map) {
    return WeatherCurrentData(
      dataSource: map['data_source'],
      location: map['location'],
      current: map['current'] != null 
          ? CurrentWeather.fromMap(map['current']) 
          : null,
      forecast24h: (map['forecast_24h'] as List<dynamic>?)
          ?.map((e) => ForecastItem.fromMap(e))
          .toList() ?? [],
      forecastSummary: map['forecast_summary'],
    );
  }
}

class CurrentWeather {
  final double? temperature;
  final double? feelsLike;
  final int? humidity;
  final double? pressure;
  final String? description;
  final String? icon;
  final double? windSpeed;
  final int? clouds;
  final String? cityName;
  final String? country;
  final int? sunrise;
  final int? sunset;

  CurrentWeather({
    this.temperature,
    this.feelsLike,
    this.humidity,
    this.pressure,
    this.description,
    this.icon,
    this.windSpeed,
    this.clouds,
    this.cityName,
    this.country,
    this.sunrise,
    this.sunset,
  });

  factory CurrentWeather.fromMap(Map<String, dynamic> map) {
    return CurrentWeather(
      temperature: map['temperature']?.toDouble(),
      feelsLike: map['feels_like']?.toDouble(),
      humidity: map['humidity'],
      pressure: map['pressure']?.toDouble(),
      description: map['description'],
      icon: map['icon'],
      windSpeed: map['wind_speed']?.toDouble(),
      clouds: map['clouds'],
      cityName: map['city_name'],
      country: map['country'],
      sunrise: map['sunrise'],
      sunset: map['sunset'],
    );
  }
}

class ForecastItem {
  final int? datetime;
  final double? temperature;
  final String? description;
  final String? icon;
  final double? precipProbability;
  final double? windSpeed;

  ForecastItem({
    this.datetime,
    this.temperature,
    this.description,
    this.icon,
    this.precipProbability,
    this.windSpeed,
  });

  factory ForecastItem.fromMap(Map<String, dynamic> map) {
    return ForecastItem(
      datetime: map['datetime'],
      temperature: map['temperature']?.toDouble(),
      description: map['description'],
      icon: map['icon'],
      precipProbability: map['precipitation_probability']?.toDouble(),
      windSpeed: map['wind_speed']?.toDouble(),
    );
  }
}

class WeatherService extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  WeatherData? _currentWeatherData;
  bool _isLoading = true;
  String? _error;

  WeatherData? get currentWeatherData => _currentWeatherData;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Stream<WeatherData?> listenToWeatherData() {
    return _firestore
        .collection('latest_weather')
        .doc('current')
        .snapshots()
        .map((snapshot) {
      if (snapshot.exists && snapshot.data() != null) {
        _currentWeatherData = WeatherData.fromFirestore(snapshot.data()!);
        _isLoading = false;
        _error = null;
        notifyListeners();
        return _currentWeatherData;
      } else {
        _isLoading = false;
        _error = 'Aucune donnée disponible';
        notifyListeners();
        return null;
      }
    });
  }

  Stream<List<WeatherData>> getHistoricalData({int limit = 24}) {
    return _firestore
        .collection('weather_data')
        .orderBy('collected_at', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => WeatherData.fromFirestore(doc.data()))
          .toList();
    });
  }

  void startListening() {
    listenToWeatherData().listen(
      (data) {
        if (kDebugMode) {
          print('🌤️ Nouvelles données météo reçues: ${data?.timestamp}');
        }
      },
      onError: (error) {
        _error = error.toString();
        _isLoading = false;
        notifyListeners();
        if (kDebugMode) {
          print('❌ Erreur WeatherService: $error');
        }
      },
    );
  }
}
