import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'app_version_provider.g.dart';

class AppVersionInfo {
  final String name;
  final List<String> versions;
  final Map<String, String> downloadUrls;
  final String? latestVersion;

  const AppVersionInfo({
    required this.name,
    required this.versions,
    required this.downloadUrls,
    this.latestVersion,
  });
}

@riverpod
class AppVersions extends _$AppVersions {
  @override
  Future<AppVersionInfo> build(String appId) async {
    return await _loadVersions(appId);
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _loadVersions(appId));
  }

  Future<AppVersionInfo> _loadVersions(String appId) async {
    switch (appId) {
      case 'nvm':
        return await _loadNvmVersions();
      case 'nodejs':
        return await _loadNodeVersions();
      case 'pyenv':
        return await _loadPyenvVersions();
      case 'php82':
        return await _loadPhpVersions();
      case 'mysql8':
        return await _loadMySqlVersions();
      case 'nginx':
        return await _loadNginxVersions();
      default:
        return const AppVersionInfo(
          name: 'Unknown',
          versions: ['latest'],
          downloadUrls: {'latest': ''},
          latestVersion: 'latest',
        );
    }
  }

  Future<AppVersionInfo> _loadNvmVersions() async {
    try {
      final response = await http
          .get(
            Uri.parse(
              'https://api.github.com/repos/coreybutler/nvm-windows/releases',
            ),
            headers: {'Accept': 'application/vnd.github.v3+json'},
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final List<dynamic> releases = json.decode(response.body);
        final versions = <String>[];
        final downloadUrls = <String, String>{};

        for (final release in releases.take(10)) {
          final version = release['tag_name']?.toString() ?? '';
          if (version.isNotEmpty) {
            versions.add(version);
            // Find the setup.exe asset
            final assets = release['assets'] as List<dynamic>?;
            if (assets != null) {
              for (final asset in assets) {
                if (asset['name'].toString().contains('nvm-setup.exe')) {
                  downloadUrls[version] = asset['browser_download_url'];
                  break;
                }
              }
            }
          }
        }

        return AppVersionInfo(
          name: 'NVM for Windows',
          versions: versions.isNotEmpty ? versions : ['latest'],
          downloadUrls: downloadUrls,
          latestVersion: releases.isNotEmpty ? releases[0]['tag_name'] : null,
        );
      }
    } catch (e) {
      print('Error loading NVM versions: $e');
    }

    // Fallback
    return const AppVersionInfo(
      name: 'NVM for Windows',
      versions: ['latest'],
      downloadUrls: {
        'latest':
            'https://github.com/coreybutler/nvm-windows/releases/latest/download/nvm-setup.exe',
      },
      latestVersion: 'latest',
    );
  }

  Future<AppVersionInfo> _loadNodeVersions() async {
    try {
      final response = await http
          .get(Uri.parse('https://nodejs.org/dist/index.json'))
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final List<dynamic> releases = json.decode(response.body);
        final versions = <String>['latest'];
        final downloadUrls = <String, String>{
          'latest': 'https://nodejs.org/dist/latest/',
        };

        // Get LTS versions
        for (final release in releases) {
          if (release['lts'] != null && release['lts'] != false) {
            final version = release['version']?.toString() ?? '';
            if (version.isNotEmpty && !versions.contains(version)) {
              versions.add(version);
              downloadUrls[version] = 'https://nodejs.org/dist/$version/';
            }
          }
        }

        return AppVersionInfo(
          name: 'Node.js',
          versions: versions.take(10).toList(),
          downloadUrls: downloadUrls,
          latestVersion: releases.isNotEmpty ? releases[0]['version'] : null,
        );
      }
    } catch (e) {
      print('Error loading Node.js versions: $e');
    }

    return const AppVersionInfo(
      name: 'Node.js',
      versions: ['latest', '20.10.0', '18.19.0', '16.20.2'],
      downloadUrls: {'latest': 'https://nodejs.org/dist/latest/'},
      latestVersion: 'latest',
    );
  }

  Future<AppVersionInfo> _loadPyenvVersions() async {
    try {
      final response = await http
          .get(
            Uri.parse(
              'https://api.github.com/repos/pyenv-win/pyenv-win/releases',
            ),
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final List<dynamic> releases = json.decode(response.body);
        final versions = <String>['latest'];
        final downloadUrls = <String, String>{};

        for (final release in releases.take(10)) {
          final version = release['tag_name']?.toString() ?? '';
          if (version.isNotEmpty) {
            versions.add(version);
            downloadUrls[version] = release['html_url']?.toString() ?? '';
          }
        }

        downloadUrls['latest'] =
            'https://github.com/pyenv-win/pyenv-win/releases/latest';

        return AppVersionInfo(
          name: 'pyenv-win',
          versions: versions,
          downloadUrls: downloadUrls,
          latestVersion: releases.isNotEmpty ? releases[0]['tag_name'] : null,
        );
      }
    } catch (e) {
      print('Error loading pyenv versions: $e');
    }

    return const AppVersionInfo(
      name: 'pyenv-win',
      versions: ['latest', '3.12.0', '3.11.6', '3.10.13'],
      downloadUrls: {
        'latest': 'https://github.com/pyenv-win/pyenv-win/releases/latest',
      },
      latestVersion: 'latest',
    );
  }

  Future<AppVersionInfo> _loadPhpVersions() async {
    return const AppVersionInfo(
      name: 'PHP',
      versions: ['latest', '8.2.0', '8.1.0', '8.0.0', '7.4.33'],
      downloadUrls: {'latest': 'https://windows.php.net/download/'},
      latestVersion: 'latest',
    );
  }

  Future<AppVersionInfo> _loadMySqlVersions() async {
    return const AppVersionInfo(
      name: 'MySQL',
      versions: ['latest', '8.0.35', '8.0.34', '5.7.44'],
      downloadUrls: {'latest': 'https://dev.mysql.com/downloads/mysql/'},
      latestVersion: 'latest',
    );
  }

  Future<AppVersionInfo> _loadNginxVersions() async {
    return const AppVersionInfo(
      name: 'Nginx',
      versions: ['latest', '1.25.3', '1.24.0', '1.22.1'],
      downloadUrls: {'latest': 'https://nginx.org/en/download.html'},
      latestVersion: 'latest',
    );
  }
}
