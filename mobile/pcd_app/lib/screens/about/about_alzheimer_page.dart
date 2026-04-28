import 'package:flutter/material.dart';

import '../../data/about_alzheimer_content.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/section_card.dart';

class AboutAlzheimerPage extends StatefulWidget {
  const AboutAlzheimerPage({super.key});

  @override
  State<AboutAlzheimerPage> createState() => _AboutAlzheimerPageState();
}

class _AboutAlzheimerPageState extends State<AboutAlzheimerPage> {
  static const String _allCategoriesId = 'all';

  late final AboutAlzheimerPageData _data = AboutAlzheimerPageData.fromMap(
    aboutAlzheimerContent,
  );
  late final TextEditingController _searchController;

  String _searchTerm = '';
  String _selectedCategoryId = _allCategoriesId;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  List<AboutAlzheimerArticleData> get _recommendedArticles {
    final articlesById = {
      for (final article in _data.articles) article.id: article,
    };

    return _data.recommendedArticleIds
        .map((articleId) => articlesById[articleId])
        .whereType<AboutAlzheimerArticleData>()
        .toList();
  }

  List<AboutAlzheimerArticleData> get _filteredArticles {
    return _data.articles.where((article) {
      final category = _categoryForArticle(article);
      final matchesCategory =
          _selectedCategoryId == _allCategoriesId ||
          article.categoryId == _selectedCategoryId;

      return matchesCategory && _matchesSearch(article, category);
    }).toList();
  }

  AboutAlzheimerCategoryData? _categoryForArticle(
    AboutAlzheimerArticleData article,
  ) {
    for (final category in _data.categories) {
      if (category.id == article.categoryId) {
        return category;
      }
    }
    return null;
  }

  bool _matchesSearch(
    AboutAlzheimerArticleData article,
    AboutAlzheimerCategoryData? category,
  ) {
    final query = _normalizeSearchText(_searchTerm.trim());
    if (query.isEmpty) {
      return true;
    }

    final searchableText = [
      article.title,
      article.description,
      article.summary,
      category?.label ?? '',
      ...article.tags,
    ].join(' ');

    return _normalizeSearchText(searchableText).contains(query);
  }

  String _normalizeSearchText(String value) {
    const accentMap = <String, String>{
      'à': 'a',
      'á': 'a',
      'â': 'a',
      'ã': 'a',
      'ä': 'a',
      'å': 'a',
      'æ': 'ae',
      'ç': 'c',
      'è': 'e',
      'é': 'e',
      'ê': 'e',
      'ë': 'e',
      'ì': 'i',
      'í': 'i',
      'î': 'i',
      'ï': 'i',
      'ñ': 'n',
      'ò': 'o',
      'ó': 'o',
      'ô': 'o',
      'õ': 'o',
      'ö': 'o',
      'œ': 'oe',
      'ù': 'u',
      'ú': 'u',
      'û': 'u',
      'ü': 'u',
      'ý': 'y',
      'ÿ': 'y',
    };

    final buffer = StringBuffer();
    for (final codePoint in value.toLowerCase().runes) {
      final character = String.fromCharCode(codePoint);
      buffer.write(accentMap[character] ?? character);
    }
    return buffer.toString();
  }

  void _openArticle(AboutAlzheimerArticleData article) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => AboutAlzheimerArticlePage(
          data: _data,
          article: article,
          category: _categoryForArticle(article),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final recommendedArticles = _recommendedArticles;
    final filteredArticles = _filteredArticles;

    return Scaffold(
      appBar: AppBar(title: const Text('À propos d’Alzheimer')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 980),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _AboutAlzheimerHeader(
                    title: _data.title,
                    subtitle: _data.subtitle,
                    introduction: _data.introduction,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  SectionCard(
                    title: 'Rechercher',
                    child: _SearchAndFilterPanel(
                      data: _data,
                      searchController: _searchController,
                      selectedCategoryId: _selectedCategoryId,
                      allCategoriesId: _allCategoriesId,
                      onSearchChanged: (value) {
                        setState(() => _searchTerm = value);
                      },
                      onCategorySelected: (categoryId) {
                        setState(() => _selectedCategoryId = categoryId);
                      },
                      onPopularSearchSelected: (search) {
                        _searchController
                          ..text = search
                          ..selection = TextSelection.collapsed(
                            offset: search.length,
                          );
                        setState(() => _searchTerm = search);
                      },
                    ),
                  ),
                  if (recommendedArticles.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.md),
                    SectionCard(
                      title: 'Articles recommandés',
                      child: _ArticleGrid(
                        articles: recommendedArticles,
                        categoryForArticle: _categoryForArticle,
                        onOpenArticle: _openArticle,
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.md),
                  SectionCard(
                    title: 'Tous les articles',
                    child: filteredArticles.isEmpty
                        ? const _EmptyArticleState()
                        : _ArticleGrid(
                            articles: filteredArticles,
                            categoryForArticle: _categoryForArticle,
                            onOpenArticle: _openArticle,
                          ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _ImportantMessageCard(message: _data.importantMessage),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AboutAlzheimerArticlePage extends StatelessWidget {
  const AboutAlzheimerArticlePage({
    super.key,
    required this.data,
    required this.article,
    required this.category,
  });

  final AboutAlzheimerPageData data;
  final AboutAlzheimerArticleData article;
  final AboutAlzheimerCategoryData? category;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(article.title)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _IconBox(
                                icon: article.icon,
                                size: 58,
                                fontSize: 28,
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: Wrap(
                                  spacing: AppSpacing.xs,
                                  runSpacing: AppSpacing.xs,
                                  children: [
                                    if (category != null)
                                      _InfoChip(
                                        icon: category!.icon,
                                        label: category!.label,
                                      ),
                                    _InfoChip(label: article.readTime),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Text(
                            article.title,
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            article.summary,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: AppColors.textSecondary,
                              height: 1.6,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          ...article.sections.map(
                            (section) => Padding(
                              padding: const EdgeInsets.only(
                                bottom: AppSpacing.md,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    section.heading,
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(fontWeight: FontWeight.w800),
                                  ),
                                  const SizedBox(height: AppSpacing.xs),
                                  Text(
                                    section.content,
                                    style: theme.textTheme.bodyLarge?.copyWith(
                                      color: AppColors.textSecondary,
                                      height: 1.6,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (article.tips.isNotEmpty) ...[
                            _TipsBox(
                              title: article.tipsTitle,
                              tips: article.tips,
                            ),
                            const SizedBox(height: AppSpacing.lg),
                          ],
                          OutlinedButton.icon(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.arrow_back),
                            label: const Text('Retour'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _ImportantMessageCard(message: data.importantMessage),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AboutAlzheimerHeader extends StatelessWidget {
  const _AboutAlzheimerHeader({
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
              AppColors.statusTeal.withValues(alpha: 0.06),
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

class _SearchAndFilterPanel extends StatelessWidget {
  const _SearchAndFilterPanel({
    required this.data,
    required this.searchController,
    required this.selectedCategoryId,
    required this.allCategoriesId,
    required this.onSearchChanged,
    required this.onCategorySelected,
    required this.onPopularSearchSelected,
  });

  final AboutAlzheimerPageData data;
  final TextEditingController searchController;
  final String selectedCategoryId;
  final String allCategoriesId;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onCategorySelected;
  final ValueChanged<String> onPopularSearchSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          decoration: InputDecoration(
            hintText: data.searchPlaceholder,
            prefixIcon: const Icon(Icons.search),
          ),
          onChanged: onSearchChanged,
          controller: searchController,
        ),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: [
            ChoiceChip(
              label: const Text('Tous'),
              selected: selectedCategoryId == allCategoriesId,
              onSelected: (_) => onCategorySelected(allCategoriesId),
            ),
            ...data.categories.map(
              (category) => ChoiceChip(
                avatar: Text(category.icon),
                label: Text(category.label),
                selected: selectedCategoryId == category.id,
                onSelected: (_) => onCategorySelected(category.id),
              ),
            ),
          ],
        ),
        if (data.popularSearches.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          Text(
            'Recherches populaires',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: data.popularSearches
                .map(
                  (search) => ActionChip(
                    label: Text(search),
                    onPressed: () => onPopularSearchSelected(search),
                  ),
                )
                .toList(),
          ),
        ],
      ],
    );
  }
}

class _ArticleGrid extends StatelessWidget {
  const _ArticleGrid({
    required this.articles,
    required this.categoryForArticle,
    required this.onOpenArticle,
  });

  final List<AboutAlzheimerArticleData> articles;
  final AboutAlzheimerCategoryData? Function(AboutAlzheimerArticleData article)
  categoryForArticle;
  final ValueChanged<AboutAlzheimerArticleData> onOpenArticle;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = AppSpacing.sm;
        final maxWidth = constraints.maxWidth;
        final columns = maxWidth >= 940
            ? 3
            : maxWidth >= 620
            ? 2
            : 1;
        final itemWidth = (maxWidth - ((columns - 1) * spacing)) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: articles
              .map(
                (article) => SizedBox(
                  width: itemWidth,
                  child: _ArticleCard(
                    article: article,
                    category: categoryForArticle(article),
                    onTap: () => onOpenArticle(article),
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _ArticleCard extends StatelessWidget {
  const _ArticleCard({
    required this.article,
    required this.category,
    required this.onTap,
  });

  final AboutAlzheimerArticleData article;
  final AboutAlzheimerCategoryData? category;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final visibleTags = article.tags.take(3).toList();

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
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _IconBox(icon: article.icon),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Wrap(
                      spacing: AppSpacing.xs,
                      runSpacing: AppSpacing.xs,
                      children: [
                        if (category != null)
                          _InfoChip(
                            icon: category!.icon,
                            label: category!.label,
                          ),
                        _InfoChip(label: article.readTime),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                article.title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                article.description,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
              ),
              if (visibleTags.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: visibleTags
                      .map((tag) => _InfoChip(label: tag, dense: true))
                      .toList(),
                ),
              ],
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Lire',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: AppColors.primaryBlue,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IconBox extends StatelessWidget {
  const _IconBox({required this.icon, this.size = 46, this.fontSize = 22});

  final String icon;
  final double size;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.primaryBlue.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
      ),
      alignment: Alignment.center,
      child: Text(icon, style: TextStyle(fontSize: fontSize)),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.label, this.icon, this.dense = false});

  final String label;
  final String? icon;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? AppSpacing.xs : AppSpacing.sm,
        vertical: dense ? AppSpacing.xxs : AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Text(icon!),
            const SizedBox(width: AppSpacing.xxs),
          ],
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TipsBox extends StatelessWidget {
  const _TipsBox({required this.title, required this.tips});

  final String title;
  final List<String> tips;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.primaryBlue.withValues(alpha: 0.06),
        border: Border.all(
          color: AppColors.primaryBlue.withValues(alpha: 0.16),
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          ...tips.map(
            (tip) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 5),
                    child: Icon(
                      Icons.check_circle_outline,
                      size: 16,
                      color: AppColors.primaryBlue,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      tip,
                      style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ImportantMessageCard extends StatelessWidget {
  const _ImportantMessageCard({required this.message});

  final AboutAlzheimerImportantMessageData message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
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
              message.title,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              message.description,
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

class _EmptyArticleState extends StatelessWidget {
  const _EmptyArticleState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.search_off_outlined,
              color: AppColors.primaryBlue.withValues(alpha: 0.65),
              size: 42,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Aucun article trouvé',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Aucun article ne correspond à cette recherche.',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class AboutAlzheimerPageData {
  const AboutAlzheimerPageData({
    required this.title,
    required this.subtitle,
    required this.introduction,
    required this.searchPlaceholder,
    required this.categories,
    required this.popularSearches,
    required this.recommendedArticleIds,
    required this.articles,
    required this.importantMessage,
  });

  final String title;
  final String subtitle;
  final String introduction;
  final String searchPlaceholder;
  final List<AboutAlzheimerCategoryData> categories;
  final List<String> popularSearches;
  final List<String> recommendedArticleIds;
  final List<AboutAlzheimerArticleData> articles;
  final AboutAlzheimerImportantMessageData importantMessage;

  factory AboutAlzheimerPageData.fromMap(Map<String, dynamic> source) {
    final importantMessage = _asMap(source['importantMessage']);

    return AboutAlzheimerPageData(
      title: _asString(source['title']),
      subtitle: _asString(source['subtitle']),
      introduction: _asString(source['introduction']),
      searchPlaceholder: _asString(source['searchPlaceholder']),
      categories: _asCategories(source['categories']),
      popularSearches: _asStringList(source['popularSearches']),
      recommendedArticleIds: _asStringList(source['recommendedArticleIds']),
      articles: _asArticles(source['articles']),
      importantMessage: AboutAlzheimerImportantMessageData(
        title: _asString(importantMessage['title']),
        description: _asString(importantMessage['description']),
      ),
    );
  }

  static Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return value.map((key, entry) => MapEntry(key.toString(), entry));
    }
    return const <String, dynamic>{};
  }

  static String _asString(dynamic value) {
    return value is String ? value : '';
  }

  static List<String> _asStringList(dynamic value) {
    if (value is! List) return const <String>[];
    return value
        .map(_asString)
        .where((item) => item.trim().isNotEmpty)
        .toList();
  }

  static List<AboutAlzheimerCategoryData> _asCategories(dynamic value) {
    if (value is! List) return const <AboutAlzheimerCategoryData>[];

    return value.map((entry) {
      final item = _asMap(entry);
      return AboutAlzheimerCategoryData(
        id: _asString(item['id']),
        label: _asString(item['label']),
        icon: _asString(item['icon']),
        description: _asString(item['description']),
      );
    }).toList();
  }

  static List<AboutAlzheimerArticleSectionData> _asSections(dynamic value) {
    if (value is! List) return const <AboutAlzheimerArticleSectionData>[];

    return value.map((entry) {
      final item = _asMap(entry);
      return AboutAlzheimerArticleSectionData(
        heading: _asString(item['heading']),
        content: _asString(item['content']),
      );
    }).toList();
  }

  static List<AboutAlzheimerArticleData> _asArticles(dynamic value) {
    if (value is! List) return const <AboutAlzheimerArticleData>[];

    return value.map((entry) {
      final item = _asMap(entry);
      return AboutAlzheimerArticleData(
        id: _asString(item['id']),
        categoryId: _asString(item['categoryId']),
        icon: _asString(item['icon']),
        title: _asString(item['title']),
        description: _asString(item['description']),
        readTime: _asString(item['readTime']),
        tags: _asStringList(item['tags']),
        summary: _asString(item['summary']),
        sections: _asSections(item['sections']),
        tipsTitle: _asString(item['tipsTitle']),
        tips: _asStringList(item['tips']),
      );
    }).toList();
  }
}

class AboutAlzheimerCategoryData {
  const AboutAlzheimerCategoryData({
    required this.id,
    required this.label,
    required this.icon,
    required this.description,
  });

  final String id;
  final String label;
  final String icon;
  final String description;
}

class AboutAlzheimerArticleSectionData {
  const AboutAlzheimerArticleSectionData({
    required this.heading,
    required this.content,
  });

  final String heading;
  final String content;
}

class AboutAlzheimerArticleData {
  const AboutAlzheimerArticleData({
    required this.id,
    required this.categoryId,
    required this.icon,
    required this.title,
    required this.description,
    required this.readTime,
    required this.tags,
    required this.summary,
    required this.sections,
    required this.tipsTitle,
    required this.tips,
  });

  final String id;
  final String categoryId;
  final String icon;
  final String title;
  final String description;
  final String readTime;
  final List<String> tags;
  final String summary;
  final List<AboutAlzheimerArticleSectionData> sections;
  final String tipsTitle;
  final List<String> tips;
}

class AboutAlzheimerImportantMessageData {
  const AboutAlzheimerImportantMessageData({
    required this.title,
    required this.description,
  });

  final String title;
  final String description;
}
