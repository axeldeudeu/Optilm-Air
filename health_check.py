"""
Système de stockage des données collectées
Inclut Firebase/Firestore pour l'app Flutter
"""

import os
import json
import logging
from datetime import datetime, timezone
from pathlib import Path
from typing import Dict, Any
from firebase.firebase_client import FirebaseClient


class DataStorage:
    """Gestionnaire de stockage des données avec Firebase"""
    
    def __init__(self):
        self.logger = logging.getLogger(__name__)
        self.firebase_client = None
        self._initialize_firebase()
    
    def _initialize_firebase(self):
        """Initialise le client Firebase si configuré"""
        try:
            if os.getenv("FIREBASE_CREDENTIALS_JSON") or os.getenv("FIREBASE_SERVICE_ACCOUNT_PATH"):
                self.firebase_client = FirebaseClient()
                self.logger.info("Firebase activé pour le stockage")
            else:
                self.logger.info("Firebase non configuré - stockage local uniquement")
        except Exception as e:
            self.logger.error(f"Erreur initialisation Firebase: {str(e)}")
            self.firebase_client = None
        
    async def save_data(self, data: Dict[str, Any]) -> Dict[str, bool]:
        """
        Sauvegarde les données en local et Firebase
        
        Args:
            data: Données à sauvegarder
            
        Returns:
            Dict avec le statut de chaque méthode de sauvegarde
        """
        results = {}
        
        # 1. Sauvegarde locale (toujours)
        local_result = await self._save_local_json(data)
        results['local_json'] = local_result
        
        # 2. Sauvegarde Firebase (si configuré)
        if self.firebase_client:
            try:
                firebase_result = await self.firebase_client.save_weather_data(data)
                results['firebase'] = firebase_result
                if firebase_result:
                    self.logger.info("✅ Données envoyées vers Firebase/Firestore")
                else:
                    self.logger.error("❌ Échec envoi vers Firebase")
            except Exception as e:
                self.logger.error(f"Erreur Firebase: {str(e)}")
                results['firebase'] = False
        else:
            results['firebase'] = False
            self.logger.info("Firebase non configuré - stockage local uniquement")
        
        return results
        
    async def _save_local_json(self, data: Dict[str, Any]) -> bool:
    async def _save_local_json(self, data: Dict[str, Any]) -> bool:
        """Sauvegarde en JSON local"""
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
            return True
            
        except Exception as e:
            self.logger.error(f"Erreur sauvegarde locale: {str(e)}")
            return False
    
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
    
    def get_firebase_status(self) -> Dict[str, Any]:
        """Retourne le statut de Firebase"""
        if self.firebase_client:
            return self.firebase_client.get_connection_status()
        return {
            'firebase_initialized': False,
            'firestore_client_ready': False,
            'error': 'Firebase non configuré'
        }
