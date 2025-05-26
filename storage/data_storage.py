"""
Système de stockage des données collectées
Version simplifiée pour éviter les problèmes de dépendances
"""

import os
import json
import logging
from datetime import datetime, timezone
from pathlib import Path
from typing import Dict, Any


class DataStorage:
    """Gestionnaire de stockage des données - Version simplifiée"""
    
    def __init__(self):
        self.logger = logging.getLogger(__name__)
        
    async def save_data(self, data: Dict[str, Any]) -> Dict[str, bool]:
        """
        Sauvegarde les données en JSON local
        
        Args:
            data: Données à sauvegarder
            
        Returns:
            Dict avec le statut de sauvegarde
        """
        try:
            # Créer le dossier de données
            data_dir = Path("data")
            data_dir.mkdir(exist_ok=True)
            
            # Nom de fichier avec timestamp
            timestamp = datetime.now(timezone.utc).strftime("%Y%m%d_%H%M%S")
            filename = f"weather_data_{timestamp}.json"
            filepath = data_dir / filename
            
            # Sauvegarde synchrone (plus simple)
            with open(filepath, 'w', encoding='utf-8') as f:
                f.write(json.dumps(data, indent=2, ensure_ascii=False))
            
            # Maintenir aussi un fichier "latest"
            latest_path = data_dir / "latest_data.json"
            with open(latest_path, 'w', encoding='utf-8') as f:
                f.write(json.dumps(data, indent=2, ensure_ascii=False))
            
            self.logger.info(f"Données sauvées localement: {filepath}")
            return {"local_json": True}
            
        except Exception as e:
            self.logger.error(f"Erreur sauvegarde locale: {str(e)}")
            return {"local_json": False}
    
    def get_latest_data(self) -> Dict[str, Any]:
        """Récupère les dernières données sauvegardées"""
        try:
            latest_path = Path("data") / "latest_data.json"
            if latest_path.exists():
                with open(latest_path, 'r', encoding='utf-8') as f:
                    return json.loads(f.read())
            return None
        except Exception as e:
            self.logger.error(f"Erreur lecture données: {str(e)}")
            return None
