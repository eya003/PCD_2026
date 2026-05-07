from app.ia.prediction_service import predict_from_features


features = {
    "roi_mean": 0.1,
    "roi_std": 0.2,
    "roi_median": 0.1,
    "roi_min": -1.0,
    "roi_max": 1.0,
    "roi_p01": -0.8,
    "roi_p05": -0.6,
    "roi_p10": -0.4,
    "roi_p25": -0.2,
    "roi_p75": 0.2,
    "roi_p90": 0.4,
    "roi_p95": 0.6,
    "roi_p99": 0.8,
    "roi_iqr": 0.4,
    "roi_range": 2.0,
    "roi_energy": 100.0,
    "roi_skew": 0.0,
    "roi_kurtosis": 3.0,
    "hippo_L_mm3": 3000.0,
    "hippo_R_mm3": 3100.0,
    "hippo_total_mm3": 6100.0,
    "brain_volume_mm3": 1200000.0,
    "hippo_L_over_brain": 0.0025,
    "hippo_R_over_brain": 0.00258,
    "hippo_total_over_brain": 0.00508,
    "hippo_asymmetry_abs": 100.0,
    "hippo_L_minus_R_over_total": -0.016,
    "hippo_L_over_R": 0.9677,
    "hippo_R_over_L": 1.0333,
    "cnn_prob_AD": 0.7,
    "cnn_pred_061": 1.0,
}

result = predict_from_features(features)

print(result)