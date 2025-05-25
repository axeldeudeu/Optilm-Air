"""
Configuration et gestion des variables d'environnement
"""

import os
from typing import Optional
import logging


class Config:
    """Gestionnaire de configuration centralisé"""
    
    def __init__(self):
        self.logger = logging.getLogger(__name__)
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
        return float(os.getenv("DEFAULT_LATITUDE", "48.8566"))  # Paris par défaut
    
    @property
    def default_longitude(self) -> float:
        """Longitude par défaut"""
        return float(os.getenv("DEFAULT_LONGITUDE", "2.3522"))  # Paris par défaut
    
    @property
    def log_level(self) -> str:
        """Niveau de logging"""
        return os.getenv("LOG_LEVEL", "INFO").upper()
    
    @property
    def database_url(self) -> Optional[str]:
        """URL de la base de données PostgreSQL"""
        return os.getenv("DATABASE_URL")
    
    @property
    def webhook_url(self) -> Optional[str]:
        """URL du webhook pour l'envoi de données"""
        return os.getenv("WEBHOOK_URL")
    
    @property
    def webhook_secret(self) -> Optional[str]:
        """Secret pour le webhook"""
        return os.getenv("WEBHOOK_SECRET")
    
    @property
    def custom_api_url(self) -> Optional[str]:
        """URL de l'API personnalisée"""
        return os.getenv("CUSTOM_API_URL")
    
    @property
    def custom_api_key(self) -> Optional[str]:
        """Clé pour l'API personnalisée"""
        return os.getenv("CUSTOM_API_KEY")
    
    @property
    def cleanup_days(self) -> int:
        """Nombre de jours à conserver pour les fichiers locaux"""
        return int(os.getenv("CLEANUP_DAYS", "7"))
    
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
            self.logger.error(error_msg)
            raise ValueError(error_msg)
        
        self.logger.info("Configuration validée avec succès")
    
    def get_location_config(self) -> tuple[float, float]:
        """Retourne les coordonnées par défaut"""
        return self.default_latitude, self.default_longitude
    
    def is_database_enabled(self) -> bool:
        """Vérifie si la base de données est configurée"""
        return self.database_url is not None
    
    def is_webhook_enabled(self) -> bool:
        """Vérifie si le webhook est configuré"""
        return self.webhook_url is not None
    
    def is_custom_api_enabled(self) -> bool:
        """Vérifie si l'API personnalisée est configurée"""
        return self.custom_api_url is not None
    
    def get_summary(self) -> dict:
        """Retourne un résumé de la configuration (sans secrets)"""
        return {
            "gcp_project_id": self.gcp_project_id,
            "default_location": [self.default_latitude, self.default_longitude],
            "log_level": self.log_level,
            "database_enabled": self.is_database_enabled(),
            "webhook_enabled": self.is_webhook_enabled(),
            "custom_api_enabled": self.is_custom_api_enabled(),
            "cleanup_days": self.cleanup_days
        }