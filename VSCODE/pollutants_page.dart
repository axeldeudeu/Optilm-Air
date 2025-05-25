// lib/pages/pollutants_page.dart

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/air_quality_service.dart';
import '../services/weather_service.dart';
import '../models/air_quality_data.dart';
import '../models/weather_data.dart';
import '../models/recommendation_model.dart';
import 'dart:convert';

// Ajoutez ces constantes au début de chaque fichier
const Color primaryColor = Color(0xFF0088FF); // Bleu vif
const Color secondaryColor = Color(0xFF00D2FF); // Bleu cyan
const Color accentColor = Color(0xFF00E5FF); // Cyan lumineux
const Color darkColor = Color(0xFF121212); // Presque noir
const Color backgroundColor = Color(0xFF0A1929); // Bleu très foncé
const Color cardColor = Color(0xFF162033); // Bleu-gris foncé

final darkGradient = LinearGradient(
  colors: [darkColor, backgroundColor],
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
);

class PollutantsPage extends StatefulWidget {
  const PollutantsPage({Key? key}) : super(key: key);

  @override
  State<PollutantsPage> createState() => _PollutantsPageState();
}

class _PollutantsPageState extends State<PollutantsPage> {
  AirQualityData? _airQualityData;
  WeatherData? _weatherData;
  String _locationName = '';
  bool _isLoading = true;
  Position? _userPosition;
  late UserPreferences _userPreferences;
  List<Recommendation> _recommendations = [];
  bool _showRecommendations = false;

  // Services avec la clé API fournie
  final String _apiKey = '50a4e8c254d27ff5fbf96264e7a3dcba';
  late final AirQualityService _airQualityService;
  late final WeatherService _weatherService;

  @override
  void initState() {
    super.initState();
    _airQualityService = AirQualityService(apiKey: _apiKey);
    _weatherService = WeatherService(apiKey: _apiKey);
    _loadUserPreferences().then((_) => _fetchData());
  }

  Future<void> _loadUserPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    String? userPrefsJson = prefs.getString('user_preferences');
    
    if (userPrefsJson != null) {
      try {
        Map<String, dynamic> userPrefsMap = jsonDecode(userPrefsJson);
        _userPreferences = UserPreferences.fromJson(userPrefsMap);
      } catch (e) {
        print('Erreur lors du parsing des préférences: $e');
        _userPreferences = UserPreferences();
      }
    } else {
      _userPreferences = UserPreferences();
    }
  }

  Future<void> _saveUserPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_preferences', jsonEncode(_userPreferences.toJson()));
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Préférences sauvegardées avec succès'),
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<void> _fetchData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Demander la permission de localisation si nécessaire
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Permission de localisation refusée');
        }
      }
      
      if (permission == LocationPermission.deniedForever) {
        throw Exception('Permission de localisation refusée de façon permanente');
      }

      // Obtenir la position actuelle
      _userPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      // Récupérer le nom de la localisation
      _locationName = await _weatherService.getLocationName(
        _userPosition!.latitude,
        _userPosition!.longitude,
      );

      // Récupérer les données de qualité de l'air
      _airQualityData = await _airQualityService.getCurrentAirQuality(
        _userPosition!.latitude,
        _userPosition!.longitude,
      );

      // Récupérer les données météo
      _weatherData = await _weatherService.getCurrentWeather(
        _userPosition!.latitude,
        _userPosition!.longitude,
      );
      
      // Générer les recommandations
      if (_airQualityData != null) {
        _recommendations = RecommendationService.getRecommendationsForAQI(
          _airQualityData!.aqi, 
          _userPreferences.selectedRiskGroups.toList()
        );
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print('Erreur lors de la récupération des données: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Envoyer des notifications en fonction des préférences
  Future<void> _sendNotifications() async {
    if (_airQualityData == null) return;
    
    try {
      await NotificationService.sendNotificationsBasedOnPreferences(
        _userPreferences,
        _airQualityData!.aqi,
        _locationName,
      );
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Notification envoyée avec succès'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors de l\'envoi de la notification: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Obtenir la couleur associée à la catégorie de qualité de l'air
  Color _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'très bien':
      case 'très bonne':
      case 'très bon':
      case 'good':
        return Colors.green;
      case 'bien':
      case 'bonne':
      case 'bon':
        return Colors.lightGreen;
      case 'pas fou':
      case 'moyenne':
      case 'moyen':
      case 'moderate':
      case 'unhealthy for sensitive groups':
        return Colors.yellow.shade700;
      case 'pas bon du tout':
      case 'mauvaise':
      case 'mauvais':
      case 'unhealthy':
        return Colors.orange;
      case 'horrible':
      case 'très mauvais':
      case 'très mauvaise':
      case 'very unhealthy':
        return Colors.red;
      case 'extrêmement dangereux':
      case 'extrêmement dangereuse':
      case 'hazardous':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true, // Permet au fond de s'étendre derrière l'AppBar
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Qualité de l\'air et Météo'),
        actions: [
          IconButton(
            icon: Icon(Icons.notifications),
            onPressed: _airQualityData == null ? null : _sendNotifications,
            tooltip: 'Envoyer une notification',
          ),
          IconButton(
            icon: Icon(Icons.save),
            onPressed: _saveUserPreferences,
            tooltip: 'Sauvegarder les préférences',
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: darkGradient,
        ),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
              ))
            : _buildContent(),
      ),
    );
  }

  Widget _buildContent() {
    if (_airQualityData == null || _weatherData == null || _userPosition == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Impossible de charger les données',
              style: TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _fetchData,
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
              ),
              child: const Text('Réessayer'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchData,
      color: primaryColor,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Carte de localisation
            _buildCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.location_on, size: 24, color: accentColor),
                      const SizedBox(width: 8),
                      Text(
                        'Localisation',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18, 
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _locationName,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Latitude: ${_userPosition!.latitude.toStringAsFixed(4)}, Longitude: ${_userPosition!.longitude.toStringAsFixed(4)}',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Carte météo
            _buildCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.wb_sunny, size: 24, color: accentColor),
                      const SizedBox(width: 8),
                      Text(
                        'Météo actuelle',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18, 
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: EdgeInsets.all(8),
                        child: Image.network(
                          _weatherData!.iconUrl,
                          width: 64,
                          height: 64,
                          errorBuilder: (context, error, stackTrace) => 
                            Icon(Icons.wb_sunny, size: 64, color: Colors.amber),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${_weatherData!.temperature.toStringAsFixed(1)}°C',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Ressenti: ${_weatherData!.feelsLike.toStringAsFixed(1)}°C',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              _weatherData!.description,
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildDetailContainer(
                        icon: Icons.water_drop,
                        label: 'Humidité',
                        value: '${_weatherData!.humidity}%',
                      ),
                      _buildDetailContainer(
                        icon: Icons.air,
                        label: 'Vent',
                        value: '${_weatherData!.windSpeed} m/s',
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Carte qualité de l'air
            _buildCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.air_sharp, size: 24, color: accentColor),
                          const SizedBox(width: 8),
                          Text(
                            'Qualité de l\'air',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18, 
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      
                      // Bouton pour afficher/masquer les recommandations
                      IconButton(
                        icon: Icon(
                          _showRecommendations ? Icons.expand_less : Icons.expand_more,
                          color: accentColor,
                        ),
                        onPressed: () {
                          setState(() {
                            _showRecommendations = !_showRecommendations;
                          });
                        },
                        tooltip: _showRecommendations ? 'Masquer les recommandations' : 'Afficher les recommandations',
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'AQI: ${_airQualityData!.aqi.toStringAsFixed(1)}',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: _getCategoryColor(_airQualityData!.category),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: _getCategoryColor(_airQualityData!.category).withOpacity(0.4),
                              blurRadius: 5,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Text(
                          _airQualityData!.level,
                          style: TextStyle(
                            color: _airQualityData!.category.toLowerCase() == 'moderate' 
                                ? Colors.black 
                                : Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  // Section de recommandations
                  if (_showRecommendations && _recommendations.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const Divider(color: Colors.white24),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.tips_and_updates, color: accentColor, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Recommandations',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ..._recommendations.map((recommendation) => 
                      _buildRecommendationTile(recommendation)
                    ).toList(),
                    const SizedBox(height: 8),
                    Center(
                      child: ElevatedButton.icon(
                        onPressed: _sendNotifications,
                        icon: Icon(Icons.notifications_active),
                        label: Text('Envoyer une notification'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ],
                  
                  const SizedBox(height: 16),
                  Text(
                    'Polluants',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            
            // Liste des polluants
            ..._airQualityData!.pollutants.entries.map((entry) {
              final pollutant = entry.value;
              final color = _getCategoryColor(pollutant.category);
              
              return Container(
                margin: const EdgeInsets.only(top: 8),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: color.withOpacity(0.2),
                      blurRadius: 8,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                child: ListTile(
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _getPollutantIcon(entry.key),
                      color: color,
                      size: 24,
                    ),
                  ),
                  title: Text(
                    pollutant.name,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  subtitle: Text(
                    '${pollutant.concentration.toStringAsFixed(1)} ${pollutant.unit}',
                    style: TextStyle(
                      color: Colors.white70,
                    ),
                  ),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: color, width: 1),
                    ),
                    child: Text(
                      pollutant.quality,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
            
            // Risque pollen
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 8,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: ListTile(
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.grass,
                    color: Colors.green,
                    size: 24,
                  ),
                ),
                title: Text(
                  'Risque de pollen',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                subtitle: Text(
                  _airQualityData!.pollenRisk.description,
                  style: TextStyle(
                    color: Colors.white70,
                  ),
                ),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green, width: 1),
                  ),
                  child: Text(
                    _airQualityData!.pollenRisk.level,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
            
            SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildCard({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 10,
            offset: Offset(0, 5),
          ),
        ],
      ),
      padding: EdgeInsets.all(16),
      child: child,
    );
  }

  Widget _buildRecommendationTile(Recommendation recommendation) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: recommendation.color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: recommendation.color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: ExpansionTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: recommendation.color.withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          child: Icon(
            recommendation.icon,
            color: recommendation.color,
            size: 24,
          ),
        ),
        title: Text(
          recommendation.message,
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w500,
          ),
        ),
        collapsedIconColor: Colors.white70,
        iconColor: accentColor,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  recommendation.actionTitle,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  recommendation.actionDescription,
                  style: TextStyle(
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailContainer({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, size: 24, color: accentColor),
          SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
          SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  IconData _getPollutantIcon(String pollutantKey) {
    switch (pollutantKey.toLowerCase()) {
      case 'pm25':
        return Icons.grain;
      case 'pm10':
        return Icons.blur_circular;
      case 'o3':
        return Icons.air;
      case 'no2':
        return Icons.cloud;
      case 'so2':
        return Icons.cloud_queue;
      case 'co':
        return Icons.local_fire_department;
      default:
        return Icons.bubble_chart;
    }
  }
}