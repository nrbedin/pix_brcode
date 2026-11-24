import 'dart:async';

import 'package:pix_brcode/pix_brcode.dart';

import 'pix_gateway.dart';

/// Backend simulado, para demonstrar o fluxo sem PSP nem servidor.
///
/// Gera um BR Code **dinâmico** com dados fictícios, como um PSP faria, e só
/// marca a cobrança como paga quando [simulatePayment] é chamado.
final class FakePixGateway implements PixGateway {
  /// Cria o gateway simulado.
  ///
  /// [latency] imita o tempo de resposta da rede; [expiresIn] é a validade
  /// de cada cobrança.
  FakePixGateway({
    this.latency = const Duration(milliseconds: 800),
    this.expiresIn = const Duration(minutes: 2),
  });

  /// Atraso de cada chamada.
  final Duration latency;

  /// Validade das cobranças criadas.
  final Duration expiresIn;

  /// Quando `true`, a próxima [createCharge] falha, para demonstrar o erro.
  bool failNextCharge = false;

  final Map<String, StreamController<ChargeStatus>> _charges = {};
  var _sequence = 0;

  @override
  Future<PixCharge> createCharge({required double amount}) async {
    await Future<void>.delayed(latency);
    if (failNextCharge) {
      failNextCharge = false;
      throw const FakeGatewayException('PSP indisponível (simulado)');
    }

    _sequence++;
    final txid = 'DEMO${_sequence.toString().padLeft(28, '0')}';
    final brCode = DynamicPixPayload(
      url: 'pix.exemplo.com.br/qr/v2/cobv/$txid',
      merchantName: 'Loja Exemplo',
      merchantCity: 'SAO PAULO',
      amount: amount,
    ).encode();

    _charges[txid] = StreamController<ChargeStatus>.broadcast();
    return PixCharge(txid: txid, brCode: brCode, expiresIn: expiresIn);
  }

  @override
  Stream<ChargeStatus> watchStatus(String txid) {
    final controller = _charges[txid];
    if (controller == null) {
      return Stream.error(FakeGatewayException('cobrança $txid não existe'));
    }
    return controller.stream;
  }

  @override
  Future<void> cancel(String txid) async {
    await _charges.remove(txid)?.close();
  }

  /// Simula o webhook do PSP avisando que [txid] foi pago.
  void simulatePayment(String txid) {
    final controller = _charges.remove(txid);
    controller?.add(ChargeStatus.paid);
    controller?.close();
  }
}

/// Erro do backend simulado.
final class FakeGatewayException implements Exception {
  /// Cria o erro com uma [message].
  const FakeGatewayException(this.message);

  /// Motivo do erro.
  final String message;

  @override
  String toString() => message;
}
