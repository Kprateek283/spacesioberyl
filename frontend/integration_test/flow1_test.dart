import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart' as p;
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


  

  testWidgets('Flow 1: Lead to Order E2E Test', (WidgetTester tester) async {
    // 1. Launch App
    app.main();
    await tester.pumpAndSettle(const Duration(seconds: 1));

    // Wait for the app to settle on a screen
    await tester.pumpAndSettle(const Duration(seconds: 2));

    // Check if we need to log in (if TextFormField exists, we are on Login screen)
    if (find.byType(TextFormField).evaluate().isNotEmpty) {
      // 2. Login
      await tester.enterText(find.byType(TextFormField).first, 'admin@gmail.com');
      await tester.enterText(find.byType(TextFormField).last, 'admin123');
      await tester.tap(find.text('Log In'));
      await tester.pumpAndSettle();
    }

    // Check if we hit the PIN entry screen (Setup or Unlock)
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

    if (find.text('Unlock').evaluate().isNotEmpty) {
      await tester.enterText(find.byType(TextField).first, '1111');
      await tester.tap(find.text('Unlock'));
      await tester.pumpAndSettle();
    }

    // Wait for the app to settle on the Home screen
    int homeRetries = 0;
    while (find.text('CRM').evaluate().isEmpty && homeRetries < 20) {
      await tester.pump(const Duration(milliseconds: 200));
      homeRetries++;
    }

    if (find.text('CRM').evaluate().isEmpty) {
      fail('Failed to reach Dashboard. Texts on screen: ${find.byType(Text).evaluate().map((e) => (e.widget as Text).data).join(', ')}');
    }

    // 4. Navigate to CRM tab
    await tester.tap(find.text('CRM'));
    await tester.pump(const Duration(seconds: 2));

    // 5. Create Lead
    await tester.tap(find.byIcon(Icons.add)); // Floating Action Button
    await tester.pump(const Duration(seconds: 1));
    
    // Fill out Lead Form
    final uniqueLeadName = 'Test Client ${DateTime.now().millisecondsSinceEpoch}';
    final textFields = find.byType(TextField);
    await tester.enterText(textFields.at(0), uniqueLeadName); // Name
    await tester.enterText(textFields.at(1), '555-0101'); // Phone
    await tester.tap(find.text('Create'));
    await tester.pump(); // Start the tap

    // Wait for the dialog to close
    int dialogRetries = 0;
    while (find.text('Create New Lead').evaluate().isNotEmpty && dialogRetries < 50) {
      await tester.pump(const Duration(milliseconds: 100));
      dialogRetries++;
    }
    await tester.pump(const Duration(seconds: 1));

    // Wait for the leads list to refresh and show our card
    int leadRetries = 0;
    while (find.textContaining(uniqueLeadName).evaluate().isEmpty && leadRetries < 50) {
      await tester.pump(const Duration(milliseconds: 100));
      leadRetries++;
    }

    // Find the card containing our test client, and tap its View button
    final cards = find.byType(Card).evaluate();
    Element? targetCard;
    for (final card in cards) {
      if (find.descendant(of: find.byWidget(card.widget), matching: find.textContaining(uniqueLeadName)).evaluate().isNotEmpty) {
        targetCard = card;
        break;
      }
    }

    if (targetCard == null) {
      throw Exception("Could not find card containing Integration Test Client");
    }

    await tester.tap(find.descendant(of: find.byWidget(targetCard.widget), matching: find.text('View')).first);
    await tester.pump(const Duration(seconds: 2));

    // 7. Update Status to 'First Call'
    await tester.tap(find.text('First Call'));
    await tester.pump(const Duration(seconds: 2));

    // 8. Create Quotation
    await tester.tap(find.text('Create Quotation'));
    await tester.pump(const Duration(seconds: 2));
    
    // Fill out Quotation Dialog
    final quoteFields = find.byType(TextField);
    await tester.enterText(quoteFields.at(0), 'Test Service'); // Item Name
    await tester.enterText(quoteFields.at(1), '1'); // Qty
    await tester.enterText(quoteFields.at(2), '500'); // Price
    await tester.tap(find.text('Create'));
    await tester.pump(const Duration(seconds: 2));

    // 9. Approve Quotation
    await tester.tap(find.text('Approve').first);
    await tester.pump(const Duration(seconds: 2));

    // 10. Verify order auto-created in Logistics
    // Wait for the backend worker to process the QueueQuoteApproved event
    await Future.delayed(const Duration(seconds: 3));
    
    await tester.tap(find.text('Logistics'));
    await tester.pump(const Duration(seconds: 2));
    await tester.tap(find.text('Orders'));
    await tester.pump(const Duration(seconds: 2));

    // Wait for the network request to load the orders
    int orderRetries = 0;
    while (find.textContaining(uniqueLeadName).evaluate().isEmpty && orderRetries < 50) {
      await tester.pump(const Duration(milliseconds: 100));
      orderRetries++;
    }
    
    // DEBUG: print all text in the app
    final allText = find.byType(Text).evaluate().map((e) => (e.widget as Text).data).join(', ');
    debugPrint('All text on screen: $allText');


    // If order was created successfully, it should show up in the list!
    expect(find.textContaining(uniqueLeadName), findsWidgets);
  });
}
