import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pix_brcode/pix_brcode.dart';
import 'package:pix_checkout_demo/app/modules/checkout/data/datasources/fake_pix_datasource.dart';
import 'package:pix_checkout_demo/app/modules/checkout/data/datasources/pix_datasource.dart';

void main() {
  const latency = Duration(milliseconds: 100);
  const stepDelay = Duration(seconds: 1);
  final now = DateTime.utc(2026, 11, 24, 14, 5, 9);

  FakePixDatasource create() => FakePixDatasource(
        latency: latency,
        expiresIn: const Duration(seconds: 90),
        stepDelay: stepDelay,
        clock: () => now,
      );

  test('createCharge devolve JSON no formato da API Pix', () {
    fakeAsync((async) {
      Map<String, dynamic>? json;
      create().createCharge(amount: 10.5).then((value) => json = value);
      async.elapse(latency);

      expect(json!['txid'], 'DEMO${'1'.padLeft(28, '0')}');
      expect(json!['status'], 'ATIVA');
      expect(json!['calendario'], {
        'criacao': '2026-11-24T14:05:09.000Z',
        'expiracao': 90,
      });
      expect(json!['valor'], {'original': '10.50'});

      final payload = PixPayload.parse(json!['pixCopiaECola'] as String);
      expect(payload, isA<DynamicPixPayload>());
      expect((payload as DynamicPixPayload).url, json!['location']);
      expect(payload.amount, 10.5);
    });
  });

  test('failNextCharge falha uma vez', () {
    fakeAsync((async) {
      final datasource = create()..failNextCharge = true;
      Object? error;
      datasource.createCharge(amount: 1).catchError((Object e) {
        error = e;
        return <String, dynamic>{};
      });
      async.elapse(latency);
      expect(error, isA<DatasourceException>());

      Map<String, dynamic>? json;
      datasource.createCharge(amount: 1).then((value) => json = value);
      async.elapse(latency);
      expect(json, isNotNull);
    });
  });

  test('simulatePayment emite as etapas com intervalo e depois CONCLUIDA', () {
    fakeAsync((async) {
      final datasource = create();
      late String txid;
      datasource.createCharge(amount: 10.5).then((v) => txid = v['txid']);
      async.elapse(latency);

      final events = <Map<String, dynamic>>[];
      var closed = false;
      datasource
          .watchCharge(txid)
          .listen(events.add, onDone: () => closed = true);

      datasource.simulatePayment(txid);
      async.elapse(Duration.zero);
      expect(events.map((e) => e['etapa']), ['PAGADOR_AUTORIZOU']);

      async.elapse(stepDelay);
      expect(events.last['etapa'], 'LIQUIDANDO_NO_SPI');

      async.elapse(stepDelay * 2);
      expect(
        events.map((e) => e['etapa']).whereType<String>(),
        FakePixDatasource.steps,
      );
      expect(events.last['status'], 'ATIVA');

      async.elapse(stepDelay);
      expect(events.last['status'], 'CONCLUIDA');
      final pix = (events.last['pix'] as List).single as Map;
      expect(pix['valor'], '10.50');
      expect(pix['horario'], '2026-11-24T14:05:09.000Z');
      expect(pix['endToEndId'], hasLength(32));
      expect(pix['endToEndId'], startsWith('E00000000202611241405'));
      expect(closed, isTrue);
    });
  });

  test('simulatePayment repetido não duplica as etapas', () {
    fakeAsync((async) {
      final datasource = create();
      late String txid;
      datasource.createCharge(amount: 1).then((v) => txid = v['txid']);
      async.elapse(latency);

      final events = <Map<String, dynamic>>[];
      datasource.watchCharge(txid).listen(events.add);
      datasource
        ..simulatePayment(txid)
        ..simulatePayment(txid);
      async.elapse(stepDelay * 5);
      expect(events, hasLength(FakePixDatasource.steps.length + 1));
    });
  });

  test('cancelCharge interrompe o pagamento e fecha o stream', () {
    fakeAsync((async) {
      final datasource = create();
      late String txid;
      datasource.createCharge(amount: 1).then((v) => txid = v['txid']);
      async.elapse(latency);

      final events = <Map<String, dynamic>>[];
      var closed = false;
      datasource
          .watchCharge(txid)
          .listen(events.add, onDone: () => closed = true);
      datasource.simulatePayment(txid);
      async.elapse(Duration.zero);
      datasource.cancelCharge(txid);
      async.elapse(stepDelay * 5);

      expect(events, hasLength(1));
      expect(closed, isTrue);
    });
  });

  test('watchCharge de cobrança inexistente emite erro', () {
    expect(
      create().watchCharge('NAOEXISTE'),
      emitsError(isA<DatasourceException>()),
    );
  });
}
