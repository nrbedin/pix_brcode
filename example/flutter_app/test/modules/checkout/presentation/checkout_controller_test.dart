import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pix_brcode/pix_brcode.dart';
import 'package:pix_checkout_demo/app/modules/checkout/data/datasources/fake_pix_datasource.dart';
import 'package:pix_checkout_demo/app/modules/checkout/data/repositories/checkout_repository_impl.dart';
import 'package:pix_checkout_demo/app/modules/checkout/domain/entities/charge_event.dart';
import 'package:pix_checkout_demo/app/modules/checkout/domain/entities/payment_receipt.dart';
import 'package:pix_checkout_demo/app/modules/checkout/domain/entities/pix_charge.dart';
import 'package:pix_checkout_demo/app/modules/checkout/domain/enums/charge_status.dart';
import 'package:pix_checkout_demo/app/modules/checkout/domain/enums/payment_step.dart';
import 'package:pix_checkout_demo/app/modules/checkout/domain/exceptions/checkout_exception.dart';
import 'package:pix_checkout_demo/app/modules/checkout/domain/repositories/checkout_repository.dart';
import 'package:pix_checkout_demo/app/modules/checkout/presentation/controller/checkout_controller.dart';
import 'package:pix_checkout_demo/app/modules/checkout/presentation/mobx/checkout_state.dart';
import 'package:pix_checkout_demo/app/modules/checkout/presentation/mobx/checkout_store.dart';

/// Repositório em que o teste controla cada resposta.
final class _ManualRepository implements CheckoutRepository {
  final pending = Completer<PixCharge>();
  final events = StreamController<ChargeEvent>.broadcast();
  final cancelled = <String>[];

  @override
  Future<PixCharge> createCharge({required double amount}) => pending.future;

  @override
  Stream<ChargeEvent> watchCharge(String txid) => events.stream;

  @override
  Future<void> cancelCharge(String txid) async => cancelled.add(txid);
}

String brCode({double? amount}) => DynamicPixPayload(
      url: 'pix.exemplo.com.br/qr/v2/cobv/TESTE',
      merchantName: 'Loja Exemplo',
      merchantCity: 'SAO PAULO',
      amount: amount,
    ).encode();

PixCharge charge({String txid = 'T1', String? code, double amount = 5}) =>
    PixCharge(
      txid: txid,
      brCode: code ?? brCode(amount: amount),
      amount: amount,
      expiresIn: const Duration(minutes: 1),
    );

final receipt = PaymentReceipt(
  endToEndId: 'E0000000020261124140500000000001',
  amount: 5,
  paidAt: DateTime(2026, 11, 24, 14, 5),
  payerName: 'Pagador Ficticio',
);

void main() {
  group('com o backend simulado', () {
    const latency = Duration(milliseconds: 100);
    const stepDelay = Duration(seconds: 1);

    late FakePixDatasource datasource;
    late CheckoutStore store;
    late CheckoutController controller;

    setUp(() {
      datasource = FakePixDatasource(
        latency: latency,
        expiresIn: const Duration(seconds: 3),
        stepDelay: stepDelay,
      );
      store = CheckoutStore();
      controller = CheckoutController(
        CheckoutRepositoryImpl(datasource),
        store,
        simulator: datasource,
      );
    });

    tearDown(() => controller.dispose());

    for (final text in ['', 'abc', '0', '-5', '0,00']) {
      test('valor "$text" é rejeitado', () async {
        await controller.submitAmount(text);
        expect((store.state as EnteringAmount).error, isNotNull);
      });
    }

    test('valor acima do limite é rejeitado', () async {
      await controller.submitAmount('99999999999');
      expect((store.state as EnteringAmount).error, contains('limite'));
    });

    test('fluxo completo: QR, etapas do pagamento e comprovante', () {
      fakeAsync((async) {
        controller.submitAmount('10,50');
        expect(store.state, isA<CreatingCharge>());
        expect(store.canCancel, isTrue);
        async.elapse(latency);

        final awaiting = store.state as AwaitingPayment;
        expect(awaiting.charge.amount, 10.5);
        expect(awaiting.payload, isA<DynamicPixPayload>());
        expect(awaiting.remaining, const Duration(seconds: 3));
        expect(store.canCancel, isTrue);

        controller.simulatePayment();
        async.elapse(Duration.zero);
        expect(
          (store.state as ProcessingPayment).currentStep,
          PaymentStep.payerAuthorized,
        );
        expect(store.canCancel, isFalse);

        // A contagem para durante o processamento: passar do prazo de 3 s
        // não expira a cobrança.
        for (final step in PaymentStep.values.skip(1)) {
          async.elapse(stepDelay);
          expect((store.state as ProcessingPayment).currentStep, step);
        }

        controller.cancel(); // ignorado durante o processamento
        expect(store.state, isA<ProcessingPayment>());

        async.elapse(stepDelay);
        final paid = store.state as PaymentConfirmed;
        expect(paid.receipt.amount, 10.5);
        expect(paid.receipt.endToEndId, hasLength(32));
        expect(paid.charge.txid, awaiting.charge.txid);

        controller.cancel();
        expect(store.state, isA<EnteringAmount>());
      });
    });

    test('countdown diminui e expira', () {
      fakeAsync((async) {
        controller.createCharge(5);
        async.elapse(latency);

        async.elapse(const Duration(seconds: 1));
        expect(
          (store.state as AwaitingPayment).remaining,
          const Duration(seconds: 2),
        );

        async.elapse(const Duration(seconds: 2));
        expect((store.state as ChargeExpired).amount, 5);
      });
    });

    test('falha do backend vira CheckoutFailed', () {
      fakeAsync((async) {
        datasource.failNextCharge = true;
        controller.createCharge(5);
        async.elapse(latency);

        final failed = store.state as CheckoutFailed;
        expect(failed.message, contains('503'));
        expect(failed.amount, 5);
      });
    });

    test('simulatePayment fora do QR não faz nada', () {
      controller.simulatePayment();
      expect(store.state, isA<EnteringAmount>());
    });
  });

  group('com repositório manual', () {
    late _ManualRepository repository;
    late CheckoutStore store;
    late CheckoutController controller;

    setUp(() {
      repository = _ManualRepository();
      store = CheckoutStore();
      controller = CheckoutController(repository, store);
    });

    tearDown(() => controller.dispose());

    Future<void> showQr([PixCharge? value]) async {
      final future = controller.createCharge(value?.amount ?? 5);
      repository.pending.complete(value ?? charge());
      await future;
    }

    test('BR Code inválido não chega à tela', () async {
      await showQr(charge(code: '${brCode().substring(0, 20)}63040000'));
      expect(
        (store.state as CheckoutFailed).message,
        contains('QR inválido'),
      );
    });

    test('valor do QR diferente do pedido é recusado', () async {
      final future = controller.createCharge(5);
      repository.pending.complete(charge(code: brCode(amount: 50)));
      await future;
      expect(
        (store.state as CheckoutFailed).message,
        contains('diferente do pedido'),
      );
    });

    test('QR sem valor é aceito', () async {
      await showQr(charge(code: brCode()));
      expect(store.state, isA<AwaitingPayment>());
    });

    test('erro do repositório vira CheckoutFailed', () async {
      final future = controller.createCharge(5);
      repository.pending.completeError(const CheckoutException('sem rede'));
      await future;
      expect((store.state as CheckoutFailed).message, 'sem rede');
    });

    test('evento ATIVA sem etapa mantém o QR', () async {
      await showQr();
      repository.events.add(const ChargeEvent(status: ChargeStatus.active));
      await Future<void>.delayed(Duration.zero);
      expect(store.state, isA<AwaitingPayment>());
    });

    for (final status in [
      ChargeStatus.removedByPsp,
      ChargeStatus.removedByReceiver,
    ]) {
      test('${status.name} encerra como expirada', () async {
        await showQr();
        repository.events.add(ChargeEvent(status: status));
        await Future<void>.delayed(Duration.zero);
        expect(store.state, isA<ChargeExpired>());
      });
    }

    test('CONCLUIDA mostra o comprovante', () async {
      await showQr();
      repository.events.add(
        ChargeEvent(status: ChargeStatus.completed, receipt: receipt),
      );
      await Future<void>.delayed(Duration.zero);
      expect((store.state as PaymentConfirmed).receipt, receipt);
    });

    test('erro de acompanhamento com o QR na tela mantém o QR', () async {
      await showQr();
      repository.events.addError(const CheckoutException('caiu'));
      await Future<void>.delayed(Duration.zero);
      expect(store.state, isA<AwaitingPayment>());
    });

    test('erro de acompanhamento durante o processamento vira falha', () async {
      await showQr();
      repository.events
        ..add(const ChargeEvent(
          status: ChargeStatus.active,
          step: PaymentStep.settlingInSpi,
        ))
        ..addError(const CheckoutException('caiu'));
      await Future<void>.delayed(Duration.zero);
      expect(
        (store.state as CheckoutFailed).message,
        contains('Confira no extrato'),
      );
    });

    test('cancelar durante a criação descarta a resposta atrasada', () async {
      final future = controller.createCharge(5);
      controller.cancel();
      repository.pending.complete(charge(txid: 'T2'));
      await future;
      expect(store.state, isA<EnteringAmount>());
      expect(repository.cancelled, ['T2']);
    });

    test('erro atrasado de uma cobrança cancelada é ignorado', () async {
      final future = controller.createCharge(5);
      controller.cancel();
      repository.pending.completeError(const CheckoutException('tarde'));
      await future;
      expect(store.state, isA<EnteringAmount>());
    });

    test('cancelar com o QR na tela avisa o backend', () async {
      await showQr(charge(txid: 'T3'));
      controller.cancel();
      expect(store.state, isA<EnteringAmount>());
      expect(repository.cancelled, ['T3']);
    });

    test('sem simulador, simulatePayment não faz nada', () async {
      await showQr();
      controller.simulatePayment();
      expect(store.state, isA<AwaitingPayment>());
    });
  });
}
