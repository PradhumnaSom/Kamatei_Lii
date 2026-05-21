import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/song.dart';
import '../../core/providers.dart';
import '../songs/song_detail_page.dart';
import '../songs/song_list_page.dart';
import '../tam_kamatoi/tam_kamatoi_page.dart';
import '../tam_kamatoi/tam_song.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = ref.watch(searchQueryProvider);
    final songsAsync = ref.watch(songListProvider(query));
    final tamSongsAsync = ref.watch(tamSongsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Kamatei Lii')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: SearchBar(
              controller: _controller,
              hintText: 'Search all songs by number, title, or lyrics',
              leading: const Icon(Icons.search),
              onChanged: (value) =>
                  ref.read(searchQueryProvider.notifier).state = value,
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(22),
                    gradient: const LinearGradient(
                      colors: [Color(0xFFE7EFE2), Color(0xFFF8F2E5)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    border: Border.all(color: const Color(0xFFE0D4BA)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'One hymnal search',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF18352D),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Search Kamatei Lii and Tam Kamatoi Lii together by number, title, or lyrics.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: const Color(0xFF5D675F),
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      query.trim().isEmpty ? 'Songs' : 'Global Search Results',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF18352D),
                      ),
                    ),
                    if (query.trim().isEmpty)
                      TextButton(
                        onPressed: () {
                          songsAsync.whenData((songs) {
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => SongListPage(
                                  title: 'All Songs',
                                  songs: songs,
                                ),
                              ),
                            );
                          });
                        },
                        child: const Text('View all'),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                _buildGlobalResults(
                  context,
                  query: query,
                  songsAsync: songsAsync,
                  tamSongsAsync: tamSongsAsync,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlobalResults(
    BuildContext context, {
    required String query,
    required AsyncValue<List<Song>> songsAsync,
    required AsyncValue<List<TamSong>> tamSongsAsync,
  }) {
    return songsAsync.when(
      data: (songs) {
        return tamSongsAsync.when(
          data: (tamSongs) {
            final safeQuery = query.trim();
            final isNumberQuery = RegExp(r'^\d+$').hasMatch(safeQuery);
            final mainSongs = safeQuery.isEmpty
                ? songs.take(12).toList()
                : isNumberQuery
                ? songs.where((song) => song.kklNumber == safeQuery).toList()
                : songs;
            final filteredTam = _filterTamSongs(songs: tamSongs, query: query);
            final showGlobal = safeQuery.isNotEmpty;
            final visibleMainSongs = showGlobal
                ? mainSongs.take(20).toList()
                : mainSongs;

            if (mainSongs.isEmpty && filteredTam.isEmpty) {
              return const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text('No songs found'),
              );
            }

            return Column(
              children: [
                if (showGlobal)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Main Songs',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                ...visibleMainSongs.map((song) {
                  return Card(
                    margin: const EdgeInsets.only(top: 8),
                    child: ListTile(
                      title: Text(
                        song.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                      subtitle: Text('KL ${song.kklNumber} • ${song.topic}'),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => SongDetailPage(song: song),
                          ),
                        );
                      },
                    ),
                  );
                }),
                if (showGlobal && filteredTam.isEmpty) ...[
                  const SizedBox(height: 12),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Tam Kamatoi Lii: no matches'),
                  ),
                ],
                if (filteredTam.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Tam Kamatoi Lii',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  ...filteredTam.take(20).map((song) {
                    return Card(
                      margin: const EdgeInsets.only(top: 8),
                      child: ListTile(
                        leading: const Icon(Icons.menu_book_outlined),
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
                      ),
                    );
                  }),
                ],
              ],
            );
          },
          loading: () => const Padding(
            padding: EdgeInsets.only(top: 12),
            child: LinearProgressIndicator(),
          ),
          error: (_, _) => const Padding(
            padding: EdgeInsets.only(top: 12),
            child: Text('Unable to load Tam Kamatoi songs'),
          ),
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.only(top: 12),
        child: LinearProgressIndicator(),
      ),
      error: (_, _) => const Padding(
        padding: EdgeInsets.only(top: 12),
        child: Text('Unable to load songs'),
      ),
    );
  }

  List<TamSong> _filterTamSongs({
    required List<TamSong> songs,
    required String query,
  }) {
    final safeQuery = query.trim();
    if (safeQuery.isEmpty) {
      return const [];
    }

    final lower = safeQuery.toLowerCase();
    final isNumberQuery = RegExp(r'^\d+$').hasMatch(safeQuery);
    final scored = <({TamSong song, int score})>[];

    for (final song in songs) {
      final title = song.title.toLowerCase();
      final lyrics = song.lyrics.toLowerCase();
      int? score;

      if (isNumberQuery && song.number == safeQuery) {
        score = 0;
      } else if (isNumberQuery) {
        score = null;
      } else if (song.number == safeQuery) {
        score = 0;
      } else if (song.number.startsWith(safeQuery)) {
        score = 1;
      } else if (title == lower) {
        score = 2;
      } else if (title.startsWith(lower)) {
        score = 3;
      } else if (title.contains(lower)) {
        score = 4;
      } else if (lyrics.contains(lower)) {
        score = 5;
      }

      if (score != null) {
        scored.add((song: song, score: score));
      }
    }

    scored.sort((a, b) {
      final cmp = a.score.compareTo(b.score);
      if (cmp != 0) {
        return cmp;
      }
      return int.parse(a.song.number).compareTo(int.parse(b.song.number));
    });

    return scored.map((item) => item.song).toList();
  }
}
