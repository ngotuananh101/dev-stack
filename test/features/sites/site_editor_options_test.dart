import 'package:dev_stack/features/sites/presentation/site_editor_options.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('site config editor exposes Caddy', () {
    expect(siteConfigEditorOptions, contains((id: 'caddy', label: 'Caddy')));
  });

  test('site log selector exposes Caddy access and runtime logs', () {
    expect(
      siteLogOptions,
      containsAll([
        (id: 'caddy_access', label: 'Caddy Access'),
        (id: 'caddy_error', label: 'Caddy Runtime'),
      ]),
    );
  });
}
