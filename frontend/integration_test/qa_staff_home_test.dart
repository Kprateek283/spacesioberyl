import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart' as p;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:frontend/main.dart' as app;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
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

  testWidgets('QA Staff: Workspace quick actions and restricted HR tab',
      (tester) async {
    const storage = FlutterSecureStorage();
    await storage.deleteAll();

    app.main();
    await tester.pumpAndSettle();
    await tester.pumpAndSettle(const Duration(seconds: 2));

    // -- 1. Login as Staff --
    await tester.enterText(find.byType(TextFormField).first, 'staff@gmail.com');
    await tester.enterText(find.byType(TextFormField).last, 'staff123');
    await tester.tap(find.text('Log In'));
    await tester.pumpAndSettle();

    // Every role now requires PIN verification (Setup on first login, Unlock
    // afterwards) -- staff no longer bypasses this like it used to.
    int waitRetries = 0;
    while (find.text('Save & Initialize').evaluate().isEmpty &&
        find.text('Session Locked').evaluate().isEmpty &&
        waitRetries < 50) {
      await tester.pump(const Duration(milliseconds: 100));
      waitRetries++;
    }

    if (find.text('Save & Initialize').evaluate().isNotEmpty) {
      await tester.enterText(find.byType(TextField).first, '1111');
      await tester.enterText(find.byType(TextField).last, '999999');
      await tester.tap(find.text('Save & Initialize'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 1));
    }

    if (find.text('Session Locked').evaluate().isNotEmpty) {
      await enterPinViaNumpad(tester, '1111');
      await tester.pumpAndSettle();
    }

    int homeRetries = 0;
    while (find.text('Command Center').evaluate().isEmpty && homeRetries < 50) {
      await tester.pump(const Duration(milliseconds: 100));
      homeRetries++;
    }
    expect(find.text('Command Center'), findsOneWidget, reason: 'Should be on Workspace screen');

    // -- 2. Quick Actions navigate to the right screens --
    await tester.tap(find.text('Clock In/Out'));
    await tester.pumpAndSettle();
    expect(find.text('My Attendance'), findsWidgets); // AppBar title
    expect(find.widgetWithText(ElevatedButton, 'Check In'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Check Out'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Request Leave'));
    await tester.pumpAndSettle();
    expect(find.text('My Leaves'), findsWidgets);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Claim Expense'));
    await tester.pumpAndSettle();
    expect(find.text('My Expenses'), findsWidgets);
    await tester.pageBack();
    await tester.pumpAndSettle();

    // -- 3. Staff should NOT see admin-only tiles on the HR tab --
    await tester.tap(find.text('HR'));
    await tester.pumpAndSettle();

    expect(find.text('My Attendance'), findsOneWidget);
    expect(find.text('My Leaves'), findsOneWidget);
    expect(find.text('My Expenses'), findsOneWidget);
    expect(find.text('Leave Admin'), findsNothing);
    expect(find.text('Expense Ledger'), findsNothing);
    expect(find.text('User Management'), findsNothing);

    // -- 4. CRM tab should still be reachable for a staff member --
    await tester.tap(find.text('CRM'));
    await tester.pumpAndSettle();
    expect(find.text('Sales Pipeline'), findsOneWidget);

    // -- 5. Logout via the HR tab's Profile icon --
    await tester.tap(find.text('HR'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Profile'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Logout'));
    await tester.pumpAndSettle();

    int logoutRetries = 0;
    while (find.text('Log In').evaluate().isEmpty && logoutRetries < 50) {
      await tester.pump(const Duration(milliseconds: 100));
      logoutRetries++;
    }
    expect(find.text('Log In'), findsWidgets);
  });
}
