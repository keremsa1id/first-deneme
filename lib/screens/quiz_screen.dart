import 'dart:async';

import 'package:flutter/material.dart';

import '../models/quiz_mode.dart';
import '../models/word.dart';
import '../services/progress_store.dart';
import '../services/quiz_generator.dart';
import '../services/tts_service.dart';
import '../services/word_repository.dart';
import '../widgets/card_colors.dart';
import '../widgets/message_view.dart';
import '../widgets/word_picture.dart';

/// Quiz ekranı. Dört türü vardır (bkz. [QuizMode]):
///
/// * [QuizMode.picture]: kelime yazılır ve okunur, doğru resim seçilir.
/// * [QuizMode.listen]: kelime sadece okunur, doğru resim seçilir.
/// * [QuizMode.definition]: İngilizce tanım gösterilir, doğru kelime seçilir.
/// * [QuizMode.typing]: resim ve Türkçesi gösterilir, kelime yazılır.
///
/// Şıklı türlerde yanlış şık soluklaşır ve tekrar denenebilir. Doğru cevap
/// bulununca kısa bir süre sonra sonraki soruya geçilir. Yazma türünde iki
/// yanlıştan sonra doğru cevap gösterilir. İlk denemede bilinen sorular puan
/// sayılır ve kelime "öğrenildi" olur; yanlış bilinen kelimeler tekrar
/// destesine (Review) düşer. Sonda yıldızlı sonuç gösterilir.
///
/// [category] verilirse yalnızca o gruptan, [onlyWords] verilirse yalnızca
/// döndürdüğü kelimelerden sorulur (şıklar yine bütün kelimelerden seçilir).
/// [onlyWords] her turda yeniden çağrılır; böylece "Tekrar oyna"da tekrar
/// destesinin güncel hâli kullanılır.
/// [mixCategories] true ise sorular bütün gruplara dengeli dağıtılır.
/// [scoreKey] verilirse en iyi skor bu anahtarla saklanır.
class QuizScreen extends StatefulWidget {
  const QuizScreen({
    super.key,
    this.repository = const WordRepository(),
    this.questionCount = 10,
    this.mode = QuizMode.picture,
    this.category,
    this.onlyWords,
    this.title = 'Quiz',
    this.mixCategories = false,
    this.scoreKey,
    this.emptyMessage = 'Quiz için yeterli kelime yok.',
  });

  final WordRepository repository;
  final int questionCount;
  final QuizMode mode;
  final String? category;
  final Set<String> Function()? onlyWords;
  final String title;
  final bool mixCategories;
  final String? scoreKey;
  final String emptyMessage;

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  /// Doğru cevaptan sonra sonraki soruya geçmeden önceki bekleme.
  static const Duration _nextQuestionDelay = Duration(milliseconds: 1500);

  /// Yazma türünde bu kadar yanlıştan sonra doğru cevap gösterilir.
  static const int _maxTypingAttempts = 2;

  final QuizGenerator _generator = QuizGenerator();
  final ProgressStore _progress = ProgressStore.instance;
  late Future<List<Word>> _wordsFuture;

  List<QuizQuestion> _questions = const <QuizQuestion>[];
  int _currentIndex = 0;
  int _score = 0;
  int _missed = 0;
  bool _solved = false;
  bool _finished = false;
  bool _isNewBest = false;
  final Set<Word> _wrongPicks = <Word>{};
  Timer? _nextTimer;

  // Yazma türü.
  final TextEditingController _typingController = TextEditingController();
  final FocusNode _typingFocus = FocusNode();
  int _typingMistakes = 0;
  bool _revealed = false;

  @override
  void initState() {
    super.initState();
    _wordsFuture = _loadWords();
  }

  @override
  void dispose() {
    _nextTimer?.cancel();
    _typingController.dispose();
    _typingFocus.dispose();
    TtsService.instance.stop();
    super.dispose();
  }

  Future<List<Word>> _loadWords() async {
    final List<Word> words =
        await widget.repository.loadWords(category: widget.category);
    _startRound(words);
    return words;
  }

  void _retry() {
    setState(() => _wordsFuture = _loadWords());
  }

  /// Yeni bir tur başlatır ve ilk soruyu okur. setState içinde çağrılabilir.
  void _startRound(List<Word> words) {
    _nextTimer?.cancel();
    final Set<String>? only = widget.onlyWords?.call();
    final bool needsDefinition = widget.mode == QuizMode.definition;
    _questions = _generator.generate(
      words,
      questionCount: widget.questionCount,
      mixCategories: widget.mixCategories,
      canAsk: only == null && !needsDefinition
          ? null
          : (Word word) =>
              (only == null || only.contains(word.english.toLowerCase())) &&
              (!needsDefinition || word.definition != null),
      // Tanımda geçen bir kelime yanlış şık olursa kafa karıştırır
      // (ör. "A bird that says quack." sorusunda "bird" şıkkı).
      avoidOption: needsDefinition
          ? (Word answer, Word option) =>
              _mentions(answer.definition ?? '', option.english)
          : null,
    );
    _currentIndex = 0;
    _score = 0;
    _missed = 0;
    _finished = false;
    _isNewBest = false;
    _resetQuestionState();
    _speakCurrent();
  }

  static bool _mentions(String text, String word) => RegExp(
        '\\b${RegExp.escape(word)}s?\\b',
        caseSensitive: false,
      ).hasMatch(text);

  void _resetQuestionState() {
    _solved = false;
    _wrongPicks.clear();
    _typingMistakes = 0;
    _revealed = false;
    _typingController.clear();
  }

  QuizQuestion get _current => _questions[_currentIndex];

  /// Sorunun sesli kısmını okur. Yazma türünde cevabı ele vermemek için
  /// kendiliğinden okunmaz; ipucu butonuyla okunabilir.
  void _speakCurrent() {
    if (_questions.isEmpty || _finished) {
      return;
    }
    switch (widget.mode) {
      case QuizMode.picture:
      case QuizMode.listen:
        TtsService.instance.speak(_current.answer.english);
      case QuizMode.definition:
        TtsService.instance.speak(_current.answer.definition ?? '');
      case QuizMode.typing:
        break;
    }
  }

  void _onOptionTap(Word option) {
    if (_solved || _wrongPicks.contains(option)) {
      return;
    }
    if (!identical(option, _current.answer)) {
      setState(() => _wrongPicks.add(option));
      return;
    }
    _completeQuestion(firstTry: _wrongPicks.isEmpty);
  }

  void _checkTyped() {
    if (_solved) {
      return;
    }
    final String typed = _normalize(_typingController.text);
    if (typed.isEmpty) {
      _typingFocus.requestFocus();
      return;
    }
    if (typed == _normalize(_current.answer.english)) {
      _completeQuestion(firstTry: _typingMistakes == 0);
      return;
    }

    setState(() => _typingMistakes++);
    if (_typingMistakes < _maxTypingAttempts) {
      _typingController.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _typingController.text.length,
      );
      _typingFocus.requestFocus();
      return;
    }
    // Yeterince denendi: doğru yazımı göster, çocuk "Next" ile geçsin.
    setState(() {
      _solved = true;
      _revealed = true;
      _missed++;
    });
    _progress.recordAnswer(_current.answer, firstTry: false);
    TtsService.instance.speak(_current.answer.english);
  }

  static String _normalize(String text) =>
      text.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  void _completeQuestion({required bool firstTry}) {
    setState(() {
      _solved = true;
      if (firstTry) {
        _score++;
      } else {
        _missed++;
      }
    });
    _progress.recordAnswer(_current.answer, firstTry: firstTry);
    TtsService.instance.speak(_current.answer.english);
    _nextTimer = Timer(_nextQuestionDelay, _goToNextQuestion);
  }

  void _goToNextQuestion() {
    if (!mounted) {
      return;
    }
    _nextTimer?.cancel();
    if (_currentIndex >= _questions.length - 1) {
      final String? key = widget.scoreKey;
      final bool isNewBest =
          key != null && _progress.saveScore(key, _score, _questions.length);
      setState(() {
        _finished = true;
        _isNewBest = isNewBest;
      });
      return;
    }
    setState(() {
      _currentIndex++;
      _resetQuestionState();
    });
    _speakCurrent();
    if (widget.mode == QuizMode.typing) {
      _typingFocus.requestFocus();
    }
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
              return MessageView(
                icon: Icons.inbox_rounded,
                message: widget.emptyMessage,
              );
            }

            if (_finished) {
              final String? key = widget.scoreKey;
              return _ResultView(
                score: _score,
                total: _questions.length,
                best: key == null ? null : _progress.bestScore(key),
                isNewBest: _isNewBest,
                missed: _missed,
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
    final QuizQuestion question = _current;

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
          if (widget.mode == QuizMode.typing)
            Expanded(child: _buildTyping(context, question))
          else ...[
            _buildPrompt(question),
            const SizedBox(height: 16),
            Expanded(child: _buildOptions(question)),
          ],
        ],
      ),
    );
  }

  Widget _buildPrompt(QuizQuestion question) {
    return switch (widget.mode) {
      QuizMode.listen => _ListenPrompt(
          word: question.answer,
          solved: _solved,
          onListen: _speakCurrent,
        ),
      QuizMode.definition => _DefinitionPrompt(
          definition: question.answer.definition ?? '',
          onListen: _speakCurrent,
        ),
      _ => _Prompt(word: question.answer, onListen: _speakCurrent),
    };
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
      // Tanım türünde resim yerine kelime yazılır.
      showText: widget.mode == QuizMode.definition,
      onTap: () => _onOptionTap(option),
    );
  }

  /// Yazma türü: resim, Türkçesi, harf ipucu, yazma alanı ve kontrol butonu.
  Widget _buildTyping(BuildContext context, QuizQuestion question) {
    final ThemeData theme = Theme.of(context);
    final Word answer = question.answer;
    final Color color = colorFor(answer.english);
    final bool solvedCorrectly = _solved && !_revealed;

    final String feedback;
    final Color feedbackColor;
    if (solvedCorrectly) {
      feedback = 'Great job!';
      feedbackColor = _OptionCard.correctColor;
    } else if (_revealed) {
      feedback = 'The answer is: ${answer.english}';
      feedbackColor = _OptionCard.wrongColor;
    } else if (_typingMistakes > 0) {
      feedback = 'Try again!';
      feedbackColor = _OptionCard.wrongColor;
    } else {
      feedback = '';
      feedbackColor = theme.colorScheme.onSurface;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: solvedCorrectly ? _OptionCard.correctColor : color,
                width: solvedCorrectly ? 8 : 4,
              ),
            ),
            padding: const EdgeInsets.all(12),
            child: WordPicture(word: answer, color: color),
          ),
        ),
        const SizedBox(height: 12),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            answer.turkish,
            style: theme.textTheme.headlineMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(height: 4),
        // Harf sayısı ipucu: "cat" -> "_ _ _".
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            answer.english
                .split('')
                .map((String c) => c == ' ' ? ' ' : '_')
                .join(' '),
            style: theme.textTheme.headlineMedium?.copyWith(
              letterSpacing: 2,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _typingController,
          focusNode: _typingFocus,
          autofocus: true,
          readOnly: _solved,
          autocorrect: false,
          enableSuggestions: false,
          textAlign: TextAlign.center,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _checkTyped(),
          style: theme.textTheme.headlineMedium,
          decoration: InputDecoration(
            hintText: 'Type here',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(24),
            ),
          ),
        ),
        SizedBox(
          height: 48,
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                feedback,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: feedbackColor,
                ),
              ),
            ),
          ),
        ),
        Row(
          children: [
            Tooltip(
              message: 'Dinle',
              child: SizedBox(
                width: 96,
                height: 72,
                child: OutlinedButton(
                  onPressed: () =>
                      TtsService.instance.speak(answer.english),
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  child: const Icon(Icons.volume_up_rounded, size: 44),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: FilledButton.icon(
                onPressed: _revealed
                    ? _goToNextQuestion
                    : (_solved ? null : _checkTyped),
                icon: Icon(
                  _revealed
                      ? Icons.arrow_forward_rounded
                      : Icons.check_rounded,
                  size: 36,
                ),
                label: Text(_revealed ? 'Next' : 'Check'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(72),
                  textStyle: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Büyük, yuvarlak köşeli "Dinle" butonu.
class _ListenButton extends StatelessWidget {
  const _ListenButton({required this.onPressed, this.width = 96});

  final VoidCallback onPressed;
  final double width;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Dinle',
      child: SizedBox(
        width: width,
        height: 72,
        child: FilledButton(
          onPressed: onPressed,
          style: FilledButton.styleFrom(
            padding: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
          ),
          child: const Icon(Icons.volume_up_rounded, size: 44),
        ),
      ),
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
        _ListenButton(onPressed: onListen),
      ],
    );
  }
}

/// "Dinle ve seç" türünün sorusu: kelime yazmaz, sadece büyük dinle butonu.
/// Doğru cevap bulununca kelime gösterilir.
class _ListenPrompt extends StatelessWidget {
  const _ListenPrompt({
    required this.word,
    required this.solved,
    required this.onListen,
  });

  final Word word;
  final bool solved;
  final VoidCallback onListen;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return SizedBox(
      height: 72,
      child: Row(
        children: [
          _ListenButton(onPressed: onListen, width: 120),
          const SizedBox(width: 16),
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                solved ? word.english : 'Listen and tap!',
                style: solved
                    ? theme.textTheme.displayLarge?.copyWith(
                        fontSize: 56,
                        color: theme.colorScheme.onSurface,
                      )
                    : theme.textTheme.headlineMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// "Tanımdan bul" türünün sorusu: tanım kartı ve dinle butonu.
class _DefinitionPrompt extends StatelessWidget {
  const _DefinitionPrompt({required this.definition, required this.onListen});

  final String definition;
  final VoidCallback onListen;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(28),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: Text(
              definition,
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineMedium?.copyWith(
                fontSize: 28,
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
          ),
          const SizedBox(width: 16),
          _ListenButton(onPressed: onListen),
        ],
      ),
    );
  }
}

enum _OptionState { normal, wrong, correct, faded }

/// Tek bir şık. Duruma göre çerçeve rengi, saydamlık ve simge değişir.
/// [showText] true ise resim yerine İngilizce kelime yazılır.
class _OptionCard extends StatelessWidget {
  const _OptionCard({
    super.key,
    required this.word,
    required this.state,
    required this.onTap,
    this.showText = false,
  });

  static const Color correctColor = Color(0xFF43A047);

  /// Yanlış şık rengi. Tema turuncu-kırmızı olduğu için kırmızı yerine
  /// gri-mavi kullanılır; böylece normal kartlardan kolayca ayrılır.
  static const Color wrongColor = Color(0xFF546E7A);

  final Word word;
  final _OptionState state;
  final VoidCallback onTap;
  final bool showText;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color baseColor = colorFor(word.english);
    final Color borderColor = switch (state) {
      _OptionState.correct => correctColor,
      _OptionState.wrong => wrongColor,
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
                color: state == _OptionState.wrong
                    ? wrongColor.withValues(alpha: 0.25)
                    : baseColor.withValues(alpha: 0.18),
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
                    child: showText
                        ? Center(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                word.english,
                                style: theme.textTheme.displayLarge?.copyWith(
                                  fontSize: 44,
                                  color: theme.colorScheme.onSurface,
                                ),
                              ),
                            ),
                          )
                        : WordPicture(word: word, color: baseColor),
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
    required this.best,
    required this.isNewBest,
    required this.missed,
    required this.onPlayAgain,
    required this.onHome,
  });

  final int score;
  final int total;
  final QuizScore? best;
  final bool isNewBest;
  final int missed;
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
    final QuizScore? best = this.best;

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
            if (isNewBest) ...[
              const SizedBox(height: 8),
              Text(
                '🏆 New record!',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
            ] else if (best != null) ...[
              const SizedBox(height: 8),
              Text(
                'Best: ${best.score} / ${best.total}',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            if (missed > 0) ...[
              const SizedBox(height: 8),
              Text(
                '🔁 $missed ${missed == 1 ? 'word' : 'words'} added to Review',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
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
