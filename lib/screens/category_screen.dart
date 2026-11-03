import 'package:flutter/material.dart';

import '../models/word.dart';
import '../models/word_category.dart';
import '../services/progress_store.dart';
import '../services/word_repository.dart';
import '../widgets/message_view.dart';

/// Kelime grubunu seçme ekranı.
///
/// Gruplar büyük, renkli kartlar halinde dizilir. Bir gruba dokununca
/// [builder] ile o grubun ekranı (kelimeler, cümleler veya quiz) açılır.
/// [minWords]'ten az kelimesi olan gruplar gösterilmez.
///
/// Her kartta grubun kaç kelimesinin öğrenildiği ilerleme çubuğuyla
/// gösterilir. [scoreKeyFor] verilirse o quizin en iyi skoru da yazılır.
class CategoryScreen extends StatefulWidget {
  const CategoryScreen({
    super.key,
    required this.title,
    required this.builder,
    this.repository = const WordRepository(),
    this.minWords = 1,
    this.scoreKeyFor,
  });

  final String title;
  final Widget Function(WordCategory category) builder;
  final WordRepository repository;
  final int minWords;
  final String Function(WordCategory category)? scoreKeyFor;

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
  List<(WordCategory, List<Word>)> _groups(List<Word> words) {
    final Map<String, List<Word>> byId = <String, List<Word>>{};
    for (final Word word in words) {
      byId.putIfAbsent(word.category, () => <Word>[]).add(word);
    }
    final List<String> ids = <String>[
      for (final WordCategory category in wordCategories)
        if (byId.containsKey(category.id)) category.id,
      for (final String id in byId.keys)
        if (wordCategories.every((WordCategory c) => c.id != id)) id,
    ];
    return <(WordCategory, List<Word>)>[
      for (final String id in ids)
        if (byId[id]!.length >= widget.minWords)
          (WordCategory.byId(id), byId[id]!),
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

            final List<(WordCategory, List<Word>)> groups =
                _groups(snapshot.data ?? const <Word>[]);
            if (groups.isEmpty) {
              return const MessageView(
                icon: Icons.inbox_rounded,
                message: 'Henüz kelime grubu yok.',
              );
            }

            // Quizden dönünce ilerleme çubukları güncellensin.
            return ListenableBuilder(
              listenable: ProgressStore.instance,
              builder: (BuildContext context, Widget? _) => GridView.builder(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 260,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  childAspectRatio: 0.8,
                ),
                itemCount: groups.length,
                itemBuilder: (BuildContext context, int index) {
                  final (WordCategory category, List<Word> words) =
                      groups[index];
                  final String? scoreKey = widget.scoreKeyFor?.call(category);
                  return _CategoryTile(
                    category: category,
                    wordCount: words.length,
                    learnedCount: ProgressStore.instance.learnedCount(words),
                    best: scoreKey == null
                        ? null
                        : ProgressStore.instance.bestScore(scoreKey),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (BuildContext context) =>
                            widget.builder(category),
                      ),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Tek bir grup kartı: büyük emoji, grup adı, öğrenme ilerlemesi ve
/// varsa en iyi quiz skoru.
class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    required this.category,
    required this.wordCount,
    required this.learnedCount,
    required this.best,
    required this.onTap,
  });

  final WordCategory category;
  final int wordCount;
  final int learnedCount;
  final QuizScore? best;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final QuizScore? best = this.best;

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
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: wordCount == 0 ? 0 : learnedCount / wordCount,
                  minHeight: 12,
                  color: category.color,
                  backgroundColor: category.color.withValues(alpha: 0.25),
                ),
              ),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  '$learnedCount/$wordCount learned',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              if (best != null)
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    '⭐ Best ${best.score}/${best.total}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
