import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart' as p;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:frontend/main.dart' as app;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' as sqflite;
import 'package:path/path.dart';

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


  testWidgets('QA Admin Dashboard Module Tests', (tester) async {
    const storage = FlutterSecureStorage();
    await storage.deleteAll();

    try {
      if (sqflite.databaseFactory is sqflite.DatabaseFactory) {
         final dbPath = await sqflite.getDatabasesPath();
         final path = p.join(dbPath, 'spacesio.db');
         await sqflite.deleteDatabase(path);
      }
    } catch (_) {}

    app.main();
    await tester.pumpAndSettle();
    
    await tester.pumpAndSettle(const Duration(seconds: 2));

    // -- 1. Login and Unlock --
    await tester.enterText(find.byType(TextFormField).first, 'admin@gmail.com');
    await tester.enterText(find.byType(TextFormField).last, 'admin123');
    await tester.tap(find.text('Log In'));
    await tester.pumpAndSettle();

    // Check if it's the Setup PIN screen or Unlock screen
    int waitRetries = 0;
    while(find.text('Complete Setup').evaluate().isEmpty && find.text('Unlock').evaluate().isEmpty && waitRetries < 50) {
      await tester.pump(const Duration(milliseconds: 100));
      waitRetries++;
    }

    if (find.text('Complete Setup').evaluate().isNotEmpty) {
      await tester.enterText(find.byType(TextField).first, '1111');
      await tester.enterText(find.byType(TextField).last, '999999');
      await tester.tap(find.text('Complete Setup'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 1));
    }

    // Now at Unlock PIN screen
    await tester.enterText(find.byType(TextField).first, '1111');
    await tester.tap(find.text('Unlock'));
    await tester.pumpAndSettle();

    int dashboardRetries = 0;
    while(find.text('Team Dashboard').evaluate().isEmpty && dashboardRetries < 50) {
      await tester.pump(const Duration(milliseconds: 100));
      dashboardRetries++;
    }
    expect(find.text('Team Dashboard'), findsOneWidget, reason: 'Should be on Admin Dashboard');

    // -- 2. Admin Dashboard Tests --

    // D01: Refresh icon
    expect(find.byIcon(Icons.refresh), findsOneWidget);
    await tester.tap(find.byIcon(Icons.refresh));
    await tester.pumpAndSettle();

    // D05: Summary Cards
    expect(find.text('PRESENT'), findsOneWidget);
    expect(find.text('OVERRIDES'), findsOneWidget);
    expect(find.text('OFF-SITE'), findsOneWidget);
    expect(find.text('ABSENT'), findsOneWidget);

    // D03: Today's Report Tab
    expect(find.text("Today's Report"), findsOneWidget);
    
    // D13: Add Staff FAB
    final addStaffFab = find.widgetWithText(FloatingActionButton, 'Add Staff');
    expect(addStaffFab, findsOneWidget);
    await tester.tap(addStaffFab);
    await tester.pumpAndSettle();
    
    // Verify we navigated to IAM Users screen
    expect(find.text('User Management'), findsOneWidget);
    
    // Go back to Dashboard
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.text('Team Dashboard'), findsOneWidget);

    // D04: Pending Requests Tab
    final pendingTab = find.text("Pending Requests");
    await tester.tap(pendingTab);
    await tester.pumpAndSettle();

    // D12: Test Reject Cancel
    if (find.text('Reject').evaluate().isNotEmpty) {
      await tester.tap(find.text('Reject').first);
      await tester.pumpAndSettle();
      
      // Dialog should open
      expect(find.text('Reject Request'), findsOneWidget);
      
      // D11: Empty reject -> Confirm disabled
      // D12: Cancel
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Reject Request'), findsNothing); // Dialog closed

      // D08: Approve
      await tester.tap(find.text('Approve').first);
      await tester.pumpAndSettle();
      // Should show success snackbar and refresh
      expect(find.text('Override approved successfully'), findsOneWidget);
      await tester.pumpAndSettle(const Duration(seconds: 3));
    }

    // D02: Logout
    final logoutFinder = find.widgetWithIcon(IconButton, Icons.logout);
    expect(logoutFinder, findsWidgets);
    await tester.tap(logoutFinder.last);
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 1));

    // Verify logout
    int logoutRetries = 0;
    while(find.text('Log In').evaluate().isEmpty && logoutRetries < 50) {
      await tester.pump(const Duration(milliseconds: 100));
      logoutRetries++;
    }
    expect(find.text('Log In'), findsWidgets);
  });
}
