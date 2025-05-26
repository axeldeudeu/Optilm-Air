#!/usr/bin/env python3
"""
Script principal pour collecter les données météorologiques avec API de géolocalisation
Version complète avec serveur FastAPI et collecteur de données
"""

import os
import sys
import asyncio
from datetime import datetime, timezone
from typing import Dict, Any
from pathlib import Path

# Imports pour la collecte de données
from data_collectors.air_quality_collector import AirQualityCollector
from data_collectors.weather_collector import WeatherCollector
from storage.data_storage import DataStorage
from utils.logger import setup_logger
from utils.config import Config

# Imports pour l'API FastAPI
from fastapi import FastAPI, HTTPException, BackgroundTasks
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
import uvicorn

# Import des routes de géolocalisation (si disponible)
try:
    from api.location_handler import router as location_router
    LOCATION_API_AVAILABLE = True
except ImportError:
    LOCATION_API_AVAILABLE = False
    print("⚠️  Module location_handler non trouvé - API de géolocalisation désactivée")

# =====================================
# CONFIGURATION FASTAPI
# =====================================

app = FastAPI(
    title="Weather Data Collector with Geolocation API",
    description="API complète pour la collecte de données météo et géolocalisation",
    version="1.0.0"
)

# Middleware CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # En production, spécifier les domaines autorisés
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Inclure les routes de géolocalisation si disponible
if LOCATION_API_AVAILABLE:
    app.include_router(location_router, prefix="/api")
    print("✅ API de géolocalisation activée")

# =====================================
# CLASSE DE COLLECTE DE DONNÉES
# =====================================

class DataCollectionOrchestrator:
    """Orchestrateur principal pour la collecte de données"""
    
    def __init__(self):
        try:
            self.config = Config()
            self.logger = setup_logger(__name__)
            self.storage = DataStorage()
            self.air_quality_collector = AirQualityCollector(
                api_key=self.config.gcp_api_key,
                project_id=self.config.gcp_project_id
            )
            self.weather_collector = WeatherCollector(
                api_key=self.config.openweather_api_key
            )
            self.logger.info("Orchestrateur initialisé avec succès")
        except Exception as e:
            print(f"Erreur initialisation: {e}")
            raise
    
    async def collect_all_data(self, lat: float = None, lon: float = None) -> Dict[str, Any]:
        """
        Collecte toutes les données de manière asynchrone
        
        Args:
            lat: Latitude (optionnelle, utilise la config par défaut sinon)
            lon: Longitude (optionnelle, utilise la config par défaut sinon)
        """
        try:
            self.logger.info("Début de la collecte de données")
            
            # Utiliser les coordonnées fournies ou celles par défaut
            latitude = lat if lat is not None else self.config.default_latitude
            longitude = lon if lon is not None else self.config.default_longitude
            
            self.logger.info(f"Collecte pour: {latitude}, {longitude}")
            
            # Collecte parallèle des données
            air_quality_task = self.air_quality_collector.get_air_quality_data(latitude, longitude)
            weather_task = self.weather_collector.get_weather_data(latitude, longitude)
            
            air_quality_data, weather_data = await asyncio.gather(
                air_quality_task, 
                weather_task,
                return_exceptions=True
            )
            
            # Gestion des erreurs
            if isinstance(air_quality_data, Exception):
                self.logger.error(f"Erreur collecte qualité de l'air: {air_quality_data}")
                air_quality_data = None
            
            if isinstance(weather_data, Exception):
                self.logger.error(f"Erreur collecte météo: {weather_data}")
                weather_data = None
            
            # Création du payload final
            collected_data = {
                'timestamp': datetime.now(timezone.utc).isoformat(),
                'location': {
                    'latitude': latitude, 
                    'longitude': longitude,
                    'source': 'user_provided' if (lat is not None and lon is not None) else 'default_config'
                },
                'air_quality': air_quality_data,
                'weather': weather_data,
                'collection_status': {
                    'air_quality_success': air_quality_data is not None,
                    'weather_success': weather_data is not None,
                    'overall_success': air_quality_data is not None or weather_data is not None
                }
            }
            
            return collected_data
            
        except Exception as e:
            self.logger.error(f"Erreur lors de la collecte: {str(e)}")
            raise
    
    async def run(self, lat: float = None, lon: float = None):
        """
        Point d'entrée principal pour la collecte
        
        Args:
            lat: Latitude optionnelle
            lon: Longitude optionnelle
        """
        try:
            # Collecte des données
            data = await self.collect_all_data(lat, lon)
            
            # Sauvegarde
            result = await self.storage.save_data(data)
            
            # Log de succès
            success_msg = f"Collecte réussie - AQ: {data['collection_status']['air_quality_success']}, Weather: {data['collection_status']['weather_success']}"
            self.logger.info(success_msg)
            print(success_msg)
            
            return data
            
        except Exception as e:
            error_msg = f"Erreur critique: {str(e)}"
            self.logger.error(error_msg)
            print(error_msg)
            raise

# Instance globale pour l'API
orchestrator_instance = None

def get_orchestrator():
    """Obtenir l'instance de l'orchestrateur (singleton)"""
    global orchestrator_instance
    if orchestrator_instance is None:
        orchestrator_instance = DataCollectionOrchestrator()
    return orchestrator_instance

# =====================================
# ENDPOINTS FASTAPI
# =====================================

@app.get("/")
async def root():
    """Point d'entrée principal de l'API"""
    return {
        "message": "Weather Data Collector with Geolocation API",
        "version": "1.0.0",
        "endpoints": {
            "health": "/health",
            "collect": "/collect",
            "collect_location": "/collect/location",
            "status": "/status",
            "latest": "/latest",  
            "geolocation_api": "/api/location" if LOCATION_API_AVAILABLE else "not_available"
        },
        "features": {
            "weather_collection": True,
            "air_quality_collection": True,
            "geolocation_api": LOCATION_API_AVAILABLE,
            "firebase_storage": True
        }
    }

@app.get("/health")
async def health_check():
    """Health check complet avec statut géolocalisation"""
    try:
        # Vérifications de base
        config = Config()
        storage = DataStorage()
        firebase_status = storage.get_firebase_status()
        
        health_data = {
            "status": "healthy",
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "services": {
                "weather_collection": bool(config.openweather_api_key),
                "air_quality_collection": bool(config.gcp_api_key),
                "geolocation_api": LOCATION_API_AVAILABLE,
                "firebase": firebase_status.get("firestore_client_ready", False)
            },
            "configuration": {
                "gcp_project_configured": bool(config.gcp_project_id),
                "default_location": {
                    "latitude": config.default_latitude,
                    "longitude": config.default_longitude
                }
            },
            "api_keys": {
                "openweather": "configured" if config.openweather_api_key else "missing",
                "gcp_air_quality": "configured" if config.gcp_api_key else "missing"
            }
        }
        
        # Déterminer le statut global
        missing_keys = [k for k, v in health_data["api_keys"].items() if v == "missing"]
        if missing_keys:
            health_data["status"] = "degraded"
            health_data["warnings"] = f"Clés API manquantes: {', '.join(missing_keys)}"
        
        return health_data
        
    except Exception as e:
        raise HTTPException(status_code=500, detail={
            "status": "unhealthy", 
            "error": str(e),
            "timestamp": datetime.now(timezone.utc).isoformat()
        })

@app.get("/status")
async def simple_status():
    """Status simple pour les vérifications rapides"""
    try:
        orchestrator = get_orchestrator()
        return {
            "status": "operational",
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "collector_ready": True,
            "api_ready": True,
            "geolocation_available": LOCATION_API_AVAILABLE
        }
    except Exception as e:
        raise HTTPException(status_code=503, detail={"status": "error", "error": str(e)})

@app.post("/collect")
async def trigger_collection(background_tasks: BackgroundTasks):
    """Déclencher une collecte manuelle avec les coordonnées par défaut"""
    try:
        orchestrator = get_orchestrator()
        
        # Lancer la collecte en arrière-plan pour ne pas bloquer l'API
        background_tasks.add_task(run_background_collection, orchestrator)
        
        return {
            "success": True,
            "message": "Collecte de données démarrée en arrière-plan",
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "location": "default_configuration"
        }
        
    except Exception as e:
        raise HTTPException(status_code=500, detail={
            "success": False, 
            "error": str(e),
            "timestamp": datetime.now(timezone.utc).isoformat()
        })

@app.post("/collect/location")
async def trigger_location_collection(
    latitude: float, 
    longitude: float, 
    background_tasks: BackgroundTasks
):
    """Déclencher une collecte manuelle pour des coordonnées spécifiques"""
    try:
        # Validation des coordonnées
        if not (-90 <= latitude <= 90):
            raise HTTPException(status_code=400, detail="Latitude doit être entre -90 et 90")
        if not (-180 <= longitude <= 180):
            raise HTTPException(status_code=400, detail="Longitude doit être entre -180 et 180")
        
        orchestrator = get_orchestrator()
        
        # Lancer la collecte en arrière-plan
        background_tasks.add_task(run_background_collection, orchestrator, latitude, longitude)
        
        return {
            "success": True,
            "message": f"Collecte de données démarrée pour {latitude}, {longitude}",
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "location": {
                "latitude": latitude,
                "longitude": longitude
            }
        }
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail={
            "success": False, 
            "error": str(e),
            "timestamp": datetime.now(timezone.utc).isoformat()
        })

@app.get("/latest")
async def get_latest_data():
    """Récupérer les dernières données collectées"""
    try:
        latest_file = Path("data") / "latest_data.json"
        
        if not latest_file.exists():
            raise HTTPException(status_code=404, detail="Aucune donnée disponible")
        
        import json
        with open(latest_file, 'r', encoding='utf-8') as f:
            data = json.load(f)
        
        # Retourner un résumé sécurisé
        return {
            "timestamp": data.get("timestamp"),
            "location": data.get("location"),
            "collection_status": data.get("collection_status"),
            "data_summary": {
                "air_quality_available": data.get("air_quality") is not None,
                "weather_available": data.get("weather") is not None,
                "temperature": data.get("weather", {}).get("current", {}).get("temperature") if data.get("weather") else None,
                "aqi": data.get("air_quality", {}).get("indexes", [{}])[0].get("aqi") if data.get("air_quality", {}).get("indexes") else None
            }
        }
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

# =====================================
# FONCTIONS UTILITAIRES
# =====================================

async def run_background_collection(orchestrator, lat: float = None, lon: float = None):
    """Exécuter une collecte en arrière-plan"""
    try:
        result = await orchestrator.run(lat, lon)
        print(f"✅ Collecte en arrière-plan terminée: {result['timestamp']}")
    except Exception as e:
        print(f"❌ Erreur collecte en arrière-plan: {str(e)}")

async def collect_weather_data():
    """Fonction de collecte de données météo en mode standalone"""
    try:
        print("🚀 Démarrage du collecteur de données météo")
        
        orchestrator = DataCollectionOrchestrator()
        result = await orchestrator.run()
        
        # Affichage du résumé
        print(f"✅ Collecte terminée à {result['timestamp']}")
        print(f"📍 Location: {result['location']['latitude']}, {result['location']['longitude']}")
        print(f"🌬️  Air Quality: {'✅' if result['collection_status']['air_quality_success'] else '❌'}")
        print(f"🌤️  Weather: {'✅' if result['collection_status']['weather_success'] else '❌'}")
        
        return result
        
    except Exception as e:
        print(f"❌ Erreur fatale: {str(e)}")
        sys.exit(1)

def run_api_server():
    """Lancer le serveur API"""
    port = int(os.getenv("PORT", 8000))
    host = os.getenv("HOST", "0.0.0.0")
    
    print(f"🚀 Démarrage du serveur API sur {host}:{port}")
    print(f"📡 API de géolocalisation: {'✅ Activée' if LOCATION_API_AVAILABLE else '❌ Désactivée'}")
    
    uvicorn.run(
        app, 
        host=host, 
        port=port,
        log_level="info",
        access_log=True
    )

# =====================================
# POINT D'ENTRÉE PRINCIPAL
# =====================================

async def main():
    """Point d'entrée du script en mode collecte"""
    await collect_weather_data()

if __name__ == "__main__":
    # Gestion des arguments de ligne de commande
    if len(sys.argv) > 1:
        command = sys.argv[1].lower()
        
        if command == "collect":
            # Mode collecte de données
            print("📊 Mode: Collecte de données")
            asyncio.run(main())
            
        elif command == "server" or command == "api":
            # Mode serveur API
            print("🌐 Mode: Serveur API")
            run_api_server()
            
        elif command == "help":
            print("""
🌤️  Weather Data Collector - Modes d'utilisation:

python main.py collect  - Collecte unique de données météo
python main.py server   - Lancer le serveur API (port 8000)
python main.py api      - Alias pour 'server'
python main.py help     - Afficher cette aide

Sans argument: Lance le serveur API par défaut
            """)
        else:
            print(f"❌ Commande inconnue: {command}")
            print("Utilisez 'python main.py help' pour voir les options disponibles")
            sys.exit(1)
    else:
        # Mode par défaut: serveur API
        print("🌐 Mode par défaut: Serveur API")
        print("💡 Utilisez 'python main.py collect' pour une collecte unique")
        run_api_server()
