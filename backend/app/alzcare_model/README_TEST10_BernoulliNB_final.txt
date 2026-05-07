TEST10 - BernoulliNB + features hippocampe + probabilité CNN
============================================================

Objectif :
Valider proprement le meilleur candidat LazyClassifier avec un split train/val/test.

Pipeline utilisé :
1. Segmentation hippocampe avec HippoDeep.
2. Extraction ROI hippocampe.
3. CNN MedicalNet ResNet34 avec data augmentation ultra-légère.
4. Extraction de la probabilité AD du CNN.
5. Extraction de features : volumes hippocampe, volume cerveau, ratios normalisés, asymétrie, statistiques ROI.
6. Classification finale avec BernoulliNB.
7. Choix du seuil sur validation.
8. Évaluation finale sur test.

Résultats test final :
model_name=BernoulliNB_features_cnn_clean
threshold=0.1
accuracy=0.8780487804878049
auc=0.9761904761904762
precision_AD=0.8260869565217391
recall_AD=0.95
f1_AD=0.8837209302325582
specificity_CN=0.809523809138322
tn=17
fp=4
fn=1
tp=19
n_features_selected=12

Features sélectionnées :
- roi_p01
- roi_p05
- roi_p25
- roi_kurtosis
- hippo_L_mm3
- hippo_R_mm3
- hippo_total_mm3
- hippo_L_over_brain
- hippo_R_over_brain
- hippo_total_over_brain
- cnn_prob_AD
- cnn_pred_061

Remarque :
Ce résultat doit être comparé au CNN seul et au GaussianNB du TEST9.
