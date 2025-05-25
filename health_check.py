"""
Health check endpoint pour Render
Vérifie que le service est opérationnel
"""

import os
import json
import asyncio
from datetime import datetime, timezone
from pathlib import Path
from fastapi import FastAPI, HTTPException
import uvicorn
import logging

from utils.config import Config
from utils.logger import setup_logger

app = FastAPI(title="Weather Data Collector Health Check")
logger = setup_logger(__name__)


@app.get("/")
async def root():
    """Point d'entrée principal"""
    return {"status": "ok", "service": "weather-data-collector"}


@app.get("/health")
async def health_check():
    """
    Health check complet du service
    """
    try:
        health_status = {
            "status": "healthy",
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "checks": {}
        }
        
        # Vérification de la configuration
        try:
            config = Config()
            health_status["checks"]["config"] = {
                "status": "ok",
                "gcp_configured": bool(config.gcp_api_key),
                "openweather_configured": bool(config.openweather_api_key)
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
            
            health_status["checks"]["filesystem"] = {
                "status": "ok",
                "data_dir_exists": data_dir.exists(),
                "logs_dir_exists": logs_dir.exists(),
                "data_dir_writable": os.access(data_dir.parent, os.W_OK)
            }
        except Exception as e:
            health_status["checks"]["filesystem"] = {
                "status": "error",
                "error": str(e)
            }
            health_status["status"] = "unhealthy"
        
        # Vérification des dernières données
        try:
            latest_file = Path("data") / "latest_data.json"
            if latest_file.exists():
                stat = latest_file.stat()
                health_status["checks"]["last_collection"] = {
                    "status": "ok",
                    "last_modified": datetime.fromtimestamp(stat.st_mtime, timezone.utc).isoformat(),
                    "file_size": stat.st_size
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
        
        # Retourner le statut approprié
        if health_status["status"] == "unhealthy":
            raise HTTPException(status_code=503, detail=health_status)
        
        return health_status
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Erreur health check: {str(e)}")
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
        "uptime": "active"
    }


@app.get("/latest")
async def get_latest_data():
    """
    Retourne les dernières données collectées (si disponibles)
    """
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
            }
        }
        
        return summary
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Erreur récupération données: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/metrics")
async def get_metrics():
    """
    Métriques basiques du service
    """
    try:
        data_dir = Path("data")
        logs_dir = Path("logs")
        
        metrics = {
            "files": {
                "data_files": len(list(data_dir.glob("*.json"))) if data_dir.exists() else 0,
                "log_files": len(list(logs_dir.glob("*.log"))) if logs_dir.exists() else 0
            },
            "disk_usage": {},
            "timestamp": datetime.now(timezone.utc).isoformat()
        }
        
        # Utilisation disque si possible
        try:
            if data_dir.exists():
                total_size = sum(f.stat().st_size for f in data_dir.glob("*") if f.is_file())
                metrics["disk_usage"]["data_dir_mb"] = round(total_size / (1024 * 1024), 2)
        except:
            pass
        
        return metrics
        
    except Exception as e:
        logger.error(f"Erreur métriques: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))


def run_health_server():
    """Lance le serveur de health check"""
    port = int(os.getenv("PORT", 8000))
    uvicorn.run(app, host="0.0.0.0", port=port, log_level="info")


if __name__ == "__main__":
    run_health_server()