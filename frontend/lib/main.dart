import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'features/auth/providers/auth_provider.dart';
import 'core/theme/app_theme.dart';
import 'core/providers/cache_provider.dart';
import 'core/routes/router.dart';

// Updated import paths to match our new folder structure
import 'screens/auth/login_screen.dart';
import 'features/auth/screens/pin_setup_screen.dart';
import 'features/auth/screens/pin_entry_screen.dart';
import 'core/widgets/main_shell_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  runApp(
    const ProviderScope(
      child: StudioCRMApp(),
    ),
  );
}

class StudioCRMApp extends ConsumerWidget {
  const StudioCRMApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'Studio CRM',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      routerConfig: router,
    );
  }
}

class AuthWrapper extends ConsumerWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);

    if (authState.isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: Color(0xFF0061a4))),
      );
    }

    if (!authState.isAuthenticated) {
      return const LoginScreen();
    }

    if (authState.needsPinSetup) {
      return const PinSetupScreen();
    }

    if (!authState.sessionUnlocked) {
      return const PinEntryScreen();
    }

    // User is authenticated and session is unlocked
    // Trigger cache sync (will fetch and cache vendors, installers, leads)
    ref.watch(cacheBootSyncProvider);

    return const MainShellScreen();
  }
}