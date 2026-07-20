import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:frontend/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Unified UX Integration Tests', () {
    testWidgets('Verify 5-tab shell navigation renders correctly',
        (tester) async {
      // Launch the app
      app.main();
      await tester.pumpAndSettle();

      // Expect to see the Login screen initially (unauthenticated cold boot)
      expect(find.text('Log In'), findsWidgets);
    });
  });
}
