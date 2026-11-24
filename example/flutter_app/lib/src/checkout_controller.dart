import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:pix_brcode/pix_brcode.dart';

import 'pix_gateway.dart';

/// Estados da tela de pagamento.
sealed class CheckoutState {
  const CheckoutState();
}

/// Esperando o valor. [error] explica um valor inválido digitado.
final class EnteringAmount extends CheckoutState {
  /// Cria o estado.
  const EnteringAmount({this.error});

  /// Mensagem de erro do valor, se houver.
  final String? error;
}

/// Pedindo a cobrança ao backend.
final class CreatingCharge extends CheckoutState {
  /// Cria o estado.
  const CreatingCharge(this.amount);

  /// Valor pedido.
  final double amount;
}

/// QR Code na tela, esperando o pagamento.
final class AwaitingPayment extends CheckoutState {
  /// Cria o estado.
  const AwaitingPayment({
    required this.amount,
    required this.charge,
    required this.payload,
    required this.remaining,
  });

  /// Valor pedido.
  final double amount;

  /// Cobrança devolvida pelo backend.
  final PixCharge charge;

  /// [PixCharge.brCode] já interpretado e validado pelo pix_brcode.
  final PixPayload payload;

  /// Tempo até expirar.
  final Duration remaining;
}

/// Pagamento confirmado pelo backend.
final class PaymentConfirmed extends CheckoutState {
  /// Cria o estado.
  const PaymentConfirmed(this.payload);

  /// Payload da cobrança paga.
  final PixPayload payload;
}

/// A cobrança expirou sem pagamento.
final class ChargeExpired extends CheckoutState {
  /// Cria o estado.
  const ChargeExpired(this.amount);

  /// Valor da cobrança expirada, para gerar outra igual.
  final double amount;
}

/// Falha ao criar ou validar a cobrança.
final class CheckoutFailed extends CheckoutState {
  /// Cria o estado.
  const CheckoutFailed(this.message, this.amount);

  /// Mensagem para o usuário.
  final String message;

  /// Valor pedido, para tentar de novo.
  final double amount;
}

/// Máquina de estados do pagamento Pix.
///
/// Fluxo: [EnteringAmount] → [CreatingCharge] → [AwaitingPayment] →
/// [PaymentConfirmed], [ChargeExpired] ou [CheckoutFailed].
class CheckoutController extends ChangeNotifier {
  /// Cria o controller usando [gateway] para falar com o backend.
  CheckoutController(this._gateway);

  final PixGateway _gateway;

  CheckoutState _state = const EnteringAmount();
  Timer? _countdown;
  StreamSubscription<ChargeStatus>? _statusSubscription;

  /// Conta as cobranças pedidas, para descartar respostas atrasadas de uma
  /// cobrança que o usuário já cancelou.
  var _attempt = 0;

  /// Estado atual.
  CheckoutState get state => _state;

  void _emit(CheckoutState state) {
    _state = state;
    notifyListeners();
  }

  /// Valida [amountText] (aceita vírgula) e pede a cobrança.
  Future<void> submitAmount(String amountText) async {
    final amount = double.tryParse(amountText.trim().replaceAll(',', '.'));
    if (amount == null || amount <= 0) {
      _emit(const EnteringAmount(error: 'Informe um valor maior que zero.'));
      return;
    }
    if (amount > PixPayload.maxAmount) {
      _emit(const EnteringAmount(error: 'Valor acima do limite do Pix.'));
      return;
    }
    await createCharge(amount);
  }

  /// Pede ao backend uma cobrança de [amount] reais e mostra o QR.
  Future<void> createCharge(double amount) async {
    _stopWatching();
    final attempt = ++_attempt;
    _emit(CreatingCharge(amount));

    final PixCharge charge;
    try {
      charge = await _gateway.createCharge(amount: amount);
    } on Exception catch (e) {
      if (attempt != _attempt) return;
      _emit(CheckoutFailed('Não foi possível criar a cobrança: $e', amount));
      return;
    }
    if (attempt != _attempt) {
      unawaited(_gateway.cancel(charge.txid));
      return;
    }

    // O front não confia cegamente no backend: valida o BR Code antes de
    // mostrar, e confere se o valor no QR é o que o usuário pediu.
    final PixPayload payload;
    try {
      payload = PixPayload.parse(charge.brCode);
    } on PixParseException catch (e) {
      _emit(CheckoutFailed('O backend devolveu um QR inválido: $e', amount));
      return;
    }
    final qrAmount = payload.amount;
    if (qrAmount != null && (qrAmount - amount).abs() >= 0.005) {
      _emit(CheckoutFailed(
        'O valor do QR (${formatBrl(qrAmount)}) é diferente do pedido '
        '(${formatBrl(amount)}).',
        amount,
      ));
      return;
    }

    _emit(AwaitingPayment(
      amount: amount,
      charge: charge,
      payload: payload,
      remaining: charge.expiresIn,
    ));

    _statusSubscription = _gateway.watchStatus(charge.txid).listen(
          (status) => _onStatus(status, payload, amount),
          onError: (Object _) {}, // Mantém o QR; o countdown ainda expira.
        );
    _countdown = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _onStatus(ChargeStatus status, PixPayload payload, double amount) {
    switch (status) {
      case ChargeStatus.pending:
        break;
      case ChargeStatus.paid:
        _stopWatching();
        _emit(PaymentConfirmed(payload));
      case ChargeStatus.expired:
        _stopWatching();
        _emit(ChargeExpired(amount));
    }
  }

  void _tick() {
    final current = _state;
    if (current is! AwaitingPayment) return;
    final remaining = current.remaining - const Duration(seconds: 1);
    if (remaining <= Duration.zero) {
      _stopWatching();
      unawaited(_gateway.cancel(current.charge.txid));
      _emit(ChargeExpired(current.amount));
      return;
    }
    _emit(AwaitingPayment(
      amount: current.amount,
      charge: current.charge,
      payload: current.payload,
      remaining: remaining,
    ));
  }

  /// Cancela a cobrança em andamento e volta para o valor.
  void cancel() {
    final current = _state;
    _attempt++;
    _stopWatching();
    if (current is AwaitingPayment) {
      unawaited(_gateway.cancel(current.charge.txid));
    }
    _emit(const EnteringAmount());
  }

  void _stopWatching() {
    _countdown?.cancel();
    _countdown = null;
    unawaited(_statusSubscription?.cancel());
    _statusSubscription = null;
  }

  @override
  void dispose() {
    _attempt++;
    _stopWatching();
    super.dispose();
  }
}

/// Formata [amount] como `R$ 10,50`.
String formatBrl(double amount) =>
    'R\$ ${amount.toStringAsFixed(2).replaceAll('.', ',')}';
