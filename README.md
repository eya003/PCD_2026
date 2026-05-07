# PCD 2026 — Système intelligent d’aide au diagnostic et à la surveillance de la maladie d’Alzheimer

## Description du projet

Ce projet est réalisé dans le cadre du Projet de Conception et de Développement à l’ENSI.

Il consiste à développer un système intelligent destiné au suivi des patients atteints ou suspectés de la maladie d’Alzheimer.

Le système est composé de trois parties principales :

- une application web destinée aux médecins ;
- une application mobile destinée à la famille et aux accompagnants ;
- un backend centralisé avec un module d’intelligence artificielle d’aide au diagnostic.

Le module IA analyse des IRM cérébrales afin de fournir une prédiction complémentaire de type AD/CN.  
Il ne remplace pas le médecin. Il sert uniquement comme outil d’aide à la décision.

---

## Technologies utilisées

### Backend

- Python
- FastAPI
- PostgreSQL
- SQLAlchemy
- Docker

### Application web

- React
- TypeScript
- Axios

### Application mobile

- Flutter
- Dart

### Intelligence artificielle

- PyTorch
- CNN 3D
- HippoDeep
- BernoulliNB
- Extraction de caractéristiques anatomiques et statistiques

---

## Structure du projet

```text
backend/        Backend FastAPI et module IA
web/            Application web pour le médecin
mobile/         Application mobile pour la famille
## Remarque sur le modèle IA
Le fichier du modèle CNN n’est pas inclus dans le dépôt GitHub à cause de sa taille.
Il doit être placé localement dans :
backend/app/ml_models/final_hybrid_model/cnn/

## Sécurité
Les fichiers `.env`, les données médicales, les fichiers IRM et les fichiers générés ne sont pas inclus dans le dépôt.