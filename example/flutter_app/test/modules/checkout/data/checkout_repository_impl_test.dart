import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:pix_checkout_demo/app/modules/checkout/data/datasources/pix_datasource.dart';
import 'package:pix_checkout_demo/app/modules/checkout/data/repositories/checkout_repository_impl.dart';
import 'package:pix_checkout_demo/app/modules/checkout/domain/enums/charge_status.dart';
import 'package:pix_checkout_demo/app/modules/checkout/domain/enums/payment_step.dart';
import 'package:pix_checkout_demo/app/modules/checkout/domain/exceptions/checkout_exception.dart';

/// Datasource que devolve o que o teste mandar.
final class _StubDatasource implements PixDatasource {
  Future<Map<String, dynamic>> Function() onCreate = () async => {};
  final events = StreamController<Map<String, dynamic>>();
  Object? cancelError;
  final cancelled = <String>[];

  @override
  Future<Map<String, dynamic>> createCharge({required double amount}) =>
      onCreate();

  @override
  Stream<Map<String, dynamic>> watchCharge(String txid) => events.stream;

  @override
  Future<void> cancelCharge(String txid) async {
    cancelled.add(txid);
    if (cancelError != null) throw cancelError!;
  }
}

const chargeJson = {
  'txid': 'T1',
  'calendario': {'criacao': '2026-11-24T14:05:09Z', 'expiracao': 120},
  'status': 'ATIVA',
  'valor': {'original': '10.50'},
  'pixCopiaECola': '000201...',
};

void main() {
  late _StubDatasource datasource;
  late CheckoutRepositoryImpl repository;

  setUp(() {
    datasource = _StubDatasource();
    repository = CheckoutRepositoryImpl(datasource);
  });

  group('createCharge', () {
    test('converte o JSON em PixCharge', () async {
      datasource.onCreate = () async => chargeJson;
      final charge = await repository.createCharge(amount: 10.5);
      expect(charge.txid, 'T1');
      expect(charge.brCode, '000201...');
      expect(charge.amount, 10.5);
      expect(charge.expiresIn, const Duration(minutes: 2));
    });

    test('erro do datasource vira CheckoutException', () {
      datasource.onCreate = () async => throw const DatasourceException('503');
      expect(
        repository.createCharge(amount: 1),
        throwsA(isA<CheckoutException>()
            .having((e) => e.message, 'message', contains('503'))),
      );
    });

    test('JSON incompleto vira CheckoutException', () {
      datasource.onCreate = () async => {'txid': 'T1'};
      expect(
        repository.createCharge(amount: 1),
        throwsA(isA<CheckoutException>().having(
          (e) => e.message,
          'message',
          contains('Resposta inesperada'),
        )),
      );
    });
  });

  group('watchCharge', () {
    test('converte status, etapa e comprovante', () async {
      final events = repository.watchCharge('T1');
      datasource.events
        ..add({'status': 'ATIVA'})
        ..add({'status': 'ATIVA', 'etapa': 'LIQUIDANDO_NO_SPI'})
        ..add({
          'status': 'CONCLUIDA',
          'pix': [
            {
              'endToEndId': 'E0000000020261124140500000000001',
              'valor': '10.50',
              'horario': '2026-11-24T14:05:09Z',
              'pagador': {'nome': 'Pagador Ficticio'},
            },
          ],
        })
        ..close();

      final list = await events.toList();
      expect(list.map((e) => e.status), [
        ChargeStatus.active,
        ChargeStatus.active,
        ChargeStatus.completed,
      ]);
      expect(list[0].step, isNull);
      expect(list[1].step, PaymentStep.settlingInSpi);
      final receipt = list[2].receipt!;
      expect(receipt.amount, 10.5);
      expect(receipt.payerName, 'Pagador Ficticio');
      expect(receipt.paidAt, DateTime.utc(2026, 11, 24, 14, 5, 9).toLocal());
    });

    test('status de remoção', () async {
      final events = repository.watchCharge('T1');
      datasource.events
        ..add({'status': 'REMOVIDA_PELO_PSP'})
        ..add({'status': 'REMOVIDA_PELO_USUARIO_RECEBEDOR'})
        ..close();
      expect((await events.toList()).map((e) => e.status), [
        ChargeStatus.removedByPsp,
        ChargeStatus.removedByReceiver,
      ]);
    });

    for (final (name, json) in [
      ('status desconhecido', {'status': 'OUTRO'}),
      ('CONCLUIDA sem pix', {'status': 'CONCLUIDA'}),
      (
        'pix incompleto',
        {
          'status': 'CONCLUIDA',
          'pix': [
            {'valor': '1.00'},
          ],
        }
      ),
      ('status com tipo errado', {'status': 1}),
    ]) {
      test('$name vira CheckoutException', () {
        final events = repository.watchCharge('T1');
        datasource.events.add(json);
        expect(events, emitsError(isA<CheckoutException>()));
      });
    }

    test('erro do datasource vira CheckoutException', () {
      final events = repository.watchCharge('T1');
      datasource.events.addError(const DatasourceException('conexão caiu'));
      expect(
        events,
        emitsError(isA<CheckoutException>()
            .having((e) => e.message, 'message', contains('conexão caiu'))),
      );
    });
  });

  group('cancelCharge', () {
    test('repassa ao datasource', () async {
      await repository.cancelCharge('T1');
      expect(datasource.cancelled, ['T1']);
    });

    test('ignora erro do datasource', () async {
      datasource.cancelError = const DatasourceException('timeout');
      await repository.cancelCharge('T1');
      expect(datasource.cancelled, ['T1']);
    });
  });
}
