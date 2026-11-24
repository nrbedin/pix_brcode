/// Status de uma cobrança, como na API Pix (`ATIVA`, `CONCLUIDA`...).
enum ChargeStatus {
  /// `ATIVA`: aguardando pagamento.
  active,

  /// `CONCLUIDA`: paga.
  completed,

  /// `REMOVIDA_PELO_USUARIO_RECEBEDOR`: cancelada por quem cobra.
  removedByReceiver,

  /// `REMOVIDA_PELO_PSP`: removida pelo PSP, por exemplo ao expirar.
  removedByPsp,
}
