import '../enums/charge_status.dart';
import '../enums/payment_step.dart';
import 'payment_receipt.dart';

/// Mudança na cobrança, avisada pelo backend.
final class ChargeEvent {
  /// Cria o evento.
  const ChargeEvent({required this.status, this.step, this.receipt});

  /// Status da cobrança.
  final ChargeStatus status;

  /// Etapa do pagamento em andamento, se houver.
  final PaymentStep? step;

  /// Comprovante, presente quando [status] é [ChargeStatus.completed].
  final PaymentReceipt? receipt;
}
