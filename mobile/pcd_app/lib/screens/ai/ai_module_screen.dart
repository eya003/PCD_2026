import 'package:flutter/material.dart';

import '../../models/ai_result_item.dart';
import '../../services/ai_service.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/ai_result_card.dart';
import '../../widgets/app_header.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/section_card.dart';
import '../../widgets/secondary_button.dart';

class AiModuleScreen extends StatefulWidget {
  const AiModuleScreen({super.key});

  @override
  State<AiModuleScreen> createState() => _AiModuleScreenState();
}

class _AiModuleScreenState extends State<AiModuleScreen> {
  final AiService _service = const AiService();
  bool _isLoading = true;
  List<AiResultItem> _results = const [];

  @override
  void initState() {
    super.initState();
    _loadResults();
  }

  Future<void> _loadResults() async {
    setState(() => _isLoading = true);
    final data = await _service.fetchResults();
    if (!mounted) return;
    setState(() {
      _results = data;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _loadResults,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          AppHeader(
            title: 'Module IA',
            subtitle: 'Resultats recents, score et recommandations.',
            actions: [
              PrimaryButton(
                label: 'Lancer analyse',
                icon: Icons.play_arrow_outlined,
                fullWidth: false,
                onPressed: () {},
              ),
              SecondaryButton(
                label: 'Historique',
                icon: Icons.history_outlined,
                fullWidth: false,
                onPressed: () {},
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.only(top: AppSpacing.xl),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_results.isEmpty)
            const EmptyState(
              icon: Icons.psychology_alt_outlined,
              title: 'Aucun resultat',
              message: 'Aucun resultat IA disponible pour le moment.',
            )
          else
            SectionCard(
              title: 'Derniers resultats',
              child: Column(
                children: _results
                    .map(
                      (result) => Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: AiResultCard(result: result),
                      ),
                    )
                    .toList(),
              ),
            ),
        ],
      ),
    );
  }
}
