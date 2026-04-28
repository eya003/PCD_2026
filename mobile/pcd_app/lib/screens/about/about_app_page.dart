import 'package:flutter/material.dart';

import '../../data/about_app_content.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/section_card.dart';
import 'about_app_detail_page.dart';

class AboutAppPage extends StatelessWidget {
  const AboutAppPage({super.key});

  @override
  Widget build(BuildContext context) {
    final data = _AboutPageData.fromMap(aboutAppContent);

    return Scaffold(
      appBar: AppBar(title: Text(data.title)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 980),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _AboutHeaderCard(
                    title: data.title,
                    subtitle: data.subtitle,
                    introduction: data.introduction,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  SectionCard(
                    title: data.objectiveTitle,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          data.objectiveDescription,
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: AppColors.textSecondary,
                            height: 1.6,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        _AboutCardGrid(
                          cards: data.objectiveItems,
                          onOpenCard: (card) => _openCardDetail(
                            context: context,
                            sectionTitle: data.objectiveTitle,
                            card: card,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  SectionCard(
                    title: data.usersTitle,
                    child: _AboutCardGrid(
                      cards: data.userCards,
                      onOpenCard: (card) => _openCardDetail(
                        context: context,
                        sectionTitle: data.usersTitle,
                        card: card,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  SectionCard(
                    title: data.featuresTitle,
                    child: _AboutCardGrid(
                      cards: data.featureCards,
                      onOpenCard: (card) => _openCardDetail(
                        context: context,
                        sectionTitle: data.featuresTitle,
                        card: card,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  SectionCard(
                    title: data.benefitsTitle,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          data.benefitsDescription,
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: AppColors.textSecondary,
                            height: 1.6,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        ...data.benefitsItems.map(
                          (item) => Padding(
                            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Padding(
                                  padding: EdgeInsets.only(top: 6),
                                  child: Icon(
                                    Icons.check_circle_outline,
                                    size: 16,
                                    color: AppColors.primaryBlue,
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.xs),
                                Expanded(
                                  child: Text(
                                    item,
                                    style: Theme.of(context).textTheme.bodyMedium
                                        ?.copyWith(height: 1.5),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Card(
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: AppColors.statusOrange.withValues(alpha: 0.28),
                        ),
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            AppColors.statusOrange.withValues(alpha: 0.10),
                            AppColors.statusOrange.withValues(alpha: 0.03),
                          ],
                        ),
                      ),
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            data.importantMessageTitle,
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            data.importantMessageDescription,
                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: AppColors.textSecondary,
                              height: 1.6,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _openCardDetail({
    required BuildContext context,
    required String sectionTitle,
    required AboutAppCardData card,
  }) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => AboutAppDetailPage(
          sectionTitle: sectionTitle,
          card: card,
        ),
      ),
    );
  }
}

class _AboutHeaderCard extends StatelessWidget {
  const _AboutHeaderCard({
    required this.title,
    required this.subtitle,
    required this.introduction,
  });

  final String title;
  final String subtitle;
  final String introduction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.primaryBlue.withValues(alpha: 0.14),
              AppColors.primaryBlue.withValues(alpha: 0.03),
            ],
          ),
        ),
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              subtitle,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              introduction,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: AppColors.textSecondary,
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AboutCardGrid extends StatelessWidget {
  const _AboutCardGrid({
    required this.cards,
    required this.onOpenCard,
  });

  final List<AboutAppCardData> cards;
  final ValueChanged<AboutAppCardData> onOpenCard;

  @override
  Widget build(BuildContext context) {
    if (cards.isEmpty) {
      return Text(
        'Aucun element disponible.',
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = AppSpacing.sm;
        final maxWidth = constraints.maxWidth;
        final columns = maxWidth >= 900 ? 3 : maxWidth >= 620 ? 2 : 1;
        final itemWidth = (maxWidth - ((columns - 1) * spacing)) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: cards
              .map(
                (card) => SizedBox(
                  width: itemWidth,
                  child: _AboutInfoCard(
                    card: card,
                    onTap: () => onOpenCard(card),
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _AboutInfoCard extends StatelessWidget {
  const _AboutInfoCard({required this.card, required this.onTap});

  final AboutAppCardData card;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceAlt,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primaryBlue.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Text(
                  card.icon,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                card.title,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              if (card.hasDescription) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  card.description,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Voir plus',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: AppColors.primaryBlue,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AboutPageData {
  const _AboutPageData({
    required this.title,
    required this.subtitle,
    required this.introduction,
    required this.objectiveTitle,
    required this.objectiveDescription,
    required this.objectiveItems,
    required this.usersTitle,
    required this.userCards,
    required this.featuresTitle,
    required this.featureCards,
    required this.benefitsTitle,
    required this.benefitsDescription,
    required this.benefitsItems,
    required this.importantMessageTitle,
    required this.importantMessageDescription,
  });

  final String title;
  final String subtitle;
  final String introduction;
  final String objectiveTitle;
  final String objectiveDescription;
  final List<AboutAppCardData> objectiveItems;
  final String usersTitle;
  final List<AboutAppCardData> userCards;
  final String featuresTitle;
  final List<AboutAppCardData> featureCards;
  final String benefitsTitle;
  final String benefitsDescription;
  final List<String> benefitsItems;
  final String importantMessageTitle;
  final String importantMessageDescription;

  factory _AboutPageData.fromMap(Map<String, dynamic> source) {
    final objective = _asMap(source['objective']);
    final users = _asMap(source['users']);
    final features = _asMap(source['features']);
    final benefits = _asMap(source['benefits']);
    final importantMessage = _asMap(source['importantMessage']);

    return _AboutPageData(
      title: _asString(source['title']),
      subtitle: _asString(source['subtitle']),
      introduction: _asString(source['introduction']),
      objectiveTitle: _asString(objective['title']),
      objectiveDescription: _asString(objective['description']),
      objectiveItems: _asCards(objective['items']),
      usersTitle: _asString(users['title']),
      userCards: _asCards(users['cards']),
      featuresTitle: _asString(features['title']),
      featureCards: _asCards(features['cards']),
      benefitsTitle: _asString(benefits['title']),
      benefitsDescription: _asString(benefits['description']),
      benefitsItems: _asStringList(benefits['items']),
      importantMessageTitle: _asString(importantMessage['title']),
      importantMessageDescription: _asString(importantMessage['description']),
    );
  }

  static Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return value.map(
        (key, entry) => MapEntry(key.toString(), entry),
      );
    }
    return const <String, dynamic>{};
  }

  static String _asString(dynamic value) {
    return value is String ? value : '';
  }

  static List<String> _asStringList(dynamic value) {
    if (value is! List) return const <String>[];
    return value.map(_asString).where((item) => item.trim().isNotEmpty).toList();
  }

  static List<AboutAppCardData> _asCards(dynamic value) {
    if (value is! List) return const <AboutAppCardData>[];

    return value.map((entry) {
      final item = _asMap(entry);
      return AboutAppCardData(
        icon: _asString(item['icon']),
        title: _asString(item['title']),
        description: _asString(item['description']),
        details: _asString(item['details']),
      );
    }).toList();
  }
}
