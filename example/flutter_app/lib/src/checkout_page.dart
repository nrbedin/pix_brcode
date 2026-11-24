import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pix_brcode/pix_brcode.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'checkout_controller.dart';

/// Tela de pagamento Pix.
///
/// [onSimulatePayment] só existe na demonstração: mostra um botão que imita
/// o pagamento feito no app do banco.
class CheckoutPage extends StatelessWidget {
  /// Cria a tela.
  const CheckoutPage({
    required this.controller,
    this.onSimulatePayment,
    super.key,
  });

  /// Controller com o estado do pagamento.
  final CheckoutController controller;

  /// Simula o pagamento da cobrança com o txid recebido.
  final void Function(String txid)? onSimulatePayment;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pagamento Pix')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: ListenableBuilder(
                listenable: controller,
                builder: (context, _) => switch (controller.state) {
                  EnteringAmount(:final error) => _AmountForm(
                      error: error,
                      onSubmit: controller.submitAmount,
                    ),
                  CreatingCharge(:final amount) => _Status(
                      key: const Key('creating'),
                      leading: const CircularProgressIndicator(),
                      title: 'Gerando cobrança de ${formatBrl(amount)}…',
                    ),
                  final AwaitingPayment state => _AwaitingPayment(
                      state: state,
                      onCancel: controller.cancel,
                      onSimulatePayment: onSimulatePayment,
                    ),
                  PaymentConfirmed(:final payload) => _Status(
                      key: const Key('paid'),
                      leading: Icon(
                        Icons.check_circle,
                        size: 72,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      title: 'Pagamento confirmado',
                      subtitle: payload.amount == null
                          ? payload.merchantName
                          : '${formatBrl(payload.amount!)} para '
                              '${payload.merchantName}',
                      action: FilledButton(
                        onPressed: controller.cancel,
                        child: const Text('Nova cobrança'),
                      ),
                    ),
                  ChargeExpired(:final amount) => _Status(
                      key: const Key('expired'),
                      leading: const Icon(Icons.timer_off, size: 72),
                      title: 'O QR Code expirou',
                      subtitle: 'Nenhum pagamento foi recebido a tempo.',
                      action: FilledButton(
                        onPressed: () => controller.createCharge(amount),
                        child: const Text('Gerar novo QR Code'),
                      ),
                      secondary: TextButton(
                        onPressed: controller.cancel,
                        child: const Text('Alterar valor'),
                      ),
                    ),
                  CheckoutFailed(:final message, :final amount) => _Status(
                      key: const Key('failed'),
                      leading: Icon(
                        Icons.error_outline,
                        size: 72,
                        color: Theme.of(context).colorScheme.error,
                      ),
                      title: 'Algo deu errado',
                      subtitle: message,
                      action: FilledButton(
                        onPressed: () => controller.createCharge(amount),
                        child: const Text('Tentar de novo'),
                      ),
                      secondary: TextButton(
                        onPressed: controller.cancel,
                        child: const Text('Alterar valor'),
                      ),
                    ),
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AmountForm extends StatefulWidget {
  const _AmountForm({required this.error, required this.onSubmit});

  final String? error;
  final void Function(String amountText) onSubmit;

  @override
  State<_AmountForm> createState() => _AmountFormState();
}

class _AmountFormState extends State<_AmountForm> {
  final _amount = TextEditingController();

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  void _submit() => widget.onSubmit(_amount.text);

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const Key('amount-form'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Quanto você quer cobrar?',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 16),
        TextField(
          key: const Key('amount-field'),
          controller: _amount,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
          ],
          decoration: InputDecoration(
            labelText: 'Valor',
            prefixText: 'R\$ ',
            hintText: '10,50',
            errorText: widget.error,
            border: const OutlineInputBorder(),
          ),
          onSubmitted: (_) => _submit(),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          key: const Key('generate'),
          onPressed: _submit,
          icon: const Icon(Icons.qr_code_2),
          label: const Text('Gerar QR Code Pix'),
        ),
      ],
    );
  }
}

class _AwaitingPayment extends StatelessWidget {
  const _AwaitingPayment({
    required this.state,
    required this.onCancel,
    required this.onSimulatePayment,
  });

  final AwaitingPayment state;
  final VoidCallback onCancel;
  final void Function(String txid)? onSimulatePayment;

  Future<void> _copy(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: state.charge.brCode));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Código Pix copiado')),
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
          formatBrl(state.amount),
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineMedium,
        ),
        Text(
          'para ${payload.merchantName} · ${payload.merchantCity}',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium,
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
              semanticsLabel: 'QR Code Pix de ${formatBrl(state.amount)}',
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
        if (payload is DynamicPixPayload) ...[
          const SizedBox(height: 8),
          Text(
            'Cobrança: https://${payload.url}',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall,
          ),
        ],
        TextButton(onPressed: onCancel, child: const Text('Cancelar')),
        if (onSimulatePayment case final simulate?) ...[
          const Divider(height: 32),
          Text(
            'Somente demonstração',
            textAlign: TextAlign.center,
            style: theme.textTheme.labelSmall,
          ),
          const SizedBox(height: 8),
          FilledButton.tonalIcon(
            key: const Key('simulate-payment'),
            onPressed: () => simulate(state.charge.txid),
            icon: const Icon(Icons.bolt),
            label: const Text('Simular pagamento no banco'),
          ),
        ],
      ],
    );
  }
}

class _Status extends StatelessWidget {
  const _Status({
    required this.leading,
    required this.title,
    this.subtitle,
    this.action,
    this.secondary,
    super.key,
  });

  final Widget leading;
  final String title;
  final String? subtitle;
  final Widget? action;
  final Widget? secondary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(child: leading),
        const SizedBox(height: 16),
        Text(
          title,
          textAlign: TextAlign.center,
          style: theme.textTheme.titleLarge,
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 8),
          Text(subtitle!, textAlign: TextAlign.center),
        ],
        if (action != null) ...[const SizedBox(height: 24), action!],
        if (secondary != null) secondary!,
      ],
    );
  }
}
