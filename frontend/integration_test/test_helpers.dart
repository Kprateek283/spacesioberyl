import 'package:flutter_test/flutter_test.dart';

/// Types [pin] into the numpad PIN-entry lock screen (pin_entry_screen.dart),
/// one digit tap at a time, letting the screen's own auto-submit logic fire.
Future<void> enterPinViaNumpad(WidgetTester tester, String pin) async {
  for (final digit in pin.split('')) {
    await tester.tap(find.text(digit).first);
    await tester.pump(const Duration(milliseconds: 100));
  }
}
