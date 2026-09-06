import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dev_stack/features/apps/domain/app_brand_resolver.dart';
import 'package:dev_stack/core/theme/app_colors.dart';

void main() {
  group('AppBrandResolver', () {
    group('iconFileName', () {
      test('resolves runtime icons for bun, deno, nodejs', () {
        expect(AppBrandResolver.iconFileName('bun'), equals('bun'));
        expect(AppBrandResolver.iconFileName('bun1'), equals('bun'));
        expect(AppBrandResolver.iconFileName('deno'), equals('deno'));
        expect(AppBrandResolver.iconFileName('nodejs'), equals('nodejs'));
      });

      test('resolves php variants including php84', () {
        expect(AppBrandResolver.iconFileName('php84'), equals('php'));
        expect(AppBrandResolver.iconFileName('phpmyadmin'), equals('phpmyadmin'));
      });

      test('resolves database and other app icons', () {
        expect(AppBrandResolver.iconFileName('mysql'), equals('mysql'));
        expect(AppBrandResolver.iconFileName('mariadb'), equals('mariadb'));
        expect(AppBrandResolver.iconFileName('mongodb'), equals('mongodb'));
        expect(AppBrandResolver.iconFileName('postgresql'), equals('postgre'));
        expect(AppBrandResolver.iconFileName('redis'), equals('redis'));
        expect(AppBrandResolver.iconFileName('caddy'), equals('caddy'));
        expect(AppBrandResolver.iconFileName('nginx'), equals('nginx'));
        expect(AppBrandResolver.iconFileName('apache'), equals('apache'));
        expect(AppBrandResolver.iconFileName('python'), equals('python'));
        expect(AppBrandResolver.iconFileName('pyenv'), equals('python'));
        expect(AppBrandResolver.iconFileName('rustfs'), equals('rustfs'));
        expect(AppBrandResolver.iconFileName('meilisearch'), equals('meilisearch'));
        expect(AppBrandResolver.iconFileName('elasticsearch'), equals('elasticsearch'));
      });

      test('falls back to group name when no specific match', () {
        expect(AppBrandResolver.iconFileName('unknown', groupName: 'node'), equals('node'));
        expect(AppBrandResolver.iconFileName('unknown', groupName: 'php'), equals('php'));
        expect(AppBrandResolver.iconFileName('unknown'), equals(''));
      });
    });

    group('iconColor', () {
      test('resolves bun brand color', () {
        expect(AppBrandResolver.iconColor('bun'), equals(const Color(0xFFE5A83B)));
      });

      test('resolves deno brand color', () {
        expect(AppBrandResolver.iconColor('deno'), equals(const Color(0xFF70FFAF)));
      });

      test('resolves nodejs/node brand color', () {
        expect(AppBrandResolver.iconColor('nodejs'), equals(const Color(0xFF68A063)));
        expect(AppBrandResolver.iconColor('node'), equals(const Color(0xFF68A063)));
      });

      test('resolves other app brand colors', () {
        expect(AppBrandResolver.iconColor('caddy'), equals(const Color(0xFF1F8C5B)));
        expect(AppBrandResolver.iconColor('nginx'), equals(const Color(0xFF009639)));
        expect(AppBrandResolver.iconColor('php'), equals(const Color(0xFF777BB4)));
        expect(AppBrandResolver.iconColor('mysql'), equals(const Color(0xFF4479A1)));
        expect(AppBrandResolver.iconColor('postgresql'), equals(const Color(0xFF336791)));
      });

      test('falls back to default color for unknown apps', () {
        expect(AppBrandResolver.iconColor('unknown'), equals(const Color(0xFF000000)));
      });

      test('uses custom fallback color', () {
        expect(
          AppBrandResolver.iconColor('unknown', fallback: AppColors.primary),
          equals(AppColors.primary),
        );
      });
    });

    group('fallbackIcon', () {
      test('returns appropriate icons for known app categories', () {
        expect(AppBrandResolver.fallbackIcon('python'), equals(Icons.code));
        expect(AppBrandResolver.fallbackIcon('pyenv'), equals(Icons.code));
        expect(AppBrandResolver.fallbackIcon('node'), equals(Icons.javascript));
        expect(AppBrandResolver.fallbackIcon('nodejs'), equals(Icons.javascript));
        expect(AppBrandResolver.fallbackIcon('php'), equals(Icons.code));
        expect(AppBrandResolver.fallbackIcon('mysql'), equals(Icons.storage));
        expect(AppBrandResolver.fallbackIcon('caddy'), equals(Icons.dns));
        expect(AppBrandResolver.fallbackIcon('nginx'), equals(Icons.cloud));
      });

      test('returns default icons for unknown apps', () {
        expect(AppBrandResolver.fallbackIcon('unknown'), equals(Icons.apps));
      });
    });
  });

  // Keep the original group for backward compatibility / broader test coverage
  group('App Brand UI resolution for Bun and Deno', () {
    test('resolves bun icon and brand color', () {
      expect(AppBrandResolver.iconFileName('bun'), equals('bun'));
      expect(AppBrandResolver.iconColor('bun'), equals(const Color(0xFFE5A83B)));
    });

    test('resolves deno icon and brand color', () {
      expect(AppBrandResolver.iconFileName('deno'), equals('deno'));
      expect(AppBrandResolver.iconColor('deno'), equals(const Color(0xFF70FFAF)));
    });
  });
}
