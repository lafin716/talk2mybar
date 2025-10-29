import 'transcript_segment.dart';
import 'speaker.dart';

/// 회의 정보 모델
class Meeting {
  final String id;
  final String title;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final List<Speaker> speakers;
  final List<TranscriptSegment> segments;
  final String? driveFileId; // 구글 드라이브에 저장된 파일 ID

  Meeting({
    required this.id,
    required this.title,
    required this.createdAt,
    this.updatedAt,
    this.speakers = const [],
    this.segments = const [],
    this.driveFileId,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'drive_file_id': driveFileId,
    };
  }

  factory Meeting.fromMap(Map<String, dynamic> map) {
    return Meeting(
      id: map['id'] as String,
      title: map['title'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'] as String)
          : null,
      driveFileId: map['drive_file_id'] as String?,
    );
  }

  Meeting copyWith({
    String? id,
    String? title,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<Speaker>? speakers,
    List<TranscriptSegment>? segments,
    String? driveFileId,
  }) {
    return Meeting(
      id: id ?? this.id,
      title: title ?? this.title,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      speakers: speakers ?? this.speakers,
      segments: segments ?? this.segments,
      driveFileId: driveFileId ?? this.driveFileId,
    );
  }

  /// 대본 형식으로 변환
  String toTranscriptText() {
    final buffer = StringBuffer();
    buffer.writeln('회의록: $title');
    buffer.writeln('날짜: ${createdAt.toString().split('.')[0]}');
    buffer.writeln('=' * 50);
    buffer.writeln();

    for (final segment in segments) {
      final time = segment.timestamp.toString().split(' ')[1].split('.')[0];
      buffer.writeln('[$time] ${segment.speakerName}: ${segment.text}');
    }

    return buffer.toString();
  }
}
