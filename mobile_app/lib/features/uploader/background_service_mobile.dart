import 'dart:async';
import 'dart:ui';

import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_sms_inbox/flutter_sms_inbox.dart';
import 'package:call_log/call_log.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:permission_handler/permission_handler.dart';
import 'background_api_helper.dart';

Future<void> initializeService() async {
  final service = FlutterBackgroundService();

  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'my_foreground', 
    'MY PROMISED FOREGROUND SERVICE', 
    description: 'This channel is used for important notifications.',
    importance: Importance.low, 
  );

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      autoStart: false,
      isForegroundMode: true,
      notificationChannelId: 'my_foreground',
      initialNotificationTitle: 'Msg & Call Sync',
      initialNotificationContent: 'Initializing',
      foregroundServiceNotificationId: 888,
    ),
    iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: onStart,
    ),
  );
}

@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  return true;
}

@pragma('vm:entry-point')
bool _isSyncing = false;

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();
  print("SERVICE_VERSION_CHECK: v4 (Quick Check Optimized)");
  
  SharedPreferences prefs = await SharedPreferences.getInstance();
  String? token = prefs.getString('jwt_token_plain');
  
  if (service is AndroidServiceInstance) {
    service.on('setAsForeground').listen((event) {
      service.setAsForegroundService();
    });
    service.on('setAsBackground').listen((event) {
      service.setAsBackgroundService();
    });
  }

  service.on('stopService').listen((event) {
    service.stopSelf();
  });

  service.on('force_sync').listen((event) async {
    print("BACKGROUND: Received force_sync event"); // Debug
    if (token == null) {
       final p = await SharedPreferences.getInstance();
       token = p.getString('jwt_token_plain');
    }
    if (token != null) {
       // Manual sync is NEVER silent
       await _performSync(service, token!, forceUpload: false, silent: false);
    }
  });

  service.on('force_sync_all').listen((event) async {
    print("BACKGROUND: Received force_sync_all event"); // Debug
    if (token == null) {
       final p = await SharedPreferences.getInstance();
       token = p.getString('jwt_token_plain');
    }
    if (token != null) {
       await _performSync(service, token!, fetchAll: true, forceUpload: true, silent: false);
    }
  });

  // Start the dynamic scheduling loop
  _scheduleNextTick(service);
}

void _scheduleNextTick(ServiceInstance service) async {
  if (service is AndroidServiceInstance) {
    if (await service.isForegroundService()) {
      service.setForegroundNotificationInfo(
        title: "Msg & Call Sync",
        content: "Active (${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')})",
      );
    }
  }

  // Read config
  SharedPreferences prefs = await SharedPreferences.getInstance();
  int interval = prefs.getInt('sync_interval') ?? 15;
  String? token = prefs.getString('jwt_token_plain');

  // Wait first
  await Future.delayed(Duration(seconds: interval));

  // Perform tick logic
  // print("BACKGROUND: Heartbeat tick (Interval: ${interval}s)"); 
  service.invoke('progress', {
      'status': 'heartbeat',
      'timestamp': DateTime.now().toIso8601String(),
  });

  if (!_isSyncing && token != null) {
      try {
        await _performSync(service, token, fetchAll: false, forceUpload: false, silent: true);
      } catch (e) {
        print('Sync error: $e');
        service.invoke('progress', {
          'status': 'error',
          'error': e.toString(),
          'timestamp': DateTime.now().toIso8601String(),
        });
      }
  }

  // Schedule next
  _scheduleNextTick(service);
}

Future<void> _performSync(ServiceInstance service, String token, {bool fetchAll = false, bool forceUpload = false, bool silent = false}) async {
  if (_isSyncing && !forceUpload) {
     return;
  }

  _isSyncing = true;
  try {
    
    // Quick Check Logic
    // If NOT forced, we first check if there is actually anything new.
    bool hasNewData = false;
    int lastServerSms = 0;
    int lastServerCall = 0;

    if (forceUpload) {
        hasNewData = true; // Always sync if forced
    } else {
        // 1. Fetch Server State
        // Notify 'starting' only if not silent (or maybe skipping this notify entirely until we confirm data?)
        // Let's keep silent=true meaning "don't disturb UI unless we act".
        
        final timestamps = await BackgroundApiHelper.fetchLastTimestamps(token);
        lastServerSms = timestamps['lastSms'] ?? 0;
        lastServerCall = timestamps['lastCall'] ?? 0;

        // 2. Probe Device (Top 10)
        final SmsQuery query = SmsQuery();
        final recentMessages = await query.querySms(
           kinds: [SmsQueryKind.inbox, SmsQueryKind.sent], 
           count: 10,
        );
        if (recentMessages.any((m) => (m.date?.millisecondsSinceEpoch ?? 0) > lastServerSms)) {
           hasNewData = true;
           print("BACKGROUND: New SMS detected via Quick Check");
        } else {
           // Probe Calls
           final recentCalls = await CallLog.get(); // CallLog doesn't support limit in query, so we take(10) from iterable
           final topCalls = recentCalls.take(10);
           if (topCalls.any((c) => (c.timestamp ?? 0) > lastServerCall)) {
              hasNewData = true;
              print("BACKGROUND: New Call detected via Quick Check");
           }
        }
    }

    if (!hasNewData) {
        // Nothing to do.
        if (!silent) {
            service.invoke('progress', {
                'status': 'idle',
                'lastChecked': DateTime.now().toIso8601String(),
            });
        }
        return;
    }

    // --- MAIN SYNC START ---
    print("BACKGROUND: Starting Active Sync (force=$forceUpload)"); // Debug

    if (!silent) {
      service.invoke('progress', {
          'status': 'starting',
          'timestamp': DateTime.now().toIso8601String(),
      });
    }

    // 1a. Cache Contacts 
    // (Only if we are actually syncing)
    Map<String, String> contactMap = {};
    if (await Permission.contacts.isGranted) {
        if (!silent) service.invoke('progress', {'status': 'reading_contacts'});
        try {
        // final contacts = await FastContacts.getAllContacts(); // Removed FastContacts
            // for (var contact in contacts) {
            // for (var phone in contact.phones) {
            //     String cleanPhone = phone.number.replaceAll(RegExp(r'\D'), '');
            //     if (cleanPhone.isNotEmpty) {
            //         contactMap[cleanPhone] = contact.displayName;
            //         contactMap[phone.number] = contact.displayName;
            //     }
            // }
            // }
        } catch (e) { /* ignore */ }
    }

    // 1. Read SMS (DEEP READ)
    // If not fetchAll (which is 10000), but we HAVE new data, we want a decent amount.
    // User requested "all messages newer". 
    // Since we can't query by date, we increase limit to 500 (safe bet for "new" gap).
    // forceUpload/fetchAll use 10000.
    int smsLimit = (fetchAll || forceUpload) ? 10000 : 500;
    
    if (!silent) service.invoke('progress', {'status': 'reading_sms'});
    final SmsQuery query = SmsQuery();
    final messages = await query.querySms(
        kinds: [SmsQueryKind.inbox, SmsQueryKind.sent], 
        count: smsLimit, 
    );
    
    // Filter
    List<SmsMessage> msgsToUpload = messages;
    if (!forceUpload && !fetchAll) {
        msgsToUpload = messages.where((m) => (m.date?.millisecondsSinceEpoch ?? 0) > lastServerSms).toList();
    }
    
    if (!silent) {
        service.invoke('progress', {
            'status': 'reading_sms_done', 
            'smsCount': msgsToUpload.length
        });
    }

    // 2. Read Calls (DEEP READ)
    if (!silent) service.invoke('progress', {'status': 'reading_calls'});
    final calls = await CallLog.get();
    
    // Logic: fetchAll -> ALL. Smart Sync -> ALL (filtered).
    // CallLog doesn't have a limit arg, so .get() brings all.
    List<CallLogEntry> recentCalls = calls.toList();
    if (!fetchAll && !forceUpload) {
        // If not forcing all, maybe limit strictly for performance? 
        // But user said "better completeness". 
        // Let's take up to 500 to match SMS.
        recentCalls = recentCalls.take(500).toList();
    }

    List<CallLogEntry> callsToUpload = recentCalls;
    if (!forceUpload && !fetchAll) {
        callsToUpload = recentCalls.where((c) => (c.timestamp ?? 0) > lastServerCall).toList();
    }

    // Announce ACTUAL Upload
    // Even if silent=true, if we have data, we go LOUD now.
    if (msgsToUpload.isNotEmpty || callsToUpload.isNotEmpty || forceUpload) {
        service.invoke('progress', {
            'status': 'uploading', 
            'smsCount': msgsToUpload.length,
            'callCount': callsToUpload.length,
            'uploaded': 0,
            'total': msgsToUpload.length + callsToUpload.length,
        });
    } else {
        // It's possible Probing said "yes" but Filter said "no" (e.g. deleted message edge case).
        if (!silent) {
             service.invoke('progress', {
                'status': 'idle',
                'lastChecked': DateTime.now().toIso8601String(),
            });
        }
        return; 
    }

    // 3. Transform
    List<Map<String, dynamic>> logs = [];
    
    for (var msg in msgsToUpload) {
        String? name = msg.sender;
        final address = msg.address;
        
        if (name == null || name == address) {
            String? cleanAddr = address?.replaceAll(RegExp(r'\D'), '');
            if (contactMap.containsKey(address)) {
            name = contactMap[address];
            } else if (cleanAddr != null && contactMap.containsKey(cleanAddr)) {
            name = contactMap[cleanAddr];
            } else {
            name = 'Unknown';
            }
        }

        logs.add({
        'type': (msg.kind == SmsMessageKind.received || msg.kind.toString().contains('received') || msg.kind.toString().contains('inbox')) ? 'sms_inbox' : 'sms_sent',
        'remote_number': msg.address,
        'remote_name': name,
        'content': msg.body,
        'timestamp': msg.date?.millisecondsSinceEpoch ?? 0,
        'duration': 0,
        'is_read': msg.isRead ?? false, 
        });
    }

    for (var call in callsToUpload) {
        String type = 'call_unknown';
        if (call.callType == CallType.incoming) type = 'call_incoming';
        else if (call.callType == CallType.outgoing) type = 'call_outgoing';
        else if (call.callType == CallType.missed) type = 'call_missed';

        logs.add({
            'type': type,
            'remote_number': call.number,
            'remote_name': call.name ?? 'Unknown',
            'content': '',
            'timestamp': call.timestamp,
            'duration': call.duration,
            'is_read': (type != 'call_missed'), 
        });
    }

    // 4. Upload Logic (Chunked)
    if (logs.isNotEmpty) {
        int chunkSize = 50; 
        for (var i = 0; i < logs.length; i += chunkSize) {
            int end = (i + chunkSize < logs.length) ? i + chunkSize : logs.length;
            List<Map<String, dynamic>> chunk = logs.sublist(i, end);
            
            await BackgroundApiHelper.uploadLogs(token, chunk);
            
            service.invoke('progress', {
            'status': 'uploading',
            'smsCount': msgsToUpload.length,
            'callCount': callsToUpload.length,
            'uploaded': end,
            'total': logs.length,
            'timestamp': DateTime.now().toIso8601String(),
            });
        }
        
        service.invoke('progress', {
            'status': 'completed',
            'smsCount': msgsToUpload.length,
            'callCount': callsToUpload.length,
            'uploaded': logs.length,
            'total': logs.length,
            'timestamp': DateTime.now().toIso8601String(),
        });
    }


  } finally {
    _isSyncing = false;
  }
}

