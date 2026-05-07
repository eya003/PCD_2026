class MriPredictionResult {
  const MriPredictionResult({
    required this.diagnosisId,
    required this.patientId,
    required this.questionnaireId,
    required this.predictedClass,
    required this.confidenceScore,
    required this.probAd,
    required this.cnnProbAd,
    required this.cnnPred061,
    required this.threshold,
    required this.message,
  });

  final int diagnosisId;
  final int patientId;
  final int? questionnaireId;
  final String predictedClass;
  final double confidenceScore;
  final double probAd;
  final double cnnProbAd;
  final double cnnPred061;
  final double threshold;
  final String message;

  factory MriPredictionResult.fromJson(Map<String, dynamic> json) {
    final diagnosisId = _parseInt(json['diagnosis_id']);
    final patientId = _parseInt(json['patient_id']);
    final confidenceScore = _parseDouble(json['confidence_score']);
    final probAd = _parseDouble(json['prob_ad']);
    final cnnProbAd = _parseDouble(json['cnn_prob_AD']);
    final cnnPred061 = _parseDouble(json['cnn_pred_061']);
    final threshold = _parseDouble(json['threshold']);

    if (diagnosisId == null ||
        patientId == null ||
        confidenceScore == null ||
        probAd == null ||
        cnnProbAd == null ||
        cnnPred061 == null ||
        threshold == null) {
      throw const MriPredictionResultParseException(
        'Format de reponse IA invalide.',
      );
    }

    return MriPredictionResult(
      diagnosisId: diagnosisId,
      patientId: patientId,
      questionnaireId: _parseInt(json['questionnaire_id']),
      predictedClass: json['predicted_class']?.toString() ?? '',
      confidenceScore: confidenceScore,
      probAd: probAd,
      cnnProbAd: cnnProbAd,
      cnnPred061: cnnPred061,
      threshold: threshold,
      message: json['message']?.toString() ?? '',
    );
  }
}

class MriPredictionResultParseException implements Exception {
  const MriPredictionResultParseException(this.message);

  final String message;

  @override
  String toString() => message;
}

int? _parseInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}

double? _parseDouble(dynamic value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}
