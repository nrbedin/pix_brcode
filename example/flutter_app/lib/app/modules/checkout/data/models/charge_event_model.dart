import '../../domain/entities/charge_event.dart';
import '../../domain/entities/payment_receipt.dart';
import '../../domain/enums/charge_status.dart';
import '../../domain/enums/payment_step.dart';

/// Evento de cobrança enviado pelo backend.
///
/// `status` e `pix[]` seguem a API Pix. `etapa` só existe na simulação, para
/// mostrar as etapas por trás da confirmação.
final class ChargeEventModel {
  /// Cria o model.
  const ChargeEventModel({required this.status, this.etapa, this.pix});

  /// Lê o JSON do evento. Lança [FormatException] se for inválido.
  factory ChargeEventModel.fromJson(Map<String, dynamic> json) {
    try {
      final pix = json['pix'] as List<dynamic>?;
      return ChargeEventModel(
        status: json['status'] as String,
        etapa: json['etapa'] as String?,
        pix: pix == null || pix.isEmpty
            ? null
            : pix.first as Map<String, dynamic>,
      );
    } on TypeError catch (e) {
      throw FormatException('evento de cobrança inválido: $e');
    }
  }

  static const _statuses = {
    'ATIVA': ChargeStatus.active,
    'CONCLUIDA': ChargeStatus.completed,
    'REMOVIDA_PELO_USUARIO_RECEBEDOR': ChargeStatus.removedByReceiver,
    'REMOVIDA_PELO_PSP': ChargeStatus.removedByPsp,
  };

  static const _steps = {
    'PAGADOR_AUTORIZOU': PaymentStep.payerAuthorized,
    'LIQUIDANDO_NO_SPI': PaymentStep.settlingInSpi,
    'CREDITO_CONFIRMADO': PaymentStep.creditedByPsp,
    'WEBHOOK_RECEBIDO': PaymentStep.webhookReceived,
  };

  /// Status da API Pix (`ATIVA`, `CONCLUIDA`...).
  final String status;

  /// Etapa do pagamento simulado.
  final String? etapa;

  /// Primeiro item de `pix[]`, com os dados do pagamento.
  final Map<String, dynamic>? pix;

  /// Converte para a entidade do domínio.
  ChargeEvent toEntity() {
    final status = _statuses[this.status];
    if (status == null) {
      throw FormatException('status de cobrança desconhecido: ${this.status}');
    }
    final pix = this.pix;
    if (status == ChargeStatus.completed && pix == null) {
      throw const FormatException('cobrança CONCLUIDA sem dados do pix');
    }
    return ChargeEvent(
      status: status,
      step: _steps[etapa],
      receipt: pix == null ? null : _receipt(pix),
    );
  }

  PaymentReceipt _receipt(Map<String, dynamic> pix) {
    try {
      return PaymentReceipt(
        endToEndId: pix['endToEndId'] as String,
        amount: double.parse(pix['valor'] as String),
        paidAt: DateTime.parse(pix['horario'] as String).toLocal(),
        payerName: (pix['pagador'] as Map<String, dynamic>)['nome'] as String,
      );
    } on TypeError catch (e) {
      throw FormatException('dados do pix inválidos: $e');
    }
  }
}
