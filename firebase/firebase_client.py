"""
Client Firebase/Firestore complet pour les données météo et de géolocalisation
"""

import os
import json
import logging
from datetime import datetime, timezone
from typing import Dict, Any, Optional
import firebase_admin
from firebase_admin import credentials, firestore


class FirebaseClient:
    """Client complet pour interagir avec Firebase/Firestore"""
    
    def __init__(self):
        self.logger = logging.getLogger(__name__)
        self.db = None
        self._initialize_firebase()
    
    def _initialize_firebase(self):
        """Initialise la connexion Firebase"""
        try:
            # Vérifier si Firebase est déjà initialisé
            if not firebase_admin._apps:
                # Méthode 1: Via variable d'environnement (JSON string)
                firebase_credentials_str = os.getenv("FIREBASE_CREDENTIALS_JSON")
                
                if firebase_credentials_str:
                    # Parser le JSON depuis la variable d'environnement
                    cred_dict = json.loads(firebase_credentials_str)
                    cred = credentials.Certificate(cred_dict)
                    firebase_admin.initialize_app(cred)
                    self.logger.info("Firebase initialisé via variable d'environnement")
                else:
                    # Méthode 2: Via fichier (pour développement local)
                    service_account_path = os.getenv("FIREBASE_SERVICE_ACCOUNT_PATH", "firebase-service-account.json")
                    if os.path.exists(service_account_path):
                        cred = credentials.Certificate(service_account_path)
                        firebase_admin.initialize_app(cred)
                        self.logger.info("Firebase initialisé via fichier de service")
                    else:
                        raise ValueError("Aucune credential Firebase trouvée")
            
            # Obtenir le client Firestore
            self.db = firestore.client()
            self.logger.info("Client Firestore initialisé avec succès")
            
        except Exception as e:
            self.logger.error(f"Erreur initialisation Firebase: {str(e)}")
            self.db = None
    
    # =====================================
    # MÉTHODES POUR LES DONNÉES MÉTÉO
    # =====================================
    
    async def save_weather_data(self, data: Dict[str, Any]) -> bool:
        """
        Sauvegarde les données météo dans Firestore
        
        Args:
            data: Données météo à sauvegarder
            
        Returns:
            True si succès, False sinon
        """
        if not self.db:
            self.logger.error("Client Firestore non initialisé")
            return False
        
        try:
            # Préparer les données pour Firestore
            firestore_data = self._prepare_firestore_data(data)
            
            # Sauvegarder dans la collection principale avec timestamp comme ID
            timestamp_id = datetime.now(timezone.utc).strftime("%Y%m%d_%H%M%S")
            doc_ref = self.db.collection('weather_data').document(timestamp_id)
            doc_ref.set(firestore_data)
            
            # Mettre à jour le document "latest" pour Flutter
            latest_ref = self.db.collection('latest_weather').document('current')
            latest_ref.set(firestore_data)
            
            self.logger.info(f"Données météo sauvées dans Firestore: {timestamp_id}")
            return True
            
        except Exception as e:
            self.logger.error(f"Erreur sauvegarde météo Firestore: {str(e)}")
            return False
    
    def _prepare_firestore_data(self, data: Dict[str, Any]) -> Dict[str, Any]:
        """
        Prépare les données météo pour Firestore (optimisé pour Flutter)
        
        Args:
            data: Données brutes
            
        Returns:
            Données formatées pour Firestore
        """
        try:
            # Structure optimisée pour Flutter
            firestore_data = {
                # Métadonnées
                'timestamp': data.get('timestamp'),
                'collected_at': firestore.SERVER_TIMESTAMP,
                'location': data.get('location', {}),
                'collection_status': data.get('collection_status', {}),
                
                # Données de qualité de l'air simplifiées
                'air_quality': self._simplify_air_quality(data.get('air_quality')),
                
                # Données météo simplifiées
                'weather': self._simplify_weather_data(data.get('weather')),
                
                # Données brutes (optionnel, pour debug)
                'raw_data_available': True
            }
            
            return firestore_data
            
        except Exception as e:
            self.logger.error(f"Erreur préparation données météo: {str(e)}")
            return data
    
    def _simplify_weather_data(self, weather_data: Optional[Dict[str, Any]]) -> Optional[Dict[str, Any]]:
        """Simplifie les données météo pour Flutter"""
        if not weather_data:
            return None
        
        try:
            simplified = {
                'collected_at': weather_data.get('collected_at'),
                'data_source': weather_data.get('data_source'),
                'location': weather_data.get('location'),
                'current': None,
                'forecast_24h': [],
                'forecast_summary': None
            }
            
            # Données actuelles
            if 'current' in weather_data and weather_data['current']:
                current = weather_data['current']
                simplified['current'] = {
                    'temperature': current.get('temperature'),
                    'feels_like': current.get('feels_like'),
                    'humidity': current.get('humidity'),
                    'pressure': current.get('pressure'),
                    'description': current.get('weather', {}).get('description'),
                    'icon': current.get('weather', {}).get('icon'),
                    'wind_speed': current.get('wind', {}).get('speed'),
                    'clouds': current.get('clouds'),
                    'city_name': current.get('location', {}).get('name'),
                    'country': current.get('location', {}).get('country'),
                    'sunrise': current.get('sunrise'),
                    'sunset': current.get('sunset')
                }
            
            # Prévisions simplifiées
            if 'forecast' in weather_data and weather_data['forecast']:
                forecast = weather_data['forecast']
                if 'forecasts' in forecast:
                    for item in forecast['forecasts'][:8]:  # 24h de prévisions
                        forecast_item = {
                            'datetime': item.get('datetime'),
                            'temperature': item.get('temperature'),
                            'description': item.get('weather', {}).get('description'),
                            'icon': item.get('weather', {}).get('icon'),
                            'precipitation_probability': item.get('precipitation_probability'),
                            'wind_speed': item.get('wind_speed')
                        }
                        simplified['forecast_24h'].append(forecast_item)
                
                # Résumé des prévisions
                if simplified['forecast_24h']:
                    temps = [f['temperature'] for f in simplified['forecast_24h'] if f['temperature']]
                    if temps:
                        simplified['forecast_summary'] = {
                            'temp_min': min(temps),
                            'temp_max': max(temps),
                            'avg_temp': round(sum(temps) / len(temps), 1)
                        }
            
            return simplified
            
        except Exception as e:
            self.logger.error(f"Erreur simplification weather: {str(e)}")
            return weather_data
    
    # =====================================
    # MÉTHODES POUR LA GÉOLOCALISATION
    # =====================================
    
    async def save_user_location(self, location_data: Dict[str, Any]) -> bool:
        """
        Sauvegarde les données de géolocalisation utilisateur
        
        Args:
            location_data: Données de géolocalisation à sauvegarder
            
        Returns:
            True si succès, False sinon
        """
        if not self.db:
            self.logger.error("Client Firestore non initialisé")
            return False
        
        try:
            # Préparer les données pour Firestore
            firestore_data = self._prepare_location_data(location_data)
            
            # Sauvegarder dans la collection user_locations
            timestamp_id = datetime.now(timezone.utc).strftime("%Y%m%d_%H%M%S")
            user_id = location_data.get('user_id')
            doc_id = f"{user_id}_{timestamp_id}"
            
            doc_ref = self.db.collection('user_locations').document(doc_id)
            doc_ref.set(firestore_data)
            
            # Mettre à jour la dernière position dans le profil utilisateur
            user_ref = self.db.collection('users').document(user_id)
            user_ref.update({
                'last_location': {
                    'latitude': location_data['position']['latitude'],
                    'longitude': location_data['position']['longitude'],
                    'updated_at': firestore.SERVER_TIMESTAMP,
                    'aqi': self._extract_aqi(location_data.get('air_quality')),
                    'air_quality_level': self._extract_air_quality_level(location_data.get('air_quality')),
                    'recommendations_count': len(location_data.get('recommendations', []))
                }
            })
            
            self.logger.info(f"Position utilisateur sauvée: {doc_id}")
            return True
            
        except Exception as e:
            self.logger.error(f"Erreur sauvegarde position: {str(e)}")
            return False

    def _prepare_location_data(self, data: Dict[str, Any]) -> Dict[str, Any]:
        """
        Prépare les données de géolocalisation pour Firestore
        
        Args:
            data: Données de géolocalisation brutes
            
        Returns:
            Données formatées pour Firestore
        """
        return {
            'user_id': data.get('user_id'),
            'position': {
                'latitude': data['position']['latitude'],
                'longitude': data['position']['longitude'],
                'accuracy': data['position']['accuracy'],
                'timestamp': firestore.SERVER_TIMESTAMP,
                'collected_at': data['position']['collected_at']
            },
            'air_quality': self._simplify_air_quality(data.get('air_quality')),
            'recommendations': data.get('recommendations', []),
            'metadata': data.get('metadata', {}),
            'created_at': firestore.SERVER_TIMESTAMP
        }
    
    # =====================================
    # MÉTHODES UTILITAIRES COMMUNES
    # =====================================
    
    def _simplify_air_quality(self, air_quality_data: Optional[Dict[str, Any]]) -> Optional[Dict[str, Any]]:
        """Simplifie les données de qualité de l'air pour Flutter"""
        if not air_quality_data:
            return None
        
        try:
            simplified = {
                'collected_at': air_quality_data.get('collected_at'),
                'data_source': air_quality_data.get('data_source'),
                'overall_aqi': None,
                'overall_category': None,
                'dominant_pollutant': air_quality_data.get('dominant_pollutant'),
                'indexes': [],
                'main_pollutants': []
            }
            
            # Extraire l'indice principal
            if 'indexes' in air_quality_data:
                for index in air_quality_data['indexes']:
                    index_simple = {
                        'code': index.get('code'),
                        'name': index.get('display_name'),
                        'aqi': index.get('aqi'),
                        'category': index.get('category'),
                        'color': index.get('color', {})
                    }
                    simplified['indexes'].append(index_simple)
                    
                    # Premier index comme référence principale
                    if not simplified['overall_aqi']:
                        simplified['overall_aqi'] = index.get('aqi')
                        simplified['overall_category'] = index.get('category')
            
            # Extraire les polluants principaux
            if 'pollutants' in air_quality_data:
                for pollutant in air_quality_data['pollutants'][:5]:  # Top 5
                    if pollutant.get('concentration'):
                        pollutant_simple = {
                            'code': pollutant.get('code'),
                            'name': pollutant.get('display_name'),
                            'concentration': pollutant.get('concentration', {}).get('value'),
                            'units': pollutant.get('concentration', {}).get('units')
                        }
                        simplified['main_pollutants'].append(pollutant_simple)
            
            return simplified
            
        except Exception as e:
            self.logger.error(f"Erreur simplification air quality: {str(e)}")
            return air_quality_data
    
    def _extract_aqi(self, air_quality_data: Optional[Dict[str, Any]]) -> Optional[int]:
        """Extrait la valeur AQI principale"""
        if not air_quality_data or 'indexes' not in air_quality_data:
            return None
        
        if air_quality_data['indexes']:
            return air_quality_data['indexes'][0].get('aqi')
        return None
    
    def _extract_air_quality_level(self, air_quality_data: Optional[Dict[str, Any]]) -> Optional[str]:
        """Extrait le niveau de qualité de l'air"""
        if not air_quality_data or 'indexes' not in air_quality_data:
            return None
        
        if air_quality_data['indexes']:
            return air_quality_data['indexes'][0].get('category')
        return None
    
    def get_connection_status(self) -> Dict[str, Any]:
        """Retourne le statut de la connexion Firebase"""
        return {
            'firebase_initialized': firebase_admin._apps != {},
            'firestore_client_ready': self.db is not None,
            'timestamp': datetime.now(timezone.utc).isoformat()
        }


# =====================================
# RÈGLES FIRESTORE (firestore.rules)
# =====================================

FIRESTORE_RULES = """
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // Règles pour les données utilisateur
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
    
    // Règles pour les positions utilisateur
    match /user_locations/{locationId} {
      allow read, write: if request.auth != null && 
        resource.data.user_id == request.auth.uid;
      allow create: if request.auth != null && 
        request.resource.data.user_id == request.auth.uid;
    }
    
    // Règles pour les données météo (lecture publique)
    match /weather_data/{docId} {
      allow read: if true;
      allow write: if false; // Seul le backend peut écrire
    }
    
    // Règles pour les dernières données météo
    match /latest_weather/{docId} {
      allow read: if true;
      allow write: if false; // Seul le backend peut écrire
    }
  }
}
"""

# =====================================
# INDEX FIRESTORE (firestore.indexes.json)
# =====================================

FIRESTORE_INDEXES = {
    "indexes": [
        {
            "collectionGroup": "user_locations",
            "queryScope": "COLLECTION",
            "fields": [
                {
                    "fieldPath": "user_id",
                    "order": "ASCENDING"
                },
                {
                    "fieldPath": "position.timestamp",
                    "order": "DESCENDING"
                }
            ]
        },
        {
            "collectionGroup": "user_locations",
            "queryScope": "COLLECTION",
            "fields": [
                {
                    "fieldPath": "position.latitude",
                    "order": "ASCENDING"
                },
                {
                    "fieldPath": "position.longitude",
                    "order": "ASCENDING"
                },
                {
                    "fieldPath": "position.timestamp",
                    "order": "DESCENDING"
                }
            ]
        },
        {
            "collectionGroup": "weather_data",
            "queryScope": "COLLECTION",
            "fields": [
                {
                    "fieldPath": "timestamp",
                    "order": "DESCENDING"
                },
                {
                    "fieldPath": "location.latitude",
                    "order": "ASCENDING"
                },
                {
                    "fieldPath": "location.longitude", 
                    "order": "ASCENDING"
                }
            ]
        }
    ],
    "fieldOverrides": []
}


# =====================================
# EXEMPLE D'UTILISATION
# =====================================

if __name__ == "__main__":
    # Exemple d'utilisation du client
    import asyncio
    
    async def main():
        # Initialiser le client
        firebase_client = FirebaseClient()
        
        # Vérifier la connexion
        status = firebase_client.get_connection_status()
        print(f"Statut Firebase: {status}")
        
        # Exemple de données météo
        weather_data = {
            'timestamp': datetime.now(timezone.utc).isoformat(),
            'location': {'latitude': 48.8566, 'longitude': 2.3522},
            'air_quality': {
                'indexes': [{'aqi': 42, 'category': 'Good', 'code': 'uaqi'}],
                'pollutants': []
            },
            'weather': {
                'current': {'temperature': 22, 'humidity': 65}
            }
        }
        
        # Sauvegarder les données météo
        success = await firebase_client.save_weather_data(weather_data)
        print(f"Sauvegarde météo: {'Succès' if success else 'Échec'}")
        
        # Exemple de données de géolocalisation utilisateur
        location_data = {
            'user_id': 'user123',
            'position': {
                'latitude': 48.8566,
                'longitude': 2.3522,
                'accuracy': 10,
                'collected_at': datetime.now(timezone.utc).isoformat()
            },
            'air_quality': weather_data['air_quality'],
            'recommendations': ['Fenêtres ouvertes recommandées'],
            'metadata': {'app_version': '1.0.0'}
        }
        
        # Sauvegarder la géolocalisation
        success = await firebase_client.save_user_location(location_data)
        print(f"Sauvegarde géolocalisation: {'Succès' if success else 'Échec'}")
    
    # Exécuter l'exemple
    asyncio.run(main())
