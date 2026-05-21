import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/providers.dart';
import 'features/bookmarks/bookmarks_page.dart';
import 'features/home/home_page.dart';
import 'features/tam_kamatoi/tam_kamatoi_page.dart';
import 'features/topics/topics_page.dart';

class KhokharumLaaApp extends ConsumerWidget {
  const KhokharumLaaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bootstrap = ref.watch(appBootstrapProvider);

    return MaterialApp(
      title: 'Kamatei Lii',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1D5C49),
          primary: const Color(0xFF1D5C49),
          secondary: const Color(0xFFB7893C),
          surface: const Color(0xFFF7F1E3),
        ),
        scaffoldBackgroundColor: const Color(0xFFF6F0E2),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFF6F0E2),
          foregroundColor: Color(0xFF18352D),
          elevation: 0,
          centerTitle: false,
        ),
        cardTheme: CardThemeData(
          color: const Color(0xFFFFFCF5),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: const BorderSide(color: Color(0xFFE4D9C1)),
          ),
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: const Color(0xFFFFFCF5),
          indicatorColor: const Color(0xFFDFEBDD),
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            final selected = states.contains(WidgetState.selected);
            return TextStyle(
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected
                  ? const Color(0xFF18352D)
                  : const Color(0xFF52615A),
            );
          }),
        ),
        searchBarTheme: SearchBarThemeData(
          backgroundColor: const WidgetStatePropertyAll(Color(0xFFFFFCF5)),
          elevation: const WidgetStatePropertyAll(0),
          side: const WidgetStatePropertyAll(
            BorderSide(color: Color(0xFFE4D9C1)),
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          ),
          hintStyle: const WidgetStatePropertyAll(
            TextStyle(color: Color(0xFF7A7A6A)),
          ),
        ),
        chipTheme: ChipThemeData(
          backgroundColor: const Color(0xFFE9E0C8),
          selectedColor: const Color(0xFFD8E5D6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
        ),
        useMaterial3: true,
      ),
      home: bootstrap.when(
        data: (_) => const AppShell(),
        loading: () => const _LoadingScreen(),
        error: (error, _) => _ErrorScreen(message: error.toString()),
      ),
    );
  }
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  static const _pages = [
    HomePage(),
    BookmarksPage(),
    TopicsPage(),
    TamKamatoiPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.bookmark_outline),
            selectedIcon: Icon(Icons.bookmark),
            label: 'Bookmarks',
          ),
          NavigationDestination(
            icon: Icon(Icons.topic_outlined),
            selectedIcon: Icon(Icons.topic),
            label: 'Topics',
          ),
          NavigationDestination(
            icon: Icon(Icons.menu_book_outlined),
            selectedIcon: Icon(Icons.menu_book),
            label: 'Tam Kamatoi',
          ),
        ],
        onDestinationSelected: (value) => setState(() => _index = value),
      ),
    );
  }
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}

class _ErrorScreen extends StatelessWidget {
  const _ErrorScreen({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Failed to initialize database:\n$message',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
