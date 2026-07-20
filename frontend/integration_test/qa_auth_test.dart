import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:frontend/main.dart' as app;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sqflite/sqflite.dart' as sqflite;
import 'test_helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    final dbPath = await databaseFactory.getDatabasesPath();
    final path = p.join(dbPath, 'studio_crm.db');
    await databaseFactory.deleteDatabase(path);
    const storage = FlutterSecureStorage();
    await storage.deleteAll();
  });


  testWidgets('QA Auth Module Button Tests', (tester) async {
    // 0. Setup: Clear secure storage and database to ensure we start at Login
    const storage = FlutterSecureStorage();
    await storage.deleteAll();

    try {
      final dbPath = await sqflite.getDatabasesPath();
      final path = p.join(dbPath, 'spacesio.db');
      await sqflite.deleteDatabase(path);
    } catch (_) {}

    app.main();
    await tester.pumpAndSettle();
    
    // Give app time to figure out initial route
    await tester.pumpAndSettle(const Duration(seconds: 2));

    expect(find.text('Log In'), findsWidgets, reason: 'Should be on Login screen');

    // A02: Log In (empty fields) -> Form validation error "Required"
    await tester.tap(find.text('Log In'));
    await tester.pumpAndSettle();
    expect(find.text('Required'), findsWidgets);

    // A03: Log In (bad creds) -> Snackbar error from API
    await tester.enterText(find.byType(TextFormField).first, 'admin@gmail.com');
    await tester.enterText(find.byType(TextFormField).last, 'wrongpassword123');
    await tester.tap(find.text('Log In'));
    // Do a short pump to allow the request to start and return
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(seconds: 2)); // wait for API
    // Pump again to start the snackbar animation
    await tester.pump(const Duration(milliseconds: 100));
    // Check if error snackbar appears
    expect(find.byType(SnackBar), findsWidgets);
    
    // Clear snackbar
    await tester.pumpAndSettle(const Duration(seconds: 3));

    // A04: Forgot? link -> Opens Reset Password dialog
    await tester.tap(find.text('Forgot?'));
    await tester.pumpAndSettle();
    expect(find.text('Reset Password'), findsOneWidget);
    
    // A06: Send OTP (empty) -> No action (guard/validation)
    await tester.tap(find.text('Send OTP'));
    await tester.pumpAndSettle();
    expect(find.text('Reset Password'), findsOneWidget); // Dialog stays open
    
    // A07: Cancel Forgot Dialog
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Reset Password'), findsNothing);

    // A01: Log In -> Success, redirect to PIN Setup
    await tester.enterText(find.byType(TextFormField).first, 'admin@gmail.com');
    await tester.enterText(find.byType(TextFormField).last, 'admin123');
    await tester.tap(find.text('Log In'));
    await tester.pumpAndSettle();
    
    // Wait for login to complete and navigate to PIN setup
    int loginRetries = 0;
    while(find.text('Security Setup').evaluate().isEmpty && loginRetries < 50) {
      await tester.pump(const Duration(milliseconds: 100));
      loginRetries++;
    }
    expect(find.text('Security Setup'), findsOneWidget, reason: 'Should be on PIN Setup screen');

    // A12: Complete Setup (empty) -> Error validation
    await tester.tap(find.text('Save & Initialize'));
    await tester.pumpAndSettle();
    // Expect some validation error since fields are empty
    expect(find.text('Please fill all fields'), findsWidgets);

    // A11: Complete Setup -> Success, redirect to main app
    final textFields = find.byType(TextField);
    await tester.enterText(textFields.first, '1111'); // normal pin
    await tester.enterText(textFields.last, '999999');  // ghost mode pin (6 digits required)
    await tester.tap(find.text('Save & Initialize'));
    await tester.pumpAndSettle();
    
    int unlockRetries = 0;
    while(find.text('Session Locked').evaluate().isEmpty && unlockRetries < 50) {
      await tester.pump(const Duration(milliseconds: 100));
      unlockRetries++;
    }
    expect(find.text('Session Locked'), findsOneWidget, reason: 'Should redirect to PIN entry to unlock session');

    // A13: Unlock (correct)
    await enterPinViaNumpad(tester, '1111');
    await tester.pumpAndSettle();
    
    int dashboardRetries = 0;
    while(find.text('Command Center').evaluate().isEmpty && dashboardRetries < 50) {
      await tester.pump(const Duration(milliseconds: 100));
      dashboardRetries++;
    }
    expect(find.text('Command Center'), findsOneWidget, reason: 'Should be on Workspace screen');

    // M06 / A16: Logout -> test PIN entry
    // Open Profile via the Home AppBar icon, then tap Logout
    await tester.tap(find.byTooltip('Profile'));
    await tester.pumpAndSettle();
    final logoutFinder = find.text('Logout');
    if (logoutFinder.evaluate().isNotEmpty) {
      await tester.ensureVisible(logoutFinder.last);
      await tester.tap(logoutFinder.last);
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 1));
      
      // We should be back at Login
      int logoutRetries = 0;
      while(find.text('Log In').evaluate().isEmpty && logoutRetries < 50) {
        await tester.pump(const Duration(milliseconds: 100));
        logoutRetries++;
      }
      expect(find.text('Log In'), findsWidgets);
      
      // Login again to test PIN Entry
      await tester.enterText(find.byType(TextFormField).first, 'admin@gmail.com');
      await tester.enterText(find.byType(TextFormField).last, 'admin123');
      await tester.tap(find.text('Log In'));
      await tester.pumpAndSettle();
      
      int pinRetries = 0;
      while(find.text('Session Locked').evaluate().isEmpty && pinRetries < 50) {
        await tester.pump(const Duration(milliseconds: 100));
        pinRetries++;
      }
      expect(find.text('Session Locked'), findsOneWidget);

      // A15: Unlock (wrong) -> Error snackbar
      await enterPinViaNumpad(tester, '0000');
      // Wait for the 600ms auto-submit debounce plus API round trip
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pump(const Duration(seconds: 1)); // wait for API error
      // Pump again to start the snackbar animation
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(SnackBar), findsWidgets, reason: 'Wrong PIN should show snackbar');
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // A13: Unlock (correct)
      await enterPinViaNumpad(tester, '1111');
      await tester.pumpAndSettle();
      
      dashboardRetries = 0;
      while(find.text('Command Center').evaluate().isEmpty && dashboardRetries < 50) {
        await tester.pump(const Duration(milliseconds: 100));
        dashboardRetries++;
      }
      expect(find.text('Command Center'), findsOneWidget);
    }
  });
}
