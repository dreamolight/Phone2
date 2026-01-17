import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'api/api_service.dart';
import 'features/auth/login_screen.dart';
import 'features/auth/register_screen.dart';
import 'features/uploader/uploader_screen.dart';
import 'features/controller/conversation_list_screen.dart';
import 'features/controller/chat_screen.dart';
import 'features/controller/chat_screen.dart';
import 'features/uploader/background_service.dart';
import 'features/settings/settings_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeService();
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = GoRouter(
      initialLocation: '/login',
      routes: [
        GoRoute(
          path: '/login',
          builder: (context, state) => const LoginScreen(),
        ),
        GoRoute(
          path: '/register',
          builder: (context, state) => const RegisterScreen(),
        ),
        GoRoute(
          path: '/mode_selection',
          builder: (context, state) => const ModeSelectionScreen(),
        ),
        GoRoute(
          path: '/settings',
          builder: (context, state) => const SettingsScreen(),
        ),
        GoRoute(
          path: '/uploader',
          builder: (context, state) => const UploaderScreen(),
        ),
        GoRoute(
          path: '/controller',
          builder: (context, state) => const ConversationListScreen(),
        ),
        GoRoute(
          path: '/chat',
          builder: (context, state) {
            final remoteNumber = state.extra as String;
            return ChatScreen(remoteNumber: remoteNumber);
          },
        ),
      ],
    );

    return MaterialApp.router(
      title: 'Phone 2',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple, brightness: Brightness.dark),
        textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
      ),
      routerConfig: router,
    );
  }
}

class ModeSelectionScreen extends StatelessWidget {
  const ModeSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Select Mode')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) ...[
              ElevatedButton.icon(
                icon: const Icon(Icons.upload),
                label: const Text('Uploader Mode'),
                onPressed: () => context.go('/uploader'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                ),
              ),
              const SizedBox(height: 20),
            ],
            ElevatedButton.icon(
              icon: const Icon(Icons.dashboard),
              label: const Text('Controller Mode'),
              onPressed: () => context.go('/controller'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
