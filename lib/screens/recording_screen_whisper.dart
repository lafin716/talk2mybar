import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../models/meeting.dart';
import '../models/speaker.dart';
import '../models/transcript_segment.dart';
import '../services/whisper_service.dart';
import '../services/speaker_detection_service.dart';
import '../services/database_service.dart';

class RecordingScreenWhisper extends StatefulWidget {
  const RecordingScreenWhisper({super.key});

  @override
  State<RecordingScreenWhisper> createState() => _RecordingScreenWhisperState();
}

class _RecordingScreenWhisperState extends State<RecordingScreenWhisper> {
  final WhisperService _whisperService = WhisperService();
  final SpeakerDetectionService _speakerService = SpeakerDetectionService();
  final DatabaseService _db = DatabaseService();
  final AudioRecorder _recorder = AudioRecorder();
  final Uuid _uuid = const Uuid();

  late String _meetingId;
  final TextEditingController _titleController = TextEditingController();
  final List<TranscriptSegment> _segments = [];

  bool _isRecording = false;
  bool _isInitialized = false;
  bool _isTranscribing = false;
  String? _currentRecordingPath;
  DateTime? _recordingStartTime;

  @override
  void initState() {
    super.initState();
    _meetingId = _uuid.v4();
    _titleController.text = '회의록 ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}';
    _initialize();
  }

  Future<void> _initialize() async {
    // Whisper 초기화
    final initialized = await _whisperService.initialize();
    if (initialized) {
      setState(() => _isInitialized = true);
      _speakerService.initializeDefaultSpeakers();
    } else {
      if (mounted) {
        // 모델이 없는 경우 다운로드 안내
        _showModelDownloadDialog();
      }
    }
  }

  void _showModelDownloadDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Whisper 모델 필요'),
        content: const Text(
          'Whisper AI 모델이 필요합니다.\n'
          '설정에서 모델을 다운로드해주세요.\n\n'
          '권장: Base 모델 (142 MB)',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: 모델 다운로드 화면으로 이동
            },
            child: const Text('다운로드'),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleRecording() async {
    if (!_isInitialized) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Whisper가 초기화되지 않았습니다.')),
      );
      return;
    }

    if (_isRecording) {
      await _stopRecording();
    } else {
      await _startRecording();
    }
  }

  Future<void> _startRecording() async {
    try {
      // 녹음 권한 확인
      if (!await _recorder.hasPermission()) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('마이크 권한이 필요합니다.')),
        );
        return;
      }

      // 녹음 파일 경로 생성
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      _currentRecordingPath = '${tempDir.path}/recording_$timestamp.wav';

      // 녹음 시작
      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.wav,
          sampleRate: 16000, // Whisper는 16kHz를 권장
          numChannels: 1, // 모노
        ),
        path: _currentRecordingPath!,
      );

      setState(() {
        _isRecording = true;
        _recordingStartTime = DateTime.now();
      });

      print('녹음 시작: $_currentRecordingPath');
    } catch (e) {
      print('녹음 시작 실패: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('녹음 시작 실패: $e')),
        );
      }
    }
  }

  Future<void> _stopRecording() async {
    try {
      // 녹음 중지
      final path = await _recorder.stop();
      setState(() => _isRecording = false);

      if (path == null || _currentRecordingPath == null) {
        print('녹음 파일이 없습니다.');
        return;
      }

      print('녹음 완료: $path');

      // Whisper로 음성 인식 시작
      await _transcribeRecording(path);
    } catch (e) {
      print('녹음 중지 실패: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('녹음 중지 실패: $e')),
        );
      }
    }
  }

  Future<void> _transcribeRecording(String audioPath) async {
    setState(() => _isTranscribing = true);

    try {
      print('Whisper 변환 시작...');

      // Whisper로 음성 인식
      final result = await _whisperService.transcribeFile(audioPath);

      if (result != null && result.text.isNotEmpty) {
        // 세그먼트 추가
        final segment = TranscriptSegment(
          id: _uuid.v4(),
          speakerId: _speakerService.currentSpeaker!.id,
          speakerName: _speakerService.currentSpeaker!.name,
          text: result.text.trim(),
          timestamp: _recordingStartTime ?? DateTime.now(),
          confidence: 1.0,
        );

        setState(() {
          _segments.add(segment);
        });

        print('세그먼트 추가: ${result.text}');
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('음성을 인식하지 못했습니다.')),
          );
        }
      }

      // 임시 파일 삭제
      await File(audioPath).delete();
    } catch (e) {
      print('음성 인식 실패: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('음성 인식 실패: $e')),
        );
      }
    } finally {
      setState(() => _isTranscribing = false);
    }
  }

  void _switchSpeaker() {
    _speakerService.switchToNextSpeaker();
    setState(() {});
  }

  Future<void> _saveMeeting() async {
    if (_segments.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('저장할 내용이 없습니다.')),
      );
      return;
    }

    final meeting = Meeting(
      id: _meetingId,
      title: _titleController.text.trim().isEmpty
          ? '회의록 ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}'
          : _titleController.text,
      createdAt: DateTime.now(),
      speakers: _speakerService.speakers,
      segments: _segments,
    );

    try {
      await _db.saveMeeting(meeting);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('회의록이 저장되었습니다.')),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('저장 실패: $e')),
        );
      }
    }
  }

  Future<bool> _onWillPop() async {
    if (_isRecording) {
      await _recorder.stop();
    }

    if (_segments.isEmpty) {
      return true;
    }

    final shouldPop = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('나가기'),
        content: const Text('저장하지 않은 내용이 있습니다. 나가시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('나가기'),
          ),
        ],
      ),
    );

    return shouldPop ?? false;
  }

  @override
  void dispose() {
    _recorder.dispose();
    _whisperService.dispose();
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('회의록 녹음 (Whisper AI)'),
          actions: [
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: _saveMeeting,
              tooltip: '저장',
            ),
          ],
        ),
        body: Column(
          children: [
            // 제목 입력
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: '회의록 제목',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.title),
                ),
              ),
            ),

            // 현재 화자 표시 및 전환
            _buildSpeakerSelector(),

            // 녹음 상태 표시
            if (_isRecording || _isTranscribing) _buildRecordingStatus(),

            // 세그먼트 목록
            Expanded(
              child: _buildSegmentList(),
            ),

            // 녹음 컨트롤
            _buildRecordingControls(),
          ],
        ),
      ),
    );
  }

  Widget _buildSpeakerSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
      child: Row(
        children: [
          const Text('현재 화자:'),
          const SizedBox(width: 12),
          Expanded(
            child: Wrap(
              spacing: 8,
              children: _speakerService.speakers.map((speaker) {
                final isCurrent = speaker.id == _speakerService.currentSpeaker?.id;
                return ChoiceChip(
                  label: Text(speaker.name),
                  selected: isCurrent,
                  onSelected: (selected) {
                    if (selected) {
                      _speakerService.setCurrentSpeaker(speaker.id);
                      setState(() {});
                    }
                  },
                  avatar: CircleAvatar(
                    backgroundColor: Color(
                      int.parse(speaker.color.substring(1), radix: 16) + 0xFF000000,
                    ),
                    radius: 8,
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecordingStatus() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _isRecording
            ? Colors.red.withOpacity(0.1)
            : Colors.blue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _isRecording ? Colors.red : Colors.blue,
          width: 2,
        ),
      ),
      child: Column(
        children: [
          Icon(
            _isRecording ? Icons.fiber_manual_record : Icons.hourglass_empty,
            color: _isRecording ? Colors.red : Colors.blue,
            size: 48,
          ),
          const SizedBox(height: 8),
          Text(
            _isRecording ? '녹음 중...' : '음성 인식 중...',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: _isRecording ? Colors.red : Colors.blue,
            ),
          ),
          if (_isRecording) ...[
            const SizedBox(height: 8),
            Text(
              _speakerService.currentSpeaker?.name ?? '',
              style: const TextStyle(fontSize: 14),
            ),
          ],
          if (_isTranscribing)
            const Padding(
              padding: EdgeInsets.only(top: 16),
              child: LinearProgressIndicator(),
            ),
        ],
      ),
    );
  }

  Widget _buildSegmentList() {
    if (_segments.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.mic_none,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              '녹음 버튼을 눌러 시작하세요',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Whisper AI가 음성을 텍스트로 변환합니다',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _segments.length,
      itemBuilder: (context, index) {
        final segment = _segments[index];
        final speaker = _speakerService.speakers.firstWhere(
          (s) => s.id == segment.speakerId,
        );

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Color(
                int.parse(speaker.color.substring(1), radix: 16) + 0xFF000000,
              ),
              child: Text(
                speaker.name[0],
                style: const TextStyle(color: Colors.white),
              ),
            ),
            title: Text(
              speaker.name,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(segment.text),
                const SizedBox(height: 4),
                Text(
                  DateFormat('HH:mm:ss').format(segment.timestamp),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline, size: 20),
              onPressed: () {
                setState(() {
                  _segments.removeAt(index);
                });
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildRecordingControls() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // 화자 전환 버튼
          IconButton.filled(
            onPressed: _isRecording ? null : _switchSpeaker,
            icon: const Icon(Icons.people),
            tooltip: '화자 전환',
            iconSize: 32,
          ),

          // 녹음/중지 버튼
          FloatingActionButton.large(
            onPressed: (_isInitialized && !_isTranscribing) ? _toggleRecording : null,
            backgroundColor: _isRecording
                ? Theme.of(context).colorScheme.error
                : Theme.of(context).colorScheme.primary,
            child: _isTranscribing
                ? const CircularProgressIndicator(color: Colors.white)
                : Icon(
                    _isRecording ? Icons.stop : Icons.mic,
                    size: 40,
                  ),
          ),

          // 저장 버튼
          IconButton.filled(
            onPressed: _segments.isNotEmpty && !_isRecording && !_isTranscribing
                ? _saveMeeting
                : null,
            icon: const Icon(Icons.save),
            tooltip: '저장',
            iconSize: 32,
          ),
        ],
      ),
    );
  }
}
