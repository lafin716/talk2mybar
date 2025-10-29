import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import '../models/meeting.dart';
import '../services/database_service.dart';
import '../services/google_drive_service.dart';
import '../utils/transcript_formatter.dart';

class MeetingDetailScreen extends StatefulWidget {
  final String meetingId;

  const MeetingDetailScreen({
    super.key,
    required this.meetingId,
  });

  @override
  State<MeetingDetailScreen> createState() => _MeetingDetailScreenState();
}

class _MeetingDetailScreenState extends State<MeetingDetailScreen> {
  final DatabaseService _db = DatabaseService();
  final GoogleDriveService _driveService = GoogleDriveService();

  Meeting? _meeting;
  bool _isLoading = true;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _loadMeeting();
  }

  Future<void> _loadMeeting() async {
    setState(() => _isLoading = true);
    try {
      final meeting = await _db.getMeeting(widget.meetingId);
      setState(() {
        _meeting = meeting;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('회의록을 불러오는데 실패했습니다: $e')),
        );
      }
    }
  }

  Future<void> _shareTranscript() async {
    if (_meeting == null) return;

    try {
      final text = TranscriptFormatter.toText(_meeting!);
      await Share.share(
        text,
        subject: _meeting!.title,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('공유 실패: $e')),
        );
      }
    }
  }

  Future<void> _copyToClipboard() async {
    if (_meeting == null) return;

    try {
      final text = TranscriptFormatter.toText(_meeting!);
      await Clipboard.setData(ClipboardData(text: text));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('클립보드에 복사되었습니다.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('복사 실패: $e')),
        );
      }
    }
  }

  Future<void> _uploadToDrive() async {
    if (_meeting == null) return;

    setState(() => _isUploading = true);

    try {
      // 로그인 확인
      if (!_driveService.isSignedIn) {
        final signedIn = await _driveService.signIn();
        if (!signedIn) {
          throw Exception('구글 로그인에 실패했습니다.');
        }
      }

      // 업로드
      String? fileId;
      if (_meeting!.driveFileId != null) {
        // 기존 파일 업데이트
        final success = await _driveService.updateMeeting(
          _meeting!.driveFileId!,
          _meeting!,
        );
        if (success) {
          fileId = _meeting!.driveFileId;
        }
      } else {
        // 새 파일 생성
        fileId = await _driveService.uploadMeeting(_meeting!);
      }

      if (fileId != null) {
        // DB 업데이트
        await _db.updateDriveFileId(widget.meetingId, fileId);
        _meeting = _meeting!.copyWith(driveFileId: fileId);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('구글 드라이브에 업로드되었습니다.')),
          );
        }
      } else {
        throw Exception('업로드에 실패했습니다.');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('업로드 실패: $e')),
        );
      }
    } finally {
      setState(() => _isUploading = false);
    }
  }

  Future<void> _editTitle() async {
    if (_meeting == null) return;

    final controller = TextEditingController(text: _meeting!.title);
    final newTitle = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('제목 수정'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: '제목',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('저장'),
          ),
        ],
      ),
    );

    if (newTitle != null && newTitle.isNotEmpty) {
      await _db.updateMeetingTitle(widget.meetingId, newTitle);
      _loadMeeting();
    }
  }

  void _showFormatOptions() {
    if (_meeting == null) return;

    showModalBottomSheet(
      context: context,
      builder: (context) => ListView(
        shrinkWrap: true,
        children: [
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              '포맷 선택',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.text_fields),
            title: const Text('기본 텍스트'),
            onTap: () {
              Navigator.pop(context);
              _showFormattedText(TranscriptFormatter.toText(_meeting!));
            },
          ),
          ListTile(
            leading: const Icon(Icons.timer),
            title: const Text('타임스탬프 포함'),
            onTap: () {
              Navigator.pop(context);
              _showFormattedText(TranscriptFormatter.toTimestampedText(_meeting!));
            },
          ),
          ListTile(
            leading: const Icon(Icons.notes),
            title: const Text('간단한 형식'),
            onTap: () {
              Navigator.pop(context);
              _showFormattedText(TranscriptFormatter.toSimpleText(_meeting!));
            },
          ),
          ListTile(
            leading: const Icon(Icons.markdown),
            title: const Text('Markdown'),
            onTap: () {
              Navigator.pop(context);
              _showFormattedText(TranscriptFormatter.toMarkdown(_meeting!));
            },
          ),
          ListTile(
            leading: const Icon(Icons.bar_chart),
            title: const Text('통계'),
            onTap: () {
              Navigator.pop(context);
              _showFormattedText(TranscriptFormatter.getStatistics(_meeting!));
            },
          ),
        ],
      ),
    );
  }

  void _showFormattedText(String text) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('포맷팅된 대본'),
        content: SingleChildScrollView(
          child: SelectableText(text),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: text));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('클립보드에 복사되었습니다.')),
              );
            },
            child: const Text('복사'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('닫기'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('회의록 상세'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: _editTitle,
            tooltip: '제목 수정',
          ),
          IconButton(
            icon: const Icon(Icons.format_list_bulleted),
            onPressed: _showFormatOptions,
            tooltip: '포맷',
          ),
          PopupMenuButton(
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'share',
                child: Row(
                  children: [
                    Icon(Icons.share),
                    SizedBox(width: 8),
                    Text('공유'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'copy',
                child: Row(
                  children: [
                    Icon(Icons.copy),
                    SizedBox(width: 8),
                    Text('복사'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'drive',
                child: Row(
                  children: [
                    Icon(Icons.cloud_upload),
                    SizedBox(width: 8),
                    Text('구글 드라이브'),
                  ],
                ),
              ),
            ],
            onSelected: (value) {
              switch (value) {
                case 'share':
                  _shareTranscript();
                  break;
                case 'copy':
                  _copyToClipboard();
                  break;
                case 'drive':
                  _uploadToDrive();
                  break;
              }
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _meeting == null
              ? const Center(child: Text('회의록을 찾을 수 없습니다.'))
              : _buildContent(),
    );
  }

  Widget _buildContent() {
    return Column(
      children: [
        // 헤더
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _meeting!.title,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                DateFormat('yyyy년 MM월 dd일 HH:mm').format(_meeting!.createdAt),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[700],
                    ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: _meeting!.speakers.map((speaker) {
                  return Chip(
                    avatar: CircleAvatar(
                      backgroundColor: Color(
                        int.parse(speaker.color.substring(1), radix: 16) + 0xFF000000,
                      ),
                    ),
                    label: Text(speaker.name),
                  );
                }).toList(),
              ),
              if (_meeting!.driveFileId != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.cloud_done,
                      size: 16,
                      color: Colors.green[700],
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '구글 드라이브에 저장됨',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.green[700],
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),

        // 세그먼트 목록
        Expanded(
          child: _meeting!.segments.isEmpty
              ? const Center(child: Text('대화 내용이 없습니다.'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _meeting!.segments.length,
                  itemBuilder: (context, index) {
                    final segment = _meeting!.segments[index];
                    final speaker = _meeting!.speakers.firstWhere(
                      (s) => s.id == segment.speakerId,
                      orElse: () => _meeting!.speakers.first,
                    );

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: Color(
                                    int.parse(speaker.color.substring(1), radix: 16) +
                                        0xFF000000,
                                  ),
                                  radius: 16,
                                  child: Text(
                                    speaker.name[0],
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        speaker.name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        DateFormat('HH:mm:ss').format(segment.timestamp),
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              segment.text,
                              style: const TextStyle(fontSize: 15),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),

        if (_isUploading)
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.black26,
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 16),
                Text('구글 드라이브에 업로드 중...'),
              ],
            ),
          ),
      ],
    );
  }
}
