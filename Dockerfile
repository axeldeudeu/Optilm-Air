# Dockerfile pour le déploiement sur Render
FROM python:3.11-slim

# Définir le répertoire de travail
WORKDIR /app

# Variables d'environnement
ENV PYTHONUNBUFFERED=1
ENV PYTHONDONTWRITEBYTECODE=1

# Installer les dépendances système
RUN apt-get update && apt-get install -y \
    gcc \
    g++ \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Copier les fichiers de requirements
COPY requirements.txt .

# Installer les dépendances Python
RUN pip install --no-cache-dir -r requirements.txt

# Copier le code source
COPY . .

# Créer les dossiers nécessaires
RUN mkdir -p data logs

# Définir les permissions
RUN chmod +x main.py health_check.py

# Exposer le port pour le health check
EXPOSE 8000

# Commande par défaut (health check server)
CMD ["python", "health_check.py"]