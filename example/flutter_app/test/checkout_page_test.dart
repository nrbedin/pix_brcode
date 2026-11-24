import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pix_checkout_demo/main.dart';
import 'package:pix_checkout_demo/src/fake_pix_gateway.dart';
import 'package:qr_flutter/qr_flutter.dart';

void main() {
  const latency = Duration(milliseconds: 100);

  late FakePixGateway gateway;
  String? copied;

  setUp(() {
    gateway = FakePixGateway(
      latency: latency,
      expiresIn: const Duration(seconds: 65),
    );
    copied = null;
  });

  Future<void> pumpApp(WidgetTester tester) async {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String;
        }
        return null;
      },
    );
    await tester.pumpWidget(PixCheckoutDemoApp(gateway: gateway));
  }

  /// Rola até [finder] e toca, já que a tela de teste é pequena (800×600).
  Future<void> tapVisible(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pump();
    await tester.tap(finder);
    await tester.pump();
  }

  Future<void> generate(WidgetTester tester, String amount) async {
    await tester.enterText(find.byKey(const Key('amount-field')), amount);
    await tester.tap(find.byKey(const Key('generate')));
    await tester.pump();
    expect(find.byKey(const Key('creating')), findsOneWidget);
    await tester.pump(latency);
  }

  testWidgets('valor inválido mostra erro no campo', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.byKey(const Key('generate')));
    await tester.pump();
    expect(find.text('Informe um valor maior que zero.'), findsOneWidget);
  });

  testWidgets('gera QR, copia o código e confirma o pagamento', (tester) async {
    await pumpApp(tester);
    await generate(tester, '10,50');

    expect(find.byKey(const Key('awaiting')), findsOneWidget);
    expect(find.byType(QrImageView), findsOneWidget);
    expect(find.text(r'R$ 10,50'), findsOneWidget);
    expect(find.text('para Loja Exemplo · SAO PAULO'), findsOneWidget);
    expect(find.textContaining('expira em 01:05'), findsOneWidget);

    await tapVisible(tester, find.byKey(const Key('copy')));
    expect(copied, startsWith('000201'));
    expect(find.text('Código Pix copiado'), findsOneWidget);

    await tester.pump(const Duration(seconds: 1));
    expect(find.textContaining('expira em 01:04'), findsOneWidget);

    // Espera o SnackBar sumir, para ele não cobrir o botão do rodapé.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(find.text('Código Pix copiado'), findsNothing);

    await tapVisible(tester, find.byKey(const Key('simulate-payment')));
    expect(find.byKey(const Key('paid')), findsOneWidget);
    expect(find.text(r'R$ 10,50 para Loja Exemplo'), findsOneWidget);

    await tester.tap(find.text('Nova cobrança'));
    await tester.pump();
    expect(find.byKey(const Key('amount-form')), findsOneWidget);
  });

  testWidgets('QR expira e pode ser gerado de novo', (tester) async {
    await pumpApp(tester);
    await generate(tester, '5');

    await tester.pump(const Duration(seconds: 65));
    expect(find.byKey(const Key('expired')), findsOneWidget);

    await tester.tap(find.text('Gerar novo QR Code'));
    await tester.pump();
    await tester.pump(latency);
    expect(find.byKey(const Key('awaiting')), findsOneWidget);
    expect(find.text(r'R$ 5,00'), findsOneWidget);

    await tapVisible(tester, find.text('Cancelar'));
    expect(find.byKey(const Key('amount-form')), findsOneWidget);
  });

  testWidgets('erro do backend permite tentar de novo', (tester) async {
    gateway.failNextCharge = true;
    await pumpApp(tester);
    await generate(tester, '5');

    expect(find.byKey(const Key('failed')), findsOneWidget);
    expect(find.textContaining('indisponível'), findsOneWidget);

    await tester.tap(find.text('Tentar de novo'));
    await tester.pump();
    await tester.pump(latency);
    expect(find.byKey(const Key('awaiting')), findsOneWidget);
  });
}
