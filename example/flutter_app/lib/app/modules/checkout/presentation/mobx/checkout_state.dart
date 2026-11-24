import 'package:pix_brcode/pix_brcode.dart';

import '../../domain/entities/payment_receipt.dart';
import '../../domain/entities/pix_charge.dart';
import '../../domain/enums/payment_step.dart';

/// Estados da tela de pagamento.
sealed class CheckoutState {
  const CheckoutState();
}

/// Esperando o valor. [error] explica um valor inválido.
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
    required this.charge,
    required this.payload,
    required this.remaining,
  });

  /// Cobrança devolvida pelo backend.
  final PixCharge charge;

  /// [PixCharge.brCode] já interpretado e validado pelo pix_brcode.
  final PixPayload payload;

  /// Tempo até expirar.
  final Duration remaining;

  /// Cópia com outro [remaining].
  AwaitingPayment copyWith({required Duration remaining}) =>
      AwaitingPayment(charge: charge, payload: payload, remaining: remaining);
}

/// O pagador pagou e o Pix está passando pelas etapas até a confirmação.
final class ProcessingPayment extends CheckoutState {
  /// Cria o estado.
  const ProcessingPayment({
    required this.charge,
    required this.payload,
    required this.currentStep,
  });

  /// Cobrança em pagamento.
  final PixCharge charge;

  /// Payload da cobrança.
  final PixPayload payload;

  /// Etapa em andamento. As anteriores já foram concluídas.
  final PaymentStep currentStep;
}

/// Pagamento confirmado pelo backend.
final class PaymentConfirmed extends CheckoutState {
  /// Cria o estado.
  const PaymentConfirmed({
    required this.charge,
    required this.payload,
    required this.receipt,
  });

  /// Cobrança paga.
  final PixCharge charge;

  /// Payload da cobrança paga.
  final PixPayload payload;

  /// Comprovante.
  final PaymentReceipt receipt;
}

/// A cobrança expirou sem pagamento.
final class ChargeExpired extends CheckoutState {
  /// Cria o estado.
  const ChargeExpired(this.amount);

  /// Valor da cobrança expirada, para gerar outra igual.
  final double amount;
}

/// Falha ao criar, validar ou acompanhar a cobrança.
final class CheckoutFailed extends CheckoutState {
  /// Cria o estado.
  const CheckoutFailed(this.message, this.amount);

  /// Mensagem para o usuário.
  final String message;

  /// Valor pedido, para tentar de novo.
  final double amount;
}
