import 'package:flutter/material.dart';

import '../models/word.dart';
import '../services/tts_service.dart';
import '../services/word_repository.dart';

/// Kelimeleri tek tek büyük kartlar halinde gösteren ekran.
///
/// Kaydırma yönü: Parmağı SAĞA doğru kaydırınca SONRAKİ kelime gelir.
/// Varsayılan PageView'da sonraki sayfa parmağı sola kaydırınca gelir; bu
/// yüzden PageView `reverse: true` ile kullanılıyor. Böylece sonraki kart
/// soldan içeri girer ve sağa doğru kaydırma hareketi bir sonraki kelimeyi
/// açar. Son kelimede durulur ve "Başa dön" butonu gösterilir.
class WordCardScreen extends StatefulWidget {
  const WordCardScreen({
    super.key,
    this.repository = const WordRepository(),
  });

  final WordRepository repository;

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
    _wordsFuture = widget.repository.loadWords();
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
      _wordsFuture = widget.repository.loadWords();
    });
  }

  void _goToFirst() {
    _pageController.animateToPage(
      0,
      duration: const Duration(milliseconds: 500),
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
          'Kelimeler',
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
              return _MessageView(
                icon: Icons.sentiment_dissatisfied_rounded,
                message: message,
                buttonLabel: 'Tekrar dene',
                onPressed: _retry,
              );
            }

            final List<Word> words = snapshot.data ?? const <Word>[];
            if (words.isEmpty) {
              return const _MessageView(
                icon: Icons.inbox_rounded,
                message: 'Henüz kelime yok.',
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
    final bool isLast = _currentIndex >= words.length - 1;

    return Column(
      children: [
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            // Sağa kaydırınca sonraki kelime gelsin diye ters çevrildi.
            reverse: true,
            itemCount: words.length,
            onPageChanged: (int index) {
              setState(() => _currentIndex = index);
            },
            itemBuilder: (BuildContext context, int index) {
              return Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                child: _WordCard(word: words[index]),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: SizedBox(
            height: 72,
            child: isLast && words.length > 1
                ? FilledButton.icon(
                    onPressed: _goToFirst,
                    icon: const Icon(Icons.replay_rounded, size: 36),
                    label: const Text('Başa dön'),
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
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '${_currentIndex + 1} / ${words.length}',
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      if (words.length > 1) ...[
                        const SizedBox(width: 16),
                        Icon(
                          Icons.swipe_right_rounded,
                          size: 40,
                          color: theme.colorScheme.primary,
                        ),
                      ],
                    ],
                  ),
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
    final Color color = _colorFor(word.english);

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
            Expanded(child: _WordPicture(word: word, color: color)),
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
            // TODO: Kelimeyi sesli okumak için buraya büyük bir ses butonu
            // eklenecek (flutter_tts, sonraki adım).
          ],
        ),
      ),
    );
  }
}

/// Kelimenin görseli. Sırasıyla: imagePath, emoji, renkli baş harf.
class _WordPicture extends StatelessWidget {
  const _WordPicture({required this.word, required this.color});

  final Word word;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final Widget fallback = _buildFallback();

    if (word.imagePath.trim().isEmpty) {
      return fallback;
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Image.asset(
        word.imagePath,
        fit: BoxFit.contain,
        // Görsel dosyası henüz eklenmediyse emoji/baş harf gösterilir.
        errorBuilder: (BuildContext context, Object error, StackTrace? _) =>
            fallback,
      ),
    );
  }

  Widget _buildFallback() {
    final String? emoji = word.emoji;
    if (emoji != null) {
      return Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(emoji, style: const TextStyle(fontSize: 160)),
        ),
      );
    }

    final String letter =
        word.english.isEmpty ? '?' : word.english[0].toUpperCase();
    return Center(
      child: AspectRatio(
        aspectRatio: 1,
        child: Container(
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(40),
          ),
          alignment: Alignment.center,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                letter,
                style: const TextStyle(
                  fontSize: 160,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Kartlar için canlı ama yorucu olmayan renkler.
const List<Color> _cardColors = <Color>[
  Color(0xFFFF8A65), // turuncu
  Color(0xFF4FC3F7), // mavi
  Color(0xFF81C784), // yeşil
  Color(0xFFBA68C8), // mor
  Color(0xFFFFB74D), // sarı-turuncu
  Color(0xFFF06292), // pembe
  Color(0xFF4DB6AC), // turkuaz
];

/// Aynı kelime her zaman aynı rengi alsın diye harf kodlarından renk seçer.
Color _colorFor(String text) {
  int sum = 0;
  for (final int unit in text.codeUnits) {
    sum += unit;
  }
  return _cardColors[sum % _cardColors.length];
}

/// Yükleme hatası veya boş liste durumunda gösterilen sade mesaj.
class _MessageView extends StatelessWidget {
  const _MessageView({
    required this.icon,
    required this.message,
    this.buttonLabel,
    this.onPressed,
  });

  final IconData icon;
  final String message;
  final String? buttonLabel;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String? label = buttonLabel;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(icon, size: 120, color: theme.colorScheme.primary),
            const SizedBox(height: 24),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineMedium,
            ),
            if (label != null && onPressed != null) ...[
              const SizedBox(height: 32),
              FilledButton.icon(
                onPressed: onPressed,
                icon: const Icon(Icons.refresh_rounded, size: 36),
                label: Text(label),
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
            ],
          ],
        ),
      ),
    );
  }
}
