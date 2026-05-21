import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import 'tam_song.dart';

class TamKamatoiPage extends ConsumerWidget {
  const TamKamatoiPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final songsAsync = ref.watch(tamSongsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Tam Kamatoi Lii')),
      body: songsAsync.when(
        data: (songs) {
          if (songs.isEmpty) {
            return const Center(child: Text('No songs found'));
          }
          return ListView.separated(
            itemCount: songs.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final song = songs[index];
              return ListTile(
                title: Text(
                  song.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                subtitle: Text('TL ${song.number}'),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => TamSongDetailPage(song: song),
                    ),
                  );
                },
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const Center(child: Text('Unable to load songs')),
      ),
    );
  }
}

class TamSongDetailPage extends ConsumerStatefulWidget {
  const TamSongDetailPage({required this.song, super.key});

  final TamSong song;

  @override
  ConsumerState<TamSongDetailPage> createState() => _TamSongDetailPageState();
}

class _TamSongDetailPageState extends ConsumerState<TamSongDetailPage> {
  late TamSong _song;
  bool _isNavigating = false;

  @override
  void initState() {
    super.initState();
    _song = widget.song;
  }

  @override
  Widget build(BuildContext context) {
    final fontSize = ref.watch(fontSizeProvider);
    final isBookmarked = ref.watch(tamBookmarkStatusProvider(_song.number));

    return Scaffold(
      appBar: AppBar(
        title: Text('TL ${_song.number}'),
        actions: [
          IconButton(
            tooltip: 'Font size',
            onPressed: () => _showFontSizeSheet(context, ref),
            icon: const Icon(Icons.format_size),
          ),
          IconButton(
            onPressed: () async {
              await ref
                  .read(tamBookmarksProvider.notifier)
                  .toggle(_song.number);
            },
            icon: Icon(isBookmarked ? Icons.bookmark : Icons.bookmark_outline),
          ),
        ],
      ),
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onHorizontalDragEnd: (details) async {
          final velocity = details.primaryVelocity ?? 0;
          if (velocity < -250) {
            await _navigateToAdjacentSong(next: true);
          } else if (velocity > 250) {
            await _navigateToAdjacentSong(next: false);
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ListView(
            children: [
              Text(
                'TL ${_song.number}',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: const Color(0xFF7F6A3E),
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _song.title,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  height: 1.15,
                  color: const Color(0xFF18352D),
                ),
              ),
              if (_song.details.isNotEmpty) ...[
                const SizedBox(height: 10),
                _TamSongDetailsText(details: _song.details),
              ],
              const SizedBox(height: 16),
              _LyricsText(lyrics: _song.lyrics, fontSize: fontSize),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _navigateToAdjacentSong({required bool next}) async {
    if (_isNavigating) {
      return;
    }
    _isNavigating = true;
    final songs = await ref.read(tamSongsProvider.future);
    final currentIndex = songs.indexWhere(
      (entry) => entry.number == _song.number,
    );
    final nextIndex = currentIndex + (next ? 1 : -1);
    if (!mounted) {
      return;
    }
    if (currentIndex == -1 || nextIndex < 0 || nextIndex >= songs.length) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            next ? 'This is the last song.' : 'This is the first song.',
          ),
          duration: const Duration(milliseconds: 900),
        ),
      );
      _isNavigating = false;
      return;
    }

    setState(() {
      _song = songs[nextIndex];
    });
    _isNavigating = false;
  }

  Future<void> _showFontSizeSheet(BuildContext context, WidgetRef ref) async {
    final fontSize = ref.read(fontSizeProvider);
    double pending = fontSize;

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Lyrics font size',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  Slider(
                    value: pending,
                    min: 12,
                    max: 28,
                    divisions: 16,
                    label: pending.toStringAsFixed(0),
                    onChanged: (value) => setState(() => pending = value),
                  ),
                  const SizedBox(height: 8),
                  FilledButton(
                    onPressed: () async {
                      await ref
                          .read(fontSizeProvider.notifier)
                          .setSize(pending);
                      if (context.mounted) {
                        Navigator.of(context).pop();
                      }
                    },
                    child: const Text('Apply'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _TamSongDetailsText extends StatelessWidget {
  const _TamSongDetailsText({required this.details});

  final String details;

  @override
  Widget build(BuildContext context) {
    final baseStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
      fontStyle: FontStyle.italic,
      height: 1.4,
      color: const Color(0xFF5E5847),
    );
    final keyStyle = baseStyle?.copyWith(
      fontWeight: FontWeight.w800,
      color: const Color(0xFF3F3522),
    );
    final lines = details.split('\n');

    return RichText(
      text: TextSpan(
        children: [
          for (var index = 0; index < lines.length; index++) ...[
            TextSpan(
              text: lines[index],
              style: lines[index].trimLeft().toUpperCase().startsWith('KEY ')
                  ? keyStyle
                  : baseStyle,
            ),
            if (index < lines.length - 1)
              TextSpan(text: '\n', style: baseStyle),
          ],
        ],
      ),
    );
  }
}

class _LyricsText extends StatelessWidget {
  const _LyricsText({required this.lyrics, required this.fontSize});

  final String lyrics;
  final double fontSize;

  bool _isChorus(String stanza) {
    final firstLine = stanza.split('\n').first.trimLeft();
    return !RegExp(r'^\d{1,3}[.)]\s+').hasMatch(firstLine);
  }

  bool _hasNumberedStanza(List<String> stanzas) {
    return stanzas.any(
      (stanza) => RegExp(
        r'^\d{1,3}[.)]\s+',
      ).hasMatch(stanza.split('\n').first.trimLeft()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final baseStyle = Theme.of(
      context,
    ).textTheme.bodyLarge?.copyWith(height: 1.45, fontSize: fontSize);
    final chorusStyle = baseStyle?.copyWith(fontStyle: FontStyle.italic);
    final stanzas = lyrics
        .split(RegExp(r'\n{2,}'))
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList();
    final hasNumbered = _hasNumberedStanza(stanzas);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < stanzas.length; i++) ...[
          if (i > 0) const SizedBox(height: 16),
          if (hasNumbered && _isChorus(stanzas[i])) ...[
            const SizedBox(height: 16),
            Text(stanzas[i], style: chorusStyle),
            const SizedBox(height: 16),
          ] else
            Text(stanzas[i], style: baseStyle),
        ],
      ],
    );
  }
}
