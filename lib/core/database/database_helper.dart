import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class DatabaseHelper {
  DatabaseHelper._();

  static final DatabaseHelper instance = DatabaseHelper._();

  static const _dbName = 'kamatei_lii.db';
  static const _dbVersion = 3;
  static const _songsAssetPath = 'assets/data/songs.json';
  static const _songsHashKey = 'songs_hash';

  Database? _database;
  bool? _ftsAvailable;

  Future<Database> get database async {
    if (_database != null) {
      return _database!;
    }

    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final fullPath = p.join(dbPath, _dbName);

    return openDatabase(
      fullPath,
      version: _dbVersion,
      onCreate: (db, _) async {
        await _createSchema(db);
      },
      onUpgrade: (db, oldVersion, _) async {
        if (oldVersion < 2) {
          await _rebuildDatabase(db);
        }
        if (oldVersion < 3) {
          await _rebuildDatabase(db);
        }
      },
      onOpen: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS app_meta(
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL
          )
        ''');
        _ftsAvailable ??= await _readFtsFlag(db);
      },
    );
  }

  Future<void> syncSongsFromAsset({bool force = false}) async {
    final db = await database;
    final jsonText = await rootBundle.loadString(_songsAssetPath);
    final decoded = jsonDecode(jsonText) as List<dynamic>;
    final assetHash = sha256.convert(utf8.encode(jsonText)).toString();
    final existing = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM songs'),
    );
    final storedHash = await _readMetaValue(db, _songsHashKey);

    final hasSongs = (existing ?? 0) > 0;
    final isUpToDate = storedHash == assetHash;

    if (!force && hasSongs && isUpToDate) {
      return;
    }

    await _importSongs(
      db,
      decoded: decoded,
      replaceExisting: hasSongs,
      preserveBookmarks: hasSongs,
    );
    await _setMetaValue(db, _songsHashKey, assetHash);
  }

  Future<void> seedSongsFromAssetIfEmpty() async {
    await syncSongsFromAsset();
  }

  Future<void> reimportSongsFromAsset() async {
    await syncSongsFromAsset(force: true);
  }

  Future<void> _importSongs(
    Database db, {
    required List<dynamic> decoded,
    required bool replaceExisting,
    required bool preserveBookmarks,
  }) async {
    await db.transaction((txn) async {
      final bookmarkedNumbers = preserveBookmarks
          ? await _loadBookmarkedNumbers(txn)
          : const <String>[];

      if (replaceExisting) {
        await txn.delete('songs');
      }

      final batch = txn.batch();
      for (final item in decoded) {
        final row = item as Map<String, dynamic>;
        batch.insert('songs', {
          'kkl_number': row['kkl_number']?.toString() ?? '',
          'title': row['title']?.toString() ?? '',
          'details': row['details']?.toString() ?? '',
          'lyrics': row['lyrics']?.toString() ?? '',
          'topic': row['topic']?.toString() ?? 'General',
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await batch.commit(noResult: true);

      if (bookmarkedNumbers.isNotEmpty) {
        for (final kklNumber in bookmarkedNumbers) {
          final rows = await txn.query(
            'songs',
            columns: ['id'],
            where: 'kkl_number = ?',
            whereArgs: [kklNumber],
            limit: 1,
          );
          if (rows.isEmpty) {
            continue;
          }
          await txn.insert('bookmarks', {
            'song_id': rows.first['id'] as int,
          }, conflictAlgorithm: ConflictAlgorithm.ignore);
        }
      }
    });
  }

  Future<void> _createSchema(Database db) async {
    await db.execute('''
      CREATE TABLE app_meta(
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE songs(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        kkl_number TEXT NOT NULL UNIQUE,
        title TEXT NOT NULL,
        details TEXT NOT NULL,
        lyrics TEXT NOT NULL,
        topic TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE bookmarks(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        song_id INTEGER NOT NULL UNIQUE,
        FOREIGN KEY(song_id) REFERENCES songs(id) ON DELETE CASCADE
      )
    ''');

    final ftsVersion = await _tryCreateFts(db);
    _ftsAvailable = ftsVersion != null && ftsVersion != '0';
    await db.insert('app_meta', {
      'key': 'fts',
      'value': ftsVersion ?? '0',
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> _rebuildDatabase(Database db) async {
    await db.transaction((txn) async {
      await txn.execute('DROP TABLE IF EXISTS songs_fts');
      await txn.execute('DROP TABLE IF EXISTS bookmarks');
      await txn.execute('DROP TABLE IF EXISTS songs');
      await txn.execute('DROP TABLE IF EXISTS app_meta');
    });

    await _createSchema(db);
  }

  Future<bool> supportsFts() async {
    if (_ftsAvailable != null) {
      return _ftsAvailable!;
    }
    final db = await database;
    _ftsAvailable = await _readFtsFlag(db);
    return _ftsAvailable!;
  }

  Future<bool> _readFtsFlag(Database db) async {
    final rows = await db.query(
      'app_meta',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: ['fts'],
      limit: 1,
    );
    if (rows.isEmpty) {
      return false;
    }
    final value = rows.first['value']?.toString() ?? '0';
    return value != '0';
  }

  Future<String?> _tryCreateFts(Database db) async {
    try {
      await db.execute('''
        CREATE VIRTUAL TABLE songs_fts USING fts5(
          title,
          lyrics,
          content='songs',
          content_rowid='id'
        )
      ''');
      await _createFtsTriggers(db);
      return '5';
    } catch (_) {
      try {
        await db.execute('''
          CREATE VIRTUAL TABLE songs_fts USING fts4(
            title,
            lyrics,
            content='songs',
            content_rowid='id'
          )
        ''');
        await _createFtsTriggers(db);
        return '4';
      } catch (_) {
        return '0';
      }
    }
  }

  Future<void> _createFtsTriggers(Database db) async {
    await db.execute('''
      CREATE TRIGGER songs_ai AFTER INSERT ON songs BEGIN
        INSERT INTO songs_fts(rowid, title, lyrics)
        VALUES (new.id, new.title, new.lyrics);
      END
    ''');

    await db.execute('''
      CREATE TRIGGER songs_ad AFTER DELETE ON songs BEGIN
        INSERT INTO songs_fts(songs_fts, rowid, title, lyrics)
        VALUES ('delete', old.id, old.title, old.lyrics);
      END
    ''');

    await db.execute('''
      CREATE TRIGGER songs_au AFTER UPDATE ON songs BEGIN
        INSERT INTO songs_fts(songs_fts, rowid, title, lyrics)
        VALUES ('delete', old.id, old.title, old.lyrics);
        INSERT INTO songs_fts(rowid, title, lyrics)
        VALUES (new.id, new.title, new.lyrics);
      END
    ''');
  }

  Future<List<String>> _loadBookmarkedNumbers(DatabaseExecutor db) async {
    final rows = await db.rawQuery('''
      SELECT s.kkl_number
      FROM songs s
      INNER JOIN bookmarks b ON b.song_id = s.id
    ''');

    return rows
        .map((row) => row['kkl_number']?.toString() ?? '')
        .where((value) => value.isNotEmpty)
        .toList();
  }

  Future<String?> _readMetaValue(Database db, String key) async {
    final rows = await db.query(
      'app_meta',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return rows.first['value']?.toString();
  }

  Future<void> _setMetaValue(Database db, String key, String value) async {
    await db.insert('app_meta', {
      'key': key,
      'value': value,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }
}
