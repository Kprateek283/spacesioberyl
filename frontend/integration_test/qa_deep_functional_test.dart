import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:frontend/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Deep Functional Tests', () {
    testWidgets('Simulate deep app interactions and logout', (tester) async {
      // 1. Reset storage to ensure deterministic test
      await const FlutterSecureStorage().deleteAll();
      
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // 2. Perform Login
      final emailField = find.byType(TextField).first;
      final passwordField = find.byType(TextField).last;
      final loginBtn = find.text('Log In');

      await tester.enterText(emailField, 'admin@gmail.com');
      await tester.enterText(passwordField, 'admin123');
      await tester.tap(loginBtn);
      
      await Future.delayed(const Duration(seconds: 2));
      await tester.pumpAndSettle();

      // 3. Handle PIN Security Flow
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

      // 4. Verify Command Center Quick Actions
      expect(find.text('Command Center'), findsWidgets);
      
      // Tap 'Clock In/Out' (empty action, but ensures it's intractable)
      final clockInBtn = find.text('Clock In/Out');
      expect(clockInBtn, findsWidgets);
      await tester.tap(clockInBtn);
      await tester.pumpAndSettle();

      // 5. Navigate to Pipeline & Swipe through stages
      final pipelineTab = find.text('Pipeline');
      await tester.tap(pipelineTab);
      await Future.delayed(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      
      expect(find.text('Unified Pipeline'), findsWidgets);
      expect(find.text('Active Leads'), findsWidgets);
      
      // Swipe the PageView to see 'Awaiting Procurement'
      await tester.fling(find.byType(PageView), const Offset(-800, 0), 1000);
      await tester.pumpAndSettle();
      expect(find.text('Awaiting Procurement'), findsWidgets);

      // Tap the FAB to add a lead
      final fab = find.byType(FloatingActionButton);
      expect(fab, findsWidgets);
      await tester.tap(fab);
      await tester.pumpAndSettle();

      // 6. Navigate to Profile & Perform Logout
      final profileTab = find.text('Profile');
      await tester.tap(profileTab);
      await Future.delayed(const Duration(seconds: 2));
      await tester.pumpAndSettle();

      expect(find.text('Profile & Settings'), findsWidgets);
      
      // Tap Logout
      final logoutBtn = find.text('Logout');
      expect(logoutBtn, findsWidgets);
      await tester.tap(logoutBtn);
      
      await Future.delayed(const Duration(seconds: 2));
      await tester.pumpAndSettle();

      // 7. Verify we are successfully redirected back to Login
      expect(find.text('Log In'), findsWidgets);
    });
  });
}
