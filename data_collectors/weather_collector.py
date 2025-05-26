"""
Collecteur de données météorologiques via OpenWeather API - Version simplifiée
"""

import aiohttp
import asyncio
import logging
from typing import Dict, Any, Optional
from datetime import datetime, timezone


class WeatherCollector:
    """Collecteur pour les données météorologiques OpenWeather"""
    
    def __init__(self, api_key: str):
        self.api_key = api_key
        self.base_url = "https://api.openweathermap.org/data/2.5"
        self.logger = logging.getLogger(__name__)
    
    async def get_weather_data(self, latitude: float, longitude: float) -> Optional[Dict[str, Any]]:
        """
        Récupère les données météorologiques complètes
        """
        try:
            # Collecte de toutes les données météo en parallèle
            current_task = self._get_current_weather(latitude, longitude)
            forecast_task = self._get_forecast_weather(latitude, longitude)
            
            current_data, forecast_data = await asyncio.gather(
                current_task, forecast_task,
                return_exceptions=True
            )
            
            # Compilation des données
            weather_data = {
                "collected_at": datetime.now(timezone.utc).isoformat(),
                "data_source": "openweather_api",
                "location": {"latitude": latitude, "longitude": longitude}
            }
            
            # Données actuelles
            if not isinstance(current_data, Exception) and current_data:
                weather_data["current"] = current_data
            else:
                self.logger.warning(f"Erreur données actuelles: {current_data}")
            
            # Prévisions
            if not isinstance(forecast_data, Exception) and forecast_data:
                weather_data["forecast"] = forecast_data
            else:
                self.logger.warning(f"Erreur prévisions: {forecast_data}")
            
            return weather_data
            
        except Exception as e:
            self.logger.error(f"Erreur lors de la collecte météo: {str(e)}")
            return None
    
    async def _get_current_weather(self, lat: float, lon: float) -> Optional[Dict[str, Any]]:
        """Récupère les données météo actuelles"""
        try:
            url = f"{self.base_url}/weather"
            params = {
                "lat": lat,
                "lon": lon,
                "appid": self.api_key,
                "units": "metric",
                "lang": "fr"
            }
            
            timeout = aiohttp.ClientTimeout(total=30)
            async with aiohttp.ClientSession(timeout=timeout) as session:
                async with session.get(url, params=params) as response:
                    if response.status == 200:
                        data = await response.json()
                        return self._process_current_weather(data)
                    else:
                        self.logger.error(f"Erreur API current weather: {response.status}")
                        return None
                        
        except Exception as e:
            self.logger.error(f"Erreur current weather: {str(e)}")
            return None
    
    async def _get_forecast_weather(self, lat: float, lon: float) -> Optional[Dict[str, Any]]:
        """Récupère les prévisions météo 5 jours"""
        try:
            url = f"{self.base_url}/forecast"
            params = {
                "lat": lat,
                "lon": lon,
                "appid": self.api_key,
                "units": "metric",
                "lang": "fr"
            }
            
            timeout = aiohttp.ClientTimeout(total=30)
            async with aiohttp.ClientSession(timeout=timeout) as session:
                async with session.get(url, params=params) as response:
                    if response.status == 200:
                        data = await response.json()
                        return self._process_forecast_weather(data)
                    else:
                        self.logger.error(f"Erreur API forecast: {response.status}")
                        return None
                        
        except Exception as e:
            self.logger.error(f"Erreur forecast: {str(e)}")
            return None
    
    def _process_current_weather(self, data: Dict[str, Any]) -> Dict[str, Any]:
        """Traite les données météo actuelles"""
        try:
            return {
                "temperature": data["main"]["temp"],
                "feels_like": data["main"]["feels_like"],
                "humidity": data["main"]["humidity"],
                "pressure": data["main"]["pressure"],
                "visibility": data.get("visibility"),
                "weather": {
                    "main": data["weather"][0]["main"],
                    "description": data["weather"][0]["description"],
                    "icon": data["weather"][0]["icon"]
                },
                "wind": {
                    "speed": data["wind"]["speed"],
                    "direction": data["wind"].get("deg"),
                    "gust": data["wind"].get("gust")
                },
                "clouds": data["clouds"]["all"],
                "location": {
                    "name": data["name"],
                    "country": data["sys"]["country"],
                    "timezone": data["timezone"]
                },
                "sunrise": data["sys"]["sunrise"],
                "sunset": data["sys"]["sunset"],
                "timestamp": data["dt"]
            }
        except Exception as e:
            self.logger.error(f"Erreur traitement current weather: {str(e)}")
            return {"error": str(e), "raw_data": data}
    
    def _process_forecast_weather(self, data: Dict[str, Any]) -> Dict[str, Any]:
        """Traite les prévisions météo"""
        try:
            forecasts = []
            for item in data["list"][:8]:  # Prendre les 8 prochaines périodes (24h)
                forecast = {
                    "datetime": item["dt"],
                    "temperature": item["main"]["temp"],
                    "feels_like": item["main"]["feels_like"],
                    "humidity": item["main"]["humidity"],
                    "pressure": item["main"]["pressure"],
                    "weather": {
                        "main": item["weather"][0]["main"],
                        "description": item["weather"][0]["description"],
                        "icon": item["weather"][0]["icon"]
                    },
                    "wind_speed": item["wind"]["speed"],
                    "clouds": item["clouds"]["all"],
                    "precipitation_probability": item.get("pop", 0) * 100
                }
                forecasts.append(forecast)
            
            return {
                "city": {
                    "name": data["city"]["name"],
                    "country": data["city"]["country"],
                    "coordinates": data["city"]["coord"]
                },
                "forecasts": forecasts
            }
        except Exception as e:
            self.logger.error(f"Erreur traitement forecast: {str(e)}")
            return {"error": str(e)}
