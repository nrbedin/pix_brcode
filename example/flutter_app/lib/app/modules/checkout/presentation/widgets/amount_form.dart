import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Campo de valor e botão para gerar a cobrança.
class AmountForm extends StatefulWidget {
  /// Cria o formulário.
  const AmountForm({required this.onSubmit, this.error, super.key});

  /// Mensagem de erro do valor.
  final String? error;

  /// Chamado com o texto digitado.
  final void Function(String amountText) onSubmit;

  @override
  State<AmountForm> createState() => _AmountFormState();
}

class _AmountFormState extends State<AmountForm> {
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
