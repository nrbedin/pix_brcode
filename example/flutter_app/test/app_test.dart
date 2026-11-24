import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pix_brcode/pix_brcode.dart';
import 'package:pix_checkout_demo/app/app_module.dart';
import 'package:pix_checkout_demo/app/app_widget.dart';
import 'package:pix_checkout_demo/app/modules/checkout/data/datasources/fake_pix_datasource.dart';
import 'package:pix_checkout_demo/app/modules/checkout/domain/enums/payment_step.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'fakes/fake_share_service.dart';

void main() {
  const latency = Duration(milliseconds: 100);
  const stepDelay = Duration(seconds: 1);

  late FakePixDatasource datasource;
  late FakeShareService shareService;
  String? copied;
  String? clipboard;

  setUp(() {
    datasource = FakePixDatasource(
      latency: latency,
      expiresIn: const Duration(seconds: 65),
      stepDelay: stepDelay,
    );
    shareService = FakeShareService();
    copied = null;
    clipboard = null;
  });

  Future<void> pumpApp(WidgetTester tester) async {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String;
        }
        if (call.method == 'Clipboard.getData') {
          return {'text': clipboard};
        }
        return null;
      },
    );
    await tester.pumpWidget(
      ModularApp(
        module: AppModule(datasource: datasource, shareService: shareService),
        child: const AppWidget(),
      ),
    );
    await tester.pumpAndSettle();
    addTearDown(Modular.destroy);
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

  testWidgets('QR, copiar, etapas do pagamento e comprovante', (tester) async {
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

    await tapVisible(tester, find.byKey(const Key('simulate-payment')));
    // A primeira etapa chega num timer de duração zero.
    await tester.pump(const Duration(milliseconds: 10));
    expect(find.byKey(const Key('processing')), findsOneWidget);
    expect(find.text(r'Processando R$ 10,50'), findsOneWidget);

    // Cada etapa fica concluída (✓) conforme o backend avisa.
    Finder doneIn(PaymentStep step) => find.descendant(
          of: find.byKey(Key('step-${step.name}')),
          matching: find.byKey(const Key('done')),
        );
    expect(doneIn(PaymentStep.payerAuthorized), findsNothing);
    await tester.pump(stepDelay);
    expect(doneIn(PaymentStep.payerAuthorized), findsOneWidget);
    expect(doneIn(PaymentStep.settlingInSpi), findsNothing);
    await tester.pump(stepDelay * 2);
    expect(doneIn(PaymentStep.creditedByPsp), findsOneWidget);

    await tester.pump(stepDelay);
    expect(find.byKey(const Key('paid')), findsOneWidget);
    expect(find.text('Pagamento recebido'), findsOneWidget);
    expect(find.text('Pagador Ficticio'), findsOneWidget);
    expect(find.textContaining(RegExp(r'^E\d{8}')), findsOneWidget);

    await tapVisible(tester, find.text('Nova cobrança'));
    expect(find.byKey(const Key('amount-form')), findsOneWidget);
  });

  testWidgets('compartilha o QR como imagem', (tester) async {
    await pumpApp(tester);
    await generate(tester, '7');

    // O PNG é desenhado pelo engine, fora do relógio falso do teste.
    await tester.ensureVisible(find.byKey(const Key('share')));
    await tester.pump();
    await tester.runAsync(() async {
      await tester.tap(find.byKey(const Key('share')));
      while (shareService.shared.isEmpty) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
    });

    final shared = shareService.shared.single;
    expect(shared.fileName, endsWith('.png'));
    expect(shared.png.sublist(0, 4), [137, 80, 78, 71]);
    expect(shared.text, contains(r'R$ 7,00'));
    expect(shared.origin, isNotNull);

    await tapVisible(tester, find.text('Cancelar'));
  });

  testWidgets('falha ao compartilhar avisa e mantém o QR', (tester) async {
    shareService.failNext = true;
    await pumpApp(tester);
    await generate(tester, '7');

    await tester.ensureVisible(find.byKey(const Key('share')));
    await tester.pump();
    await tester.runAsync(() async {
      await tester.tap(find.byKey(const Key('share')));
      while (shareService.failNext) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
    });
    await tester.pump();
    expect(find.text('Não deu para compartilhar o QR Code'), findsOneWidget);
    expect(find.byKey(const Key('awaiting')), findsOneWidget);

    await tapVisible(tester, find.text('Cancelar'));
  });

  testWidgets('QR expira e pode ser gerado de novo', (tester) async {
    await pumpApp(tester);
    await generate(tester, '5');

    await tester.pump(const Duration(seconds: 65));
    expect(find.byKey(const Key('expired')), findsOneWidget);

    await tester.tap(find.text('Gerar novo QR Code'));
    await tester.pump();
    await tester.pump(latency);
    expect(find.text(r'R$ 5,00'), findsOneWidget);

    await tapVisible(tester, find.text('Cancelar'));
    expect(find.byKey(const Key('amount-form')), findsOneWidget);
  });

  testWidgets('erro do backend permite tentar de novo', (tester) async {
    datasource.failNextCharge = true;
    await pumpApp(tester);
    await generate(tester, '5');

    expect(find.byKey(const Key('failed')), findsOneWidget);
    expect(find.textContaining('503'), findsOneWidget);

    await tester.tap(find.text('Tentar de novo'));
    await tester.pump();
    await tester.pump(latency);
    expect(find.byKey(const Key('awaiting')), findsOneWidget);

    await tester.pump(const Duration(seconds: 65));
    expect(find.byKey(const Key('expired')), findsOneWidget);
    await tapVisible(tester, find.text('Alterar valor'));
    expect(find.byKey(const Key('amount-form')), findsOneWidget);
  });

  group('leitor', () {
    Future<void> openReader(WidgetTester tester) async {
      await pumpApp(tester);
      await tester.tap(find.byKey(const Key('open-reader')));
      await tester.pumpAndSettle();
      expect(find.text('Ler QR Code Pix'), findsOneWidget);
    }

    testWidgets('colar um BR Code mostra o resumo e os campos', (tester) async {
      clipboard = StaticPixPayload(
        key: PixKey.parse('fulano@exemplo.com'),
        merchantName: 'Fulano de Tal',
        merchantCity: 'CURITIBA',
        amount: 25,
        txid: 'PEDIDO42',
      ).encode();
      await openReader(tester);

      await tester.tap(find.byKey(const Key('paste')));
      await tester.pump();
      expect(find.byKey(const Key('decoded')), findsOneWidget);
      expect(find.text('Estático · reutilizável'), findsOneWidget);
      expect(find.text(r'R$ 25,00'), findsOneWidget);
      expect(find.text('fulano@exemplo.com'), findsOneWidget);
      expect(find.text('PEDIDO42'), findsOneWidget);

      await tapVisible(tester, find.text('Campos EMV'));
      await tester.pumpAndSettle();
      expect(find.text('Conta Pix'), findsOneWidget);
      expect(find.text('Identificador (txid)'), findsOneWidget);

      // Voltar leva à tela de pagamento.
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('amount-form')), findsOneWidget);
    });

    testWidgets('código inválido mostra o campo e a posição', (tester) async {
      await openReader(tester);
      final valid = DynamicPixPayload(
        url: 'pix.exemplo.com.br/qr/v2/cobv/ABC',
        merchantName: 'Loja Exemplo',
        merchantCity: 'SAO PAULO',
      ).encode();
      final broken = '${valid.substring(0, valid.length - 4)}0000';

      await tester.enterText(find.byKey(const Key('brcode-field')), broken);
      await tester.tap(find.byKey(const Key('read')));
      await tester.pump();
      expect(find.byKey(const Key('invalid')), findsOneWidget);
      expect(find.textContaining('Campo 63: CRC inválido'), findsOneWidget);
      expect(find.byKey(const Key('error-source')), findsOneWidget);
    });

    testWidgets('ler sem texto pede um código', (tester) async {
      await openReader(tester);
      await tester.tap(find.byKey(const Key('read')));
      await tester.pump();
      expect(find.byKey(const Key('idle-message')), findsOneWidget);
    });
  });
}
