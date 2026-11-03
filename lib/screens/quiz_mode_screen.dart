import 'package:flutter/material.dart';

import '../models/quiz_mode.dart';
import '../models/word_category.dart';
import 'category_screen.dart';
import 'quiz_screen.dart';

/// Quiz türünü seçme ekranı. Türe dokununca grup seçme ekranı açılır.
class QuizModeScreen extends StatelessWidget {
  const QuizModeScreen({super.key});

  /// En iyi skorun saklandığı anahtar: tür ve grup.
  static String scoreKey(QuizMode mode, String categoryId) =>
      '${mode.name}:$categoryId';

  void _openMode(BuildContext context, QuizMode mode) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => CategoryScreen(
          title: mode.title,
          // Seçim yapılabilmesi için en az iki şık gerekir.
          minWords: 2,
          scoreKeyFor: (WordCategory category) =>
              scoreKey(mode, category.id),
          builder: (WordCategory category) => QuizScreen(
            mode: mode,
            category: category.id,
            title: category.name,
            scoreKey: scoreKey(mode, category.id),
          ),
        ),
      ),
    );
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
          'Quiz',
          style: theme.textTheme.headlineMedium?.copyWith(
            color: theme.colorScheme.primary,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          children: [
            for (final QuizMode mode in QuizMode.values) ...[
              _ModeTile(mode: mode, onTap: () => _openMode(context, mode)),
              const SizedBox(height: 16),
            ],
          ],
        ),
      ),
    );
  }
}

/// Tek bir quiz türü kartı: simge, ad ve kısa açıklama.
class _ModeTile extends StatelessWidget {
  const _ModeTile({required this.mode, required this.onTap});

  final QuizMode mode;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Material(
      color: theme.colorScheme.primaryContainer,
      borderRadius: BorderRadius.circular(28),
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Icon(
                mode.icon,
                size: 56,
                color: theme.colorScheme.onPrimaryContainer,
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      mode.title,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      mode.description,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
