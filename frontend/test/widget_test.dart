// Smoke test for the Studio CRM app shell. It boots the real widget tree
// (ProviderScope + MaterialApp.router) with a fake, storage-free AuthNotifier
// standing in for the real one (which talks to FlutterSecureStorage and isn't
// available under the plain widget-test platform), and asserts the app lands
// on the login screen when the user is unauthenticated.
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/features/auth/providers/auth_provider.dart';
import 'package:frontend/main.dart';

class _FakeAuthNotifier extends AuthNotifier {
  _FakeAuthNotifier(super.apiClient);

  @override
  Future<void> checkAuthStatus() async {
    state = state.copyWith(isLoading: false, isAuthenticated: false);
  }
}

void main() {
  setUpAll(() {
    dotenv.loadFromString(envString: 'API_URL=http://localhost:8080/api/v1');
  });

  testWidgets('Unauthenticated users land on the login screen',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith((ref) => _FakeAuthNotifier(ApiClient())),
        ],
        child: const StudioCRMApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Log In'), findsOneWidget);
    expect(find.byType(TextFormField), findsAtLeastNWidgets(2));
  });
}
