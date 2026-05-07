MODÈLE FINAL - CLASSIFICATION ALZHEIMER AD vs CN
================================================

Nom du modèle :
FINAL_BernoulliNB_HippoDeep_ROI_ResNet34_UltraLightAug_FeaturesBrainNorm

Pipeline final :
1. Données : IRM cérébrales 1.5T, classes AD et CN.
2. Segmentation : segmentation automatique de l'hippocampe avec HippoDeep.
3. ROI : extraction d'une région d'intérêt hippocampique 3D.
4. CNN : MedicalNet ResNet34 pré-entraîné.
5. Data augmentation : ultra-légère pendant l'entraînement CNN.
   - faible variation d'intensité
   - bruit gaussien très faible
   - pas de flip gauche/droite
   - pas de rotation forte
   - pas de roll 3D
6. Extraction de la probabilité AD du CNN.
7. Extraction des features explicites :
   - volume hippocampe gauche
   - volume hippocampe droit
   - volume hippocampe total
   - volume cerveau total
   - ratios hippocampe / volume cerveau
   - asymétrie gauche-droite
   - statistiques du ROI : mean, std, percentiles, skewness, kurtosis, energy
8. Classification finale : BernoulliNB.
9. Choix du seuil : seuil choisi sur validation.
10. Évaluation finale : test set séparé.

Résultats finaux TEST10 :
Accuracy       = 0.878049
AUC            = 0.976190
Precision AD   = 0.826087
Recall AD      = 0.950000
F1-score AD    = 0.883721
Specificity CN = 0.809524
TN = 17
FP = 4
FN = 1
TP = 19

Interprétation :
Le modèle final détecte correctement 19 patients AD sur 20, avec seulement 1 faux négatif.
Il classe correctement 17 patients CN sur 21, avec 4 faux positifs.
Le résultat final validé proprement est une accuracy de 87.8% avec une AUC de 97.6%.

Fichiers inclus :
- bernoulliNB_features_cnn_model.joblib : modèle ML final
- final_test_metrics.csv : métriques finales
- test_predictions.csv : prédictions patient par patient
- selected_features.csv : features sélectionnées
- threshold_search_validation.csv : recherche du seuil sur validation
- best_threshold.txt : seuil final choisi
- feature_columns.txt : liste complète des features
- roc_curve_test.png : courbe ROC test
- confusion_matrix_test.png : matrice de confusion test
- threshold_metrics_validation.png : métriques selon le seuil
- final_metrics_barplot.png : graphe des métriques finales
