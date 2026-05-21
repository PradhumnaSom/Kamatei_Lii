class Song {
  const Song({
    required this.id,
    required this.kklNumber,
    required this.title,
    required this.details,
    required this.lyrics,
    required this.topic,
  });

  final int id;
  final String kklNumber;
  final String title;
  final String details;
  final String lyrics;
  final String topic;

  factory Song.fromMap(Map<String, Object?> map) {
    return Song(
      id: map['id'] as int,
      kklNumber: map['kkl_number'] as String,
      title: map['title'] as String,
      details: map['details'] as String? ?? '',
      lyrics: map['lyrics'] as String,
      topic: map['topic'] as String,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'kkl_number': kklNumber,
      'title': title,
      'details': details,
      'lyrics': lyrics,
      'topic': topic,
    };
  }
}
