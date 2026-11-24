import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:flutter_modular/flutter_modular.dart';

import '../../../../core/formatters/currency_formatter.dart';
import '../controller/checkout_controller.dart';
import '../mobx/checkout_state.dart';
import '../widgets/amount_form.dart';
import '../widgets/awaiting_payment_view.dart';
import '../widgets/processing_payment_view.dart';
import '../widgets/receipt_view.dart';
import '../widgets/status_view.dart';

/// Tela de pagamento Pix.
class CheckoutPage extends StatefulWidget {
  /// Cria a tela.
  const CheckoutPage({super.key});

  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  final _controller = Modular.get<CheckoutController>();

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Pagamento Pix')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Observer(
                builder: (_) => switch (controller.store.state) {
                  EnteringAmount(:final error) => AmountForm(
                      error: error,
                      onSubmit: controller.submitAmount,
                    ),
                  CreatingCharge(:final amount) => StatusView(
                      key: const Key('creating'),
                      leading: const CircularProgressIndicator(),
                      title: 'Gerando cobrança de ${formatBrl(amount)}…',
                    ),
                  final AwaitingPayment state => AwaitingPaymentView(
                      state: state,
                      onCancel: controller.cancel,
                      onSimulatePayment: controller.simulator == null
                          ? null
                          : controller.simulatePayment,
                    ),
                  final ProcessingPayment state =>
                    ProcessingPaymentView(state: state),
                  final PaymentConfirmed state => ReceiptView(
                      state: state,
                      onNewCharge: controller.cancel,
                    ),
                  ChargeExpired(:final amount) => StatusView(
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
                  CheckoutFailed(:final message, :final amount) => StatusView(
                      key: const Key('failed'),
                      leading: Icon(
                        Icons.error_outline,
                        size: 72,
                        color: colors.error,
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
