import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  int _syncInterval = 15; // Default 15s

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _syncInterval = prefs.getInt('sync_interval') ?? 15;
    });
  }

  Future<void> _saveInterval(int interval) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('sync_interval', interval);
    setState(() {
      _syncInterval = interval;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'Sync Configuration',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.deepPurpleAccent),
            ),
          ),
          ListTile(
            title: const Text('Heartbeat Interval'),
            subtitle: const Text('How often the app checks for new messages and calls to upload.'),
          ),
          _buildRadioOption("15 Seconds (Fastest)", 15),
          _buildRadioOption("30 Seconds", 30),
          _buildRadioOption("1 Minute", 60),
          _buildRadioOption("3 Minutes", 180),
          _buildRadioOption("5 Minutes", 300),
          _buildRadioOption("10 Minutes", 600),
          
          const Divider(),
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'Note: Shorter intervals use more battery but sync messages and calls faster.',
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildRadioOption(String label, int value) {
    return RadioListTile<int>(
      title: Text(label),
      value: value,
      groupValue: _syncInterval,
      activeColor: Colors.deepPurpleAccent,
      onChanged: (val) {
        if (val != null) {
          _saveInterval(val);
        }
      },
    );
  }
}
