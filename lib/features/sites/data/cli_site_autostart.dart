import 'package:isar_plus/isar_plus.dart';

import '../../../core/services/log_service.dart';
import '../domain/site_model.dart';
import 'cli_process_manager.dart';

/// Starts every persisted CLI site whose `autoStart` flag is set.
///
/// This deliberately lives outside the Sites provider: that provider is
/// autoDispose and only builds once the Sites UI is opened, so auto-start used
/// to wait for the user to visit the tab. In the meantime the webserver was
/// already running and reverse-proxying to the CLI port, answering 502 until
/// the user opened Sites (or pressed Start/Restart) — most visibly for a Vite
/// dev server, whose vhost proxies to its fixed port.
///
/// [manager.startSite] only spawns the process; it does not wait for the dev
/// server to listen. A short 502 window after boot is therefore expected and
/// not something this function can remove.
///
/// A site that cannot start (missing directory, empty command, bad port) is
/// logged and skipped: one broken record must not stop the others, and nothing
/// here may crash startup.
Future<void> startAutoStartCliSites({
  required Isar isar,
  required CliProcessManager manager,
  required LogService logger,
}) async {
  final sites = isar.siteModels.where().autoStartEqualTo(true).findAll();

  for (final site in sites) {
    if (site.siteType != 'cli') continue;

    if (site.command == null || site.command!.trim().isEmpty) {
      await logger.warning(
        'Skipping auto-start for ${site.domain}: no start command',
      );
      continue;
    }

    try {
      await manager.startSite(site);
    } catch (e) {
      await logger.error('Auto-start failed for ${site.domain}: $e');
    }
  }
}
