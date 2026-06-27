import 'dart:io';

import 'package:dio/dio.dart';

/// Form validation utilities for common input types
class FormValidators {
  /// Validates that field is not empty
  static String? validateRequired(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }
    return null;
  }

  /// Validates email format
  static String? validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Email is required';
    }
    final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    if (!emailRegex.hasMatch(value.trim())) {
      return 'Enter a valid email address';
    }
    return null;
  }

  /// Validates phone number (10 digits)
  static String? validatePhone(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Phone is required';
    }
    final phoneRegex = RegExp(r'^[0-9]{10}$');
    if (!phoneRegex.hasMatch(value.replaceAll(RegExp(r'\D'), ''))) {
      return 'Enter a valid 10-digit phone number';
    }
    return null;
  }

  /// Validates numeric amount (must be > 0)
  static String? validateAmount(String? value, {String fieldName = 'Amount'}) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }
    try {
      final amount = double.parse(value);
      if (amount <= 0) {
        return '$fieldName must be greater than 0';
      }
      return null;
    } catch (e) {
      return 'Enter a valid $fieldName';
    }
  }

  /// Validates minimum length
  static String? validateMinLength(String? value, int minLength, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }
    if (value.length < minLength) {
      return '$fieldName must be at least $minLength characters';
    }
    return null;
  }

  /// Validates that end date is after start date
  static String? validateDateRange(DateTime? startDate, DateTime? endDate) {
    if (startDate == null || endDate == null) {
      return 'Both start and end dates are required';
    }
    if (endDate.isBefore(startDate)) {
      return 'End date must be after start date';
    }
    return null;
  }

  /// Validates integer rate (must be > 0)
  static String? validateRate(String? value, {String fieldName = 'Rate'}) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }
    try {
      final rate = int.parse(value);
      if (rate <= 0) {
        return '$fieldName must be greater than 0';
      }
      return null;
    } catch (e) {
      return 'Enter a valid $fieldName';
    }
  }

  /// Validates DateTime is not in future
  static String? validateDateTime(DateTime? dateTime) {
    if (dateTime == null) {
      return 'Date/time is required';
    }
    if (dateTime.isAfter(DateTime.now())) {
      return 'Date/time cannot be in the future';
    }
    return null;
  }

  /// Validates photo file (existence and size)
  static String? validatePhotoFile(dynamic photoFile, {int maxSizeMB = 5}) {
    if (photoFile == null) {
      return 'Photo is required';
    }
    
    // Import needed: import 'dart:io';
    try {
      final file = File(photoFile.path);
      if (!file.existsSync()) {
        return 'Photo file not found';
      }
      
      final fileSizeInBytes = file.lengthSync();
      final fileSizeInMB = fileSizeInBytes / (1024 * 1024);
      
      if (fileSizeInMB > maxSizeMB) {
        return 'Photo must be less than ${maxSizeMB}MB (current: ${fileSizeInMB.toStringAsFixed(1)}MB)';
      }
      
      return null;
    } catch (e) {
      return 'Error validating photo: ${e.toString()}';
    }
  }
}

/// Helper class for error message parsing
class ErrorMessageParser {
  /// Extracts user-friendly error message from exception
  static String parseError(dynamic error) {
    if (error is DioException) {
      final responseData = error.response?.data;
      if (responseData is Map) {
        final apiError = responseData['error'] ?? responseData['message'];
        if (apiError != null && apiError.toString().isNotEmpty) {
          return apiError.toString();
        }
      }
      if (responseData is String && responseData.isNotEmpty) {
        return responseData;
      }

      switch (error.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.receiveTimeout:
        case DioExceptionType.sendTimeout:
          return 'Request timed out. Please try again.';
        case DioExceptionType.connectionError:
          return 'Network error. Please check your connection.';
        case DioExceptionType.badResponse:
          final code = error.response?.statusCode;
          if (code == 401) return 'Session expired. Please log in again.';
          if (code == 403) return 'You do not have permission for this action.';
          if (code == 404) return 'Requested resource was not found.';
          if (code != null && code >= 500) {
            return 'Server error ($code). Please try again later.';
          }
          break;
        case DioExceptionType.cancel:
          return 'Request was cancelled.';
        default:
          break;
      }
    }

    final errorStr = error.toString();

    if (errorStr.startsWith('Exception: ')) {
      return errorStr.replaceFirst('Exception: ', '');
    }

    if (errorStr.contains('SocketException') ||
        errorStr.contains('Connection refused')) {
      return 'Network error. Please check your connection.';
    }
    if (errorStr.contains('TimeoutException')) {
      return 'Request timed out. Please try again.';
    }
    if (errorStr.contains('FormatException')) {
      return 'Invalid response format from server.';
    }

    return errorStr;
  }

  /// Checks if error is a network error
  static bool isNetworkError(dynamic error) {
    if (error is DioException) {
      return error.type == DioExceptionType.connectionError ||
          error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.receiveTimeout ||
          error.type == DioExceptionType.sendTimeout;
    }
    final errorStr = error.toString();
    return errorStr.contains('SocketException') ||
        errorStr.contains('TimeoutException') ||
        errorStr.contains('Connection refused');
  }
}
