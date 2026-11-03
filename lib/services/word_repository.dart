import 'dart:convert';

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

  /// [assetPath] dosyasındaki kelimeleri yükler.
  ///
  /// Dosya boşsa veya boş bir liste içeriyorsa boş liste döner.
  /// Dosya bulunamazsa ya da JSON biçimi hatalıysa
  /// [WordRepositoryException] fırlatır.
  Future<List<Word>> loadWords() async {
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
}
