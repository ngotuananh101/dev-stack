import 'package:dev_stack/features/apps/data/apps_provider.dart';
import 'package:dev_stack/features/apps/domain/app_model.dart';
import 'package:dev_stack/features/sites/data/sites_provider.dart';
import 'package:dev_stack/features/sites/domain/site_model.dart';
import 'package:dev_stack/features/tunnels/presentation/widgets/create_tunnel_modal.dart';
import 'package:dev_stack/shared/widgets/app_button.dart';
import 'package:dev_stack/shared/widgets/app_modal_header.dart';
import 'package:dev_stack/shared/widgets/app_text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _StaticAppsNotifier extends Apps {
  @override
  Future<List<AppModel>> build() => Future.value([]);
}

class _StaticSitesNotifier extends Sites {
  final List<SiteModel> _sites;
  _StaticSitesNotifier(this._sites);

  @override
  Future<List<SiteModel>> build() => Future.value(_sites);
}

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  group('CreateTunnelModal Layout and Field Standardization', () {
    testWidgets('renders standard labels, inputs, and 36px controls', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1080, 720));
      addTearDown(() => tester.binding.setSurfaceSize(const Size(800, 600)));

      final testSites = [
        SiteModel(
          id: 1,
          domain: 'mysite.test',
          rootDir: 'C:\\Projects\\mysite',
          siteType: 'php',
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appsProvider.overrideWith(() => _StaticAppsNotifier()),
            sitesProvider.overrideWith(() => _StaticSitesNotifier(testSites)),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: CreateTunnelModal(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check AppModalHeader
      expect(find.byType(AppModalHeader), findsOneWidget);
      final header = tester.widget<AppModalHeader>(find.byType(AppModalHeader));
      expect(header.title, 'Create Tunnel');

      // Check standard section labels exist
      expect(find.text('Tunnel Name'), findsOneWidget);
      expect(find.text('Target Type'), findsOneWidget);
      expect(find.text('Provider'), findsOneWidget);
      expect(find.text('Target Site'), findsOneWidget);
      expect(find.text('Auth Token (Optional)'), findsOneWidget);
      expect(find.text('Custom Domain (Optional)'), findsOneWidget);

      // Check AppTextField widgets are used
      expect(find.byType(AppTextField), findsWidgets);

      // Check Buttons
      expect(find.widgetWithText(AppButton, 'Cancel'), findsOneWidget);
      expect(find.widgetWithText(AppButton, 'Create Tunnel'), findsOneWidget);

      // Target Type toggle items (Site and Port)
      expect(find.text('Site'), findsOneWidget);
      expect(find.text('Port'), findsOneWidget);

      // Switch to Port target and verify 'Target Port' label and field appear
      await tester.tap(find.text('Port'));
      await tester.pumpAndSettle();

      expect(find.text('Target Port'), findsOneWidget);
    });
  });
}
