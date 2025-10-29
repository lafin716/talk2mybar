import 'dart:async';
import '../models/speaker.dart';

/// 화자 구분 서비스
/// 온디바이스에서 완전한 자동 화자 구분은 어렵기 때문에,
/// 침묵 구간 감지와 수동 선택을 결합한 방식을 사용
class SpeakerDetectionService {
  final List<Speaker> _speakers = [];
  Speaker? _currentSpeaker;
  DateTime? _lastSpeechTime;
  final Duration _speakerChangeSilenceThreshold = const Duration(seconds: 3);

  List<Speaker> get speakers => List.unmodifiable(_speakers);
  Speaker? get currentSpeaker => _currentSpeaker;

  /// 화자 추가
  void addSpeaker(Speaker speaker) {
    if (!_speakers.any((s) => s.id == speaker.id)) {
      _speakers.add(speaker);
      if (_currentSpeaker == null) {
        _currentSpeaker = speaker;
      }
    }
  }

  /// 화자 제거
  void removeSpeaker(String speakerId) {
    _speakers.removeWhere((s) => s.id == speakerId);
    if (_currentSpeaker?.id == speakerId && _speakers.isNotEmpty) {
      _currentSpeaker = _speakers.first;
    }
  }

  /// 현재 화자 설정
  void setCurrentSpeaker(String speakerId) {
    final speaker = _speakers.firstWhere(
      (s) => s.id == speakerId,
      orElse: () => throw Exception('화자를 찾을 수 없습니다: $speakerId'),
    );
    _currentSpeaker = speaker;
    _lastSpeechTime = DateTime.now();
  }

  /// 음성 입력이 있을 때 호출 - 침묵 구간 기반 화자 전환 감지
  /// 자동 화자 전환이 감지되면 true를 반환
  bool onSpeechDetected() {
    final now = DateTime.now();
    bool speakerChanged = false;

    if (_lastSpeechTime != null) {
      final silenceDuration = now.difference(_lastSpeechTime!);

      // 일정 시간 이상 침묵이 있었다면 화자가 바뀌었을 가능성
      if (silenceDuration > _speakerChangeSilenceThreshold) {
        speakerChanged = true;
        // 화자 자동 순환 (간단한 구현)
        if (_speakers.length > 1) {
          final currentIndex = _speakers.indexOf(_currentSpeaker!);
          final nextIndex = (currentIndex + 1) % _speakers.length;
          _currentSpeaker = _speakers[nextIndex];
        }
      }
    }

    _lastSpeechTime = now;
    return speakerChanged;
  }

  /// 다음 화자로 전환
  void switchToNextSpeaker() {
    if (_speakers.isEmpty) return;

    if (_currentSpeaker == null) {
      _currentSpeaker = _speakers.first;
    } else {
      final currentIndex = _speakers.indexOf(_currentSpeaker!);
      final nextIndex = (currentIndex + 1) % _speakers.length;
      _currentSpeaker = _speakers[nextIndex];
    }
    _lastSpeechTime = DateTime.now();
  }

  /// 이전 화자로 전환
  void switchToPreviousSpeaker() {
    if (_speakers.isEmpty) return;

    if (_currentSpeaker == null) {
      _currentSpeaker = _speakers.last;
    } else {
      final currentIndex = _speakers.indexOf(_currentSpeaker!);
      final previousIndex = (currentIndex - 1 + _speakers.length) % _speakers.length;
      _currentSpeaker = _speakers[previousIndex];
    }
    _lastSpeechTime = DateTime.now();
  }

  /// 기본 화자 목록 생성
  void initializeDefaultSpeakers() {
    final defaultSpeakers = [
      Speaker(
        id: 'speaker_1',
        name: '화자 1',
        color: '#FF6B6B', // 빨강
      ),
      Speaker(
        id: 'speaker_2',
        name: '화자 2',
        color: '#4ECDC4', // 청록
      ),
      Speaker(
        id: 'speaker_3',
        name: '화자 3',
        color: '#45B7D1', // 파랑
      ),
    ];

    for (final speaker in defaultSpeakers) {
      addSpeaker(speaker);
    }
  }

  /// 화자 이름 변경
  void updateSpeakerName(String speakerId, String newName) {
    final index = _speakers.indexWhere((s) => s.id == speakerId);
    if (index != -1) {
      _speakers[index] = _speakers[index].copyWith(name: newName);
      if (_currentSpeaker?.id == speakerId) {
        _currentSpeaker = _speakers[index];
      }
    }
  }

  /// 초기화
  void reset() {
    _speakers.clear();
    _currentSpeaker = null;
    _lastSpeechTime = null;
  }
}
