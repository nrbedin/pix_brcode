import 'package:flutter/material.dart';

import '../../../../core/formatters/currency_formatter.dart';
import '../../domain/enums/payment_step.dart';
import '../mobx/checkout_state.dart';

/// Etapas do pagamento, marcadas conforme o backend avisa.
class ProcessingPaymentView extends StatelessWidget {
  /// Cria a tela.
  const ProcessingPaymentView({required this.state, super.key});

  /// Estado com a etapa atual.
  final ProcessingPayment state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final current = state.currentStep.index;

    return Column(
      key: const Key('processing'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Center(child: CircularProgressIndicator()),
        const SizedBox(height: 16),
        Text(
          'Processando ${formatBrl(state.charge.amount)}',
          textAlign: TextAlign.center,
          style: theme.textTheme.titleLarge,
        ),
        const SizedBox(height: 4),
        Text(
          'Não feche esta tela.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 24),
        for (final step in PaymentStep.values)
          _StepTile(
            key: Key('step-${step.name}'),
            label: step.label,
            status: step.index < current
                ? _StepStatus.done
                : step.index == current
                    ? _StepStatus.running
                    : _StepStatus.pending,
          ),
        const SizedBox(height: 16),
        Text(
          'Na vida real, o app de quem cobra só recebe a última etapa. As '
          'anteriores acontecem entre os bancos e o Banco Central, em '
          'poucos segundos.',
          textAlign: TextAlign.center,
          style: theme.textTheme.labelSmall,
        ),
      ],
    );
  }
}

enum _StepStatus { pending, running, done }

class _StepTile extends StatelessWidget {
  const _StepTile({required this.label, required this.status, super.key});

  final String label;
  final _StepStatus status;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final (icon, color) = switch (status) {
      _StepStatus.done => (
          const Icon(Icons.check_circle, key: Key('done')),
          colors.primary,
        ),
      _StepStatus.running => (
          const SizedBox.square(
            dimension: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          colors.onSurface,
        ),
      _StepStatus.pending => (
          const Icon(Icons.radio_button_unchecked),
          colors.outline,
        ),
    };

    return ListTile(
      dense: true,
      leading: SizedBox(width: 24, child: Center(child: icon)),
      iconColor: color,
      textColor: color,
      title: Text(label),
    );
  }
}
