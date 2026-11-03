import 'package:flutter/material.dart';

/// Quiz türleri.
enum QuizMode {
  /// Kelime yazılır ve okunur, doğru resim seçilir.
  picture(
    title: 'Picture Quiz',
    description: 'Read and listen, then tap the picture.',
    icon: Icons.image_rounded,
  ),

  /// Kelime sadece sesli okunur, ekranda yazmaz. Kulak alıştırması.
  listen(
    title: 'Listen & Choose',
    description: 'Only listen, then tap the picture.',
    icon: Icons.hearing_rounded,
  ),

  /// İngilizce tanım gösterilir, doğru kelime seçilir.
  definition(
    title: 'Find from Definition',
    description: 'Read the meaning, then tap the word.',
    icon: Icons.menu_book_rounded,
  ),

  /// Şık yok; resme bakıp kelime yazılır. Yazımı öğretir.
  typing(
    title: 'Type the Word',
    description: 'Look at the picture and write the word.',
    icon: Icons.keyboard_rounded,
  );

  const QuizMode({
    required this.title,
    required this.description,
    required this.icon,
  });

  final String title;
  final String description;
  final IconData icon;
}
