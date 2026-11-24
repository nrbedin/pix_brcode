import 'package:flutter_test/flutter_test.dart';
import 'package:pix_brcode/pix_brcode.dart';
import 'package:pix_checkout_demo/app/modules/reader/presentation/controller/reader_controller.dart';
import 'package:pix_checkout_demo/app/modules/reader/presentation/mobx/reader_state.dart';
import 'package:pix_checkout_demo/app/modules/reader/presentation/mobx/reader_store.dart';

void main() {
  late ReaderStore store;
  late ReaderController controller;

  final code = StaticPixPayload(
    key: PixKey.parse('+5511999998888'),
    merchantName: 'Fulano',
    merchantCity: 'RECIFE',
  ).encode();

  setUp(() {
    store = ReaderStore();
    controller = ReaderController(store);
  });

  test('começa sem nada lido', () {
    expect((store.state as ReaderIdle).message, isNull);
  });

  test('texto vazio pede um código', () {
    controller.read('   ');
    expect((store.state as ReaderIdle).message, isNotNull);
  });

  test('código válido vira ReaderDecoded', () {
    controller.read(code);
    final reading = (store.state as ReaderDecoded).reading;
    expect((reading.payload as StaticPixPayload).key.type, PixKeyType.phone);
  });

  test('código inválido guarda o erro com campo e posição', () {
    final broken = code.replaceFirst('5802BR', '5802US');
    controller.read(broken);
    final state = store.state as ReaderInvalid;
    expect(state.source, broken);
    // O CRC é conferido antes dos campos, então é ele que acusa a troca.
    expect(state.error.field, '63');
    expect(state.error.offset, isNotNull);
  });

  test('clear volta ao início', () {
    controller.read(code);
    controller.clear();
    expect(store.state, isA<ReaderIdle>());
  });
}
