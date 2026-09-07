import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dev_stack/features/tunnels/presentation/widgets/tunnel_qr_modal.dart';

void main() {
  testWidgets('TunnelQrModal renders public URL and QR view', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: TunnelQrModal(
            tunnelName: 'Test Tunnel',
            publicUrl: 'https://test.trycloudflare.com',
          ),
        ),
      ),
    );

    expect(find.text('Test Tunnel - QR Code'), findsOneWidget);
    expect(find.text('https://test.trycloudflare.com'), findsOneWidget);
    expect(find.text('Copy Link'), findsOneWidget);
  });
}
