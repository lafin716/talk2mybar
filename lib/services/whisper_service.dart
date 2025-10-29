import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:whisper_ggml/whisper_ggml.dart';

/// Whisper.cpp 기반 온디바이스 AI 음성 인식 서비스
class WhisperService {
  final WhisperController _whisperController = WhisperController();
  bool _isInitialized = false;
  WhisperModel _currentModel = WhisperModel.base;

  bool get isInitialized => _isInitialized;
  WhisperModel get currentModel => _currentModel;

  /// Whisper 초기화
  /// model: 사용할 Whisper 모델 (기본: base)
  Future<bool> initialize({WhisperModel? model}) async {
    if (_isInitialized) return true;

    try {
      // 마이크 권한 확인
      final status = await Permission.microphone.request();
      if (!status.isGranted) {
        print('마이크 권한이 거부되었습니다.');
        return false;
      }

      // 모델 설정
      if (model != null) {
        _currentModel = model;
      }

      // 모델 다운로드 (자동)
      print('모델 다운로드 시작: ${_currentModel.name}');
      await _whisperController.downloadModel(_currentModel);
      print('모델 다운로드 완료');

      _isInitialized = true;
      return true;
    } catch (e) {
      print('Whisper 초기화 실패: $e');
      return false;
    }
  }

  /// 오디오 파일을 텍스트로 변환
  /// audioPath: 녹음된 오디오 파일 경로 (WAV 권장)
  /// language: 언어 코드 ('ko', 'en', 'auto' 등)
  Future<WhisperTranscription?> transcribeFile(
    String audioPath, {
    String language = 'ko',
  }) async {
    if (!_isInitialized) {
      throw Exception('Whisper가 초기화되지 않았습니다.');
    }

    if (!await File(audioPath).exists()) {
      throw Exception('오디오 파일을 찾을 수 없습니다: $audioPath');
    }

    try {
      print('음성 인식 시작: $audioPath (모델: ${_currentModel.name}, 언어: $language)');

      final result = await _whisperController.transcribe(
        model: _currentModel,
        audioPath: audioPath,
        lang: language,
      );

      if (result?.transcription.text != null) {
        print('음성 인식 완료: ${result!.transcription.text}');

        // 세그먼트 정보 파싱
        final segments = <WhisperSegment>[];
        if (result.transcription.segments != null) {
          for (final segment in result.transcription.segments!) {
            segments.add(WhisperSegment(
              text: segment.text,
              startTime: (segment.from * 1000).toInt(),
              endTime: (segment.to * 1000).toInt(),
            ));
          }
        }

        return WhisperTranscription(
          text: result.transcription.text!,
          segments: segments,
          language: language,
        );
      }

      print('음성 인식 결과가 없습니다.');
      return null;
    } catch (e) {
      print('음성 인식 실패: $e');
      return null;
    }
  }

  /// 모델 변경
  Future<bool> changeModel(WhisperModel newModel) async {
    try {
      print('모델 변경: ${_currentModel.name} → ${newModel.name}');

      // 새 모델 다운로드
      await _whisperController.downloadModel(newModel);

      _currentModel = newModel;
      print('모델 변경 완료');
      return true;
    } catch (e) {
      print('모델 변경 실패: $e');
      return false;
    }
  }

  /// 사용 가능한 모델 목록
  List<WhisperModelInfo> getAvailableModels() {
    return [
      WhisperModelInfo(
        model: WhisperModel.tiny,
        name: 'Tiny',
        size: '75 MB',
        description: '가장 빠르지만 정확도가 낮음',
        recommended: '저사양 기기, 빠른 응답 필요시',
      ),
      WhisperModelInfo(
        model: WhisperModel.base,
        name: 'Base',
        size: '142 MB',
        description: '균형잡힌 속도와 정확도 (권장)',
        recommended: '대부분의 사용 환경',
      ),
      WhisperModelInfo(
        model: WhisperModel.small,
        name: 'Small',
        size: '466 MB',
        description: '높은 정확도, 느린 처리 속도',
        recommended: '정확도가 중요한 경우',
      ),
      WhisperModelInfo(
        model: WhisperModel.medium,
        name: 'Medium',
        size: '1.5 GB',
        description: '최고 정확도, 매우 느린 처리 속도',
        recommended: '고사양 기기, 최고 품질 필요시',
      ),
    ];
  }

  /// 모델이 다운로드되어 있는지 확인
  Future<bool> isModelDownloaded(WhisperModel model) async {
    try {
      final path = await _whisperController.getPath(model);
      return await File(path).exists();
    } catch (e) {
      print('모델 확인 실패: $e');
      return false;
    }
  }

  /// 현재 사용 중인 모델 정보
  WhisperModelInfo getCurrentModelInfo() {
    return getAvailableModels().firstWhere(
      (info) => info.model == _currentModel,
      orElse: () => getAvailableModels()[1], // 기본값: Base
    );
  }

  /// 리소스 정리
  void dispose() {
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
class WhisperModelInfo {
  final WhisperModel model;
  final String name;
  final String size;
  final String description;
  final String recommended;

  WhisperModelInfo({
    required this.model,
    required this.name,
    required this.size,
    required this.description,
    required this.recommended,
  });
}
