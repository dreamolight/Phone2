import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart';
import '../../api/api_service.dart';
import 'controller_settings_screen.dart';

class ConversationListScreen extends ConsumerStatefulWidget {
  const ConversationListScreen({super.key});

  @override
  ConsumerState<ConversationListScreen> createState() => _ConversationListScreenState();
}

class _ConversationListScreenState extends ConsumerState<ConversationListScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<dynamic> _conversations = [];
  bool _isLoading = true;
  String? _error;
  Map<String, int> _unreadCounts = {'messages': 0, 'calls': 0};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_handleTabSelection);
    _fetchConversations();
    _fetchUnreadCounts();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _handleTabSelection() {
    if (_tabController.indexIsChanging) return;
    _fetchConversations();
    // User requested NOT to auto-mark calls as read on tab switch.
    // if (_tabController.index == 1) { // Calls tab
    //     _markCallsRead();
    // }
  }

  Future<void> _fetchUnreadCounts() async {
      try {
          final api = ref.read(apiServiceProvider);
          final counts = await api.fetchUnreadCounts();
          print('DEBUG: Fetched unread counts: $counts');
          if (mounted) setState(() => _unreadCounts = counts);
      } catch (e) {
          print('Failed to fetch unread counts: $e');
      }
  }

  Future<void> _markCallsRead() async {
      try {
          final api = ref.read(apiServiceProvider);
          await api.markCategoryRead('calls');
          if (mounted) {
              setState(() {
                  _unreadCounts['calls'] = 0;
              });
          }
      } catch (e) {
          print('Failed to mark calls read: $e');
      }
  }

  Future<void> _markAllAsRead() async {
    try {
      final api = ref.read(apiServiceProvider);
      
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Mark All as Read?'),
          content: const Text('This will mark every message and call log as read. This cannot be undone.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Mark Read'),
            ),
          ],
        ),
      );

      if (confirmed == true) {
        await api.markCategoryRead('all');
        // Refresh UI
        _fetchConversations();
        _fetchUnreadCounts();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('All items marked as read')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _fetchConversations() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _conversations = [];
    });
    
    try {
      final api = ref.read(apiServiceProvider);
      // index 0 = Messages, index 1 = Calls
      final category = _tabController.index == 0 ? 'messages' : 'calls';
      
      final data = await api.fetchConversations(category: category);
      setState(() => _conversations = data);
      
      // Also refresh unread counts
      await _fetchUnreadCounts();
    } catch (e) {
      print('Fetch Error: $e');
      setState(() => _error = e.toString());
    } finally {
      if(mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Phone 2'),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(
                child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                        const Text('Messages'),
                        if (_unreadCounts['messages']! > 0) ...[
                            const SizedBox(width: 8),
                            Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                    color: Colors.redAccent,
                                    borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                    _unreadCounts['messages'].toString(),
                                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                            ),
                        ]
                    ],
                ),
            ),
            Tab(
                child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                        const Text('Calls'),
                        if (_unreadCounts['calls']! > 0) ...[
                            const SizedBox(width: 8),
                            Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                    color: Colors.redAccent,
                                    borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                    _unreadCounts['calls'].toString(),
                                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                            ),
                        ]
                    ],
                ),
            ),
          ],
        ),
        actions: [
          IconButton(onPressed: _fetchConversations, icon: const Icon(Icons.refresh)),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(color: Colors.deepPurpleAccent),
              child: Text('Phone 2', style: TextStyle(color: Colors.white, fontSize: 24)),
            ),
            ListTile(
              leading: const Icon(Icons.mark_email_read),
              title: const Text('Mark All as Read'),
              onTap: () async {
                Navigator.pop(context); // Close drawer
                await _markAllAsRead();
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('Settings'),
              onTap: () async {
                Navigator.pop(context); // Close drawer
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ControllerSettingsScreen()),
                );
              },
            ),
            if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android)
              ListTile(
                leading: const Icon(Icons.swap_horiz),
                title: const Text('Switch Mode'),
                onTap: () {
                   if (mounted) context.go('/mode_selection');
                },
              ),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Logout'),
              onTap: () async {
                final api = ref.read(apiServiceProvider);
                await api.logout();
                if (mounted) context.go('/login');
              },
            ),
          ],
        ),
      ),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
            // TODO: Implement new conversation dialog
        },
        child: const Icon(Icons.message),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Failed to load conversations', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.red)),
            ),
            ElevatedButton(onPressed: _fetchConversations, child: const Text('Retry')),
          ],
        ),
      );
    }

    if (_conversations.isEmpty) {
      return const Center(child: Text('No conversations found.'));
    }

    return ListView.separated(
      itemCount: _conversations.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final item = _conversations[index];
        final isSelf = item['type'].toString().contains('sent') || item['type'].toString().contains('outgoing');
        final remoteNumber = item['remote_number'];
        final remoteName = item['remote_name'];
        final timestamp = int.parse(item['timestamp'].toString());
        final content = item['content'] ?? (item['duration'] != null ? 'Duration: ${item['duration']}s' : '');
        final type = item['type'];
        // isSelf already defined above
        print('DEBUG: remote=${item['remote_number']}, type=$type, isSelf=$isSelf');

        IconData leadingIcon = Icons.person;
        if (type == 'call_missed') leadingIcon = Icons.call_missed;
        else if (type == 'call_incoming') leadingIcon = Icons.call_received;
        else if (type == 'call_outgoing') leadingIcon = Icons.call_made;

        return ListTile(
          leading: CircleAvatar(
            child: _tabController.index == 1 
              ? Icon(leadingIcon, size: 20) 
              : Text(remoteName?[0] ?? remoteNumber?[0] ?? '?'),
          ),
          title: Text(
            (remoteName == null || remoteName!.isEmpty || remoteName == 'Unknown') 
                ? (remoteNumber ?? 'Unknown') 
                : remoteName
          ),
          subtitle: Row(
            children: [
              if (isSelf && _tabController.index == 0) 
                const Padding(padding: EdgeInsets.only(right: 4), child: Text('You:', style: TextStyle(fontWeight: FontWeight.bold))),
              
              if (type == 'call_missed')
                const Text('Missed Call', style: TextStyle(color: Colors.red))
              else
                Expanded(child: Text(content, maxLines: 1, overflow: TextOverflow.ellipsis)),
            ],
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                DateFormat('MM/dd HH:mm').format(DateTime.fromMillisecondsSinceEpoch(timestamp)),
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 4),
              if ((item['unread_count'] != null && int.parse(item['unread_count'].toString()) > 0))
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.redAccent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    item['unread_count'].toString(),
                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          ),
          onTap: () async {
            // If calls, maybe show call history detail or just same chat screen?
            // Chat screen supports showing all logs, so it works for both.
            await context.push('/chat', extra: remoteNumber);
            // Refresh list when returning to update unread counts
            _fetchConversations();
          },
        );
      },
    );
  }
}
