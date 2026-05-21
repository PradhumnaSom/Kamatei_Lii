import 'dart:convert';

import 'package:flutter/services.dart';

class TamSong {
  const TamSong({
    required this.number,
    required this.title,
    required this.details,
    required this.lyrics,
  });

  final String number;
  final String title;
  final String details;
  final String lyrics;

  factory TamSong.fromMap(Map<String, Object?> map) {
    return TamSong(
      number: map['kkl_number']?.toString() ?? '',
      title: map['title']?.toString() ?? '',
      details: map['details']?.toString() ?? '',
      lyrics: map['lyrics']?.toString() ?? '',
    );
  }

  static Future<List<TamSong>> loadFromAsset(String path) async {
    final jsonText = await rootBundle.loadString(path);
    final decoded = jsonDecode(jsonText) as List<dynamic>;
    return decoded
        .map((item) => TamSong.fromMap(item as Map<String, Object?>))
        .toList();
  }
}
