import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/meeting.dart';
import '../models/speaker.dart';
import '../models/transcript_segment.dart';

/// 로컬 데이터베이스 서비스
class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'meeting_transcriber.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // 회의 테이블
    await db.execute('''
      CREATE TABLE meetings (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT,
        drive_file_id TEXT
      )
    ''');

    // 화자 테이블
    await db.execute('''
      CREATE TABLE speakers (
        id TEXT PRIMARY KEY,
        meeting_id TEXT NOT NULL,
        name TEXT NOT NULL,
        color TEXT NOT NULL,
        FOREIGN KEY (meeting_id) REFERENCES meetings (id) ON DELETE CASCADE
      )
    ''');

    // 대화 세그먼트 테이블
    await db.execute('''
      CREATE TABLE transcript_segments (
        id TEXT PRIMARY KEY,
        meeting_id TEXT NOT NULL,
        speaker_id TEXT NOT NULL,
        speaker_name TEXT NOT NULL,
        text TEXT NOT NULL,
        timestamp TEXT NOT NULL,
        confidence REAL NOT NULL DEFAULT 1.0,
        FOREIGN KEY (meeting_id) REFERENCES meetings (id) ON DELETE CASCADE,
        FOREIGN KEY (speaker_id) REFERENCES speakers (id)
      )
    ''');

    // 인덱스 생성
    await db.execute(
        'CREATE INDEX idx_segments_meeting ON transcript_segments(meeting_id)');
    await db.execute(
        'CREATE INDEX idx_speakers_meeting ON speakers(meeting_id)');
  }

  // 회의 저장
  Future<void> saveMeeting(Meeting meeting) async {
    final db = await database;
    await db.insert(
      'meetings',
      meeting.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    // 화자 저장
    for (final speaker in meeting.speakers) {
      await db.insert(
        'speakers',
        {
          ...speaker.toMap(),
          'meeting_id': meeting.id,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    // 세그먼트 저장
    for (final segment in meeting.segments) {
      await db.insert(
        'transcript_segments',
        {
          ...segment.toMap(),
          'meeting_id': meeting.id,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  // 회의 목록 조회
  Future<List<Meeting>> getMeetings() async {
    final db = await database;
    final maps = await db.query(
      'meetings',
      orderBy: 'created_at DESC',
    );

    return maps.map((map) => Meeting.fromMap(map)).toList();
  }

  // 회의 상세 조회 (화자 및 세그먼트 포함)
  Future<Meeting?> getMeeting(String id) async {
    final db = await database;

    // 회의 정보 조회
    final meetingMaps = await db.query(
      'meetings',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (meetingMaps.isEmpty) return null;

    final meeting = Meeting.fromMap(meetingMaps.first);

    // 화자 정보 조회
    final speakerMaps = await db.query(
      'speakers',
      where: 'meeting_id = ?',
      whereArgs: [id],
    );
    final speakers = speakerMaps.map((map) => Speaker.fromMap(map)).toList();

    // 세그먼트 조회
    final segmentMaps = await db.query(
      'transcript_segments',
      where: 'meeting_id = ?',
      whereArgs: [id],
      orderBy: 'timestamp ASC',
    );
    final segments =
        segmentMaps.map((map) => TranscriptSegment.fromMap(map)).toList();

    return meeting.copyWith(
      speakers: speakers,
      segments: segments,
    );
  }

  // 세그먼트 추가
  Future<void> addSegment(String meetingId, TranscriptSegment segment) async {
    final db = await database;
    await db.insert(
      'transcript_segments',
      {
        ...segment.toMap(),
        'meeting_id': meetingId,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    // 회의 업데이트 시간 갱신
    await db.update(
      'meetings',
      {'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [meetingId],
    );
  }

  // 회의 삭제
  Future<void> deleteMeeting(String id) async {
    final db = await database;
    await db.delete(
      'meetings',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // 회의 제목 업데이트
  Future<void> updateMeetingTitle(String id, String title) async {
    final db = await database;
    await db.update(
      'meetings',
      {
        'title': title,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // 구글 드라이브 파일 ID 업데이트
  Future<void> updateDriveFileId(String meetingId, String driveFileId) async {
    final db = await database;
    await db.update(
      'meetings',
      {'drive_file_id': driveFileId},
      where: 'id = ?',
      whereArgs: [meetingId],
    );
  }
}
