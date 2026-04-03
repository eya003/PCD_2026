import '../models/ai_result_item.dart';

class AiService {
  const AiService();

  Future<List<AiResultItem>> fetchResults() async {
    await Future<void>.delayed(const Duration(milliseconds: 220));
    return const [
      AiResultItem(
        id: 1,
        patientName: 'Ahmed Ben Salah',
        modelName: 'CN',
        score: 77,
        dateLabel: '18 fev. 2026',
        summary: 'Stabilite cognitive conservee. Revoir dans 30 jours.',
      ),
      AiResultItem(
        id: 2,
        patientName: 'Sara Trabelsi',
        modelName: 'CN',
        score: 64,
        dateLabel: '17 fev. 2026',
        summary: 'Changement modere. Controle rapproche recommande.',
      ),
    ];
  }
}
