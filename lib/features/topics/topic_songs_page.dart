import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/topic_group.dart';
import '../../core/providers.dart';
import '../songs/song_detail_page.dart';

class TopicSongsPage extends ConsumerWidget {
  const TopicSongsPage({required this.topic, super.key});

  final TopicGroup topic;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final songsAsync = ref.watch(officialTopicSongsProvider(topic.topic));

    return Scaffold(
      appBar: AppBar(title: Text(topic.topic)),
      body: songsAsync.when(
        data: (songs) {
          if (songs.isEmpty) {
            return const Center(child: Text('No songs in this topic'));
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
                subtitle: Text('KL ${song.kklNumber}'),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => SongDetailPage(song: song),
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
