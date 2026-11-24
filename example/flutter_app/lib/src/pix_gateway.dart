/// Contrato entre o app e o backend que fala com o PSP (banco).
///
/// Em produção, uma implementação real faria chamadas HTTP ao **seu**
/// backend, nunca direto ao PSP: é o backend que guarda o certificado e as
/// credenciais da API Pix, cria a cobrança e recebe o webhook de pagamento.
///
/// - [createCharge] → `POST /cobrancas` no seu backend, que chama a API Pix
///   do PSP e devolve o texto do "Pix Copia e Cola".
/// - [watchStatus] → WebSocket, Server-Sent Events ou polling no seu backend,
///   que fica sabendo do pagamento pelo webhook do PSP.
/// - [cancel] → avisa o backend que a tela foi abandonada.
abstract interface class PixGateway {
  /// Cria uma cobrança de [amount] reais.
  Future<PixCharge> createCharge({required double amount});

  /// Emite as mudanças de status da cobrança [txid].
  Stream<ChargeStatus> watchStatus(String txid);

  /// Cancela a cobrança [txid].
  Future<void> cancel(String txid);
}

/// Cobrança criada pelo backend.
final class PixCharge {
  /// Cria uma cobrança.
  const PixCharge({
    required this.txid,
    required this.brCode,
    required this.expiresIn,
  });

  /// Identificador da cobrança no PSP.
  final String txid;

  /// Texto do "Pix Copia e Cola", que também vai no QR Code.
  final String brCode;

  /// Tempo até a cobrança expirar.
  final Duration expiresIn;
}

/// Status de uma cobrança.
enum ChargeStatus {
  /// Aguardando pagamento.
  pending,

  /// Paga.
  paid,

  /// Expirada no PSP.
  expired,
}
