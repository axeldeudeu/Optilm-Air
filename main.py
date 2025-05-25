#!/usr/bin/env python3
"""
Script principal pour collecter les données de qualité de l'air et météorologiques
Exécuté toutes les heures via cron-job sur Render
"""

import os
import sys
import json
import logging
from datetime import datetime, timezone
from typing import Dict, Any, Optional
import asyncio

from data_collectors.air_quality_collector import AirQualityCollector
from data_collectors.weather_collector import WeatherCollector
from storage.data_storage import DataStorage
from utils.logger import setup_logger
from utils.config import Config


class DataCollectionOrchestrator:
    """Orchestrateur principal pour la collecte de données"""
    
    def __init__(self):
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
    
    async def collect_all_data(self) -> Dict[str, Any]:
        """Collecte toutes les données de manière asynchrone"""
        try:
            self.logger.info("Début de la collecte de données")
            
            # Coordonnées par défaut (Paris) - à adapter selon vos besoins
            lat = float(os.getenv('DEFAULT_LATITUDE', '48.8566'))
            lon = float(os.getenv('DEFAULT_LONGITUDE', '2.3522'))
            
            # Collecte parallèle des données
            air_quality_task = self.air_quality_collector.get_air_quality_data(lat, lon)
            weather_task = self.weather_collector.get_weather_data(lat, lon)
            
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
                'location': {'latitude': lat, 'longitude': lon},
                'air_quality': air_quality_data,
                'weather': weather_data,
                'collection_status': {
                    'air_quality_success': air_quality_data is not None,
                    'weather_success': weather_data is not None
                }
            }
            
            return collected_data
            
        except Exception as e:
            self.logger.error(f"Erreur lors de la collecte: {str(e)}")
            raise
    
    async def run(self):
        """Point d'entrée principal"""
        try:
            # Collecte des données
            data = await self.collect_all_data()
            
            # Sauvegarde
            await self.storage.save_data(data)
            
            # Log de succès
            self.logger.info(f"Collecte réussie - AQ: {data['collection_status']['air_quality_success']}, Weather: {data['collection_status']['weather_success']}")
            
            return data
            
        except Exception as e:
            self.logger.error(f"Erreur critique: {str(e)}")
            sys.exit(1)


async def main():
    """Point d'entrée du script"""
    orchestrator = DataCollectionOrchestrator()
    result = await orchestrator.run()
    
    # Affichage du résumé
    print(f"✅ Collecte terminée à {result['timestamp']}")
    print(f"📍 Location: {result['location']['latitude']}, {result['location']['longitude']}")
    print(f"🌬️  Air Quality: {'✅' if result['collection_status']['air_quality_success'] else '❌'}")
    print(f"🌤️  Weather: {'✅' if result['collection_status']['weather_success'] else '❌'}")


if __name__ == "__main__":
    asyncio.run(main())