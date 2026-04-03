class AiResultItem {
  const AiResultItem({
    required this.id,
    required this.patientName,
    required this.modelName,
    required this.score,
    required this.dateLabel,
    required this.summary,
  });

  final int id;
  final String patientName;
  final String modelName;
  final int score;
  final String dateLabel;
  final String summary;
}
