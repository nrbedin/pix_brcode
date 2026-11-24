/// Formata [amount] como `R$ 10,50`.
String formatBrl(double amount) =>
    'R\$ ${amount.toStringAsFixed(2).replaceAll('.', ',')}';

/// Formata [value] como `24/11/2026 14:05:09`.
String formatDateTime(DateTime value) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(value.day)}/${two(value.month)}/${value.year} '
      '${two(value.hour)}:${two(value.minute)}:${two(value.second)}';
}
