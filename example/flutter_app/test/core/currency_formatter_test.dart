import 'package:flutter_test/flutter_test.dart';
import 'package:pix_checkout_demo/app/core/formatters/currency_formatter.dart';

void main() {
  test('formatBrl', () {
    expect(formatBrl(10.5), r'R$ 10,50');
    expect(formatBrl(0.01), r'R$ 0,01');
    expect(formatBrl(1234.5), r'R$ 1234,50');
  });

  test('formatDateTime', () {
    expect(
        formatDateTime(DateTime(2026, 1, 2, 3, 4, 5)), '02/01/2026 03:04:05');
  });
}
