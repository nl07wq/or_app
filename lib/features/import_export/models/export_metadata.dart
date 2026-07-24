class ExportMetadata {
  final String? applicationVersion;
  final String? devicePlatform;

  const ExportMetadata({this.applicationVersion, this.devicePlatform});

  Map<String, Object?> toJson() {
    return {
      if (applicationVersion != null) 'applicationVersion': applicationVersion,
      if (devicePlatform != null) 'devicePlatform': devicePlatform,
    };
  }
}
