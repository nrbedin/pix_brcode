## 0.1.0-dev

- Estrutura inicial do pacote.
- `Crc16`: cálculo e validação do CRC16-CCITT do BR Code.
- `EmvTlv` e `EmvField`: leitura e escrita de campos EMV TLV, incluindo templates aninhados.
- `PixParseException`: erro de leitura com o caminho do campo (ex.: `26.01`) e a posição na string.
- `PixKey` e `PixKeyType`: validação e normalização de chaves Pix (CPF, CNPJ numérico e alfanumérico, telefone E.164, e-mail e EVP), com detecção automática do tipo.
- `StaticPixPayload` e `DynamicPixPayload`: geração do BR Code estático (chave, valor, descrição, txid, CEP, uso único) e dinâmico (URL de cobrança), com validação de tamanhos e caracteres.
- `PixPayload.parse` e `tryParse`: leitura do BR Code em `StaticPixPayload` ou `DynamicPixPayload`, com `PixParseException` indicando campo e posição.
- Exemplo de linha de comando em `example/main.dart` para gerar e ler BR Codes.
- App Flutter de exemplo em `example/flutter_app`: fluxo de pagamento Pix com backend simulado, validação do BR Code e QR com `qr_flutter`.
- App Flutter de exemplo reestruturado em flutter_modular 5 + MobX (data/domain/presentation), com backend fake em JSON no formato da API Pix, etapas do pagamento e comprovante.
- App de exemplo: compartilhar o QR como imagem PNG (com valor, recebedor e o copia e cola no texto) usando `share_plus`.
- App de exemplo: tela para ler BR Code pela câmera (`mobile_scanner`) ou colando, com resumo, árvore dos campos EMV e o campo e a posição do erro quando inválido.
