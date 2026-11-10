import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:dev_stack/features/system/data/linux_system_probe.dart';

void main() {
  group('parseMeminfo', () {
    test('reads total, available and swap in bytes', () {
      const content = '''
MemTotal:       15965416 kB
MemFree:          384576 kB
MemAvailable:    5225316 kB
SwapTotal:      29549356 kB
SwapFree:       23253376 kB
''';

      final mem = LinuxSystemProbe.parseMeminfo(content);

      expect(mem['MemTotal'], 15965416 * 1024);
      expect(mem['MemAvailable'], 5225316 * 1024);
      expect(mem['SwapTotal'], 29549356 * 1024);
      expect(mem['SwapFree'], 23253376 * 1024);
    });

    test('ignores lines without a kB value', () {
      final mem = LinuxSystemProbe.parseMeminfo('MemTotal: 100 kB\nBogus: x\n');

      expect(mem, {'MemTotal': 100 * 1024});
    });
  });

  group('parseUptime', () {
    test('reads seconds from /proc/uptime', () {
      expect(
        LinuxSystemProbe.parseUptime('61742.69 964614.77\n'),
        const Duration(seconds: 61742),
      );
    });

    test('returns null for unparseable content', () {
      expect(LinuxSystemProbe.parseUptime('nonsense\n'), isNull);
    });
  });

  group('formatBytes', () {
    test('scales to the largest binary unit with one decimal', () {
      expect(LinuxSystemProbe.formatBytes(15965416 * 1024), '15.2 GB');
      expect(LinuxSystemProbe.formatBytes(512 * 1024), '512.0 KB');
      expect(LinuxSystemProbe.formatBytes(0), '0 B');
    });
  });

  group('formatDuration', () {
    test('renders days, hours, minutes and seconds', () {
      expect(LinuxSystemProbe.formatDuration(const Duration(seconds: 45)), '45s');
      expect(LinuxSystemProbe.formatDuration(const Duration(minutes: 9)), '9m');
      expect(
        LinuxSystemProbe.formatDuration(const Duration(hours: 17, minutes: 9)),
        '17h 9m',
      );
      expect(
        LinuxSystemProbe.formatDuration(
          const Duration(days: 3, hours: 1, minutes: 22),
        ),
        '3d 1h 22m',
      );
    });
  });

  group('parseDf', () {
    test('keeps real filesystems and drops virtual ones', () {
      const out = '''
Filesystem     1024-blocks      Used Available Capacity Mounted on
/dev/nvme0n1p3   250000000  95502944 151546832      39% /
efivarfs               192       138        50      74% /sys/firmware/efi/efivars
/dev/nvme0n1p4   242400700 110273656 119740948      48% /mnt/Data
tmpfs              7955200         0   7955200       0% /run/user/1000
''';

      final mounts = LinuxSystemProbe.parseDf(out);

      expect(mounts.map((m) => m.mount), ['/', '/mnt/Data']);
      expect(mounts.first.totalBytes, 250000000 * 1024);
      expect(mounts.first.percent, '39%');
    });

    test('keeps mount points that contain spaces', () {
      const out = '''
Filesystem     1024-blocks      Used Available Capacity Mounted on
/dev/sda1       1000000    500000    500000      50% /media/My Disk
''';

      expect(LinuxSystemProbe.parseDf(out).single.mount, '/media/My Disk');
    });
  });

  group('parseIpBriefAddr', () {
    test('splits name, state and addresses, flagging IPv4', () {
      const out = '''
lo               UNKNOWN        127.0.0.1/8 ::1/128
enp2s0           UP             192.168.158.29/23 fe80::1d2e:472f:dfdb:4de0/64
wlo1             DOWN
''';

      final interfaces = LinuxSystemProbe.parseIpBriefAddr(out);

      expect(interfaces.map((i) => i.name), ['lo', 'enp2s0', 'wlo1']);
      expect(interfaces[1].state, 'UP');
      expect(interfaces[1].ipv4, ['192.168.158.29/23']);
      expect(interfaces[1].ipv6, ['fe80::1d2e:472f:dfdb:4de0/64']);
      expect(interfaces[2].ipv4, isEmpty);
    });
  });

  group('parseLscpuJson', () {
    test('reads the fields that describe the CPU', () {
      final json = jsonEncode({
        'lscpu': [
          {'field': 'Architecture:', 'data': 'x86_64'},
          {'field': 'CPU(s):', 'data': '16'},
          {'field': 'Vendor ID:', 'data': 'GenuineIntel'},
          {'field': 'Model name:', 'data': 'Intel(R) Core(TM) i5-14400'},
          {
            'field': 'Thread(s) per core:',
            'data': '2',
          },
        ],
      });

      final cpu = LinuxSystemProbe.parseLscpuJson(json);

      expect(cpu['Model name'], 'Intel(R) Core(TM) i5-14400');
      expect(cpu['CPU(s)'], '16');
      expect(cpu['Vendor ID'], 'GenuineIntel');
      expect(cpu['Architecture'], 'x86_64');
    });

    test('returns an empty map for malformed output', () {
      expect(LinuxSystemProbe.parseLscpuJson('not json'), isEmpty);
    });
  });

  group('parseCpuInfo', () {
    test('reads the model and counts logical processors', () {
      const content = '''
processor\t: 0
model name\t: AMD Ryzen 9 5950X
flags\t: fpu hypervisor sse

processor\t: 1
model name\t: AMD Ryzen 9 5950X
flags\t: fpu sse
''';

      final cpu = LinuxSystemProbe.parseCpuInfo(content);

      expect(cpu['Model name'], 'AMD Ryzen 9 5950X');
      expect(cpu['CPU(s)'], '2');
      expect(cpu['Virtualization'], 'yes');
    });

    test('omits virtualization when no processor reports a hypervisor', () {
      final cpu = LinuxSystemProbe.parseCpuInfo(
        'processor\t: 0\nmodel name\t: Bare Metal\nflags\t: sse\n',
      );

      expect(cpu.containsKey('Virtualization'), isFalse);
    });
  });

  group('describe', () {
    test('assembles the sections from the available sources', () async {
      final probe = LinuxSystemProbe(
        run: (exe, args) async => switch ((exe, args.firstOrNull)) {
          ('uname', '-r') => '6.17.8-200.fc44.x86_64',
          ('uname', '-m') => 'x86_64',
          ('getconf', 'GNU_LIBC_VERSION') => 'glibc 2.43',
          ('lscpu', '-J') =>
            jsonEncode({
              'lscpu': [
                {'field': 'Model name:', 'data': 'Intel(R) Core(TM) i5-14400'},
                {'field': 'CPU(s):', 'data': '16'},
              ],
            }),
          ('df', '-kP') => '''
Filesystem     1024-blocks      Used Available Capacity Mounted on
/dev/nvme0n1p3   250000000  95502944 151546832      39% /
''',
          ('ip', '-brief') =>
            'enp2s0           UP             192.168.158.29/23 \n',
          _ => null,
        },
        readFile: (path) => switch (path) {
          '/etc/os-release' =>
            'PRETTY_NAME="Fedora Linux 44 (Workstation Edition)"\nID=fedora\nVERSION_ID=44\n',
          '/proc/meminfo' =>
            'MemTotal: 15965416 kB\nMemAvailable: 5225316 kB\nSwapTotal: 29549356 kB\nSwapFree: 23253376 kB\n',
          '/proc/uptime' => '61740.00 964614.77\n',
          '/proc/sys/kernel/hostname' => 'fedora\n',
          '/sys/class/dmi/id/sys_vendor' => 'LENOVO\n',
          '/sys/class/dmi/id/product_name' => 'ThinkCentre neo 50s Gen 5\n',
          _ => null,
        },
        environment: {
          'XDG_CURRENT_DESKTOP': 'GNOME',
          'XDG_SESSION_TYPE': 'wayland',
          'LANG': 'en_US.UTF-8',
        },
        clock: () => DateTime.utc(2026, 11, 10, 8),
      );

      final text = await probe.describe();

      expect(text, contains('[OS]'));
      expect(text, contains('OS                  : Fedora Linux 44 (Workstation Edition)'));
      expect(text, contains('Kernel              : 6.17.8-200.fc44.x86_64'));
      expect(text, contains('Architecture        : x86_64'));
      expect(text, contains('libc                : glibc 2.43'));
      expect(text, contains('[HOST]'));
      expect(text, contains('Hostname            : fedora'));
      expect(text, contains('Uptime              : 17h 9m'));
      expect(text, contains('Boot time           : 2026-11-09T14:51:00'));
      expect(text, contains('[HARDWARE]'));
      expect(text, contains('Vendor              : LENOVO'));
      expect(text, contains('Model               : ThinkCentre neo 50s Gen 5'));
      expect(text, contains('[CPU]'));
      expect(text, contains('Model               : Intel(R) Core(TM) i5-14400'));
      expect(text, contains('Threads             : 16'));
      expect(text, contains('[MEMORY]'));
      expect(text, contains('RAM                 : 15.2 GB total, 5.0 GB available'));
      expect(text, contains('Swap                : 28.2 GB total, 22.2 GB free'));
      expect(text, contains('[STORAGE]'));
      expect(text, contains('/'));
      expect(text, contains('39%'));
      expect(text, contains('[NETWORK]'));
      expect(text, contains('enp2s0'));
      expect(text, contains('192.168.158.29/23'));
      expect(text, contains('[SESSION]'));
      expect(text, contains('Desktop             : GNOME'));
      expect(text, contains('Session             : wayland'));
      expect(text, contains('Locale              : en_US.UTF-8'));
    });

    test('omits a section whose tool is missing instead of guessing', () async {
      final probe = LinuxSystemProbe(
        run: (exe, args) async => null,
        readFile: (path) => path == '/etc/os-release'
            ? 'PRETTY_NAME="Alpine Linux v3.20"\n'
            : null,
        environment: const {},
      );

      final text = await probe.describe();

      expect(text, contains('OS                  : Alpine Linux v3.20'));
      expect(text, isNot(contains('[HARDWARE]')));
      expect(text, isNot(contains('[STORAGE]')));
      expect(text, isNot(contains('[NETWORK]')));
      expect(text, isNot(contains('[SESSION]')));
      expect(text, isNot(contains('GPU')));
    });

    test('falls back to /proc/cpuinfo when lscpu is unavailable', () async {
      final probe = LinuxSystemProbe(
        run: (exe, args) async => null,
        readFile: (path) => switch (path) {
          '/proc/cpuinfo' => 'processor\t: 0\nmodel name\t: Bare Metal Chip\n',
          _ => null,
        },
        environment: const {},
      );

      final text = await probe.describe();

      expect(text, contains('[CPU]'));
      expect(text, contains('Model               : Bare Metal Chip'));
    });
  });
}
