import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show visibleForTesting;

/// A real mount point reported by `df`.
class MountUsage {
  final String mount;
  final int totalBytes;
  final int usedBytes;
  final int availableBytes;
  final String percent;

  const MountUsage({
    required this.mount,
    required this.totalBytes,
    required this.usedBytes,
    required this.availableBytes,
    required this.percent,
  });
}

/// One network interface reported by `ip -brief addr`.
class NetworkInterfaceInfo {
  final String name;
  final String state;
  final List<String> ipv4;
  final List<String> ipv6;

  const NetworkInterfaceInfo({
    required this.name,
    required this.state,
    required this.ipv4,
    required this.ipv6,
  });
}

/// Collects the Linux half of the system report.
///
/// Sources, in order of preference per section:
///
/// * commands (`uname`, `getconf`, `lscpu`, `df`, `ip`, `lspci`), each with a
///   short timeout and skipped entirely when the binary is missing;
/// * procfs/sysfs files (`/etc/os-release`, `/proc/meminfo`, `/proc/uptime`,
///   `/proc/cpuinfo`, `/sys/class/dmi/id/*`), which need no external tool;
/// * the process environment (`XDG_*`, `LANG`).
///
/// A section whose sources are all unavailable is left out rather than printed
/// with placeholder values. Everything is injected so the parsing can be tested
/// without the host machine's exact tooling.
class LinuxSystemProbe {
  static const Duration commandTimeout = Duration(seconds: 3);

  /// Runs `exe args`, returning stdout, or null when the tool is missing,
  /// exits non-zero, or exceeds [commandTimeout].
  final Future<String?> Function(String exe, List<String> args) run;

  /// Reads a file, or null when it is missing or unreadable.
  final String? Function(String path) readFile;

  final Map<String, String> environment;
  final DateTime Function() clock;

  LinuxSystemProbe({
    Future<String?> Function(String exe, List<String> args)? run,
    String? Function(String path)? readFile,
    Map<String, String>? environment,
    DateTime Function()? clock,
  }) : run = run ?? _runCommand,
       readFile = readFile ?? _readFileOrNull,
       environment = environment ?? Platform.environment,
       clock = clock ?? DateTime.now;

  /// Builds the whole Linux report as a printable block.
  Future<String> describe() async {
    final sections = <String>[];

    final os = await _osSection();
    if (os.isNotEmpty) sections.add(_section('OS', os));

    final host = await _hostSection();
    if (host.isNotEmpty) sections.add(_section('HOST', host));

    final hardware = await _hardwareSection();
    if (hardware.isNotEmpty) sections.add(_section('HARDWARE', hardware));

    final cpu = await _cpuSection();
    if (cpu.isNotEmpty) sections.add(_section('CPU', cpu));

    final memory = _memorySection();
    if (memory.isNotEmpty) sections.add(_section('MEMORY', memory));

    final storage = await _storageSection();
    if (storage.isNotEmpty) sections.add(_section('STORAGE', storage));

    final network = await _networkSection();
    if (network.isNotEmpty) sections.add(_section('NETWORK', network));

    final session = _sessionSection();
    if (session.isNotEmpty) sections.add(_section('SESSION', session));

    return sections.join('\n');
  }

  // ---------------------------------------------------------------- sections

  Future<List<(String, String)>> _osSection() async {
    final rows = <(String, String)>[];
    final release = parseOsRelease(readFile('/etc/os-release') ?? '');
    final pretty =
        release['PRETTY_NAME'] ??
        [release['NAME'], release['VERSION']]
            .whereType<String>()
            .where((v) => v.isNotEmpty)
            .join(' ');
    if (pretty.isNotEmpty) rows.add(('OS', pretty));

    final kernel = await run('uname', ['-r']);
    if (kernel != null && kernel.isNotEmpty) rows.add(('Kernel', kernel));

    final machine = await run('uname', ['-m']);
    if (machine != null && machine.isNotEmpty) {
      rows.add(('Architecture', machine));
    }

    final libc = await run('getconf', ['GNU_LIBC_VERSION']);
    if (libc != null && libc.isNotEmpty) rows.add(('libc', libc));

    return rows;
  }

  Future<List<(String, String)>> _hostSection() async {
    final rows = <(String, String)>[];

    final hostname = readFile('/proc/sys/kernel/hostname');
    if (hostname != null && hostname.isNotEmpty) {
      rows.add(('Hostname', hostname));
    }

    final uptime = parseUptime(readFile('/proc/uptime') ?? '');
    if (uptime != null) {
      rows.add(('Uptime', formatDuration(uptime)));
      final boot = clock().subtract(uptime);
      rows.add(('Boot time', _isoNoMillis(boot)));
    }

    return rows;
  }

  Future<List<(String, String)>> _hardwareSection() async {
    final rows = <(String, String)>[];

    String? dmi(String name) {
      final value = readFile('/sys/class/dmi/id/$name')?.trim();
      return (value == null || value.isEmpty) ? null : value;
    }

    final vendor = dmi('sys_vendor');
    final model = dmi('product_name');
    final family = dmi('product_family');
    final board = dmi('board_name');
    final biosVendor = dmi('bios_vendor');
    final biosVersion = dmi('bios_version');
    final biosDate = dmi('bios_date');
    final chassis = dmi('chassis_type');

    if (vendor != null) rows.add(('Vendor', vendor));
    if (family != null && family != model) rows.add(('Family', family));
    if (model != null) rows.add(('Model', model));
    if (board != null) rows.add(('Board', board));
    if (chassis != null) {
      final label = chassisLabel(chassis);
      if (label != null) rows.add(('Chassis', label));
    }
    if (biosVendor != null || biosVersion != null) {
      rows.add((
        'BIOS',
        [biosVendor, biosVersion].whereType<String>().join(' '),
      ));
    }
    if (biosDate != null) rows.add(('BIOS date', biosDate));

    final gpu = await _gpuLines();
    for (final line in gpu) {
      rows.add(('GPU', line));
    }

    return rows;
  }

  Future<List<String>> _gpuLines() async {
    final output = await run('lspci', []);
    if (output == null) return const [];
    final lines = <String>[];
    for (final line in output.split('\n')) {
      final lower = line.toLowerCase();
      if (!lower.contains('vga compatible') &&
          !lower.contains('3d controller') &&
          !lower.contains('display controller')) {
        continue;
      }
      // "00:02.0 VGA compatible controller: Intel Corporation ... (rev 04)"
      final colon = line.indexOf(': ');
      final colon2 = line.indexOf(': ', colon + 2);
      final start = colon2 >= 0 ? colon2 + 2 : line.lastIndexOf(': ') + 2;
      final name = line.substring(start).trim();
      if (name.isNotEmpty) lines.add(name);
    }
    return lines;
  }

  Future<List<(String, String)>> _cpuSection() async {
    final rows = <(String, String)>[];

    var cpu = parseLscpuJson(await run('lscpu', ['-J']) ?? '');
    if (cpu.isEmpty) {
      cpu = parseCpuInfo(readFile('/proc/cpuinfo') ?? '');
    }

    final model = cpu['Model name'];
    if (model != null) rows.add(('Model', model));

    final vendor = cpu['Vendor ID'];
    if (vendor != null) rows.add(('Vendor', vendor));

    final sockets = cpu['Socket(s)'];
    if (sockets != null) rows.add(('Sockets', sockets));

    final cores = cpu['Core(s) per socket'];
    if (cores != null) rows.add(('Cores per socket', cores));

    final threads = cpu['CPU(s)'];
    if (threads != null) rows.add(('Threads', threads));

    final architecture = cpu['Architecture'];
    if (architecture != null) rows.add(('Architecture', architecture));

    final virtualization = cpu['Virtualization'];
    if (virtualization != null) rows.add(('Virtualization', virtualization));

    return rows;
  }

  List<(String, String)> _memorySection() {
    final mem = parseMeminfo(readFile('/proc/meminfo') ?? '');
    final total = mem['MemTotal'];
    if (total == null) return const [];

    final rows = <(String, String)>[];
    final available = mem['MemAvailable'];
    rows.add((
      'RAM',
      available == null
          ? '${formatBytes(total)} total'
          : '${formatBytes(total)} total, ${formatBytes(available)} available',
    ));

    final swapTotal = mem['SwapTotal'];
    if (swapTotal != null) {
      final swapFree = mem['SwapFree'];
      rows.add((
        'Swap',
        swapFree == null
            ? '${formatBytes(swapTotal)} total'
            : '${formatBytes(swapTotal)} total, ${formatBytes(swapFree)} free',
      ));
    }
    return rows;
  }

  Future<List<(String, String)>> _storageSection() async {
    final output = await run('df', ['-kP']);
    if (output == null) return const [];
    return [
      for (final mount in parseDf(output))
        (
          mount.mount,
          '${formatBytes(mount.usedBytes)} / ${formatBytes(mount.totalBytes)} '
              '(${mount.percent}, ${formatBytes(mount.availableBytes)} free)',
        ),
    ];
  }

  Future<List<(String, String)>> _networkSection() async {
    final output = await run('ip', ['-brief', 'addr']);
    if (output == null) return const [];
    return [
      for (final interface in parseIpBriefAddr(output))
        (
          interface.name,
          [
            interface.state,
            if (interface.ipv4.isNotEmpty) interface.ipv4.join(', '),
            if (interface.ipv6.isNotEmpty) interface.ipv6.join(', '),
          ].join('  '),
        ),
    ];
  }

  List<(String, String)> _sessionSection() {
    final rows = <(String, String)>[];
    String? env(String key) {
      final value = environment[key]?.trim();
      return (value == null || value.isEmpty) ? null : value;
    }

    final desktop = env('XDG_CURRENT_DESKTOP') ?? env('XDG_SESSION_DESKTOP');
    if (desktop != null) rows.add(('Desktop', desktop));

    final sessionType = env('XDG_SESSION_TYPE');
    if (sessionType != null) rows.add(('Session', sessionType));

    final locale = env('LC_ALL') ?? env('LANG');
    if (locale != null) rows.add(('Locale', locale));

    return rows;
  }

  /// Default command runner: missing binary or non-zero exit means "no data".
  static Future<String?> _runCommand(String exe, List<String> args) async {
    try {
      final result = await Process.run(
        exe,
        args,
        environment: {'LC_ALL': 'C'},
      ).timeout(commandTimeout);
      if (result.exitCode != 0) return null;
      return (result.stdout as String).trim();
    } catch (_) {
      return null;
    }
  }

  static String? _readFileOrNull(String path) {
    try {
      final file = File(path);
      if (!file.existsSync()) return null;
      return file.readAsStringSync().trim();
    } catch (_) {
      return null;
    }
  }

  // ----------------------------------------------------------------- parsers

  /// Parses `KEY="value"` pairs from `/etc/os-release`.
  @visibleForTesting
  static Map<String, String> parseOsRelease(String content) {
    final map = <String, String>{};
    for (final line in content.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
      final eq = trimmed.indexOf('=');
      if (eq <= 0) continue;
      final key = trimmed.substring(0, eq).trim();
      var value = trimmed.substring(eq + 1).trim();
      if (value.length >= 2 &&
          ((value.startsWith('"') && value.endsWith('"')) ||
              (value.startsWith("'") && value.endsWith("'")))) {
        value = value.substring(1, value.length - 1);
      }
      map[key] = value;
    }
    return map;
  }

  /// Parses `/proc/meminfo` into bytes.
  @visibleForTesting
  static Map<String, int> parseMeminfo(String content) {
    final map = <String, int>{};
    for (final line in content.split('\n')) {
      final match = RegExp(r'^(\w+):\s+(\d+)\s*kB\s*$').firstMatch(line.trim());
      if (match == null) continue;
      map[match.group(1)!] = int.parse(match.group(2)!) * 1024;
    }
    return map;
  }

  /// Parses the first field of `/proc/uptime` into a duration.
  @visibleForTesting
  static Duration? parseUptime(String content) {
    final first = content.trim().split(RegExp(r'\s+')).firstOrNull;
    final seconds = double.tryParse(first ?? '');
    if (seconds == null || seconds.isNaN || seconds.isInfinite) return null;
    return Duration(seconds: seconds.floor());
  }

  /// Parses `df -kP`, keeping real filesystems only.
  @visibleForTesting
  static List<MountUsage> parseDf(String output) {
    final mounts = <MountUsage>[];
    for (final line in output.split('\n').skip(1)) {
      final trimmed = line.trimRight();
      if (trimmed.trim().isEmpty) continue;
      // The mount point is everything after the capacity column, so a path with
      // spaces stays intact.
      final match = RegExp(r'^(\S+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+%)\s+(.+)$')
          .firstMatch(trimmed);
      if (match == null) continue;

      final device = match.group(1)!;
      final mount = match.group(6)!.trim();
      if (device == 'tmpfs' ||
          device == 'devtmpfs' ||
          device == 'efivarfs' ||
          device == 'none' ||
          mount.startsWith('/sys/') ||
          mount.startsWith('/proc/') ||
          mount.startsWith('/run/')) {
        continue;
      }

      mounts.add(
        MountUsage(
          mount: mount,
          totalBytes: int.parse(match.group(2)!) * 1024,
          usedBytes: int.parse(match.group(3)!) * 1024,
          availableBytes: int.parse(match.group(4)!) * 1024,
          percent: match.group(5)!,
        ),
      );
    }
    return mounts;
  }

  /// Parses `ip -brief addr`.
  @visibleForTesting
  static List<NetworkInterfaceInfo> parseIpBriefAddr(String output) {
    final interfaces = <NetworkInterfaceInfo>[];
    for (final line in output.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      final parts = trimmed.split(RegExp(r'\s+'));
      if (parts.length < 2) continue;
      final addresses = parts.skip(2);
      interfaces.add(
        NetworkInterfaceInfo(
          name: parts[0],
          state: parts[1],
          ipv4: addresses.where((a) => !a.contains(':')).toList(),
          ipv6: addresses.where((a) => a.contains(':')).toList(),
        ),
      );
    }
    return interfaces;
  }

  /// Parses `lscpu -J` into a field → data map.
  @visibleForTesting
  static Map<String, String> parseLscpuJson(String output) {
    try {
      final decoded = jsonDecode(output);
      if (decoded is! Map<String, dynamic>) return const {};
      final entries = decoded['lscpu'];
      if (entries is! List) return const {};
      final map = <String, String>{};
      for (final entry in entries) {
        if (entry is! Map) continue;
        final field = entry['field']?.toString();
        final data = entry['data']?.toString();
        if (field == null || data == null) continue;
        map[field.replaceAll(':', '').trim()] = data.trim();
      }
      return map;
    } catch (_) {
      return const {};
    }
  }

  /// Parses `/proc/cpuinfo` into the same field names `lscpu` uses.
  @visibleForTesting
  static Map<String, String> parseCpuInfo(String content) {
    final map = <String, String>{};
    var processors = 0;
    var virtualized = false;
    for (final line in content.split('\n')) {
      final colon = line.indexOf(':');
      if (colon <= 0) continue;
      final key = line.substring(0, colon).trim();
      final value = line.substring(colon + 1).trim();
      if (key == 'processor') {
        processors++;
      } else if (key == 'model name' && !map.containsKey('Model name')) {
        map['Model name'] = value;
      } else if (key == 'vendor_id' && !map.containsKey('Vendor ID')) {
        map['Vendor ID'] = value;
      } else if (key == 'flags' && value.split(' ').contains('hypervisor')) {
        virtualized = true;
      }
    }
    if (processors > 0) map['CPU(s)'] = processors.toString();
    if (virtualized) map['Virtualization'] = 'yes';
    return map;
  }

  // --------------------------------------------------------------- formatting

  /// Human-readable byte count using binary units.
  @visibleForTesting
  static String formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    const units = ['B', 'KB', 'MB', 'GB', 'TB', 'PB'];
    var value = bytes.toDouble();
    var unit = 0;
    while (value >= 1024 && unit < units.length - 1) {
      value /= 1024;
      unit++;
    }
    final digits = unit == 0 ? 0 : 1;
    return '${value.toStringAsFixed(digits)} ${units[unit]}';
  }

  /// Renders a duration as `3d 1h 22m`, dropping trailing zero components.
  @visibleForTesting
  static String formatDuration(Duration duration) {
    final days = duration.inDays;
    final hours = duration.inHours % 24;
    final minutes = duration.inMinutes % 60;
    final seconds = duration.inSeconds % 60;

    if (days > 0) return '${days}d ${hours}h ${minutes}m';
    if (hours > 0) return '${hours}h ${minutes}m';
    if (minutes > 0) return '${minutes}m';
    return '${seconds}s';
  }

  /// Maps a SMBIOS chassis type code to its name.
  static String? chassisLabel(String code) {
    const names = {
      '3': 'Desktop',
      '4': 'Low-profile desktop',
      '5': 'Pizza box',
      '6': 'Mini tower',
      '7': 'Tower',
      '8': 'Portable',
      '9': 'Laptop',
      '10': 'Notebook',
      '11': 'Hand-held',
      '13': 'All-in-one',
      '14': 'Sub-notebook',
      '15': 'Space-saving',
      '16': 'Lunch box',
      '17': 'Main server chassis',
      '23': 'Rack mount',
      '24': 'Sealed-case PC',
      '30': 'Tablet',
      '31': 'Convertible',
      '32': 'Detachable',
      '34': 'Mini PC',
      '35': 'Stick PC',
    };
    return names[code.trim()];
  }

  static String _isoNoMillis(DateTime value) {
    final iso = value.toIso8601String();
    final dot = iso.indexOf('.');
    return dot >= 0 ? iso.substring(0, dot) : iso;
  }

  static String _section(String title, List<(String, String)> rows) {
    final buffer = StringBuffer('[$title]\n');
    for (final (label, value) in rows) {
      buffer.writeln('${label.padRight(20)}: $value');
    }
    return buffer.toString();
  }
}
