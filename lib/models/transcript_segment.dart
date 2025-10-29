/// 대화 세그먼트 (발화 단위)
class TranscriptSegment {
  final String id;
  final String speakerId;
  final String speakerName;
  final String text;
  final DateTime timestamp;
  final double confidence; // 음성 인식 신뢰도

  TranscriptSegment({
    required this.id,
    required this.speakerId,
    required this.speakerName,
    required this.text,
    required this.timestamp,
    this.confidence = 1.0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'speaker_id': speakerId,
      'speaker_name': speakerName,
      'text': text,
      'timestamp': timestamp.toIso8601String(),
      'confidence': confidence,
    };
  }

  factory TranscriptSegment.fromMap(Map<String, dynamic> map) {
    return TranscriptSegment(
      id: map['id'] as String,
      speakerId: map['speaker_id'] as String,
      speakerName: map['speaker_name'] as String,
      text: map['text'] as String,
      timestamp: DateTime.parse(map['timestamp'] as String),
      confidence: (map['confidence'] as num?)?.toDouble() ?? 1.0,
    );
  }

  TranscriptSegment copyWith({
    String? id,
    String? speakerId,
    String? speakerName,
    String? text,
    DateTime? timestamp,
    double? confidence,
  }) {
    return TranscriptSegment(
      id: id ?? this.id,
      speakerId: speakerId ?? this.speakerId,
      speakerName: speakerName ?? this.speakerName,
      text: text ?? this.text,
      timestamp: timestamp ?? this.timestamp,
      confidence: confidence ?? this.confidence,
    );
  }
}
