import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import '../models/meeting.dart';
import '../models/speaker.dart';
import '../models/transcript_segment.dart';
import '../services/speech_service.dart';
import '../services/speaker_detection_service.dart';
import '../services/database_service.dart';

class RecordingScreen extends StatefulWidget {
  const RecordingScreen({super.key});

  @override
  State<RecordingScreen> createState() => _RecordingScreenState();
}

class _RecordingScreenState extends State<RecordingScreen> {
  final SpeechService _speechService = SpeechService();
  final SpeakerDetectionService _speakerService = SpeakerDetectionService();
  final DatabaseService _db = DatabaseService();
  final Uuid _uuid = const Uuid();

  late String _meetingId;
  final TextEditingController _titleController = TextEditingController();
  final List<TranscriptSegment> _segments = [];
  String _currentText = '';
  bool _isRecording = false;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _meetingId = _uuid.v4();
    _titleController.text = '회의록 ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}';
    _initialize();
  }

  Future<void> _initialize() async {
    final initialized = await _speechService.initialize();
    if (initialized) {
      setState(() => _isInitialized = true);
      _speakerService.initializeDefaultSpeakers();
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('음성 인식을 초기화할 수 없습니다. 마이크 권한을 확인하세요.')),
        );
      }
    }
  }

  Future<void> _toggleRecording() async {
    if (!_isInitialized) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('음성 인식이 초기화되지 않았습니다.')),
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
    setState(() => _isRecording = true);

    await _speechService.startListening(
      onResult: (text, confidence) {
        setState(() {
          _currentText = text;
        });
      },
      languageCode: 'ko_KR',
      partialResults: true,
    );
  }

  Future<void> _stopRecording() async {
    await _speechService.stopListening();
    setState(() => _isRecording = false);

    // 현재 텍스트가 있으면 세그먼트로 저장
    if (_currentText.isNotEmpty) {
      _addSegment();
    }
  }

  void _addSegment() {
    if (_currentText.isEmpty || _speakerService.currentSpeaker == null) {
      return;
    }

    final segment = TranscriptSegment(
      id: _uuid.v4(),
      speakerId: _speakerService.currentSpeaker!.id,
      speakerName: _speakerService.currentSpeaker!.name,
      text: _currentText,
      timestamp: DateTime.now(),
      confidence: 1.0,
    );

    setState(() {
      _segments.add(segment);
      _currentText = '';
    });
  }

  void _switchSpeaker() {
    // 현재 텍스트를 세그먼트로 저장
    if (_currentText.isNotEmpty) {
      _addSegment();
    }

    _speakerService.switchToNextSpeaker();
    setState(() {});

    if (_isRecording) {
      // 녹음 중이면 계속 녹음
      _startRecording();
    }
  }

  Future<void> _saveMeeting() async {
    // 현재 텍스트가 있으면 저장
    if (_currentText.isNotEmpty) {
      _addSegment();
    }

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
    if (_segments.isEmpty && _currentText.isEmpty) {
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
    _speechService.dispose();
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('회의록 녹음'),
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

            // 현재 인식 중인 텍스트
            if (_currentText.isNotEmpty) _buildCurrentText(),

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
                      if (_currentText.isNotEmpty) {
                        _addSegment();
                      }
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

  Widget _buildCurrentText() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary,
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.mic,
                color: Theme.of(context).colorScheme.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                _speakerService.currentSpeaker?.name ?? '',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _currentText,
            style: const TextStyle(fontSize: 16),
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
            onPressed: _switchSpeaker,
            icon: const Icon(Icons.people),
            tooltip: '화자 전환',
            iconSize: 32,
          ),

          // 녹음/중지 버튼
          FloatingActionButton.large(
            onPressed: _isInitialized ? _toggleRecording : null,
            backgroundColor: _isRecording
                ? Theme.of(context).colorScheme.error
                : Theme.of(context).colorScheme.primary,
            child: Icon(
              _isRecording ? Icons.stop : Icons.mic,
              size: 40,
            ),
          ),

          // 세그먼트 추가 버튼 (수동)
          IconButton.filled(
            onPressed: _currentText.isNotEmpty ? _addSegment : null,
            icon: const Icon(Icons.add),
            tooltip: '세그먼트 추가',
            iconSize: 32,
          ),
        ],
      ),
    );
  }
}
