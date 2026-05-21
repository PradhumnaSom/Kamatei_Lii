import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../songs/song_detail_page.dart';
import '../tam_kamatoi/tam_kamatoi_page.dart';

class BookmarksPage extends ConsumerWidget {
  const BookmarksPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookmarksAsync = ref.watch(bookmarkedSongsProvider);
    final tamBookmarksAsync = ref.watch(tamBookmarkedSongsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Bookmarks')),
      body: bookmarksAsync.when(
        data: (songs) => tamBookmarksAsync.when(
          data: (tamSongs) {
            if (songs.isEmpty && tamSongs.isEmpty) {
              return const Center(child: Text('No bookmarks yet'));
            }

            return ListView(
              children: [
                if (songs.isNotEmpty) ...[
                  const _SectionHeader(title: 'Kamatei Lii'),
                  ...songs.map((song) {
                    return ListTile(
                      title: Text(
                        song.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                      subtitle: Text('KL ${song.kklNumber} • ${song.topic}'),
                      trailing: IconButton(
                        icon: const Icon(Icons.bookmark_remove_outlined),
                        onPressed: () async {
                          await ref
                              .read(songRepositoryProvider)
                              .toggleBookmark(song.id);
                          ref.invalidate(bookmarkedSongsProvider);
                          ref.invalidate(bookmarkStatusProvider(song.id));
                        },
                      ),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => SongDetailPage(song: song),
                          ),
                        );
                      },
                    );
                  }),
                ],
                if (tamSongs.isNotEmpty) ...[
                  const _SectionHeader(title: 'Tam Kamatoi Lii'),
                  ...tamSongs.map((song) {
                    return ListTile(
                      title: Text(
                        song.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                      subtitle: Text('TL ${song.number}'),
                      trailing: IconButton(
                        icon: const Icon(Icons.bookmark_remove_outlined),
                        onPressed: () async {
                          await ref
                              .read(tamBookmarksProvider.notifier)
                              .toggle(song.number);
                        },
                      ),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => TamSongDetailPage(song: song),
                          ),
                        );
                      },
                    );
                  }),
                ],
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) =>
              const Center(child: Text('Unable to load Tam bookmarks')),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const Center(child: Text('Unable to load bookmarks')),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
      ),
    );
  }
}
