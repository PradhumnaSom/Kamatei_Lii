import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'database/database_helper.dart';
import 'database/song_repository.dart';
import 'models/song.dart';
import 'models/topic_group.dart';
import '../features/tam_kamatoi/tam_song.dart';

final databaseHelperProvider = Provider<DatabaseHelper>((ref) {
  return DatabaseHelper.instance;
});

final songRepositoryProvider = Provider<SongRepository>((ref) {
  return SongRepository(ref.watch(databaseHelperProvider));
});

final appBootstrapProvider = FutureProvider<void>((ref) async {
  final helper = ref.watch(databaseHelperProvider);
  await helper.syncSongsFromAsset();
});

final searchQueryProvider = StateProvider<String>((_) => '');

final songListProvider = FutureProvider.autoDispose.family<List<Song>, String>((
  ref,
  query,
) async {
  return ref.watch(songRepositoryProvider).searchSongs(query: query);
});

final songsByTopicProvider = FutureProvider.autoDispose
    .family<List<Song>, String>((ref, topic) async {
      return ref.watch(songRepositoryProvider).searchSongs(topic: topic);
    });

final topicsProvider = FutureProvider<List<String>>((ref) async {
  return ref.watch(songRepositoryProvider).getTopics();
});

final officialTopicIndexProvider = FutureProvider<List<TopicGroup>>((
  ref,
) async {
  final jsonText = await rootBundle.loadString('assets/data/topic_index.json');
  final decoded = jsonDecode(jsonText) as List<dynamic>;
  return decoded
      .map((item) => TopicGroup.fromMap(item as Map<String, Object?>))
      .toList();
});

final officialTopicSongsProvider = FutureProvider.autoDispose
    .family<List<Song>, String>((ref, topic) async {
      final groups = await ref.watch(officialTopicIndexProvider.future);
      final group = groups.firstWhere((entry) => entry.topic == topic);
      return ref
          .watch(songRepositoryProvider)
          .getSongsByNumbers(group.songNumbers);
    });

final bookmarkedSongsProvider = FutureProvider<List<Song>>((ref) async {
  return ref.watch(songRepositoryProvider).getBookmarkedSongs();
});

final bookmarkStatusProvider = FutureProvider.autoDispose.family<bool, int>((
  ref,
  songId,
) async {
  return ref.watch(songRepositoryProvider).isSongBookmarked(songId);
});

final sharedPreferencesProvider = Provider<Future<SharedPreferences>>((ref) {
  return SharedPreferences.getInstance();
});

final fontSizeProvider = StateNotifierProvider<FontSizeNotifier, double>((ref) {
  return FontSizeNotifier(ref.watch(sharedPreferencesProvider));
});

class FontSizeNotifier extends StateNotifier<double> {
  FontSizeNotifier(this._prefsFuture) : super(16) {
    _load();
  }

  final Future<SharedPreferences> _prefsFuture;

  Future<void> _load() async {
    final prefs = await _prefsFuture;
    state = prefs.getDouble('font_size') ?? 16;
  }

  Future<void> setSize(double value) async {
    state = value;
    final prefs = await _prefsFuture;
    await prefs.setDouble('font_size', value);
  }
}

final tamSongsProvider = FutureProvider<List<TamSong>>((ref) async {
  return TamSong.loadFromAsset('assets/data/tam_kamatoi_lii.json');
});

final tamBookmarksProvider =
    StateNotifierProvider<TamBookmarksNotifier, Set<String>>((ref) {
      return TamBookmarksNotifier(ref.watch(sharedPreferencesProvider));
    });

final tamBookmarkStatusProvider = Provider.family<bool, String>((ref, number) {
  return ref.watch(tamBookmarksProvider).contains(number);
});

final tamBookmarkedSongsProvider = FutureProvider<List<TamSong>>((ref) async {
  final songs = await ref.watch(tamSongsProvider.future);
  final bookmarks = ref.watch(tamBookmarksProvider);
  return songs.where((song) => bookmarks.contains(song.number)).toList();
});

class TamBookmarksNotifier extends StateNotifier<Set<String>> {
  TamBookmarksNotifier(this._prefsFuture) : super(<String>{}) {
    _load();
  }

  final Future<SharedPreferences> _prefsFuture;
  static const _storageKey = 'tam_bookmarks';

  Future<void> _load() async {
    final prefs = await _prefsFuture;
    state = prefs.getStringList(_storageKey)?.toSet() ?? <String>{};
  }

  Future<void> toggle(String songNumber) async {
    final updated = Set<String>.from(state);
    if (!updated.add(songNumber)) {
      updated.remove(songNumber);
    }
    state = updated;
    final prefs = await _prefsFuture;
    await prefs.setStringList(_storageKey, updated.toList()..sort());
  }
}
