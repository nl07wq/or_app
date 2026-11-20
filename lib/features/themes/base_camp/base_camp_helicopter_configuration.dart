import 'package:flutter/material.dart';

/// Durable BODY-local calibration shared by production flybys and MAP EDITOR.
@immutable
class BaseCampHelicopterAssembly {
  const BaseCampHelicopterAssembly({
    this.globalScale = 1,
    this.mainHub = const Offset(772, 273),
    this.mainScale = 1,
    this.tailHub = const Offset(1250, 484),
    this.tailScale = .5,
    this.mainFrameMs = defaultMainFrameMs,
    this.tailFrameMs = defaultTailFrameMs,
    this.flightSpeed = defaultFlightSpeed,
    this.forwardPitchDegrees = defaultForwardPitchDegrees,
  });

  static const defaults = BaseCampHelicopterAssembly();
  static const minimumScale = .1;
  static const maximumScale = 3.0;
  static const sourceSize = Size(1448, 1086);
  static const defaultMainFrameMs = 110;
  static const defaultTailFrameMs = 50;
  static const minimumMainFrameMs = 20;
  static const maximumMainFrameMs = 200;
  static const minimumTailFrameMs = 5;
  static const maximumTailFrameMs = 120;
  static const frameMsStep = 5;
  static const defaultFlightSpeed = 190;
  static const minimumFlightSpeed = 80;
  static const maximumFlightSpeed = 400;
  static const flightSpeedStep = 10;
  static const defaultForwardPitchDegrees = 4;
  static const minimumForwardPitchDegrees = 0;
  static const maximumForwardPitchDegrees = 12;
  static const forwardPitchDegreesStep = 1;

  final double globalScale;
  final Offset mainHub;
  final double mainScale;
  final Offset tailHub;
  final double tailScale;
  final int mainFrameMs;
  final int tailFrameMs;
  final int flightSpeed;
  final int forwardPitchDegrees;

  bool get isValid =>
      globalScale.isFinite &&
      mainScale.isFinite &&
      tailScale.isFinite &&
      mainHub.dx.isFinite &&
      mainHub.dy.isFinite &&
      tailHub.dx.isFinite &&
      tailHub.dy.isFinite &&
      globalScale >= minimumScale &&
      globalScale <= maximumScale &&
      mainScale >= minimumScale &&
      mainScale <= maximumScale &&
      tailScale >= minimumScale &&
      tailScale <= maximumScale &&
      _validFrameMs(mainFrameMs, minimumMainFrameMs, maximumMainFrameMs) &&
      _validFrameMs(tailFrameMs, minimumTailFrameMs, maximumTailFrameMs) &&
      flightSpeed >= minimumFlightSpeed &&
      flightSpeed <= maximumFlightSpeed &&
      flightSpeed % flightSpeedStep == 0 &&
      forwardPitchDegrees >= minimumForwardPitchDegrees &&
      forwardPitchDegrees <= maximumForwardPitchDegrees &&
      forwardPitchDegrees % forwardPitchDegreesStep == 0 &&
      _validHub(mainHub) &&
      _validHub(tailHub);

  static bool _validFrameMs(int value, int minimum, int maximum) =>
      value >= minimum && value <= maximum && value % frameMsStep == 0;

  static bool _validHub(Offset hub) =>
      hub.dx >= 0 &&
      hub.dx <= sourceSize.width &&
      hub.dy >= 0 &&
      hub.dy <= sourceSize.height;

  BaseCampHelicopterAssembly copyWith({
    double? globalScale,
    Offset? mainHub,
    double? mainScale,
    Offset? tailHub,
    double? tailScale,
    int? mainFrameMs,
    int? tailFrameMs,
    int? flightSpeed,
    int? forwardPitchDegrees,
  }) => BaseCampHelicopterAssembly(
    globalScale: globalScale ?? this.globalScale,
    mainHub: mainHub ?? this.mainHub,
    mainScale: mainScale ?? this.mainScale,
    tailHub: tailHub ?? this.tailHub,
    tailScale: tailScale ?? this.tailScale,
    mainFrameMs: mainFrameMs ?? this.mainFrameMs,
    tailFrameMs: tailFrameMs ?? this.tailFrameMs,
    flightSpeed: flightSpeed ?? this.flightSpeed,
    forwardPitchDegrees: forwardPitchDegrees ?? this.forwardPitchDegrees,
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'globalScale': globalScale,
    'mainHubX': mainHub.dx,
    'mainHubY': mainHub.dy,
    'mainScale': mainScale,
    'tailHubX': tailHub.dx,
    'tailHubY': tailHub.dy,
    'tailScale': tailScale,
    'mainFrameMs': mainFrameMs,
    'tailFrameMs': tailFrameMs,
    'flightSpeed': flightSpeed,
    'forwardPitchDegrees': forwardPitchDegrees,
  };

  static BaseCampHelicopterAssembly? tryParse(Object? raw) {
    if (raw is! Map) return null;
    double? finite(String key) {
      final value = raw[key];
      return value is num && value.isFinite ? value.toDouble() : null;
    }

    final globalScale = finite('globalScale');
    final mainX = finite('mainHubX');
    final mainY = finite('mainHubY');
    final mainScale = finite('mainScale');
    final tailX = finite('tailHubX');
    final tailY = finite('tailHubY');
    final tailScale = finite('tailScale');
    int? frameMs(String key, int fallback) {
      final value = raw[key];
      if (value == null) return fallback;
      if (value is! num || !value.isFinite || value != value.roundToDouble()) {
        return null;
      }
      return value.toInt();
    }

    final mainFrameMs = frameMs('mainFrameMs', defaultMainFrameMs);
    final tailFrameMs = frameMs('tailFrameMs', defaultTailFrameMs);
    final flightSpeed = frameMs('flightSpeed', defaultFlightSpeed);
    final forwardPitchDegrees = frameMs(
      'forwardPitchDegrees',
      defaultForwardPitchDegrees,
    );
    if (globalScale == null ||
        mainX == null ||
        mainY == null ||
        mainScale == null ||
        tailX == null ||
        tailY == null ||
        tailScale == null ||
        mainFrameMs == null ||
        tailFrameMs == null ||
        flightSpeed == null ||
        forwardPitchDegrees == null) {
      return null;
    }
    final result = BaseCampHelicopterAssembly(
      globalScale: globalScale,
      mainHub: Offset(mainX, mainY),
      mainScale: mainScale,
      tailHub: Offset(tailX, tailY),
      tailScale: tailScale,
      mainFrameMs: mainFrameMs,
      tailFrameMs: tailFrameMs,
      flightSpeed: flightSpeed,
      forwardPitchDegrees: forwardPitchDegrees,
    );
    return result.isValid ? result : null;
  }
}
