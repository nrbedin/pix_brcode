# pix_brcode

Gera, interpreta e valida payloads **Pix BR Code** (padrão EMV QRCPS) em Dart puro, sem dependências.

> Em desenvolvimento. A API ainda pode mudar antes da versão 1.0.

## Escopo

- **Gerar** payload estático (chave, valor opcional, nome, cidade, txid) e dinâmico (URL de cobrança).
- **Interpretar** uma string em um objeto tipado, com `PixParseException` indicando o campo inválido.
- **CRC16-CCITT** (polinômio `0x1021`, valor inicial `0xFFFF`) para gerar e validar.
- **Validar** tamanhos de campo, caracteres permitidos e formato da chave (e-mail, telefone, CPF/CNPJ, EVP).
- **Exemplos**: CLI (`dart run example/main.dart --key ... --amount 10.50`) e app Flutter mínimo com `qr_flutter`.

Todos os dados usados em testes e exemplos são fictícios.

## Uso

```dart
import 'package:pix_brcode/pix_brcode.dart';

void main() {
  // QR estático: a chave vai no próprio payload.
  final estatico = StaticPixPayload(
    key: PixKey.parse('123e4567-e12b-12d1-a456-426655440000'),
    merchantName: 'Fulano de Tal',
    merchantCity: 'Brasília', // acentos são removidos
    amount: 10.50, // opcional
    txid: 'PEDIDO123', // opcional
  );
  print(estatico.encode()); // string do "Pix Copia e Cola"

  // QR dinâmico: aponta para a URL de cobrança do PSP.
  final dinamico = DynamicPixPayload(
    url: 'https://pix.exemplo.com.br/qr/v2/9d36b84fc70b478fb95c12729b90ca25',
    merchantName: 'Fulano de Tal',
    merchantCity: 'Brasília',
  );
  print(dinamico.encode());
}
```

Campos inválidos lançam `ArgumentError` com o nome do parâmetro e o motivo.

## Licença

MIT
