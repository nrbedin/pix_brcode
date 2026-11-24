import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pix_brcode/pix_brcode.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../../core/formatters/currency_formatter.dart';
import '../mobx/checkout_state.dart';

/// QR Code, "copia e cola" e contagem regressiva.
class AwaitingPaymentView extends StatelessWidget {
  /// Cria a tela.
  const AwaitingPaymentView({
    required this.state,
    required this.onCancel,
    this.onShare,
    this.onSimulatePayment,
    super.key,
  });

  /// Estado com a cobrança.
  final AwaitingPayment state;

  /// Cancela a cobrança.
  final VoidCallback onCancel;

  /// Compartilha o QR como imagem, recebendo a área do botão. Devolve
  /// `false` se falhou. `null` esconde o botão.
  final Future<bool> Function(Rect? origin)? onShare;

  /// Simula o pagamento. `null` esconde o botão.
  final VoidCallback? onSimulatePayment;

  Future<void> _copy(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: state.charge.brCode));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Código Pix copiado')),
    );
  }

  Future<void> _share(BuildContext buttonContext) async {
    final box = buttonContext.findRenderObject() as RenderBox?;
    final origin = box == null || !box.hasSize
        ? null
        : box.localToGlobal(Offset.zero) & box.size;
    final shared = await onShare!(origin);
    if (shared || !buttonContext.mounted) return;
    ScaffoldMessenger.of(buttonContext).showSnackBar(
      const SnackBar(content: Text('Não deu para compartilhar o QR Code')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final payload = state.payload;
    final remaining = state.remaining;
    final minutes = remaining.inMinutes.toString().padLeft(2, '0');
    final seconds = (remaining.inSeconds % 60).toString().padLeft(2, '0');

    return Column(
      key: const Key('awaiting'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          formatBrl(state.charge.amount),
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineMedium,
        ),
        Text(
          'para ${payload.merchantName} · ${payload.merchantCity}',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Center(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: QrImageView(
              data: state.charge.brCode,
              size: 240,
              semanticsLabel:
                  'QR Code Pix de ${formatBrl(state.charge.amount)}',
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Escaneie no app do seu banco · expira em $minutes:$seconds',
          key: const Key('countdown'),
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          key: const Key('copy'),
          onPressed: () => _copy(context),
          icon: const Icon(Icons.copy),
          label: const Text('Copiar código Pix'),
        ),
        if (onShare != null) ...[
          const SizedBox(height: 8),
          Builder(
            builder: (buttonContext) => OutlinedButton.icon(
              key: const Key('share'),
              onPressed: () => _share(buttonContext),
              icon: const Icon(Icons.share),
              label: const Text('Compartilhar QR Code'),
            ),
          ),
        ],
        if (payload is DynamicPixPayload) ...[
          const SizedBox(height: 8),
          Text(
            'Cobrança: https://${payload.url}',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall,
          ),
        ],
        TextButton(onPressed: onCancel, child: const Text('Cancelar')),
        if (onSimulatePayment != null) ...[
          const Divider(height: 32),
          Text(
            'Somente demonstração: o QR aponta para uma cobrança fictícia, '
            'então o app do banco não consegue pagá-lo.',
            textAlign: TextAlign.center,
            style: theme.textTheme.labelSmall,
          ),
          const SizedBox(height: 8),
          FilledButton.tonalIcon(
            key: const Key('simulate-payment'),
            onPressed: onSimulatePayment,
            icon: const Icon(Icons.bolt),
            label: const Text('Simular pagamento no banco'),
          ),
        ],
      ],
    );
  }
}
