import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:frontend/main.dart' as app;
import 'package:frontend/core/local_db/database_helper.dart';
import 'package:signature/signature.dart';
import 'package:sqflite/sqflite.dart' as sqflite;
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


  testWidgets('Flow 3: Execution Task Assignment & Installer Flow E2E Test',
      (tester) async {
    
    // Clear local database to ensure clean state
    try {
      if (sqflite.databaseFactory is sqflite.DatabaseFactory) {
         // factory is probably not set up yet here, so this might fail. We will also clear tables after app.main().
         final dbPath = await sqflite.getDatabasesPath();
         final path = p.join(dbPath, 'spacesio.db');
         await sqflite.deleteDatabase(path);
      }
    } catch (_) {}

    app.main();
    await tester.pumpAndSettle();
    
    try {
      final db = await DatabaseHelper.instance.database;
      await db.delete('outbox_queue');
      await db.delete('site_updates_cache');
    } catch (_) {}

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

    // Wait for Dashboard
    int dashRetries = 0;
    while (find.byIcon(Icons.construction).evaluate().isEmpty && dashRetries < 50) {
      await tester.pump(const Duration(milliseconds: 100));
      dashRetries++;
    }

    // 3. Navigate to Execution Module
    await tester.tap(find.byIcon(Icons.construction).first);
    await tester.pumpAndSettle();

    // 4. Create Installer
    await tester.tap(find.text('Installers'));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    // Installer Dialog
    final installerFields = find.byType(TextField);
    await tester.enterText(installerFields.at(0), 'Bob the Builder');
    await tester.enterText(installerFields.at(1), '9876543210'); // Must be 10 digits
    await tester.enterText(installerFields.at(2), '50'); // Rate
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();

    // Wait for it to close
    int addRetries = 0;
    while (find.text('Add Installer').evaluate().isNotEmpty && addRetries < 50) {
        await tester.pump(const Duration(milliseconds: 100));
        addRetries++;
    }

    // Go back to Hub
    final backBtn = find.byTooltip('Back');
    if(backBtn.evaluate().isNotEmpty) {
        await tester.tap(backBtn.first);
    } else {
        await tester.pageBack();
    }
    await tester.pumpAndSettle();

    // 5. Assign Installer to Job
    await tester.tap(find.text('All Jobs'));
    await tester.pumpAndSettle();

    // Wait for jobs list
    int jobRetries = 0;
    while (find.byType(ListTile).evaluate().isEmpty && jobRetries < 50) {
      await tester.pump(const Duration(milliseconds: 100));
      jobRetries++;
    }

    expect(find.byType(ListTile).evaluate().isNotEmpty, true, reason: 'Expected to find at least one job');

    // Tap first job
    await tester.tap(find.byType(ListTile).first);
    await tester.pumpAndSettle();

    // Wait for Job Detail
    int detailRetries = 0;
    while (find.text('Assign Installer').evaluate().isEmpty &&
        detailRetries < 50) {
      await tester.pump(const Duration(milliseconds: 100));
      detailRetries++;
    }

    await tester.tap(find.text('Assign Installer'));
    await tester.pumpAndSettle();

    final assignFields = find.byType(TextField);
    await tester.enterText(assignFields.at(0), '1'); // Installer ID
    await tester.enterText(assignFields.at(1), '450'); // Agreed Price
    await tester.enterText(assignFields.at(2), '2026-12-31'); // Est. Completion
    await tester.tap(find.text('Assign'));
    await tester.pumpAndSettle();

    // Wait for Assign to close
    int assignRetries = 0;
    while (find.text('Assign Installer').evaluate().length > 1 &&
        assignRetries < 50) {
      await tester.pump(const Duration(milliseconds: 100));
      assignRetries++;
    }

    // 6. Sync Site Updates
    await tester.pumpAndSettle(const Duration(seconds: 2));
    await tester.tap(find.text('Site Updates'));
    await tester.pumpAndSettle(const Duration(seconds: 2));

    // Tap FAB to add update (wait for route transition)
    int fabRetries = 0;
    while (find.byIcon(Icons.add).evaluate().isEmpty && fabRetries < 50) {
      await tester.pump(const Duration(milliseconds: 100));
      fabRetries++;
    }
    
    final fab = find.byIcon(Icons.add).last;
    await tester.ensureVisible(fab);
    await tester.pumpAndSettle();
    await tester.tap(fab);
    await tester.pumpAndSettle(const Duration(seconds: 1));

    // Wait for dialog
    int updateRetries = 0;
    while (find.text('Create Site Update').evaluate().isEmpty &&
        updateRetries < 50) {
      await tester.pump(const Duration(milliseconds: 100));
      updateRetries++;
    }

    final updateFields = find.byType(TextField);
    // index 0 is Job ID (pre-filled), index 1 is Description
    await tester.enterText(updateFields.at(1), 'Installation completed safely.');
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();

    // Wait for dialog to close
    int createUpdateRetries = 0;
    while (find.text('Create Site Update').evaluate().isNotEmpty &&
        createUpdateRetries < 50) {
      await tester.pump(const Duration(milliseconds: 100));
      createUpdateRetries++;
    }

    // Back to Job Detail
    if(find.byTooltip('Back').evaluate().isNotEmpty) {
        await tester.tap(find.byTooltip('Back').first);
    } else {
        await tester.pageBack();
    }
    await tester.pumpAndSettle();

    // 7. Client Sign-off
    await tester.tap(find.text('Sign-off'));
    await tester.pumpAndSettle();

    // Wait for screen
    int signoffRetries = 0;
    while (find.byType(Signature).evaluate().isEmpty && signoffRetries < 50) {
      await tester.pump(const Duration(milliseconds: 100));
      signoffRetries++;
    }

    // Draw on signature canvas
    final center = tester.getCenter(find.byType(Signature));
    await tester.dragFrom(center, const Offset(50, 50));
    await tester.pumpAndSettle();

    // Use Signature
    await tester.tap(find.text('Use Signature'));
    await tester.pumpAndSettle();

    // Submit Sign-off
    await tester.ensureVisible(find.text('Submit Sign-off'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Submit Sign-off'));
    await tester.pumpAndSettle();

  });
}
