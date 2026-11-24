import 'package:pix_brcode/pix_brcode.dart';

import 'brcode_field.dart';

/// Um BR Code lido e validado.
final class BrCodeReading {
  /// Cria a leitura.
  const BrCodeReading({
    required this.source,
    required this.payload,
    required this.fields,
  });

  /// O texto lido, sem espaços nas pontas.
  final String source;

  /// O payload interpretado pelo pix_brcode.
  final PixPayload payload;

  /// Os campos EMV na ordem em que aparecem.
  final List<BrCodeField> fields;
}
