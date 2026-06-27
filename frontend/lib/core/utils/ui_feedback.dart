import 'package:flutter/material.dart';
import 'form_validators.dart';

class UiFeedback {
  static const _successColor = Color(0xFF006e1c);
  static const _errorColor = Color(0xFFba1a1a);
  static const _infoColor = Color(0xFF0061a4);

  static void success(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 2),
  }) {
    _show(
      context,
      message,
      backgroundColor: _successColor,
      duration: duration,
    );
  }

  static void error(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 4),
  }) {
    _show(
      context,
      message,
      backgroundColor: _errorColor,
      duration: duration,
    );
  }

  static void parsedError(
    BuildContext context,
    dynamic exception, {
    Duration duration = const Duration(seconds: 4),
  }) {
    UiFeedback.error(
      context,
      ErrorMessageParser.parseError(exception),
      duration: duration,
    );
  }

  static void info(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 2),
  }) {
    _show(
      context,
      message,
      backgroundColor: _infoColor,
      duration: duration,
    );
  }

  static void _show(
    BuildContext context,
    String message, {
    required Color backgroundColor,
    required Duration duration,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor,
        duration: duration,
      ),
    );
  }
}
