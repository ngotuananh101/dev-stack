class SystemInfo {
  final String rawOutput;
  final String appVersion;
  final String frameworkVersion;
  final String dartVersion;
  final String databaseVersion;
  final String engineVersion;
  final String appPath;
  final String userDataPath;
  final DateTime generatedAt;

  SystemInfo({
    required this.rawOutput,
    required this.appVersion,
    required this.frameworkVersion,
    required this.dartVersion,
    required this.databaseVersion,
    required this.engineVersion,
    required this.appPath,
    required this.userDataPath,
    required this.generatedAt,
  });

  String toFormattedString() {
    final buffer = StringBuffer();
    buffer.writeln('============================================================');
    buffer.writeln('DEV-ENV SYSTEM INFORMATION');
    buffer.writeln('============================================================');
    buffer.writeln();

    // Align raw output
    final lines = rawOutput.split('\n');
    int maxLabelWidth = 0;

    // First pass: find max label width
    for (var line in lines) {
      if (line.contains(':')) {
        final label = line.split(':').first.trim();
        if (label.length > maxLabelWidth && label.length < 40) {
          maxLabelWidth = label.length;
        }
      }
    }

    // Second pass: format with padding
    for (var line in lines) {
      if (line.contains(':')) {
        final parts = line.split(':');
        final label = parts.first.trim();
        final value = parts.sublist(1).join(':').trim();
        
        if (label.length < 40) {
          buffer.writeln('  ${label.padRight(maxLabelWidth)} : $value');
        } else {
          buffer.writeln('  $line');
        }
      } else {
        if (line.trim().isNotEmpty) {
          buffer.writeln('  $line');
        }
      }
    }
    buffer.writeln();

    buffer.writeln('============================================================');
    buffer.writeln('[APPLICATION]');
    buffer.writeln('  ${'App Version'.padRight(maxLabelWidth)} : $appVersion');
    buffer.writeln('  ${'Framework'.padRight(maxLabelWidth)} : $frameworkVersion');
    buffer.writeln('  ${'Dart SDK'.padRight(maxLabelWidth)} : $dartVersion');
    buffer.writeln('  ${'Database'.padRight(maxLabelWidth)} : $databaseVersion');
    buffer.writeln('  ${'Engine'.padRight(maxLabelWidth)} : $engineVersion');
    buffer.writeln('  ${'App Path'.padRight(maxLabelWidth)} : $appPath');
    buffer.writeln('  ${'User Data'.padRight(maxLabelWidth)} : $userDataPath');
    buffer.writeln();

    buffer.writeln('============================================================');
    buffer.writeln('Generated at: ${generatedAt.toString()}');
    buffer.writeln('============================================================');

    return buffer.toString();
  }
}
