import 'package:flutter/services.dart';
import 'package:pix_checkout_demo/app/core/share/share_service.dart';

/// Um compartilhamento registrado pelo [FakeShareService].
typedef SharedImage = ({
  Uint8List png,
  String fileName,
  String? text,
  Rect? origin,
});

/// [ShareService] que só guarda o que foi pedido.
final class FakeShareService implements ShareService {
  /// Compartilhamentos pedidos, em ordem.
  final shared = <SharedImage>[];

  /// Se `true`, o próximo compartilhamento falha como o plugin falharia.
  bool failNext = false;

  @override
  Future<void> shareImage({
    required Uint8List png,
    required String fileName,
    String? text,
    Rect? origin,
  }) async {
    if (failNext) {
      failNext = false;
      throw PlatformException(code: 'share-failed');
    }
    shared.add((png: png, fileName: fileName, text: text, origin: origin));
  }
}
