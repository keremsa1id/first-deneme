import 'package:flutter/material.dart';

import '../models/word.dart';

/// Kelimenin görseli. Sırasıyla: imagePath, emoji, renkli baş harf.
class WordPicture extends StatelessWidget {
  const WordPicture({super.key, required this.word, required this.color});

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
