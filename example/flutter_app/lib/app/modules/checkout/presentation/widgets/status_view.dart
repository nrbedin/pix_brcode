import 'package:flutter/material.dart';

/// Tela simples de status: ícone, título, texto e ações.
class StatusView extends StatelessWidget {
  /// Cria a tela.
  const StatusView({
    required this.leading,
    required this.title,
    this.subtitle,
    this.action,
    this.secondary,
    super.key,
  });

  /// Ícone ou indicador no topo.
  final Widget leading;

  /// Título.
  final String title;

  /// Texto de apoio.
  final String? subtitle;

  /// Ação principal.
  final Widget? action;

  /// Ação secundária.
  final Widget? secondary;

  @override
  Widget build(BuildContext context) {
    final subtitle = this.subtitle;
    final action = this.action;
    final secondary = this.secondary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(child: leading),
        const SizedBox(height: 16),
        Text(
          title,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 8),
          Text(subtitle, textAlign: TextAlign.center),
        ],
        if (action != null) ...[const SizedBox(height: 24), action],
        if (secondary != null) secondary,
      ],
    );
  }
}
