import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:frontend/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Unified UX Integration Tests', () {
    testWidgets('Verify Unified UX Navigation renders correctly', (tester) async {
      // Clear previous test session
      await const FlutterSecureStorage().deleteAll();
      

      // Launch the app
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Ensure Login screen is visible
      expect(find.text('Log In'), findsWidgets);

      // Perform Login (Mocked via UI)
      final emailField = find.byType(TextFormField).first;
      final passwordField = find.byType(TextFormField).last;
      final loginBtn = find.byType(ElevatedButton);

      await tester.enterText(emailField, 'admin@gmail.com');
      await tester.enterText(passwordField, 'admin123');
      await tester.tap(loginBtn);
      
      // Wait for navigation and API calls
      await Future.delayed(const Duration(seconds: 2));
      await tester.pumpAndSettle();

      // Handle PIN Setup or Entry if presented
      if (find.text('Security Setup').evaluate().isNotEmpty) {
        final pinFields = find.byType(TextField);
        await tester.enterText(pinFields.first, '2853');
        await tester.enterText(pinFields.last, '280503');
        await tester.tap(find.text('Complete Setup'));
        
        await Future.delayed(const Duration(seconds: 2));
        await tester.pumpAndSettle();
      }
      
      if (find.text('Session Locked').evaluate().isNotEmpty) {
        final pinField = find.byType(TextField);
        await tester.enterText(pinField, '2853');
        await tester.tap(find.text('Unlock'));
        
        await Future.delayed(const Duration(seconds: 2));
        await tester.pumpAndSettle();
      }

      await tester.pumpAndSettle();
      final texts = find.byType(Text).evaluate().map((e) => (e.widget as Text).data).toList();
      print("==== TEXTS ON SCREEN ==== \n$texts\n=========================");

      // 1. Verify Workspace / Command Center
      expect(find.text('Command Center'), findsWidgets);
      expect(find.text('Manager Inbox'), findsWidgets);

      // 2. Navigate to Pipeline
      final pipelineTab = find.text('Pipeline');
      await tester.tap(pipelineTab);
      await tester.pumpAndSettle(const Duration(seconds: 2));
      expect(find.text('Unified Pipeline'), findsWidgets);
      expect(find.text('Active Leads'), findsWidgets);
      
      // 3. Navigate to Profile
      final profileTab = find.text('Profile');
      await tester.tap(profileTab);
      await tester.pumpAndSettle(const Duration(seconds: 2));
      expect(find.text('Profile & Settings'), findsWidgets);
      expect(find.text('Logout'), findsWidgets);
    });
  });
}
