import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/meeting.dart';
import '../services/database_service.dart';
import 'recording_screen_whisper.dart';
import 'meeting_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final DatabaseService _db = DatabaseService();
  List<Meeting> _meetings = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMeetings();
  }

  Future<void> _loadMeetings() async {
    setState(() => _isLoading = true);
    try {
      final meetings = await _db.getMeetings();
      setState(() {
        _meetings = meetings;
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

  Future<void> _startNewMeeting() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const RecordingScreenWhisper(),
      ),
    );

    if (result == true) {
      _loadMeetings();
    }
  }

  Future<void> _deleteMeeting(Meeting meeting) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('회의록 삭제'),
        content: Text('${meeting.title}을(를) 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _db.deleteMeeting(meeting.id);
      _loadMeetings();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('회의록'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadMeetings,
            tooltip: '새로고침',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _meetings.isEmpty
              ? _buildEmptyState()
              : _buildMeetingList(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _startNewMeeting,
        icon: const Icon(Icons.mic),
        label: const Text('새 회의록'),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.description_outlined,
            size: 100,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            '회의록이 없습니다',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.grey[600],
                ),
          ),
          const SizedBox(height: 8),
          Text(
            '새 회의록 버튼을 눌러 시작하세요',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[500],
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildMeetingList() {
    return RefreshIndicator(
      onRefresh: _loadMeetings,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _meetings.length,
        itemBuilder: (context, index) {
          final meeting = _meetings[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                child: Icon(
                  Icons.description,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
              title: Text(
                meeting.title,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                DateFormat('yyyy년 MM월 dd일 HH:mm').format(meeting.createdAt),
              ),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () => _deleteMeeting(meeting),
              ),
              onTap: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => MeetingDetailScreen(
                      meetingId: meeting.id,
                    ),
                  ),
                );
                if (result == true) {
                  _loadMeetings();
                }
              },
            ),
          );
        },
      ),
    );
  }
}
