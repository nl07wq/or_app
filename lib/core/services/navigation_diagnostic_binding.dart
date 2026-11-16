import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'system_diagnostics.dart';

/// Installs a transparent observer at the framework-to-engine platform-message
/// boundary. The delegated bytes and ordering are never changed.
class NavigationDiagnosticWidgetsFlutterBinding extends WidgetsFlutterBinding {
  @override
  BinaryMessenger createBinaryMessenger() {
    return NavigationDiagnosticBinaryMessenger(
      super.createBinaryMessenger(),
      diagnostics: SystemDiagnostics.instance,
    );
  }
}

class NavigationDiagnosticBinaryMessenger extends BinaryMessenger {
  NavigationDiagnosticBinaryMessenger(
    this._delegate, {
    required this._diagnostics,
  });

  final BinaryMessenger _delegate;
  final SystemDiagnostics _diagnostics;

  @override
  // BinaryMessenger requires this delegating member even though callers should
  // prefer ChannelBuffers for new incoming-message code.
  Future<void> handlePlatformMessage(
    String channel,
    ByteData? data,
    ui.PlatformMessageResponseCallback? callback,
  ) {
    // ignore: deprecated_member_use
    return _delegate.handlePlatformMessage(channel, data, callback);
  }

  @override
  Future<ByteData?>? send(String channel, ByteData? message) {
    if (channel != SystemChannels.navigation.name) {
      return _delegate.send(channel, message);
    }

    final messageId = _diagnostics.captureNavigationPlatformMessage(message);
    final response = _delegate.send(channel, message);
    if (response == null) return null;
    return response.then(
      (value) {
        _diagnostics.completeNavigationPlatformMessage(messageId);
        return value;
      },
      onError: (Object error, StackTrace stackTrace) {
        _diagnostics.freezeUriExceptionEvidence(
          trigger: 'platform_message_response_error',
          error: error,
          stackTrace: stackTrace,
          messageId: messageId,
        );
        Error.throwWithStackTrace(error, stackTrace);
      },
    );
  }

  @override
  void setMessageHandler(String channel, MessageHandler? handler) {
    _delegate.setMessageHandler(channel, handler);
  }
}
