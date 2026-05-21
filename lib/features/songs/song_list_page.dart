import 'package:flutter/material.dart';

import '../../core/models/song.dart';
import 'song_detail_page.dart';

class SongListPage extends StatelessWidget {
  const SongListPage({required this.title, required this.songs, super.key});

  final String title;
  final List<Song> songs;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: songs.isEmpty
          ? const Center(child: Text('No songs found'))
          : ListView.separated(
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
                  subtitle: Text('KL ${song.kklNumber} • ${song.topic}'),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => SongDetailPage(song: song),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}
