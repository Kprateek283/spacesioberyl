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


  testWidgets('QA Staff Home Module Tests', (tester) async {
    const storage = FlutterSecureStorage();
    await storage.deleteAll();

    try {
      if (sqflite.databaseFactory is sqflite.DatabaseFactory) {
         final dbPath = await sqflite.getDatabasesPath();
         final path = p.join(dbPath, 'studio_crm.db');
         await sqflite.deleteDatabase(path);
      }
    } catch (_) {}

    app.main();
    await tester.pumpAndSettle();
    
    await tester.pumpAndSettle(const Duration(seconds: 2));

    // -- 1. Login as Staff --
    await tester.enterText(find.byType(TextFormField).first, 'staff@gmail.com');
    await tester.enterText(find.byType(TextFormField).last, 'staff123');
    await tester.tap(find.text('Log In'));
    await tester.pump(const Duration(seconds: 2));

    // Staff logs in directly to Staff Home, no PIN required.
    int homeRetries = 0;
    while(find.text('Studio CRM').evaluate().isEmpty && homeRetries < 50) {
      await tester.pump(const Duration(milliseconds: 100));
      homeRetries++;
    }
    expect(find.text('Studio CRM'), findsOneWidget, reason: 'Should be on Staff Home screen');

    // -- 3. Staff Home Tests --

    // S02: Check-In
    final checkInBtn = find.widgetWithText(ElevatedButton, 'Check-In');
    expect(checkInBtn, findsOneWidget);
    await tester.tap(checkInBtn);
    
    // Wait for API and UI
    int checkInWait = 0;
    while(find.text('Checked in successfully!').evaluate().isEmpty && 
          find.textContaining(RegExp(r'already checked in', caseSensitive: false)).evaluate().isEmpty && 
          checkInWait < 20) {
      await tester.pump(const Duration(milliseconds: 200));
      checkInWait++;
    }

    if (find.text('Checked in successfully!').evaluate().isEmpty &&
        find.textContaining(RegExp(r'already checked in', caseSensitive: false)).evaluate().isEmpty) {
      fail('Failed to Check-in. Texts on screen: ${find.byType(Text).evaluate().map((e) => (e.widget as Text).data).join(', ')}');
    }
    // Wait for snackbar to fully disappear (Snackbars queue up)
    for (int i = 0; i < 5; i++) {
      await tester.pump(const Duration(seconds: 1));
    }

    // S03: Check-Out
    final checkOutBtn = find.widgetWithText(ElevatedButton, 'Check-Out');
    expect(checkOutBtn, findsOneWidget);
    await tester.tap(checkOutBtn);
    
    int checkOutWait = 0;
    while(find.text('Checked out successfully!').evaluate().isEmpty && 
          find.textContaining(RegExp(r'already checked out', caseSensitive: false)).evaluate().isEmpty &&
          find.textContaining(RegExp(r'Check-in required first', caseSensitive: false)).evaluate().isEmpty &&
          checkOutWait < 20) {
      await tester.pump(const Duration(milliseconds: 200));
      checkOutWait++;
    }

    if (find.text('Checked out successfully!').evaluate().isEmpty &&
        find.textContaining(RegExp(r'already checked out', caseSensitive: false)).evaluate().isEmpty &&
        find.textContaining(RegExp(r'Check-in required first', caseSensitive: false)).evaluate().isEmpty) {
      fail('Failed to Check-out. Texts on screen: ${find.byType(Text).evaluate().map((e) => (e.widget as Text).data).join(', ')}');
    }
    for (int i = 0; i < 5; i++) {
      await tester.pump(const Duration(seconds: 1));
    }

    // S04: Working off-site? link
    final offsiteLink = find.text('Working off-site or left early?');
    expect(offsiteLink, findsOneWidget);
    await tester.ensureVisible(offsiteLink);
    await tester.tap(offsiteLink);
    await tester.pump(const Duration(seconds: 2));
    
    expect(find.text('Off-site Pass'), findsOneWidget);

    // S05: Start Time picker
    final startTimeBtn = find.ancestor(
      of: find.text('Start Time'),
      matching: find.byType(Column),
    );
    // Actually, tapping the InkWell. Let's just tap the text that shows the time, or the Icon
    await tester.tap(find.byIcon(Icons.schedule).first);
    await tester.pump(const Duration(seconds: 2));
    
    // Time picker dialog should open, tap OK
    expect(find.text('OK'), findsOneWidget);
    await tester.tap(find.text('OK'));
    await tester.pump(const Duration(seconds: 2));

    // S06: End Time picker
    await tester.tap(find.byIcon(Icons.schedule).last);
    await tester.pump(const Duration(seconds: 2));
    
    // Time picker dialog should open, tap OK
    expect(find.text('OK'), findsOneWidget);
    await tester.tap(find.text('OK'));
    await tester.pump(const Duration(seconds: 2));

    // S07: Submit Request
    await tester.enterText(find.byType(TextField).last, 'Automated Test Off-site');
    await tester.tap(find.text('Submit Request'));
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('Request submitted! Pending admin approval.'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));

    // S08: My Attendance tile
    await tester.tap(find.text('My Attendance'));
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('My Attendance'), findsWidgets); // Appbar has this title
    await tester.tap(find.byTooltip('Back'));
    await tester.pump(const Duration(seconds: 2));

    // S09: My Leaves tile
    await tester.tap(find.text('My Leaves'));
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('My Leaves'), findsWidgets); // Appbar has this title
    await tester.tap(find.byTooltip('Back'));
    await tester.pump(const Duration(seconds: 2));

    // S10: My Expenses tile
    await tester.ensureVisible(find.text('My Expenses'));
    await tester.tap(find.text('My Expenses'));
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('My Expenses'), findsWidgets); // Appbar title
    await tester.tap(find.byTooltip('Back'));
    await tester.pump(const Duration(seconds: 2));

    // S01: Logout icon
    final logoutFinder = find.widgetWithIcon(IconButton, Icons.logout);
    expect(logoutFinder, findsWidgets);
    await tester.tap(logoutFinder.last);
    await tester.pump(const Duration(seconds: 2));
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
