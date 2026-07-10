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

  testWidgets('QA Admin: 5-tab nav and HR admin tools are reachable', (tester) async {
    const storage = FlutterSecureStorage();
    await storage.deleteAll();

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

    // Now at the numpad PIN entry screen
    if (find.text('Session Locked').evaluate().isNotEmpty) {
      await enterPinViaNumpad(tester, '1111');
      await tester.pumpAndSettle();
    }

    int dashboardRetries = 0;
    while (find.text('Command Center').evaluate().isEmpty && dashboardRetries < 50) {
      await tester.pump(const Duration(milliseconds: 100));
      dashboardRetries++;
    }
    expect(find.text('Command Center'), findsOneWidget, reason: 'Should be on Workspace screen');

    // -- 2. Verify the 5-tab bottom nav is present --
    expect(find.text('Home'), findsWidgets);
    expect(find.text('CRM'), findsOneWidget);
    expect(find.text('Logistics'), findsOneWidget);
    expect(find.text('Execution'), findsOneWidget);
    expect(find.text('HR'), findsOneWidget);

    // -- 3. Open the HR tab and verify admin-only tiles are present --
    await tester.tap(find.text('HR'));
    await tester.pumpAndSettle();

    expect(find.text('My Attendance'), findsOneWidget);
    expect(find.text('My Leaves'), findsOneWidget);
    expect(find.text('My Expenses'), findsOneWidget);
    // Admin-only tiles
    expect(find.text('Leave Admin'), findsOneWidget);
    expect(find.text('Expense Ledger'), findsOneWidget);
    expect(find.text('User Management'), findsOneWidget);

    // -- 4. Verify User Management actually opens --
    await tester.tap(find.text('User Management'));
    await tester.pumpAndSettle();
    expect(find.text('User Management'), findsWidgets); // AppBar title too
    await tester.pageBack();
    await tester.pumpAndSettle();

    // -- 5. Verify CRM/Logistics/Execution tabs are reachable and Follow-ups/Complaints icons exist on CRM --
    await tester.tap(find.text('CRM'));
    await tester.pumpAndSettle();
    expect(find.text('Sales Pipeline'), findsOneWidget);
    expect(find.byTooltip('Follow-ups'), findsOneWidget);
    expect(find.byTooltip('Complaints'), findsOneWidget);

    // -- 6. Logout via the HR tab's Profile icon --
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
