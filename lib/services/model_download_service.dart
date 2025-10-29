import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

/// Whisper 모델 다운로드 및 관리 서비스
class ModelDownloadService {
  static final ModelDownloadService _instance = ModelDownloadService._internal();
  factory ModelDownloadService() => _instance;
  ModelDownloadService._internal();

  final Dio _dio = Dio();

  // Hugging Face에서 제공하는 Whisper 모델 URL
  static const String _baseUrl = 'https://huggingface.co/ggerganov/whisper.cpp/resolve/main';

  /// 모델 다운로드
  /// modelName: 모델 파일명 (예: ggml-base.bin)
  /// onProgress: 다운로드 진행률 콜백 (0.0 ~ 1.0)
  Future<String?> downloadModel(
    String modelName, {
    Function(double progress)? onProgress,
  }) async {
    try {
      // 모델 저장 경로 생성
      final appDir = await getApplicationDocumentsDirectory();
      final modelDir = Directory('${appDir.path}/models');

      if (!await modelDir.exists()) {
        await modelDir.create(recursive: true);
      }

      final filePath = '${modelDir.path}/$modelName';

      // 이미 다운로드되어 있는지 확인
      if (await File(filePath).exists()) {
        print('모델이 이미 존재합니다: $filePath');
        return filePath;
      }

      // 다운로드 URL
      final downloadUrl = '$_baseUrl/$modelName';
      print('모델 다운로드 시작: $downloadUrl');

      // 다운로드 진행
      await _dio.download(
        downloadUrl,
        filePath,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            final progress = received / total;
            print('다운로드 진행률: ${(progress * 100).toStringAsFixed(0)}%');
            onProgress?.call(progress);
          }
        },
      );

      print('모델 다운로드 완료: $filePath');
      return filePath;
    } catch (e) {
      print('모델 다운로드 실패: $e');
      return null;
    }
  }

  /// 다운로드된 모델 목록 조회
  Future<List<String>> getDownloadedModels() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final modelDir = Directory('${appDir.path}/models');

      if (!await modelDir.exists()) {
        return [];
      }

      final files = await modelDir.list().toList();
      return files
          .where((file) => file is File && file.path.endsWith('.bin'))
          .map((file) => file.path)
          .toList();
    } catch (e) {
      print('모델 목록 조회 실패: $e');
      return [];
    }
  }

  /// 모델 파일 존재 여부 확인
  Future<bool> isModelDownloaded(String modelName) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final filePath = '${appDir.path}/models/$modelName';
      return await File(filePath).exists();
    } catch (e) {
      print('모델 확인 실패: $e');
      return false;
    }
  }

  /// 모델 파일 경로 가져오기
  Future<String> getModelPath(String modelName) async {
    final appDir = await getApplicationDocumentsDirectory();
    return '${appDir.path}/models/$modelName';
  }

  /// 모델 파일 크기 조회
  Future<int?> getModelSize(String modelName) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final filePath = '${appDir.path}/models/$modelName';
      final file = File(filePath);

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
  Future<bool> deleteModel(String modelName) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final filePath = '${appDir.path}/models/$modelName';
      final file = File(filePath);

      if (await file.exists()) {
        await file.delete();
        print('모델 삭제 완료: $filePath');
        return true;
      }
      return false;
    } catch (e) {
      print('모델 삭제 실패: $e');
      return false;
    }
  }

  /// 전체 모델 디렉토리 삭제
  Future<bool> deleteAllModels() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final modelDir = Directory('${appDir.path}/models');

      if (await modelDir.exists()) {
        await modelDir.delete(recursive: true);
        print('모든 모델 삭제 완료');
        return true;
      }
      return false;
    } catch (e) {
      print('모델 삭제 실패: $e');
      return false;
    }
  }

  /// 권장 모델 정보
  Map<String, ModelInfo> getRecommendedModels() {
    return {
      'ggml-tiny.bin': ModelInfo(
        name: 'Tiny',
        fileName: 'ggml-tiny.bin',
        sizeBytes: 75 * 1024 * 1024, // 75 MB
        description: '가장 빠른 처리 속도, 기본적인 정확도',
        recommended: '저사양 기기, 빠른 응답 필요시',
      ),
      'ggml-base.bin': ModelInfo(
        name: 'Base',
        fileName: 'ggml-base.bin',
        sizeBytes: 142 * 1024 * 1024, // 142 MB
        description: '균형잡힌 속도와 정확도 (권장)',
        recommended: '대부분의 사용 환경',
      ),
      'ggml-small.bin': ModelInfo(
        name: 'Small',
        fileName: 'ggml-small.bin',
        sizeBytes: 466 * 1024 * 1024, // 466 MB
        description: '높은 정확도, 느린 처리 속도',
        recommended: '정확도가 중요한 경우',
      ),
      'ggml-medium.bin': ModelInfo(
        name: 'Medium',
        fileName: 'ggml-medium.bin',
        sizeBytes: 1500 * 1024 * 1024, // 1.5 GB
        description: '최고 정확도, 매우 느린 처리 속도',
        recommended: '고사양 기기, 최고 품질 필요시',
      ),
    };
  }
}

/// 모델 정보
class ModelInfo {
  final String name;
  final String fileName;
  final int sizeBytes;
  final String description;
  final String recommended;

  ModelInfo({
    required this.name,
    required this.fileName,
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
