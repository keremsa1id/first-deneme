import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart' show rootBundle;

import '../models/word.dart';

/// Kelime verisi okunamadığında veya bozuk olduğunda fırlatılır.
class WordRepositoryException implements Exception {
  const WordRepositoryException(this.message, [this.cause]);

  /// Kullanıcıya gösterilebilecek kısa açıklama.
  final String message;

  /// Asıl hata (hata ayıklama için).
  final Object? cause;

  @override
  String toString() => 'WordRepositoryException: $message'
      '${cause == null ? '' : ' ($cause)'}';
}

/// Kelimeleri assets/data/ altındaki JSON dosyasından okur.
class WordRepository {
  const WordRepository({this.assetPath = defaultAssetPath});

  static const String defaultAssetPath = 'assets/data/words.json';

  final String assetPath;

  /// [assetPath] dosyasındaki kelimeleri yükler. [category] verilirse
  /// yalnızca o gruptaki kelimeler, [only] verilirse yalnızca İngilizcesi
  /// (küçük harfle) bu kümede olan kelimeler döner.
  ///
  /// Dosya boşsa veya boş bir liste içeriyorsa boş liste döner.
  /// Dosya bulunamazsa ya da JSON biçimi hatalıysa
  /// [WordRepositoryException] fırlatır.
  Future<List<Word>> loadWords({String? category, Set<String>? only}) async {
    final List<Word> words = await _loadAll();
    if (category == null && only == null) {
      return words;
    }
    return List<Word>.unmodifiable(
      words.where(
        (Word word) =>
            (category == null || word.category == category) &&
            (only == null || only.contains(word.english.toLowerCase())),
      ),
    );
  }

  Future<List<Word>> _loadAll() async {
    final String raw;
    try {
      raw = await rootBundle.loadString(assetPath);
    } catch (error) {
      throw WordRepositoryException('Kelime dosyası açılamadı.', error);
    }

    if (raw.trim().isEmpty) {
      return const <Word>[];
    }

    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException catch (error) {
      throw WordRepositoryException('Kelime dosyası okunamadı.', error);
    }

    if (decoded is! List) {
      throw const WordRepositoryException(
        'Kelime dosyası bir liste içermeli.',
      );
    }

    final List<Word> words = <Word>[];
    for (int i = 0; i < decoded.length; i++) {
      final Object? item = decoded[i];
      if (item is! Map<String, dynamic>) {
        throw WordRepositoryException(
          'Kelime dosyasındaki ${i + 1}. kayıt hatalı.',
        );
      }
      try {
        words.add(Word.fromJson(item));
      } on FormatException catch (error) {
        throw WordRepositoryException(
          'Kelime dosyasındaki ${i + 1}. kayıt hatalı.',
          error,
        );
      }
    }
    return List<Word>.unmodifiable(words);
  }

  /// [loadWords] gibi yükler ama kelimeleri rastgele sıraya dizer;
  /// böylece ekran her açılışta farklı bir kelimeyle başlar.
  Future<List<Word>> loadShuffledWords({
    String? category,
    Set<String>? only,
    Random? random,
  }) async {
    final List<Word> words =
        List<Word>.of(await loadWords(category: category, only: only))
          ..shuffle(random);
    return List<Word>.unmodifiable(words);
  }
}
