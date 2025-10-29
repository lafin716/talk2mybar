import '../models/meeting.dart';
import '../models/transcript_segment.dart';
import 'package:intl/intl.dart';
import 'dart:convert';

/// 대본 정리 및 포맷팅 유틸리티
class TranscriptFormatter {
  /// 대본 텍스트 형식으로 변환
  static String toText(Meeting meeting) {
    final buffer = StringBuffer();

    // 헤더
    buffer.writeln('=' * 60);
    buffer.writeln('회의록: ${meeting.title}');
    buffer.writeln('날짜: ${DateFormat('yyyy년 MM월 dd일 HH:mm').format(meeting.createdAt)}');
    buffer.writeln('=' * 60);
    buffer.writeln();

    // 참석자
    if (meeting.speakers.isNotEmpty) {
      buffer.writeln('참석자:');
      for (final speaker in meeting.speakers) {
        buffer.writeln('  - ${speaker.name}');
      }
      buffer.writeln();
    }

    // 대화 내용
    buffer.writeln('대화 내용:');
    buffer.writeln('-' * 60);

    String? lastSpeakerId;
    for (final segment in meeting.segments) {
      // 화자가 바뀌었을 때만 화자명 표시
      if (segment.speakerId != lastSpeakerId) {
        if (lastSpeakerId != null) {
          buffer.writeln(); // 화자 전환 시 빈 줄 추가
        }
        buffer.writeln();
        buffer.writeln('[${segment.speakerName}]');
        lastSpeakerId = segment.speakerId;
      }

      // 시간 및 내용
      final time = DateFormat('HH:mm:ss').format(segment.timestamp);
      buffer.writeln('$time: ${segment.text}');
    }

    buffer.writeln();
    buffer.writeln('=' * 60);
    buffer.writeln('총 ${meeting.segments.length}개 발화');
    buffer.writeln('=' * 60);

    return buffer.toString();
  }

  /// 간단한 대본 형식 (화자: 내용)
  static String toSimpleText(Meeting meeting) {
    final buffer = StringBuffer();
    buffer.writeln('${meeting.title}\n');

    for (final segment in meeting.segments) {
      buffer.writeln('${segment.speakerName}: ${segment.text}');
    }

    return buffer.toString();
  }

  /// 타임스탬프 포함 대본
  static String toTimestampedText(Meeting meeting) {
    final buffer = StringBuffer();
    buffer.writeln('회의록: ${meeting.title}');
    buffer.writeln('날짜: ${DateFormat('yyyy-MM-dd HH:mm').format(meeting.createdAt)}\n');

    for (final segment in meeting.segments) {
      final time = DateFormat('HH:mm:ss').format(segment.timestamp);
      buffer.writeln('[$time] ${segment.speakerName}: ${segment.text}');
    }

    return buffer.toString();
  }

  /// Markdown 형식으로 변환
  static String toMarkdown(Meeting meeting) {
    final buffer = StringBuffer();

    // 제목
    buffer.writeln('# ${meeting.title}\n');

    // 메타데이터
    buffer.writeln('**날짜:** ${DateFormat('yyyy년 MM월 dd일 HH:mm').format(meeting.createdAt)}  ');
    buffer.writeln('**참석자:** ${meeting.speakers.map((s) => s.name).join(', ')}  ');
    buffer.writeln();

    // 대화 내용
    buffer.writeln('## 대화 내용\n');

    String? lastSpeakerId;
    for (final segment in meeting.segments) {
      // 화자가 바뀌었을 때
      if (segment.speakerId != lastSpeakerId) {
        if (lastSpeakerId != null) {
          buffer.writeln(); // 화자 전환 시 빈 줄
        }
        buffer.writeln('### ${segment.speakerName}\n');
        lastSpeakerId = segment.speakerId;
      }

      final time = DateFormat('HH:mm:ss').format(segment.timestamp);
      buffer.writeln('- `$time` ${segment.text}');
    }

    buffer.writeln();
    buffer.writeln('---');
    buffer.writeln('*총 ${meeting.segments.length}개 발화*');

    return buffer.toString();
  }

  /// JSON 형식으로 변환 (구조화된 데이터)
  static String toJson(Meeting meeting) {
    final data = {
      'title': meeting.title,
      'created_at': meeting.createdAt.toIso8601String(),
      'speakers': meeting.speakers.map((s) => s.toMap()).toList(),
      'segments': meeting.segments.map((s) => s.toMap()).toList(),
    };

    return const JsonEncoder.withIndent('  ').convert(data);
  }

  /// 회의 요약 통계
  static String getStatistics(Meeting meeting) {
    final buffer = StringBuffer();

    // 기본 정보
    buffer.writeln('회의 통계');
    buffer.writeln('=' * 40);
    buffer.writeln('제목: ${meeting.title}');
    buffer.writeln('날짜: ${DateFormat('yyyy-MM-dd').format(meeting.createdAt)}');

    if (meeting.segments.isNotEmpty) {
      final duration = meeting.segments.last.timestamp
          .difference(meeting.segments.first.timestamp);
      buffer.writeln('소요 시간: ${_formatDuration(duration)}');
    }

    buffer.writeln();

    // 참석자별 통계
    buffer.writeln('참석자별 발화 수:');
    final speakerCounts = <String, int>{};
    for (final segment in meeting.segments) {
      speakerCounts[segment.speakerName] =
          (speakerCounts[segment.speakerName] ?? 0) + 1;
    }

    for (final entry in speakerCounts.entries) {
      final percentage =
          (entry.value / meeting.segments.length * 100).toStringAsFixed(1);
      buffer.writeln('  ${entry.key}: ${entry.value}회 ($percentage%)');
    }

    buffer.writeln();
    buffer.writeln('총 발화 수: ${meeting.segments.length}');

    return buffer.toString();
  }

  /// Duration을 읽기 쉬운 형식으로 변환
  static String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '$hours시간 $minutes분 $seconds초';
    } else if (minutes > 0) {
      return '$minutes분 $seconds초';
    } else {
      return '$seconds초';
    }
  }

  /// 세그먼트를 그룹화 (같은 화자의 연속된 발화를 하나로 합침)
  static List<TranscriptSegment> groupSegments(
      List<TranscriptSegment> segments) {
    if (segments.isEmpty) return [];

    final grouped = <TranscriptSegment>[];
    TranscriptSegment current = segments.first;
    final textBuffer = StringBuffer(current.text);

    for (int i = 1; i < segments.length; i++) {
      if (segments[i].speakerId == current.speakerId) {
        // 같은 화자면 텍스트를 합침
        textBuffer.write(' ${segments[i].text}');
      } else {
        // 화자가 바뀌면 현재까지의 내용을 저장
        grouped.add(current.copyWith(text: textBuffer.toString()));
        current = segments[i];
        textBuffer.clear();
        textBuffer.write(current.text);
      }
    }

    // 마지막 세그먼트 추가
    grouped.add(current.copyWith(text: textBuffer.toString()));

    return grouped;
  }
}
