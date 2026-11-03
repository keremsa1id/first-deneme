import 'package:flutter/material.dart';

import '../models/word.dart';
import '../models/word_category.dart';
import '../services/word_repository.dart';
import '../widgets/message_view.dart';

/// Kelime grubunu seçme ekranı.
///
/// Gruplar büyük, renkli kartlar halinde dizilir. Bir gruba dokununca
/// [builder] ile o grubun ekranı (kelimeler, cümleler veya quiz) açılır.
/// [minWords]'ten az kelimesi olan gruplar gösterilmez.
class CategoryScreen extends StatefulWidget {
  const CategoryScreen({
    super.key,
    required this.title,
    required this.builder,
    this.repository = const WordRepository(),
    this.minWords = 1,
  });

  final String title;
  final Widget Function(WordCategory category) builder;
  final WordRepository repository;
  final int minWords;

  @override
  State<CategoryScreen> createState() => _CategoryScreenState();
}

class _CategoryScreenState extends State<CategoryScreen> {
  late Future<List<Word>> _wordsFuture;

  @override
  void initState() {
    super.initState();
    _wordsFuture = widget.repository.loadWords();
  }

  void _retry() {
    setState(() => _wordsFuture = widget.repository.loadWords());
  }

  /// Gruplar [wordCategories] sırasıyla, tanımsız gruplar en sonda.
  List<(WordCategory, int)> _groups(List<Word> words) {
    final Map<String, int> counts = <String, int>{};
    for (final Word word in words) {
      counts[word.category] = (counts[word.category] ?? 0) + 1;
    }
    final List<String> ids = <String>[
      for (final WordCategory category in wordCategories)
        if (counts.containsKey(category.id)) category.id,
      for (final String id in counts.keys)
        if (wordCategories.every((WordCategory c) => c.id != id)) id,
    ];
    return <(WordCategory, int)>[
      for (final String id in ids)
        if (counts[id]! >= widget.minWords) (WordCategory.byId(id), counts[id]!),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        toolbarHeight: 72,
        backgroundColor: theme.colorScheme.surface,
        leading: IconButton(
          iconSize: 40,
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Geri',
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          widget.title,
          style: theme.textTheme.headlineMedium?.copyWith(
            color: theme.colorScheme.primary,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: FutureBuilder<List<Word>>(
          future: _wordsFuture,
          builder: (BuildContext context, AsyncSnapshot<List<Word>> snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(
                child: SizedBox(
                  width: 72,
                  height: 72,
                  child: CircularProgressIndicator(strokeWidth: 8),
                ),
              );
            }

            if (snapshot.hasError) {
              final Object? error = snapshot.error;
              final String message = error is WordRepositoryException
                  ? error.message
                  : 'Gruplar yüklenemedi.';
              return MessageView(
                icon: Icons.sentiment_dissatisfied_rounded,
                message: message,
                buttonLabel: 'Tekrar dene',
                onPressed: _retry,
              );
            }

            final List<(WordCategory, int)> groups =
                _groups(snapshot.data ?? const <Word>[]);
            if (groups.isEmpty) {
              return const MessageView(
                icon: Icons.inbox_rounded,
                message: 'Henüz kelime grubu yok.',
              );
            }

            return GridView.builder(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 260,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 0.95,
              ),
              itemCount: groups.length,
              itemBuilder: (BuildContext context, int index) {
                final (WordCategory category, int count) = groups[index];
                return _CategoryTile(
                  category: category,
                  wordCount: count,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (BuildContext context) =>
                          widget.builder(category),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

/// Tek bir grup kartı: büyük emoji, grup adı ve kelime sayısı.
class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    required this.category,
    required this.wordCount,
    required this.onTap,
  });

  final WordCategory category;
  final int wordCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Semantics(
      button: true,
      label: category.name,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: category.color.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: category.color, width: 4),
          ),
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Expanded(
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      category.emoji,
                      style: const TextStyle(fontSize: 72),
                    ),
                  ),
                ),
              ),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  category.name,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
              Text(
                '$wordCount words',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
