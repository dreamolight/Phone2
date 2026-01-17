import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'background_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../api/api_service.dart';

class UploaderScreen extends ConsumerStatefulWidget {
  const UploaderScreen({super.key});

  @override
  ConsumerState<UploaderScreen> createState() => _UploaderScreenState();
}



class _UploaderScreenState extends ConsumerState<UploaderScreen> with WidgetsBindingObserver {
  bool _isRunning = false;
  Map<String, dynamic> _lastProgress = {};
  
  // Permissions State
  PermissionStatus _statusSms = PermissionStatus.denied;
  PermissionStatus _statusPhone = PermissionStatus.denied;
  PermissionStatus _statusContacts = PermissionStatus.denied;
  PermissionStatus _statusNotification = PermissionStatus.denied;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkPermissions();
    _checkServiceStatus();
    FlutterBackgroundService().on('progress').listen((event) {
      if (mounted && event != null) {
        // STRICTLY IGNORE HEARTBEATS to prevent UI flickering/updates
        if (event['status'] == 'heartbeat') return;
        
        setState(() => _lastProgress = event);
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkPermissions();
      _checkServiceStatus();
    }
  }

  Future<void> _checkPermissions() async {
    final sms = await Permission.sms.status;
    final phone = await Permission.phone.status;
    final contacts = await Permission.contacts.status;
    final notif = await Permission.notification.status;
    
    if (mounted) {
      setState(() {
        _statusSms = sms;
        _statusPhone = phone;
        _statusContacts = contacts;
        _statusNotification = notif;
      });
    }
  }

  Future<void> _checkServiceStatus() async {
    final isRunning = await FlutterBackgroundService().isRunning();
    setState(() => _isRunning = isRunning);
  }

  Future<void> _toggleService() async {
    final service = FlutterBackgroundService();
    if (_isRunning) {
      service.invoke("stopService");
      setState(() => _isRunning = false);
    } else {
      // Request Permissions first
      Map<Permission, PermissionStatus> statuses = await [
        Permission.sms,
        Permission.phone,
        Permission.contacts,
        Permission.ignoreBatteryOptimizations,
        Permission.notification,
      ].request();
      
      // Refresh status vars
      await _checkPermissions();

      if (statuses.values.every((status) => status.isGranted)) {
        // ... (Start Service Logic) ...
        final api = ref.read(apiServiceProvider);
        final token = await api.getToken();
        if (token != null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('jwt_token_plain', token);
        }

        await initializeService();
        service.startService();
        setState(() => _isRunning = true);
      } else {
        // Just checking is enough, the UI below will show what's wrong.
        // We can show a snackbar to prompt them to look below.
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
             const SnackBar(content: Text('Please grant all permissions below to start.')),
           );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
       return Scaffold(
          appBar: AppBar(title: const Text('Phone 2')),
          body: const Center(child: Text('Uploader mode is only available on Android.')),
       );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Phone 2')),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(color: Colors.deepPurpleAccent),
              child: Text('Phone 2', style: TextStyle(color: Colors.white, fontSize: 24)),
            ),
            ListTile(
              leading: const Icon(Icons.cloud_sync),
              title: const Text('Re-upload All Data'),
              onTap: () {
                 Navigator.pop(context);
                 setState(() {
                    _lastProgress = {
                      'status': 'starting', 
                      'smsCount': 0, 
                      'callCount': 0,
                      'uploaded': 0,
                      'total': 0,
                    };
                 });
                 FlutterBackgroundService().invoke("force_sync_all");
                 ScaffoldMessenger.of(context).showSnackBar(
                   const SnackBar(content: Text('Re-uploading ALL data. This may take a while...')),
                 );
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.swap_horiz),
              title: const Text('Switch Mode'),
              onTap: () {
                 if (mounted) context.go('/mode_selection');
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('Settings'),
              onTap: () {
                 if (mounted) context.go('/settings');
              },
            ),
            const Divider(),
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
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Refactored Status Block
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: _isRunning ? Colors.green : Colors.red,
                      shape: BoxShape.circle,
                      boxShadow: [
                         BoxShadow(
                           color: (_isRunning ? Colors.green : Colors.red).withOpacity(0.5),
                           blurRadius: 10,
                           spreadRadius: 2,
                         )
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    _getMainStatusText(),
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 20),
                  ElevatedButton(
                    onPressed: _toggleService,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                       backgroundColor: Colors.grey[200],
                       foregroundColor: Colors.black,
                    ),
                    child: Text(_isRunning ? 'STOP' : 'START'),
                  ),
                ],
              ),

              const SizedBox(height: 30),

              // --- Permissions Section ---
              Card(
                elevation: 0,
                color: Colors.grey.withOpacity(0.1),
                margin: const EdgeInsets.only(bottom: 20),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                        const Text(
                          "Permissions Required", 
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          "The app needs the following permissions to function well.",
                          style: TextStyle(fontSize: 13, color: Colors.grey),
                        ),
                        const SizedBox(height: 12),
                        _buildPermissionRow("SMS Access", _statusSms),
                        _buildPermissionRow("Phone Logs", _statusPhone),
                        _buildPermissionRow("Contacts", _statusContacts),
                        _buildPermissionRow("Notifications", _statusNotification),
                        
                        const SizedBox(height: 12),
                        Center(
                          child: TextButton(
                            onPressed: () => openAppSettings(),
                            child: const Text("Open App Settings"),
                          ),
                        )
                    ],
                  ),
                ),
              ),
              
              // --- Sync Status Section ---
              if (_isRunning) ...[
                // Sync Activity Section - Always visible if service running
                const Divider(),
                const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Text("Sync Activity", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
                
                // Show Progress Bar (Only when uploading)
                if (_lastProgress['status'] == 'uploading') ...[
                      LinearProgressIndicator(
                        value: (_lastProgress['total'] != null && _lastProgress['total'] > 0 && _lastProgress['uploaded'] != null)
                            ? (_lastProgress['uploaded'] / _lastProgress['total'])
                            : null,
                      ),
                      if (_lastProgress['total'] != null)
                         Padding(
                           padding: const EdgeInsets.only(top: 8.0),
                           child: Text(
                             "Uploaded ${_lastProgress['uploaded']} / ${_lastProgress['total']}",
                             style: const TextStyle(fontWeight: FontWeight.bold),
                           ),
                         ),
                      const SizedBox(height: 10),
                ],
                  
                Card(
                  margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 10),
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        Text(
                          _getFriendlyStatus(_lastProgress['status']),
                          style: const TextStyle(fontSize: 16, color: Colors.blueGrey, fontWeight: FontWeight.w500),
                        ),
                        const Divider(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _buildStatItem('Messages', '${_lastProgress['smsCount'] ?? 0}'),
                            _buildVerticalDivider(),
                            _buildStatItem('Calls', '${_lastProgress['callCount'] ?? 0}'),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: (_shouldShowProgress && _lastProgress['status'] != 'error') ? null : () {
                     // Immediate feedback
                     setState(() {
                        _lastProgress = {
                          'status': 'starting',
                          'smsCount': 0, 
                          'callCount': 0,
                          'uploaded': 0,
                          'total': 0,
                        };
                     });
                     FlutterBackgroundService().invoke("force_sync");
                     ScaffoldMessenger.of(context).showSnackBar(
                       const SnackBar(content: Text('Manual upload triggered')),
                     );
                  },
                  icon: const Icon(Icons.cloud_upload),
                  label: (_shouldShowProgress && _lastProgress['status'] != 'error') ? const Text("Syncing...") : const Text("Upload Now"),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }


  bool get _shouldShowProgress {
    final s = _lastProgress['status'];
    return s == 'starting' || 
           s == 'reading_contacts' || 
           s == 'reading_sms' || 
           s == 'reading_sms_done' || 
           s == 'reading_calls' || 
           s == 'reading_calls_done' || 
           s == 'uploading' || 
           s == 'error';
  }

  String _getMainStatusText() {
    if (!_isRunning) return 'Service Stopped';
    if (_shouldShowProgress) {
      if (_lastProgress['status'] == 'uploading') return 'Uploading...';
      return 'Syncing...';
    }
    return 'Service Active';
  }

  String _getFriendlyStatus(String? status) {
    if (status == null || status == 'idle') return 'No uploading in progress';
    switch (status) {
      case 'starting': return 'Starting Sync...';
      case 'reading_contacts': return 'Reading Contacts...';
      case 'reading_sms': return 'Reading Messages...';
      case 'reading_sms_done': return 'Analyzing Messages...';
      case 'reading_calls': return 'Reading Call Logs...';
      case 'reading_calls_done': return 'Preparing Upload...';
      case 'uploading': 
          if (_lastProgress['total'] != null && _lastProgress['total'] > 0) {
             return 'Uploading (${((_lastProgress['uploaded'] / _lastProgress['total'])*100).toStringAsFixed(0)}%)...';
          }
          return 'Uploading Data...';
      case 'completed': return 'Sync Completed (Waiting)';
      case 'error': return 'Error Occurred';
      case 'heartbeat': return 'Service Active (Heartbeat)';
      default: return status;
    }
  }

  String _formatTime(String isoString) {
    try {
      final dt = DateTime.parse(isoString).toLocal();
      return "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}";
    } catch (e) {
      return isoString;
    }
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.grey)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
      ],
    );
  }

  Widget _buildVerticalDivider() {
    return Container(height: 30, width: 1, color: Colors.grey.shade300);
  }
  
  Widget _buildPermissionRow(String label, PermissionStatus status) {
    Color color;
    IconData icon;
    
    if (status.isGranted) {
      color = Colors.green;
      icon = Icons.check_circle;
    } else if (status.isDenied) {
      color = Colors.red;
      icon = Icons.cancel;
    } else {
      color = Colors.orange;
      icon = Icons.help;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Text(label, style: const TextStyle(fontSize: 15)),
          const Spacer(),
          Text(
             status.isGranted ? "Granted" : "Denied", 
             style: TextStyle(color: color, fontSize: 13)
          ),
        ],
      ),
    );
  }
}
