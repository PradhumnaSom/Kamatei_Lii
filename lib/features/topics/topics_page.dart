import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import 'topic_songs_page.dart';

class TopicsPage extends ConsumerWidget {
  const TopicsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final topicsAsync = ref.watch(officialTopicIndexProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Topical Index')),
      body: topicsAsync.when(
        data: (topics) {
          if (topics.isEmpty) {
            return const Center(child: Text('No topics found'));
          }

          return ListView.separated(
            itemCount: topics.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final topic = topics[index];
              return ListTile(
                leading: const Icon(Icons.label_outline),
                title: Text(
                  topic.topic,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                subtitle: Text('${topic.songNumbers.length} songs'),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => TopicSongsPage(topic: topic),
                    ),
                  );
                },
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const Center(child: Text('Unable to load topics')),
      ),
    );
  }
}
