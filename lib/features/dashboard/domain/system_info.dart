import 'package:intl/intl.dart';

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
    buffer.writeln(
      '============================================================',
    );
    buffer.writeln('SYSTEM INFORMATION');
    buffer.writeln(
      '============================================================',
    );
    buffer.writeln();

    // Display raw output exactly as it comes from Windows
    buffer.writeln(rawOutput);
    buffer.writeln();

    buffer.writeln(
      '============================================================',
    );
    buffer.writeln('[APPLICATION]');
    buffer.writeln('App Version         : $appVersion');
    buffer.writeln('Framework           : $frameworkVersion');
    buffer.writeln('Dart SDK            : $dartVersion');
    buffer.writeln('Database            : $databaseVersion');
    buffer.writeln('Engine              : $engineVersion');
    buffer.writeln('App Path            : $appPath');
    buffer.writeln('User Data           : $userDataPath');
    buffer.writeln();

    buffer.writeln(
      '============================================================',
    );
    final timestamp = DateFormat('yyyy-MM-dd HH:mm:ss').format(generatedAt);
    buffer.writeln('Generated at: $timestamp');
    buffer.writeln(
      '============================================================',
    );

    return buffer.toString();
  }
}
