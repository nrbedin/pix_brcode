import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:pix_checkout_demo/app/core/share/qr_image_renderer.dart';

void main() {
  testWidgets('gera um PNG com o QR e a legenda abaixo', (tester) async {
    const renderer = QrImageRenderer(qrSize: 200, padding: 20);

    final image = await tester.runAsync(() async {
      final png = await renderer.renderPng(
        data: '00020101021226',
        title: r'R$ 10,50',
        subtitle: 'para Loja Exemplo · SAO PAULO',
      );
      // Assinatura de todo arquivo PNG.
      expect(png.sublist(0, 8), [137, 80, 78, 71, 13, 10, 26, 10]);
      final codec = await ui.instantiateImageCodec(png);
      return (await codec.getNextFrame()).image;
    });

    expect(image!.width, 240);
    // QR + margens + duas linhas de legenda.
    expect(image.height, greaterThan(240));
    image.dispose();
  });
}
