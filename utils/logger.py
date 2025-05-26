"""
Configuration du système de logging
"""

import logging
import os
import sys
from pathlib import Path


def setup_logger(name: str) -> logging.Logger:
    """
    Configure et retourne un logger personnalisé
    
    Args:
        name: Nom du logger
        
    Returns:
        Instance du logger configuré
    """
    logger = logging.getLogger(name)
    
    # Éviter la duplication si déjà configuré
    if logger.handlers:
        return logger
    
    # Niveau de log depuis les variables d'environnement
    log_level = os.getenv("LOG_LEVEL", "INFO").upper()
    logger.setLevel(getattr(logging, log_level, logging.INFO))
    
    # Format des messages
    formatter = logging.Formatter(
        '%(asctime)s - %(name)s - %(levelname)s - %(message)s',
        datefmt='%Y-%m-%d %H:%M:%S'
    )
    
    # Handler pour la console (stdout)
    console_handler = logging.StreamHandler(sys.stdout)
    console_handler.setLevel(logging.INFO)
    console_handler.setFormatter(formatter)
    logger.addHandler(console_handler)
    
    # Créer le dossier des logs si nécessaire
    try:
        log_dir = Path("logs")
        log_dir.mkdir(exist_ok=True)
    except:
        pass  # Ignorer si on ne peut pas créer le dossier
    
    return logger
