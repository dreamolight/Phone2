import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../api/api_service.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final String remoteNumber;
  const ChatScreen({super.key, required this.remoteNumber});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  List<dynamic> _messages = [];
  bool _isLoading = true;


  @override
  void initState() {
    super.initState();
    _markRead();
    _fetchMessages();
  }

  Future<void> _fetchMessages() async {
    setState(() => _isLoading = true);
    try {
      final api = ref.read(apiServiceProvider);
      final data = await api.fetchMessages(widget.remoteNumber);
      // Backend returns desc, we might want to reverse for chat view (bottom up)
      setState(() => _messages = data);
    } catch (e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if(mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _markRead() async {
    try {
      final api = ref.read(apiServiceProvider);
      await api.markRead(widget.remoteNumber);
    } catch (e) {
      print("Failed to mark read: $e");
    }
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.remoteNumber)),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    reverse: true, // Start from bottom
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final item = _messages[index];
                      final isSelf = item['type'].toString().contains('sent') || item['type'].toString().contains('outgoing');
                      final content = item['content'] ?? (item['duration'] != null ? 'Call (${item['duration']}s)' : '');
                      final timestamp = int.parse(item['timestamp'].toString());

                      return Align(
                        alignment: isSelf ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isSelf ? Colors.deepPurpleAccent : Colors.grey[800],
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(content, style: const TextStyle(color: Colors.white)),
                              const SizedBox(height: 4),
                              Text(
                                DateFormat('MM/dd HH:mm').format(DateTime.fromMillisecondsSinceEpoch(timestamp)),
                                style: const TextStyle(fontSize: 10, color: Colors.white70),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
            const SizedBox.shrink(),
        ],
      ),
    );
  }
}
