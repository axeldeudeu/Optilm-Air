"""
Collecteur de données météorologiques via OpenWeather API
"""

import aiohttp
import asyncio
from typing import Dict, Any, Optional
import logging
from datetime import datetime, timezone


class WeatherCollector:
    """Collecteur pour les données météorologiques OpenWeather"""
    
    def __init__(self, api_key: str):
        self.api_key = api_key
        self.base_url = "https://api.openweathermap.org/data/2.5"
        self.onecall_url = "https://api.openweathermap.org/data/3.0/onecall"
        self.logger = logging.getLogger(__name__)
    
    async def get_weather_data(self, latitude: float, longitude: float) -> Optional[Dict[str, Any]]:
        """
        Récupère les données météorologiques complètes
        
        Args:
            latitude: Latitude de la localisation
            longitude: Longitude de la localisation
            
        Returns:
            Dictionnaire contenant les données météo ou None en cas d'erreur
        """
        try:
            # Collecte de toutes les données météo en parallèle
            current_task = self._get_current_weather(latitude, longitude)
            forecast_task = self._get_forecast_weather(latitude, longitude)
            onecall_task = self._get_onecall_weather(latitude, longitude)
            
            current_data, forecast_data, onecall_data = await asyncio.gather(
                current_task, forecast_task, onecall_task,
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
            
            # OneCall (données complètes)
            if not isinstance(onecall_data, Exception) and onecall_data:
                weather_data["detailed"] = onecall_data
            else:
                self.logger.warning(f"Erreur OneCall: {onecall_data}")
            
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
            
            async with aiohttp.ClientSession() as session:
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
            
            async with aiohttp.ClientSession() as session:
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
    
    async def _get_onecall_weather(self, lat: float, lon: float) -> Optional[Dict[str, Any]]:
        """Récupère les données complètes OneCall"""
        try:
            url = self.onecall_url
            params = {
                "lat": lat,
                "lon": lon,
                "appid": self.api_key,
                "units": "metric",
                "lang": "fr",
                "exclude": "minutely"  # Exclut les données par minute pour économiser
            }
            
            async with aiohttp.ClientSession() as session:
                async with session.get(url, params=params) as response:
                    if response.status == 200:
                        data = await response.json()
                        return self._process_onecall_weather(data)
                    else:
                        self.logger.warning(f"OneCall non disponible: {response.status}")
                        return None
                        
        except Exception as e:
            self.logger.warning(f"OneCall non accessible: {str(e)}")
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
                "uv_index": data.get("uvi"),
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
    
    def _process_onecall_weather(self, data: Dict[str, Any]) -> Dict[str, Any]:
        """Traite les données OneCall complètes"""
        try:
            processed = {
                "timezone": data["timezone"],
                "timezone_offset": data["timezone_offset"]
            }
            
            # Données actuelles
            if "current" in data:
                current = data["current"]
                processed["current_detailed"] = {
                    "temperature": current["temp"],
                    "feels_like": current["feels_like"],
                    "pressure": current["pressure"],
                    "humidity": current["humidity"],
                    "dew_point": current["dew_point"],
                    "uvi": current["uvi"],
                    "clouds": current["clouds"],
                    "visibility": current.get("visibility"),
                    "wind_speed": current["wind_speed"],
                    "wind_deg": current.get("wind_deg"),
                    "weather": current["weather"][0] if current["weather"] else None
                }
            
            # Prévisions horaires (24h)
            if "hourly" in data:
                processed["hourly"] = data["hourly"][:24]
            
            # Prévisions quotidiennes (7 jours)
            if "daily" in data:
                processed["daily"] = data["daily"][:7]
            
            return processed
            
        except Exception as e:
            self.logger.error(f"Erreur traitement OneCall: {str(e)}")
            return {"error": str(e)}