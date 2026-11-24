import 'package:flutter/material.dart';

import '../../../../core/formatters/currency_formatter.dart';
import '../mobx/checkout_state.dart';

/// Comprovante do pagamento recebido.
class ReceiptView extends StatelessWidget {
  /// Cria o comprovante.
  const ReceiptView(
      {required this.state, required this.onNewCharge, super.key});

  /// Estado com o comprovante.
  final PaymentConfirmed state;

  /// Volta para uma nova cobrança.
  final VoidCallback onNewCharge;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final receipt = state.receipt;
    final rows = [
      ('Valor', formatBrl(receipt.amount)),
      ('Data', formatDateTime(receipt.paidAt)),
      ('Pagador', receipt.payerName),
      ('Recebedor', state.payload.merchantName),
      ('ID da transação (E2E)', receipt.endToEndId),
      ('txid', state.charge.txid),
    ];

    return Column(
      key: const Key('paid'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(Icons.check_circle, size: 72, color: theme.colorScheme.primary),
        const SizedBox(height: 16),
        Text(
          'Pagamento recebido',
          textAlign: TextAlign.center,
          style: theme.textTheme.titleLarge,
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final (label, value) in rows) ...[
                  Text(label, style: theme.textTheme.labelSmall),
                  SelectableText(value, style: theme.textTheme.bodyMedium),
                  const SizedBox(height: 8),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        FilledButton(
            onPressed: onNewCharge, child: const Text('Nova cobrança')),
      ],
    );
  }
}
