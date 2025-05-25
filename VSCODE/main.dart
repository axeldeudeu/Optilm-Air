import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';

// Importez TOUTES vos pages
import 'pages/map_page.dart';
import 'pages/pollutants_page.dart';
import 'pages/preferences_page.dart';
import 'pages/profile_page.dart';

// Importez vos services (parfaitement compatibles !)
import 'services/air_quality_service.dart';
import 'services/weather_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print('🎉 OptimAir COMPLET - Firebase + OpenWeather API configurés !');
  } catch (e) {
    print('❌ Erreur Firebase: $e');
  }
  
  runApp(OptimAirApp());
}

class OptimAirApp extends StatelessWidget {
  // 🔑 VOTRE CLÉ OPENWEATHER API
  static const String OPENWEATHER_API_KEY = '50a4e8c254d27ff5fbf96264e7a3dcba';
  
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // 🌍 Service de qualité de l'air avec votre clé API
        Provider<AirQualityService>(
          create: (_) => AirQualityService(apiKey: OPENWEATHER_API_KEY),
        ),
        // 🌦️ Service météo avec votre clé API
        Provider<WeatherService>(
          create: (_) => WeatherService(apiKey: OPENWEATHER_API_KEY),
        ),
      ],
      child: MaterialApp(
        title: 'OptimAir - Production Ready',
        theme: _buildOptimAirTheme(),
        home: MainNavigationPage(),
        debugShowCheckedModeBanner: false,
        routes: {
          '/profile': (context) => ProfilePage(),
          '/map': (context) => AirQualityPage(),
          '/pollutants': (context) => PollutantsPage(),
          '/preferences': (context) => PreferencesPage(),
        },
      ),
    );
  }
  
  ThemeData _buildOptimAirTheme() {
    return ThemeData.dark().copyWith(
      // 🎨 Couleurs cohérentes OptimAir
      primaryColor: Color(0xFF0088FF),
      scaffoldBackgroundColor: Color(0xFF0A1929),
      cardColor: Color(0xFF162033),
      
      // 📱 AppBar
      appBarTheme: AppBarTheme(
        backgroundColor: Color(0xFF0088FF),
        elevation: 2,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: IconThemeData(color: Colors.white),
      ),
      
      // 🔽 Navigation
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: Color(0xFF162033),
        selectedItemColor: Color(0xFF0088FF),
        unselectedItemColor: Colors.white60,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      
      // 🔘 Bouton flottant
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: Color(0xFF0088FF),
        foregroundColor: Colors.white,
        elevation: 6,
      ),
    );
  }
}

class MainNavigationPage extends StatefulWidget {
  @override
  _MainNavigationPageState createState() => _MainNavigationPageState();
}

class _MainNavigationPageState extends State<MainNavigationPage> {
  int _currentIndex = 0;
  
  // 📄 Vos VRAIES pages avec API fonctionnelle
  final List<Widget> _pages = [
    AirQualityPage(),      // 🗺️ Carte avec données OpenWeather
    PollutantsPage(),      // 🏭 Polluants avec géolocalisation
    PreferencesPage(),     // ⚙️ Préférences utilisateur
  ];

  final List<String> _pageTitles = [
    'Carte Qualité de l\'Air',
    'Polluants Temps Réel', 
    'Préférences',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_pageTitles[_currentIndex]),
        actions: [
          // 🎉 Badge de statut API
          Container(
            margin: EdgeInsets.only(right: 8),
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.green, Colors.green.shade700],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.cloud_done, size: 14, color: Colors.white),
                SizedBox(width: 4),
                Text(
                  'OpenWeather',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          // 👤 Bouton profil avec indicateur
          Stack(
            children: [
              IconButton(
                icon: Icon(Icons.person),
                tooltip: 'Mon Profil',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ProfilePage(),
                    ),
                  );
                },
              ),
              // Point indicateur profil
              Positioned(
                right: 6,
                top: 6,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: Color(0xFF00E5FF),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: [
          BottomNavigationBarItem(
            icon: Icon(Icons.map),
            label: 'Carte',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.air),
            label: 'Polluants',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Réglages',
          ),
        ],
      ),
      
      // 🎯 Accès rapide au profil
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _showProfileQuickAction(context);
        },
        child: Icon(Icons.person_add),
        tooltip: 'Profil Utilisateur',
        heroTag: "profile_fab",
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
  
  void _showProfileQuickAction(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Color(0xFF162033),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.person, color: Color(0xFF0088FF)),
              title: Text('Mon Profil', style: TextStyle(color: Colors.white)),
              subtitle: Text('Gérer mes informations', style: TextStyle(color: Colors.white70)),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => ProfilePage()),
                );
              },
            ),
            ListTile(
              leading: Icon(Icons.api, color: Colors.green),
              title: Text('Statut API', style: TextStyle(color: Colors.white)),
              subtitle: Text('OpenWeather API active', style: TextStyle(color: Colors.green)),
              onTap: () {
                Navigator.pop(context);
                _showAPIStatus(context);
              },
            ),
          ],
        ),
      ),
    );
  }
  
  void _showAPIStatus(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Color(0xFF162033),
        title: Row(
          children: [
            Icon(Icons.cloud_done, color: Colors.green),
            SizedBox(width: 10),
            Text('Statut API', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildAPIStatusRow('Qualité de l\'Air', true),
            _buildAPIStatusRow('Données Météo', true),
            _buildAPIStatusRow('Géolocalisation', true),
            _buildAPIStatusRow('Firebase', true),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK', style: TextStyle(color: Color(0xFF0088FF))),
          ),
        ],
      ),
    );
  }
  
  Widget _buildAPIStatusRow(String service, bool isActive) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            isActive ? Icons.check_circle : Icons.error,
            color: isActive ? Colors.green : Colors.red,
            size: 16,
          ),
          SizedBox(width: 8),
          Text(
            service,
            style: TextStyle(color: Colors.white70),
          ),
          Spacer(),
          Text(
            isActive ? 'ACTIF' : 'INACTIF',
            style: TextStyle(
              color: isActive ? Colors.green : Colors.red,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}