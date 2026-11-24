import 'package:flutter/material.dart';
import 'package:pix_brcode/pix_brcode.dart';

/// Erro de leitura, com o campo e a posição marcados no código.
class ParseErrorView extends StatelessWidget {
  /// Cria a tela.
  const ParseErrorView({required this.source, required this.error, super.key});

  /// O texto lido.
  final String source;

  /// O erro do pix_brcode.
  final PixParseException error;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final field = error.field;
    final offset = error.offset;
    final mono = theme.textTheme.bodySmall?.copyWith(fontFamily: 'monospace');
    final marked = offset != null && offset >= 0 && offset < source.length;

    return Column(
      key: const Key('invalid'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(Icons.error_outline, color: colors.error),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Não é um BR Code Pix válido',
                style: theme.textTheme.titleMedium,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          field == null ? error.message : 'Campo $field: ${error.message}',
          key: const Key('error-message'),
        ),
        if (marked) ...[
          const SizedBox(height: 12),
          Text('Posição $offset:', style: theme.textTheme.bodySmall),
          const SizedBox(height: 4),
          SelectableText.rich(
            key: const Key('error-source'),
            TextSpan(
              style: mono,
              children: [
                TextSpan(text: source.substring(0, offset)),
                TextSpan(
                  text: source[offset],
                  style: TextStyle(
                    color: colors.onError,
                    backgroundColor: colors.error,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextSpan(text: source.substring(offset + 1)),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
