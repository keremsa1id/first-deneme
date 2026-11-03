import 'package:flutter/material.dart';

import '../widgets/card_colors.dart';

/// Kelime grubu. [id], words.json'daki "category" alanıyla eşleşir.
class WordCategory {
  const WordCategory({
    required this.id,
    required this.name,
    required this.emoji,
    required this.color,
  });

  final String id;

  /// Ekranda gösterilen Türkçe ad.
  final String name;
  final String emoji;
  final Color color;

  /// [id] için tanımlı grubu döner. Tanımsız bir kategori gelirse
  /// (ör. JSON'a yeni grup eklenip burası güncellenmediyse) id'yi
  /// ad olarak kullanan genel bir grup üretir.
  static WordCategory byId(String id) {
    for (final WordCategory category in wordCategories) {
      if (category.id == id) {
        return category;
      }
    }
    return WordCategory(id: id, name: id, emoji: '📚', color: colorFor(id));
  }
}

/// Grupların ekrandaki sırası. Kolaydan zora, günlük hayattan başlayarak.
const List<WordCategory> wordCategories = <WordCategory>[
  WordCategory(
    id: 'animals',
    name: 'Hayvanlar',
    emoji: '🐾',
    color: Color(0xFF81C784),
  ),
  WordCategory(
    id: 'colors',
    name: 'Renkler',
    emoji: '🎨',
    color: Color(0xFFF06292),
  ),
  WordCategory(
    id: 'numbers',
    name: 'Sayılar',
    emoji: '🔢',
    color: Color(0xFF4FC3F7),
  ),
  WordCategory(
    id: 'fruits',
    name: 'Meyveler',
    emoji: '🍎',
    color: Color(0xFFFF8A65),
  ),
  WordCategory(
    id: 'food',
    name: 'Yiyecekler',
    emoji: '🍞',
    color: Color(0xFFFFB74D),
  ),
  WordCategory(
    id: 'family',
    name: 'Ailem',
    emoji: '👨‍👩‍👧',
    color: Color(0xFFBA68C8),
  ),
  WordCategory(
    id: 'body',
    name: 'Vücudumuz',
    emoji: '✋',
    color: Color(0xFFF48FB1),
  ),
  WordCategory(
    id: 'clothes',
    name: 'Kıyafetler',
    emoji: '👕',
    color: Color(0xFF7986CB),
  ),
  WordCategory(
    id: 'toys',
    name: 'Oyuncaklar',
    emoji: '🧸',
    color: Color(0xFFFFD54F),
  ),
  WordCategory(
    id: 'home',
    name: 'Evimiz',
    emoji: '🏠',
    color: Color(0xFFA1887F),
  ),
  WordCategory(
    id: 'kitchen',
    name: 'Mutfak',
    emoji: '🍽️',
    color: Color(0xFFFF8A65),
  ),
  WordCategory(
    id: 'bathroom',
    name: 'Banyo',
    emoji: '🛁',
    color: Color(0xFF4DD0E1),
  ),
  WordCategory(
    id: 'school',
    name: 'Okul',
    emoji: '🎒',
    color: Color(0xFF4DB6AC),
  ),
  WordCategory(
    id: 'vehicles',
    name: 'Taşıtlar',
    emoji: '🚗',
    color: Color(0xFFE57373),
  ),
  WordCategory(
    id: 'nature',
    name: 'Doğa',
    emoji: '🌳',
    color: Color(0xFF9CCC65),
  ),
];
