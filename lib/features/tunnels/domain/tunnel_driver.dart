import 'tunnel_model.dart';

abstract class TunnelDriver {
  String get providerId;

  List<String> buildStartArguments(
    TunnelModel tunnel, {
    String? defaultToken,
  });

  String? parsePublicUrl(String logLine);

  String? parseInspectorUrl(String logLine);
}
