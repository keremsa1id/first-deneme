import 'package:flutter/material.dart';

import 'models/word_category.dart';
import 'screens/category_screen.dart';
import 'screens/quiz_mode_screen.dart';
import 'screens/quiz_screen.dart';
import 'screens/sentence_screen.dart';
import 'screens/word_card_screen.dart';
import 'services/progress_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ProgressStore.instance.load();
  runApp(const KelimeApp());
}

class KelimeApp extends StatelessWidget {
  const KelimeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Word Game',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.orange,
        textTheme: const TextTheme(
          displayLarge: TextStyle(fontSize: 48, fontWeight: FontWeight.bold),
          headlineLarge: TextStyle(fontSize: 40, fontWeight: FontWeight.bold),
          headlineMedium: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
          titleLarge: TextStyle(fontSize: 26, fontWeight: FontWeight.w600),
          bodyLarge: TextStyle(fontSize: 22),
          bodyMedium: TextStyle(fontSize: 20),
          labelLarge: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
      ),
      home: const HomeScreen(),
    );
  }
}

/// Ana menü. Üstte günlük hedef ve seri kartı vardır.
/// Words ve Sentences önce grup, Quiz önce tür sonra grup seçtirir.
/// Mixed Test bütün gruplardan, Review yanlış bilinen kelimelerden sorar.
/// Favorites yıldızlanan kelimelerin kartlarını gösterir.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  void _open(BuildContext context, Widget screen) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (BuildContext context) => screen),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Word Game',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.displayLarge?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 24),
                const _DailyGoalCard(),
                const SizedBox(height: 24),
                _MenuButton(
                  label: 'Words',
                  icon: Icons.abc,
                  onPressed: () => _open(
                    context,
                    CategoryScreen(
                      title: 'Words',
                      builder: (WordCategory category) => WordCardScreen(
                        category: category.id,
                        title: category.name,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                _MenuButton(
                  label: 'Sentences',
                  icon: Icons.chat_bubble,
                  onPressed: () => _open(
                    context,
                    CategoryScreen(
                      title: 'Sentences',
                      builder: (WordCategory category) => SentenceScreen(
                        category: category.id,
                        title: category.name,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                _MenuButton(
                  label: 'Quiz',
                  icon: Icons.star,
                  onPressed: () => _open(context, const QuizModeScreen()),
                ),
                const SizedBox(height: 24),
                _MenuButton(
                  label: 'Mixed Test',
                  icon: Icons.shuffle_rounded,
                  onPressed: () => _open(
                    context,
                    const QuizScreen(
                      title: 'Mixed Test',
                      questionCount: 15,
                      mixCategories: true,
                      scoreKey: 'mixed',
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                ListenableBuilder(
                  listenable: ProgressStore.instance,
                  builder: (BuildContext context, Widget? _) {
                    final int count = ProgressStore.instance.reviewCount;
                    return _MenuButton(
                      label: count == 0 ? 'Review' : 'Review ($count)',
                      icon: Icons.replay_rounded,
                      onPressed: () => _open(
                        context,
                        QuizScreen(
                          title: 'Review',
                          onlyWords: () => ProgressStore.instance.reviewWords,
                          emptyMessage: 'No words to review. Great job! 🎉',
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 24),
                _MenuButton(
                  label: 'Favorites',
                  icon: Icons.star_rounded,
                  onPressed: () => _open(
                    context,
                    WordCardScreen(
                      title: 'Favorites',
                      onlyWords: ProgressStore.instance.favorites,
                      emptyMessage: 'Tap the ☆ on a word card to add it here.',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MenuButton extends StatelessWidget {
  const _MenuButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 36),
      label: Text(label),
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(80),
        textStyle: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
      ),
    );
  }
}

/// Günlük hedef ve seri kartı. Hedef tutmadıysa kaç kelime kaldığını
/// hatırlatır.
class _DailyGoalCard extends StatelessWidget {
  const _DailyGoalCard();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ProgressStore progress = ProgressStore.instance;

    return ListenableBuilder(
      listenable: progress,
      builder: (BuildContext context, Widget? _) {
        const int goal = ProgressStore.dailyGoal;
        final int today =
            progress.todayCount > goal ? goal : progress.todayCount;
        final int streak = progress.streak;
        final int left = goal - today;
        final String message = progress.goalMetToday
            ? 'Goal done! Great job! 🎉'
            : '$left more ${left == 1 ? 'word' : 'words'} to reach '
                "today's goal!";

        return Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.secondaryContainer,
            borderRadius: BorderRadius.circular(24),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Today: $today / $goal words',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSecondaryContainer,
                      ),
                    ),
                  ),
                  Text(
                    '🔥 $streak ${streak == 1 ? 'day' : 'days'}',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSecondaryContainer,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: today / goal,
                  minHeight: 16,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSecondaryContainer,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
