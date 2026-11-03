import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';

import '../models/word.dart';
import '../services/progress_store.dart';
import '../services/tts_service.dart';
import '../services/word_repository.dart';
import '../widgets/card_colors.dart';
import '../widgets/message_view.dart';
import '../widgets/nav_button.dart';
import '../widgets/word_picture.dart';

/// Kelimeleri tek tek büyük kartlar halinde gösteren ekran.
///
/// Kaydırma yönü: Parmağı SOLA doğru kaydırınca SONRAKİ kelime gelir;
/// eski kart sola çıkar, yenisi sağdan girer (PageView'ın varsayılanı).
/// Alttaki ileri/geri butonlarıyla da geçilebilir. Son kelimede
/// durulur ve ileri butonu yerine "Başa dön" butonu gösterilir.
/// [category] verilirse yalnızca o gruptaki kelimeler gösterilir.
class WordCardScreen extends StatefulWidget {
  const WordCardScreen({
    super.key,
    this.repository = const WordRepository(),
    this.category,
    this.onlyWords,
    this.title = 'Words',
    this.emptyMessage = 'Henüz kelime yok.',
  });

  final WordRepository repository;
  final String? category;

  /// Verilirse yalnızca İngilizcesi (küçük harfle) bu kümede olan
  /// kelimeler gösterilir (ör. favoriler).
  final Set<String>? onlyWords;
  final String title;
  final String emptyMessage;

  @override
  State<WordCardScreen> createState() => _WordCardScreenState();
}

class _WordCardScreenState extends State<WordCardScreen> {
  final PageController _pageController = PageController();
  late Future<List<Word>> _wordsFuture;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _wordsFuture = _loadWords();
  }

  /// Kelimeleri yükler; ilk kart görüldüğü için günlük hedefe sayılır.
  Future<List<Word>> _loadWords() async {
    final List<Word> words = await widget.repository.loadShuffledWords(
      category: widget.category,
      only: widget.onlyWords,
    );
    if (words.isNotEmpty) {
      ProgressStore.instance.markStudied(words.first);
    }
    return words;
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
      _wordsFuture = _loadWords();
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
                  : 'Kelimeler yüklenemedi.';
              return MessageView(
                icon: Icons.sentiment_dissatisfied_rounded,
                message: message,
                buttonLabel: 'Tekrar dene',
                onPressed: _retry,
              );
            }

            final List<Word> words = snapshot.data ?? const <Word>[];
            if (words.isEmpty) {
              return MessageView(
                icon: Icons.inbox_rounded,
                message: widget.emptyMessage,
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
                ProgressStore.instance.markStudied(words[index]);
              },
              itemBuilder: (BuildContext context, int index) {
                return Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                  child: _WordCard(word: words[index]),
                );
              },
            ),
          ),
        ),
        // Alt çubuk: geri, sayaç, ileri. Son kelimede ileri yerine başa dön.
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

/// Tek bir kelimenin kartı: üstte görsel, altında İngilizcesi ve Türkçesi.
class _WordCard extends StatelessWidget {
  const _WordCard({required this.word});

  final Word word;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color color = colorFor(word.english);

    // Karta dokununca İngilizce kelime sesli okunur.
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => TtsService.instance.speak(word.english),
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
              child: Stack(
                children: [
                  Positioned.fill(
                    child: WordPicture(word: word, color: color),
                  ),
                  Positioned(
                    top: 0,
                    right: 0,
                    child: FavoriteButton(word: word),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            FittedBox(
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
            const SizedBox(height: 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                word.turkish,
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Kelimeyi favorilere ekleyen/çıkaran yıldız butonu.
class FavoriteButton extends StatelessWidget {
  const FavoriteButton({super.key, required this.word});

  final Word word;

  @override
  Widget build(BuildContext context) {
    final ProgressStore progress = ProgressStore.instance;

    return ListenableBuilder(
      listenable: progress,
      builder: (BuildContext context, Widget? _) {
        final bool isFavorite = progress.isFavorite(word);
        return IconButton(
          iconSize: 56,
          tooltip: isFavorite ? 'Remove from favorites' : 'Add to favorites',
          onPressed: () => progress.toggleFavorite(word),
          icon: Icon(
            isFavorite ? Icons.star_rounded : Icons.star_border_rounded,
            color: const Color(0xFFFFC107),
          ),
        );
      },
    );
  }
}
