import 'dart:async';

import 'package:flutter/material.dart';

import '../models/word.dart';
import '../services/quiz_generator.dart';
import '../services/tts_service.dart';
import '../services/word_repository.dart';
import '../widgets/card_colors.dart';
import '../widgets/message_view.dart';
import '../widgets/word_picture.dart';

/// Dinle ve doğru resmi seç oyunu.
///
/// Her soruda İngilizce kelime yazılır ve sesli okunur; çocuk resimler
/// arasından doğrusuna dokunur. Yanlış resim soluklaşır ve tekrar denenebilir.
/// Doğru resim bulununca kısa bir süre sonra sonraki soruya geçilir.
/// İlk denemede bilinen sorular puan sayılır. Sonda yıldızlı sonuç gösterilir.
class QuizScreen extends StatefulWidget {
  const QuizScreen({
    super.key,
    this.repository = const WordRepository(),
    this.questionCount = 10,
  });

  final WordRepository repository;
  final int questionCount;

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  /// Doğru cevaptan sonra sonraki soruya geçmeden önceki bekleme.
  static const Duration _nextQuestionDelay = Duration(milliseconds: 1500);

  final QuizGenerator _generator = QuizGenerator();
  late Future<List<Word>> _wordsFuture;

  List<QuizQuestion> _questions = const <QuizQuestion>[];
  int _currentIndex = 0;
  int _score = 0;
  bool _solved = false;
  bool _finished = false;
  final Set<Word> _wrongPicks = <Word>{};
  Timer? _nextTimer;

  @override
  void initState() {
    super.initState();
    _wordsFuture = _loadWords();
  }

  @override
  void dispose() {
    _nextTimer?.cancel();
    TtsService.instance.stop();
    super.dispose();
  }

  Future<List<Word>> _loadWords() async {
    final List<Word> words = await widget.repository.loadWords();
    _startRound(words);
    return words;
  }

  void _retry() {
    setState(() => _wordsFuture = _loadWords());
  }

  /// Yeni bir tur başlatır ve ilk kelimeyi okur. setState içinde çağrılabilir.
  void _startRound(List<Word> words) {
    _nextTimer?.cancel();
    _questions = _generator.generate(
      words,
      questionCount: widget.questionCount,
    );
    _currentIndex = 0;
    _score = 0;
    _solved = false;
    _finished = false;
    _wrongPicks.clear();
    _speakCurrent();
  }

  void _speakCurrent() {
    if (_questions.isEmpty || _finished) {
      return;
    }
    TtsService.instance.speak(_questions[_currentIndex].answer.english);
  }

  void _onOptionTap(Word option) {
    if (_solved || _wrongPicks.contains(option)) {
      return;
    }
    final QuizQuestion question = _questions[_currentIndex];

    if (!identical(option, question.answer)) {
      setState(() => _wrongPicks.add(option));
      return;
    }

    setState(() {
      _solved = true;
      if (_wrongPicks.isEmpty) {
        _score++;
      }
    });
    TtsService.instance.speak(question.answer.english);
    _nextTimer = Timer(_nextQuestionDelay, _goToNextQuestion);
  }

  void _goToNextQuestion() {
    if (!mounted) {
      return;
    }
    setState(() {
      if (_currentIndex >= _questions.length - 1) {
        _finished = true;
        return;
      }
      _currentIndex++;
      _solved = false;
      _wrongPicks.clear();
    });
    _speakCurrent();
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
                  : 'Quiz yüklenemedi.';
              return MessageView(
                icon: Icons.sentiment_dissatisfied_rounded,
                message: message,
                buttonLabel: 'Tekrar dene',
                onPressed: _retry,
              );
            }

            final List<Word> words = snapshot.data ?? const <Word>[];
            // Tek kelimeyle seçim yapılamaz; en az iki şık gerekir.
            if (words.length < 2 || _questions.isEmpty) {
              return const MessageView(
                icon: Icons.inbox_rounded,
                message: 'Quiz için yeterli kelime yok.',
              );
            }

            if (_finished) {
              return _ResultView(
                score: _score,
                total: _questions.length,
                onPlayAgain: () => setState(() => _startRound(words)),
                onHome: () => Navigator.of(context).pop(),
              );
            }

            return _buildQuestion(context);
          },
        ),
      ),
    );
  }

  Widget _buildQuestion(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final QuizQuestion question = _questions[_currentIndex];

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Column(
        children: [
          // İlerleme: kaçıncı soru olduğu.
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: (_currentIndex + 1) / _questions.length,
                    minHeight: 16,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Text(
                '${_currentIndex + 1} / ${_questions.length}',
                style: theme.textTheme.titleLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _Prompt(word: question.answer, onListen: _speakCurrent),
          const SizedBox(height: 16),
          Expanded(child: _buildOptions(question)),
        ],
      ),
    );
  }

  /// Şıkları ikişerli satırlar halinde, kalan alanı dolduracak şekilde dizer.
  Widget _buildOptions(QuizQuestion question) {
    final List<Widget> rows = <Widget>[];
    for (int i = 0; i < question.options.length; i += 2) {
      final List<Word> rowOptions = question.options.skip(i).take(2).toList();
      if (rows.isNotEmpty) {
        rows.add(const SizedBox(height: 16));
      }
      rows.add(
        Expanded(
          child: Row(
            children: [
              for (int j = 0; j < rowOptions.length; j++) ...[
                if (j > 0) const SizedBox(width: 16),
                Expanded(child: _buildOption(question, rowOptions[j])),
              ],
            ],
          ),
        ),
      );
    }
    return Column(children: rows);
  }

  Widget _buildOption(QuizQuestion question, Word option) {
    final _OptionState state;
    if (_wrongPicks.contains(option)) {
      state = _OptionState.wrong;
    } else if (_solved && identical(option, question.answer)) {
      state = _OptionState.correct;
    } else if (_solved) {
      state = _OptionState.faded;
    } else {
      state = _OptionState.normal;
    }

    return _OptionCard(
      // Soru değişince kart durumu (animasyon) sıfırlansın.
      key: ValueKey<String>('$_currentIndex-${option.english}'),
      word: option,
      state: state,
      onTap: () => _onOptionTap(option),
    );
  }
}

/// Sorulan kelime ve tekrar dinleme butonu.
class _Prompt extends StatelessWidget {
  const _Prompt({required this.word, required this.onListen});

  final Word word;
  final VoidCallback onListen;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Row(
      children: [
        Expanded(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              word.english,
              textAlign: TextAlign.center,
              style: theme.textTheme.displayLarge?.copyWith(
                fontSize: 56,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Tooltip(
          message: 'Dinle',
          child: SizedBox(
            width: 96,
            height: 72,
            child: FilledButton(
              onPressed: onListen,
              style: FilledButton.styleFrom(
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
              child: const Icon(Icons.volume_up_rounded, size: 44),
            ),
          ),
        ),
      ],
    );
  }
}

enum _OptionState { normal, wrong, correct, faded }

/// Tek bir resim şıkkı. Duruma göre çerçeve rengi, saydamlık ve simge değişir.
class _OptionCard extends StatelessWidget {
  const _OptionCard({
    super.key,
    required this.word,
    required this.state,
    required this.onTap,
  });

  static const Color _correctColor = Color(0xFF43A047);
  static const Color _wrongColor = Color(0xFFE53935);

  final Word word;
  final _OptionState state;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color baseColor = colorFor(word.english);
    final Color borderColor = switch (state) {
      _OptionState.correct => _correctColor,
      _OptionState.wrong => _wrongColor,
      _ => baseColor,
    };
    final IconData? badge = switch (state) {
      _OptionState.correct => Icons.check_circle_rounded,
      _OptionState.wrong => Icons.cancel_rounded,
      _ => null,
    };

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 250),
      opacity: switch (state) {
        _OptionState.wrong => 0.45,
        _OptionState.faded => 0.3,
        _ => 1.0,
      },
      child: AnimatedScale(
        duration: const Duration(milliseconds: 250),
        scale: state == _OptionState.correct ? 1.05 : 1.0,
        child: Semantics(
          button: true,
          label: word.english,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              decoration: BoxDecoration(
                color: baseColor.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: borderColor,
                  width: state == _OptionState.normal ? 4 : 8,
                ),
              ),
              padding: const EdgeInsets.all(12),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: WordPicture(word: word, color: baseColor),
                  ),
                  if (badge != null)
                    Positioned(
                      top: 0,
                      right: 0,
                      child: Icon(badge, size: 48, color: borderColor),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Tur sonunda gösterilen yıldızlı sonuç ekranı.
class _ResultView extends StatelessWidget {
  const _ResultView({
    required this.score,
    required this.total,
    required this.onPlayAgain,
    required this.onHome,
  });

  final int score;
  final int total;
  final VoidCallback onPlayAgain;
  final VoidCallback onHome;

  /// 0-3 yıldız: hepsi ya da neredeyse hepsi doğruysa 3 yıldız.
  int get _stars {
    if (total == 0 || score == 0) {
      return 0;
    }
    final double ratio = score / total;
    if (ratio >= 0.9) {
      return 3;
    }
    if (ratio >= 0.6) {
      return 2;
    }
    return 1;
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final int stars = _stars;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (int i = 0; i < 3; i++)
                  Icon(
                    i < stars ? Icons.star_rounded : Icons.star_border_rounded,
                    size: 96,
                    color: const Color(0xFFFFC107),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              stars >= 2 ? 'Aferin!' : 'Tekrar deneyelim!',
              textAlign: TextAlign.center,
              style: theme.textTheme.displayLarge?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '$score / $total doğru',
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineMedium,
            ),
            const SizedBox(height: 40),
            FilledButton.icon(
              onPressed: onPlayAgain,
              icon: const Icon(Icons.replay_rounded, size: 36),
              label: const Text('Tekrar oyna'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(80),
                textStyle: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onHome,
              icon: const Icon(Icons.home_rounded, size: 36),
              label: const Text('Ana ekran'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(80),
                textStyle: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
