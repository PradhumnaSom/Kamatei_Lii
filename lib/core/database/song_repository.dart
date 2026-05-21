import 'package:sqflite/sqflite.dart';

import '../models/song.dart';
import 'database_helper.dart';

class SongRepository {
  SongRepository(this._databaseHelper);

  final DatabaseHelper _databaseHelper;

  Future<List<Song>> searchSongs({String? query, String? topic}) async {
    final db = await _databaseHelper.database;
    final safeQuery = (query ?? '').trim();
    final queryLower = safeQuery.toLowerCase();
    final hasFts = await _databaseHelper.supportsFts();

    if (safeQuery.isEmpty && (topic == null || topic.isEmpty)) {
      final rows = await db.query(
        'songs',
        orderBy: 'CAST(kkl_number AS INTEGER) ASC',
      );
      return rows.map(Song.fromMap).toList();
    }

    final args = <Object?>[];
    final where = <String>[];

    if (topic != null && topic.isNotEmpty) {
      where.add('topic = ?');
      args.add(topic);
    }

    if (safeQuery.isNotEmpty) {
      where.add('''
        (
          kkl_number = ? OR
          kkl_number LIKE ? OR
          title LIKE ? OR
          ${hasFts ? "id IN (SELECT rowid FROM songs_fts WHERE songs_fts MATCH ?)" : "lyrics LIKE ?"}
        )
      ''');
      args.add(safeQuery);
      args.add('$safeQuery%');
      args.add('%$safeQuery%');
      if (hasFts) {
        args.add(_toFtsQuery(safeQuery));
      } else {
        args.add('%$safeQuery%');
      }

      final sql =
          '''
        SELECT *
        FROM songs
        WHERE ${where.join(' AND ')}
        ORDER BY
          CASE
            WHEN kkl_number = ? THEN 0
            WHEN kkl_number LIKE ? THEN 1
            WHEN LOWER(title) = ? THEN 2
            WHEN title LIKE ? THEN 3
            WHEN title LIKE ? THEN 4
            ELSE 5
          END ASC,
          CAST(kkl_number AS INTEGER) ASC
      ''';

      final rankedArgs = <Object?>[
        ...args,
        safeQuery,
        '$safeQuery%',
        queryLower,
        '$safeQuery%',
        '%$safeQuery%',
      ];
      final rows = await db.rawQuery(sql, rankedArgs);
      return rows.map(Song.fromMap).toList();
    }

    final rows = await db.query(
      'songs',
      where: where.join(' AND '),
      whereArgs: args,
      orderBy: 'CAST(kkl_number AS INTEGER) ASC',
    );

    return rows.map(Song.fromMap).toList();
  }

  Future<Song?> getSongById(int id) async {
    final db = await _databaseHelper.database;
    final rows = await db.query('songs', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) {
      return null;
    }
    return Song.fromMap(rows.first);
  }

  Future<List<String>> getTopics() async {
    final db = await _databaseHelper.database;
    final rows = await db.rawQuery(
      'SELECT DISTINCT topic FROM songs ORDER BY topic COLLATE NOCASE ASC',
    );

    return rows
        .map((row) => row['topic']?.toString() ?? '')
        .where((topic) => topic.isNotEmpty)
        .toList();
  }

  Future<List<Song>> getSongsByNumbers(List<int> numbers) async {
    if (numbers.isEmpty) {
      return const [];
    }

    final db = await _databaseHelper.database;
    final placeholders = List.filled(numbers.length, '?').join(', ');
    final rows = await db.query(
      'songs',
      where: 'CAST(kkl_number AS INTEGER) IN ($placeholders)',
      whereArgs: numbers,
    );

    final songs = rows.map(Song.fromMap).toList();
    final order = {for (var i = 0; i < numbers.length; i++) numbers[i]: i};
    songs.sort((a, b) {
      final left = order[int.parse(a.kklNumber)] ?? 1 << 30;
      final right = order[int.parse(b.kklNumber)] ?? 1 << 30;
      return left.compareTo(right);
    });
    return songs;
  }

  Future<Song?> getAdjacentSong({
    required String currentKklNumber,
    required bool next,
  }) async {
    final db = await _databaseHelper.database;
    final currentNumber = int.tryParse(currentKklNumber);
    if (currentNumber == null) {
      return null;
    }

    final comparator = next ? '>' : '<';
    final direction = next ? 'ASC' : 'DESC';
    final rows = await db.query(
      'songs',
      where: 'CAST(kkl_number AS INTEGER) $comparator ?',
      whereArgs: [currentNumber],
      orderBy: 'CAST(kkl_number AS INTEGER) $direction',
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return Song.fromMap(rows.first);
  }

  Future<void> toggleBookmark(int songId) async {
    final db = await _databaseHelper.database;
    final isBookmarked = await _isBookmarked(db, songId);

    if (isBookmarked) {
      await db.delete('bookmarks', where: 'song_id = ?', whereArgs: [songId]);
      return;
    }

    await db.insert('bookmarks', {'song_id': songId});
  }

  Future<bool> isSongBookmarked(int songId) async {
    final db = await _databaseHelper.database;
    return _isBookmarked(db, songId);
  }

  Future<List<Song>> getBookmarkedSongs() async {
    final db = await _databaseHelper.database;
    final rows = await db.rawQuery('''
      SELECT s.*
      FROM songs s
      INNER JOIN bookmarks b ON b.song_id = s.id
      ORDER BY CAST(s.kkl_number AS INTEGER) ASC
    ''');

    return rows.map(Song.fromMap).toList();
  }

  Future<bool> _isBookmarked(Database db, int songId) async {
    final rows = await db.query(
      'bookmarks',
      columns: ['id'],
      where: 'song_id = ?',
      whereArgs: [songId],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  String _toFtsQuery(String input) {
    return input
        .split(RegExp(r'\s+'))
        .map((token) => token.trim())
        .where((token) => token.isNotEmpty)
        .map((token) => '"$token"*')
        .join(' AND ');
  }
}
