import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
// Note: You must update the import path based on your pubspec name if needed.
import 'package:frontend/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Flow 1: Lead to Order E2E Test', (WidgetTester tester) async {
    // 1. Launch App
    app.main();
    await tester.pumpAndSettle();

    // 2. Login
    // Enter Email
    await tester.enterText(find.byType(TextFormField).first, 'admin@gmail.com');
    // Enter Password
    await tester.enterText(find.byType(TextFormField).last, 'admin123'); // Assuming default admin pass
    await tester.tap(find.text('Log In'));
    await tester.pumpAndSettle();

    // 3. PIN Entry
    // (Assuming UI has text fields or buttons for PIN input. Adjust selectors as needed).
    // If it uses buttons like '1', '2', '3':
    final pin = '2853'; 
    for (var char in pin.split('')) {
      final keyBtn = find.text(char);
      if (keyBtn.evaluate().isNotEmpty) {
        await tester.tap(keyBtn.first);
        await tester.pumpAndSettle(const Duration(milliseconds: 100));
      }
    }
    await tester.tap(find.text('Unlock'));
    await tester.pumpAndSettle();

    // 4. Navigate to CRM tab
    await tester.tap(find.text('CRM').or(find.byIcon(Icons.people)));
    await tester.pumpAndSettle();

    // 5. Create Lead
    await tester.tap(find.byIcon(Icons.add)); // Floating Action Button
    await tester.pumpAndSettle();
    
    // Fill out Lead Form (Assumes order of DialogTextFields)
    final textFields = find.byType(TextField);
    await tester.enterText(textFields.at(0), 'Integration Test Client'); // Name
    await tester.enterText(textFields.at(1), '555-0101'); // Phone
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();

    // 6. View the newly created Lead
    // Assumes the Lead card has a 'View' button
    await tester.tap(find.text('View').first);
    await tester.pumpAndSettle();

    // 7. Update Status to 'First Call'
    await tester.tap(find.text('First Call'));
    await tester.pumpAndSettle();

    // 8. Create Quotation
    await tester.tap(find.text('Create Quotation'));
    await tester.pumpAndSettle();
    
    // Fill out Quotation Dialog
    final quoteFields = find.byType(TextField);
    await tester.enterText(quoteFields.at(0), 'Test Service'); // Item Name
    await tester.enterText(quoteFields.at(1), '1'); // Qty
    await tester.enterText(quoteFields.at(2), '500'); // Price
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();

    // 9. Approve Quotation
    await tester.tap(find.text('Approve').first);
    await tester.pumpAndSettle();

    // 10. Verify order auto-created in Logistics
    await tester.tap(find.text('Logistics').or(find.byIcon(Icons.local_shipping)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Orders'));
    await tester.pumpAndSettle();

    // If order was created successfully, it should show up in the list!
    expect(find.textContaining('Integration Test Client'), findsWidgets);
  });
}
