import 'package:flutter/material.dart';

/// Kartlar için canlı ama yorucu olmayan renkler.
const List<Color> cardColors = <Color>[
  Color(0xFFFF8A65), // turuncu
  Color(0xFF4FC3F7), // mavi
  Color(0xFF81C784), // yeşil
  Color(0xFFBA68C8), // mor
  Color(0xFFFFB74D), // sarı-turuncu
  Color(0xFFF06292), // pembe
  Color(0xFF4DB6AC), // turkuaz
];

/// Aynı kelime her zaman aynı rengi alsın diye harf kodlarından renk seçer.
Color colorFor(String text) {
  int sum = 0;
  for (final int unit in text.codeUnits) {
    sum += unit;
  }
  return cardColors[sum % cardColors.length];
}
