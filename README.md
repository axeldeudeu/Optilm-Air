# 🌤️ Weather Data Collector

Système automatisé de collecte de données météorologiques et de qualité de l'air, déployé sur Render avec exécution horaire via cron-job.

## 📋 Fonctionnalités

- ✅ Collecte de données de qualité de l'air (Google Cloud Platform Air Quality API)
- ✅ Collecte de données météorologiques (OpenWeather API)
- ✅ Exécution automatique toutes les heures via cron-job
- ✅ Stockage local en JSON + options base de données/webhook
- ✅ Health check endpoint pour monitoring
- ✅ Logging complet et gestion d'erreurs
- ✅ Déploiement facile sur Render

## 🏗️ Architecture

```
weather-data-collector/
├── main.py                     # Script principal
├── health_check.py             # Health check pour Render
├── test_apis.py               # Script de test des APIs
├── requirements.txt            # Dépendances Python
├── Dockerfile                 # Configuration Docker
├── .env.template              # Template des variables d'environnement
├── README.md                  # Cette documentation
├── data_collectors/           # Modules de collecte
│   ├── __init__.py
│   ├── air_quality_collector.py
│   └── weather_collector.py
├── storage/                   # Système de stockage
│   ├── __init__.py
│   └── data_storage.py
├── utils/                     # Utilitaires
│   ├── __init__.py
│   ├── config.py
│   └── logger.py
├── data/                      # Données collectées (créé automatiquement)
└── logs/                      # Fichiers de log (créé automatiquement)
```

## 🚀 Installation et Configuration

### 1. Préparation du Repository GitHub

```bash
# Créer un nouveau repository sur GitHub nommé weather-data-collector
# Cloner localement
git clone https://github.com/votre-username/weather-data-collector.git
cd weather-data-collector

# Copier tous les fichiers fournis dans votre repository
# Créer la structure des dossiers
mkdir -p data_collectors storage utils
```

### 2. Configuration des APIs

#### Google Cloud Platform Air Quality API

1. Aller sur [Google Cloud Console](https://console.cloud.google.com/)
2. Créer un nouveau projet ou sélectionner un existant
3. Activer l'API "Air Quality API" :
   - Dans le menu "APIs & Services" > "Library"
   - Rechercher "Air Quality API"
   - Cliquer "Enable"
4. Créer une clé API :
   - Aller dans "APIs & Services" > "Credentials"
   - Cliquer "Create Credentials" > "API Key"
   - Copier la clé générée
   - **IMPORTANT :** Noter aussi l'ID de votre projet GCP

#### OpenWeather API

1. Aller sur [OpenWeatherMap](https://openweathermap.org/api)
2. Créer un compte gratuit
3. Aller dans votre profil > "My API Keys"
4. Copier votre clé API
5. **ATTENTION :** La clé peut prendre jusqu'à 2 heures pour être active

### 3. Configuration sur Render

#### Étape 1: Créer le Web Service

1. Aller sur [Render.com](https://render.com)
2. Connecter votre compte GitHub
3. Cliquer **"New"** > **"Web Service"**
4. Sélectionner votre repository `weather-data-collector`

#### Étape 2: Configuration du Web Service

**Settings principaux :**
- **Name :** `weather-data-collector`
- **Environment :** `Docker`
- **Branch :** `main`
- **Dockerfile Path :** **LAISSER VIDE** (ou mettre `Dockerfile`)
- **Health Check Path :** `/health`

**Variables d'environnement :**
Ajouter ces variables dans l'interface Render :

```
GCP_AIR_QUALITY_API_KEY = votre_cle_gcp_ici
GCP_PROJECT_ID = votre_projet_gcp_id
OPENWEATHER_API_KEY = votre_cle_openweather_ici
DEFAULT_LATITUDE = 48.8566
DEFAULT_LONGITUDE = 2.3522
LOG_LEVEL = INFO
PORT = 8000
```

#### Étape 3: Créer le Cron Job

1. Dans Render, cliquer **"New"** > **"Cron Job"**
2. **Settings :**
   - **Name :** `weather-collector-hourly`
   - **Environment :** `Docker`
   - **Repository :** Sélectionner le même repository
   - **Branch :** `main`
   - **Dockerfile Path :** **LAISSER VIDE** (ou mettre `Dockerfile`)
   - **Schedule :** `0 * * * *` (toutes les heures)
   - **Command :** `python main.py`

3. **Variables d'environnement :** Ajouter **exactement les mêmes** que le Web Service

## ⚙️ Dockerfile Path - Configuration Importante

**POUR LE WEB SERVICE ET LE CRON JOB :**

- **Dockerfile Path :** **LAISSER COMPLÈTEMENT VIDE**
- Ou, si Render l'exige, mettre simplement : `Dockerfile`

**❌ NE PAS mettre :**
- `./Dockerfile`
- `/Dockerfile` 
- Un chemin complexe

**✅ Configuration correcte :**
- Champ vide = Render cherche automatiquement `Dockerfile` à la racine
- Si le champ exige une valeur : `Dockerfile`

## 🧪 Tests Locaux (Optionnel)

### Installation locale

```bash
# Installer les dépendances
pip install -r requirements.txt

# Configurer les variables d'environnement
cp .env.template .env
# Éditer .env avec vos vraies clés API

# Tester la configuration et les APIs
python test_apis.py

# Tester une collecte complète
python main.py

# Tester le health check
python health_check.py
# Aller sur http://localhost:8000/health
```

## 📊 Monitoring et Vérification

### Health Check Endpoints

Une fois déployé sur Render, votre service sera accessible via :

- **Health Check :** `https://votre-app.onrender.com/health`
- **Status Simple :** `https://votre-app.onrender.com/status`  
- **Dernières Données :** `https://votre-app.onrender.com/latest`
- **Métriques :** `https://votre-app.onrender.com/metrics`

### Vérification du Déploiement

1. **Web Service :** Doit être "Live" et répondre sur `/health`
2. **Cron Job :** Doit s'exécuter sans erreur toutes les heures
3. **Logs :** Vérifier les logs dans l'interface Render

### Structure des Données

Les données sont sauvegardées avec cette structure :

```json
{
  "timestamp": "2025-05-26T14:00:00Z",
  "location": {
    "latitude": 48.8566,
    "longitude": 2.3522
  },
  "air_quality": {
    "indexes": [...],
    "pollutants": [...],
    "health_recommendations": {...}
  },
  "weather": {
    "current": {...},
    "forecast": {...}
  },
  "collection_status": {
    "air_quality_success": true,
    "weather_success": true
  }
}
```

## 🛠️ Personnalisation

### Changer la Localisation

Modifier dans les variables d'environnement Render :
```
DEFAULT_LATITUDE = votre_latitude
DEFAULT_LONGITUDE = votre_longitude
```

### Ajouter une Base de Données PostgreSQL

```
DATABASE_URL = postgresql://user:pass@host:5432/db
```

### Ajouter des Webhooks

```
WEBHOOK_URL = https://votre-api.com/webhook
WEBHOOK_SECRET = votre_secret
```

### Modifier la Fréquence du Cron Job

Dans les settings du cron job Render :
- `0 * * * *` : Toutes les heures
- `*/30 * * * *` : Toutes les 30 minutes  
- `0 */6 * * *` : Toutes les 6 heures
- `0 9 * * *` : Tous les jours à 9h

## 🚨 Troubleshooting

### Erreurs de Déploiement

**"Failed to build Docker image"**
- Vérifier que `Dockerfile` est à la racine du repository
- S'assurer que le champ "Dockerfile Path" est vide ou contient `Dockerfile`

**"Environment variables not found"**
- Vérifier que toutes les variables sont configurées dans Render
- Variables requises : `GCP_AIR_QUALITY_API_KEY`, `GCP_PROJECT_ID`, `OPENWEATHER_API_KEY`

### Erreurs d'APIs

**"GCP_AIR_QUALITY_API_KEY non définie"**
- Vérifier la variable dans les settings Render
- S'assurer que l'API Air Quality est activée dans GCP

**"Erreur API Air Quality: 403"**
- Vérifier les permissions de la clé API GCP
- S'assurer que l'API Air Quality est bien activée

**"Erreur OpenWeather API"**
- Vérifier que la clé OpenWeather est active (peut prendre 2h)
- Vérifier le quota de votre plan gratuit

### Problèmes de Cron Job

**Le cron job ne s'exécute pas**
- Vérifier qu'il est "Enabled" dans Render
- Vérifier la syntaxe du schedule cron
- Regarder les logs du cron job dans Render

**Timeout ou erreurs de mémoire**
- Les plans gratuits Render ont des limites
- Considérer un upgrade si nécessaire

### Debug

Pour plus de logs détaillés :
```
LOG_LEVEL = DEBUG
```

## 📈 Fonctionnement Automatique

Une fois configuré correctement :

1. ⏰ **Toutes les heures :** Le cron job s'exécute automatiquement
2. 🌐 **Collecte :** Récupère les données des APIs GCP et OpenWeather
3. 💾 **Sauvegarde :** Stocke les données en JSON local
4. 📊 **Monitoring :** Le web service reste actif pour les health checks
5. 🔄 **Répétition :** Le cycle recommence automatiquement

## ✅ Liste de Vérification Finale

Avant de déployer, vérifier :

- [ ] Tous les fichiers sont dans le repository GitHub
- [ ] Les APIs GCP Air Quality et OpenWeather sont activées
- [ ] Les clés API sont valides et actives
- [ ] Le test local `python test_apis.py` passe
- [ ] Les variables d'environnement sont configurées sur Render
- [ ] Le Dockerfile Path est vide ou contient `Dockerfile`
- [ ] Le web service et le cron job sont créés sur Render

## 📄 Licence

MIT License - Voir le fichier LICENSE pour les détails.

---

**🎉 Votre système de collecte météo automatique est maintenant prêt ! Il collectera les données toutes les heures sans intervention.**