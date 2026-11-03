import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';

import '../models/word.dart';
import '../services/tts_service.dart';
import '../services/word_repository.dart';
import '../widgets/card_colors.dart';
import '../widgets/message_view.dart';
import '../widgets/nav_button.dart';
import '../widgets/word_picture.dart';

/// Kelimelerin örnek cümlelerini tek tek büyük kartlar halinde gösteren ekran.
///
/// Gezinme [WordCardScreen] ile aynıdır: parmağı SOLA kaydırınca SONRAKİ
/// cümle gelir (eski kart sola çıkar), alttaki butonlarla da geçilebilir.
/// Cümlede öğrenilen kelime renkli ve kalın gösterilir.
class SentenceScreen extends StatefulWidget {
  const SentenceScreen({
    super.key,
    this.repository = const WordRepository(),
  });

  final WordRepository repository;

  @override
  State<SentenceScreen> createState() => _SentenceScreenState();
}

class _SentenceScreenState extends State<SentenceScreen> {
  final PageController _pageController = PageController();
  late Future<List<Word>> _wordsFuture;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _wordsFuture = widget.repository.loadShuffledWords();
  }

  @override
  void dispose() {
    _pageController.dispose();
    TtsService.instance.stop();
    super.dispose();
  }

  void _retry() {
    setState(() {
      _currentIndex = 0;
      _wordsFuture = widget.repository.loadShuffledWords();
    });
  }

  void _goToFirst() {
    _pageController.animateToPage(
      0,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
    );
  }

  void _goToNext() {
    _pageController.nextPage(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
    );
  }

  void _goToPrevious() {
    _pageController.previousPage(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
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
          'Cümleler',
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
                  : 'Cümleler yüklenemedi.';
              return MessageView(
                icon: Icons.sentiment_dissatisfied_rounded,
                message: message,
                buttonLabel: 'Tekrar dene',
                onPressed: _retry,
              );
            }

            final List<Word> words = snapshot.data ?? const <Word>[];
            if (words.isEmpty) {
              return const MessageView(
                icon: Icons.inbox_rounded,
                message: 'Henüz cümle yok.',
              );
            }

            return _buildCards(context, words);
          },
        ),
      ),
    );
  }

  Widget _buildCards(BuildContext context, List<Word> words) {
    final ThemeData theme = Theme.of(context);
    final bool isFirst = _currentIndex == 0;
    final bool isLast = _currentIndex >= words.length - 1;

    return Column(
      children: [
        Expanded(
          // Web'de fareyle sürükleyerek de kart geçilebilsin.
          child: ScrollConfiguration(
            behavior: ScrollConfiguration.of(context).copyWith(
              dragDevices: <PointerDeviceKind>{
                PointerDeviceKind.touch,
                PointerDeviceKind.mouse,
                PointerDeviceKind.stylus,
                PointerDeviceKind.trackpad,
              },
            ),
            child: PageView.builder(
              controller: _pageController,
              itemCount: words.length,
              onPageChanged: (int index) {
                setState(() => _currentIndex = index);
              },
              itemBuilder: (BuildContext context, int index) {
                return Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                  child: _SentenceCard(word: words[index]),
                );
              },
            ),
          ),
        ),
        // Alt çubuk: geri, sayaç, ileri. Son cümlede ileri yerine başa dön.
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Row(
            children: [
              NavButton(
                icon: Icons.arrow_back_rounded,
                tooltip: 'Önceki',
                onPressed: isFirst ? null : _goToPrevious,
              ),
              Expanded(
                child: Text(
                  '${_currentIndex + 1} / ${words.length}',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              if (isLast)
                NavButton(
                  icon: Icons.replay_rounded,
                  tooltip: 'Başa dön',
                  onPressed: words.length > 1 ? _goToFirst : null,
                )
              else
                NavButton(
                  icon: Icons.arrow_forward_rounded,
                  tooltip: 'Sonraki',
                  onPressed: _goToNext,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Tek bir cümlenin kartı: üstte küçük görsel, ortada cümle,
/// altında kelimenin anlamı ve ses butonu.
class _SentenceCard extends StatelessWidget {
  const _SentenceCard({required this.word});

  final Word word;

  void _speak() => TtsService.instance.speak(word.exampleSentence);

  /// Cümleyi, öğrenilen kelime [highlightStyle] ile vurgulanmış olarak yazar.
  Widget _buildSentence(TextStyle baseStyle, TextStyle highlightStyle) {
    return Text.rich(
      TextSpan(
        children: <TextSpan>[
          for (final SentencePart part
              in splitSentence(word.exampleSentence, word.english))
            TextSpan(
              text: part.text,
              style: part.isHighlighted ? highlightStyle : baseStyle,
            ),
        ],
      ),
      textAlign: TextAlign.center,
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color color = colorFor(word.english);
    final TextStyle baseStyle = theme.textTheme.headlineLarge!.copyWith(
      fontSize: 36,
      fontWeight: FontWeight.w600,
      height: 1.3,
      color: theme.colorScheme.onSurface,
    );
    final TextStyle highlightStyle = baseStyle.copyWith(
      fontWeight: FontWeight.w900,
      color: Color.lerp(color, Colors.black, 0.25),
    );

    // Karta dokununca cümlenin tamamı sesli okunur.
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _speak,
      child: Container(
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: color, width: 4),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Expanded(
              flex: 2,
              child: WordPicture(word: word, color: color),
            ),
            const SizedBox(height: 16),
            Expanded(
              flex: 3,
              // Cümle kart genişliğinde satırlara sarılır; yüksekliğe
              // sığmazsa bütün olarak küçültülür.
              child: LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  return Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: ConstrainedBox(
                        constraints:
                            BoxConstraints(maxWidth: constraints.maxWidth),
                        child: _buildSentence(baseStyle, highlightStyle),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                '${word.english} = ${word.turkish}',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Tooltip(
              message: 'Dinle',
              child: SizedBox(
                width: 120,
                height: 72,
                child: FilledButton(
                  onPressed: _speak,
                  style: FilledButton.styleFrom(
                    backgroundColor: color,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  child: const Icon(Icons.volume_up_rounded, size: 48),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Cümlenin bir parçası. [isHighlighted] true ise öğrenilen kelimedir.
class SentencePart {
  const SentencePart(this.text, {this.isHighlighted = false});

  final String text;
  final bool isHighlighted;

  @override
  bool operator ==(Object other) =>
      other is SentencePart &&
      other.text == text &&
      other.isHighlighted == isHighlighted;

  @override
  int get hashCode => Object.hash(text, isHighlighted);

  @override
  String toString() => 'SentencePart("$text", $isHighlighted)';
}

/// [sentence] içinde [word] kelimesinin geçtiği yerleri ayırır.
///
/// Büyük/küçük harfe bakılmaz ve yalnızca tam kelime eşleşir
/// ("cat" kelimesi "catch" içinde vurgulanmaz). Kelime bulunamazsa
/// cümlenin tamamı tek, vurgusuz parça olarak döner.
List<SentencePart> splitSentence(String sentence, String word) {
  final String target = word.trim();
  if (target.isEmpty) {
    return <SentencePart>[SentencePart(sentence)];
  }

  final RegExp pattern = RegExp(
    '\\b${RegExp.escape(target)}\\b',
    caseSensitive: false,
  );
  final List<SentencePart> parts = <SentencePart>[];
  int start = 0;
  for (final RegExpMatch match in pattern.allMatches(sentence)) {
    if (match.start > start) {
      parts.add(SentencePart(sentence.substring(start, match.start)));
    }
    parts.add(SentencePart(match[0]!, isHighlighted: true));
    start = match.end;
  }
  if (start < sentence.length) {
    parts.add(SentencePart(sentence.substring(start)));
  }
  return parts.isEmpty ? <SentencePart>[SentencePart(sentence)] : parts;
}
