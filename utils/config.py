"""
Configuration et gestion des variables d'environnement
"""

import os
import logging


class Config:
    """Gestionnaire de configuration centralisé"""
    
    def __init__(self):
        self._validate_config()
    
    @property
    def gcp_api_key(self) -> str:
        """Clé API Google Cloud Platform Air Quality"""
        key = os.getenv("GCP_AIR_QUALITY_API_KEY")
        if not key:
            raise ValueError("GCP_AIR_QUALITY_API_KEY non définie")
        return key
    
    @property
    def gcp_project_id(self) -> str:
        """ID du projet Google Cloud Platform"""
        project_id = os.getenv("GCP_PROJECT_ID")
        if not project_id:
            raise ValueError("GCP_PROJECT_ID non défini")
        return project_id
    
    @property
    def openweather_api_key(self) -> str:
        """Clé API OpenWeather"""
        key = os.getenv("OPENWEATHER_API_KEY")
        if not key:
            raise ValueError("OPENWEATHER_API_KEY non définie")
        return key
    
    @property
    def default_latitude(self) -> float:
        """Latitude par défaut"""
        return float(os.getenv("DEFAULT_LATITUDE", "48.8566"))
    
    @property
    def default_longitude(self) -> float:
        """Longitude par défaut"""
        return float(os.getenv("DEFAULT_LONGITUDE", "2.3522"))
    
    @property
    def log_level(self) -> str:
        """Niveau de logging"""
        return os.getenv("LOG_LEVEL", "INFO").upper()
    
    def _validate_config(self):
        """Valide la configuration au démarrage"""
        required_vars = [
            "GCP_AIR_QUALITY_API_KEY",
            "GCP_PROJECT_ID", 
            "OPENWEATHER_API_KEY"
        ]
        
        missing_vars = []
        for var in required_vars:
            if not os.getenv(var):
                missing_vars.append(var)
        
        if missing_vars:
            error_msg = f"Variables d'environnement manquantes: {', '.join(missing_vars)}"
            print(f"ERREUR CONFIG: {error_msg}")
            raise ValueError(error_msg)
        
        print("Configuration validée avec succès")
