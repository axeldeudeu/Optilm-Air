"""
Système de stockage des données collectées
Supporte JSON local, PostgreSQL et envoi vers des APIs externes
"""

import os
import json
import asyncio
import aiofiles
import aiohttp
from typing import Dict, Any, Optional
import logging
from datetime import datetime, timezone
from pathlib import Path


class DataStorage:
    """Gestionnaire de stockage des données"""
    
    def __init__(self):
        self.logger = logging.getLogger(__name__)
        self.storage_methods = self._get_storage_methods()
        
    def _get_storage_methods(self) -> list:
        """Détermine les méthodes de stockage activées"""
        methods = []
        
        # Stockage local JSON (toujours activé)
        methods.append("local_json")
        
        # PostgreSQL si configuré
        if os.getenv("DATABASE_URL"):
            methods.append("postgresql")
            
        # Webhook si configuré
        if os.getenv("WEBHOOK_URL"):
            methods.append("webhook")
            
        # API custom si configurée
        if os.getenv("CUSTOM_API_URL"):
            methods.append("custom_api")
            
        return methods
    
    async def save_data(self, data: Dict[str, Any]) -> Dict[str, bool]:
        """
        Sauvegarde les données selon toutes les méthodes configurées
        
        Args:
            data: Données à sauvegarder
            
        Returns:
            Dict avec le statut de chaque méthode de sauvegarde
        """
        results = {}
        
        # Exécution parallèle de toutes les sauvegardes
        tasks = []
        
        if "local_json" in self.storage_methods:
            tasks.append(self._save_local_json(data))
            
        if "postgresql" in self.storage_methods:
            tasks.append(self._save_postgresql(data))
            
        if "webhook" in self.storage_methods:
            tasks.append(self._send_webhook(data))
            
        if "custom_api" in self.storage_methods:
            tasks.append(self._send_custom_api(data))
        
        # Attendre tous les résultats
        if tasks:
            task_results = await asyncio.gather(*tasks, return_exceptions=True)
            
            for i, method in enumerate(self.storage_methods):
                if i < len(task_results):
                    result = task_results[i]
                    results[method] = not isinstance(result, Exception)
                    if isinstance(result, Exception):
                        self.logger.error(f"Erreur {method}: {result}")
        
        self.logger.info(f"Sauvegarde terminée: {results}")
        return results
    
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
            
            # Sauvegarde asynchrone
            async with aiofiles.open(filepath, 'w', encoding='utf-8') as f:
                await f.write(json.dumps(data, indent=2, ensure_ascii=False))
            
            # Maintenir aussi un fichier "latest"
            latest_path = data_dir / "latest_data.json"
            async with aiofiles.open(latest_path, 'w', encoding='utf-8') as f:
                await f.write(json.dumps(data, indent=2, ensure_ascii=False))
            
            self.logger.info(f"Données sauvées localement: {filepath}")
            return True
            
        except Exception as e:
            self.logger.error(f"Erreur sauvegarde locale: {str(e)}")
            return False
    
    async def _save_postgresql(self, data: Dict[str, Any]) -> bool:
        """Sauvegarde en base PostgreSQL"""
        try:
            import asyncpg
            
            database_url = os.getenv("DATABASE_URL")
            if not database_url:
                return False
            
            conn = await asyncpg.connect(database_url)
            
            try:
                # Création de la table si elle n'existe pas
                await conn.execute('''
                    CREATE TABLE IF NOT EXISTS weather_data (
                        id SERIAL PRIMARY KEY,
                        collected_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
                        latitude FLOAT,
                        longitude FLOAT,
                        air_quality_data JSONB,
                        weather_data JSONB,
                        collection_status JSONB,
                        raw_data JSONB
                    )
                ''')
                
                # Insertion des données
                await conn.execute('''
                    INSERT INTO weather_data 
                    (latitude, longitude, air_quality_data, weather_data, collection_status, raw_data)
                    VALUES ($1, $2, $3, $4, $5, $6)
                ''', 
                    data['location']['latitude'],
                    data['location']['longitude'],
                    json.dumps(data.get('air_quality')),
                    json.dumps(data.get('weather')),
                    json.dumps(data.get('collection_status')),
                    json.dumps(data)
                )
                
                self.logger.info("Données sauvées en PostgreSQL")
                return True
                
            finally:
                await conn.close()
                
        except ImportError:
            self.logger.warning("asyncpg non installé - sauvegarde PostgreSQL ignorée")
            return False
        except Exception as e:
            self.logger.error(f"Erreur PostgreSQL: {str(e)}")
            return False
    
    async def _send_webhook(self, data: Dict[str, Any]) -> bool:
        """Envoi des données via webhook"""
        try:
            webhook_url = os.getenv("WEBHOOK_URL")
            webhook_secret = os.getenv("WEBHOOK_SECRET")
            
            if not webhook_url:
                return False
            
            headers = {"Content-Type": "application/json"}
            if webhook_secret:
                headers["Authorization"] = f"Bearer {webhook_secret}"
            
            # Payload simplifié pour le webhook
            payload = {
                "timestamp": data["timestamp"],
                "location": data["location"],
                "air_quality_success": data["collection_status"]["air_quality_success"],
                "weather_success": data["collection_status"]["weather_success"],
                "data": data
            }
            
            async with aiohttp.ClientSession() as session:
                async with session.post(webhook_url, json=payload, headers=headers) as response:
                    if response.status in [200, 201, 202]:
                        self.logger.info(f"Webhook envoyé avec succès: {response.status}")
                        return True
                    else:
                        self.logger.error(f"Erreur webhook: {response.status}")
                        return False
                        
        except Exception as e:
            self.logger.error(f"Erreur webhook: {str(e)}")
            return False
    
    async def _send_custom_api(self, data: Dict[str, Any]) -> bool:
        """Envoi vers une API personnalisée"""
        try:
            api_url = os.getenv("CUSTOM_API_URL")
            api_key = os.getenv("CUSTOM_API_KEY")
            
            if not api_url:
                return False
            
            headers = {"Content-Type": "application/json"}
            if api_key:
                headers["X-API-Key"] = api_key
            
            async with aiohttp.ClientSession() as session:
                async with session.post(api_url, json=data, headers=headers) as response:
                    if response.status in [200, 201, 202]:
                        self.logger.info(f"API personnalisée: {response.status}")
                        return True
                    else:
                        self.logger.error(f"Erreur API personnalisée: {response.status}")
                        return False
                        
        except Exception as e:
            self.logger.error(f"Erreur API personnalisée: {str(e)}")
            return False
    
    async def get_latest_data(self) -> Optional[Dict[str, Any]]:
        """Récupère les dernières données sauvegardées"""
        try:
            latest_path = Path("data") / "latest_data.json"
            if latest_path.exists():
                async with aiofiles.open(latest_path, 'r', encoding='utf-8') as f:
                    content = await f.read()
                    return json.loads(content)
            return None
        except Exception as e:
            self.logger.error(f"Erreur lecture données: {str(e)}")
            return None
    
    async def cleanup_old_files(self, days_to_keep: int = 7) -> int:
        """Nettoie les anciens fichiers JSON"""
        try:
            data_dir = Path("data")
            if not data_dir.exists():
                return 0
            
            cutoff_time = datetime.now().timestamp() - (days_to_keep * 24 * 60 * 60)
            cleaned_count = 0
            
            for file_path in data_dir.glob("weather_data_*.json"):
                if file_path.stat().st_mtime < cutoff_time:
                    file_path.unlink()
                    cleaned_count += 1
            
            if cleaned_count > 0:
                self.logger.info(f"Nettoyage: {cleaned_count} fichiers supprimés")
            
            return cleaned_count
            
        except Exception as e:
            self.logger.error(f"Erreur nettoyage: {str(e)}")
            return 0