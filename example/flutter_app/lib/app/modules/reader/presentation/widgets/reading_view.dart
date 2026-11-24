import 'package:flutter/material.dart';
import 'package:pix_brcode/pix_brcode.dart';

import '../../../../core/formatters/currency_formatter.dart';
import '../../domain/entities/brcode_field.dart';
import '../../domain/entities/brcode_reading.dart';

/// Resumo do BR Code lido e a lista dos campos EMV.
class ReadingView extends StatelessWidget {
  /// Cria a tela.
  const ReadingView({required this.reading, super.key});

  /// O que foi lido.
  final BrCodeReading reading;

  static String _keyType(PixKeyType type) => switch (type) {
        PixKeyType.cpf => 'CPF',
        PixKeyType.cnpj => 'CNPJ',
        PixKeyType.phone => 'telefone',
        PixKeyType.email => 'e-mail',
        PixKeyType.evp => 'chave aleatória',
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final payload = reading.payload;
    final amount = payload.amount;
    final postalCode = payload.postalCode;

    final rows = <(String, String)>[
      (
        'Tipo',
        switch (payload) {
          StaticPixPayload(singleUse: true) => 'Estático · uso único',
          StaticPixPayload() => 'Estático · reutilizável',
          DynamicPixPayload() => 'Dinâmico',
        },
      ),
      (
        'Valor',
        amount == null ? 'Livre (quem paga digita)' : formatBrl(amount)
      ),
      ('Recebedor', payload.merchantName),
      ('Cidade', payload.merchantCity),
      if (postalCode != null) ('CEP', postalCode),
      ...switch (payload) {
        StaticPixPayload(:final key, :final description, :final txid) => [
            ('Chave (${_keyType(key.type)})', key.value),
            if (description != null) ('Descrição', description),
            if (txid != null) ('txid', txid),
          ],
        DynamicPixPayload(:final url) => [('Cobrança', 'https://$url')],
      },
    ];

    return Column(
      key: const Key('decoded'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(Icons.verified, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text('BR Code válido', style: theme.textTheme.titleMedium),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                for (final (label, value) in rows)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 120,
                          child: Text(label, style: theme.textTheme.bodySmall),
                        ),
                        Expanded(child: SelectableText(value)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (payload is DynamicPixPayload) ...[
          const SizedBox(height: 8),
          Text(
            'Num QR dinâmico, o app do banco busca a cobrança nessa URL e é '
            'ela, assinada pelo PSP, que define valor e vencimento finais.',
            style: theme.textTheme.bodySmall,
          ),
        ],
        const SizedBox(height: 16),
        ExpansionTile(
          key: const Key('fields'),
          title: const Text('Campos EMV'),
          subtitle: Text('${reading.source.length} caracteres'),
          tilePadding: EdgeInsets.zero,
          childrenPadding: const EdgeInsets.only(bottom: 8),
          children: [
            for (final field in reading.fields) _FieldTile(field: field),
          ],
        ),
      ],
    );
  }
}

class _FieldTile extends StatelessWidget {
  const _FieldTile({required this.field, this.depth = 0});

  final BrCodeField field;
  final int depth;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mono = theme.textTheme.bodySmall?.copyWith(fontFamily: 'monospace');
    return Padding(
      padding: EdgeInsets.only(left: depth * 16.0, top: 4, bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 48,
                child: Text(
                  field.path,
                  style: mono?.copyWith(color: theme.colorScheme.primary),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(field.name, style: theme.textTheme.bodyMedium),
                    if (field.children.isEmpty)
                      SelectableText(field.value, style: mono),
                  ],
                ),
              ),
            ],
          ),
          for (final child in field.children)
            _FieldTile(field: child, depth: depth + 1),
        ],
      ),
    );
  }
}
