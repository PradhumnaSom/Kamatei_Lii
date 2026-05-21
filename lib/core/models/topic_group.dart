class TopicGroup {
  const TopicGroup({required this.topic, required this.songNumbers});

  final String topic;
  final List<int> songNumbers;

  factory TopicGroup.fromMap(Map<String, Object?> map) {
    final numbers = (map['song_numbers'] as List<dynamic>)
        .map((value) => int.parse(value.toString()))
        .toList();
    return TopicGroup(
      topic: map['topic']?.toString() ?? '',
      songNumbers: numbers,
    );
  }
}
