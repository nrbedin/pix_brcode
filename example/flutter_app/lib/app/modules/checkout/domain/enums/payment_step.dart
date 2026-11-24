/// Etapas de um pagamento Pix, do pagador até a confirmação para quem cobra.
///
/// Num sistema real, o app de quem cobra só fica sabendo da última etapa (o
/// webhook). As anteriores aparecem aqui para mostrar o que acontece por
/// trás da confirmação.
enum PaymentStep {
  /// O pagador leu o QR e autorizou no app do banco dele.
  payerAuthorized('Pagador autorizou no app do banco'),

  /// O banco do pagador enviou a ordem ao SPI, o sistema do Banco Central
  /// que liquida o Pix entre os bancos.
  settlingInSpi('Liquidando no SPI (Banco Central)'),

  /// O PSP de quem cobra recebeu o crédito na conta.
  creditedByPsp('Crédito confirmado pelo PSP'),

  /// O PSP avisou o backend por webhook, e o backend avisou o app.
  webhookReceived('Backend recebeu a confirmação');

  const PaymentStep(this.label);

  /// Descrição para a tela.
  final String label;
}
