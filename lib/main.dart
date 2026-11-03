import 'package:flutter/material.dart';

import 'screens/sentence_screen.dart';
import 'screens/word_card_screen.dart';

void main() {
  runApp(const KelimeApp());
}

class KelimeApp extends StatelessWidget {
  const KelimeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Kelime Oyunu',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.orange,
        textTheme: const TextTheme(
          displayLarge: TextStyle(fontSize: 48, fontWeight: FontWeight.bold),
          headlineLarge: TextStyle(fontSize: 40, fontWeight: FontWeight.bold),
          headlineMedium: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
          titleLarge: TextStyle(fontSize: 26, fontWeight: FontWeight.w600),
          bodyLarge: TextStyle(fontSize: 22),
          bodyMedium: TextStyle(fontSize: 20),
          labelLarge: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
      ),
      home: const HomeScreen(),
    );
  }
}

/// Geçici ana ekran. Asıl ekranlar lib/screens/ altına eklenecek.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  void _showComingSoon(BuildContext context) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Yakında', style: TextStyle(fontSize: 20)),
          duration: Duration(seconds: 2),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Kelime Oyunu',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.displayLarge?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 48),
                _MenuButton(
                  label: 'Kelimeler',
                  icon: Icons.abc,
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (BuildContext context) =>
                          const WordCardScreen(),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                _MenuButton(
                  label: 'Cümleler',
                  icon: Icons.chat_bubble,
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (BuildContext context) =>
                          const SentenceScreen(),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                _MenuButton(
                  label: 'Quiz',
                  icon: Icons.star,
                  onPressed: () => _showComingSoon(context),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MenuButton extends StatelessWidget {
  const _MenuButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 36),
      label: Text(label),
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(80),
        textStyle: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
      ),
    );
  }
}
