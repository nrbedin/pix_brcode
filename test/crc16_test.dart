import 'dart:convert';

import 'package:pix_brcode/pix_brcode.dart';
import 'package:test/test.dart';

void main() {
  group('Crc16.compute', () {
    test('valor de verificação padrão do CRC-16/CCITT-FALSE', () {
      expect(Crc16.compute(ascii.encode('123456789')), 0x29B1);
    });

    test('entrada vazia devolve o valor inicial', () {
      expect(Crc16.compute(const []), 0xFFFF);
    });

    test('usa só os 8 bits baixos de cada elemento', () {
      expect(Crc16.compute(const [0x141]), Crc16.compute(const [0x41]));
    });
  });

  group('Crc16.hex', () {
    test('devolve 4 dígitos maiúsculos com zeros à esquerda', () {
      final value = Crc16.hex('123456789');
      expect(value, '29B1');
      expect(value, hasLength(4));
    });

    test('calcula sobre os bytes UTF-8', () {
      expect(
        Crc16.hex('São Paulo'),
        Crc16.compute(utf8.encode('São Paulo'))
            .toRadixString(16)
            .toUpperCase()
            .padLeft(4, '0'),
      );
      expect(Crc16.hex('São Paulo'), isNot(Crc16.hex('Sao Paulo')));
    });
  });

  group('Crc16.isValid', () {
    // Payload estático de exemplo do Manual do BR Code (Bacen), com chave
    // EVP e recebedor fictícios.
    const reference = '00020126580014br.gov.bcb.pix'
        '0136123e4567-e12b-12d1-a456-426655440000'
        '5204000053039865802BR5913Fulano de Tal6008BRASILIA'
        '62070503***63041D3D';

    test('aceita o payload de referência do manual', () {
      expect(Crc16.isValid(reference), isTrue);
    });

    test('aceita CRC em minúsculas', () {
      final lower = '${reference.substring(0, reference.length - 4)}1d3d';
      expect(Crc16.isValid(lower), isTrue);
    });

    test('rejeita CRC errado', () {
      final wrong = '${reference.substring(0, reference.length - 4)}0000';
      expect(Crc16.isValid(wrong), isFalse);
    });

    test('rejeita payload alterado', () {
      final tampered = reference.replaceFirst('BRASILIA', 'BRASILIB');
      expect(Crc16.isValid(tampered), isFalse);
    });

    test('rejeita strings com menos de 4 caracteres', () {
      expect(Crc16.isValid(''), isFalse);
      expect(Crc16.isValid('1D3'), isFalse);
    });
  });
}
