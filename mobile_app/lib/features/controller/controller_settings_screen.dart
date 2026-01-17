import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ControllerSettingsScreen extends ConsumerWidget {
  const ControllerSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Controller Settings')),
      body: ListView(
        children: const [
           ListTile(
            title: Text('Theme'),
            subtitle: Text('System Default'),
            trailing: Icon(Icons.chevron_right),
            // TODO: Implement theme switching
          ),
           Divider(),
           Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'More settings coming soon...',
              style: TextStyle(color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }
}
