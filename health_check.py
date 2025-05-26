"""
Health check endpoint pour Render - Version complète avec géolocalisation
"""

import os
import json
from datetime import datetime, timezone
from pathlib import Path
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
import uvicorn

from storage.data_storage import DataStorage

app = FastAPI(
    title="Weather Data Collector API",
    description="API complète pour la collecte de données météo et géolocalisation",
    version="1.0.0"
)

# Middleware CORS pour les applications Flutter/Web
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # En production, spécifier les domaines autorisés
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Initialiser le storage pour les checks Firebase
storage = DataStorage()

# =====================================
# ENDPOINTS PRINCIPAUX
# =====================================

@app.get("/")
async def root():
    """Point d'entrée principal"""
    return {
        "status": "ok", 
        "service": "weather-data-collector",
        "version": "1.0.0",
        "endpoints": {
            "health": "/health",
            "status": "/status", 
            "latest": "/latest",
            "metrics": "/metrics",
            "firebase": "/firebase",
            "location_status": "/api/location/status"
        }
    }

@app.get("/health")
async def health_check():
    """Health check complet du service"""
    try:
        health_status = {
            "status": "healthy",
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "checks": {}
        }
        
        # Vérification de la configuration
        try:
            required_vars = ["GCP_AIR_QUALITY_API_KEY", "GCP_PROJECT_ID", "OPENWEATHER_API_KEY"]
            missing_vars = [var for var in required_vars if not os.getenv(var)]
            
            if missing_vars:
                health_status["checks"]["config"] = {
                    "status": "error",
                    "missing_vars": missing_vars
                }
                health_status["status"] = "unhealthy"
            else:
                health_status["checks"]["config"] = {
                    "status": "ok",
                    "gcp_configured": bool(os.getenv("GCP_AIR_QUALITY_API_KEY")),
                    "openweather_configured": bool(os.getenv("OPENWEATHER_API_KEY")),
                    "firebase_configured": bool(os.getenv("FIREBASE_CREDENTIALS_JSON") or os.getenv("FIREBASE_SERVICE_ACCOUNT_PATH"))
                }
        except Exception as e:
            health_status["checks"]["config"] = {
                "status": "error",
                "error": str(e)
            }
            health_status["status"] = "unhealthy"
        
        # Vérification du système de fichiers
        try:
            data_dir = Path("data")
            logs_dir = Path("logs")
            
            # Créer les dossiers s'ils n'existent pas
            data_dir.mkdir(exist_ok=True)
            logs_dir.mkdir(exist_ok=True)
            
            health_status["checks"]["filesystem"] = {
                "status": "ok",
                "data_dir_exists": data_dir.exists(),
                "logs_dir_exists": logs_dir.exists(),
                "data_dir_writable": os.access(data_dir, os.W_OK),
                "logs_dir_writable": os.access(logs_dir, os.W_OK)
            }
        except Exception as e:
            health_status["checks"]["filesystem"] = {
                "status": "error",
                "error": str(e)
            }
        
        # Vérification de Firebase
        try:
            firebase_status = storage.get_firebase_status()
            health_status["checks"]["firebase"] = firebase_status
            
            # Si Firebase n'est pas disponible, marquer comme warning (pas critique)
            if not firebase_status.get("firestore_client_ready", False):
                if health_status["status"] == "healthy":
                    health_status["status"] = "degraded"
                    
        except Exception as e:
            health_status["checks"]["firebase"] = {
                "status": "error",
                "error": str(e)
            }
            if health_status["status"] == "healthy":
                health_status["status"] = "degraded"
        
        # Vérification des dernières données
        try:
            latest_file = Path("data") / "latest_data.json"
            if latest_file.exists():
                stat = latest_file.stat()
                last_modified = datetime.fromtimestamp(stat.st_mtime, timezone.utc)
                age_hours = (datetime.now(timezone.utc) - last_modified).total_seconds() / 3600
                
                health_status["checks"]["last_collection"] = {
                    "status": "ok" if age_hours < 24 else "warning",
                    "last_modified": last_modified.isoformat(),
                    "file_size": stat.st_size,
                    "age_hours": round(age_hours, 2)
                }
            else:
                health_status["checks"]["last_collection"] = {
                    "status": "warning",
                    "message": "Aucune donnée collectée encore"
                }
        except Exception as e:
            health_status["checks"]["last_collection"] = {
                "status": "error",
                "error": str(e)
            }
        
        # Déterminer le code de statut HTTP
        status_code = 200
        if health_status["status"] == "unhealthy":
            status_code = 503
        elif health_status["status"] == "degraded":
            status_code = 200  # Service partiellement fonctionnel
        
        if status_code == 503:
            raise HTTPException(status_code=status_code, detail=health_status)
        
        return health_status
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail={
            "status": "error",
            "error": str(e),
            "timestamp": datetime.now(timezone.utc).isoformat()
        })

@app.get("/status")
async def simple_status():
    """Status simple pour les checks rapides"""
    return {
        "status": "ok",
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "uptime": "active",
        "service": "weather-data-collector"
    }

# =====================================
# ENDPOINTS DE DONNÉES
# =====================================

@app.get("/latest")
async def get_latest_data():
    """Retourne les dernières données collectées (si disponibles)"""
    try:
        latest_file = Path("data") / "latest_data.json"
        
        if not latest_file.exists():
            raise HTTPException(status_code=404, detail="Aucune donnée disponible")
        
        with open(latest_file, 'r', encoding='utf-8') as f:
            data = json.load(f)
        
        # Retourner seulement un résumé pour la sécurité
        summary = {
            "timestamp": data.get("timestamp"),
            "location": data.get("location"),
            "collection_status": data.get("collection_status"),
            "data_available": {
                "air_quality": data.get("air_quality") is not None,
                "weather": data.get("weather") is not None
            },
            "summary": {
                "temperature": None,
                "aqi": None,
                "weather_description": None
            }
        }
        
        # Ajouter des données de résumé si disponibles
        if data.get("weather") and data["weather"].get("current"):
            summary["summary"]["temperature"] = data["weather"]["current"].get("temperature")
            weather_info = data["weather"]["current"].get("weather", {})
            summary["summary"]["weather_description"] = weather_info.get("description")
        
        if data.get("air_quality") and data["air_quality"].get("indexes"):
            if data["air_quality"]["indexes"]:
                summary["summary"]["aqi"] = data["air_quality"]["indexes"][0].get("aqi")
        
        return summary
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/metrics")
async def get_metrics():
    """Métriques basiques du service"""
    try:
        data_dir = Path("data")
        logs_dir = Path("logs")
        
        # Calculer les métriques de fichiers
        data_files = list(data_dir.glob("*.json")) if data_dir.exists() else []
        log_files = list(logs_dir.glob("*.log")) if logs_dir.exists() else []
        
        # Calculer la taille totale
        total_data_size = sum(f.stat().st_size for f in data_files)
        total_log_size = sum(f.stat().st_size for f in log_files)
        
        metrics = {
            "files": {
                "data_files": len(data_files),
                "log_files": len(log_files),
                "total_data_size_mb": round(total_data_size / (1024 * 1024), 2),
                "total_log_size_mb": round(total_log_size / (1024 * 1024), 2)
            },
            "disk_usage": {
                "data_directory": str(data_dir) if data_dir.exists() else "N/A",
                "logs_directory": str(logs_dir) if logs_dir.exists() else "N/A"
            },
            "timestamp": datetime.now(timezone.utc).isoformat()
        }
        
        return metrics
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

# =====================================
# ENDPOINTS FIREBASE
# =====================================

@app.get("/firebase")
async def firebase_status():
    """Status détaillé de Firebase"""
    try:
        firebase_status = storage.get_firebase_status()
        
        # Ajouter des informations supplémentaires
        firebase_status.update({
            "configuration": {
                "credentials_method": "environment_variable" if os.getenv("FIREBASE_CREDENTIALS_JSON") else "service_account_file",
                "project_configured": bool(os.getenv("GCP_PROJECT_ID")),
                "credentials_available": bool(os.getenv("FIREBASE_CREDENTIALS_JSON") or os.getenv("FIREBASE_SERVICE_ACCOUNT_PATH"))
            }
        })
        
        return firebase_status
    except Exception as e:
        raise HTTPException(status_code=500, detail={
            "error": str(e),
            "firebase_available": False,
            "timestamp": datetime.now(timezone.utc).isoformat()
        })

# =====================================
# ENDPOINTS DE GÉOLOCALISATION
# =====================================

@app.get("/api/location/status")
async def location_service_status():
    """Status du service de géolocalisation"""
    try:
        # Vérifier les connexions Firebase
        firebase_status = storage.get_firebase_status()
        
        # Vérifier les APIs
        apis_status = {
            "gcp_air_quality": {
                "configured": bool(os.getenv("GCP_AIR_QUALITY_API_KEY")),
                "api_key_length": len(os.getenv("GCP_AIR_QUALITY_API_KEY", "")) if os.getenv("GCP_AIR_QUALITY_API_KEY") else 0
            },
            "openweather": {
                "configured": bool(os.getenv("OPENWEATHER_API_KEY")),
                "api_key_length": len(os.getenv("OPENWEATHER_API_KEY", "")) if os.getenv("OPENWEATHER_API_KEY") else 0
            },
            "firebase": {
                "configured": firebase_status.get("firestore_client_ready", False),
                "connection_ready": firebase_status.get("firebase_initialized", False)
            }
        }
        
        # Déterminer le statut global
        all_apis_ready = (
            apis_status["gcp_air_quality"]["configured"] and
            apis_status["openweather"]["configured"] and
            apis_status["firebase"]["configured"]
        )
        
        service_status = "operational" if all_apis_ready else "degraded"
        
        return {
            "status": service_status,
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "apis": apis_status,
            "firebase": firebase_status,
            "capabilities": {
                "weather_data": apis_status["openweather"]["configured"],
                "air_quality": apis_status["gcp_air_quality"]["configured"],
                "user_location_storage": apis_status["firebase"]["configured"],
                "real_time_data": all_apis_ready
            },
            "service_info": {
                "version": "1.0.0",
                "supported_features": [
                    "weather_collection",
                    "air_quality_monitoring", 
                    "user_location_tracking",
                    "firebase_storage"
                ]
            }
        }
        
    except Exception as e:
        raise HTTPException(status_code=500, detail={
            "status": "error",
            "error": str(e),
            "timestamp": datetime.now(timezone.utc).isoformat()
        })

@app.get("/api/location/health")
async def location_health_check():
    """Health check spécifique pour les services de géolocalisation"""
    try:
        health_data = {
            "status": "healthy",
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "services": {}
        }
        
        # Check GCP Air Quality API
        try:
            gcp_key = os.getenv("GCP_AIR_QUALITY_API_KEY")
            health_data["services"]["gcp_air_quality"] = {
                "status": "ready" if gcp_key else "not_configured",
                "configured": bool(gcp_key)
            }
        except Exception as e:
            health_data["services"]["gcp_air_quality"] = {
                "status": "error",
                "error": str(e)
            }
        
        # Check OpenWeather API
        try:
            ow_key = os.getenv("OPENWEATHER_API_KEY")
            health_data["services"]["openweather"] = {
                "status": "ready" if ow_key else "not_configured",
                "configured": bool(ow_key)
            }
        except Exception as e:
            health_data["services"]["openweather"] = {
                "status": "error", 
                "error": str(e)
            }
        
        # Check Firebase
        try:
            firebase_status = storage.get_firebase_status()
            health_data["services"]["firebase"] = {
                "status": "ready" if firebase_status.get("firestore_client_ready") else "not_ready",
                "details": firebase_status
            }
        except Exception as e:
            health_data["services"]["firebase"] = {
                "status": "error",
                "error": str(e)
            }
        
        # Déterminer le statut global
        service_statuses = [service.get("status") for service in health_data["services"].values()]
        if "error" in service_statuses:
            health_data["status"] = "unhealthy"
        elif "not_configured" in service_statuses or "not_ready" in service_statuses:
            health_data["status"] = "degraded"
        
        return health_data
        
    except Exception as e:
        raise HTTPException(status_code=500, detail={
            "status": "error",
            "error": str(e),
            "timestamp": datetime.now(timezone.utc).isoformat()
        })

# =====================================
# ENDPOINTS UTILITAIRES
# =====================================

@app.get("/api/config/check")
async def config_check():
    """Vérification de la configuration sans exposer les clés"""
    try:
        config_status = {
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "environment_variables": {},
            "files": {},
            "status": "ok"
        }
        
        # Vérifier les variables d'environnement (sans exposer les valeurs)
        env_vars = [
            "GCP_AIR_QUALITY_API_KEY",
            "GCP_PROJECT_ID", 
            "OPENWEATHER_API_KEY",
            "FIREBASE_CREDENTIALS_JSON",
            "FIREBASE_SERVICE_ACCOUNT_PATH",
            "PORT"
        ]
        
        for var in env_vars:
            value = os.getenv(var)
            config_status["environment_variables"][var] = {
                "set": bool(value),
                "length": len(value) if value else 0
            }
        
        # Vérifier les fichiers
        files_to_check = [
            "firebase-service-account.json",
            "data/latest_data.json"
        ]
        
        for file_path in files_to_check:
            path = Path(file_path)
            config_status["files"][file_path] = {
                "exists": path.exists(),
                "size": path.stat().st_size if path.exists() else 0
            }
        
        return config_status
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

# =====================================
# FONCTION DE LANCEMENT
# =====================================

def run_health_server():
    """Lance le serveur de health check"""
    port = int(os.getenv("PORT", 8000))
    host = os.getenv("HOST", "0.0.0.0")
    
    uvicorn.run(
        app, 
        host=host, 
        port=port, 
        log_level="info",
        access_log=True
    )

if __name__ == "__main__":
    run_health_server()
