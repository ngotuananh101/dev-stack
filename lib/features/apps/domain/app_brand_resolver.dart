import 'package:flutter/material.dart';

/// Shared utility that resolves the brand icon filename and brand color for an
/// application based on its [appId] and optional [groupName].
///
/// This centralizes the icon/color logic that was previously duplicated between
/// [AppVersionModal] and [CompactAppsTable], making it testable as a pure
/// function without needing to build full widget trees.
class AppBrandResolver {
  AppBrandResolver._();

  /// Returns the icon asset filename (without extension) for [appId].
  ///
  /// Falls back to the lower-cased [groupName] when no specific match is found.
  static String iconFileName(String appId, {String? groupName}) {
    final id = appId.toLowerCase();
    final group = groupName?.toLowerCase() ?? '';

    if (id.contains('bun')) return 'bun';
    if (id.contains('deno')) return 'deno';
    if (id.contains('nodejs')) return 'nodejs';
    if (id == 'phpmyadmin') return 'phpmyadmin';
    if (id.contains('php')) return 'php';
    if (id.contains('mysql')) return 'mysql';
    if (id.contains('mariadb')) return 'mariadb';
    if (id.contains('mongodb')) return 'mongodb';
    if (id.contains('postgresql')) return 'postgre';
    if (id.contains('caddy')) return 'caddy';
    if (id.contains('nginx')) return 'nginx';
    if (id.contains('apache')) return 'apache';
    if (id.contains('redis')) return 'redis';
    if (id.contains('python') || id.contains('pyenv')) return 'python';
    if (id.contains('heidisql')) return 'heidisql';
    if (id.contains('compass')) return 'mongodb';
    if (id.contains('rustfs')) return 'rustfs';
    if (id.contains('meilisearch')) return 'meilisearch';
    if (id.contains('elasticsearch')) return 'elasticsearch';

    // Fallback to group name if id doesn't match
    return group;
  }

  /// Returns the brand color for [appId].
  ///
  /// Returns [fallback] (defaults to [Colors.black]) when no brand color
  /// is defined for the app.
  static Color iconColor(String appId, {Color fallback = const Color(0xFF000000)}) {
    final id = appId.toLowerCase();

    if (id.contains('bun')) return const Color(0xFFE5A83B);
    if (id.contains('deno')) return const Color(0xFF70FFAF);
    if (id.contains('nginx')) return const Color(0xFF009639);
    if (id.contains('caddy')) return const Color(0xFF1F8C5B);
    if (id.contains('nginx') && id.contains('waf')) return const Color(0xFF4169E1);
    if (id.contains('php')) return const Color(0xFF777BB4);
    if (id.contains('apache') && id.contains('waf')) return const Color(0xFFDC143C);
    if (id.contains('mysql')) return const Color(0xFF4479A1);
    if (id.contains('postgresql')) return const Color(0xFF336791);
    if (id.contains('cloud')) return const Color(0xFF58A6FF);
    if (id.contains('rustfs')) return const Color(0xFFE67E22);
    if (id.contains('meilisearch')) return const Color(0xFFFF5E5E);
    if (id.contains('elasticsearch')) return const Color(0xFF005A9E);
    if (id.contains('python') || id.contains('pyenv')) return const Color(0xFF3776AB);
    if (id.contains('node')) return const Color(0xFF68A063);

    return fallback;
  }

  /// Returns the fallback [IconData] used when the icon asset file is missing.
  static IconData fallbackIcon(String appId) {
    final id = appId.toLowerCase();
    if (id.contains('python') || id.contains('pyenv')) return Icons.code;
    if (id.contains('node')) return Icons.javascript;
    if (id.contains('php')) return Icons.code;
    if (id.contains('mysql')) return Icons.storage;
    if (id.contains('caddy')) return Icons.dns;
    if (id.contains('nginx')) return Icons.cloud;
    return Icons.apps;
  }
}
