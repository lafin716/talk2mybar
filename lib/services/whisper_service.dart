import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:whisper_flutter/whisper_flutter.dart';

/// Whisper.cpp 기반 온디바이스 AI 음성 인식 서비스
class WhisperService {
  Whisper? _whisper;
  bool _isInitialized = false;
  String? _modelPath;

  bool get isInitialized => _isInitialized;

  /// Whisper 초기화
  /// modelPath: 모델 파일 경로 (예: ggml-base.bin)
  Future<bool> initialize({String? modelPath}) async {
    if (_isInitialized) return true;

    try {
      // 마이크 권한 확인
      final status = await Permission.microphone.request();
      if (!status.isGranted) {
        print('마이크 권한이 거부되었습니다.');
        return false;
      }

      // 모델 경로 설정
      if (modelPath != null) {
        _modelPath = modelPath;
      } else {
        // 기본 모델 경로 (assets 또는 다운로드된 위치)
        final appDir = await getApplicationDocumentsDirectory();
        _modelPath = '${appDir.path}/models/ggml-base.bin';
      }

      // 모델 파일 존재 확인
      if (!await File(_modelPath!).exists()) {
        print('모델 파일을 찾을 수 없습니다: $_modelPath');
        return false;
      }

      // Whisper 초기화
      _whisper = Whisper(
        model: _modelPath!,
        language: 'ko', // 한국어
        threads: 4, // CPU 코어 수에 맞게 조정
        translate: false, // 번역 안 함
      );

      _isInitialized = true;
      print('Whisper 초기화 성공: $_modelPath');
      return true;
    } catch (e) {
      print('Whisper 초기화 실패: $e');
      return false;
    }
  }

  /// 오디오 파일을 텍스트로 변환
  /// audioPath: 녹음된 오디오 파일 경로 (WAV 또는 M4A)
  /// Returns: 변환된 텍스트와 세그먼트 정보
  Future<WhisperTranscription?> transcribeFile(String audioPath) async {
    if (!_isInitialized || _whisper == null) {
      throw Exception('Whisper가 초기화되지 않았습니다.');
    }

    if (!await File(audioPath).exists()) {
      throw Exception('오디오 파일을 찾을 수 없습니다: $audioPath');
    }

    try {
      print('음성 인식 시작: $audioPath');
      final result = await _whisper!.transcribe(audioPath);
      print('음성 인식 완료');
      return result;
    } catch (e) {
      print('음성 인식 실패: $e');
      return null;
    }
  }

  /// 스트림 방식으로 음성 인식 (실시간)
  /// 참고: Whisper는 기본적으로 파일 기반이므로 실시간은 제한적
  Stream<String> transcribeStream(String audioPath) async* {
    final result = await transcribeFile(audioPath);
    if (result != null) {
      yield result.text;
    }
  }

  /// 사용 가능한 모델 목록
  List<WhisperModel> getAvailableModels() {
    return [
      WhisperModel(
        name: 'Tiny',
        fileName: 'ggml-tiny.bin',
        size: '75 MB',
        description: '가장 빠르지만 정확도가 낮음',
      ),
      WhisperModel(
        name: 'Base',
        fileName: 'ggml-base.bin',
        size: '142 MB',
        description: '균형잡힌 속도와 정확도',
      ),
      WhisperModel(
        name: 'Small',
        fileName: 'ggml-small.bin',
        size: '466 MB',
        description: '높은 정확도, 느린 속도',
      ),
      WhisperModel(
        name: 'Medium',
        fileName: 'ggml-medium.bin',
        size: '1.5 GB',
        description: '매우 높은 정확도, 매우 느림',
      ),
    ];
  }

  /// 현재 사용 중인 모델 경로
  String? get currentModelPath => _modelPath;

  /// 리소스 정리
  void dispose() {
    _whisper = null;
    _isInitialized = false;
  }
}

/// Whisper 변환 결과
class WhisperTranscription {
  final String text; // 전체 텍스트
  final List<WhisperSegment> segments; // 세그먼트 목록
  final String language; // 감지된 언어

  WhisperTranscription({
    required this.text,
    required this.segments,
    required this.language,
  });
}

/// Whisper 세그먼트 (시간별 텍스트)
class WhisperSegment {
  final String text;
  final int startTime; // 밀리초
  final int endTime; // 밀리초

  WhisperSegment({
    required this.text,
    required this.startTime,
    required this.endTime,
  });

  Duration get start => Duration(milliseconds: startTime);
  Duration get end => Duration(milliseconds: endTime);
  Duration get duration => end - start;
}

/// Whisper 모델 정보
class WhisperModel {
  final String name;
  final String fileName;
  final String size;
  final String description;

  WhisperModel({
    required this.name,
    required this.fileName,
    required this.size,
    required this.description,
  });
}
