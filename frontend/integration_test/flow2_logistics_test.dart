import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:frontend/main.dart' as app;

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


  testWidgets('Flow 2: Logistics Order Management E2E Test', (WidgetTester tester) async {
    // 1. Launch App
    app.main();
    await tester.pumpAndSettle(const Duration(seconds: 1));
    await tester.pumpAndSettle(const Duration(seconds: 2));

    // Check if we need to log in (if TextFormField exists, we are on Login screen)
    if (find.byType(TextFormField).evaluate().isNotEmpty) {
      // 2. Login
      await tester.enterText(find.byType(TextFormField).first, 'admin@gmail.com');
      await tester.enterText(find.byType(TextFormField).last, 'admin123'); // Assuming default admin pass
      await tester.tap(find.text('Log In'));
      await tester.pumpAndSettle();
    }

    // 3. PIN Entry
    final pin = '1111';
    // The PIN screen uses a standard TextField with obscureText: true
    int pinRetries = 0;
    while (find.byType(TextField).evaluate().isEmpty && pinRetries < 50) {
      await tester.pump(const Duration(milliseconds: 100));
      pinRetries++;
    }
    if (find.byType(TextField).evaluate().isNotEmpty) {
      await tester.enterText(find.byType(TextField).first, pin);
      await tester.tap(find.text('Unlock'));
      await tester.pumpAndSettle();
    }

    // Wait for Dashboard to appear
    int dashRetries = 0;
    while (find.text('CRM').evaluate().isEmpty && dashRetries < 50) {
      await tester.pump(const Duration(milliseconds: 100));
      dashRetries++;
    }

    // 4. Navigate to Logistics Module
    await tester.tap(find.byIcon(Icons.local_shipping));
    await tester.pumpAndSettle();

    // Tap Orders tile in the Hub
    await tester.tap(find.text('Orders'));
    await tester.pumpAndSettle();

    // 5. Select the first order in the list
    int orderRetries = 0;
    while (find.byType(ExpansionTile).evaluate().isEmpty && orderRetries < 50) {
      await tester.pump(const Duration(milliseconds: 100));
      orderRetries++;
    }

    // Tap the first ExpansionTile to expand the order details
    await tester.tap(find.byType(ExpansionTile).first);
    await tester.pumpAndSettle();

    // 6. Create PO
    await tester.tap(find.text('Create PO').first);
    await tester.pumpAndSettle();

    // Fill PO Dialog
    final poFields = find.byType(TextField);
    await tester.enterText(poFields.at(0), '1'); // Vendor ID
    await tester.enterText(poFields.at(1), '4500'); // Amount
    await tester.enterText(poFields.at(2), '2026-12-31'); // Date
    
    await tester.tap(find.text('Create PO').last); // Submit button
    await tester.pump();

    // Wait for dialog to close
    int poDialogRetries = 0;
    while (find.text('Total Amount').evaluate().isNotEmpty && poDialogRetries < 50) {
      await tester.pump(const Duration(milliseconds: 100));
      poDialogRetries++;
    }
    await tester.pumpAndSettle();

    // 7. Schedule Dispatch
    await tester.tap(find.text('Schedule Dispatch').first);
    await tester.pumpAndSettle();

    // Fill Dispatch Dialog
    final dispatchFields = find.byType(TextField);
    await tester.enterText(dispatchFields.at(0), 'Bob Driver'); // Driver Name
    await tester.enterText(dispatchFields.at(1), 'TRUCK-01'); // Vehicle Number
    
    await tester.tap(find.text('Schedule Dispatch').last);
    await tester.pump();
    
    // Wait for dialog to close
    int dispatchDialogRetries = 0;
    while (find.text('Select Staff').evaluate().isNotEmpty && dispatchDialogRetries < 50) {
      await tester.pump(const Duration(milliseconds: 100));
      dispatchDialogRetries++;
    }
    await tester.pumpAndSettle();

    // Flow completed successfully!
  });
}
