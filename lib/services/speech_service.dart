import 'package:speech_to_text/speech_to_text.dart';
import 'package:permission_handler/permission_handler.dart';

/// 음성 인식 서비스 (온디바이스)
class SpeechService {
  final SpeechToText _speechToText = SpeechToText();
  bool _isInitialized = false;
  bool _isListening = false;

  bool get isListening => _isListening;
  bool get isInitialized => _isInitialized;

  /// 초기화 및 권한 요청
  Future<bool> initialize() async {
    if (_isInitialized) return true;

    // 마이크 권한 확인
    final status = await Permission.microphone.request();
    if (!status.isGranted) {
      return false;
    }

    // 음성 인식 초기화
    _isInitialized = await _speechToText.initialize(
      onError: (error) => print('Speech recognition error: $error'),
      onStatus: (status) => print('Speech recognition status: $status'),
    );

    return _isInitialized;
  }

  /// 사용 가능한 언어 목록 조회
  Future<List<String>> getAvailableLanguages() async {
    if (!_isInitialized) {
      await initialize();
    }
    final locales = await _speechToText.locales();
    return locales.map((locale) => locale.localeId).toList();
  }

  /// 음성 인식 시작
  Future<void> startListening({
    required Function(String text, double confidence) onResult,
    String languageCode = 'ko_KR', // 기본 한국어
    bool partialResults = true,
  }) async {
    if (!_isInitialized) {
      final initialized = await initialize();
      if (!initialized) {
        throw Exception('음성 인식을 초기화할 수 없습니다.');
      }
    }

    if (_isListening) {
      await stopListening();
    }

    _isListening = await _speechToText.listen(
      onResult: (result) {
        onResult(result.recognizedWords, result.confidence);
      },
      localeId: languageCode,
      listenMode: ListenMode.dictation, // 연속 받아쓰기 모드
      partialResults: partialResults,
      cancelOnError: false,
      listenFor: const Duration(minutes: 30), // 최대 30분
      pauseFor: const Duration(seconds: 5), // 5초 침묵 후 일시정지
    );
  }

  /// 음성 인식 중지
  Future<void> stopListening() async {
    if (_isListening) {
      await _speechToText.stop();
      _isListening = false;
    }
  }

  /// 음성 인식 일시정지/재개
  Future<void> toggleListening({
    required Function(String text, double confidence) onResult,
    String languageCode = 'ko_KR',
  }) async {
    if (_isListening) {
      await stopListening();
    } else {
      await startListening(
        onResult: onResult,
        languageCode: languageCode,
      );
    }
  }

  /// 음성 레벨 (볼륨) 조회
  double getSoundLevel() {
    return _speechToText.lastRecognizedWords.isNotEmpty
        ? _speechToText.lastRecognizedWords.length / 100.0
        : 0.0;
  }

  /// 리소스 정리
  void dispose() {
    if (_isListening) {
      _speechToText.stop();
    }
    _speechToText.cancel();
  }
}
