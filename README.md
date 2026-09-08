# PCD 2026 — Système intelligent d’aide au diagnostic et à la surveillance de la maladie d’Alzheimer

Projet académique réalisé dans le cadre du **Projet de Conception et de Développement (PCD)** à l’École Nationale des Sciences de l’Informatique (**ENSI**).

Le projet combine **Intelligence Artificielle, imagerie médicale, Machine Learning, Deep Learning et développement logiciel** afin de proposer un système d’aide au diagnostic et au suivi de la maladie d’Alzheimer.

> ⚠️ Le module IA constitue un outil expérimental d’aide à la décision et ne remplace en aucun cas un diagnostic réalisé par un professionnel de santé.

---

## Description du projet

Le système est composé de trois principales parties :

- une **application web** destinée aux médecins ;
- une **application mobile** destinée à la famille et aux accompagnants ;
- un **backend FastAPI** intégrant les services applicatifs et le pipeline d’Intelligence Artificielle.

Le module IA analyse des **IRM cérébrales** afin de réaliser une classification binaire :

- **AD** — Alzheimer's Disease
- **CN** — Cognitively Normal

---

## Ma contribution

Ma contribution principale au projet s’est concentrée sur la **conception, l’expérimentation et l’évaluation du pipeline d’Intelligence Artificielle**.

J’ai notamment travaillé sur :

- le prétraitement des IRM cérébrales ;
- la segmentation automatique de l’hippocampe avec **HippoDeep** ;
- l’extraction et le traitement de régions d’intérêt hippocampiques 3D ;
- l’expérimentation avec plusieurs architectures **MedicalNet 3D ResNet** ;
- la comparaison de **ResNet10, ResNet18, ResNet34 et ResNet50** ;
- l’extraction de caractéristiques anatomiques et statistiques à partir des IRM ;
- l’exploitation de la probabilité produite par le CNN comme caractéristique supplémentaire ;
- le benchmark de plusieurs modèles de Machine Learning avec **LazyClassifier** ;
- la sélection et l’évaluation du modèle hybride final basé sur **BernoulliNB** ;
- l’analyse des métriques de classification et des performances du modèle ;
- la contribution à l’intégration du module IA dans l’application.

Le projet a été développé **en équipe** dans le cadre du PCD à l’ENSI.

---

# Pipeline IA

Le pipeline final combine **Deep Learning 3D** et **Machine Learning classique**.

```text
IRM cérébrale
      ↓
HippoDeep
Segmentation hippocampique
      ↓
Extraction des ROI 3D
      ↓
MedicalNet ResNet34
      ↓
Probabilité CNN
      +
Caractéristiques anatomiques
et statistiques
      ↓
Benchmark Machine Learning
avec LazyClassifier
      ↓
Sélection de BernoulliNB
      ↓
Modèle hybride final
      ↓
Prédiction AD / CN
```

---

## 1. Segmentation hippocampique

La première étape du pipeline consiste à localiser automatiquement les hippocampes à partir des IRM cérébrales.

**HippoDeep** est utilisé pour segmenter :

- l’hippocampe gauche ;
- l’hippocampe droit.

Les masques obtenus permettent ensuite d’extraire des **régions d’intérêt 3D (ROI)** centrées sur les structures hippocampiques.

Ces régions sont ensuite utilisées comme entrées du modèle de Deep Learning.

---

## 2. Deep Learning 3D

Plusieurs architectures de réseaux de neurones 3D basées sur **MedicalNet** ont été expérimentées :

- ResNet10
- ResNet18
- ResNet34
- ResNet50

Les différentes architectures ont été comparées afin d’identifier celle offrant le meilleur compromis pour le pipeline développé.

**ResNet34** a été retenu pour la version finale.

Le CNN analyse les ROI hippocampiques 3D et produit notamment une **probabilité associée à la classe Alzheimer (AD)**.

---

## 3. Feature Engineering

En complément de la prédiction du CNN, plusieurs caractéristiques anatomiques et statistiques sont extraites à partir des IRM et des résultats de segmentation.

Parmi les caractéristiques utilisées :

- volume de l’hippocampe gauche ;
- volume de l’hippocampe droit ;
- volume hippocampique total ;
- ratios entre le volume hippocampique et le volume cérébral ;
- mesures d’asymétrie entre les hippocampes ;
- caractéristiques statistiques calculées sur les ROI ;
- probabilité `AD` produite par le CNN.

Cette étape permet de combiner les informations apprises automatiquement par le réseau de neurones avec des informations anatomiques structurées.

---

## 4. Benchmark Machine Learning

Après l’extraction des caractéristiques, plusieurs modèles de Machine Learning ont été comparés.

**LazyClassifier / LazyPredict** a été utilisé comme outil de benchmark afin d’explorer rapidement plusieurs familles de classifieurs.

Des expérimentations complémentaires ont également été réalisées avec différents algorithmes classiques de Machine Learning.

Cette étape a permis de comparer les performances des modèles avant de sélectionner le classifieur utilisé dans le pipeline hybride final.

---

## 5. Modèle hybride final

À l’issue du benchmark, **BernoulliNB** a été retenu pour le modèle hybride final.

Le pipeline de Machine Learning utilise notamment :

- `StandardScaler`
- `Binarizer`
- `SelectKBest`
- `BernoulliNB`

Le modèle reçoit à la fois :

- les caractéristiques anatomiques et statistiques extraites des IRM ;
- la probabilité produite par le CNN ResNet34.

Le seuil de décision est sélectionné sur l’ensemble de **validation**.

L’ensemble de **test** est ensuite utilisé uniquement pour l’évaluation finale.

---

# Résultats du modèle final

Le run final consolidé du pipeline hybride a obtenu les performances suivantes :

| Métrique | Résultat |
|---|---:|
| Accuracy | **87.80 %** |
| ROC-AUC | **0.9762** |
| Precision — AD | **82.61 %** |
| Recall — AD | **95.00 %** |
| F1-score — AD | **88.37 %** |
| Specificity — CN | **80.95 %** |

### Matrice de confusion

```text
                Prédit CN     Prédit AD
Réel CN             17            4
Réel AD              1           19
```

Le modèle identifie correctement **19 patients AD sur 20** dans l’ensemble de test final.

---

# Notebook IA

Une version nettoyée du notebook contenant les principales étapes d’expérimentation ainsi que le pipeline final est disponible ici :

➡️ [`notebooks/PCD_Alzheimer_Final_Clean.ipynb`](notebooks/PCD_Alzheimer_Final_Clean.ipynb)

Le notebook contient notamment :

- le prétraitement des IRM ;
- la segmentation avec HippoDeep ;
- l’extraction des ROI 3D ;
- l’utilisation de MedicalNet / ResNet34 ;
- l’extraction des caractéristiques ;
- le benchmark avec LazyClassifier ;
- la sélection de BernoulliNB ;
- la construction du modèle hybride ;
- l’évaluation finale du pipeline.

---

# Architecture de l’application

```text
                     ┌─────────────────────┐
                     │   Application Web   │
                     │       React         │
                     │      Médecins       │
                     └──────────┬──────────┘
                                │
                                │ REST API
                                │
                     ┌──────────▼──────────┐
                     │      FastAPI        │
                     │      Backend        │
                     └──────────┬──────────┘
                                │
             ┌──────────────────┼──────────────────┐
             │                  │                  │
             ▼                  ▼                  ▼

        PostgreSQL         Pipeline IA       Application
                           MRI → AD/CN         Mobile
                                               Flutter
```

---

# Technologies utilisées

## Intelligence Artificielle

- Python
- PyTorch
- MedicalNet
- ResNet34
- CNN 3D
- HippoDeep
- Scikit-learn
- LazyPredict
- LazyClassifier
- BernoulliNB
- Feature Engineering
- NumPy
- Pandas

## Backend

- FastAPI
- PostgreSQL
- SQLAlchemy
- Docker

## Application web

- React
- TypeScript
- Axios

## Application mobile

- Flutter
- Dart

---

# Structure du projet

```text
PCD_2026/
│
├── backend/
│   └── Backend FastAPI et module IA
│
├── mobile/
│   └── pcd_app/
│       └── Application mobile Flutter
│
├── web/
│   └── Application web React
│
├── notebooks/
│   └── PCD_Alzheimer_Final_Clean.ipynb
│
├── docker-compose.yml
├── .gitignore
└── README.md
```

---

# Modèles IA

Le fichier du modèle CNN 3D n’est pas inclus directement dans le dépôt GitHub en raison de sa taille.

Il doit être placé localement dans :

```text
backend/app/ml_models/final_hybrid_model/cnn/
```

Les autres artefacts nécessaires au pipeline sont chargés par le backend lors de l’inférence.

---

# Confidentialité et sécurité

Pour des raisons de confidentialité, de sécurité et de taille du dépôt, les éléments suivants ne sont pas publiés :

- données médicales ;
- IRM de patients ;
- informations personnelles ;
- fichiers `.env` ;
- secrets et credentials ;
- modèles volumineux ;
- fichiers temporaires générés pendant l’exécution.

---

# Contexte académique

**École Nationale des Sciences de l’Informatique — ENSI**  
Cycle ingénieur en informatique  
Projet de Conception et de Développement — **PCD 2026**

**Sujet :**  
Système intelligent d’aide au diagnostic et à la surveillance de la maladie d’Alzheimer
