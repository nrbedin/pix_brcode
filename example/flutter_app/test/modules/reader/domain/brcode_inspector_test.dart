import 'package:flutter_test/flutter_test.dart';
import 'package:pix_brcode/pix_brcode.dart';
import 'package:pix_checkout_demo/app/modules/reader/domain/services/brcode_inspector.dart';

void main() {
  const inspector = BrCodeInspector();

  final staticCode = StaticPixPayload(
    key: PixKey.parse('fulano@exemplo.com'),
    merchantName: 'Fulano de Tal',
    merchantCity: 'CURITIBA',
    amount: 12.34,
    description: 'Pedido 42',
    txid: 'PEDIDO42',
  ).encode();

  test('estático: payload e árvore de campos com nomes', () {
    final reading = inspector.inspect('  $staticCode\n');

    expect(reading.source, staticCode);
    final payload = reading.payload as StaticPixPayload;
    expect(payload.key.type, PixKeyType.email);
    expect(payload.amount, 12.34);

    final paths = reading.fields.map((f) => f.path).toList();
    expect(paths.first, '00');
    expect(paths.last, '63');

    final account = reading.fields.singleWhere((f) => f.path == '26');
    expect(account.name, 'Conta Pix');
    expect(
      [for (final f in account.children) '${f.path} ${f.name}'],
      ['26.00 Arranjo (GUI)', '26.01 Chave Pix', '26.02 Informação adicional'],
    );
    expect(account.children[1].value, 'fulano@exemplo.com');
    expect(account.children[1].id, '01');

    final additional = reading.fields.singleWhere((f) => f.path == '62');
    expect(additional.children.single.name, 'Identificador (txid)');
    expect(additional.children.single.value, 'PEDIDO42');

    expect(reading.fields.singleWhere((f) => f.path == '54').value, '12.34');
  });

  test('dinâmico: URL da cobrança dentro do 26', () {
    final code = DynamicPixPayload(
      url: 'pix.exemplo.com.br/qr/v2/cobv/ABC',
      merchantName: 'Loja Exemplo',
      merchantCity: 'SAO PAULO',
    ).encode();

    final reading = inspector.inspect(code);
    expect(reading.payload, isA<DynamicPixPayload>());
    final account = reading.fields.singleWhere((f) => f.path == '26');
    expect(account.children.last.path, '26.25');
    expect(account.children.last.name, 'URL da cobrança');
  });

  test('CRC errado lança PixParseException apontando o campo 63', () {
    final broken = '${staticCode.substring(0, staticCode.length - 4)}0000';
    expect(
      () => inspector.inspect(broken),
      throwsA(isA<PixParseException>().having((e) => e.field, 'field', '63')),
    );
  });

  test('texto que não é BR Code lança PixParseException', () {
    expect(
      () => inspector.inspect('https://exemplo.com'),
      throwsA(isA<PixParseException>()),
    );
  });
}
