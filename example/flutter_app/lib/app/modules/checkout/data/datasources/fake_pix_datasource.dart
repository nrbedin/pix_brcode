import 'dart:async';

import 'package:pix_brcode/pix_brcode.dart';

import 'pix_datasource.dart';

/// Backend simulado, sem servidor nem PSP.
///
/// Cria cobranças com BR Code **dinâmico** e dados fictícios. Quando
/// [simulatePayment] é chamado, emite as etapas do pagamento com
/// [stepDelay] entre elas e termina com `CONCLUIDA` e o comprovante.
final class FakePixDatasource implements PixDatasource, PaymentSimulator {
  /// Cria o backend simulado.
  FakePixDatasource({
    this.latency = const Duration(milliseconds: 800),
    this.expiresIn = const Duration(minutes: 2),
    this.stepDelay = const Duration(milliseconds: 1200),
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  /// Tempo de resposta de cada chamada.
  final Duration latency;

  /// Validade das cobranças.
  final Duration expiresIn;

  /// Intervalo entre as etapas do pagamento simulado.
  final Duration stepDelay;

  final DateTime Function() _clock;

  /// Quando `true`, a próxima [createCharge] falha.
  bool failNextCharge = false;

  final Map<String, _FakeCharge> _charges = {};
  var _sequence = 0;

  /// Etapas emitidas depois de [simulatePayment], na ordem.
  static const steps = [
    'PAGADOR_AUTORIZOU',
    'LIQUIDANDO_NO_SPI',
    'CREDITO_CONFIRMADO',
    'WEBHOOK_RECEBIDO',
  ];

  @override
  Future<Map<String, dynamic>> createCharge({required double amount}) async {
    await Future<void>.delayed(latency);
    if (failNextCharge) {
      failNextCharge = false;
      throw const DatasourceException('503 Service Unavailable (simulado)');
    }

    _sequence++;
    final txid = 'DEMO${_sequence.toString().padLeft(28, '0')}';
    final location = 'pix.exemplo.com.br/qr/v2/cobv/$txid';
    final brCode = DynamicPixPayload(
      url: location,
      merchantName: 'Loja Exemplo',
      merchantCity: 'SAO PAULO',
      amount: amount,
    ).encode();

    _charges[txid] = _FakeCharge(amount);
    return {
      'txid': txid,
      'calendario': {
        'criacao': _clock().toUtc().toIso8601String(),
        'expiracao': expiresIn.inSeconds,
      },
      'status': 'ATIVA',
      'valor': {'original': amount.toStringAsFixed(2)},
      'location': location,
      'pixCopiaECola': brCode,
    };
  }

  @override
  Stream<Map<String, dynamic>> watchCharge(String txid) {
    final charge = _charges[txid];
    if (charge == null) {
      return Stream.error(DatasourceException('404 cobrança $txid'));
    }
    return charge.events.stream;
  }

  @override
  Future<void> cancelCharge(String txid) async {
    final charge = _charges.remove(txid);
    charge?.cancelTimers();
    await charge?.events.close();
  }

  @override
  void simulatePayment(String txid) {
    final charge = _charges[txid];
    if (charge == null || charge.paying) return;
    charge.paying = true;

    for (var i = 0; i < steps.length; i++) {
      charge.timers.add(Timer(stepDelay * i, () {
        charge.events.add({'txid': txid, 'status': 'ATIVA', 'etapa': steps[i]});
      }));
    }
    charge.timers.add(Timer(stepDelay * steps.length, () {
      _charges.remove(txid);
      charge.events
        ..add({
          'txid': txid,
          'status': 'CONCLUIDA',
          'pix': [
            {
              'endToEndId': _endToEndId(),
              'valor': charge.amount.toStringAsFixed(2),
              'horario': _clock().toUtc().toIso8601String(),
              'pagador': {'nome': 'Pagador Ficticio'},
            },
          ],
        })
        ..close();
    }));
  }

  /// `E` + ISPB fictício (8 dígitos) + data e hora + sufixo: 32 caracteres.
  String _endToEndId() {
    final now = _clock().toUtc();
    String two(int n) => n.toString().padLeft(2, '0');
    final stamp = '${now.year}${two(now.month)}${two(now.day)}'
        '${two(now.hour)}${two(now.minute)}';
    return 'E00000000${stamp}DEMO${_sequence.toString().padLeft(7, '0')}';
  }
}

final class _FakeCharge {
  _FakeCharge(this.amount);

  final double amount;
  final events = StreamController<Map<String, dynamic>>.broadcast();
  final timers = <Timer>[];
  var paying = false;

  void cancelTimers() {
    for (final timer in timers) {
      timer.cancel();
    }
  }
}
