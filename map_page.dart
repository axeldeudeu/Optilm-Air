import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../services/air_quality_service.dart';
import '../models/air_quality_data.dart';
import '../services/openaq_service.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Qualité de l\'air',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        fontFamily: 'Roboto',
      ),
      home: const AirQualityPage(),
    );
  }
}

class AirQualityPage extends StatefulWidget {
  const AirQualityPage({Key? key}) : super(key: key);

  @override
  State<AirQualityPage> createState() => _AirQualityPageState();
}

class _AirQualityPageState extends State<AirQualityPage> {
  int _selectedTimeIndex = 0;
  final List<String> _timeOptions = ['En direct'];
  bool _isPollutantExpanded = true;
  final AirQualityService _airQualityService = AirQualityService(
    apiKey: '50a4e8c254d27ff5fbf96264e7a3dcba',
  );
  final OpenAQService _openAQService = OpenAQService();
  
  AirQualityData? _airQualityData;
  Map<String, dynamic>? _openAQData;
  
  // Position du curseur
  LatLng _cursorPosition = LatLng(48.8566, 2.3522); // Paris par défaut
  bool _isDraggingCursor = false;

  String _getQualityLabel(dynamic value) {
    if (value == null) return 'Inconnu';
    if (value < 20) return 'Bonne';
    if (value < 40) return 'Moyenne';
    if (value < 60) return 'Dégradée';
    return 'Mauvaise';
  }

  @override
  void initState() {
    super.initState();
    _fetchAirQualityData();
  }

  Future<void> _fetchAirQualityData() async {
    final data = await _airQualityService.getCurrentAirQuality(_cursorPosition.latitude, _cursorPosition.longitude);
    final openaqData = await _openAQService.getLatestMeasurements(_cursorPosition.latitude, _cursorPosition.longitude);

    setState(() {
      _airQualityData = data;
      _openAQData = openaqData;
    });
  }
  
  // Mise à jour de la position du curseur
  void _updateCursorPosition(LatLng newPosition) {
    setState(() {
      _cursorPosition = newPosition;
    });
    // Récupérer les nouvelles données pour cette position
    _fetchAirQualityData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.menu, color: Colors.black87),
          onPressed: () {},
        ),
        title: Center(
          child: Image.asset(
            'assets/airparif_logo.png',
            height: 40,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: Colors.black87),
            onPressed: () {},
          ),
          TextButton(
            onPressed: () {},
            child: const Row(
              children: [
                Text(
                  'FRANÇAIS',
                  style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
                ),
                Icon(Icons.arrow_drop_down, color: Colors.black87),
              ],
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          // Map
          FlutterMap(
            options: MapOptions(
              center: _cursorPosition,
              zoom: 9.0,
              onTap: (tapPosition, point) {
                _updateCursorPosition(point);
              },
              onPointerDown: (event, point) {
                setState(() {
                  _isDraggingCursor = true;
                });
              },
              onPointerUp: (event, point) {
                setState(() {
                  _isDraggingCursor = false;
                });
              },
              onPointerCancel: (event, point) {
                setState(() {
                  _isDraggingCursor = false;
                });
              },
              onPointerHover: (event, point) {
                if (_isDraggingCursor) {
                  _updateCursorPosition(point);
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                subdomains: const ['a', 'b', 'c'],
              ),
              // Green overlay
              ColorFiltered(
                colorFilter: ColorFilter.mode(
                  Colors.green.withOpacity(0.3),
                  BlendMode.srcOver,
                ),
                child: Container(
                  color: Colors.transparent,
                ),
              ),
              // Curseur déplaçable
              MarkerLayer(
                markers: [
                  Marker(
                    width: 40.0,
                    height: 40.0,
                    point: _cursorPosition,
                    builder: (ctx) => GestureDetector(
                      onPanUpdate: (details) {
                        final RenderBox renderBox = ctx.findRenderObject() as RenderBox;
                        final localPosition = renderBox.globalToLocal(details.globalPosition);
                        final point = localPosition;
                        // TODO: Convertir les coordonnées d'écran en coordonnées LatLng
                        // Cette conversion nécessite des calculs plus complexes qui dépendent de l'état de la carte
                      },
                      child: Stack(
                        children: [
                          // Cercle externe animé quand le curseur est en mouvement
                          if (_isDraggingCursor)
                            Container(
                              width: 40.0,
                              height: 40.0,
                              decoration: BoxDecoration(
                                color: Colors.blue.withOpacity(0.3),
                                shape: BoxShape.circle,
                              ),
                            ),
                          // Curseur principal
                          Center(
                            child: Container(
                              width: 30.0,
                              height: 30.0,
                              decoration: BoxDecoration(
                                color: Colors.blue[900],
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Colors.black26,
                                    blurRadius: 4,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: const Center(
                                child: Icon(
                                  Icons.location_searching,
                                  color: Colors.white,
                                  size: 16,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          
          // Filter buttons at top
          Positioned(
            top: 10,
            left: 0,
            right: 0,
            child: Center(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildFilterButton('Qualité de l\'air', true),
                  
                  ],
                ),
              ),
            ),
          ),

          // Affichage des coordonnées du curseur
          Positioned(
            top: 60,
            right: 20,
            child: Container(
              padding: const EdgeInsets.all(8.0),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8.0),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text(
                    'Position du capteur:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Lat: ${_cursorPosition.latitude.toStringAsFixed(4)}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  Text(
                    'Lon: ${_cursorPosition.longitude.toStringAsFixed(4)}',
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
          
          // Air quality panel
          Positioned(
            top: 120,
            left: 20,
            child: Container(
              width: 350,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 5,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Air quality indicator
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Text(
                              'Qualité de l\'air',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.black54,
                              ),
                            ),
                            SizedBox(width: 5),
                            Icon(
                              Icons.info_outline,
                              size: 16,
                              color: Colors.black54,
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                color: Color(_airQualityData?.colorCode ?? 0xFF60C5BA),
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  _airQualityData?.emoji ?? '😐',
                                  style: const TextStyle(fontSize: 24),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _airQualityData?.level ?? 'Moyenne',
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  'AQI: ${_airQualityData?.aqi ?? '--'}',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Colors.black54,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Time selector
                  SizedBox(
                    height: 40,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _timeOptions.length,
                      itemBuilder: (context, index) {
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedTimeIndex = index;
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(
                                  width: 3,
                                  color: _selectedTimeIndex == index
                                      ? Colors.blue
                                      : Colors.transparent,
                                ),
                              ),
                            ),
                            child: Center(
                              child: Text(
                                _timeOptions[index],
                                style: TextStyle(
                                  color: _selectedTimeIndex == index
                                      ? Colors.blue
                                      : Colors.black54,
                                  fontWeight: _selectedTimeIndex == index
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  // Indicateur de mise à jour
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 14,
                          color: Colors.grey[600],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Cliquez sur la carte pour voir les données à cet endroit',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Pollutant details
                  InkWell(
                    onTap: () {
                      setState(() {
                        _isPollutantExpanded = !_isPollutantExpanded;
                      });
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Qualité de l\'air par polluant',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Icon(
                            _isPollutantExpanded
                                ? Icons.keyboard_arrow_up
                                : Icons.keyboard_arrow_down,
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Pollutant details expanded section
                  if (_isPollutantExpanded)
                    Column(
                      children: [
                        _buildPollutantRow(
                          'Particules (PM₁₀)',
                          _getQualityLabel(_openAQData?['pm10']),
                          const Color(0xFF60C5BA),
                          '${_openAQData?['pm10']?.toStringAsFixed(1) ?? "--"} µg/m³',
                        ),
                        _buildPollutantRow(
                          'Dioxyde d\'Azote (NO₂)',
                          _getQualityLabel(_openAQData?['no2']),
                          const Color(0xFF60C5BA),
                          '${_openAQData?['no2']?.toStringAsFixed(1) ?? "--"} µg/m³',
                        ),
                        _buildPollutantRow(
                          'Ozone (O₃)',
                          _getQualityLabel(_openAQData?['o3']),
                          const Color(0xFF60C5BA),
                          '${_openAQData?['o3']?.toStringAsFixed(1) ?? "--"} µg/m³',
                        ),
                        _buildPollutantRow(
                          'Particules fines (PM₂.₅)',
                          _getQualityLabel(_openAQData?['pm25']),
                          const Color(0xFF60C5BA),
                          '${_openAQData?['pm25']?.toStringAsFixed(1) ?? "--"} µg/m³',
                        ),
                      ],
                    ),

                  // Pollen risk section
                  Container(
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Image.asset(
                              'assets/pollen_icon.png',
                              height: 50,
                              width: 50,
                            ),
                            const SizedBox(width: 16),
                            const Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Risques allergiques par',
                                  style: TextStyle(fontSize: 14),
                                ),
                                Text(
                                  'pollen',
                                  style: TextStyle(fontSize: 14),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Faible',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        const Row(
                          children: [
                            Text(
                              'En savoir plus',
                              style: TextStyle(
                                color: Colors.blue,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Icon(
                              Icons.arrow_forward,
                              color: Colors.blue,
                              size: 16,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Bottom navigation buttons
          Positioned(
            bottom: 20,
            right: 20,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Bouton pour réinitialiser la position à Paris
                FloatingActionButton(
                  mini: true,
                  onPressed: () {
                    _updateCursorPosition(LatLng(48.8566, 2.3522)); // Réinitialiser à Paris
                  },
                  backgroundColor: Colors.white,
                  child: const Icon(Icons.home, color: Colors.blue),
                ),
                const SizedBox(height: 10),
                // Bouton pour utiliser la géolocalisation
                FloatingActionButton(
                  mini: true,
                  onPressed: () {
                    // À implémenter: obtenir la position de l'utilisateur
                    // Nécessite le package geolocator
                    // _getUserLocation();
                  },
                  backgroundColor: Colors.white,
                  child: const Icon(Icons.my_location, color: Colors.blue),
                ),
                const SizedBox(height: 10),
                // Bouton original
                FloatingActionButton(
                  onPressed: () {},
                  backgroundColor: Colors.white,
                  child: Transform.rotate(
                    angle: 3.14159, // 180 degrees in radians
                    child: const Icon(Icons.arrow_downward, color: Colors.blue),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterButton(String text, bool isSelected) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 5),
      child: ElevatedButton(
        onPressed: () {},
        style: ElevatedButton.styleFrom(
          backgroundColor: isSelected ? Colors.blue[800] : Colors.blue[300],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        child: Text(text),
      ),
    );
  }

  Widget _buildPollutantRow(String name, String quality, Color color, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            name,
            style: const TextStyle(fontSize: 14, color: Colors.black54),
          ),
          Row(
            children: [
              Text(
                quality,
                style: const TextStyle(fontSize: 14),
              ),
              Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  height: 10,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        color,
                        Colors.yellow,
                        Colors.orange,
                        Colors.red,
                        Colors.purple,
                      ],
                      stops: const [0.0, 0.25, 0.5, 0.75, 1.0],
                    ),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Stack(
                    children: [
                      Positioned(
                        left: 30,
                        child: Container(
                          width: 3,
                          height: 15,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Text(
                value,
                style: const TextStyle(fontSize: 14),
              ),
            ],
          ),
        ],
      ),
    );
  }
}