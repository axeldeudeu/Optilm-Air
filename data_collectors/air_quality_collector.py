"""
Collecteur de données de qualité de l'air via GCP Air Quality API - Version simplifiée
"""

import aiohttp
import asyncio
import logging
from typing import Dict, Any, Optional
from datetime import datetime, timezone


class AirQualityCollector:
    """Collecteur pour les données de qualité de l'air GCP"""
    
    def __init__(self, api_key: str, project_id: str):
        self.api_key = api_key
        self.project_id = project_id
        self.base_url = "https://airquality.googleapis.com/v1"
        self.logger = logging.getLogger(__name__)
    
    async def get_air_quality_data(self, latitude: float, longitude: float) -> Optional[Dict[str, Any]]:
        """
        Récupère les données de qualité de l'air pour une localisation donnée
        """
        try:
            url = f"{self.base_url}/currentConditions:lookup"
            
            payload = {
                "location": {
                    "latitude": latitude,
                    "longitude": longitude
                },
                "extraComputations": [
                    "HEALTH_RECOMMENDATIONS",
                    "DOMINANT_POLLUTANT_CONCENTRATION",
                    "POLLUTANT_CONCENTRATION",
                    "LOCAL_AQI"
                ],
                "languageCode": "fr"
            }
            
            headers = {
                "Content-Type": "application/json",
                "X-Goog-Api-Key": self.api_key,
                "X-Goog-User-Project": self.project_id
            }
            
            timeout = aiohttp.ClientTimeout(total=30)
            async with aiohttp.ClientSession(timeout=timeout) as session:
                async with session.post(url, json=payload, headers=headers) as response:
                    if response.status == 200:
                        data = await response.json()
                        return self._process_air_quality_response(data)
                    else:
                        error_text = await response.text()
                        self.logger.error(f"Erreur API Air Quality: {response.status} - {error_text}")
                        return None
                        
        except asyncio.TimeoutError:
            self.logger.error("Timeout lors de la requête Air Quality API")
            return None
        except Exception as e:
            self.logger.error(f"Erreur lors de la collecte Air Quality: {str(e)}")
            return None
    
    def _process_air_quality_response(self, raw_data: Dict[str, Any]) -> Dict[str, Any]:
        """Traite et structure la réponse de l'API Air Quality"""
        try:
            processed_data = {
                "collected_at": datetime.now(timezone.utc).isoformat(),
                "data_source": "gcp_air_quality_api"
            }
            
            # Index de qualité de l'air
            if "indexes" in raw_data:
                processed_data["indexes"] = []
                for index in raw_data["indexes"]:
                    index_data = {
                        "code": index.get("code"),
                        "display_name": index.get("displayName"),
                        "aqi": index.get("aqi"),
                        "category": index.get("category"),
                        "color": index.get("color", {})
                    }
                    processed_data["indexes"].append(index_data)
            
            # Polluants
            if "pollutants" in raw_data:
                processed_data["pollutants"] = []
                for pollutant in raw_data["pollutants"]:
                    pollutant_data = {
                        "code": pollutant.get("code"),
                        "display_name": pollutant.get("displayName"),
                        "full_name": pollutant.get("fullName"),
                        "concentration": pollutant.get("concentration", {}),
                        "additional_info": pollutant.get("additionalInfo", {})
                    }
                    processed_data["pollutants"].append(pollutant_data)
            
            # Recommandations santé
            if "healthRecommendations" in raw_data:
                processed_data["health_recommendations"] = raw_data["healthRecommendations"]
            
            # Polluant dominant
            if "dominantPollutant" in raw_data:
                processed_data["dominant_pollutant"] = raw_data["dominantPollutant"]
            
            # Métadonnées de région
            if "regionCode" in raw_data:
                processed_data["region_code"] = raw_data["regionCode"]
            
            return processed_data
            
        except Exception as e:
            self.logger.error(f"Erreur lors du traitement des données Air Quality: {str(e)}")
            return {"error": str(e), "raw_data": raw_data}
