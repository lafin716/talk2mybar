import 'dart:io';
import 'package:whisper_ggml/whisper_ggml.dart';

/// Whisper 모델 관리 서비스
/// whisper_ggml이 자동 다운로드를 지원하므로 주로 모델 정보 제공 역할
class ModelDownloadService {
  static final ModelDownloadService _instance = ModelDownloadService._internal();
  factory ModelDownloadService() => _instance;
  ModelDownloadService._internal();

  final WhisperController _whisperController = WhisperController();

  /// 모델 다운로드
  /// whisper_ggml의 자동 다운로드 기능 사용
  Future<bool> downloadModel(WhisperModel model) async {
    try {
      print('모델 다운로드 시작: ${model.name}');
      await _whisperController.downloadModel(model);
      print('모델 다운로드 완료: ${model.name}');
      return true;
    } catch (e) {
      print('모델 다운로드 실패: $e');
      return false;
    }
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

  /// 모델 파일 경로 가져오기
  Future<String> getModelPath(WhisperModel model) async {
    return await _whisperController.getPath(model);
  }

  /// 모델 파일 크기 조회
  Future<int?> getModelSize(WhisperModel model) async {
    try {
      final path = await _whisperController.getPath(model);
      final file = File(path);

      if (await file.exists()) {
        return await file.length();
      }
      return null;
    } catch (e) {
      print('모델 크기 조회 실패: $e');
      return null;
    }
  }

  /// 모델 삭제
  Future<bool> deleteModel(WhisperModel model) async {
    try {
      final path = await _whisperController.getPath(model);
      final file = File(path);

      if (await file.exists()) {
        await file.delete();
        print('모델 삭제 완료: $path');
        return true;
      }
      return false;
    } catch (e) {
      print('모델 삭제 실패: $e');
      return false;
    }
  }

  /// 권장 모델 정보
  Map<WhisperModel, ModelInfo> getRecommendedModels() {
    return {
      WhisperModel.tiny: ModelInfo(
        model: WhisperModel.tiny,
        name: 'Tiny',
        sizeBytes: 75 * 1024 * 1024, // 75 MB
        description: '가장 빠른 처리 속도, 기본적인 정확도',
        recommended: '저사양 기기, 빠른 응답 필요시',
      ),
      WhisperModel.base: ModelInfo(
        model: WhisperModel.base,
        name: 'Base',
        sizeBytes: 142 * 1024 * 1024, // 142 MB
        description: '균형잡힌 속도와 정확도 (권장)',
        recommended: '대부분의 사용 환경',
      ),
      WhisperModel.small: ModelInfo(
        model: WhisperModel.small,
        name: 'Small',
        sizeBytes: 466 * 1024 * 1024, // 466 MB
        description: '높은 정확도, 느린 처리 속도',
        recommended: '정확도가 중요한 경우',
      ),
      WhisperModel.medium: ModelInfo(
        model: WhisperModel.medium,
        name: 'Medium',
        sizeBytes: 1500 * 1024 * 1024, // 1.5 GB
        description: '최고 정확도, 매우 느린 처리 속도',
        recommended: '고사양 기기, 최고 품질 필요시',
      ),
    };
  }

  /// 모든 모델 다운로드 상태 확인
  Future<Map<WhisperModel, bool>> checkAllModelsStatus() async {
    final status = <WhisperModel, bool>{};

    for (final model in WhisperModel.values) {
      status[model] = await isModelDownloaded(model);
    }

    return status;
  }
}

/// 모델 정보
class ModelInfo {
  final WhisperModel model;
  final String name;
  final int sizeBytes;
  final String description;
  final String recommended;

  ModelInfo({
    required this.model,
    required this.name,
    required this.sizeBytes,
    required this.description,
    required this.recommended,
  });

  String get sizeFormatted {
    if (sizeBytes < 1024 * 1024) {
      return '${(sizeBytes / 1024).toStringAsFixed(0)} KB';
    } else if (sizeBytes < 1024 * 1024 * 1024) {
      return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(0)} MB';
    } else {
      return '${(sizeBytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }
  }
}
