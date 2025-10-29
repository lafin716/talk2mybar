import 'dart:convert';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import '../models/meeting.dart';

/// 구글 드라이브 연동 서비스
class GoogleDriveService {
  static final GoogleDriveService _instance = GoogleDriveService._internal();
  factory GoogleDriveService() => _instance;
  GoogleDriveService._internal();

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [
      drive.DriveApi.driveFileScope,
    ],
  );

  GoogleSignInAccount? _currentUser;
  drive.DriveApi? _driveApi;

  bool get isSignedIn => _currentUser != null;
  GoogleSignInAccount? get currentUser => _currentUser;

  /// 구글 로그인
  Future<bool> signIn() async {
    try {
      final account = await _googleSignIn.signIn();
      if (account != null) {
        _currentUser = account;

        // DriveApi 초기화
        final httpClient = await _googleSignIn.authenticatedClient();
        if (httpClient != null) {
          _driveApi = drive.DriveApi(httpClient);
          return true;
        }
      }
      return false;
    } catch (e) {
      print('Google Sign In Error: $e');
      return false;
    }
  }

  /// 구글 로그아웃
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    _currentUser = null;
    _driveApi = null;
  }

  /// 자동 로그인 시도
  Future<bool> signInSilently() async {
    try {
      final account = await _googleSignIn.signInSilently();
      if (account != null) {
        _currentUser = account;

        final httpClient = await _googleSignIn.authenticatedClient();
        if (httpClient != null) {
          _driveApi = drive.DriveApi(httpClient);
          return true;
        }
      }
      return false;
    } catch (e) {
      print('Silent Sign In Error: $e');
      return false;
    }
  }

  /// 회의록을 구글 드라이브에 텍스트 파일로 저장
  Future<String?> uploadMeeting(Meeting meeting) async {
    if (_driveApi == null) {
      throw Exception('구글 드라이브에 로그인되어 있지 않습니다.');
    }

    try {
      // 회의록을 텍스트로 변환
      final content = meeting.toTranscriptText();
      final contentBytes = utf8.encode(content);

      // 파일 메타데이터 설정
      final driveFile = drive.File();
      driveFile.name = '${meeting.title}.txt';
      driveFile.mimeType = 'text/plain';
      driveFile.description = '회의록 - ${meeting.createdAt}';

      // 파일 업로드
      final media = drive.Media(
        Stream.value(contentBytes),
        contentBytes.length,
      );

      final uploadedFile = await _driveApi!.files.create(
        driveFile,
        uploadMedia: media,
      );

      return uploadedFile.id;
    } catch (e) {
      print('Upload Error: $e');
      return null;
    }
  }

  /// 기존 파일 업데이트
  Future<bool> updateMeeting(String fileId, Meeting meeting) async {
    if (_driveApi == null) {
      throw Exception('구글 드라이브에 로그인되어 있지 않습니다.');
    }

    try {
      // 회의록을 텍스트로 변환
      final content = meeting.toTranscriptText();
      final contentBytes = utf8.encode(content);

      // 파일 메타데이터 설정
      final driveFile = drive.File();
      driveFile.name = '${meeting.title}.txt';
      driveFile.modifiedTime = DateTime.now();

      // 파일 업데이트
      final media = drive.Media(
        Stream.value(contentBytes),
        contentBytes.length,
      );

      await _driveApi!.files.update(
        driveFile,
        fileId,
        uploadMedia: media,
      );

      return true;
    } catch (e) {
      print('Update Error: $e');
      return false;
    }
  }

  /// 파일 삭제
  Future<bool> deleteFile(String fileId) async {
    if (_driveApi == null) {
      throw Exception('구글 드라이브에 로그인되어 있지 않습니다.');
    }

    try {
      await _driveApi!.files.delete(fileId);
      return true;
    } catch (e) {
      print('Delete Error: $e');
      return false;
    }
  }

  /// 내 드라이브의 파일 목록 조회
  Future<List<drive.File>> listFiles() async {
    if (_driveApi == null) {
      throw Exception('구글 드라이브에 로그인되어 있지 않습니다.');
    }

    try {
      final fileList = await _driveApi!.files.list(
        q: "mimeType='text/plain' and trashed=false",
        orderBy: 'modifiedTime desc',
        pageSize: 100,
      );

      return fileList.files ?? [];
    } catch (e) {
      print('List Files Error: $e');
      return [];
    }
  }

  /// 파일 다운로드
  Future<String?> downloadFile(String fileId) async {
    if (_driveApi == null) {
      throw Exception('구글 드라이브에 로그인되어 있지 않습니다.');
    }

    try {
      final media = await _driveApi!.files.get(
        fileId,
        downloadOptions: drive.DownloadOptions.fullMedia,
      ) as drive.Media;

      final bytes = await media.stream.toList();
      final content = utf8.decode(bytes.expand((x) => x).toList());
      return content;
    } catch (e) {
      print('Download Error: $e');
      return null;
    }
  }
}
