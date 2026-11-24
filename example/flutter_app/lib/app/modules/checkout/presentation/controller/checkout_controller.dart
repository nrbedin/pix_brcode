import 'dart:async';

import 'package:pix_brcode/pix_brcode.dart';

import '../../../../core/formatters/currency_formatter.dart';
import '../../data/datasources/pix_datasource.dart';
import '../../domain/entities/charge_event.dart';
import '../../domain/entities/pix_charge.dart';
import '../../domain/enums/charge_status.dart';
import '../../domain/exceptions/checkout_exception.dart';
import '../../domain/repositories/checkout_repository.dart';
import '../mobx/checkout_state.dart';
import '../mobx/checkout_store.dart';

/// Regras da tela de pagamento Pix.
///
/// Fluxo: [EnteringAmount] → [CreatingCharge] → [AwaitingPayment] →
/// [ProcessingPayment] → [PaymentConfirmed], ou [ChargeExpired] e
/// [CheckoutFailed] no caminho.
class CheckoutController {
  /// Cria o controller.
  ///
  /// [simulator] só existe na demonstração, para o botão de simular o
  /// pagamento.
  CheckoutController(this._repository, this.store, {this.simulator});

  final CheckoutRepository _repository;

  /// Estado observável da tela.
  final CheckoutStore store;

  /// Simulador de pagamento, quando o backend é fake.
  final PaymentSimulator? simulator;

  Timer? _countdown;
  StreamSubscription<ChargeEvent>? _subscription;

  /// Conta as cobranças pedidas, para descartar respostas atrasadas de uma
  /// cobrança que o usuário já cancelou.
  var _attempt = 0;

  /// Valida [amountText] (aceita vírgula) e pede a cobrança.
  Future<void> submitAmount(String amountText) async {
    final amount = double.tryParse(amountText.trim().replaceAll(',', '.'));
    if (amount == null || amount <= 0) {
      store.setState(
        const EnteringAmount(error: 'Informe um valor maior que zero.'),
      );
      return;
    }
    if (amount > PixPayload.maxAmount) {
      store.setState(
        const EnteringAmount(error: 'Valor acima do limite do Pix.'),
      );
      return;
    }
    await createCharge(amount);
  }

  /// Pede ao backend uma cobrança de [amount] reais e mostra o QR.
  Future<void> createCharge(double amount) async {
    _stopWatching();
    final attempt = ++_attempt;
    store.setState(CreatingCharge(amount));

    final PixCharge charge;
    try {
      charge = await _repository.createCharge(amount: amount);
    } on CheckoutException catch (e) {
      if (attempt != _attempt) return;
      store.setState(CheckoutFailed(e.message, amount));
      return;
    }
    if (attempt != _attempt) {
      unawaited(_repository.cancelCharge(charge.txid));
      return;
    }

    // O front não confia cegamente no backend: valida o BR Code antes de
    // mostrar e confere se o valor no QR é o que o usuário pediu.
    final PixPayload payload;
    try {
      payload = PixPayload.parse(charge.brCode);
    } on PixParseException catch (e) {
      store.setState(
        CheckoutFailed('O servidor devolveu um QR inválido: $e', amount),
      );
      return;
    }
    final qrAmount = payload.amount;
    if (qrAmount != null && (qrAmount - amount).abs() >= 0.005) {
      store.setState(CheckoutFailed(
        'O valor do QR (${formatBrl(qrAmount)}) é diferente do pedido '
        '(${formatBrl(amount)}).',
        amount,
      ));
      return;
    }

    store.setState(AwaitingPayment(
      charge: charge,
      payload: payload,
      remaining: charge.expiresIn,
    ));

    _subscription = _repository.watchCharge(charge.txid).listen(
          (event) => _onEvent(event, charge, payload),
          onError: (Object error) => _onWatchError(error, charge),
        );
    _countdown = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _onEvent(ChargeEvent event, PixCharge charge, PixPayload payload) {
    switch (event.status) {
      case ChargeStatus.active:
        final step = event.step;
        if (step == null) return;
        // O pagamento começou: o QR já foi lido e a contagem para.
        _countdown?.cancel();
        store.setState(ProcessingPayment(
          charge: charge,
          payload: payload,
          currentStep: step,
        ));
      case ChargeStatus.completed:
        _stopWatching();
        store.setState(PaymentConfirmed(
          charge: charge,
          payload: payload,
          receipt: event.receipt!,
        ));
      case ChargeStatus.removedByPsp || ChargeStatus.removedByReceiver:
        _stopWatching();
        store.setState(ChargeExpired(charge.amount));
    }
  }

  void _onWatchError(Object error, PixCharge charge) {
    // Com o QR na tela, um erro de acompanhamento não deve sumir com ele:
    // o pagador pode estar pagando. Só vira erro se o pagamento já estava
    // sendo processado.
    if (store.state is ProcessingPayment) {
      _stopWatching();
      store.setState(CheckoutFailed(
        'Perdemos o contato com o servidor durante o pagamento. '
        'Confira no extrato antes de cobrar de novo.',
        charge.amount,
      ));
    }
  }

  void _tick() {
    final current = store.state;
    if (current is! AwaitingPayment) return;
    final remaining = current.remaining - const Duration(seconds: 1);
    if (remaining <= Duration.zero) {
      _stopWatching();
      unawaited(_repository.cancelCharge(current.charge.txid));
      store.setState(ChargeExpired(current.charge.amount));
      return;
    }
    store.setState(current.copyWith(remaining: remaining));
  }

  /// Simula o pagador pagando a cobrança na tela.
  void simulatePayment() {
    final current = store.state;
    if (current is AwaitingPayment) {
      simulator?.simulatePayment(current.charge.txid);
    }
  }

  /// Cancela a cobrança em andamento, se houver, e volta para o valor.
  ///
  /// Não faz nada enquanto o pagamento está sendo processado: nesse ponto
  /// o dinheiro já saiu da conta do pagador.
  void cancel() {
    if (store.state is ProcessingPayment) return;
    final current = store.state;
    _attempt++;
    _stopWatching();
    if (current is AwaitingPayment) {
      unawaited(_repository.cancelCharge(current.charge.txid));
    }
    store.setState(const EnteringAmount());
  }

  void _stopWatching() {
    _countdown?.cancel();
    _countdown = null;
    unawaited(_subscription?.cancel());
    _subscription = null;
  }

  /// Libera timers e assinaturas.
  void dispose() {
    _attempt++;
    _stopWatching();
  }
}
