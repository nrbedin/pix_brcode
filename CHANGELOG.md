## 0.1.0-dev

- Estrutura inicial do pacote.
- `Crc16`: cálculo e validação do CRC16-CCITT do BR Code.
- `EmvTlv` e `EmvField`: leitura e escrita de campos EMV TLV, incluindo templates aninhados.
- `PixParseException`: erro de leitura com o caminho do campo (ex.: `26.01`) e a posição na string.
- `PixKey` e `PixKeyType`: validação e normalização de chaves Pix (CPF, CNPJ numérico e alfanumérico, telefone E.164, e-mail e EVP), com detecção automática do tipo.
