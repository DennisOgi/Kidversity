import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import '../config/env.dart';

/// Global error handling and reporting.
class ErrorHandler {
  static Future<void> initialize() async {
    if (Env.sentryDsn.isEmpty) {
      // Skip Sentry initialization in development
      debugPrint('Sentry not initialized (no DSN provided)');
      return;
    }

    await SentryFlutter.init(
      (options) {
        options
          ..dsn = Env.sentryDsn
          ..environment = Env.environment
          ..tracesSampleRate = Env.isProduction ? 0.2 : 1.0
          ..enableAutoSessionTracking = true
          ..attachStacktrace = true
          ..sendDefaultPii = false // Don't send personally identifiable info
          ..beforeSend = (event, hint) {
            // Filter out noisy errors in development
            if (Env.isDevelopment) {
              return null;
            }
            return event;
          };
      },
    );
  }

  /// Report an error to monitoring service.
  static Future<void> reportError(
    dynamic error,
    StackTrace? stackTrace, {
    String? context,
    Map<String, dynamic>? extras,
  }) async {
    // Log to console in development
    if (kDebugMode) {
      debugPrint('❌ ERROR: $error');
      if (stackTrace != null) {
        debugPrint('Stack trace:\n$stackTrace');
      }
      if (context != null) {
        debugPrint('Context: $context');
      }
    }

    // Report to Sentry in production
    if (Env.sentryDsn.isNotEmpty) {
      await Sentry.captureException(
        error,
        stackTrace: stackTrace,
        withScope: (scope) {
          if (context != null) {
            scope.setTag('error_context', context);
          }
          if (extras != null) {
            for (final entry in extras.entries) {
              scope.setExtra(entry.key, entry.value);
            }
          }
        },
      );
    }
  }

  /// Report a message/warning to monitoring service.
  static Future<void> reportMessage(
    String message, {
    SentryLevel level = SentryLevel.warning,
    Map<String, dynamic>? extras,
  }) async {
    if (kDebugMode) {
      debugPrint('⚠️ $message');
    }

    if (Env.sentryDsn.isNotEmpty) {
      await Sentry.captureMessage(
        message,
        level: level,
        withScope: (scope) {
          if (extras != null) {
            for (final entry in extras.entries) {
              scope.setExtra(entry.key, entry.value);
            }
          }
        },
      );
    }
  }

  /// Record a breadcrumb for debugging.
  static void addBreadcrumb(String message, {String? category, Map<String, dynamic>? data}) {
    if (Env.sentryDsn.isNotEmpty) {
      Sentry.addBreadcrumb(
        Breadcrumb(
          message: message,
          category: category,
          data: data,
        ),
      );
    }
  }
}

/// Result type for operations that can fail.
class Result<T> {
  final T? data;
  final String? error;
  final StackTrace? stackTrace;

  Result.success(this.data)
      : error = null,
        stackTrace = null;

  Result.failure(this.error, [this.stackTrace]) : data = null;

  bool get isSuccess => data != null;
  bool get isFailure => error != null;

  /// Transform the data if successful, otherwise pass through the error.
  Result<R> map<R>(R Function(T data) transform) {
    if (isSuccess) {
      try {
        return Result.success(transform(data as T));
      } catch (e, stack) {
        return Result.failure(e.toString(), stack);
      }
    }
    return Result.failure(error!, stackTrace);
  }

  /// Handle both success and failure cases.
  R when<R>({
    required R Function(T data) success,
    required R Function(String error) failure,
  }) {
    if (isSuccess) {
      return success(data as T);
    }
    return failure(error!);
  }
}

/// Common app exceptions.
class AppException implements Exception {
  final String message;
  final String? code;
  final dynamic originalError;

  AppException(this.message, {this.code, this.originalError});

  @override
  String toString() => message;
}

class AuthException extends AppException {
  AuthException(super.message, {super.code, super.originalError});
}

class NetworkException extends AppException {
  NetworkException(super.message, {super.code, super.originalError});
}

class ValidationException extends AppException {
  ValidationException(super.message, {super.code, super.originalError});
}

class NotFoundException extends AppException {
  NotFoundException(super.message, {super.code, super.originalError});
}
