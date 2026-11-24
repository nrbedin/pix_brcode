import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:pix_brcode/pix_brcode.dart';
import 'package:pix_checkout_demo/src/checkout_controller.dart';
import 'package:pix_checkout_demo/src/fake_pix_gateway.dart';
import 'package:pix_checkout_demo/src/pix_gateway.dart';

/// Gateway que devolve um BR Code fixo, para testar a validação do front.
final class _FixedGateway implements PixGateway {
  _FixedGateway(this.brCode);

  final String brCode;

  @override
  Future<PixCharge> createCharge({required double amount}) async =>
      PixCharge(txid: 'FIXO', brCode: brCode, expiresIn: Duration(minutes: 1));

  @override
  Stream<ChargeStatus> watchStatus(String txid) => const Stream.empty();

  @override
  Future<void> cancel(String txid) async {}
}

/// Gateway em que o teste controla quando a cobrança é criada e o status.
final class _ManualGateway implements PixGateway {
  final pending = Completer<PixCharge>();
  final status = StreamController<ChargeStatus>.broadcast();
  final cancelled = <String>[];

  @override
  Future<PixCharge> createCharge({required double amount}) => pending.future;

  @override
  Stream<ChargeStatus> watchStatus(String txid) => status.stream;

  @override
  Future<void> cancel(String txid) async => cancelled.add(txid);
}

String dynamicBrCode({double? amount}) => DynamicPixPayload(
      url: 'pix.exemplo.com.br/qr/v2/cobv/TESTE',
      merchantName: 'Loja Exemplo',
      merchantCity: 'SAO PAULO',
      amount: amount,
    ).encode();

void main() {
  const latency = Duration(milliseconds: 100);

  late FakePixGateway gateway;
  late CheckoutController controller;

  setUp(() {
    gateway = FakePixGateway(
      latency: latency,
      expiresIn: const Duration(seconds: 3),
    );
    controller = CheckoutController(gateway);
  });

  tearDown(() => controller.dispose());

  group('valor digitado', () {
    for (final text in ['', 'abc', '0', '-5', '0,00']) {
      test('"$text" é rejeitado', () async {
        await controller.submitAmount(text);
        expect(controller.state, isA<EnteringAmount>());
        expect((controller.state as EnteringAmount).error, isNotNull);
      });
    }

    test('acima do limite é rejeitado', () async {
      await controller.submitAmount('99999999999');
      expect(
        (controller.state as EnteringAmount).error,
        contains('limite'),
      );
    });
  });

  testWidgets('fluxo feliz: cria, mostra QR válido e confirma', (tester) async {
    final future = controller.submitAmount('10,50');
    expect(controller.state, isA<CreatingCharge>());

    await tester.pump(latency);
    await future;

    final awaiting = controller.state as AwaitingPayment;
    expect(awaiting.amount, 10.5);
    expect(awaiting.payload, isA<DynamicPixPayload>());
    expect(awaiting.payload.amount, 10.5);
    expect(awaiting.remaining, const Duration(seconds: 3));
    expect(Crc16.isValid(awaiting.charge.brCode), isTrue);

    gateway.simulatePayment(awaiting.charge.txid);
    await tester.pump();

    expect(controller.state, isA<PaymentConfirmed>());
  });

  testWidgets('countdown diminui e expira', (tester) async {
    final future = controller.createCharge(5);
    await tester.pump(latency);
    await future;

    await tester.pump(const Duration(seconds: 1));
    expect(
      (controller.state as AwaitingPayment).remaining,
      const Duration(seconds: 2),
    );

    await tester.pump(const Duration(seconds: 2));
    expect(controller.state, isA<ChargeExpired>());
    expect((controller.state as ChargeExpired).amount, 5);
  });

  testWidgets('falha do backend vira CheckoutFailed', (tester) async {
    gateway.failNextCharge = true;
    final future = controller.createCharge(5);
    await tester.pump(latency);
    await future;

    final failed = controller.state as CheckoutFailed;
    expect(failed.message, contains('indisponível'));
    expect(failed.amount, 5);
  });

  test('BR Code inválido do backend não chega à tela', () async {
    final broken = '${dynamicBrCode().substring(0, 20)}63040000';
    final controller = CheckoutController(_FixedGateway(broken));
    addTearDown(controller.dispose);

    await controller.createCharge(5);
    expect(
      (controller.state as CheckoutFailed).message,
      contains('QR inválido'),
    );
  });

  test('valor do QR diferente do pedido é recusado', () async {
    final controller =
        CheckoutController(_FixedGateway(dynamicBrCode(amount: 50)));
    addTearDown(controller.dispose);

    await controller.createCharge(5);
    expect(
      (controller.state as CheckoutFailed).message,
      contains('diferente do pedido'),
    );
  });

  test('QR sem valor é aceito', () async {
    final controller = CheckoutController(_FixedGateway(dynamicBrCode()));
    addTearDown(controller.dispose);

    await controller.createCharge(5);
    expect(controller.state, isA<AwaitingPayment>());
  });

  test('status expired do backend encerra a cobrança', () async {
    final manual = _ManualGateway();
    final controller = CheckoutController(manual);
    addTearDown(controller.dispose);

    final future = controller.createCharge(5);
    manual.pending.complete(
      PixCharge(
          txid: 'T1', brCode: dynamicBrCode(), expiresIn: Duration(minutes: 1)),
    );
    await future;

    manual.status.add(ChargeStatus.pending);
    await Future<void>.delayed(Duration.zero);
    expect(controller.state, isA<AwaitingPayment>());

    manual.status.add(ChargeStatus.expired);
    await Future<void>.delayed(Duration.zero);
    expect(controller.state, isA<ChargeExpired>());
  });

  test('cancelar durante a criação descarta a resposta atrasada', () async {
    final manual = _ManualGateway();
    final controller = CheckoutController(manual);
    addTearDown(controller.dispose);

    final future = controller.createCharge(5);
    controller.cancel();
    manual.pending.complete(
      PixCharge(
          txid: 'T2', brCode: dynamicBrCode(), expiresIn: Duration(minutes: 1)),
    );
    await future;

    expect(controller.state, isA<EnteringAmount>());
    expect(manual.cancelled, ['T2']);
  });

  test('cancelar com QR na tela avisa o backend', () async {
    final manual = _ManualGateway();
    final controller = CheckoutController(manual);
    addTearDown(controller.dispose);

    final future = controller.createCharge(5);
    manual.pending.complete(
      PixCharge(
          txid: 'T3', brCode: dynamicBrCode(), expiresIn: Duration(minutes: 1)),
    );
    await future;

    controller.cancel();
    expect(controller.state, isA<EnteringAmount>());
    expect(manual.cancelled, ['T3']);
  });

  test('formatBrl', () {
    expect(formatBrl(10.5), r'R$ 10,50');
    expect(formatBrl(0.01), r'R$ 0,01');
  });
}
