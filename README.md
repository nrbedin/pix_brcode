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

## Licença

MIT
